import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import JevKit

@Test func requestEncodingAndCustomBaseURL() async throws {
    let transport = StubTransport([.http(200, fixture)])
    let base = try #require(URL(string: "https://gateway.example/prefix/"))
    let client = try JevClient(configuration: .init(apiKey: "test-secret", baseURL: base, timeout: .seconds(7), model: "jev-1.13.0"), transport: transport)
    let state = JevValue.object(["title": "Crash", "labels": .array(["bug"]), "count": .number(3), "active": .bool(true)])
    _ = try await client.evaluate(state: state, questions: allQuestions)
    let requests = await transport.requests
    let request = try #require(requests.first)
    #expect(request.url?.absoluteString == "https://gateway.example/prefix/v1/systemone")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-secret")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.timeoutInterval == 7)
    let data = try #require(request.httpBody)
    let json = try JSONDecoder().decode(JevValue.self, from: data)
    #expect(json == .object([
        "model": "jev-1.13.0", "state": state,
        "questions": .object([
            "bug": .object(["type": "noul", "instructions": "Is this a bug?"]),
            "priority": .object(["type": "choice", "instructions": "What priority?", "criteria": .object(["low": .null, "high": "Blocking"])]),
            "urgency": .object(["type": "score", "instructions": "How urgent?", "criteria": .array(["Cosmetic", "Workaround exists", "Blocking"])])
        ])
    ]))
}

@Test func decodingRetainsSemanticsAndMetadata() async throws {
    let response = try await client(StubTransport([.http(200, fixture)])).evaluate(state: "Crash", questions: allQuestions)
    let bug = try response.noul("bug")
    #expect(bug.probability == 0.92)
    #expect(bug.value)
    #expect(abs(bug.noProbability - 0.08) < 1e-10)
    #expect(try !bug.value(threshold: 0.95))
    let priority = try response.choice("priority")
    #expect(priority.value == "high")
    #expect(priority.confidence == 0.82)
    #expect(priority.probabilities == ["low": 0.15, "high": 0.85])
    #expect(try priority.value(ifConfidenceAtLeast: 0.8) == "high")
    #expect(try priority.value(ifConfidenceAtLeast: 0.9) == nil)
    let urgency = try response.score("urgency")
    #expect(urgency.value == 1.3)
    #expect(urgency.confidence == 0.54)
    #expect(urgency.probabilities == [0: 0, 1: 0.7, 2: 0.3])
    #expect(urgency.legend[1] == "Workaround exists")
    #expect(try urgency.scaled(to: 0...100) == 65)
    #expect(try urgency.value(ifConfidenceAtLeast: 0.6) == nil)
    #expect(response.metadata.model == "jev-1.13.0")
    #expect(response.metadata.usage.inputTokens == 312)
    #expect(response.metadata.usage.outputTokens == 48)
    #expect(response.metadata.attempts == 1)
    #expect(response.metadata.latency >= .zero)
}

@Test(arguments: [0.0, 0.49, 0.5, 1.0]) func noulBoundary(_ p: Double) async throws {
    let body = noulFixture.replacingOccurrences(of: "0.92", with: String(p))
    let response = try await client(StubTransport([.http(200, body)])).evaluate(state: "text", questions: [bugQuestion])
    #expect(try response.noul("bug").value == (p >= 0.5))
}

@Test func structuredInstructionsAndCriteria() throws {
    let instructions = JevValue.object(["question": "Bug?", "examples": .array(["Crash"])])
    let question = JevQuestion.noul(id: "bug", question: instructions, yes: .object(["meaning": "Defect"]), no: "Expected behavior")
    try question.validate()
    let wire = try JSONDecoder().decode(JevValue.self, from: JSONEncoder().encode(WireQuestion(question)))
    #expect(wire == .object(["type": "noul", "instructions": instructions, "criteria": .object(["true": .object(["meaning": "Defect"]), "false": "Expected behavior"])]))
}

@Test func structuredLegendIsPreserved() async throws {
    let body = fixture.replacingOccurrences(of: "\"0\":\"Cosmetic\"", with: "\"0\":{\"description\":\"Cosmetic\"}")
    let response = try await client(StubTransport([.http(200, body)])).evaluate(state: "text", questions: allQuestions)
    #expect(try response.score("urgency").legend[0] == .object(["description": "Cosmetic"]))
}

@Test func unknownResponseFieldsAreIgnoredAndMissingUsageCountsRemainNil() async throws {
    let body = noulFixture.replacingOccurrences(of: "\"input_tokens\":12,\"output_tokens\":4", with: "\"future\":42")
    let response = try await client(StubTransport([.http(200, body)])).evaluate(state: "text", questions: [bugQuestion])
    #expect(response.metadata.usage.inputTokens == nil)
    #expect(response.metadata.usage.outputTokens == nil)
}

@Test func codableStateAndQuestionID() throws {
    struct State: Codable { let labels: [String]; let attempts: Int }
    #expect(try JevValue(encoding: State(labels: ["bug"], attempts: 2)) == .object(["labels": .array(["bug"]), "attempts": .number(2)]))
    let id: JevQuestionID = "priority"
    #expect(try String(decoding: JSONEncoder().encode(id), as: UTF8.self) == "\"priority\"")
    #expect(try JSONDecoder().decode(JevQuestionID.self, from: Data("\"priority\"".utf8)) == id)
    let value = JevValue.object(["nil": .null, "bool": .bool(false), "nested": .array([.number(2), "text"])])
    #expect(try JSONDecoder().decode(JevValue.self, from: JSONEncoder().encode(value)) == value)
}

@Test func malformedEncodableStateIsRejected() throws {
    #expect(throws: JevError.self) { try JevValue(encoding: Double.nan) }
}
