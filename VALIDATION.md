# Validation evidence

Local validation completed 2026-09-20 on macOS arm64 with Apple Swift 6.4, compiling in Swift 6 language mode. This is local evidence, not a hosted CI or live API certification.

| Check | Result |
| --- | --- |
| `swift build` | Passed |
| `swift build -c release -Xswiftc -warnings-as-errors` | Passed |
| `swift test -Xswiftc -warnings-as-errors` | 42 unit test functions passed, including parameterized cases |
| `python3 Scripts/test-http.py` | 4 real URLSession integration tests passed against a loopback fixture |
| iOS library cross-compilation, arm64 / iOS 16 minimum | Passed with warnings treated as errors |
| `bash Scripts/build-docs.sh` | DocC archive generated with warnings treated as errors |
| Public symbol graph documentation check | No undocumented declared public symbols |
| Example CLI without JEV_API_KEY | Printed setup instructions; no API request |
| `git diff --check` | Passed |

The local HTTP tests cover request/response handling, redirect rejection, timeout, and cancellation after the server has received the request. Unit tests cover retries independently with injected transport and time, including Retry-After, exhaustion, non-retryable errors, cancellation during backoff, concurrent evaluations, validation, structured inputs, typed schemas, and redaction.

## Not yet verified

- Authenticated TypeSafe contract: `liveAllPrimitives` was automatically skipped because JEV_API_KEY was absent.
- Linux runtime and Swift 6.0.3 / 6.2.3 toolchains: configured in GitHub Actions, not executed on this macOS host.
- Hosted CI: no Git remote is configured in this checkout.
- Physical Apple devices: library cross-compilation is not a runtime device test.
- Public release: VERSION is 0.1.0; no Git tag or release was published.

Cross-compilation command:

```sh
swift build --target JevKit --triple arm64-apple-ios16.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  --scratch-path .build/ios -Xswiftc -warnings-as-errors
```
