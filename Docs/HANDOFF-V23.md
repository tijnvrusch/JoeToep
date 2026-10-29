# JoeToep — overdracht naar versie 23

## Context
- App: JoeToep (SwiftUI + WKWebView YouTube-speler), één multiplatform target: macOS, iOS, iPadOS, plus Watch en widgets.
- Laatste code: 22.3.0 (33). Zie CHANGELOG.md bovenaan voor alles wat in 22.3 zit.
- Apparaten:
  - MacBook Pro M1 Max, met monitoren BenQ 1440p en HP 1920x1200
  - iPhone 13 Pro "eiFoon", draadloos verbonden met Xcode
  - iPad Pro 2e generatie (iPadOS 17.7; Device Hub kan het scherm niet tonen)
  - Apple Watch
- Mappen op de Mac (~/Documents/Claude):
  - `300926-JoeToep-V22.2-Xcode`: de map die Xcode tot nu toe opende, inhoud 22.3.
  - `031026-JoeToep-V22.3-Xcode.zip`: complete 22.3 inclusief PNG's.
  - `JoeToep-V23`: nieuw. Werk hier verder en open het project vanuit deze map in Xcode.
  - `_transfer/deploy.py`: pakt een src-zip uit in de projectmappen.
- DerivedData van het project: `~/Library/Developer/Xcode/DerivedData/JoeToep-*`. Controleer builds via de nieuwste `Logs/Build/*.xcactivitylog` (gunzip, dan grep op `error:` / `Build succeeded`).

## Vaste afspraken van Tijn
- Antwoord in het Nederlands.
- Typ nooit wachtwoorden en log nooit in.
- Xcode alleen met klikken bedienen: niet typen, geen toetsen, geen app-menu, geen AppleScript.
- Klik geen weblinks aan in apps.
- Raak de map `~/Documents/Claude/JoeToep/Codex*` niet aan, en ook de QA-app `nl.tijn.JoeToep.QA` niet.
- Geen omzeiling van YouTube-downloads.
- Handel niet in andere apps (TickTick, Dia enz.).
- Geen vangnetten (send_later) starten.

## Bekende stand en open punten uit 22.3
- iPhone draait nog 22.2. Die kan niet syncen met 22.3, omdat 22.3 alleen met dezelfde app syncet (appTag). Bouw eerst 23 op de iPhone.
- Er was een sync-incident waarbij een QA-kopie tabs overschreef. De iPhone heeft de oude tabs waarschijnlijk nog. 22.3+ wist bij de eerste start de oude sluit-markeringen (key `tombstoneReset22_3`), zodat de iPhone die tabs bij het samenvoegen terugbrengt. Controleer dit.
- Niet getest:
  - de overdracht "Continue on"/"Play here" tussen Mac en iPad (iPad stond waarschijnlijk op slot);
  - de fallback die na 8 s weer lokaal gaat spelen;
  - Watch;
  - een deel van de instellingenpagina's.
- Testtips:
  - Escape komt niet aan bij de app als je hem op afstand stuurt.
  - Scrollen in instellingen werkt niet via scroll. Gebruik een klik plus `pagedown`.
  - Na Run komt de app naar voren. Breng eerst Xcode naar voren voordat je klikt, anders klik je op de video.
  - Het sync-logboek (Instellingen › Sync & devices › Activity) is het beste diagnosemiddel.

## Wensen voor versie 23
1. **Fullscreen op macOS:** de video staat soms op ongeveer 75% met zwarte balken, op zowel de 1440p- als de 1920x1200-monitor. Na een herstart is het weg. Fullscreen moet altijd 100% breed en hoog zijn.
2. **Nieuwe instelling:** automatisch wisselen van apparaat uitzetten. Dan alleen overnemen met "Continue here"/"Play here", bijvoorbeeld in de widget.
3. **Volume:** bij een verticale swipe het YouTube-volumepercentage in beeld tonen, zoals YouTube dat doet bij de pijltjestoetsen.
4. **Live Activity op de iPhone:** moet zeer goed gesynchroniseerd en actief blijven. De bediening moet altijd werken, ook voor een video die op een ander apparaat speelt.
5. **Picture in Picture:** moet consistent op de achtergrond actief blijven en altijd werken. Ook wanneer je de inline YouTube-speler verlaat terwijl er een video speelt.
6. **Versie:** 23.0.0 (34). Werk de CHANGELOG bij.
7. **Testen:** alles uitgebreid testen, ook onder belasting, op Mac, iPhone (eerst bouwen) en iPad. Doorwerken tot er een stabiele release is.
8. **Oplevering:** complete zip `~/Documents/Claude/<YYMMDD>-JoeToep-V23-Xcode.zip`, inclusief PNG's.
