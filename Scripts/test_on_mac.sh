#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Requires macOS with Xcode and an Apple SDK." >&2
  exit 1
fi
JOETOEP_DESTINATION="${1:-platform=macOS}"
JOETOEP_RESULTS="TestResults/JoeToep-$(date -u +%Y%m%dT%H%M%SZ)-$$.xcresult"
mkdir -p TestResults
xcodebuild -project JoeToep.xcodeproj -scheme JoeToep \
  -destination "$JOETOEP_DESTINATION" -resultBundlePath "$JOETOEP_RESULTS" test
