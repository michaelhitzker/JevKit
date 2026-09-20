# Changelog

## 0.1.0 — initial implementation (unreleased)

- Dependency-free Swift 6 library with strict concurrency and FoundationNetworking support.
- Noul, Choice, and Score runtime questions, structured state/instructions/criteria, complete probability distributions.
- Immutable typed descriptors and explicit `JevSchema` assessments.
- Actor client, injectable transport, validation, bounded retries, Retry-After, cancellation, and safe observability.
- Credential-redacted diagnostics and redirect-rejecting default transport.
- Explicit credential loading from named environment variables, Info.plist, and local XML or binary plist files, alongside direct API-key initialization.
- SwiftUI example app with offline fixtures, selectable live credential sources, and runnable Noul, Choice, Score, and typed assessment examples.
- Swift Testing unit tests, opt-in live contract test, and local URLSession integration tests.
- Issue-triage CLI, DocC catalog, and macOS/Linux CI.

### 0.2.0 candidates

- An optional schema macro target, generating the existing protocol rather than changing the base library.
- Model discovery through the documented models endpoint.
- Additional authenticated contract fixtures once early-access credentials are available.
- API evolution based on real usage; no speculative streaming, batching, or authentication endpoints.
