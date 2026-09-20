# ``JevKit``

Typed probabilistic decisions for Swift, powered by TypeSafe AI's Jev API.

## Overview

Jev evaluates fuzzy judgments. Your Swift code owns deterministic policy. Use ``JevClient`` to submit state and independent questions in one request, then read typed answers without discarding their probability distributions.

```swift
let bug = Noul("Does this describe a software bug?", id: "bug")
let client = try JevClient(apiKey: apiKey)
let response = try await client.evaluate(
    state: "The app crashes at startup.",
    questions: [bug.question]
)
let answer = try response.answer(bug)
if answer.probability > 0.9 {
    // Apply your own policy.
}
```

Noul supplies a yes probability. Choice supplies a selected option, confidence, and all option probabilities. Score supplies a fractional position on an ordered rubric, confidence, a level distribution, and a legend. Confidence is preserved from the API, not recomputed as the winning probability.

Keep long-lived API keys on a trusted backend. A consumer application cannot keep an embedded secret private.

## Topics

### Evaluate state

- ``JevClient``
- ``JevConfiguration``
- ``JevRetryPolicy``
- ``JevValue``

### Define questions

- ``JevQuestion``
- ``JevQuestionID``
- ``Noul``
- ``Choice``
- ``Score``
- ``JevChoice``

### Read results

- ``JevResponse``
- ``JevAnswer``
- ``NoulResult``
- ``ChoiceResult``
- ``ScoreResult``
- ``JevMetadata``
- ``JevUsage``

### Compose a schema

- ``JevSchema``
- ``JevField``
- <doc:TypedAssessments>

### Integrate and observe

- ``JevTransport``
- ``URLSessionTransport``
- ``JevLogger``
- ``JevLogEvent``
- ``JevError``
- ``JevHTTPFailure``
