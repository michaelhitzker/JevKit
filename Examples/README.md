# Issue triage

The executable source is [Sources/JevKitExample/main.swift](../Sources/JevKitExample/main.swift); it is compiled by every package build so the example cannot drift silently.

Set `JEV_API_KEY` through your environment or secret manager, then run:

```sh
swift run JevKitExample
```

With no key, the executable prints setup instructions and makes no request. With a key it sends one structured GitHub issue and five questions to TypeSafe (billable usage): probable bug, known duplicate, priority, urgency, and need for human review.

`IssueAssessment` handles question definitions and typed answer extraction. `route` alone implements deterministic application policy. It prints a route; it does not actually page an engineer or send messages. Add existing issue context to the state before relying on duplicate detection.

For a consumer iOS UI, call an authenticated backend that owns the API key and returns the policy outcome or appropriately scoped assessment. Do not embed the example's environment credential into an app bundle.
