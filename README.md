# JevKit

[![Latest release](https://img.shields.io/github/v/release/michaelhitzker/JevKit)](https://github.com/michaelhitzker/JevKit/releases/latest)
[![CI](https://github.com/michaelhitzker/JevKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/michaelhitzker/JevKit/actions/workflows/ci.yml?query=branch%3Amain)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-orange)](Package.swift)
[![MIT License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

A lightweight, strongly typed Swift client for TypeSafe’s Jev / System One API. Ask yes/no questions, choose between enum cases, or score an input against a rubric—then use ordinary Swift to decide what happens next.

JevKit preserves the full probability distribution alongside each result. It uses `async/await`, supports Swift 6 strict concurrency, and has no third-party dependencies.

**Independent community SDK.** JevKit is not an official TypeSafe product.

[Installation](#installation) · [Quick start](#quick-start) · [Usage guide](Documentation/Usage.md) · [Examples](Examples/README.md) · [Contributing](CONTRIBUTING.md)

## Features

- **Typed questions:** `Noul` for yes/no probabilities, `Choice<YourEnum>` for discrete options, and `Score` for ordered rubrics.
- **Batch evaluation:** ask multiple independent questions about the same text or structured JSON input.
- **Typed assessments:** collect answers into your own `JevSchema` without macros or reflection.
- **Async networking:** a shareable actor client, cancellation, configurable timeouts, and bounded retries.
- **Testable integration:** injectable transports and privacy-conscious logging.

## Requirements

Swift **6.0 or later**. For Apple development, use Xcode **16 or later** with a compatible Swift toolchain.

| Platform | Minimum version |
| --- | --- |
| macOS | 13 |
| iOS / iPadOS | 16 |
| tvOS | 16 |
| watchOS | 9 |
| visionOS | 1 |
| Linux | Swift 6.0+ with FoundationNetworking |

The package includes CI configuration for macOS and Ubuntu. The bundled SwiftUI example app has separate, newer requirements; see [Examples](Examples/README.md#swiftui-example-app).

## Installation

JevKit uses Swift Package Manager. Add the **JevKit** library product to the target that imports it.

### Xcode

1. Choose **File → Add Package Dependencies…**.
2. Enter `https://github.com/michaelhitzker/JevKit.git`.
3. Select **Up to Next Major Version**, enter `0.1.0`, then choose **Add Package**.
4. Add the **JevKit** product to your app target.

For a local checkout, choose **Add Local…** and select the `JevKit` directory instead.

### Package.swift

Add the repository to `dependencies` and the library product to your target:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13), .iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/michaelhitzker/JevKit.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [.product(name: "JevKit", package: "JevKit")]
        )
    ]
)
```

The latest published version is available on the [releases page](https://github.com/michaelhitzker/JevKit/releases/latest). Commit your application’s `Package.resolved` to retain the resolved version. To follow unreleased development, replace `from: "0.1.0"` with `branch: "main"`; branch updates can include breaking changes.

To use a sibling checkout immediately, replace the `.package(url:from:)` entry with:

```swift
.package(path: "../JevKit")
```

## Quick start

Provide a TypeSafe API key through the `TYPESAFE_API_KEY` environment variable, then call the client from an asynchronous context:

```swift
import JevKit

enum Priority: String, CaseIterable, JevChoice {
    case low, medium, high, critical
}

let client = try JevClient() // Reads TYPESAFE_API_KEY.
let priority = Choice<Priority>(
    "What priority should this issue have?",
    id: "priority"
)

let response = try await client.evaluate(
    state: "Every production user sees a crash after upgrading to version 4.2.",
    questions: [priority.question]
)
let answer = try response.answer(priority)

print(answer.value)
print(answer.confidence)
print(answer.probabilities) // Includes every Priority case.

if answer.value == .critical && answer.confidence > 0.95 {
    // Apply your application's escalation policy.
}
```

You can also pass a key directly with `try JevClient(apiKey: apiKey)` or select a custom environment variable with `try JevClient(apiKeySource: .environment("JEV_API_KEY"))`. Credential sources are read once when the client is initialized; `.env` files are not loaded automatically.

API requests require access to TypeSafe and may incur usage charges. Keep production consumer-app credentials on your backend, and never commit real keys. See [credential configuration](Documentation/Usage.md#initialize-with-an-api-key) for environment and plist options.

## Question types

### Noul: yes/no probability

```swift
let bug = Noul("Does this describe a software bug?", id: "is_bug")
let response = try await client.evaluate(
    state: "The app crashes at startup.",
    questions: [bug.question]
)
let answer = try response.answer(bug)

print(answer.probability)    // Probability of yes.
print(answer.noProbability) // Complementary probability of no.
let shouldLabel = try answer.value(threshold: 0.9)
```

Noul returns a probability, not a separate confidence value. A probability near zero means a strong no. The default Boolean `value` uses a local threshold of 0.5.

### Choice: enum values and distributions

The quick start uses `Choice<Priority>` to return a Swift enum and a probability for every case. Implement `jevDescription` on your enum to supply a richer rubric for each option.

Choice confidence is a server-provided statistic; it is not necessarily the probability of the selected option. Keep both when making decisions.

### Score: an ordered rubric

```swift
let urgency = Score("How soon does this need attention?", id: "urgency", levels: [
    "Can wait for normal backlog grooming",
    "Needs attention in the next business day",
    "Requires immediate incident response"
])
let response = try await client.evaluate(
    state: "Production users cannot launch the app.",
    questions: [urgency.question]
)
let answer = try response.answer(urgency)

print(answer.value)         // Fractional position on the 0...2 rubric.
print(answer.probabilities) // Probability for each level.
let displayedUrgency = try answer.scaled(to: 0...100)
```

Scores require 2–10 descriptive levels. Scaling is a local display conversion; it does not turn the score into a probability.

Combine descriptors in one call with `questions: [bug.question, priority.question, urgency.question]`. Questions share the input but are evaluated independently. For structured inputs, schemas, dynamic questions, and confidence gates, see the [usage guide](Documentation/Usage.md).

## Configuration and errors

```swift
let configuration = try JevConfiguration(
    apiKeySource: .environment(),
    timeout: .seconds(15),
    retryPolicy: .init(maximumRetries: 0)
)
let client = try JevClient(configuration: configuration)
```

By default, JevKit uses `jev-latest`, a 30-second request timeout, and up to two retries for eligible transient failures. Retries can repeat billable evaluations. The timeout applies per request, rather than to the entire evaluation including backoff.

Calls throw `JevError` for configuration, validation, HTTP, transport, and decoding failures. Cancellation throws `CancellationError`. Response metadata exposes the model, usage, attempt count, and locally measured latency. See [error handling](Documentation/Usage.md#error-handling-and-observability) and [retry behavior](Documentation/Usage.md#configuration-retries-and-cancellation) for details.

## Examples

**Command-line issue triage:** from the repository root, set `JEV_API_KEY` in your environment and run:

```sh
swift run JevKitExample
```

The executable uses `JEV_API_KEY`, while the default library initializer uses `TYPESAFE_API_KEY`. Without a key, the executable prints setup instructions and makes no request.

**SwiftUI app:** open [ExampleApp.xcodeproj](Examples/ExampleApp/ExampleApp.xcodeproj), choose the **ExampleApp** scheme, and run on **My Mac** or an iOS Simulator. The app currently requires Xcode 27 and OS 27 deployment targets. Enter your API key in the app’s **Settings**; it is stored in Keychain. The app runs live requests, with fixtures available separately through its test script.

See [example setup and checks](Examples/README.md) for details.

## Documentation

- [Usage guide](Documentation/Usage.md): credentials, typed schemas, structured state, retries, errors, logging, and mocking.
- [API notes](API_NOTES.md): wire contract, sources, and service limitations.
- [Changelog](CHANGELOG.md): package changes.
- [DocC overview](Sources/JevKit/JevKit.docc/JevKit.md): library documentation.

To generate the API documentation locally with a DocC-capable Swift toolchain and Python 3:

```sh
bash Scripts/build-docs.sh
```

The archive is written to `.build/JevKit.doccarchive`.

## Contributing

Bug reports, documentation improvements, and pull requests are welcome. [Open an issue](https://github.com/michaelhitzker/JevKit/issues) or [submit a pull request](https://github.com/michaelhitzker/JevKit/pulls). Include a minimal reproduction, your Swift version, and platform when reporting a problem. Remove API keys and sensitive input or response data before sharing logs.

From a local checkout, run:

```sh
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
python3 Scripts/test-http.py
```

The HTTP fixture requires Python 3.9+ and runs against loopback. Leave `JEV_API_KEY` unset for offline testing; setting it enables the billable live contract test. See [CONTRIBUTING.md](CONTRIBUTING.md) for development conventions and release checks.

## License

JevKit is available under the [MIT License](LICENSE).
