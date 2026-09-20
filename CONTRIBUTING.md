# Contributing

Use Swift 6.0 or newer. Keep the base library dependency-free and all state crossing concurrency boundaries Sendable. Do not suppress concurrency checks. Keep wire-format changes in `Internal` and cite current official documentation in `API_NOTES.md` before changing the API contract.

Run:

```sh
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
python3 Scripts/test-http.py
bash Scripts/build-docs.sh
```

The local HTTP fixture requires Python 3.9+ and binds only to loopback on an ephemeral port. It clears JEV_API_KEY for its child process. Tests run independently and in parallel without shared mutable Swift globals. Test fixtures are documentation-derived examples, not captured customer data.

Live verification is opt-in: set `JEV_API_KEY` in your environment and run `swift test --filter liveAllPrimitives`. This makes a billable request. Do not print or commit the key, and do not use live credentials in pull-request CI. Without the variable the test is disabled by a Swift Testing trait.

## Release 0.1.0

1. Run the checks above on macOS and Linux and confirm the hosted CI results.
2. With authorized early-access credentials, run the live contract test and review probability semantics.
3. Verify the README's installation URL against the actual public repository.
4. Update the changelog release date, commit the release, and create/push the `0.1.0` Git tag.

`VERSION` records intended package version; SwiftPM resolves published versions from Git tags. Building the package does not publish or tag it.
