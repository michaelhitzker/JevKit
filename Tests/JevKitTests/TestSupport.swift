import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import JevKit

let fixture = """
{"model":"jev-1.13.0","answers":{
 "bug":{"type":"noul","noul":0.92},
 "priority":{"type":"choice","choice":"high","confidence":0.82,"probabilities":{"low":0.15,"high":0.85}},
 "urgency":{"type":"score","score":1.3,"confidence":0.54,"probabilities":{"0":0.0,"1":0.7,"2":0.3},"legend":{"0":"Cosmetic","1":"Workaround exists","2":"Blocking"}}
},"usage":{"input_tokens":312,"output_tokens":48}}
"""
let noulFixture = """
{"model":"jev-latest","answers":{"bug":{"type":"noul","noul":0.92}},"usage":{"input_tokens":12,"output_tokens":4}}
"""
let bugQuestion = JevQuestion.noul(id: "bug", question: "Is this a bug?")
let allQuestions: [JevQuestion] = [
    bugQuestion,
    .choice(id: "priority", question: "What priority?", criteria: ["low": .null, "high": "Blocking"]),
    .score(id: "urgency", question: "How urgent?", levels: ["Cosmetic", "Workaround exists", "Blocking"])
]

enum TestFailure: Error { case noStub, invalidURL }

actor StubTransport: JevTransport {
    enum Reply: Sendable {
        case http(Int, String, [String: String] = [:])
        case failure(URLError.Code)
    }
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw TestFailure.noStub }
        switch replies.removeFirst() {
        case .failure(let code): throw URLError(code)
        case .http(let status, let body, let headers):
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
            return (Data(body.utf8), response)
        }
    }
}

actor DelayRecorder {
    private(set) var values: [Duration] = []
    func record(_ delay: Duration) { values.append(delay) }
}

// AsyncStream's continuation is Sendable and synchronized by the standard library.
struct EventLogger: JevLogger {
    let continuation: AsyncStream<JevLogEvent>.Continuation
    func log(_ event: JevLogEvent) { continuation.yield(event) }
}

func client(_ transport: any JevTransport, retries: Int = 0) throws -> JevClient {
    try JevClient(configuration: .init(apiKey: "test-secret", retryPolicy: .init(maximumRetries: retries, initialDelay: .zero)), transport: transport)
}

func expectInvalidRequest(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Expected invalid request") }
    catch JevError.invalidRequest { }
    catch { Issue.record("Unexpected error: \(error)") }
}
