# Prompt voor een nieuwe, gewone Claude Code-chat — JoeToep (verder na V26)

Plak alles onder de streep in een nieuwe Claude Code-chat op je Mac (Claude-app of `claude` in Terminal).

---

Je werkt verder aan **JoeToep**, mijn (Tijn) SwiftUI + WKWebView-browser rond YouTube voor Mac, iPhone, iPad, Apple Watch, widgets en Live Activity. Antwoord altijd in het **Nederlands**, kort en concreet.

## Waar alles staat
- **GitHub:** `tijnvrusch/JoeToep` is de enige bron van waarheid. `main` = nieuwste stand = **26.0.0 (39)**; elke versie staat ook in een branch `versie/vX.Y` (`versie/v15` … `versie/v26`).
- Werkmap op de Mac: `~/Documents/Claude/JoeToep-V26`. Bestaat die nog niet: `git clone https://github.com/tijnvrusch/JoeToep ~/Documents/Claude/JoeToep-V26`. Bestaat hij wel: `git pull`.
- **Lees eerst:** `CLAUDE.md` (werkafspraken en tests), `README.md`, `CHANGELOG.md` (bovenste versie), `Docs/HANDOFF-V27.md` (stand, techniek van V26, open punten), `Docs/HANDOFF-V23.md` (vaste afspraken), `Docs/VERSIEGESCHIEDENIS.md`. Chatgeschiedenis van eerdere sessies: `Docs/chatgeschiedenis/` (de V26-cloudsessie staat in `JoeToep-cloudsessie-V26.md`).

## Stand na V26
- Nieuw in V26 (Arc/Dia-editie): Spaces, Split View, Peek, Boosts + Zap, pagina-assistent (Apple Intelligence of offline), instellingenpagina "Spaces, Split View & Boosts". Fix: tabgroepen bleven na een herstart niet bewaard.
- **Groen in GitHub Actions** (`.github/workflows/build.yml`, draait bij elke push): Xcode-build voor macOS + iOS Simulator, `JoeToepTests` op beide, alle JS-tests (`npm test`), `validate_project.py`, Swift-tests op Linux. Status: `Scripts/ci_status.sh [branch]`.
- **Nog nooit op echte toestellen getest.** Dat is de eerste taak.

## Vaste afspraken (strikt)
- Xcode **alleen met klikken** (Run/Stop/bestemming); nooit typen, toetsen, app-menu of AppleScript in Xcode. Project openen: dubbelklik in de recente-lijst van het welkomstvenster, nooit op "Open…".
- Nooit wachtwoorden typen of inloggen. Geen weblinks in apps aanklikken. Niet handelen in andere apps.
- Niet aanraken: `~/Documents/Claude/JoeToep/Codex*` en de QA-app `nl.tijn.JoeToep.QA`.
- Geen geplande taken of vangnetten starten tenzij ik erom vraag.
- Apparaten: MacBook Pro M1 Max (+ BenQ 1440p en HP 1920×1200), iPhone 13 Pro "eiFoon" (kabel), iPad Pro 12,9" 2e gen (iPadOS 17.7), Apple Watch.

## Werkwijze per versie
- Code-commentaar in het Nederlands met versielabel (`// V26.1:`). Elke wijziging in `CHANGELOG.md` (nieuwste bovenaan, `# X.Y.Z (build)`: wat merkte ik, oorzaak, oplossing).
- Versie ophogen in `project.pbxproj` (alle targets), `JoeToep/Support/AppConstants.swift` en `EXPECTED_VERSION`/`EXPECTED_BUILD` in `Scripts/validate_project.py`.
- Vóór opleveren: `npm ci --ignore-scripts && npm test`, `python3 Scripts/validate_project.py`, build + `JoeToepTests` in Xcode (Mac en iPhone), en CI groen na de push.
- Opleveren: commit "JoeToep VX.Y" op `main` + branch `versie/vX.Y` pushen, `Docs/HANDOFF-V<volgende>.md` schrijven, en een korte Nederlandse samenvatting.

## Wat ik nu wil
1. Vraag eerst in één keer alle toegang (computer use voor JoeToep, Xcode en Device Hub; maptoegang tot `~/Documents/Claude` en DerivedData). Daarna laat ik de computer met rust.
2. Voer `Docs/PROMPT-TESTEN-V26.md` volledig uit: bouwen op Mac, eiFoon en iPad, unit tests, en uitvoerig testen van alle V26-functies plus de regressielijst (PiP, fullscreen, rotatie, play/pauze, sync, widgets, Live Activity, Watch) en een stresstest.
3. Los alle gevonden fouten op als **26.1.0 (40)** en lever op zoals hierboven.
4. [Zet hier eventuele nieuwe wensen.]
