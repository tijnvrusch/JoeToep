# JoeToep V17.1 — 17.1.0 (21)

Persoonlijke YouTube-browser voor Mac (macOS 27), iPhone 13 Pro (iOS 27) en iPad Pro 12,9" 2e generatie (iPadOS 17). Open `JoeToep.xcodeproj`, kies scheme **JoeToep**, je apparaat en je Signing Team (app-ID `nl.tijn.JoeToep`). Zie `CHANGELOG.md` voor alles wat nieuw is en `Docs/BUILD_REPORT.md` voor de testresultaten.

## Signing (gratis Apple-team)

Een gratis team ondertekent 7 dagen; daarna meldt iOS "This app is no longer available". Settings toont bovenaan hoe lang de huidige build nog geldig is. Een dagelijkse geplande taak in Claude herbouwt de app vanuit Xcode op iPhone en iPad zodra het profiel binnen 30 uur verloopt (Mac wakker, Claude-app open, apparaten via kabel). Alleen het betaalde Apple Developer Program (1 jaar geldig) maakt dit overbodig.

## Bediening

- **Tabs**: vullen de breedte tot de +-knop en krimpen bij veel tabs. Tik op de actieve tab om een adres of zoekterm te typen. Rechtsklik/lang indrukken op een tab: vastzetten, dupliceren, delen, sluiten. Vastgezette tabs sluiten nooit automatisch.
- **Links en video's**: lang indrukken (iOS) of rechtsklik (Mac) → "Open in New Tab and Switch" / "Open in New Tab". ⌘-klik of middenklik = achtergrondtab.
- **PiP-knop**: tik = PiP aan/uit, 0,3 s vasthouden = PiP resetten. De terugknop in het PiP-venster gaat direct naar fullscreen en blijft afspelen.
- **⋯-menu**: nieuwe (privé)tab, gesloten tab heropenen, bladwijzers en geschiedenis, zoeken op pagina, delen, desktop/mobiele site, zoom.

## Sneltoetsen (Mac en iPad met toetsenbord)

| Toets | Actie |
|---|---|
| ⌘T / ⌘⇧N / ⌘⇧T | Nieuwe tab / privétab / gesloten tab heropenen |
| ⌘W / ⌘⇧W / ⌘N | Tab sluiten / venster sluiten / nieuw venster |
| ⌘L | Adresbalk |
| ⌘F | Zoeken op pagina |
| ⌘D / ⌘Y | Bladwijzer / bladwijzers en geschiedenis |
| ⌘[ / ⌘] | Terug / vooruit |
| ⌘⇧[ / ⌘⇧], ⌃Tab | Vorige / volgende tab |
| ⌘1…⌘9 | Tab 1–8 / laatste tab |
| ⌘R / ⌘, | Herladen / instellingen |
| ⌘+ / ⌘− / ⌘0 | Zoom |
| ⌥Z | PiP wisselen |
| Spatie, ←/→, ⌥←/→, ⌘⌥←/→, ↑/↓ | Play/pauze, 5 s, 30 s, 60 s, volume ±5% |

## Standaarden

| Instelling | Mac | iPad | iPhone |
|---|---|---|---|
| Resolutievoorkeur | 4K | 1080p | 1080p |
| Website | Desktop | Desktop | Mobiel |
| Fullscreen | YouTube | Apple-speler | Apple-speler |
| Adblock | 3 · Balanced | 3 · Balanced | 3 · Balanced |
| SponsorBlock | Sponsor overslaan | idem | idem |
| Tab-samenvatting | Aan, kort | Aan, kort | Aan, kort |
| Inactieve tabs sluiten | 2 dagen | 2 dagen | 2 dagen |
| Thema | YouTube dark, rood | idem | idem |

## Ontwikkeling

`npm ci --ignore-scripts && npm test` draait de DOM/bridge-regressies. Die simuleren Apple-media-API's en bewijzen geen native PiP.

Native tests: `xcodebuild -project JoeToep.xcodeproj -scheme JoeToep -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:JoeToepTests test` (unit tests). UI- en apparaattests: `JoeToepUITests` en `JoeToepUITests/V15DeviceTests` (PiP-terugknop, 8× PiP-cycli, pauze in PiP, nieuwe tab houdt PiP, rotatie, stress).

Python-controles: installeer `Scripts/requirements-dev.txt` in een virtualenv, voer vervolgens `Scripts/validate_project.py`, `Scripts/test_content_filters.py` en `Scripts/validate_swift_syntax.py` uit. `Scripts/generate_fixture.sh` vereist ffmpeg en maakt een lokale video van 96 seconden. Er wordt geen YouTube-video gedownload.
