# JoeToep — overdracht na versie 23.1

## Stand
- Code: 23.1.0 (35), map `~/Documents/Claude/JoeToep-V23.1` (Xcode heeft het project uit deze map open).
- Oplevering: `~/Documents/Claude/131026-JoeToep-V23.1-Xcode.zip`.
- Zie CHANGELOG.md (23.1.0) en Docs/BUILD_REPORT.md.

## Wat er in 23.1 zit (technisch)
- `MacNavigationMonitor`: leftMouseDown in `WebCoreFullScreenWindow` op een niet-WebKit-view (VisionKit) → `JoeToepControls.surfaceClick(clickCount)`. `NSWindow.isWebKitFullScreenWindow` (naam bevat "FullScreenWindow"); WebKit's fullscreen-venster wordt nooit meer door JoeToep omgeschakeld.
- `playbackControls.js`: klik-logica fullscreen (`surfaceClick`), bezel, dubbelklik houdt stand (`__joetoepDblClickKeepPaused`).
- `WebHostNSView` (WebContentView.swift): herstelt een verweesde webview (2 + 1,5 s na verlaten fullscreen).
- `phoneLayout.js` (iPhone, documentStart).
- `OrientationCoordinator`: `beginFullscreenLandscape` / `endFullscreenLandscape`, instelling `autoRotateFullscreenV231`.
- Let op: `TextRecognitionInVideosEnabled` uitzetten laat het webproces vastlopen — niet doen.
- `Views/DebugHUD.swift` is leeg (tijdelijk diagnosepaneel); mag weg.

## Open punten
- iPhone: startpagina (één kolom vanaf eerste frame) en automatisch draaien (met/zonder rotatievergrendeling) op het toestel bekijken — scherm was in deze sessie niet beschikbaar.
- Bij het starten herstelt de Mac een video soms direct in fullscreen en gedempt (bestond al; niet veranderd).
- Open punten uit HANDOFF-V24.md (Live Activity-knoppen, BenQ/HP-fullscreen, Watch) blijven staan.

## Vaste afspraken: zie HANDOFF-V23.md (ongewijzigd).
