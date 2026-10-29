# JoeToep — overdracht na versie 24.0

## Stand
- Code: 24.0.0 (36), map `~/Documents/Claude/JoeToep-V24`.
- Zie CHANGELOG.md (24.0.0) en Docs/BUILD_REPORT.md.

## Wat er in 24 zit (technisch)
- Crashfix: `SpotifyController.init` ververst pas na `DispatchQueue.main.async`; `MediaHub.spotifyChanged` herbouwt asynchroon en samengevoegd. Crashrapporten: `~/Library/Logs/DiagnosticReports/Retired/JoeToep-2026-10-1*.ips` (allemaal "trying to lock recursively" in `SpotifyController.shared.unsafeMutableAddressor`).
- `BrowserWorkspace.close(_:remember:)`: geen geforceerde index meer.
- Mac auto-fullscreen: `fulfillAutomaticFullscreen` → `verifyAutomaticFullscreen` (3 controles, dubbele meting, nooit F tijdens overgang) + `rearmAutomaticFullscreen`; JS `JoeToepPreferences.rearmAutomaticFullscreen()` / `automaticFullscreenState()` in `sitePreferences.js`.
- iPhone: `OrientationCoordinator.installWindowObserver()` (UIWindow.didBecomeVisible → landscape-klem vóór de presentatie), `videoContextActive`, `expectFullscreen()`, `isVideoFullscreenWindow`; klem blijft tot fullscreen dicht; app-venster altijd portrait onder de klem.

## Open punten
- Op het toestel nakijken: iPhone-rotatie (met/zonder rotatievergrendeling, PiP → fullscreen, na app-wissel) — lifecycle-log toont "fullscreen window visible: landscape from first frame".
- Lijst uit HANDOFF-V24.1.md (BenQ/HP-fullscreen, Live Activity-knoppen, Watch, UI-tests) blijft staan.
- `Views/DebugHUD.swift` (leeg) mag nog steeds weg (wissen in de map vraagt toestemming).

## Vaste afspraken: zie HANDOFF-V23.md (ongewijzigd).
