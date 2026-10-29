# JoeToep — overdracht na versie 23

## Stand
- Code: 23.0.0 (34), map `~/Documents/Claude/JoeToep-V23` (Xcode opent het project uit deze map).
- Oplevering: `~/Documents/Claude/121026-JoeToep-V23-Xcode.zip` (bron + PNG's).
- Gebouwd en geïnstalleerd op Mac, iPhone "eiFoon" en iPad. Unit tests 128/128 groen op Mac én iPhone. Zie BUILD_REPORT.md.

## Wat er in 23 zit (kort)
- `Support/MacFullscreenFitGuard.swift`: fullscreen altijd 100 % (controle na fullscreen/scherm-/schaalwissel, herstel in stappen; meldingen in het lifecycle-logboek als "fullscreen fit: …").
- Instelling "Switch devices automatically" (key `handoffAutoResumeV21`, per apparaat).
- Volume-HUD in `playbackControls.js` (`volumeHud`; géén innerHTML — YouTube dwingt Trusted Types af).
- Live Activity: `WidgetIntentRouter.asyncHandler` → `WidgetBridge.performFromIntent`; outbox in `TabSyncService.send`; `isReachable` (2 min speling); `LiveActivityManager.applyOptimistic/staleDate`.
- PiP na verlaten van de kijkpagina: `leftWithPlayingVideo` in `mediaCompatibility.js` + `|| isPlaying` in WebSession.

## Open punten / nog te testen
- Fullscreen op de BenQ en HP: het venster kon in deze sessie niet naar een ander scherm (slepen over het bureaublad wordt geblokkeerd). Test: venster naar BenQ, video fullscreen, monitor wisselen/slaapstand, opnieuw fullscreen; kijk in het lifecycle-logboek naar "fullscreen fit".
- Live tab sync stond UIT op de Mac (in 23 aangezet om te testen) en kon op iPhone/iPad niet worden bekeken. Controleer op iPhone/iPad Instellingen › Sync & devices › Live tab sync, en of de oude tabs van de iPhone na het samenvoegen terugkomen (`tombstoneReset22_3`).
- Live Activity-knoppen met een video op de Mac (iPhone vergrendeld) — kon niet: Device Hub geeft geen aanraking op een fysiek toestel.
- UI-tests op de iPhone: het gratis ontwikkelaarsprofiel zit vol (3 apps: JoeToep, Murmur, Murmur-testrunner). Eén weghalen (door Tijn) maakt UI-tests weer mogelijk. In het schema staan UI-tests standaard uit (`skipped = "YES"`).
- UI-tests op de Mac vonden het venster niet onder computer-use-besturing; bij gewone start opent het venster normaal.
- Watch niet apart getest.

## Vaste afspraken: zie HANDOFF-V23.md (ongewijzigd).
