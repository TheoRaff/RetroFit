import UIKit

enum RenderError: Error, Equatable, Sendable {
    case missingConfig(String)
    case imageEncodingFailed
    case imageTooLarge
    case server(status: Int, message: String)
    case invalidResponse
    case timedOut
}

extension RenderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingConfig(let key): return "Rendering isn't set up on this phone (\(key) is missing)."
        case .imageEncodingFailed: return "That photo couldn't be prepared. Try another one."
        case .imageTooLarge: return "That photo is too large to send. Try another one."
        case .server(_, let message): return "The render failed: \(message)"
        case .invalidResponse: return "The render service sent back something unexpected. Try again."
        case .timedOut: return "The render is taking too long. Try again."
        }
    }
}

enum RenderStatus: Equatable, Sendable {
    case queued(position: Int?)
    case inProgress
    case completed(URL)
}

/// Output shapes the model supports.
enum RenderAspectRatio: String, Sendable {
    case square = "1:1"
    case landscape = "16:9"
    case tall = "9:16"
    case wide = "4:3"
    case portrait = "3:4"
}

/// Sends HTTP requests. Tests swap in a fake that replays canned responses.
protocol RenderHTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionRenderClient: RenderHTTPClient {
    var session: URLSession = .shared

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RenderError.invalidResponse
        }
        return (data, http)
    }
}

/// Talks to the Vercel render function in server/api/render.ts:
/// starts an AI try-on render, then checks back until the image is ready.
struct RenderService: Sendable {
    let config: RenderConfig
    var client: any RenderHTTPClient = URLSessionRenderClient()
    var pollInterval: Duration = .seconds(2)
    var timeout: Duration = .seconds(120)

    /// The upload sends two photos and waits for them to reach fal.ai, so it gets longer than a status check.
    static let uploadTimeout: TimeInterval = 60
    static let statusTimeout: TimeInterval = 20

    /// Network errors worth riding out while checking on a render, e.g. patchy venue Wi-Fi.
    private static let transientNetworkErrors: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
    ]

    /// Renders `clothing` onto the person in `person` and returns the finished image's URL.
    /// `onStatus` reports each progress check, for a "Buffering…" bar.
    func render(
        person: UIImage,
        clothing: UIImage,
        preservePose: Bool = true,
        aspectRatio: RenderAspectRatio = .portrait,
        onStatus: @escaping @Sendable (RenderStatus) -> Void = { _ in }
    ) async throws -> URL {
        let requestId = try await start(person: person, clothing: clothing, preservePose: preservePose, aspectRatio: aspectRatio)
        return try await waitForImage(requestId: requestId, onStatus: onStatus)
    }

    func start(
        person: UIImage,
        clothing: UIImage,
        preservePose: Bool = true,
        aspectRatio: RenderAspectRatio = .portrait
    ) async throws -> String {
        let payload: [String: Any] = [
            "personImage": try RenderImageEncoder.dataURI(for: person),
            "clothingImage": try RenderImageEncoder.dataURI(for: clothing),
            "preservePose": preservePose,
            "aspectRatio": aspectRatio.rawValue,
        ]
        var request = makeRequest(method: "POST", timeout: Self.uploadTimeout)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let started: StartedRender = try await send(request)
        return started.requestId
    }

    func status(of requestId: String) async throws -> RenderStatus {
        let request = makeRequest(method: "GET", query: [URLQueryItem(name: "id", value: requestId)], timeout: Self.statusTimeout)
        let progress: RenderProgress = try await send(request)
        switch progress.status {
        case "COMPLETED":
            guard let text = progress.imageUrl, let url = URL(string: text) else {
                throw RenderError.invalidResponse
            }
            return .completed(url)
        case "IN_QUEUE":
            return .queued(position: progress.queuePosition)
        default:
            return .inProgress
        }
    }

    func waitForImage(
        requestId: String,
        onStatus: @escaping @Sendable (RenderStatus) -> Void = { _ in }
    ) async throws -> URL {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while true {
            try Task.checkCancellation()
            if let status = try await statusRidingOutNetworkDrops(of: requestId) {
                onStatus(status)
                if case .completed(let url) = status {
                    return url
                }
            }
            guard clock.now + pollInterval < deadline else {
                throw RenderError.timedOut
            }
            try await Task.sleep(for: pollInterval)
        }
    }

    /// A status check, or nil when the network briefly dropped and the next check should try again.
    private func statusRidingOutNetworkDrops(of requestId: String) async throws -> RenderStatus? {
        do {
            return try await status(of: requestId)
        } catch let error as URLError where Self.transientNetworkErrors.contains(error.code) {
            return nil
        }
    }

    // MARK: HTTP

    private func makeRequest(method: String, query: [URLQueryItem] = [], timeout: TimeInterval) -> URLRequest {
        var components = URLComponents(url: config.baseURL.appending(path: "api/render"), resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components?.url ?? config.baseURL)
        request.httpMethod = method
        request.setValue(config.token, forHTTPHeaderField: "x-app-token")
        request.timeoutInterval = timeout
        return request
    }

    /// Sends a request and unwraps the function's `{ success, data, error }` envelope.
    private func send<Payload: Decodable>(_ request: URLRequest) async throws -> Payload {
        let (data, response) = try await client.send(request)
        let envelope = try? JSONDecoder().decode(Envelope<Payload>.self, from: data)
        guard (200..<300).contains(response.statusCode) else {
            let message = envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw RenderError.server(status: response.statusCode, message: message)
        }
        guard let envelope, envelope.success, let payload = envelope.data else {
            throw RenderError.invalidResponse
        }
        return payload
    }
}

private struct Envelope<Payload: Decodable>: Decodable {
    let success: Bool
    let data: Payload?
    let error: String?
}

private struct StartedRender: Decodable {
    let requestId: String
}

private struct RenderProgress: Decodable {
    let status: String
    let queuePosition: Int?
    let imageUrl: String?
}
