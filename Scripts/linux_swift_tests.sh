#!/usr/bin/env bash
# V26: Swift-controle in een Linux-cloudsessie (zonder Mac/Xcode).
#
# Bouwt een tijdelijk SwiftPM-pakket met alle app-bestanden die alleen Foundation gebruiken
# (modellen, sync, opslag, V26-logica) en draait de unit tests die alleen die bestanden nodig hebben.
# SwiftUI/AppKit/UIKit/WebKit bestaan niet op Linux; die code blijft alleen via Xcode te bouwen.
#
# Gebruik:  Scripts/linux_swift_tests.sh            (swift lokaal, of via Docker-image swift:6.1)
#           SWIFT_IMAGE=mirror.gcr.io/library/swift:6.1-noble Scripts/linux_swift_tests.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$(mktemp -d)}"
IMAGE="${SWIFT_IMAGE:-mirror.gcr.io/library/swift:6.1-noble}"

rm -rf "$WORK/pkg"; mkdir -p "$WORK/pkg/Sources/JoeToep" "$WORK/pkg/Tests/JoeToepTests"
# Bronbestanden die zonder SwiftUI/AppKit/UIKit/WebKit compileren (lijst bijhouden).
for source in Models/AdBlockLevel.swift Models/ExperimentalFilterParser.swift \
              Models/ForegroundReturnGate.swift Models/MultiMonitorPiPPolicy.swift \
              Models/PiPStateMachine.swift Models/PlaybackQualityPreference.swift Models/SessionNotice.swift \
              Models/SponsorBlockSettings.swift Models/StartPage.swift Models/TabSessionStore.swift \
              Models/V17Options.swift Models/YouTubeFeedParser.swift Support/AppConstants.swift \
              Support/SigningInfo.swift Support/WebBridgeEvent.swift Support/WindowOpener.swift \
              Models/BrowserSpaces.swift Models/SplitLayout.swift Models/SiteBoosts.swift Models/PageDigest.swift Models/V26Prefs.swift; do
  [ -f "$ROOT/JoeToep/$source" ] && cp "$ROOT/JoeToep/$source" "$WORK/pkg/Sources/JoeToep/"
done
# Tests die alleen deze bestanden gebruiken (lijst bijhouden bij nieuwe pure tests).
for test in ForegroundReturnGateTests PiPStateMachineTests \
            ExperimentalFilterParserTests WebBridgeEventTests LinuxV26Tests; do
  [ -f "$ROOT/JoeToepTests/$test.swift" ] && cp "$ROOT/JoeToepTests/$test.swift" "$WORK/pkg/Tests/JoeToepTests/"
done
cat > "$WORK/pkg/Package.swift" <<'PKG'
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "JoeToepLinux",
    targets: [
        .target(name: "JoeToep", path: "Sources/JoeToep", swiftSettings: [.unsafeFlags(["-swift-version", "5"])]),
        .testTarget(name: "JoeToepTests", dependencies: ["JoeToep"], path: "Tests/JoeToepTests",
                    swiftSettings: [.unsafeFlags(["-swift-version", "5"])]),
    ]
)
PKG
if command -v swift >/dev/null 2>&1; then
  (cd "$WORK/pkg" && swift test 2>&1)
else
  docker run --rm -v "$WORK/pkg:/pkg" -w /pkg "$IMAGE" swift test 2>&1
fi
