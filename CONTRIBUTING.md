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

## Pull-request checks

Every pull request runs the package build, unit tests, local HTTP integration tests,
and release build on macOS 14 and Ubuntu 24.04 with Swift 6.0.3 and 6.2.1.
macOS jobs also build DocC. Live API credentials are explicitly empty in CI.
The same checks run on pushes to `main`, merge queues, and before publication.

Use **All checks passed** as the required status check in a GitHub branch ruleset.
It succeeds only when every matrix job succeeds, including documentation builds.
Workflow files alone do not enforce branch protection.

## Publish a version

Swift Package Manager installs releases directly from Git tags; no package-registry
credentials or separate package upload are needed.

1. Prepare a pull request updating `VERSION` to the desired stable `major.minor.patch`
   version, and add a matching `##` heading in `CHANGELOG.md` with the release date.
   Remove `unreleased` from that heading. Update README installation examples as needed.
2. Merge the pull request after CI passes.
3. Open **Actions → Publish version → Run workflow** on GitHub, select **main**, and
   enter the exact version (for example, `0.1.0`, without a `v` prefix).
4. The workflow validates the metadata and reruns the full CI matrix. Only after
   success does it create the version tag at the tested commit and publish a GitHub
   release with generated release notes.

The workflow uses GitHub's built-in token with write access limited to the publish
job. No personal access token or TypeSafe API key is required. It rejects runs from
other branches, malformed versions, mismatched metadata, and existing tags.

If publication fails after creating the tag, inspect the run and the tag's commit,
then finish the GitHub release from that existing tag. Do not move a published tag.
Live API contract verification remains a separate, opt-in check requiring authorized
credentials; it is not performed by the release workflow.
