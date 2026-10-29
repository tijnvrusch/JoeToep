# CLAUDE.md — werken aan JoeToep

Lees dit eerst. Daarna: `README.md`, `CHANGELOG.md` (bovenste versie), `Docs/HANDOFF-V26.md` (nieuwste overdracht), `Docs/VERSIEGESCHIEDENIS.md`.

## Wat is JoeToep
Persoonlijke YouTube-browser/-speler (SwiftUI + WKWebView) van Tijn, één multiplatform-target voor macOS, iOS en iPadOS, plus Apple Watch-app, widgets en een Live Activity. Kern: tabs, tab-sync tussen apparaten (MultipeerConnectivity, `Support/TabSyncService.swift`), Picture in Picture, fullscreen, overlay/zoekbalk, Spotify-koppeling. Veel gedrag zit in de geïnjecteerde scripts in `JoeToep/Resources/*.js` (vooral `mediaCompatibility.js`, `sitePreferences.js`, `playbackControls.js`).

## Taal en stijl
- Antwoord Tijn in het **Nederlands**. Code-commentaar is Nederlands met versielabel (bijv. `// V25:`).
- Elke wijziging komt in `CHANGELOG.md` (nieuwste bovenaan, kopje `# X.Y.Z (build)`), in gewone taal: wat de gebruiker merkte, de oorzaak, de oplossing.
- Versie ophogen in `JoeToep.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` — alle targets), `JoeToep/Support/AppConstants.swift` en `Scripts/validate_project.py`.

## Testen in de cloud (zonder Mac)
- `node Scripts/test_media_compatibility.cjs` en de andere `Scripts/test_*.cjs` (DOM-simulatie van de JS-scripts).
- `python3 Scripts/validate_project.py` (projectpoorten).
- Swift kan hier niet gecompileerd worden voor Apple-platforms: wees extra zorgvuldig (`#if os(macOS)`/`os(iOS)` voor AppKit/UIKit, `@MainActor`, toegang tot `private` leden).
- Echte builds en tests gebeuren op Tijns Mac via Xcode (zie `Docs/RUNBOOK.md`, `Docs/BUILD_REPORT.md`).

## Werken op Tijns Mac (alleen als die gekoppeld is)
- Xcode **alleen klikken** — nooit typen/toetsen/app-menu in Xcode, nooit AppleScript.
- Nooit wachtwoorden typen of inloggen. Geen weblinks in apps aanklikken. Niet in andere apps handelen.
- Niet aanraken: `~/Documents/Claude/JoeToep/Codex*` en de QA-app `nl.tijn.JoeToep.QA`.
- Apparaten: MacBook Pro M1 Max (monitoren BenQ 1440p, HP 1920×1200), iPhone 13 Pro "eiFoon", iPad Pro 12,9" 2e gen (iPadOS 17.7), Apple Watch.
- Builds controleren via `~/Library/Developer/Xcode/DerivedData/JoeToep-*/Logs/Build/*.xcactivitylog` (gunzip + grep `error:` / `Build succeeded`).
- Geen vangnetten/geplande herinneringen starten tenzij Tijn erom vraagt.

## Git
- Elke versie is een commit + tag (`v15` … `v25.1`). Nieuwe versie = commit "JoeToep VX.Y" + tag `vX.Y`.
- Chatgeschiedenis van eerdere sessies: `Docs/chatgeschiedenis/`.
