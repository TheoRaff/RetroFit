import Foundation
import Testing
import UIKit
@testable import TheoRaff

/// Replays canned responses and records the requests the service sends.
private final class FakeRenderClient: RenderHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(Int, String)]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [(status: Int, body: String)]) {
        self.responses = responses.map { ($0.status, $0.body) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        let (status, body) = responses.isEmpty ? (500, "") : responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

/// Throws the given network errors first, then behaves like FakeRenderClient.
private final class FlakyRenderClient: RenderHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [URLError.Code]
    private let next: FakeRenderClient

    init(failures: [URLError.Code], then responses: [(status: Int, body: String)]) {
        self.failures = failures
        self.next = FakeRenderClient(responses)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        let failure = failures.isEmpty ? nil : failures.removeFirst()
        lock.unlock()
        if let failure { throw URLError(failure) }
        return try await next.send(request)
    }
}

private final class StatusLog: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var statuses: [RenderStatus] = []
    func append(_ status: RenderStatus) { lock.lock(); statuses.append(status); lock.unlock() }
}

struct RenderServiceTests {
    private let config = RenderConfig(baseURL: URL(string: "https://render.example.com")!, token: "secret")
    private let photo = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
    }

    private func service(_ client: FakeRenderClient, timeout: Duration = .seconds(5)) -> RenderService {
        RenderService(config: config, client: client, pollInterval: .zero, timeout: timeout)
    }

    private func body(of request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func startSendsTheRenderRequest() async throws {
        let client = FakeRenderClient([(202, #"{"success":true,"data":{"requestId":"req-1"},"error":null}"#)])
        let id = try await service(client).start(person: photo, clothing: photo, aspectRatio: .tall)
        #expect(id == "req-1")

        let request = try #require(client.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://render.example.com/api/render")
        #expect(request.value(forHTTPHeaderField: "x-app-token") == "secret")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
        let json = try body(of: request)
        #expect((json["personImage"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true)
        #expect((json["clothingImage"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true)
        #expect(json["preservePose"] as? Bool == true)
        #expect(json["aspectRatio"] as? String == "9:16")
    }

    @Test func statusAsksForTheRequestWithTheToken() async throws {
        let client = FakeRenderClient([(200, #"{"success":true,"data":{"status":"IN_QUEUE","queuePosition":3},"error":null}"#)])
        let status = try await service(client).status(of: "req-1")
        #expect(status == .queued(position: 3))
        let request = try #require(client.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://render.example.com/api/render?id=req-1")
        #expect(request.value(forHTTPHeaderField: "x-app-token") == "secret")
    }

    @Test(arguments: [
        (#"{"success":true,"data":{"status":"IN_QUEUE","queuePosition":null},"error":null}"#, RenderStatus.queued(position: nil)),
        (#"{"success":true,"data":{"status":"IN_PROGRESS","queuePosition":null},"error":null}"#, .inProgress),
        (#"{"success":true,"data":{"status":"COMPLETED","imageUrl":"https://cdn.example.com/out.png"},"error":null}"#,
         .completed(URL(string: "https://cdn.example.com/out.png")!)),
    ])
    func readsEachStatus(body: String, expected: RenderStatus) async throws {
        let status = try await service(FakeRenderClient([(200, body)])).status(of: "req-1")
        #expect(status == expected)
    }

    @Test func surfacesTheServersErrorMessage() async {
        let client = FakeRenderClient([(401, #"{"success":false,"data":null,"error":"Missing or wrong x-app-token header"}"#)])
        await #expect(throws: RenderError.server(status: 401, message: "Missing or wrong x-app-token header")) {
            try await service(client).start(person: photo, clothing: photo)
        }
    }

    @Test func handlesANonJSONFailure() async {
        let client = FakeRenderClient([(504, "Gateway Timeout")])
        await #expect(throws: RenderError.server(status: 504, message: "gateway timed out")) {
            try await service(client).status(of: "req-1")
        }
    }

    @Test func rejectsACompletedRenderWithoutAnImage() async {
        let client = FakeRenderClient([(200, #"{"success":true,"data":{"status":"COMPLETED"},"error":null}"#)])
        await #expect(throws: RenderError.invalidResponse) {
            try await service(client).status(of: "req-1")
        }
    }

    @Test func renderStartsThenPollsUntilTheImageIsReady() async throws {
        let client = FakeRenderClient([
            (202, #"{"success":true,"data":{"requestId":"req-9"},"error":null}"#),
            (200, #"{"success":true,"data":{"status":"IN_QUEUE","queuePosition":1},"error":null}"#),
            (200, #"{"success":true,"data":{"status":"IN_PROGRESS","queuePosition":null},"error":null}"#),
            (200, #"{"success":true,"data":{"status":"COMPLETED","imageUrl":"https://cdn.example.com/look.png"},"error":null}"#),
        ])
        let log = StatusLog()
        let url = try await service(client).render(person: photo, clothing: photo) { log.append($0) }
        #expect(url.absoluteString == "https://cdn.example.com/look.png")
        #expect(log.statuses == [.queued(position: 1), .inProgress, .completed(url)])
        #expect(client.requests.count == 4)
    }

    @Test func keepsCheckingThroughBriefNetworkDrops() async throws {
        let client = FlakyRenderClient(
            failures: [.notConnectedToInternet, .timedOut, .networkConnectionLost],
            then: [(200, #"{"success":true,"data":{"status":"COMPLETED","imageUrl":"https://cdn.example.com/ok.png"},"error":null}"#)]
        )
        let url = try await RenderService(config: config, client: client, pollInterval: .zero, timeout: .seconds(5))
            .waitForImage(requestId: "req-1")
        #expect(url.absoluteString == "https://cdn.example.com/ok.png")
    }

    @Test func doesNotRetryNonNetworkFailures() async {
        let client = FlakyRenderClient(failures: [.badURL], then: [])
        await #expect(throws: URLError.self) {
            try await RenderService(config: config, client: client, pollInterval: .zero, timeout: .seconds(5))
                .waitForImage(requestId: "req-1")
        }
    }

    @Test func givesUpWhenTheNetworkStaysDown() async {
        let client = FlakyRenderClient(failures: Array(repeating: .notConnectedToInternet, count: 100), then: [])
        let service = RenderService(config: config, client: client, pollInterval: .milliseconds(10), timeout: .milliseconds(40))
        await #expect(throws: RenderError.timedOut) {
            try await service.waitForImage(requestId: "req-1")
        }
    }

    @Test func givesTheUploadMoreTimeThanStatusChecks() async throws {
        let client = FakeRenderClient([
            (202, #"{"success":true,"data":{"requestId":"req-1"},"error":null}"#),
            (200, #"{"success":true,"data":{"status":"IN_PROGRESS","queuePosition":null},"error":null}"#),
        ])
        let service = service(client)
        _ = try await service.start(person: photo, clothing: photo)
        _ = try await service.status(of: "req-1")
        #expect(client.requests[0].timeoutInterval == 60)
        #expect(client.requests[1].timeoutInterval == 20)
    }

    @Test func givesUpAfterTheTimeout() async {
        let queued = #"{"success":true,"data":{"status":"IN_QUEUE","queuePosition":5},"error":null}"#
        let client = FakeRenderClient(Array(repeating: (200, queued), count: 50))
        let slowService = RenderService(config: config, client: client, pollInterval: .milliseconds(20), timeout: .milliseconds(50))
        await #expect(throws: RenderError.timedOut) {
            try await slowService.waitForImage(requestId: "req-1")
        }
    }
}

struct RenderErrorMessageTests {
    @Test(arguments: [
        (RenderError.missingConfig("RenderAPIToken"), "Rendering isn't set up on this phone (RenderAPIToken is missing)."),
        (.imageEncodingFailed, "That photo couldn't be prepared. Try another one."),
        (.imageTooLarge, "That photo is too large to send. Try another one."),
        (.server(status: 502, message: "The render could not start. Try again."), "The render failed: The render could not start. Try again."),
        (.invalidResponse, "The render service sent back something unexpected. Try again."),
        (.timedOut, "The render is taking too long. Try again."),
    ])
    func explainsEachErrorToTheUser(error: RenderError, message: String) {
        #expect(error.localizedDescription == message)
    }

    @Test func fromBundleFailsClearlyWithoutConfig() {
        #expect(throws: RenderError.missingConfig("RenderHost")) {
            try RenderConfig.fromBundle(Bundle(for: BundleMarker.self))
        }
    }
}

private final class BundleMarker {}
