# Prompt voor de Mac-chat — JoeToep V26 uitvoerig testen op Mac, iPhone en iPad

Plak alles hieronder in de chat die aan Tijns Mac gekoppeld is (de chat waarin V25 gemaakt is).

---

Je werkt verder aan **JoeToep**. Versie **26.0.0 (39)** is in een Claude-cloudsessie gebouwd en staat op GitHub (`tijnvrusch/JoeToep`, branches `main` en `versie/v26`). De cloud kon de app compileren en unit tests draaien (GitHub Actions, macOS-runner + iOS Simulator), maar **niet op echte toestellen testen**. Dat is jouw taak. Antwoord in het Nederlands, kort en concreet.

## 1. Voorbereiden
1. Vraag in één keer alle toegang: computer use voor JoeToep (`nl.tijn.JoeToep`, volledig), Xcode (klik-niveau) en Device Hub; maptoegang tot `~/Documents/Claude` en `~/Library/Developer/Xcode/DerivedData`. Daarna laat Tijn de computer met rust.
2. Haal V26 op in een nieuwe map `~/Documents/Claude/JoeToep-V26` (bijv. `git clone -b versie/v26 https://github.com/tijnvrusch/JoeToep JoeToep-V26`, of download de zip van branch `versie/v26`). Raak `~/Documents/Claude/JoeToep/Codex*` en de QA-app `nl.tijn.JoeToep.QA` niet aan.
3. Lees `CLAUDE.md`, `CHANGELOG.md` (26.0.0), `Docs/HANDOFF-V27.md` (stand + testlijst) en `Docs/HANDOFF-V23.md` (vaste afspraken).
4. Laat Tijn het project openen (of dubbelklik het in de recente-lijst van Xcode's welkomstvenster; **niet** op "Open…" klikken). Kies je eigen Signing Team.

## 2. Vaste afspraken (strikt)
- Xcode **alleen klikken** (Run/Stop/bestemming); nooit typen, toetsen, app-menu of AppleScript in Xcode.
- Nooit wachtwoorden typen of inloggen. Geen weblinks in apps aanklikken. Niet in andere apps handelen.
- Geen geplande taken/vangnetten starten. Builds controleren via `DerivedData/JoeToep-*/Logs/Build/*.xcactivitylog` (gunzip + grep `error:` / `Build succeeded`).

## 3. Bouwen en unit tests
- Bouw en installeer op **My Mac**, **iPhone "eiFoon"** (kabel) en **iPad**. Los compileerfouten op (de CI was groen, maar je eigen Xcode/SDK kan afwijken).
- Draai `JoeToepTests` op de Mac (o.a. `V26FeatureTests`, `LinuxV26Tests`, `V25FeatureTests`).

## 4. Uitvoerig testen (elk punt op Mac én iPhone, iPad waar het past; noteer per punt OK/fout)
**Spaces**: maak 3 Spaces (naam, symbool, emoji, kleur); wissel via zijbalk-icoontjes, Space-knop in de tabbalk, ⌃1…⌃9, ⌃⌘[ / ⌃⌘] (werkt ⌃1 niet op de Mac: Mission Control-sneltoets — meld het aan Tijn); tab naar andere Space; vastgezette tab zichtbaar in elke Space (en uit in de instellingen); laatste tab van een Space sluiten → blijft in die Space; Space verwijderen met en zonder tabs; app herstarten → tabs **en tabgroepen** in de juiste Space (bugfix 26: groepen bleven eerder leeg); sync met de iPhone blijft werken.
**Split View** (Mac/iPad): ⌘⇧\\, rechtsklik › Open in Split View, ⋯-menu; lijn slepen, dubbelklik 50/50; klikken wisselt de focus; video in het ene paneel, pagina in het andere; wisselen/draaien/sluiten via de paneelkop; venster smal → boven elkaar; fullscreen-video in een paneel in- en uit (F/Esc/dubbelklik) → terug in de split zonder zwart beeld; 50× openen/sluiten zonder herladen.
**Peek**: ⇧-klik (Mac) en linkmenu "Open in Peek" (Mac/iPhone/iPad); Esc, klik ernaast, ⌘↩, "Open in Split View"; video in Peek pauzeert de andere tab; Peek komt niet terug na herstart.
**Boosts/Zap**: ⌘⌥B op YouTube: reacties, aanbevelingen, eindkaarten, startfeed verbergen; Zap (⌘⌥Z) een onderdeel, Undo, Done, herladen → blijft weg; m.youtube.com op de iPhone deelt de Boost; lettertype, donker forceren (video's blijven normaal), eigen CSS; Boosts uit in Instellingen → direct alles weg.
**Pagina-assistent** (⌘E / ⋯): artikel en YouTube-video; samenvatten, kernpunten, vraag stellen, onderwerp aantikken, kopiëren; met en zonder Apple Intelligence; iPhone als blad.
**Instellingen**: pagina "Spaces, Split View & Boosts": elke schakelaar en schuif doet wat de uitleg zegt; zoeken in de instellingen vindt de nieuwe opties; "Restore Defaults".
**Regressie (moet gelijk zijn aan 25.1)**: PiP (aan/uit, terugknop → fullscreen, pauze in PiP), Mac-fullscreen (F/Esc/dubbelklik/klik = pauze, BenQ/HP-monitor), iPhone automatisch draaien bij fullscreen (rotatievergrendeling aan/uit, omlaag vegen = inline), play/pauze precies één keer, tab-sync en "Continue on", widgets, Live Activity-knoppen, Watch.
**Stress**: 30 tabs over 3 Spaces, snel wisselen, Split View open/dicht, 10 minuten video met wisselen tussen Spaces; let op haperingen, geheugen en crashes (`~/Library/Logs/DiagnosticReports`).

## 5. Fouten oplossen en opleveren
- Los elke gevonden fout op in de map, met commentaar `// V26.1:` en een CHANGELOG-kopje `# 26.1.0 (40)` (wat merkte je, oorzaak, oplossing); versie ophogen in `project.pbxproj`, `AppConstants.swift` en `EXPECTED_VERSION/EXPECTED_BUILD` in `Scripts/validate_project.py`.
- Draai `npm ci --ignore-scripts && npm test` en `python3 Scripts/validate_project.py`.
- Lever op als `~/Documents/Claude/<YYMMDD>-JoeToep-V26.1-Xcode.zip` (zonder xcuserdata/.DS_Store/node_modules) en, als git beschikbaar is, commit "JoeToep V26.1" op `main` + branch `versie/v26.1`.
- Sluit af met een korte Nederlandse samenvatting: wat getest is (per toestel), wat fout was, wat opgelost is en wat nog open staat. Schrijf het testresultaat ook in `Docs/BUILD_REPORT.md`.
