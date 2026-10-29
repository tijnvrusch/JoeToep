# JoeToep — overdracht na versie 25.0

## Stand
- Code: 25.0.0 (37), map `~/Documents/Claude/JoeToep-V25`.
- Let op: deze map is de vroegere map `JoeToep-V23.1` (hernoemd, inhoud = V24 + V25), zodat Xcode's recente-lijst hem kan openen. De oorspronkelijke 23.1 staat ongewijzigd in `131026-JoeToep-V23.1-Xcode.zip`. Een overbodige tussenkopie staat in `_to_delete/JoeToep-V25-kopie` (mag weg; wissen vraagt toestemming).
- Zie CHANGELOG.md (25.0.0) en Docs/BUILD_REPORT.md.

## Wat er in 25 zit (technisch)
- `mediaCompatibility.js`: `ownPlay/ownPause` + `scriptPlayAt/scriptPauseAt` (wie startte?), `nativeUserPlay` (▶ in AVKit-fullscreen/PiP zonder script-verzoek = gebruiker, alleen iOS), `allowedPlay` (WeakSet: quiet beslist één keer per start), `releasedKey` (quiet(-1) opnieuw zetten voor een video die je zelf startte wordt genegeerd), native ❚❚ in fullscreen = gebruikerspauze (`native-user-pause`, teruggedraaid als de app binnen 750 ms naar de achtergrond gaat), `userPlayIntent()`, `pick()` via levende `getElementsByTagName`-lijst.
- `sitePreferences.js applyResume` en `WebSession.syncPosition`: niet pauzeren als `userPlayIntent()`.
- `WebSession.handle`: 1,2 s echt spelen → `releaseQuiet()`.
- Mac: `ensureFullscreenExit` / `forceFullscreenExit` (WKWebView.fullscreenState, `closeAllMediaPresentations`), `staleYouTubeFullscreenFix`; `reenterFullscreenForFit` nooit < 4 s na jouw eigen fullscreen-actie; `MacFullscreenFitGuard` meet tegen `screen.safeAreaInsets` (notch) en `userIntervened()`.
- `BrowserWorkspace.RemotePlayback.playStamp`: geen automatische overname bij alleen app-activatie als het daar < 10 s geleden begon.
- `playbackControls.js`: klik op de fullscreen-knop in fullscreen → `joetoep-exit-window-fullscreen` → nakijken in de app.

## Open punten
- Alles op de toestellen nog bouwen en testen (zie BUILD_REPORT).
- Lijst uit HANDOFF-V25.md (iPhone-rotatie op het toestel, BenQ/HP-fullscreen, Live Activity-knoppen, Watch, UI-tests) blijft staan.
- Les voor computer use: in Xcode's welkomstvenster NIET op "Open…" klikken — het paneel is een apart proces en blokkeert Xcode. Een project in de recente-lijst dubbelklikken werkt wel.

## Vaste afspraken: zie HANDOFF-V23.md (ongewijzigd).
