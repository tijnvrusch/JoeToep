# Prompt voor een nieuwe Claude Code-chat — JoeToep (verder na 23.1)

Je werkt verder aan **JoeToep**, de app van Tijn: een SwiftUI + WKWebView-browser rond YouTube (en andere media-sites) voor **Mac, iPhone, iPad, Apple Watch, widgets en Live Activity**. Antwoord altijd in het **Nederlands**, kort en concreet.

## 1. Waar alles staat
- Projectmap (nieuwste stand): `~/Documents/Claude/JoeToep-V23.1` — Xcode heeft het project uit déze map open (`JoeToep.xcodeproj`).
- Laatste oplevering: `~/Documents/Claude/131026-JoeToep-V23.1-Xcode.zip` (bron + alle PNG's). Oudere zips/mappen per versie staan ernaast (V15 … V23).
- Lees eerst: `CHANGELOG.md` (volledige geschiedenis, nieuwste bovenaan), `Docs/HANDOFF-V24.1.md` (stand + open punten), `Docs/HANDOFF-V23.md` (vaste afspraken), `Docs/BUILD_REPORT.md`.
- Werkwijze per versie: maak een nieuwe map `~/Documents/Claude/JoeToep-V<versie>` met de nieuwste stand, werk daarin, en lever op als `~/Documents/Claude/<YYMMDD>-JoeToep-V<versie>-Xcode.zip` (inclusief PNG's, zonder xcuserdata/.DS_Store/node_modules/__pycache__). Versie + build ophogen in `project.pbxproj` (MARKETING_VERSION / CURRENT_PROJECT_VERSION, 8×) én `JoeToep/Support/AppConstants.swift`. CHANGELOG bijwerken (Nederlands, per onderwerp, met oorzaak + oplossing).
- Huidige versie: **23.1.0 (35)**. Volgende: 23.2 (36) of 24.0 (36).

## 2. Vaste afspraken van Tijn (strikt)
- Nederlands. Nooit wachtwoorden typen of inloggen.
- **Xcode alleen met klikken** (geen typen, geen toetsen, geen app-menu, geen AppleScript). Run/Stop/bestemming-kiezer klikken mag.
- Geen weblinks aanklikken in apps. Niet handelen in andere apps (TickTick, Dia, ChatGPT enz.).
- Map `~/Documents/Claude/JoeToep/Codex*` en de QA-app `nl.tijn.JoeToep.QA` niet aanraken.
- Geen omzeiling van YouTube-downloads. Geen vangnetten / send_later / geplande taken starten.
- Computer-use-toegang: JoeToep (`nl.tijn.JoeToep`, volledig), Xcode-beta (klik-niveau), Device Hub.

## 3. Apparaten
- MacBook Pro M1 Max (macOS 27.2, ingebouwd scherm met notch; fullscreen-venster begint op y=33), monitoren BenQ XL2730Z (1440p) en HP E243i (1920x1200).
- iPhone 13 Pro "eiFoon" (iOS 27.2), draadloos met Xcode. Device Hub toont het scherm alleen (geen aanraking); soms "Screen unavailable" als microfoon/camera actief is.
- iPad Pro 2e gen. "Tijn's iPad" (iPadOS 17.7, A10X): bouwen/installeren gaat, geen schermweergave en geen XCTest.
- Apple Watch (schema "JoeToepWatch").
- Gratis ontwikkelaarsprofiel: max. 3 apps op de iPhone (JoeToep, Murmur, Murmur-testrunner) → UI-tests op iPhone pas na het weghalen van één app door Tijn.

## 4. Praktische lessen (scheelt veel tijd)
- **Bouwen/testen**: device_bash werkt in een Linux-VM met de map gekoppeld (`$HOME/mnt/Claude/...`); bouwen kan alleen in Xcode (klikken). Build controleren: `~/Library/Developer/Xcode/DerivedData/JoeToep-*/Logs/Build/*.xcactivitylog` (gunzip → grep `error:` / `Build succeeded`); vraag eerst map-toegang tot DerivedData. De DerivedData-map van V23.1 is `JoeToep-ckupkwvknsnqqaagpmklxiepmetd` (info.plist → WorkspacePath).
- **Project openen in Xcode**: het Open-paneel is een apart systeemproces en mag NIET aangeklikt worden → vraag Tijn het project te openen, of gebruik de recente-lijst in het Welkomstvenster (Welkomstvenster komt terug door Xcode opnieuw te "openen" als er geen venster is).
- In de map kan niet gewist worden (rm geeft "Operation not permitted"); `zip` in de map faalt → zip naar `$HOME` en kopieer. Achtergebleven tijdelijke bestanden: `zijz1u8F`, `zi3UFWDv` (kopieën van zips) — mogen weg (door Tijn).
- Na Run komt JoeToep naar voren (vaak in fullscreen op een eigen Space); breng Xcode eerst naar voren vóór je klikt. Run-knop ±(316,119), Stop ±(345,119), bestemming ±(850,119) op het ingebouwde scherm (schermafbeelding 1372x887).
- Escape op afstand komt niet altijd aan; F, spatie en klikken wel. Scrollen in instellingen: klik + pagedown. Het sync-logboek (Instellingen › Sync & devices › Activity) is het beste diagnosemiddel.
- Diagnose-truc die werkte: tijdelijk een DEBUG-paneel (SwiftUI-overlay met `session.recentLifecycle` + waar de webview hangt) of een JS-logregel in de pagina (`window.JOETOEP_DEBUG`, functie `dbg()` in playbackControls.js staat er nog, doet niets zonder vlag). Altijd weer verwijderen vóór oplevering.
- JS-tests (jsdom) in de VM: kopieer `Scripts`, `JoeToep`, `package.json` naar `$HOME/jt/proj`, `npm install jsdom@26.1.0`, dan `node Scripts/test_bridge.mjs`, `test_media_compatibility.cjs`, `test_v15_scripts.cjs`, `test_v17_scripts.cjs`, `test_v231_scripts.cjs` (laatste stand: 17 / 134 / 12 / 13 / 11 groen; de "Uncaught … querySelector" in v15 is oud en onschuldig).
- Swift: SWIFT_VERSION 5, strict concurrency minimal; nieuwe bestanden worden automatisch meegenomen (PBXFileSystemSynchronizedRootGroup). Closures van DispatchWorkItem/errorHandlers: `MainActor.assumeIsolated { … }` gebruiken.

## 5. Architectuur (kern)
- `JoeToep/Browser/WebSession.swift` (±2.900 regels): één WKWebView per tab, bridge-events (`handle(_ event:)`), fullscreen/PiP-logica, auto-fullscreen (`fulfillAutomaticFullscreen`), `installUserScripts()` (welke JS waar en wanneer), lifecycle-log (`recordLifecycle`, 16 regels; zichtbaar in Instellingen).
- `Browser/WebContentView.swift`: houder van de webview; Mac `WebHostNSView` (V23.1) zet een losgeraakte webview terug.
- JS in `JoeToep/Resources/` (page-world tenzij anders): `mediaCompatibility.js` (PiP/fullscreen/achtergrond-bescherming, "quiet"-logica, `JoeToepMedia`), `playbackControls.js` (toetsen, vegen, volume-HUD, Mac-fullscreen-klikken, `JoeToepControls`), `sitePreferences.js` (donker, ondertitels uit, theater → auto-fullscreen, hervatten), `playerBridge.js` (bridge-world, meldt status aan de app), `videoStage.js` (eigen "veilige" fullscreen), `adShield.js`, `sponsorBlock.js`, `qualityBridge.js`, `siteChrome.js`, `phoneLayout.js` (V23.1, iPhone documentStart), `privacyShield.js`, `cookieConsent.js`, `webPiP.js`, `creatorTools.js`, `findInPage.js`, `linkBridge.js`.
- `Support/`: `MacNavigationMonitor.swift` (lokale event-monitors: Esc, F, dubbelklik, vegen, V23.1-klikdoorgave), `MacFullscreenFitGuard.swift` (fullscreen 100 %), `GestureScrubber.swift` (native vegen), `OrientationCoordinator.swift` (iPhone-rotatie), `TabSyncService.swift` (MultipeerConnectivity-sync, appTag, outbox), `LiveActivityManager`, `WidgetBridge`, `WatchBridge`, `SpotifyController`, `JoeToepMediaCompatibility.m` (private WebKit-voorkeuren via runtime-checks).
- Instellingen: `Models/AppSettings.swift` + `SettingsSnapshot.swift` (WebSession gebruikt de snapshot), losse `@AppStorage`-sleutels in `Views/V20Settings.swift` (o.a. `handoffAutoResumeV21`, `autoRotateFullscreenV231`); uitleg/zoekindex in `Views/SettingHelp.swift` (help-tekst, pagina, advancedOnly).

## 6. Belangrijke technische inzichten (niet opnieuw uitzoeken)
- **Mac fullscreen = WebKit element-fullscreen** van `<html>` (YouTube) in een apart venster `WebCoreFullScreenWindow` (macOS 27). JoeToep mag dat venster **nooit** zelf omschakelen (`toggleFullScreen`) — dat brak WebKit's terugweg en gaf een zwarte tab. Helper: `NSWindow.isWebKitFullScreenWindow`.
- **Gepauzeerde video in fullscreen**: macOS legt een VisionKit/Live Text-laag (`VKCImageAnalysisOverlayView` → `VKCImageSubjectHighlightView`, subview van de webview) over het beeld die alle klikken opslokt. Oplossing: MacNavigationMonitor geeft zulke klikken door aan `JoeToepControls.surfaceClick(clickCount)`. **`TextRecognitionInVideosEnabled` uitzetten laat het webproces vastlopen — niet doen.**
- Mac auto-fullscreen werkt via een echte F-toets naar de webview (YouTube's eigen handler), want script-fullscreen zonder gebaar wordt geweigerd. F is een aan/uit-knop: altijd eerst de pagina vragen of hij al fullscreen is.
- iPhone laadt in "desktopweergave" de desktop-YouTube (ytd-…); de UA bevat dan geen "iPhone" — gebruik de vlaggen `JOETOEP_MOBILE` / `JOETOEP_IPAD` (prefix van de scripts) i.p.v. de UA.
- YouTube dwingt Trusted Types af: geen `innerHTML`, alleen DOM-API's.
- Sync: alleen met JoeToep zelf (appTag); grote tab-verliezen worden geweigerd; sluit-markeringen > 7 dagen tellen niet; `tombstoneReset22_3` bracht oude iPhone-tabs terug.
- Hersteld/gesynct tabblad blijft "quiet" tot een echte gebaar op de speler (`JoeToepMedia.quiet`); een klik via de app moet `quiet(0)` aanroepen.

## 7. Korte versiegeschiedenis (details in CHANGELOG.md)
- **V10–V13**: PiP-stabiliteit (iPhone/iPad/Mac), Apple-streaming-engine optie, netwerk-herstel, direct typen in nieuwe tab, hervatten op dezelfde tijd, één-tik play/pauze op desktopsite.
- **V15**: hernoemd van HaloPlayer naar JoeToep; tabs (pinnen, samenvatting, privé), browserfuncties, PiP-terugknop → fullscreen, 6 adblock-niveaus, SponsorBlock, thema's, 43 iconen.
- **V16 / 16.2**: MRU-tabs, geforceerd herladen, zoeken op pagina, pauze in PiP blijft pauze, visualizer, geavanceerde animatie-instellingen; PiP-terugkeer in één stap.
- **V17 / 17.1**: complete media-browser (terug sluit tab, PiP op elke site, cookiebanners weigeren, trackers blokkeren, GPC, ruimtelijke audio, creator tools), ±1.750 regels Nederlandse code-uitleg, standaardbrowser (Mac), 153 iconen, nieuwe instellingenindeling.
- **V18**: live tab-sync (MultipeerConnectivity), Apple Watch-app, slimme PiP met meerdere schermen, snelheidsknoppen, downloads.
- **V19–19.3**: Ctrl+Tab, auto-fullscreen na theatermodus, native vegen/scrubben (trackpad/muis), apparaatwissel op de seconde, nooit vast in fullscreen, pauze ⇄ fullscreen, menubalk-vasthouden, iPad-sneltoetsen.
- **V20**: mediacentrum, Spotify-integratie, aanpasbare nieuwe-tab-pagina, bovenbalk auto-verbergen, 193 iconen.
- **V21**: automatisch verder spelen bij wisselen, "Verder op …", één balk / verticale zijbalk (Arc), zwevende zoekbalk met Tab-om-te-zoeken, 11 widgets, Liquid Glass.
- **V22–22.3**: sync-precisie, PiP ✕ = stoppen, fullscreen-opties, dashboard-overlay, widgets + Live Activity, Watch-uitbreiding; daarna veel stabiliteitsfixes (spook-overname, tabs verdwijnen, één venster, geen autoplay bij start, zuiniger sync), iPhone desktop-pagina past op het scherm.
- **V23.0**: fullscreen altijd 100 % (fit-guard), instelling "Switch devices automatically", volume-HUD, Live Activity robuuster (outbox, optimistische weergave), PiP na verlaten kijkpagina.
- **V23.1**: Mac-klikken in fullscreen (VisionKit-oorzaak), geen zwarte tab meer, sneller fullscreen/laden, iPhone-startpagina één kolom vanaf het eerste frame (`phoneLayout.js`), iPhone automatisch draaien bij fullscreen (ook met rotatievergrendeling).

## 8. Open punten (begin hier)
1. **iPhone op het toestel controleren** (in 23.1 niet zichtbaar geweest): startpagina in desktopweergave meteen één kolom zonder verspringen; automatisch naar landscape bij fullscreen en terug naar portrait — met rotatievergrendeling aan én uit; "rechtop = fullscreen uit" na zelf kantelen.
2. Mac: bij starten wordt een herstelde video soms direct in fullscreen en gedempt geopend (bestond al vóór 23.1).
3. Fullscreen op BenQ/HP-monitor na monitorwissel/slaapstand (fit-guard; lifecycle "fullscreen fit") — nog nooit op die schermen getest.
4. Live Activity-knoppen met een video op de Mac terwijl de iPhone vergrendeld is.
5. Live tab sync op iPhone/iPad controleren (Instellingen › Sync & devices) en of oude iPhone-tabs terugkwamen.
6. "Continue on"/"Play here" Mac ⇄ iPad en de 8-s-terugval testen; Watch apart testen.
7. UI-tests: Mac vond het venster niet onder computer-use-besturing; iPhone pas na het weghalen van één app (profiel vol). In het schema staan UI-tests uit (`skipped = "YES"`).
8. Opruimen: `Views/DebugHUD.swift` (leeg) mag weg.

## 9. Wat ik nu van je wil
[Zet hier je wensen voor de volgende versie.]

Begin met: map- en computer-use-toegang vragen (Documents/Claude en DerivedData; JoeToep, Xcode-beta, Device Hub), `CHANGELOG.md` en `Docs/HANDOFF-V24.1.md` lezen, een nieuwe versiemap maken, en daarna zelfstandig werken: bouwen en uitvoerig testen op Mac, iPhone en iPad, CHANGELOG bijwerken, zip opleveren en afsluiten met een korte Nederlandse samenvatting.
