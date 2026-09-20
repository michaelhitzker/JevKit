# Compose typed assessments

Collect typed question descriptors into a Sendable result struct.

## Define options and a schema

```swift
enum Priority: String, JevChoice {
    case low, high
}

struct Assessment: JevSchema {
    static let bug = Noul("Is this probably a bug?", id: "bug")
    static let priorityQuestion = Choice<Priority>("What priority?", id: "priority")
    static var questions: [JevQuestion] { [bug.question, priorityQuestion.question] }

    let isBug: NoulResult
    let priority: ChoiceResult<Priority>

    init(response: JevResponse) throws {
        isBug = try response.answer(Self.bug)
        priority = try response.answer(Self.priorityQuestion)
    }
}

let assessment = try await client.evaluate(state: issueText, as: Assessment.self)
```

``JevSchema`` keeps initialization explicit. Results cannot accidentally remain in an unevaluated property-wrapper state. Runtime arrays remain available through each descriptor's `question` property. Duplicate question IDs are rejected before encoding.

## Keep policy separate

Use Noul's `probability` to gate a yes decision. Use Choice's or Score's `confidence` to decide whether to accept its result automatically. A low Noul probability means no; it is not a signal to discard the answer.

Score criteria must be descriptive levels, not a bare range. ``ScoreResult`` preserves fractional indices and the full distribution. Its local scale conversion can support a UI, but does not change the meaning of the model's answer.

The library validates probabilities and rejects missing or incompatible answers. It does not guarantee the model's judgment is correct for your domain. Evaluate your rubric and policy on representative data.
