# Issue triage

The executable source is [Sources/JevKitExample/main.swift](../Sources/JevKitExample/main.swift); it is compiled by every package build so the example cannot drift silently.

Set `JEV_API_KEY` through your environment or secret manager, then run:

```sh
swift run JevKitExample
```

With no key, the executable prints setup instructions and makes no request. With a key it sends one structured GitHub issue and five questions to TypeSafe (billable usage): probable bug, known duplicate, priority, urgency, and need for human review.

`IssueAssessment` handles question definitions and typed answer extraction. `route` alone implements deterministic application policy. It prints a route; it does not actually page an engineer or send messages. Add existing issue context to the state before relying on duplicate detection.

For a consumer iOS UI, call an authenticated backend that owns the API key and returns the policy outcome or appropriately scoped assessment. Do not embed the example's environment credential into an app bundle.

## SwiftUI example app

Open `Examples/ExampleApp/ExampleApp.xcodeproj`, select the **ExampleApp** scheme, choose **My Mac** or an iOS Simulator, and run. The project references JevKit from this checkout using a relative local package dependency. The app currently inherits the starter project's OS 27 deployment targets and requires Xcode 27.

The sidebar contains four runnable examples:

- **Noul:** bug probability, complementary no probability, and a configurable local yes threshold.
- **Choice:** a typed `Priority` enum, its full distribution, and a confidence gate.
- **Score:** a three-level urgency rubric, fractional score, distribution, and explicit 0–100 scaling.
- **Typed assessment:** structured `Encodable` issue state evaluated as a `JevSchema`, followed by deterministic incident-routing policy.

Each screen includes a selectable Swift usage snippet. `Examples.swift` contains descriptors, schema, and fixture transport; `ExampleModel.swift` contains the actual evaluation calls and result handling; `ContentView.swift` renders the controls and distributions.

**Run demo** works immediately without credentials or network access. It uses an injected transport and fixed responses that pass through JevKit's real decoding and validation. Editing the input does not change fixture results. Requests support cancellation; leaving an example cancels its outstanding work. Results and thresholds are snapshots of the last run.

For optional development-only live usage, enable **Use live API** and select an **API-key source**:

- **Direct key:** enter the key in the secure field. The app passes it directly to the configuration constructor and keeps it in memory for that screen only.
- **Environment:** defaults to `JEV_API_KEY`; enter `TYPESAFE_API_KEY` or any existing variable name instead. Set the variable in your **private** Xcode scheme under **Run → Arguments → Environment Variables**.
- **Info.plist:** add a String entry named `JEV_API_KEY` under the example app target's **Info → Custom Target Properties**.
- **JevSecrets.plist:** create this file in `Examples/ExampleApp/ExampleApp/` with a top-level `JEV_API_KEY` String entry. This exact path is gitignored. Include the file in the app resources; the synchronized Xcode folder handles new resources automatically.

See [credential initialization](../README.md#initialize-with-an-api-key) for constructor examples and plist format. Missing or invalid credentials produce an inline error before a request is sent. There is no automatic fallback between sources.

A live run sends the entered issue to TypeSafe and may incur charges. The example disables retries and uses a 20-second request timeout. The app does not write keys to disk. Do not commit credentials or distribute a credential-bearing scheme or app bundle. Plist credentials remain extractable; production consumer apps should use an authenticated backend that holds the API secret.

Build without signing:

```sh
xcodebuild -project Examples/ExampleApp/ExampleApp.xcodeproj \
  -scheme ExampleApp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Run `bash Examples/Checks/run.sh` on macOS to build the app and exercise all four offline examples, cancellation, and threshold policy without making API calls.
