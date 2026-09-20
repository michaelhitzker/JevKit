import Testing
@testable import JevKit

enum TestPriority: String, JevChoice { case low, high }
struct TestAssessment: JevSchema {
    static let bug = Noul("Is this a bug?", id: "bug")
    static let priority = Choice<TestPriority>("What priority?", id: "priority")
    static let urgency = Score("How urgent?", id: "urgency", levels: ["Cosmetic", "Workaround exists", "Blocking"])
    static var questions: [JevQuestion] { [bug.question, priority.question, urgency.question] }
    let isBug: NoulResult
    let selectedPriority: ChoiceResult<TestPriority>
    let score: ScoreResult
    init(response: JevResponse) throws {
        isBug = try response.answer(Self.bug)
        selectedPriority = try response.answer(Self.priority)
        score = try response.answer(Self.urgency)
    }
}

@Test func typedSchemaEvaluatesAndPreservesDistribution() async throws {
    let client = try client(StubTransport([.http(200, fixture)]))
    let assessment = try await client.evaluate(state: "Crash", as: TestAssessment.self)
    #expect(assessment.isBug.probability == 0.92)
    #expect(assessment.selectedPriority.value == .high)
    #expect(assessment.selectedPriority.probabilities == [.low: 0.15, .high: 0.85])
    #expect(assessment.score.value == 1.3)
}

@Test func runtimeQuestionsCanUseTypedDescriptors() async throws {
    let question = Noul("Is this a bug?", id: "bug")
    var questions: [JevQuestion] = []
    questions.append(question.question)
    let response = try await client(StubTransport([.http(200, noulFixture)])).evaluate(state: JevValue.object(["title": "Crash"]), questions: questions)
    #expect(try response.answer(question).probability == 0.92)
}

@Test func unknownEnumOptionsAreNotDropped() async throws {
    enum OtherPriority: String, JevChoice { case medium, high }
    let response = try await client(StubTransport([.http(200, fixture)])).evaluate(state: "text", questions: allQuestions)
    #expect(throws: JevError.self) { try response.choice("priority", as: OtherPriority.self) }
}
