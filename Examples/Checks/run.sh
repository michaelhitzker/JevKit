#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/jev-example-check.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
xcodebuild -quiet -project "$repo_root/Examples/ExampleApp/ExampleApp.xcodeproj" \
  -scheme ExampleApp -destination 'platform=macOS' -derivedDataPath "$build_dir" \
  CODE_SIGNING_ALLOWED=NO build
swiftc -parse-as-library -swift-version 6 -I "$build_dir/Build/Products/Debug" \
  "$repo_root/Examples/ExampleApp/ExampleApp/Examples.swift" \
  "$repo_root/Examples/ExampleApp/ExampleApp/APIKeyStore.swift" \
  "$repo_root/Examples/ExampleApp/ExampleApp/ExampleModel.swift" \
  "$repo_root/Examples/Checks/FixtureTransport.swift" \
  "$repo_root/Examples/Checks/Smoke.swift" \
  "$build_dir/Build/Products/Debug/JevKit.o" -o "$build_dir/smoke"
"$build_dir/smoke"
