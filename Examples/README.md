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

Each screen includes a selectable Swift usage snippet. `Examples.swift` contains descriptors and schema; `ExampleModel.swift` contains the actual evaluation calls and result handling; `ContentView.swift` renders the controls and distributions.

Open **Settings** in the sidebar to enter or edit your **API key**. The key applies to every example and window, is stored securely in Keychain, and is restored across launches. Clearing the field removes the saved key. Storage failures are shown in Settings. Changes take effect on the next run.

**Run example** evaluates the issue using the API. If the key is empty or contains only whitespace, the app shows an error with an **Open Settings** action without sending a request. There is no demo mode or alternate credential source in the app.

Requests support cancellation; leaving an example cancels its outstanding work. Results and thresholds are snapshots of the last run. Running an example sends the entered issue to TypeSafe and may incur charges. Retries are disabled and requests have a 20-second timeout.

Build without signing:

```sh
xcodebuild -project Examples/ExampleApp/ExampleApp.xcodeproj \
  -scheme ExampleApp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Run `bash Examples/Checks/run.sh` on macOS to build the app and exercise all four examples using test-only injected fixtures, cancellation, threshold policy, missing-key validation, and shared key editing without making API calls.
