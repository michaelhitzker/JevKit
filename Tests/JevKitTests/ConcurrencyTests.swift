import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import JevKit

actor BlockingTransport: JevTransport {
    let started: AsyncStream<Void>.Continuation
    private(set) var observedCancellation = false
    init(started: AsyncStream<Void>.Continuation) { self.started = started }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        started.yield(())
        do { try await Task.sleep(for: .seconds(60)) }
        catch { observedCancellation = error is CancellationError; throw error }
        throw TestFailure.noStub
    }
}

@Test(.timeLimit(.minutes(1))) func cancellationDuringTransportPropagates() async throws {
    let (started, signal) = AsyncStream<Void>.makeStream()
    let transport = BlockingTransport(started: signal)
    let client = try client(transport, retries: 2)
    let task = Task { try await client.evaluate(state: "text", questions: [bugQuestion]) }
    for await _ in started { break }
    task.cancel()
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.observedCancellation)
    signal.finish()
}

@Test(.timeLimit(.minutes(1))) func cancellationDuringBackoffStopsRetries() async throws {
    let (started, signal) = AsyncStream<Void>.makeStream()
    let transport = StubTransport([.http(529, "busy")])
    let client = try JevClient(configuration: .init(apiKey: "key"), transport: transport, sleep: { _ in
        signal.yield(())
        try await Task.sleep(for: .seconds(60))
    })
    let task = Task { try await client.evaluate(state: "text", questions: [bugQuestion]) }
    for await _ in started { break }
    task.cancel()
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.requests.count == 1)
    signal.finish()
}

@Test func urlCancellationNormalizesToCancellationError() async throws {
    let transport = StubTransport([.failure(.cancelled)])
    do { _ = try await client(transport, retries: 2).evaluate(state: "text", questions: [bugQuestion]); Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.requests.count == 1)
}

@Test(.timeLimit(.minutes(1))) func preCancelledRequestDoesNotSend() async throws {
    let (gate, signal) = AsyncStream<Void>.makeStream()
    let transport = StubTransport([])
    let client = try client(transport)
    let task = Task {
        for await _ in gate { break }
        return try await client.evaluate(state: "text", questions: [bugQuestion])
    }
    task.cancel()
    signal.finish()
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.requests.isEmpty)
}

actor ConcurrentTransport: JevTransport {
    private var first: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls += 1
        if calls == 1 { await withCheckedContinuation { first = $0 } }
        else { first?.resume(); first = nil }
        let data = try #require(request.httpBody)
        let requestValue = try JSONDecoder().decode(JevValue.self, from: data)
        guard case .object(let body) = requestValue, case .string(let state) = body["state"] else { throw TestFailure.noStub }
        let probability = state == "first" ? "0.1" : "0.9"
        let responseBody = noulFixture.replacingOccurrences(of: "0.92", with: probability)
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        return (Data(responseBody.utf8), response)
    }
}

@Test(.timeLimit(.minutes(1))) func concurrentRequestsOverlapWithoutMixingAnswers() async throws {
    let transport = ConcurrentTransport()
    let client = try client(transport)
    async let first = client.evaluate(state: "first", questions: [bugQuestion])
    async let second = client.evaluate(state: "second", questions: [bugQuestion])
    let results = try await (first, second)
    #expect(try results.0.noul("bug").probability == 0.1)
    #expect(try results.1.noul("bug").probability == 0.9)
    #expect(await transport.calls == 2)
}
