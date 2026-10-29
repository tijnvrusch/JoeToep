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
