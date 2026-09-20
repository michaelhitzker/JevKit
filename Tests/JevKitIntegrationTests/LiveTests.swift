import Foundation
import Testing
import JevKit

@Test(.enabled(if: !(ProcessInfo.processInfo.environment["JEV_API_KEY"] ?? "").isEmpty,
               "Set JEV_API_KEY to opt in to a billable live API contract test."))
func liveAllPrimitives() async throws {
    let key = try #require(ProcessInfo.processInfo.environment["JEV_API_KEY"])
    let client = try JevClient(apiKey: key)
    let response = try await client.evaluate(state: "The application crashes at startup for every production user after an upgrade.", questions: [
        .noul(id: "bug", question: "Does the report describe a bug?"),
        .choice(id: "priority", question: "How serious is this?", criteria: ["low": "Cosmetic only", "high": "Application unavailable"]),
        .score(id: "urgency", question: "How soon does it need attention?", levels: ["Can wait", "Needs immediate attention"])
    ])
    #expect((0...1).contains(try response.noul("bug").probability))
    #expect(try response.choice("priority").probabilities.count == 2)
    #expect(try response.score("urgency").probabilities.count == 2)
    #expect(!response.metadata.model.isEmpty)
}
