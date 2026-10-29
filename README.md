# JoeToep — 25.1.0 (38)

Open-source persoonlijke YouTube-browser en -speler voor **Mac**, **iPhone** en **iPad** (plus Apple Watch, widgets en Live Activity), gebouwd met SwiftUI en WKWebView. Tabs en afspeelpositie synchroniseren live tussen je apparaten; Picture in Picture, fullscreen (met automatisch liggend op de iPhone) en een Arc-achtige zoekbalk zijn tot in detail uitgewerkt.

- **Wat er nieuw is:** [`CHANGELOG.md`](CHANGELOG.md) · **alle versies:** [`Docs/VERSIEGESCHIEDENIS.md`](Docs/VERSIEGESCHIEDENIS.md) (elke versie staat in een eigen branch `versie/vX.Y`)
- **Bijdragen:** [`CONTRIBUTING.md`](CONTRIBUTING.md) · **licentie:** MIT ([`LICENSE`](LICENSE))
- **Voor Claude/AI-sessies:** [`CLAUDE.md`](CLAUDE.md), nieuwste overdracht [`Docs/HANDOFF-V26.md`](Docs/HANDOFF-V26.md), chatgeschiedenis in [`Docs/chatgeschiedenis/`](Docs/chatgeschiedenis/)

## Bouwen

1. Open `JoeToep.xcodeproj` in Xcode (26 of nieuwer).
2. Kies scheme **JoeToep**, je apparaat (My Mac, iPhone of iPad) en je eigen Signing Team. Pas zo nodig `JOETOEP_BUNDLE_ID` (standaard `nl.tijn.JoeToep`) en de App Group aan.
3. Run. Alle apparaten moeten dezelfde app-build draaien om te kunnen syncen.

Snelle checks zonder Xcode: `node Scripts/test_media_compatibility.cjs` (en andere `Scripts/test_*.cjs`) en `python3 Scripts/validate_project.py`.

## Projectstructuur

| Map | Inhoud |
|---|---|
| `JoeToep/Browser` | `WebSession` (één tab: WKWebView, PiP, fullscreen, herstel), webview-hosting |
| `JoeToep/Views` | SwiftUI-schermen: werkruimte/tabs (`BrowserWorkspace`), instellingen, overlay, zijbalk |
| `JoeToep/Support` | Sync (`TabSyncService`), widgets/Watch-brug, Live Activity, Spotify, oriëntatie |
| `JoeToep/Models` | Datamodellen (sync-snapshots, bibliotheek, tabopslag) |
| `JoeToep/Resources` | Geïnjecteerde scripts (`mediaCompatibility.js`, `sitePreferences.js`, …) |
| `JoeToepWidgets`, `JoeToepWatch`, `JoeToepWatchWidgets` | Widgets, Watch-app en complicaties |
| `JoeToepTests`, `JoeToepUITests`, `Scripts` | Tests en validatie |
| `Docs` | Runbook, testplan, buildrapport, overdrachten, versiegeschiedenis |


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
