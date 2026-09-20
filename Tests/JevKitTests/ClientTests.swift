import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import JevKit

@Test(arguments: [401, 403, 400, 404, 422, 429, 500, 529, 302])
func httpErrorsRetainSafeDetails(_ status: Int) async throws {
    let transport = StubTransport([.http(status, "failure body", ["Retry-After": "2"])])
    do {
        _ = try await client(transport).evaluate(state: "text", questions: [bugQuestion])
        Issue.record("Expected HTTP error")
    } catch let error as JevError {
        let details: JevHTTPFailure
        switch error {
        case .authenticationFailed(let value): #expect([401, 403].contains(status)); details = value
        case .rateLimited(let value): #expect(status == 429); details = value
        case .serverError(let value): #expect(status >= 500); details = value
        case .httpError(let value): #expect([400, 404, 422, 302].contains(status)); details = value
        default: Issue.record("Unexpected error category"); return
        }
        #expect(details.status == status)
        #expect(details.responseBody == "failure body")
        #expect(details.retryAfter == .seconds(2))
        #expect(!error.description.contains("failure body"))
    }
}

@Test(arguments: [408, 429, 500, 502, 503, 504, 529])
func retriesDocumentedStatuses(_ status: Int) async throws {
    let transport = StubTransport([.http(status, "busy", ["Retry-After": "2"]), .http(200, noulFixture)])
    let recorder = DelayRecorder()
    let client = try JevClient(configuration: .init(apiKey: "test-secret"), transport: transport, sleep: { await recorder.record($0) })
    let response = try await client.evaluate(state: "text", questions: [bugQuestion])
    #expect(response.metadata.attempts == 2)
    #expect(await recorder.values == [.seconds(2)])
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(requests[0].httpBody == requests[1].httpBody)
}

@Test(arguments: [400, 401, 403, 404, 422, 301])
func deterministicErrorsNeverRetry(_ status: Int) async throws {
    let transport = StubTransport([.http(status, "failure")])
    do { _ = try await client(transport, retries: 2).evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected error") }
    catch is JevError { }
    #expect(await transport.requests.count == 1)
}

@Test func retriesAreBoundedAndExponential() async throws {
    let transport = StubTransport(Array(repeating: .http(529, "busy"), count: 3))
    let recorder = DelayRecorder()
    let client = try JevClient(configuration: .init(apiKey: "test-secret"), transport: transport, sleep: { await recorder.record($0) })
    do { _ = try await client.evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected overload") }
    catch JevError.serverError(let failure) { #expect(failure.status == 529) }
    #expect(await transport.requests.count == 3)
    let delays = await recorder.values
    #expect(delays.count == 2)
    #expect((0.5...0.625).contains(delays[0].secondsValue))
    #expect((1...1.25).contains(delays[1].secondsValue))
}

@Test func excessiveRetryAfterDoesNotRetryEarly() async throws {
    let transport = StubTransport([.http(429, "busy", ["Retry-After": "3600"])])
    let recorder = DelayRecorder()
    let client = try JevClient(configuration: .init(apiKey: "test-secret"), transport: transport, sleep: { await recorder.record($0) })
    do { _ = try await client.evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected rate limit") }
    catch JevError.rateLimited(let failure) { #expect(failure.retryAfter == .seconds(3600)) }
    #expect(await recorder.values.isEmpty)
    #expect(await transport.requests.count == 1)
}

@Test func retryAfterParsing() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(retryAfter("Thu, 01 Jan 1970 00:00:07 GMT", now: now) == .seconds(7))
    #expect(retryAfter("Thu, 01 Jan 1970 00:00:00 GMT", now: now.addingTimeInterval(1)) == .zero)
    #expect(retryAfter(" 3 ") == .seconds(3))
    #expect(retryAfter("-1") == nil)
    #expect(retryAfter("nan") == nil)
    #expect(retryAfter("1e100") == nil)
    #expect(retryAfter("later") == nil)
}

@Test(arguments: [URLError.Code.timedOut, .networkConnectionLost, .cannotConnectToHost])
func transientTransportRetries(_ code: URLError.Code) async throws {
    let transport = StubTransport([.failure(code), .http(200, noulFixture)])
    let response = try await client(transport, retries: 1).evaluate(state: "text", questions: [bugQuestion])
    #expect(response.metadata.attempts == 2)
}

@Test func certificateFailureNeverRetries() async throws {
    let transport = StubTransport([.failure(.serverCertificateUntrusted)])
    do { _ = try await client(transport, retries: 2).evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected failure") }
    catch JevError.transport(let code) { #expect(code == URLError.serverCertificateUntrusted.rawValue) }
    #expect(await transport.requests.count == 1)
}

@Test func secretsAreRedactedFromConfigurationErrorsAndLogs() async throws {
    let secret = "test-secret"
    let configuration = JevConfiguration(apiKey: secret)
    #expect(!String(describing: configuration).contains(secret))
    #expect(!String(reflecting: configuration).contains(secret))
    #expect(!String(describing: Mirror(reflecting: configuration).children.map { String(describing: $0.value) }).contains(secret))
    let (events, continuation) = AsyncStream<JevLogEvent>.makeStream()
    let logger = EventLogger(continuation: continuation)
    let transport = StubTransport([.http(401, "{\"error\":\"Bearer test-\\u0073ecret\"}")])
    let client = try JevClient(configuration: configuration, transport: transport, logger: logger)
    do { _ = try await client.evaluate(state: "sensitive customer data", questions: [bugQuestion]); Issue.record("Expected auth failure") }
    catch JevError.authenticationFailed(let failure) {
        #expect(!failure.responseBody.contains(secret))
        #expect(failure.responseBody.contains("<redacted>"))
    }
    continuation.finish()
    var logText = ""
    for await event in events { logText += String(describing: event) }
    #expect(logText.contains("requestStarted"))
    #expect(logText.contains("requestFailed"))
    #expect(!logText.contains(secret))
    #expect(!logText.contains("sensitive customer data"))
}

@Test func errorBodyIsBoundedAfterRedaction() {
    let body = String(repeating: "x", count: 8190) + "test-secret"
    let redacted = redactedBody(Data(body.utf8), apiKey: "test-secret")
    #expect(redacted.utf8.count <= 8192)
    #expect(!redacted.contains("test-secret"))
    #expect(redactedBody(Data("plain test-secret".utf8), apiKey: "test-secret") == "plain <redacted>")
}

@Test func arbitraryTransportErrorDoesNotExposeUnderlyingSecrets() async throws {
    struct Transport: JevTransport {
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            throw NSError(domain: "test-secret", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bearer test-secret"])
        }
    }
    do { _ = try await client(Transport()).evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected failure") }
    catch {
        #expect(!String(reflecting: error).contains("test-secret"))
        #expect(!error.localizedDescription.contains("test-secret"))
    }
}

@Test func observableSuccessAndDecodeFailure() async throws {
    for body in [noulFixture, "invalid"] {
        let (events, continuation) = AsyncStream<JevLogEvent>.makeStream()
        let client = try JevClient(configuration: .init(apiKey: "key"), transport: StubTransport([.http(200, body)]), logger: EventLogger(continuation: continuation))
        do { _ = try await client.evaluate(state: "text", questions: [bugQuestion]) }
        catch JevError.decodingFailed { }
        continuation.finish()
        var kinds: [String] = []
        var ids: Set<UUID> = []
        for await event in events {
            switch event {
            case .requestStarted(let id, _): ids.insert(id); kinds.append("start")
            case .responseReceived(let id, _, _): ids.insert(id); kinds.append("http")
            case .requestCompleted(let id, _, _): ids.insert(id); kinds.append("complete")
            case .decodingFailed(let id): ids.insert(id); kinds.append("decode")
            case .requestFailed(let id, _): ids.insert(id); kinds.append("fail")
            case .retry: Issue.record("Unexpected retry")
            }
        }
        #expect(ids.count == 1)
        #expect(kinds == (body == noulFixture ? ["start", "http", "complete"] : ["start", "http", "decode", "fail"]))
    }
}

@Test func unicodeErrorBodyTruncationPreservesByteLimit() {
    let body = String(repeating: "a", count: 8191) + "🔑"
    let redacted = redactedBody(Data(body.utf8), apiKey: "test-secret")
    #expect(redacted.utf8.count <= 8192)
    #expect(!redacted.contains("�"))
}
