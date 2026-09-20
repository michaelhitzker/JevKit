# Jev API compatibility notes

Researched **2026-09-19**, TypeSafe HTTP **v1**, current documented model `jev-1.13.0`. JevKit release baseline: **0.1.0**. No authenticated live call was made during research.

## Official sources

- https://docs.typesafe.ai/api — HTTP request, response, authentication, errors
- https://docs.typesafe.ai/models — model IDs, aliases, limits, Retry-After
- https://docs.typesafe.ai/primitives/noul — probability semantics; no confidence
- https://docs.typesafe.ai/primitives/choice — full distribution, 255 options
- https://docs.typesafe.ai/primitives/score — 2–10 ordered levels, fractional index, legend
- https://docs.typesafe.ai/primitives/advanced — structured instructions and criteria
- https://docs.typesafe.ai/concepts/state — text, object, array state
- https://docs.typesafe.ai/confidence — confidence differs from winning probability
- https://docs.typesafe.ai/sdk/python/api/retries — SDK retries 408, 429, 5xx; two retries
- https://docs.typesafe.ai/introduction/quickstart — console and credential setup

## Wire contract

POST `https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <key>`, JSON.
Request: `state` (string/object/array), `model` (string), `questions` (ID-keyed object).
Questions have `type`, `instructions`, and optional/required `criteria`. Noul criteria optionally describe `true`/`false`; Choice criteria map option names to descriptions/null; Score criteria are ordered level descriptions. No `range`, `question`, `options`, messages, or chat-completions fields are sent.
Response: `model`, `answers` keyed by question ID, `usage` with `input_tokens` and `output_tokens`. Answers carry `type`; Noul has `noul`; Choice has `choice`, `confidence`, `probabilities`; Score has `score`, `confidence`, `probabilities`, `legend`.

## Semantics and explicit local policy

- Noul's Boolean uses `probability >= 0.5` (including the tie). Applications can use an explicit validated threshold. `noProbability` is locally derived as 1 − p, not another server field. There is no invented Noul confidence.
- Choice confidence is preserved verbatim, never substituted with the winner's probability.
- Score is a Double on 0...(levelCount − 1), with integer-keyed distribution and legend. `scaled(to:)` is explicit local linear conversion to a finite increasing range; no numeric-only rubric is manufactured.
- All questions share state and are evaluated independently. Schema construction and policy run locally.
- `jev-latest` defaults to the official stable alias; users can pin `jev-1.13.0` or supply future IDs without an SDK update.
- Validation rejects empty state/instructions/IDs, non-finite JSON numbers, fewer than two or more than 255 choices, and rubric sizes outside 2–10. Empty object/array rejection and the two-choice minimum are deliberate SDK guardrails. Token limits are left to the server because no official Swift tokenizer is available.
- Probability values must be finite and in [0,1]. Distribution sums tolerate 0.001 rounding error. Missing/extra answers, option keys, and level keys are rejected. Scores are range-checked, but not recomputed or equality-checked against the mean: the HTTP example reports 1.6 with a distribution whose mean is 1.60; future rounding may vary.
- Default retries follow the official SDK statuses (408, 429, all 5xx including 529) and a narrow set of transient URL errors. Retrying POST may incur duplicate computation/billing; no idempotency key is documented. Set maximumRetries to zero to disable.
- Retry-After delta seconds and HTTP dates are supported. A delay above the configured maximum causes the original HTTP error to be returned, rather than retrying before the server permits. Timeout is passed to the transport per request (URLSession treats it as an inactivity timeout), not an overall operation deadline. Timeout and maximum retry delay are limited to one day; retries are limited to ten.

## Incomplete or inconsistent documentation

- The HTTP reference narrows criteria/legend descriptions to strings, while the primitive and advanced pages explicitly support JSON objects/arrays. JevKit preserves these with `JevValue` and also accepts string legends.
- Models documentation says response model is a versioned ID, but examples return an alias. JevKit preserves the supplied string without resolving it.
- Error body schema and request-ID response headers are not specified. Errors retain a bounded, credential-redacted response body for explicit inspection; no guessed requestID or vendor latency field is exposed. Metadata includes server model/usage and locally measured latency/attempt count.
- No API version header, streaming, batch job, client-side credential exchange, or guaranteed idempotency contract is documented. These are not invented.

## Evolution boundary and scope

Wire DTOs live under Internal; public questions/results and schemas do not depend on DTOs. Early-access changes are most likely in criteria/legend shapes, limits, model aliases, error bodies, and retry conventions. Rejecting malformed distributions is intentional and may require adaptation if the contract changes.

0.1.0 includes all three primitives, structured JSON inputs, transport injection, retries/cancellation, runtime questions, typed descriptors/schemas, documentation, tests and CLI. Macros/property wrappers are deferred: wrappers alone cannot synthesize schema discovery and decoding safely, whereas explicit immutable descriptors avoid reflection and uninitialized wrapped results. A 0.2.0 macro target can generate the same schema protocol once the surface stabilizes. Model discovery and live contract fixtures are also candidates for 0.2.0.
