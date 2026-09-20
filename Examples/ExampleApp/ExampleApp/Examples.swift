import Foundation
import JevKit

enum Example: String, CaseIterable, Identifiable {
    case noul = "Noul", choice = "Choice", score = "Score", assessment = "Typed assessment"
    var id: Self { self }
    var title: String {
        switch self {
        case .noul: "Yes or no"
        case .choice: "Choose a priority"
        case .score: "Score urgency"
        case .assessment: "Full assessment"
        }
    }
    var question: String {
        switch self {
        case .noul: "Is this a software bug?"
        case .choice: "Which priority fits?"
        case .score: "How urgent is this issue?"
        case .assessment: "Turn an issue into a decision."
        }
    }
    var symbol: String {
        switch self {
        case .noul: "checkmark.circle"
        case .choice: "list.bullet"
        case .score: "slider.horizontal.3"
        case .assessment: "tray.full"
        }
    }
    var explanation: String {
        switch self {
        case .noul: "Ask a yes/no question, then apply your own probability threshold."
        case .choice: "Select a Swift enum case while preserving every option’s probability."
        case .score: "Evaluate an ordered rubric without rounding away fractional results."
        case .assessment: "Send structured state and three independent questions in one request, then apply Swift policy."
        }
    }
    var questions: [JevQuestion] {
        switch self {
        case .noul: [Assessment.bug.question]
        case .choice: [Assessment.priorityQuestion.question]
        case .score: [Assessment.urgencyQuestion.question]
        case .assessment: Assessment.questions
        }
    }
    var code: String {
        switch self {
        case .noul: """
        let bug = Noul("Is this a software bug?", id: "bug")
        let response = try await client.evaluate(
            state: text, questions: [bug.question])
        let answer = try response.answer(bug)
        let labelAsBug = try answer.value(threshold: 0.9)
        """
        case .choice: """
        enum Priority: String, CaseIterable, JevChoice {
            case low, medium, high, critical
        }
        let priority = Choice<Priority>("What priority?", id: "priority")
        let response = try await client.evaluate(
            state: text, questions: [priority.question])
        let answer = try response.answer(priority)
        let trusted = try answer.value(ifConfidenceAtLeast: 0.9)
        """
        case .score: """
        let urgency = Score("How soon does this need attention?",
            id: "urgency", levels: [
                "Can wait for backlog grooming",
                "Needs attention today",
                "Requires immediate incident response"
            ])
        let response = try await client.evaluate(
            state: text, questions: [urgency.question])
        let answer = try response.answer(urgency)
        let displayScore = try answer.scaled(to: 0...100)
        """
        case .assessment: """
        // See Assessment in Examples.swift for the JevSchema definition.
        let state = try JevValue(encoding: Issue(body: text))
        let result = try await client.evaluate(
            state: state, as: Assessment.self)
        // Application policy, separate from model judgment:
        let escalate = result.priority.value == .critical
            && result.priority.confidence >= 0.95
        """
        }
    }
}

enum Priority: String, CaseIterable, JevChoice {
    case low, medium, high, critical
}

struct Issue: Encodable, Sendable {
    let body: String
    let labels = ["production"]
}

struct Assessment: JevSchema {
    static let bug = Noul("Is this a software bug?", id: "bug")
    static let priorityQuestion = Choice<Priority>("What priority?", id: "priority")
    static let urgencyQuestion = Score("How soon does this need attention?", id: "urgency", levels: [
        "Can wait for backlog grooming", "Needs attention today", "Requires immediate incident response"
    ])
    static var questions: [JevQuestion] { [bug.question, priorityQuestion.question, urgencyQuestion.question] }
    let bugResult: NoulResult
    let priority: ChoiceResult<Priority>
    let urgency: ScoreResult
    let metadata: JevMetadata

    init(response: JevResponse) throws {
        bugResult = try response.answer(Self.bug)
        priority = try response.answer(Self.priorityQuestion)
        urgency = try response.answer(Self.urgencyQuestion)
        metadata = response.metadata
    }
}
