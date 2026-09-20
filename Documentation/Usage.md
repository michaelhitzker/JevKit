# JevKit usage guide

[Back to the README](../README.md)

The examples below build on the client and `Priority` enum in the README quick start. Replace application-specific values such as `issueText` with your own data.

## Initialize with an API key

Pass a key directly, select an existing environment variable, or load a plist:

```swift
import Foundation
import JevKit

// Direct value, such as a credential supplied by your application.
let direct = try JevClient(apiKey: "your-api-key")

// Reads TYPESAFE_API_KEY from the current process environment.
let environment = try JevClient()
let customEnvironment = try JevClient(apiKeySource: .environment("JEV_API_KEY"))

// Reads the JEV_API_KEY string in Bundle.main's Info.plist.
let infoPlist = try JevClient(apiKeySource: .infoPlist())
// Custom plist entry and bundle are also supported.
let customInfo = try JevClient(apiKeySource: .infoPlist(key: "TypeSafeKey", bundle: .main))

// Reads an XML or binary plist from a local file URL.
let file = URL(fileURLWithPath: "/path/to/JevSecrets.plist")
let separatePlist = try JevClient(apiKeySource: .plist(url: file))
// Use .plist(url: file, key: "TypeSafeKey") for a custom entry name.
```

For `Info.plist`, add a **String** entry named `JEV_API_KEY` under the Xcode app target's **Info → Custom Target Properties**. A separate `JevSecrets.plist` has this structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>JEV_API_KEY</key>
    <string>your-api-key</string>
</dict>
</plist>
```

If the file is an app resource, obtain its URL with `Bundle.main.url(forResource: "JevSecrets", withExtension: "plist")` and handle a missing file before initialization. Only local file URLs are accepted. Plist entries are top-level, unlocalized strings.

Source-based configuration also works with custom settings and injected transports:

```swift
let configuration = try JevConfiguration(
    apiKeySource: .environment("JEV_API_KEY"),
    timeout: .seconds(15),
    retryPolicy: .init(maximumRetries: 0)
)
let client = try JevClient(configuration: configuration)
```

The selected source is read once during construction. There is no implicit fallback between environment variables or plists. Missing values, non-string plist entries, whitespace, unresolved build-variable placeholders, and unreadable or malformed files throw `JevError.invalidConfiguration` before a request is sent. Diagnostics omit credential values and file paths.

Environment loading reads the running process's environment; it does not parse `.env` files or automatically import your shell's environment into an Xcode-launched app. Set a variable in **Edit Scheme → Run → Arguments → Environment Variables**, or launch your executable from a process that already exports it.

Direct strings and bundled plists do not secure a secret in a distributed app. Keep real credentials out of source control and use a backend to hold production consumer-app secrets.

## Noul: yes/no probability

```swift
let response = try await jev.evaluate(state: "The app crashes at startup.", questions: [
    .noul(id: "is_bug", question: "Does this describe a software bug?")
])
let bug = try response.noul("is_bug")
print(bug.probability)    // Probability of yes, supplied by Jev.
print(bug.noProbability) // 1 - probability, computed locally.
print(bug.value)         // Local policy: probability >= 0.5.
let shouldLabel = try bug.value(threshold: 0.9)
```

Noul does **not** return a separate confidence value. A probability near zero means a strong no, not low confidence. Optional `yes:` and `no:` descriptions clarify the question's boundary.

## Choice: enum values and full distributions

```swift
let priority = Choice<Priority>("What priority should this issue have?", id: "priority")
let response = try await jev.evaluate(state: issueText, questions: [priority.question])
let answer: ChoiceResult<Priority> = try response.answer(priority)
print(answer.value)
print(answer.confidence)
print(answer.probabilities[.critical] as Any)
```

Provide richer rubric descriptions by implementing `var jevDescription: JevValue` on your enum. Its default is `.null`, meaning the option name stands alone. The runtime API also supports `.choice(id:question:criteria:)` and the throwing `.choice(id:question:options:)` convenience.

Confidence is the server's distribution-based statistic. It is **not** the probability of the selected option. JevKit preserves both without substituting one for the other.

## Score: descriptive levels, fractional results

```swift
let urgency = Score("How soon does this need attention?", id: "urgency", levels: [
    "Can wait for normal backlog grooming",
    "Needs attention in the next business day",
    "Requires immediate incident response"
])
let response = try await jev.evaluate(state: issueText, questions: [urgency.question])
let answer = try response.answer(urgency)
print(answer.value)         // For example, 1.3 on the 0...2 level scale.
print(answer.confidence)
print(answer.probabilities) // [Int: Double], one entry per level.
print(answer.legend)        // [Int: JevValue], preserving structured descriptions.
let displayedUrgency = try answer.scaled(to: 0...100)
```

Jev requires **2–10 ordered descriptive levels**, not a numeric `range` field. `scaled(to:)` is an explicit local linear conversion, not a different API question or a probability. Score results use `Double` so fractional information is never silently rounded. Every level should describe a concrete situation independently.

## Multiple questions in one request

```swift
let response = try await jev.evaluate(state: issueText, questions: [
    .noul(id: "is_bug", question: "Is this likely to be a bug?"),
    priority.question,
    urgency.question
])
```

Questions share the same state and are evaluated independently. One question's answer is not available to another question in that request. Combine the answers in your own deterministic policy.

## Strongly typed schemas without macros

Descriptors provide typed access without reflection, property-wrapper initialization traps, or a compiler plugin. A schema collects them into a result struct:

```swift
struct IssueAssessment: JevSchema {
    static let bug = Noul("Is this likely to be a bug?", id: "is_bug")
    static let priorityQuestion = Choice<Priority>("What priority?", id: "priority")
    static let urgencyQuestion = Score("How soon does this need attention?", id: "urgency", levels: [
        "Can wait", "Needs attention today", "Needs immediate response"
    ])
    static var questions: [JevQuestion] {
        [bug.question, priorityQuestion.question, urgencyQuestion.question]
    }

    let isBug: NoulResult
    let priority: ChoiceResult<Priority>
    let urgency: ScoreResult
    let metadata: JevMetadata

    init(response: JevResponse) throws {
        isBug = try response.answer(Self.bug)
        priority = try response.answer(Self.priorityQuestion)
        urgency = try response.answer(Self.urgencyQuestion)
        metadata = response.metadata
    }
}

let assessment = try await jev.evaluate(state: issueText, as: IssueAssessment.self)
print(assessment.isBug.probability)
print(assessment.priority.value)
```

A future optional macro can synthesize `questions` and the initializer without changing the base library's dependency-free contract. Macros are deliberately deferred from 0.1.0.

## Confidence-aware branching

```swift
switch assessment.priority.confidence {
case 0.95...:
    // Process automatically if your application's policy permits it.
case 0.75..<0.95:
    // Request confirmation.
default:
    // Route to a human or a reasoning model.
}

if let trusted = try assessment.priority.value(ifConfidenceAtLeast: 0.9) {
    print(trusted)
}
```

`isConfident(threshold:)` and `value(ifConfidenceAtLeast:)` reject NaN, infinity, and thresholds outside 0...1. Thresholds in these examples illustrate application policy; validate them on your own data and pin a model if your policy depends on calibrated behavior.

## Dynamic questions and structured state

```swift
var questions: [JevQuestion] = [priority.question]
if accountIsEnterprise {
    questions.append(.noul(
        id: "needs_account_manager",
        question: "Should this customer be escalated to their account manager?"
    ))
}
let response = try await jev.evaluate(state: issueText, questions: questions)
```

IDs use `JevQuestionID` and support string literals. Duplicate IDs fail before a request is sent. Dynamic text uses `.string(text)` and dynamic IDs use `JevQuestionID(rawValue: id)`.

To send an `Encodable` value, use `try JevValue(encoding: value)`:

```swift
struct Issue: Encodable {
    let title: String
    let body: String
    let labels: [String]
}
let issue = Issue(title: "Crash", body: "Fails at launch", labels: ["production"])
let response = try await jev.evaluate(state: JevValue(encoding: issue), questions: questions)
```

`JevValue` also supports explicit JSON objects/arrays for instructions and criteria. Root state must be nonempty text, an object, or an array. Non-finite numbers are rejected. Numbers use Double; represent exact large identifiers as strings.

## Configuration, retries, and cancellation

```swift
let configuration = JevConfiguration(
    apiKey: apiKey,
    timeout: .seconds(15),
    retryPolicy: .init(maximumRetries: 2)
)
let jev = try JevClient(configuration: configuration)
```

`baseURL` is the API **root**; JevKit appends `v1/systemone` and preserves a gateway path prefix. Use only trusted gateways. HTTPS is required except for localhost/loopback development. URLs with credentials, query strings, or fragments are rejected.

Defaults: `jev-latest`, 30-second request timeout, two additional attempts. Retryable statuses follow the official SDK: 408, 429, and 5xx, including 529. Only selected transient URL errors are retried. Authentication, validation, decoding, certificate failures, and cancellation are not retried. Exponential backoff has jitter; valid `Retry-After` seconds or HTTP dates take precedence. If the server asks for more than `maximumDelay`, the call returns its HTTP error instead of retrying early.

Retries may repeat billable evaluation; no documented idempotency key is invented. Set `maximumRetries: 0` to disable. Timeout is passed to the transport per request; URLSession treats it as an inactivity timeout, not a total evaluation deadline. Backoff adds time. Timing values are limited to one day and retries to ten.

```swift
let task = Task {
    try await jev.evaluate(state: issueText, questions: questions)
}
task.cancel() // Propagates to URLSession and interrupts retry waits.
```

The client normalizes URLSession cancellation to `CancellationError`. A client can be shared among concurrent tasks; each evaluation keeps its own request and response state.

## Error handling and observability

```swift
do {
    let response = try await jev.evaluate(state: issueText, questions: questions)
    print(response.metadata.model)
    print(response.metadata.latency) // Locally measured, including retries.
    print(response.metadata.usage.inputTokens as Any)
} catch is CancellationError {
    // Caller cancelled the operation.
} catch let error as JevError {
    switch error {
    case .authenticationFailed:
        // Fix credentials; do not retry blindly.
    case .rateLimited(let details):
        print(details.retryAfter as Any)
    case .invalidRequest(let reason):
        print(reason)
    default:
        print(error) // Safe default descriptions exclude server bodies.
    }
}
```

HTTP failures expose status, parsed retry delay, and a bounded credential-redacted `responseBody` for **explicit** inspection. Bodies can still contain sensitive application data: do not send them to general-purpose logs. Transport errors retain a URL error code, not arbitrary userInfo or URLs. Decode errors omit potentially sensitive server text.

Inject a `JevLogger` to receive start, HTTP response, retry, completion, decoding-failure, and failure events. Events contain local correlation UUIDs, counts, timing, and statuses; no state, questions, API keys, URLs, or response bodies. The logger is synchronous and `Sendable`; keep it fast and thread-safe. Metadata does not invent undocumented request-ID or usage fields.

## Testing and mocking

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import JevKit

struct FixtureTransport: JevTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { throw URLError(.badServerResponse) }
        let body = #"{"model":"fixture","answers":{"is_bug":{"type":"noul","noul":0.92}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        return (Data(body.utf8), response)
    }
}

let jev = try JevClient(
    configuration: .init(apiKey: "test-only"),
    transport: FixtureTransport()
)
```

Transport implementations must honor cancellation and request timeouts. The default `URLSessionTransport` uses an ephemeral, cache-free session and rejects redirects. Injecting your own URLSession transfers responsibility for redirects, cookies, and cache policy to you.

```sh
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
python3 Scripts/test-http.py  # Local HTTP tests: no key or external API call.
swift test --filter liveAllPrimitives # Skips automatically without JEV_API_KEY.
```

Swift 6 language mode enables complete concurrency checking. Tests cover wire encoding/decoding, distributions, validation, safe diagnostics, retries, cancellation, concurrent requests, typed schemas, and real URLSession behavior against a loopback fixture. Integration tests avoid asserting probabilistic correctness from a single live answer.

## API-key security

**Shipping a long-lived TypeSafe API secret inside a consumer iOS or macOS application can expose that credential.** App bundles, memory, and client-controlled network traffic are not secret stores. Production consumer apps should generally call their own authenticated backend, which holds the TypeSafe key and enforces usage policy. Check TypeSafe's current authentication guidance before choosing another architecture; the researched API documents bearer secrets, not an ephemeral client credential exchange.

Load server keys from a secret manager or environment, keep them out of source control, and rotate exposed keys. Redacted descriptions reduce accidental disclosure; they do not make an in-memory credential inaccessible to a debugger. Never log injected transport requests or full headers.

