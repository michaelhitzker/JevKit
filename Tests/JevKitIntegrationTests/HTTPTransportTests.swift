import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import JevKit

@Suite(.enabled(if: ProcessInfo.processInfo.environment["JEV_TEST_HTTP_URL"] != nil,
                "Run python3 Scripts/test-http.py for local URLSession tests."), .timeLimit(.minutes(1)))
struct HTTPTransportTests {
    func baseURL() throws -> URL {
        let text = try #require(ProcessInfo.processInfo.environment["JEV_TEST_HTTP_URL"])
        return try #require(URL(string: text))
    }
    func client(timeout: Duration = .seconds(10)) throws -> JevClient {
        try JevClient(configuration: .init(apiKey: "local-fixture", baseURL: baseURL(), timeout: timeout, retryPolicy: .init(maximumRetries: 0)))
    }
    let question = JevQuestion.noul(id: "bug", question: "Bug?")

    @Test func realURLSessionEncodesAndDecodes() async throws {
        let result = try await client().evaluate(state: "normal", questions: [question])
        #expect(try result.noul("bug").probability == 0.91)
    }

    @Test func redirectsAreNotFollowed() async throws {
        do { _ = try await client().evaluate(state: "redirect", questions: [question]); Issue.record("Redirect was followed") }
        catch JevError.httpError(let details) { #expect(details.status == 307) }
    }

    @Test func realURLSessionTimeout() async throws {
        do { _ = try await client(timeout: .milliseconds(250)).evaluate(state: "timeout", questions: [question]); Issue.record("Expected timeout") }
        catch JevError.transport(let code) { #expect(code == URLError.timedOut.rawValue) }
    }

    @Test func realURLSessionCancellation() async throws {
        let id = "cancel-" + UUID().uuidString
        let client = try client()
        let task = Task { try await client.evaluate(state: id, questions: [question]) }
        defer { task.cancel() }
        let url = try baseURL().appendingPathComponent("seen").appendingPathComponent(id)
        let observer = URLSession(configuration: .ephemeral)
        defer { observer.invalidateAndCancel() }
        var seen = false
        for _ in 0..<200 {
            let (data, _) = try await observer.data(from: url)
            if String(decoding: data, as: UTF8.self) == "yes" { seen = true; break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try #require(seen, "Fixture server must receive the request before cancellation")
        let clock = ContinuousClock()
        let start = clock.now
        task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError { }
        #expect(start.duration(to: clock.now) < .seconds(2))
    }
}
