# Build report V25 — 25.0.0 (37), 29-10-2026

| Platform | Gebouwd/geïnstalleerd | Getest |
|---|---|---|
| Mac (M1 Max, ingebouwd scherm) | ja — Debug, Run vanuit Xcode, geen fouten (6 oude waarschuwingen) | klik = pauze/afspelen in fullscreen (elk precies één keer), dubbelklik = eruit (blijft spelen), Esc, F in/uit, Esc tijdens de ingang, 3× snel F in/uit + dubbelklik, YouTube's fullscreen-knop → telkens netjes inline; 5 s fullscreen op het ingebouwde scherm (notch) zonder uit-en-weer-aan |
| iPhone 13 Pro "eiFoon" (kabel, iOS 27.2) | ja — "Running JoeToep on eiFoon" | scherm niet zichtbaar (Device Hub: microfoon/camera actief) → handmatige test door Tijn |
| iPad Pro 2e gen. | nee | — |

Opvallend: bij het starten vanuit Xcode kwam de herstelde (gepauzeerde) video op de Mac direct in fullscreen terug — bestaand open punt uit 23.1, nog niet opgelost.

JS (jsdom): bridge 17, mediaCompatibility 134, V15 12, V17 13, V23.1 11, V24 10, **V25 13 (nieuw; 7 daarvan falen op 24.0 = bug nagebootst)** — alles groen.
Swift: grammaticacontrole (tree-sitter) van alle gewijzigde bestanden zonder fouten; geen Apple-SDK-typecontrole mogelijk zonder Xcode. `V25FeatureTests` staat klaar voor ⌘U.

Eerstvolgende stap: in het open Open-paneel `JoeToep.xcodeproj` kiezen (het paneel staat al in de juiste map: die heette JoeToep-V23.1 en heet nu JoeToep-V25), dan Run op Mac en eiFoon, unit tests, en op de iPhone: herstelde tab → fullscreen → ▶/❚❚ (met Mac tegelijk aan), en op de Mac: Esc/F/dubbelklik/knop op het ingebouwde scherm, BenQ en HP.

# Build report V24 — 24.0.0 (36), 15-10-2026

| Platform | Gebouwd/geïnstalleerd | Getest |
|---|---|---|
| Mac (M1 Max, macOS 27.2) | **nog niet** — Xcode-beta 27.0 b3 vroeg eerst "Install Required" (systeemcomponenten, apart proces; door Tijn geïnstalleerd) en het V24-project staat niet in de recente lijst; het Open-paneel mag niet bediend worden | crash-oorzaak vastgesteld uit 7 crashrapporten (14–15 okt); code-review van alle singletons en geforceerde indexen |
| iPhone 13 Pro "eiFoon" (kabel) | nog niet (zelfde reden) | — |

JS (jsdom): bridge 17, mediaCompatibility 134, V15 12, V17 13, V23.1 11, **V24 8 (nieuw, incl. 1.000 cycli)** — alles groen.
Swift: nieuwe unit tests `V24FeatureTests` staan klaar voor de eerstvolgende test-run (⌘U vanuit Xcode).

Eerstvolgende stap: project openen uit `~/Documents/Claude/JoeToep-V24`, Run op Mac en eiFoon, unit tests draaien, en de iPhone-rotatie met/zonder rotatievergrendeling bekijken.

# Build report V23.1 — 23.1.0 (35), 13-10-2026

| Platform | Gebouwd/geïnstalleerd | Getest |
|---|---|---|
| Mac (M1 Max, macOS 27.2) | ja (Debug, Run vanuit Xcode, "Build succeeded") | fullscreen-klikken uitvoerig: pauze → klik speelt, klik pauzeert (4×), dubbelklik vanuit spelen én vanuit pauze verlaat fullscreen en houdt de stand, reeks van 6× F/dubbelklik in- en uitgaan → tab nooit meer zwart; oorzaak gemeten met een tijdelijk diagnosepaneel (VisionKit-laag `VKCImageAnalysisOverlayView` in `WebCoreFullScreenWindow`) |
| iPhone 13 Pro "eiFoon" (iOS 27.2) | ja (draadloos, "Running JoeToep on eiFoon") | scherm niet te bekijken: Device Hub meldde "Screen unavailable (microfoon/camera actief)" |
| iPad Pro 2e gen. (iPadOS 17.7) | ja ("Running JoeToep on Tijn's iPad") | geen schermweergave mogelijk (A10X) |

JS (jsdom): nieuw `test_v231_scripts.cjs` 11/11 (o.a. 2.000-kliks stresstest), bridge 17, mediaCompatibility 134, V15 12, V17 13 — alles groen.

Niet getest: iPhone-startpagina en automatisch draaien op het toestel zelf (scherm niet beschikbaar), Watch.

# Build report V23 — 23.0.0 (34), 12-10-2026

| Platform | Gebouwd/geïnstalleerd | Getest |
|---|---|---|
| Mac (M1 Max, macOS 27.2) | ja (Debug, Run vanuit Xcode) | unit tests 128/128 groen (na bijwerken van 2 verouderde tests); handmatig: volume-HUD bij veeg (100 % → 40 % → 100 %), fullscreen vult het ingebouwde scherm, 4× app-wissel tijdens fullscreen-video → PiP-paneel verschijnt en video keert terug in fullscreen, nieuwe instelling aan/uit met uitleg |
| iPhone 13 Pro "eiFoon" (iOS 27.2) | ja (draadloos) | unit tests 128/128 groen op het toestel; app draait. UI-tests konden niet: gratis ontwikkelaarsprofiel zit aan het maximum van 3 apps (JoeToep + Murmur + Murmur-testrunner); Device Hub toont het scherm alleen (geen aanraking) |
| iPad Pro 2e gen. "Tijn's iPad" (iPadOS 17.7) | ja | app start; geen schermweergave/XCTest mogelijk (A10X) |
| Apple Watch | meegebouwd met de iPhone-app | niet apart getest |

UI-tests op de Mac (29): 15 overgeslagen (alleen iOS), 14 mislukt op het allereerste element — het testvenster verscheen niet onder computer-use-besturing (zelfde soort verstoring als in V17.1). Geen inhoudelijke fout gevonden; bij gewone start opent het venster normaal.

JS: bridge 17 scenario's, mediaCompatibility 134 scenario's, V15 12/12, V17 13/13 (jsdom). Project- en Swift-grammaticacontrole: geen nieuwe meldingen.

Niet te testen in deze sessie: fullscreen op de BenQ/HP (venster kon niet naar een ander scherm worden gesleept), sync tussen apparaten ("Live tab sync" stond uit op de Mac — nu aan — en op iPhone/iPad niet te bedienen), Live Activity-knoppen (geen aanraking op de iPhone mogelijk).
