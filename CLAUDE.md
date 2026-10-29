# CLAUDE.md — werken aan JoeToep

Lees dit eerst. Daarna: `README.md`, `CHANGELOG.md` (bovenste versie), `Docs/HANDOFF-V27.md` (nieuwste overdracht), `Docs/VERSIEGESCHIEDENIS.md`.

## Wat is JoeToep
Persoonlijke YouTube-browser/-speler (SwiftUI + WKWebView) van Tijn, één multiplatform-target voor macOS, iOS en iPadOS, plus Apple Watch-app, widgets en een Live Activity. Sinds V26 ook Arc/Dia-functies: Spaces, Split View, Peek, Boosts/Zap en een pagina-assistent (zie `Docs/HANDOFF-V27.md`). Kern: tabs, tab-sync tussen apparaten (MultipeerConnectivity, `Support/TabSyncService.swift`), Picture in Picture, fullscreen, overlay/zoekbalk, Spotify-koppeling. Veel gedrag zit in de geïnjecteerde scripts in `JoeToep/Resources/*.js` (vooral `mediaCompatibility.js`, `sitePreferences.js`, `playbackControls.js`).

## Taal en stijl
- Antwoord Tijn in het **Nederlands**. Code-commentaar is Nederlands met versielabel (bijv. `// V25:`).
- Elke wijziging komt in `CHANGELOG.md` (nieuwste bovenaan, kopje `# X.Y.Z (build)`), in gewone taal: wat de gebruiker merkte, de oorzaak, de oplossing.
- Versie ophogen in `JoeToep.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` — alle targets), `JoeToep/Support/AppConstants.swift` en `Scripts/validate_project.py` (`EXPECTED_VERSION` / `EXPECTED_BUILD` bovenaan); `check_version` vergelijkt ze met elkaar en met het bovenste CHANGELOG-kopje.

## Testen in de cloud (zonder Mac)
- `npm ci --ignore-scripts && npm test` (alle `Scripts/test_*.cjs` + `test_bridge.mjs`: DOM-simulatie van de JS-scripts).
- `python3 Scripts/validate_project.py` (projectpoorten; Pillow nodig: `python3 -m venv … && pip install -r Scripts/requirements-dev.txt`).
- `Scripts/linux_swift_tests.sh`: compileert de pure Swift-bestanden (alleen Foundation) en draait hun unit tests op Linux. Geen `swift`? Start Docker (`dockerd &`) — het script gebruikt `mirror.gcr.io/library/swift:6.1-noble` (Docker Hub en download.swift.org kunnen geblokkeerd/gelimiteerd zijn). Nieuwe pure logica → in `Models/` met alleen `import Foundation`, toevoegen aan de lijst in het script, tests in `JoeToepTests/LinuxV26Tests.swift` (of een nieuw bestand in de testlijst).
- `Scripts/validate_swift_syntax.py` (tree-sitter) geeft ook vals alarm op bestaande code; vergelijk het aantal meldingen per bestand met de vorige versie in plaats van op nul te mikken.
- SwiftUI/AppKit/UIKit/WebKit kunnen hier niet gecompileerd worden: wees extra zorgvuldig (`#if os(macOS)`/`os(iOS)` voor AppKit/UIKit, `@MainActor`, toegang tot `private` leden, hooguit 10 onderdelen per Commands-/ViewBuilder-niveau, geen dubbele sleutels in dictionary-literals zoals `SettingHelp.texts` — dat crasht bij het starten).
- Echte builds en tests gebeuren op Tijns Mac via Xcode (zie `Docs/RUNBOOK.md`, `Docs/BUILD_REPORT.md`).

## Swift-compiler = GitHub Actions (macOS-runner)
Een Linux-Swift-toolchain helpt niet (geen SwiftUI/AppKit/UIKit) en download.swift.org is hier geblokkeerd. De compiler is daarom `.github/workflows/build.yml`: bij **elke push** bouwt GitHub de app met de nieuwste Xcode voor macOS én iOS Simulator (zonder ondertekenen), plus alle `Scripts/test_*.cjs` en `validate_project.py`.
- Werkwijze: wijzig → commit → push (eigen branch, bijv. `werk/<onderwerp>`, of `main`) → wacht ~5–10 min → `Scripts/ci_status.sh [branch]` toont de status en bij een fout de `error:`-regels. Herhaal tot alle jobs groen zijn vóórdat je een versie oplevert.
- Zonder `gh`: `curl -s https://api.github.com/repos/tijnvrusch/JoeToep/actions/runs?branch=<branch>&per_page=1` (status/conclusion); volledige logs staan als artifact `build-log-macOS`/`build-log-iOS` bij de run.
- Groen in CI = compileert; gedrag testen blijft op Tijns apparaten.

## Werken op Tijns Mac (alleen als die gekoppeld is)
- Xcode **alleen klikken** — nooit typen/toetsen/app-menu in Xcode, nooit AppleScript.
- Nooit wachtwoorden typen of inloggen. Geen weblinks in apps aanklikken. Niet in andere apps handelen.
- Niet aanraken: `~/Documents/Claude/JoeToep/Codex*` en de QA-app `nl.tijn.JoeToep.QA`.
- Apparaten: MacBook Pro M1 Max (monitoren BenQ 1440p, HP 1920×1200), iPhone 13 Pro "eiFoon", iPad Pro 12,9" 2e gen (iPadOS 17.7), Apple Watch.
- Builds controleren via `~/Library/Developer/Xcode/DerivedData/JoeToep-*/Logs/Build/*.xcactivitylog` (gunzip + grep `error:` / `Build succeeded`).
- Geen vangnetten/geplande herinneringen starten tenzij Tijn erom vraagt.

## Git
- Elke versie is een commit op `main` plus een branch `versie/vX.Y` (`versie/v15` … `versie/v25.1`). Nieuwe versie = commit "JoeToep VX.Y" + branch `versie/vX.Y` (tags pushen wordt door de proxy geblokkeerd).
- Chatgeschiedenis van eerdere sessies: `Docs/chatgeschiedenis/`.
