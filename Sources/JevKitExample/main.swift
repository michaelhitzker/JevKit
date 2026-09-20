import Foundation
import JevKit

struct GitHubIssue: Encodable, Sendable {
    let title: String
    let body: String
    let labels: [String]
}

enum Priority: String, CaseIterable, Codable, JevChoice {
    case low, medium, high, critical
    var jevDescription: JevValue {
        switch self {
        case .low: return "Cosmetic issue, no functional impact"
        case .medium: return "Degraded behavior with a practical workaround"
        case .high: return "Core workflow blocked for some customers"
        case .critical: return "Production outage or data loss requiring immediate response"
        }
    }
}

struct IssueAssessment: JevSchema {
    static let bug = Noul("Is this probably a software bug?", id: "bug")
    static let duplicate = Noul("Does the supplied context identify an existing issue with the same root cause?", id: "duplicate")
    static let priorityQuestion = Choice<Priority>("What priority should this issue have?", id: "priority")
    static let urgencyQuestion = Score("How soon does this issue need attention?", id: "urgency", levels: [
        "Can wait for normal backlog grooming", "Needs attention in the next business day", "Requires immediate incident response"
    ])
    static let human = Noul("Does ambiguity, missing context, or potential harm require human review?", id: "human")
    static var questions: [JevQuestion] { [bug.question, duplicate.question, priorityQuestion.question, urgencyQuestion.question, human.question] }

    let isBug: NoulResult
    let isDuplicate: NoulResult
    let priority: ChoiceResult<Priority>
    let urgency: ScoreResult
    let needsHumanReview: NoulResult
    let metadata: JevMetadata

    init(response: JevResponse) throws {
        isBug = try response.answer(Self.bug)
        isDuplicate = try response.answer(Self.duplicate)
        priority = try response.answer(Self.priorityQuestion)
        urgency = try response.answer(Self.urgencyQuestion)
        needsHumanReview = try response.answer(Self.human)
        metadata = response.metadata
    }
}

// Jev supplies fuzzy judgment. This function owns deterministic policy.
func route(_ assessment: IssueAssessment) -> String {
    if assessment.needsHumanReview.probability > 0.90 { return "Route to human review" }
    if assessment.priority.value == .critical && assessment.priority.confidence > 0.95 { return "Page an engineer" }
    if assessment.priority.confidence < 0.75 { return "Request confirmation of priority" }
    return "Queue as \(assessment.priority.value.rawValue) priority"
}

if let key = ProcessInfo.processInfo.environment["JEV_API_KEY"], !key.isEmpty {
    do {
        let client = try JevClient(apiKey: key)
        let issue = GitHubIssue(title: "Crash after upgrade", body: "Production users cannot launch version 4.2. Previous version worked. No known duplicates supplied.", labels: ["production"])
        let assessment = try await client.evaluate(state: JevValue(encoding: issue), as: IssueAssessment.self)
        print("Bug probability: \(assessment.isBug.probability)")
        print("Duplicate probability: \(assessment.isDuplicate.probability)")
        print("Urgency: \(assessment.urgency.value), confidence: \(assessment.urgency.confidence)")
        print("Priority distribution: \(assessment.priority.probabilities)")
        print(route(assessment))
    } catch {
        print("Evaluation failed: \(error)")
        exit(1)
    }
} else {
    print("Set JEV_API_KEY to run issue triage. This makes a billable request to TypeSafe.")
}
