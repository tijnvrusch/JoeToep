#!/usr/bin/env python3
from __future__ import annotations

import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# V26: de huidige versie staat op één plek. Ophogen = deze twee waarden, project.pbxproj (alle targets),
# JoeToep/Support/AppConstants.swift en een nieuw bovenste kopje in CHANGELOG.md.
EXPECTED_VERSION = "26.0.0"
EXPECTED_BUILD = 39


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_plist(path: Path) -> dict:
    with path.open("rb") as stream:
        return plistlib.load(stream)


def check_required_files() -> None:
    required = [
        "JoeToep.xcodeproj/project.pbxproj",
        "JoeToep/JoeToepApp.swift",
        "JoeToep/Browser/WebSession.swift",
        "JoeToep/Resources/playerBridge.js",
        "JoeToep/Info.plist",
        "JoeToep/PrivacyInfo.xcprivacy",
        "Docs/RUNBOOK.md",
        "Docs/SNELSTART_NL.md",
        "Docs/TEST_PLAN.md",
        "JoeToepTests/NavigationPolicyTests.swift",
        "JoeToepUITests/JoeToepUITests.swift",
    ]
    for relative in required:
        require((ROOT / relative).is_file(), f"Missing required file: {relative}")


def check_plists() -> None:
    info = load_plist(ROOT / "JoeToep/Info.plist")
    require("audio" in info.get("UIBackgroundModes", []), "Background audio mode is missing")
    phone_orientations = set(info.get("UISupportedInterfaceOrientations", []))
    require("UIInterfaceOrientationPortrait" in phone_orientations, "Phone portrait support is missing")
    require("UIInterfaceOrientationLandscapeLeft" in phone_orientations, "Phone landscape support is missing")
    require(info.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads") is False,
            "Arbitrary network loads must remain disabled")

    privacy = load_plist(ROOT / "JoeToep/PrivacyInfo.xcprivacy")
    require(privacy.get("NSPrivacyTracking") is False, "Privacy manifest must disable tracking")
    require(privacy.get("NSPrivacyCollectedDataTypes") == [], "App must not declare collected data")


def check_assets() -> None:
    asset_root = ROOT / "JoeToep/Assets.xcassets"
    for json_path in asset_root.rglob("Contents.json"):
        with json_path.open(encoding="utf-8") as stream:
            json.load(stream)

    app_icon = asset_root / "AppIcon.appiconset"
    with (app_icon / "Contents.json").open(encoding="utf-8") as stream:
        contents = json.load(stream)
    filenames = {item.get("filename") for item in contents["images"] if item.get("filename")}
    for filename in filenames:
        require((app_icon / filename).is_file(), f"Missing app icon bitmap: {filename}")


def check_sources() -> None:
    swift_files = sorted((ROOT / "JoeToep").rglob("*.swift"))
    require(len(swift_files) >= 15, "Unexpectedly small Swift source set")
    forbidden = {
        "fatalError(": "fatal error",
        "try!": "forced try",
        " as! ": "forced cast",
        "googlevideo.com": "direct media endpoint",
        "yt-dlp": "stream extractor",
        "Timer.scheduledTimer": "polling timer",
    }
    for source_path in swift_files:
        text = source_path.read_text(encoding="utf-8")
        require(text.count("{") == text.count("}"), f"Unbalanced braces in {source_path.relative_to(ROOT)}")
        require(text.count("(") == text.count(")"), f"Unbalanced parentheses in {source_path.relative_to(ROOT)}")
        require(text.count("[") == text.count("]"), f"Unbalanced brackets in {source_path.relative_to(ROOT)}")
        if_count = len(re.findall(r"^\s*#if\b", text, flags=re.MULTILINE))
        endif_count = len(re.findall(r"^\s*#endif\b", text, flags=re.MULTILINE))
        require(if_count == endif_count, f"Unbalanced conditional compilation in {source_path.relative_to(ROOT)}")
        require("TODO" not in text and "FIXME" not in text, f"Unresolved marker in {source_path.relative_to(ROOT)}")
        for token, label in forbidden.items():
            require(token not in text, f"Forbidden {label} in {source_path.relative_to(ROOT)}")

    bridge = (ROOT / "JoeToep/Resources/playerBridge.js").read_text(encoding="utf-8")
    for token in ["fetch(", "XMLHttpRequest", ".remove()", "display = 'none'", "display:none"]:
        require(token not in bridge, f"Playback bridge must not rewrite requests or remove DOM nodes; found {token}")


def check_project_file() -> None:
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    required_tokens = [
        "PBXProject",
        "PBXNativeTarget",
        "PBXFileSystemSynchronizedRootGroup",
        "JoeToepTests",
        "JoeToepUITests",
        "IPHONEOS_DEPLOYMENT_TARGET = 17.0",
        "MACOSX_DEPLOYMENT_TARGET = 14.0",
        "JoeToep/Info.plist",
        "com.apple.product-type.application",
    ]
    for token in required_tokens:
        require(token in project, f"Project file missing: {token}")

    require(project.count("{") == project.count("}"), "Unbalanced project-file braces")
    # Test bundles keep their registered IDs: a free Apple team may create only 10 App IDs per week.
    require(re.search(r"PRODUCT_BUNDLE_IDENTIFIER = nl\.tijn\.haloplayer\.(ui)?tests", project) is not None,
            "Expected test bundle identifier is missing")


def check_setting_help():
    import collections, re as _re
    text = (ROOT / "JoeToep/Views/SettingHelp.swift").read_text()
    body = text[text.index("static let texts"):]
    body = body[:body.index("    ]")]
    keys = _re.findall(r'^\s*"([^"]+)":', body, _re.M)
    dup = [k for k, c in collections.Counter(keys).items() if c > 1]
    require(not dup, "SettingHelp duplicate keys: " + ", ".join(dup))

def check_version() -> None:
    """V26: versie en build zijn overal gelijk (alle targets, AppConstants, CHANGELOG)."""
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    marketing = set(re.findall(r"MARKETING_VERSION = ([0-9.]+);", project))
    builds = set(re.findall(r"CURRENT_PROJECT_VERSION = ([0-9]+);", project))
    require(marketing == {EXPECTED_VERSION}, f"MARKETING_VERSION differs from {EXPECTED_VERSION}: {sorted(marketing)}")
    require(builds == {str(EXPECTED_BUILD)}, f"CURRENT_PROJECT_VERSION differs from {EXPECTED_BUILD}: {sorted(builds)}")
    require(project.count(f"MARKETING_VERSION = {EXPECTED_VERSION};") >= 8, "Not every build configuration carries the version")
    constants = (ROOT / "JoeToep/Support/AppConstants.swift").read_text()
    require(f'static let version = "{EXPECTED_VERSION}"' in constants, "AppConstants.version out of date")
    changelog = (ROOT / "CHANGELOG.md").read_text()
    first = next(line for line in changelog.splitlines() if line.startswith("# "))
    require(first.strip() == f"# {EXPECTED_VERSION} ({EXPECTED_BUILD})", f"CHANGELOG top heading is {first!r}")


def main() -> int:
    checks = [check_version, check_v26, check_required_files, check_plists, check_assets, check_sources, check_project_file, check_v2, check_v3, check_v4, check_v5, check_v6, check_v7, check_setting_help, check_v21, check_v22]
    for check in checks:
        check()
        print(f"PASS {check.__name__}")
    print(f"PASS project validation ({len(checks)} gates)")
    return 0


def check_v2() -> None:
    for file in ["JoeToep/Models/PiPStateMachine.swift", "JoeToep/Resources/qualityBridge.js",
                 "JoeToep/Support/MacFloatingPlayerController.swift", "JoeToep/Resources/fixture.mp4",
                 "JoeToep/Support/ContentFilterController.swift", "JoeToep/Resources/contentFilters.json"]:
        require((ROOT / file).is_file(), "Missing V2 resource: " + file)
    filters = json.loads((ROOT / "JoeToep/Resources/contentFilters.json").read_text())
    require(set(filters) == {"ads", "shorts", "posts", "premium"}, "Missing filter group")
    for rules in filters.values():
        require(bool(rules), "Empty filter group")
        for rule in rules:
            require("if-domain" in rule["trigger"], "Unscoped content filter")
            require(rule["action"]["type"] in {"block", "css-display-none"}, "Unexpected filtering action")
    entitlements = load_plist(ROOT / "JoeToep/JoeToep.macOS.entitlements")
    require(entitlements.get("com.apple.security.app-sandbox") is True, "Mac sandbox disabled")
    require(entitlements.get("com.apple.security.temporary-exception.mach-lookup.global-name") == ["com.apple.PIPAgent"],
            "Mac PiP entitlement missing or broadened")
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    definitions = re.findall(r"^\t\t([A-F0-9]{24})\s*(?:/\*.*?\*/\s*)?=\s*\{", project, re.M)
    require(len(definitions) == len(set(definitions)), "Duplicate Xcode object id")
    require(set(re.findall(r"\b[A-F0-9]{24}\b", project)) <= set(definitions), "Dangling Xcode object reference")
    scheme = ET.parse(ROOT / "JoeToep.xcodeproj/xcshareddata/xcschemes/JoeToep.xcscheme")
    require({item.get("BlueprintName") for item in scheme.findall(".//TestableReference/BuildableReference")}
            == {"JoeToepTests", "JoeToepUITests"}, "Scheme omits a test target")
    for file in (ROOT / "JoeToep/Assets.xcassets/AppIcon.appiconset").glob("*.png"):
        with Image.open(file) as icon:
            size = int(file.stem.split("-")[-1])
            # iOS: opaque. macOS (V15): transparent margin around the rounded-rectangle icon body.
            expected = "RGB" if "iOS" in file.stem else "RGBA"
            require(icon.size == (size, size) and icon.mode == expected, "Invalid icon dimensions/alpha")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require(session.count("JoeToepWebView(frame:") == 1 and session.count(" WKWebView(frame:") == 1 and
            "authenticationWebView = popup" in session, "Expected one player and a separate sign-in popup")
    require(("forMainFrameOnly: true" in session or "forMainFrameOnly: !allFrames" in session) and "WKContentWorld.world" in session, "Bridge isolation missing")
    bridge = (ROOT / "JoeToep/Resources/playerBridge.js").read_text()
    for token in ["setInterval(", "setTimeout(", ".pause()", ".play()"]:
        require(token not in bridge, "Bridge forces playback or has polling: " + token)
    shell = (ROOT / "JoeToep/Views/PlayerShellView.swift").read_text()
    require("Task.sleep(for: .seconds(5))" in shell, "Notice expiry missing")
    require("frame(width: geometry.size.width, height: geometry.size.height)" in shell, "Width bound missing")


def check_v3() -> None:
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    require(project.count('SWIFT_OBJC_BRIDGING_HEADER = "JoeToep/Support/JoeToep-Bridging-Header.h";') == 2,
            "Objective-C bridge missing from an app build configuration")
    native = (ROOT / "JoeToep/Support/JoeToepMediaCompatibility.m").read_text()
    require("respondsToSelector" in native and "_setAllowsPictureInPictureMediaPlayback:YES" in native,
            "Mac native PiP configuration missing")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require('world: .page, time: .atDocumentStart' in session, "Compatibility script must precede website scripts")
    require('JTStartNativePiP(self.webView)' in session, "Native Mac route not connected")
    require('endBackgroundTask(identifier)' in session, "Background assertion not balanced")
    media = (ROOT / "JoeToep/Resources/mediaCompatibility.js").read_text()
    for token in ["setInterval(", "requestAnimationFrame("]:
        require(token not in media, "Unnecessary background scheduler: " + token)
    require('lastPauseAt < 750' in media and 'recoveryUsed' in media, "Pause recovery must be bounded")
    bar = (ROOT / "JoeToep/Components/PlayerControlBar.swift").read_text()
    require("Divider()" not in bar and "joeToepGlass" not in bar, "Toolbar is not minimal black")
    # V15: themeable; the default theme is YouTube's #0F0F0F.
    require('theme.background' in bar, "Themed toolbar missing")
    theme = (ROOT / "JoeToep/Models/ThemeOptions.swift").read_text()
    require('case .youtube: Color(hex: 0x0F0F0F)' in theme, "YouTube dark default missing")
    require((ROOT / "Scripts/test_media_compatibility.cjs").is_file(), "Missing V3 regressions")


def check_v4() -> None:
    info = load_plist(ROOT / "JoeToep/Info.plist")
    require(info["CFBundleDisplayName"] == "JoeToep", "App display name not updated")
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    require(project.count("PRODUCT_NAME = JoeToep;") == 2, "Product name differs across configurations")
    require(project.count("PRODUCT_MODULE_NAME = JoeToep;") == 2, "Stable module name lost")
    scheme = ET.parse(ROOT / "JoeToep.xcodeproj/xcshareddata/xcschemes/JoeToep.xcscheme")
    for item in scheme.findall(".//BuildableReference"):
        require(item.get("ReferencedContainer") == "container:JoeToep.xcodeproj", "Old scheme project path")
        if item.get("BlueprintName") == "JoeToep":
            require(item.get("BuildableName") == "JoeToep.app", "Old scheme app product")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require('status == "system-fullscreen"' in session and "systemFullscreenHandoff = true" in session,
            "iOS fullscreen auto-PiP ownership guard missing")
    require("automaticHandoffTask?.cancel()" in session and "self.pip.reset()" in session,
            "Bounded cancellable handoff check missing")
    branch = session.split('status == "system-fullscreen"', 1)[1].split("return\n            }", 1)[0]
    require("requestBridgePiP" not in branch, "V10: fullscreen auto-PiP must not send a second page request")
    require("JTSetBackgroundMediaProtection(webView, enabled)" in session and "!applicationActive" in session,
            "Scoped visibility protection missing")
    require("func goHome() { load(StartPage.home.url) }" in session, "Brand home follows custom start page")
    stage = (ROOT / "JoeToep/Resources/videoStage.js").read_text()
    for forbidden in ["setInterval(", "requestAnimationFrame(", "cloneNode(", "captureStream(", "fetch("]:
        require(forbidden not in stage, "Unnecessary stage work: " + forbidden)
    for required in ["abort?.abort()", "observer?.disconnect()", "yt-navigate-start", "seekable", "Video progress"]:
        require(required in stage, "Missing stage safety/control: " + required)
    bar = (ROOT / "JoeToep/Components/PlayerControlBar.swift").read_text()
    require(bar.index('"toolbar.refresh"') < bar.index('ForEach(StartPage.allCases'), "Refresh is not before Home")
    require('theme.style.separator' in bar, "Mac edges lack a separator")
    with Image.open(ROOT / "JoeToep/Assets.xcassets/AppIcon.appiconset/AppIcon-iOS-1024.png") as icon:
        require(icon.getpixel((0, 0)) == (185, 187, 193), "V8 icon tile must be light gray")
        require(icon.getpixel((300, 512)) == (255, 0, 0), "Icon badge must be YouTube red")


def check_v5() -> None:
    media = (ROOT / "JoeToep/Resources/mediaCompatibility.js").read_text()
    event_body = media.split("const presentationChanged =")[1].split("function recoverReturn")[0]
    require("stopImmediatePropagation" not in event_body, "Presentation events must reach YouTube")
    require("returnRecoveryUsed" in media and "handoffDuration = 5000" in media, "Bounded transition recovery missing")
    require("native.exitPiP.call(document)" in media, "Return must bypass site exit guard")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    leave = session.split("func applicationWillDeactivate()")[1].split("func applicationDidActivate()")[0]
    require("isPlaying," not in leave, "Automatic entry must not gate on stale Swift playback snapshot")
    require("beginAutomaticHandoff()" in session and "returnToApp('origin')" in session, "Page handoff/return not wired")
    bar = (ROOT / "JoeToep/Components/PlayerControlBar.swift").read_text()
    require("if settings.showPiPButton" in bar, "Optional manual PiP missing")
    require("enabled: !session.isInPictureInPicture" not in bar, "Navigation cannot lock during PiP")
    settings = (ROOT / "JoeToep/Models/SettingsSnapshot.swift").read_text()
    for token in ["nativeFullscreen = true", "showPiPButton = true", "showNavigationControls = true", "keepPiPOnReturn = false", "pipOnFullscreenExit = false"]:
        require(token in settings, "Incorrect V5 default: " + token)
    filters = json.loads((ROOT / "JoeToep/Resources/strictAds.json").read_text())
    require(all("if-domain" in x["trigger"] for x in filters), "Unscoped strict filter")
    controller = (ROOT / "JoeToep/Support/ContentFilterController.swift").read_text()
    require("2_000_000" in controller and "timeoutIntervalForResource = 30" in controller, "Unbounded remote filter fetch")


def check_v6() -> None:
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    activate = session.split("func applicationDidActivate()")[1].split("private func requestPictureInPicture")[0]
    require(activate.index("consumeActivation()") < activate.index("returnToApp('origin')"), "Return must be gated before native exit")
    require("if !shouldReturn" in activate and "return" in activate, "Transient activation guard missing")
    view = (ROOT / "JoeToep/Views/PlayerShellView.swift").read_text()
    require("UIApplication.willEnterForegroundNotification" in view, "Foreground gate is not connected")
    require("self.documentID == expectedDocument" in session and "self.videoID == expectedVideo" in session, "Fullscreen restore can target a stale video")
    media = (ROOT / "JoeToep/Resources/mediaCompatibility.js").read_text()
    require("native.pause.call(v)" in media and 'userPause = true; desiredPlaying = false;' in media, "Explicit remote pause missing")
    require("MPRemoteCommandCenter" not in (ROOT / "JoeToep/Support/PlaybackSessionController.swift").read_text(), "Competing media owner")


def check_v7() -> None:
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require("FeedNavigation.needsDesktop" in session, "Feed presentation routing missing")
    require("window.JoeToepMedia?.leaveForNavigation()" in session, "Navigation must clean native and safe fullscreen")
    require("self.navigationSerial == ticket" in session and ".milliseconds(400)" in session, "Navigation must execute once and not wait forever")
    require("window.makeKeyAndOrderFront(nil)" in session and "NSApp.activate" in session, "Mac PiP return does not focus its window")
    require("releaseHandoffAfterSettling()" in session and "handoffReleaseTask == nil" in session, "iPhone settling assertion missing/unbounded")
    require("UIDevice.current.userInterfaceIdiom == .phone" in session, "iPad settling route changed unexpectedly")


def check_v21() -> None:
    for name in ("WidgetShared.swift", "WidgetIntents.swift"):
        app = (ROOT / "JoeToep/Support" / name).read_text()
        ext = (ROOT / "JoeToepWidgets" / name).read_text()
        require(app == ext, f"{name}: app and widget copies differ")
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    require("JoeToepWidgets.appex in Embed Foundation Extensions" in project, "Widget extension is not embedded")
    require("nl.tijn.JoeToep.widgets" in project, "Widget bundle id missing")
    for ent in ("JoeToep/JoeToep.iOS.entitlements", "JoeToepWidgets/JoeToepWidgets.iOS.entitlements"):
        require("group.nl.tijn.JoeToep" in (ROOT / ent).read_text(), f"App group missing in {ent}")
    shared = (ROOT / "JoeToep/Support/WidgetShared.swift").read_text()
    require('"group.nl.tijn.JoeToep"' in shared and "37WRZNSADT.nl.tijn.JoeToep.shared" in shared, "App group ids out of sync")


def check_v22() -> None:
    shared = (ROOT / "JoeToep/Support/WatchShared.swift").read_text()
    for copy in ("JoeToepWatch/WatchShared.swift", "JoeToepWatchWidgets/WatchShared.swift"):
        require((ROOT / copy).read_text() == shared, f"{copy} differs from JoeToep/Support/WatchShared.swift")
    project = (ROOT / "JoeToep.xcodeproj/project.pbxproj").read_text()
    require("JoeToepWatchWidgets.appex in Embed Foundation Extensions" in project, "Watch widgets are not embedded in the Watch app")
    require("nl.tijn.JoeToep.watchkitapp.widgets" in project, "Watch widget bundle id missing")
    for ent in ("JoeToepWatch/JoeToepWatch.entitlements", "JoeToepWatchWidgets/JoeToepWatchWidgets.entitlements"):
        require("group.nl.tijn.JoeToep" in (ROOT / ent).read_text(), f"App group missing in {ent}")
    plist = (ROOT / "JoeToep/Info.plist").read_text()
    require("NSSupportsLiveActivities" in plist, "Live Activities not enabled")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require("PiP closed with ✕" in session, "PiP close must stop playback")
    require("horizontalLock" in session, "iPhone horizontal offset lock missing")
    media = (ROOT / "JoeToep/Resources/mediaCompatibility.js").read_text()
    require("system-pip-closed" in media and "quiet(ms)" in media, "PiP close / sync quiet guard missing in JS")
    model = (ROOT / "JoeToep/Models/SyncModel.swift").read_text()
    require("handoffID" in model and "handoffTime" in model, "Background handoff marker missing")


def check_v26() -> None:
    """V26: Spaces, Split View, Peek, Boosts en de pagina-assistent zijn compleet en veilig ingebouwd."""
    for name in ["JoeToep/Models/BrowserSpaces.swift", "JoeToep/Models/SplitLayout.swift", "JoeToep/Models/SiteBoosts.swift",
                 "JoeToep/Models/PageDigest.swift", "JoeToep/Models/V26Prefs.swift", "JoeToep/Views/V26Views.swift",
                 "JoeToep/Views/V26Panels.swift", "JoeToep/Support/PageAssistant.swift", "JoeToep/Resources/boosts.js",
                 "JoeToep/Resources/pageReader.js", "JoeToepTests/LinuxV26Tests.swift", "JoeToepTests/V26FeatureTests.swift",
                 "Scripts/test_v26_arc_scripts.cjs", "Scripts/linux_swift_tests.sh"]:
        require((ROOT / name).is_file(), "V26 file missing: " + name)
    require(not (ROOT / "JoeToep/Views/DebugHUD.swift").exists(), "Empty DebugHUD.swift is back")
    # Pure modellen: alleen Foundation, zodat ze op Linux compileren en getest worden.
    for name in ["BrowserSpaces", "SplitLayout", "SiteBoosts", "PageDigest", "V26Prefs"]:
        imports = set(re.findall(r"^import (\w+)", (ROOT / f"JoeToep/Models/{name}.swift").read_text(), re.M))
        require(imports == {"Foundation"}, f"{name}.swift must only import Foundation (Linux tests): {sorted(imports)}")
    session = (ROOT / "JoeToep/Browser/WebSession.swift").read_text()
    require('installScript("boosts", world: Self.bridgeWorld, time: .atDocumentStart' in session, "Boosts must load at document start in the bridge world")
    require('installScript("pageReader", world: Self.bridgeWorld)' in session, "Page reader must run in the bridge world")
    require("guard message.frameInfo.isMainFrame else { return }" in session.split('event.hasPrefix("boostZap")', 1)[1][:200],
            "Zap messages must come from the main frame")
    require("boosts.hashValue" in session, "Changed boosts must reinstall the document-start scripts")
    for name in ["boosts.js", "pageReader.js"]:
        source = (ROOT / "JoeToep/Resources" / name).read_text()
        for token in ["innerHTML", "outerHTML", "insertAdjacentHTML", "document.write", "setInterval(", "requestAnimationFrame(", "fetch(", "XMLHttpRequest"]:
            require(token not in source, f"{name}: forbidden {token}")
    store = (ROOT / "JoeToep/Models/TabSessionStore.swift").read_text()
    require("static func sanitized" in store and "SavedBrowserTab(id: $0.id" not in store,
            "TabSessionStore must keep every field (groupID/spaceID) when saving and restoring")
    # Elke V26-instelling heeft uitleg en is vindbaar in de instellingen.
    help_text = (ROOT / "JoeToep/Views/SettingHelp.swift").read_text()
    block = help_text[help_text.index("static let v26Texts"):]
    block = block[:block.index("    ]")]
    keys = re.findall(r'^\s*"([^"]+)":', block, re.M)
    require(len(keys) == len(set(keys)), "SettingHelp.v26Texts has duplicate keys")
    texts_block = help_text[help_text.index("static let texts"):]
    texts_block = texts_block[:texts_block.index("    ]")]
    old_keys = set(re.findall(r'^\s*"([^"]+)":', texts_block, re.M))
    require(not (set(keys) & old_keys), "V26 setting titles must not reuse existing titles: " + ", ".join(sorted(set(keys) & old_keys)))
    titles = re.findall(r'SettingToggle\("([^"]+)"', (ROOT / "JoeToep/Views/V26Panels.swift").read_text())
    missing = [t for t in titles if t not in keys]
    require(not missing, "V26 settings without help text: " + ", ".join(missing))
    # CommandsBuilder accepteert hooguit 10 onderdelen per niveau (anders bouwt het menu niet).
    app = (ROOT / "JoeToep/JoeToepApp.swift").read_text()
    body = app[app.index("struct BrowserCommands"):]
    body = body[body.index("var body: some Commands {"):]
    depth, top, i = 0, 0, body.index("{") + 1
    line_start = True
    for line in body[i:].splitlines():
        stripped = line.strip()
        if depth == 0 and re.match(r"(CommandGroup|CommandMenu|Group|SidebarCommands|ToolbarCommands)\b", stripped):
            top += 1
        depth += line.count("{") - line.count("}")
        if depth < 0:
            break
    require(top <= 10, f"BrowserCommands has {top} top-level items (max 10)")
    package = json.loads((ROOT / "package.json").read_text())
    require("test_v26_arc_scripts.cjs" in package["scripts"]["test"], "npm test must run the V26 scripts")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
