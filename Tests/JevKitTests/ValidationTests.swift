import Foundation
import Testing
@testable import JevKit

@Test(arguments: [JevValue.string(""), .string(" \n"), .object([:]), .array([]), .null, .bool(true), .number(2), .object(["invalid": .number(.infinity)])])
func invalidStateNeverSends(_ state: JevValue) async throws {
    let transport = StubTransport([])
    let client = try client(transport)
    await expectInvalidRequest { _ = try await client.evaluate(state: state, questions: [bugQuestion]) }
    #expect(await transport.requests.isEmpty)
}

@Test func duplicateIDsAndEmptyQuestionsNeverSend() async throws {
    let transport = StubTransport([])
    let client = try client(transport)
    await expectInvalidRequest { _ = try await client.evaluate(state: "text", questions: [bugQuestion, bugQuestion]) }
    await expectInvalidRequest { _ = try await client.evaluate(state: "text", questions: []) }
    #expect(await transport.requests.isEmpty)
}

@Test(arguments: [
    JevQuestion.noul(id: " ", question: "Question"),
    .noul(id: "x", question: " \n"),
    .noul(id: "x", question: "Question", yes: .number(4)),
    .choice(id: "x", question: "Question", criteria: ["a": .null]),
    .choice(id: "x", question: "Question", criteria: ["": .null, "b": .null]),
    .choice(id: "x", question: "Question", criteria: ["a": .number(2), "b": .null]),
    .score(id: "x", question: "Question", levels: []),
    .score(id: "x", question: "Question", levels: ["One"]),
    .score(id: "x", question: "Question", levels: ["", "Two"]),
    .score(id: "x", question: "Question", levels: Array(repeating: "Level", count: 11)),
    .choice(id: "x", question: "Question", criteria: Dictionary(uniqueKeysWithValues: (0...255).map { (String($0), JevValue.null) }))
])
func invalidQuestionsNeverSend(_ question: JevQuestion) async throws {
    let transport = StubTransport([])
    let client = try client(transport)
    await expectInvalidRequest { _ = try await client.evaluate(state: "text", questions: [question]) }
    #expect(await transport.requests.isEmpty)
}

@Test func choiceArrayDetectsDuplicatesAndEncodesNull() throws {
    #expect(throws: JevError.self) { try JevQuestion.choice(id: "x", question: "Question", options: ["a", "a"]) }
    let question = try JevQuestion.choice(id: "x", question: "Question", options: ["a", "b"])
    try question.validate()
    #expect(WireQuestion(question).criteria == .object(["a": .null, "b": .null]))
}

@Test(arguments: [-0.1, 1.1, Double.nan, Double.infinity])
func invalidThresholds(_ threshold: Double) async throws {
    let response = try await client(StubTransport([.http(200, fixture)])).evaluate(state: "text", questions: allQuestions)
    #expect(throws: JevError.self) { try response.noul("bug").value(threshold: threshold) }
    #expect(throws: JevError.self) { try response.choice("priority").isConfident(threshold: threshold) }
    #expect(throws: JevError.self) { try response.score("urgency").value(ifConfidenceAtLeast: threshold) }
}

@Test(arguments: [(1.0, 1.0), (2.0, 1.0), (Double.nan, 100.0), (0.0, Double.infinity), (-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)])
func invalidScoreScales(_ bounds: (Double, Double)) async throws {
    let response = try await client(StubTransport([.http(200, fixture)])).evaluate(state: "text", questions: allQuestions)
    #expect(throws: JevError.self) { try response.score("urgency").scaled(minimum: bounds.0, maximum: bounds.1) }
}

@Test(arguments: ["", " ", "key\nInjected: value", "key\r", "key with space", "🔑"])
func invalidAPIKey(_ key: String) {
    #expect(throws: JevError.self) { try JevClient(apiKey: key) }
}

@Test(arguments: ["http://example.com", "https://user:pass@example.com", "https://example.com?key=value", "https://example.com/#fragment", "file:///tmp/test"])
func invalidBaseURL(_ value: String) throws {
    let url = try #require(URL(string: value))
    #expect(throws: JevError.self) { try JevClient(configuration: .init(apiKey: "key", baseURL: url)) }
}

@Test func invalidConfigurationTimingAndModel() {
    #expect(throws: JevError.self) { try JevClient(configuration: .init(apiKey: "key", timeout: .zero)) }
    #expect(throws: JevError.self) { try JevClient(configuration: .init(apiKey: "key", model: " \n")) }
    #expect(throws: JevError.self) { try JevClient(configuration: .init(apiKey: "key", retryPolicy: .init(maximumRetries: -1))) }
    #expect(throws: JevError.self) { try JevClient(configuration: .init(apiKey: "key", retryPolicy: .init(initialDelay: .seconds(10), maximumDelay: .seconds(1)))) }
}

@Test func loopbackHTTPIsSupported() throws {
    let url = try #require(URL(string: "http://127.0.0.1:8000"))
    _ = try JevClient(configuration: .init(apiKey: "development", baseURL: url))
}

@Test(arguments: [
    ("\"noul\":0.92", "\"noul\":1.2"),
    ("\"noul\":0.92", "\"noul\":-0.1"),
    ("\"type\":\"noul\"", "\"type\":\"unknown\""),
    ("\"bug\":", "\"other\":"),
    ("\"choice\":\"high\"", "\"choice\":\"missing\""),
    ("\"choice\":\"high\"", "\"choice\":\"low\""),
    ("\"confidence\":0.82", "\"confidence\":2"),
    ("\"low\":0.15", "\"low\":0.9"),
    ("\"low\":0.15", "\"unknown\":0.15"),
    ("\"score\":1.3", "\"score\":3"),
    ("\"0\":0.0", "\"00\":0.0"),
    ("\"0\":\"Cosmetic\"", "\"9\":\"Cosmetic\""),
    ("\"input_tokens\":312", "\"input_tokens\":-1"),
    ("\"model\":\"jev-1.13.0\"", "\"model\":\"\"")
])
func invalidResponsesAreRejected(_ replacement: (String, String)) async throws {
    let body = fixture.replacingOccurrences(of: replacement.0, with: replacement.1)
    let transport = StubTransport([.http(200, body)])
    do {
        _ = try await client(transport, retries: 2).evaluate(state: "text", questions: allQuestions)
        Issue.record("Expected invalid response")
    } catch JevError.invalidResponse { }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: ["not json", "{}", "{\"model\":\"jev\",\"answers\":{},\"usage\":null}", noulFixture.replacingOccurrences(of: "0.92", with: "\"0.92\"")])
func malformedResponses(_ body: String) async throws {
    do {
        _ = try await client(StubTransport([.http(200, body)])).evaluate(state: "text", questions: [bugQuestion])
        Issue.record("Expected decoding failure")
    } catch JevError.decodingFailed { }
}

@Test func typedAccessRejectsMissingAndWrongType() async throws {
    let response = try await client(StubTransport([.http(200, noulFixture)])).evaluate(state: "text", questions: [bugQuestion])
    #expect(throws: JevError.self) { try response.noul("missing") }
    #expect(throws: JevError.self) { try response.choice("bug") }
    #expect(throws: JevError.self) { try response.score("bug") }
}
