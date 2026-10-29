#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Requires macOS with Xcode selected by xcode-select." >&2
  exit 1
fi
# Compile checks only. Real signing and playback tests are separate.
xcodebuild -project JoeToep.xcodeproj -scheme JoeToep \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath BuildChecks/iOS \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project JoeToep.xcodeproj -scheme JoeToep \
  -destination 'platform=macOS' -derivedDataPath BuildChecks/macOS \
  CODE_SIGNING_ALLOWED=NO build
