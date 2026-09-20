# Agent guidance

## Project

JevKit is an independent, dependency-free Swift client for TypeSafe’s Jev / System One API. Read [CONTRIBUTING.md](CONTRIBUTING.md) for development and release conventions and [API_NOTES.md](API_NOTES.md) for the wire contract.

- `Sources/JevKit/`: library code, organized by client, configuration, questions, results, schema, transport, and internal wire models.
- `Sources/JevKitExample/`: command-line example, compiled with the package.
- `Tests/JevKitTests/`: unit tests; `Tests/JevKitIntegrationTests/`: local HTTP and opt-in live tests.
- `Examples/ExampleApp/`: separate SwiftUI example app. See [Examples/README.md](Examples/README.md) for its newer Xcode and OS requirements.
- `Documentation/Usage.md` and `Sources/JevKit/JevKit.docc/`: usage and API documentation.

## Making changes

- Inspect the working tree first and preserve unrelated changes.
- Keep the library compatible with Swift 6.0, Swift 6 language mode, and the platform minimums in `Package.swift`, including Linux support through conditional `FoundationNetworking` imports.
- Keep the base library free of third-party dependencies. Preserve actor isolation and `Sendable` boundaries; do not suppress concurrency checks.
- Keep wire-format changes in `Sources/JevKit/Internal/`. Verify contract changes against current official documentation and record the sources in `API_NOTES.md`.
- Preserve full probability distributions and the distinction between probabilities, confidence, scores, and local application policy.
- Use injectable transports for deterministic tests. Follow the existing Swift Testing patterns and avoid shared mutable globals so tests remain parallel-safe.
- Update affected public API documentation and examples when behavior changes. Keep release procedures in `CONTRIBUTING.md` as the source of truth.

## Validation

Run commands from the repository root. For library changes, use the package checks below; include the HTTP fixture for transport changes and DocC for API documentation changes. Run the full set before proposing a release.

```sh
swift build -Xswiftc -warnings-as-errors
JEV_API_KEY= TYPESAFE_API_KEY= swift test -Xswiftc -warnings-as-errors
python3 Scripts/test-http.py
swift build -c release -Xswiftc -warnings-as-errors
bash Scripts/build-docs.sh
```

The HTTP fixture needs Python 3.9+ and binds to loopback; DocC needs a compatible toolchain and Python 3. For SwiftUI example changes, run `bash Examples/Checks/run.sh` on macOS, which builds the app and exercises test-only fixtures without API calls.

Live tests are opt-in and billable. Keep credentials empty for routine validation; only run `JEV_API_KEY`-enabled tests or live examples when the task authorizes live API usage. Never print or commit real keys or sensitive request/response data. The library defaults to `TYPESAFE_API_KEY`; the command-line example and live tests use `JEV_API_KEY`.

Report which checks actually ran and any limitations. Local fixtures and successful builds do not establish live API compatibility or runtime behavior on untested platforms.
