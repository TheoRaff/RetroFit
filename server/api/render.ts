import { createHash, timingSafeEqual } from "node:crypto";
import { fal } from "@fal-ai/client";

/**
 * Virtual try-on renders for the TheoRaff app, using fal.ai's image-apps-v2 model.
 *
 * Every request needs the header `x-app-token: <APP_TOKEN>`.
 *
 * POST /api/render starts a render.
 *   JSON body:
 *     personImage    data URI ("data:image/jpeg;base64,...") or https URL   (required)
 *     clothingImage  data URI or https URL                                  (required)
 *     preservePose   boolean, default true
 *     aspectRatio    "1:1" | "16:9" | "9:16" | "4:3" | "3:4", default "3:4"
 *   202 { success: true, data: { requestId }, error: null }
 *
 * GET /api/render?id=<requestId> reports progress, then the finished image.
 *   200 { success: true, data: { status: "IN_QUEUE" | "IN_PROGRESS", queuePosition }, error: null }
 *   200 { success: true, data: { status: "COMPLETED", imageUrl }, error: null }
 *
 * Errors use the same envelope: { success: false, data: null, error: "<message>" }.
 *
 * Environment variables: FAL_KEY (read by @fal-ai/client) and APP_TOKEN (the app sends it).
 */

const MODEL = "fal-ai/image-apps-v2/virtual-try-on";
const ASPECT_RATIOS = ["1:1", "16:9", "9:16", "4:3", "3:4"] as const;
const DEFAULT_ASPECT_RATIO: AspectRatio = "3:4";
/** Per image, after base64 decoding. Vercel caps the whole request body at 4.5 MB. */
const MAX_IMAGE_BYTES = 1.5 * 1024 * 1024;
const DATA_URI = /^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=\s]+)$/;
const REQUEST_ID = /^[A-Za-z0-9-]{8,100}$/;
/** Best effort only: each serverless instance keeps its own count. */
const RATE_LIMIT = { maxRenders: 20, windowMs: 60_000 };

type AspectRatio = (typeof ASPECT_RATIOS)[number];
type FalClient = typeof fal;

interface Env {
  appToken: string | undefined;
  falKey: string | undefined;
}

type ParsedImage =
  | { kind: "url"; url: string }
  | { kind: "data"; mimeType: string; bytes: Uint8Array };

interface RenderRequest {
  person: ParsedImage;
  clothing: ParsedImage;
  preservePose: boolean;
  aspectRatio: AspectRatio;
}

class InputError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}

// MARK: Responses

function respond<T>(status: number, data: T | null, error: string | null = null): Response {
  const body = { success: error === null, data, error };
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

// MARK: Checks

function sha256(text: string): Buffer {
  return createHash("sha256").update(text).digest();
}

/** Compares hashes so the check takes the same time whatever the token length. */
function isAuthorised(request: Request, appToken: string): boolean {
  const sent = request.headers.get("x-app-token") ?? "";
  return timingSafeEqual(sha256(sent), sha256(appToken));
}

/** Returns an error response when the server is misconfigured or the token is wrong. */
function checkAccess(request: Request, env: Env): Response | null {
  if (!env.appToken || !env.falKey) {
    console.error("render: APP_TOKEN or FAL_KEY is not set");
    return respond(500, null, "The render service is not configured");
  }
  if (!isAuthorised(request, env.appToken)) {
    return respond(401, null, "Missing or wrong x-app-token header");
  }
  return null;
}

function parseImage(value: unknown, field: string): ParsedImage {
  if (typeof value !== "string" || value.trim() === "") {
    throw new InputError(`${field} is required`);
  }
  const text = value.trim();
  if (text.startsWith("https://")) {
    try {
      return { kind: "url", url: new URL(text).toString() };
    } catch {
      throw new InputError(`${field} is not a valid URL`);
    }
  }
  const match = DATA_URI.exec(text);
  if (!match) {
    throw new InputError(`${field} must be an https URL or a base64 JPEG, PNG or WebP data URI`);
  }
  const bytes = Buffer.from(match[2].replace(/\s/g, ""), "base64");
  if (bytes.length === 0) {
    throw new InputError(`${field} is empty`);
  }
  if (bytes.length > MAX_IMAGE_BYTES) {
    throw new InputError(`${field} is larger than 1.5 MB. Resize it before sending.`, 413);
  }
  return { kind: "data", mimeType: match[1], bytes: new Uint8Array(bytes) };
}

function parseRenderRequest(body: unknown): RenderRequest {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new InputError("The request body must be a JSON object");
  }
  const fields = body as Record<string, unknown>;
  const preservePose = fields.preservePose ?? true;
  if (typeof preservePose !== "boolean") {
    throw new InputError("preservePose must be true or false");
  }
  const aspectRatio = fields.aspectRatio ?? DEFAULT_ASPECT_RATIO;
  if (!ASPECT_RATIOS.includes(aspectRatio as AspectRatio)) {
    throw new InputError(`aspectRatio must be one of ${ASPECT_RATIOS.join(", ")}`);
  }
  return {
    person: parseImage(fields.personImage, "personImage"),
    clothing: parseImage(fields.clothingImage, "clothingImage"),
    preservePose,
    aspectRatio: aspectRatio as AspectRatio,
  };
}

// MARK: fal helpers

/** fal models read images from URLs, so inline images go to fal's storage first. */
async function toImageUrl(image: ParsedImage, client: FalClient): Promise<string> {
  if (image.kind === "url") {
    return image.url;
  }
  return client.storage.upload(new Blob([image.bytes], { type: image.mimeType }));
}

function falErrorStatus(error: unknown): number | null {
  if (typeof error === "object" && error !== null && "status" in error) {
    const status = (error as { status: unknown }).status;
    return typeof status === "number" ? status : null;
  }
  return null;
}

function firstImageUrl(data: unknown): string | null {
  const images = (data as { images?: unknown } | null)?.images;
  if (!Array.isArray(images)) {
    return null;
  }
  const url = (images[0] as { url?: unknown } | undefined)?.url;
  return typeof url === "string" && url !== "" ? url : null;
}

// MARK: Handlers

/** Builds the endpoints. Tests pass a fake client and fixed environment values. */
export function createRenderHandlers(client: FalClient, readEnv: () => Env) {
  let recentRenders: number[] = [];

  function isRateLimited(now: number): boolean {
    recentRenders = recentRenders.filter((time) => now - time < RATE_LIMIT.windowMs);
    if (recentRenders.length >= RATE_LIMIT.maxRenders) {
      return true;
    }
    recentRenders = [...recentRenders, now];
    return false;
  }

  async function startRender(request: Request): Promise<Response> {
    const denied = checkAccess(request, readEnv());
    if (denied) {
      return denied;
    }
    if (isRateLimited(Date.now())) {
      return respond(429, null, "Too many renders. Wait a minute and try again.");
    }
    let render: RenderRequest;
    try {
      render = parseRenderRequest(await request.json());
    } catch (error) {
      const inputError = error instanceof InputError ? error : new InputError("The request body must be valid JSON");
      return respond(inputError.status, null, inputError.message);
    }
    try {
      const [personUrl, clothingUrl] = await Promise.all([
        toImageUrl(render.person, client),
        toImageUrl(render.clothing, client),
      ]);
      const { request_id } = await client.queue.submit(MODEL, {
        input: {
          person_image_url: personUrl,
          clothing_image_url: clothingUrl,
          preserve_pose: render.preservePose,
          aspect_ratio: { ratio: render.aspectRatio },
        },
      });
      return respond(202, { requestId: request_id });
    } catch (error) {
      const status = falErrorStatus(error);
      console.error("render: submit failed", { status, message: String(error) });
      if (status !== null && status >= 400 && status < 500) {
        return respond(400, null, "fal.ai rejected the images. Send clear JPEG or PNG photos.");
      }
      return respond(502, null, "The render could not start. Try again.");
    }
  }

  async function checkRender(request: Request): Promise<Response> {
    const denied = checkAccess(request, readEnv());
    if (denied) {
      return denied;
    }
    const id = new URL(request.url).searchParams.get("id") ?? "";
    if (!REQUEST_ID.test(id)) {
      return respond(400, null, "id must be a render request id");
    }
    try {
      const queueStatus = await client.queue.status(MODEL, { requestId: id, logs: false });
      if (queueStatus.status !== "COMPLETED") {
        const queuePosition = "queue_position" in queueStatus ? queueStatus.queue_position : null;
        return respond(200, { status: queueStatus.status, queuePosition: queuePosition ?? null });
      }
      const result = await client.queue.result(MODEL, { requestId: id });
      const imageUrl = firstImageUrl(result.data);
      if (!imageUrl) {
        console.error("render: completed without an image", { id });
        return respond(502, null, "The render finished without an image. Try again.");
      }
      return respond(200, { status: "COMPLETED", imageUrl });
    } catch (error) {
      const status = falErrorStatus(error);
      console.error("render: status check failed", { id, status, message: String(error) });
      if (status === 404) {
        return respond(404, null, "No render with that id");
      }
      return respond(502, null, "The render failed. Start a new one.");
    }
  }

  return { startRender, checkRender };
}

const handlers = createRenderHandlers(fal, () => ({
  appToken: process.env.APP_TOKEN,
  falKey: process.env.FAL_KEY,
}));

export function POST(request: Request): Promise<Response> {
  return handlers.startRender(request);
}

export function GET(request: Request): Promise<Response> {
  return handlers.checkRender(request);
}
