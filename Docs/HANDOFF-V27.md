# JoeToep — overdracht na versie 26.0

## Stand
- Code: **26.0.0 (39)** op de werkbranch `claude/cool-ride-ksydny` (cloudsessie, geen Mac gekoppeld). Na akkoord van Tijn: naar `main` en een branch `versie/v26` (zoals elke versie).
- Gebouwd en getest in de cloud: alle JS-suites (`npm test`), `python3 Scripts/validate_project.py` (16 poorten), `Scripts/linux_swift_tests.sh` (37 Swift-unit tests op Linux, Swift 6.1), `Scripts/test_content_filters.py`, de mediatests en de grammaticacontrole (geen nieuwe meldingen ten opzichte van 25.1).
- **Gebouwd en getest in GitHub Actions** (nieuwste Xcode op een macOS-runner): build voor macOS en iOS Simulator groen, en `JoeToepTests` (o.a. `V26FeatureTests`, `LinuxV26Tests`) groen op macOS en in de iOS Simulator. De eerste CI-run vond één compilerfout (`withAnimation { addSpace() }`), die is opgelost. Niet getest: echte toestellen (PiP, rotatie, sync, Watch, Live Activity) — zie `Docs/PROMPT-TESTEN-V26.md`.

## Wat er in 26 zit (technisch)
- **Spaces** (`Models/BrowserSpaces.swift`, `BrowserWorkspace` → "V26 — Spaces, Split View en Peek"): `BrowserTab.spaceID` / `SavedBrowserTab.spaceID` / `TabGroup.spaceID` (nil = eerste Space). `activeSpaceID` per venster; `selectedID.didSet` → `selectionChanged(from:)` laat de Space meelopen met élke selectiewijziging (klik, sync, ⌃Tab, zoekbalk). `visibleTabs`, `pinnedTabs`, `tabs(in:)` en `visibleGroups` filteren op de actieve Space; `select(index:)`, `selectNext/Previous` en `stepTab` werken op zichtbare tabs. Sluiten van de laatste tab in een Space → `makeBlankTab(in:)`. Spaces in `UserDefaults` (`browserSpacesV26`), gedeeld door vensters via `SpaceStore.didChange`.
- **Split View** (`Models/SplitLayout.swift`, `Views/V26Views.swift` → `WorkspaceTabStack`): `split: SplitPair?`. De tabstapel geeft elke tab een kader (geen nieuwe webview). `select(_:)` naar het andere paneel = `focusPane` (geen `leaveCurrent`, dus geen pauze/PiP). Een tab buiten de split kiezen of een paneel sluiten beëindigt hem; het andere paneel pauzeert dan.
- **Peek** (`openPeek/closePeek/expandPeek`): `peekTab` staat buiten `tabs` (niet bewaard/gesynct). Mac: ⇧-klik in `decidePolicyFor` (na de ⌘-klik-tak) en "Open in Peek" in `JoeToepWebView.willOpenMenu`; iOS: `contextMenuConfigurationForElement`. Video in Peek → `handOver(to:)`.
- **Boosts/Zap** (`Models/SiteBoosts.swift`, `Resources/boosts.js`): alle Boosts gaan als `window.JOETOEP_BOOSTS_ALL` mee in de documentStart-prefix (bridge-wereld); de hash zit in `installedScriptKey`, dus een wijziging installeert de scripts opnieuw en `applyBoost()` zet hem live. Zap-berichten komen binnen via de `joeToepLinks`-handler (`event: "boostZap"`), alleen uit de hoofdframe; de site komt uit `currentURL`.
- **Pagina-assistent** (`Models/PageDigest.swift`, `Support/PageAssistant.swift`, `Resources/pageReader.js`): `WebSession.readPage()` → `PageContent`; Apple Intelligence via `LanguageModelSession` (iOS/macOS 26, `#if canImport(FoundationModels)`), anders `PageDigest` (extractief).
- **Voorkeuren**: `Models/V26Prefs.swift` (sleutels + grenzen), pagina `V26Settings` in `Views/V26Panels.swift`, uitleg in `SettingHelp.v26Texts`.
- **Menu's**: `BrowserCommands` heeft het menu "Spaces"; de twee werkbalk-groepen zitten in één `Group` (CommandsBuilder: max. 10 onderdelen — `check_v26` bewaakt dit).
- **Bugfix**: `TabSessionStore.sanitized` — groupID (en nu spaceID) bleef bij opslaan/herstellen niet bewaard.

## Testen op de toestellen (nieuw in 26)
1. **Mac**: Spaces maken/hernoemen/kleur/emoji/verwijderen; ⌃1…⌃9 (let op: macOS kan ⌃1… voor "Ga naar bureaublad" gebruiken — Systeeminstellingen › Toetsenbord › Sneltoetsen › Mission Control); tab naar andere Space; zijbalk-tint; app herstarten → tabs en groepen in de juiste Space.
2. **Mac**: Split View openen (⌘⇧\\, rechtsklik), lijn slepen, dubbelklik 50/50, focus wisselen met klik, video in één paneel + pagina in het andere, wisselen/draaien/sluiten, venster smal maken (→ boven elkaar), fullscreen-video in een paneel (verlaten → terug in de split).
3. **Mac/iPhone**: Peek via ⇧-klik / linkmenu, Esc, klik ernaast, ⌘↩, "Open in Split View"; video in Peek pauzeert de andere tab.
4. **Boosts**: ⌘⌥B op YouTube: reacties/eindkaarten/startfeed verbergen; Zap een onderdeel, Undo, Done; herladen → blijft weg; m.youtube.com op de iPhone deelt de Boost; eigen CSS; donker forceren.
5. **Assistent**: ⌘E op een artikel en op een YouTube-video, met en zonder Apple Intelligence; vraag stellen; iPhone als blad.
6. **Regressie**: PiP, fullscreen (Mac F/Esc/dubbelklik), iPhone-rotatie, play/pauze precies één keer, tab-sync, Live Activity — mogen niet veranderd zijn (V26 raakt die code niet, behalve dat `TabPlayerView` nu via `WorkspaceTabStack` getekend wordt).

## Open punten (van V25, blijven staan)
- Alles op de toestellen bouwen en testen (zie BUILD_REPORT).
- iPhone-rotatie op het toestel, BenQ/HP-fullscreen, Live Activity-knoppen, Watch, UI-tests (zie HANDOFF-V25.md).
- Les voor computer use: in Xcode's welkomstvenster NIET op "Open…" klikken; een project in de recente-lijst dubbelklikken werkt wel.

## Ideeën voor 27
- Spaces met een eigen thema/profiel (eigen cookies per Space, zoals Arc-profielen).
- Peek automatisch voor links naar andere sites vanuit vastgezette tabs.
- Boosts delen/exporteren; Zap-voorbeeld vóór opslaan.
- Assistent: vragen over meerdere tabs tegelijk (Dia "@tab").

## Vaste afspraken: zie HANDOFF-V23.md (ongewijzigd).
