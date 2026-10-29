# V15 testverslag — 26 september 2026

Xcode 27 beta · iPhone 13 Pro (iOS 27) · iPad Pro 12,9" 2e gen (iPadOS 17.7.11) · MacBook Pro (macOS 27). Alle tests draaiden onbeheerd (gebruiker afwezig).

| Controle | Resultaat | Toelichting |
|---|---|---|
| Hernoemen HaloPlayer → JoeToep | Geslaagd | Mac en iOS bouwen en starten; schema, targets, module en tests hernoemd |
| Mac build + start | Geslaagd | Tabs, adresbalk, zoeken, rechtsklik "Open in New Tab (and Switch)", instellingenpagina's, thema's (incl. Light), SponsorBlock-status live gecontroleerd |
| iPhone build + start | Geslaagd | V15 geïnstalleerd |
| iPad build + start | Geslaagd | V15 geïnstalleerd |
| Mac unit-tests (incl. 12 nieuwe V15-tests) | 50 geslaagd | Samenvatting/titels, adresbalk, adblock-niveaus + migratie, SponsorBlock, instellingen, maten, kleuren, bladwijzers/geschiedenis, vastgezette tabs |
| iPhone: PiP-terugknop → direct fullscreen, blijft spelen | **Geslaagd (2×)** | Echte systeem-PiP; knop "Restore fullscreen" in het PiP-venster ingedrukt; status bemonsterd elke 80 ms: geen inline-tussenstap, fullscreen + play=1 |
| iPhone: landscape → fullscreen → portrait → inline | Geslaagd (losse run) | 3 cycli, ~0,6–0,8 s tot fullscreen en ~0,2–0,5 s terug (incl. meetvertraging van de test); video blijft spelen. In de volledige suite blokkeerde XCTest 60 s op "app idle" tijdens fullscreen (testinfrastructuur, geen app-fout; beelden bevestigen fullscreen) |
| iPhone: bestaande PiP-tests (handmatig, fullscreen→Home, 5 cycli, Camera, lang indrukken reset, AirPlay-kiezer) | Geslaagd | Uitgezonderd de bekende WebKit-beperking inline-auto-PiP met MediaSource (nu gemarkeerd als verwachte fout) |
| iPhone: tabs-, adresbalk-, instellingen-UI-tests | Gecorrigeerd | Tests aangepast aan nieuwe tabbalk en instellingenpagina's |
| iPad XCTest | Geblokkeerd | Xcode 27-testrunner crasht op de A10X (illegale `casal`-instructie in lib_TestingInterop); de app zelf draait wel. PiP-terugkeer op iPad dus niet automatisch te bewijzen — code-pad: `_webViewFullscreenMayReturnToInline` vraagt fullscreen aan zodra WebKit terug naar inline wil |
| Mac UI-tests | Niet onbeheerd uit te voeren | macOS vraagt bij UI-tests om Automation Mode-authenticatie (wachtwoord/Touch ID) |
| JavaScript DOM-regressies | 113 geslaagd | +3 nieuwe PiP-terugkeer-scenario's |
| JavaScript bridge | 17 geslaagd | |
| Projectvalidatie | 11 poorten geslaagd | Aangepast aan thema's, iconen (macOS RGBA) en web-view-subklasse |

Bekende beperkingen (WebKit/iOS, niet op te lossen in de app): korte audiohapering bij PiP-start vanuit fullscreen en bij de lockknop; inline-video start geen automatische PiP met MediaSource; Now Playing gaat naar de app die het laatst begon met afspelen (iOS/macOS-regel).

# V10 testverslag — tussenstand 22 september 2026

Dit verslag onderscheidt echte apparaten, simulaties en nog open werk. V10 is niet definitief goedgekeurd.

| Controle | Resultaat | Bewijs / beperking |
|---|---|---|
| Mac native unit-tests | 36 geslaagd | MacNativeSept22.xcresult; inclusief fullscreen-bridge |
| iPhone 17 Pro simulator native tests | 36 geslaagd | SimulatorSept22.xcresult; geen fysieke PiP-proef |
| Mac UI-regressies | 11 geslaagd | 10 in MacClickSuite.xcresult, plus uitgebreide toetsen/seek/volumetest in MacKeyboardNoon.xcresult |
| JavaScript bridge/kwaliteit | 17 geslaagd | Gesimuleerde browser/media-API's |
| DOM-regressies | 98 geslaagd | Inclusief toetsen/trackpad, fullscreenaanvraag en stresslussen; OS-API's gesimuleerd |
| Contentfilters | 25 geslaagd | Lokale HTML/URL-fixtures |
| Projectvalidatie | 11 geslaagd | Statische controles, inclusief fullscreen-bridge |
| Swift-grammatica | 52 bestanden geslaagd | Geen Apple SDK-typecontrole |
| Mac Release-build | Geslaagd | Ondertekende productieconfiguratie |
| iOS/iPadOS Release-build | Geslaagd | Ondertekende universele iOS-app, geen apparaattest |
| iPhone handmatige PiP en fullscreen→Home | Geslaagd | Echte systeem-PiP zichtbaar na 8 seconden |
| iPhone 5 fullscreen→Home→app-cycli | Geslaagd | PhoneStress.xcresult; lokale video |
| iPhone Camera tijdens PiP | Zichtbaar beeld behouden | Screenshot na Camera toont gekleurde video, geen zwart vlak; audio niet doorgemeten |
| iPhone sessieherstel tabs | Geslaagd | 3 tabs→herstart→3; sluit 1→herstart→2 |
| iPhone AirPlay-routekiezer | Visueel bevestigd | Video en Mac/TV-ontvangers zichtbaar; nog geen overdracht naar ontvanger bewezen |
| iPhone automatische inline-PiP | **Mislukt** | PhoneScene.xcresult; systeemvenster ontbreekt na zes seconden |
| iPad build en normale appstart | Geslaagd | Fysieke iPad iOS 17.7.11 |
| iPad XCTest | Geblokkeerd | Xcode 27 beta runner crasht vóór testbootstrap in XCTInteropHandlerInstaller |
| Mac uitgebreide toetsen-UI-test | Geslaagd | MacKeyboardNoon.xcresult; 5/30/60 seconden, 65/70% volume, spatie play/pauze |

## Actuele blokkades en open tests

De Mac is beschikbaar en de iPad is bekabeld/ontgrendeld. De draadloze iPhone-verbinding valt terug naar CoreDevice-verbindingsfouten; een kabel is gevraagd. Het experiment met fullscreenvoorbereiding 250 ms vóór PiP is inmiddels fysiek getest en mislukt, en weer verwijderd.

Nog te testen: herhaald inline/mobile-YouTube PiP; daadwerkelijke video-AirPlay naar Mac; lock/unlock zonder hoorbare audio-overgang; live-YouTube regressies; fysieke iPad-PiP; iconen op apparaten; uitgebreide netwerkovergangen, energiegebruik en lange stresstests.

Mac automatisch fullscreen is nu met live YouTube (officiële Big Buck Bunny-video) visueel bevestigd. De native F-aanvraag wacht éénmalig 0,5 seconde op pagina-initialisatie; daarna vult alleen het videobeeld het scherm. Handmatig F is als vergelijking getest. Meer verschillende video’s en herhaalde navigaties blijven onderdeel van de eindcontrole. Deze korte opstartwachttijd geldt alleen voor Mac-fullscreen, niet voor PiP.

Tests liepen met Xcode 27 beta, iPhone 13 Pro met iOS 27 beta en iPad Pro 12.9 tweede generatie met iOS 17.7.11. Ruwe apparaatlogs en screenshots blijven lokaal buiten de oplevering wegens privé-inhoud. Een PiP-status uit JavaScript geldt niet als bewijs van een zichtbaar systeemvenster.

## Aanvullende fysieke iPhone-tests op 22 september

- **PiP-reset geslaagd:** tweemaal langer dan 0,3 seconde indrukken, daarna Home; systeem-PiP bleef zichtbaar na acht seconden (PhoneUnlockedSept22.xcresult).
- **Inline-PiP opnieuw mislukt:** originele route, 250 ms fullscreenvoorbereiding en nieuwe videorouteconfiguratie leverden geen blijvend zichtbaar PiP-venster op. De falende tests blijven behouden.
- **Fullscreen-PiP geslaagd met videorouteconfiguratie:** PhoneVideoRoutingSept22.xcresult, zichtbaar na acht seconden.
- **AirPlay-kiezer visueel en via systeemhiërarchie vastgelegd:** PhoneAirPlayRoutesSept22.xcresult. Een daadwerkelijke overdracht naar Mac met beeld én geluid is nog niet uitgevoerd. De extra geautomatiseerde kiezer-assertie is toegevoegd op basis van de vastgelegde hiërarchie; nog opnieuw uitvoeren.

De app declareert nu `AVInitialRouteSharingPolicy=LongFormVideo` en configureert dezelfde AVAudioSession-policy vóór WebKit. Dit volgt [Apple’s videoroute-documentatie](https://developer.apple.com/documentation/avfaudio/avaudiosession/routesharingpolicy-swift.enum/longformvideo); de policy alleen bewijst geen geslaagde video-overdracht.

## Laatste weekquotum: iPhone-stresstest

PhoneFinalWeekStress.xcresult is geslaagd met de nieuwste videorouteconfiguratie: vijf fullscreen→Home→app-cycli, daarna Camera en opnieuw zichtbaar systeem-PiP. Ook de expliciete systeemcontrole op de AirPlay-routekiezer slaagt. Dit bevestigt geen automatische inline-PiP, daadwerkelijke AirPlay-overdracht of hoorbaar onderbrekingsvrije audio. Die punten blijven open.

## Update 26 september 2026 — Claude

**Onderzoek (WebKit iOS 27, 24A437):** automatische PiP start in WebKit alleen via een voorbereide AVKit-presenter in *standby* of fullscreen (`VideoPresentationInterfaceAVKitLegacy::mayAutomaticallyShowVideoPictureInPicture`: `isPlaying && (m_standby || fullscreen)`). Standby wordt uitsluitend gezet door `WebFullScreenManager::setPIPStandbyElement` tijdens element-fullscreen. Een kleine inline-video met MediaSource kan daardoor niet automatisch naar PiP; dit verklaart waarom de desktopsite (element-fullscreen) consistenter was. De eerdere native log (PiP 0,09 s actief na deactivatie; tweede verzoek eindigt na ~5 s) past hierbij.

**Gebruikerskeuze:** altijd 1080p (MediaSource). Zonder MediaSource levert YouTube in WKWebView alleen een 360p-URL-stream (op simulator gemeten, ook met een Safari 16-useragent). De Apple-streaming-engine (AirPlay met beeld + native inline-PiP-presenter) is daarom optioneel en standaard uit.

| Controle | Resultaat | Bewijs / beperking |
|---|---|---|
| iOS-simulator Debug-build (iPhone 17 Pro, iOS 27) | Geslaagd | Clean build, 2 bestaande waarschuwingen |
| Mac Debug-build | Geslaagd | Niet gestart: JoeToep was in gebruik op de Mac |
| JavaScript bridge + DOM | 17 + 102 geslaagd | Nieuwe tests: geen inline-verzoek na deactivatie, directe PiP→fullscreen, inline-PiP keert inline terug, fullscreen altijd bereikbaar, native presenter-overdracht |
| Contentfilters / projectvalidatie | 25 / 11 geslaagd | Validatie aangepast aan nieuwe fullscreen-PiP-eigendom |
| Simulator live YouTube zonder MediaSource | Speelt | 360p progressieve googlevideo-URL; simulator meldt PiP niet ondersteund |
| SPI-configuratie | Actief | InterruptVideoOnPageVisibilityChange=0, MediaUserGestureInheritsFromDocument=1, MainContentUserGestureOverride=1 |
| Fysieke iPhone/iPad | **Niet uitgevoerd** | Xcode had geen Apple-account ("No Accounts / No profiles"); gebruiker gevraagd in te loggen |

**Nog fysiek te testen:** fullscreen→Home→PiP met live mobiele YouTube in herhaalde rondes (verwacht beter door het verwijderde tweede verzoek), PiP→app zonder sprong, lock tijdens PiP zonder hapering, Mac Cmd , en netwerkherstel.

## V11/V12 — 26 september 2026 (Claude)

| Controle | Resultaat | Bewijs / beperking |
|---|---|---|
| Fysieke iPhone 13 Pro (iOS 27): fullscreen→Home→PiP (V10-fix) | Geslaagd | Gebruikerstest; PiP bleef spelen |
| iPhone lock tijdens PiP | Korte hapering blijft | WebKit onderbreekt video+audio bij "suspended under lock" zonder PiP-uitzondering (HTMLMediaElement::shouldOverrideBackgroundPlaybackRestriction). Eenmalig herstel toegevoegd; volledig vermijden niet mogelijk vanuit de app |
| iPhone PiP→fullscreen ronde hoeken | Blijft (systeemanimatie) | AVKit-terugkeeranimatie; V11-hoekenfix verwijderd omdat die verspringen gaf |
| Mac Spatie pauze/afspelen | Geslaagd | Live YouTube; frames vergeleken |
| Mac ⌘, / ⌘T typen / '/' | Geslaagd | Live |
| Mac ⌘R en herstart hervatten | Geslaagd | 30:25→30:41 na ⌘R; herstart hervat op 31:53 |
| Mac tabwissel tijdens fullscreen | Gerepareerd, geslaagd | Geen "Click to Exit Full Screen" meer |
| JavaScript | 17 + 110 geslaagd | Nieuwe V11/V12-scenario's |
| iPad Pro 12.9 (iOS 17.7.11) | Niet geïnstalleerd | Xcode 27: CoreDeviceError 3 enablePersonalizedDDI; oude installatie "no longer available" (profiel) |
| V12 mobiele-site PiP, portrait-exit, element-fullscreen | In gebruikerstest | — |
