# V15 — 15.0.0 (15)

**Naam en project**
- Alle oude "HaloPlayer"-namen vervangen door JoeToep: mappen (`JoeToep/`, `JoeToepTests/`, `JoeToepUITests/`), targets, module, bestanden, Objective-C-functies (`JT…`), JavaScript-globals (`JoeToepMedia`, `JoeToepBridge`, …) en berichtnamen. Alleen de bundle-ID's van de twee test-targets blijven `nl.tijn.haloplayer.(ui)tests`: een gratis Apple-team mag maar 10 nieuwe App-ID's per week aanmaken.

**Tabs**
- Tabs gebruiken de volle breedte tot de +-knop; bij veel tabs krimpen ze tot een leesbaar minimum en scrollt de strook. Vloeiende animaties bij openen, sluiten en wisselen.
- Automatische tab-samenvatting: korte titel van de video in een paar woorden (Apple Intelligence op het apparaat indien beschikbaar, anders een ingebouwde verkorter). Aan/uit en lengte instelbaar. Uit = volledige videotitel. Nooit meer alleen "YouTube".
- Tik op de actieve tab = adresbalk: typ een URL of zoekterm (zoekmachine instelbaar).
- Tabs vastzetten (pinnen): nooit automatisch gesloten, staan vooraan. Rechtsklik/lang indrukken op een tab: vastzetten, dupliceren, link kopiëren, delen, verplaatsen, sluiten, andere tabs sluiten, tabs rechts sluiten.
- Gesloten tabs heropenen (⌘⇧T of +-menu), privétabs (geen geschiedenis, cookies of cache).
- Video's/links: lang indrukken (iPhone/iPad) of rechtsklik (Mac) → bovenaan "Open in New Tab and Switch" en "Open in New Tab". ⌘-klik/middenklik opent een achtergrondtab. Achtergrondtabs tonen direct de echte videotitel (YouTube oEmbed) zonder de speler te laden.

**Browser**
- Andere websites openen in JoeToep (instelbaar), bladwijzers, geschiedenis (met zoeken en wissen), zoeken op pagina, delen, link kopiëren, openen in standaardbrowser, desktop/mobiele website per tab, zoom per tab, http-sites in webinhoud toegestaan.
- Nieuwe sneltoetsen: ⌘L, ⌘F, ⌘D, ⌘Y, ⌘[ ⌘], ⌘⇧[ ⌘⇧], ⌃Tab, ⌘1–9, ⌘⇧N, ⌘⇧T, ⌘+ ⌘− ⌘0.

**Picture in Picture en fullscreen**
- De terugknop rechtsboven in het PiP-venster brengt de video direct naar fullscreen en laat hem doorspelen; JoeToep vraagt fullscreen al aan zodra WebKit meldt dat PiP terug naar inline wil (iPad). Instelbaar: altijd fullscreen / waar PiP begon / inline, en "blijf afspelen".
- Mac: terugkeer uit PiP naar fullscreen werd soms overgeslagen door een verouderde `ytp-fullscreen`-klasse; nu directe aanvraag met controle en maximaal twee herhalingen. Kortere wachttijden ("Snelste overgangen").
- iPhone: "Directe rotatie" houdt de pagina zelf in portret, zodat draaien in één beweging naar liggend fullscreen gaat (en terug).
- Scherm blijft aan tijdens afspelen (instelbaar).

**Advertenties en SponsorBlock**
- Zes strengheidsniveaus (Minimaal → Maximaal): alleen cosmetisch, advertentieservers blokkeren, automatisch "Overslaan" drukken, meet-endpoints + niet-overslaanbare advertenties vooruitspoelen, advertentiedata uit de speler-respons verwijderen, feed-advertenties verwijderen + adblock-waarschuwingen sluiten.
- SponsorBlock ingebouwd (hash-prefix-API, privacyvriendelijk): per categorie overslaan/dempen/knop/alleen tonen/negeren, melding met Ongedaan maken, segmenten in de voortgangsbalk, minimale duur, eigen server, statistieken (overgeslagen segmenten, bespaarde tijd).

**Uiterlijk**
- Thema's (YouTube dark, OLED black, Graphite, Midnight, Deep ocean, Forest, Plum, Espresso, Light), 16 accentkleuren + eigen kleur, icoonstijl (outline/filled/circle/square), icoongewicht, icoonkleuring, tabvorm, tabtekstgrootte, sluitknoppen, tab-iconen, animatiestijl.
- Menubalk: drie extra maten net onder Large (Cozy, Medium, Roomy) — acht in totaal. Optionele bladwijzerknop en ⋯-browsermenu.
- 43 app-iconen (24 nieuw), kiesbaar via een raster. macOS-iconen staan nu op het officiële macOS-raster (afgeronde rechthoek met marge en schaduw) — geen te groot vierkant met rechte hoeken meer in het Dock.

**Overig**
- Instellingen opnieuw ingedeeld in pagina's; ondertekening/verloopdatum van het profiel zichtbaar.
- Dagelijkse geplande taak ververst de gratis signing automatisch vóór die verloopt (Mac moet wakker zijn met de Claude-app open).

# V13 — 13.0.0 (13)

- Play/pauze en fullscreen reageren op één tik op de desktopsite (iOS content-change-observer uit).
- Drie extra grotere menubalkmaten; inactieve tabs sluiten automatisch na een instelbare tijd (standaard 2 dagen).

# V12 — 12.0.0 (12)

- Mobiele YouTube-site: ook webkitVisibilityState/webkitHidden, document.hasFocus() en blur/pagehide/freeze/webkitvisibilitychange worden gemaskeerd zolang de beschermde video speelt of in PiP staat (mobiel YouTube stopt anders zelf bij achtergrondgebruik).
- Terugkeer uit PiP: geen tweede presentatie-aanvraag meer als AVKit al terugzet (verspringen opgelost); alleen bij terugkeer via het app-icoon met nog zichtbare PiP haalt JoeToep de video terug. Hoekenfix (V11) verwijderd.
- Nieuwe iPhone-instellingen: fullscreen verlaten bij terugdraaien naar portrait (video speelt inline door), optioneel YouTube-element-fullscreen i.p.v. Apple-speler.

# V11 — 11.0.0 (11)

- Nieuwe tab: direct typen in YouTube-zoekveld (iOS-toetsenbord via WebKit input-delegate-SPI); '/' focust zoeken op alle layouts.
- Verversen en herstart: video gaat verder op dezelfde tijd (positie per tab opgeslagen, t=-parameter + eenmalige hervatting).
- PiP: pauze door vergrendelen/ontgrendelen wordt éénmaal hersteld; expliciete pauze wint altijd.
- PiP-status die "actief" bleef zonder venster wordt na terugkeer hersteld vanuit de echte WebKit-status; lang indrukken herlaadt op dezelfde tijd als WebKit vastzit.
- Mac: Spatie toggelde dubbel (JoeToep + YouTube) — YouTube handelt Spatie nu zelf af; Enhanced-stage gebruikt de YouTube-player-API.
- Mac: tabwissel tijdens fullscreen liet "Click to Exit Full Screen" achter — fullscreen wordt eerst verlaten.
- iPhone: draaien naar landscape opent fullscreen (instelling).

# V10 — werkversie

## Update 26 september 2026 (Claude)

- Oorzaak "PiP stopt na enkele seconden" vanuit Apple-fullscreen verholpen: na het verlaten van de app werd nog een tweede paginaverzoek (na 1,8 s bridge-herhaling en 2,5 s watchdog-fallback) gestuurd. WebKit wachtte dan ~5 s op isPictureInPicturePossible en brak het lopende PiP-venster af. Fullscreen-PiP is nu volledig eigendom van iOS/AVKit.
- Geen zinloze inline-PiP-verzoeken meer na deactivatie op iPhone/iPad (AVKit weigert die; het gaf een korte PiP-flits en audiohik).
- PiP → app gaat in één stap terug naar de presentatie van vóór PiP (fullscreen blijft fullscreen, inline blijft inline); de standaard exitPictureInPicture-route die eerst inline landde is vervangen.
- Fullscreen kan niet meer onbereikbaar worden door een verouderde PiP-status.
- Lockknop-hapering: WebKit-instellingen worden niet meer gewijzigd tijdens lock/Home (dat stuurde een preferences-update naar het webproces precies tijdens de overgang). Zichtbaarheidsgebonden video-onderbreking uitgeschakeld.
- MediaUserGestureInheritsFromDocument/MainContentUserGestureOverride via runtime-gecontroleerde WebKit-C-API.
- Optionele Apple-streaming-engine (standaard uit): zonder MediaSource levert YouTube 360p als URL-stream; dan werkt AirPlay met beeld en een vooraf klaargezette native AVKit-PiP-speler voor inline video.
- Cmd , opent Instellingen (Mac en iPad met toetsenbord).
- Mac/iOS: tijdelijke netwerk- en DNS-fouten worden tot drie keer stil opnieuw geprobeerd (0,8/2,5/6 s); een melding verschijnt pas daarna. Een echte offline→online-overgang herstart het herstel.


- V9-voorkeuren, tabs, vensters, Enhanced fullscreen, sneltoetsen en 19 iconen geïntegreerd.
- Tabs en geselecteerde tab atomair opslaan en herstellen; alleen YouTube-adressen worden hersteld.
- PiP lang indrukken reset presentatie; exclusief gebaar voorkomt een extra klikactie.
- PiP-terugkeer vraagt direct Apple-fullscreen aan in plaats van eerst inline te gaan.
- Reeds actieve PiP wordt bij deactivatie niet opnieuw bewapend; dit beperkt overbodige audio-/presentatiewijzigingen bij vergrendelen. Audiocontinuïteit is nog niet gemeten.
- AirPlay-routekiezer hoort nu bij het video-element, met externe video toegestaan en LongFormVideo als initiële en actieve route-policy.
- Cmd R en begrensd netwerkherstel; nieuwe navigatie annuleert oud herstel, fouten uit een loginvenster herladen de hoofdspeler niet.
- Eén Settings/login-sheet voorkomt concurrerende presentaties.
- Mac automatisch fullscreen gebruikt een native F-aanvraag na éénmalig 0,5 seconde pagina-initialisatie; eenmalige aanvraag vervalt bij gewijzigde video, pauze, achtergrond of uitgeschakelde voorkeur.
- Testvideo verlengd tot 96 seconden voor zinvolle seek-controles.

Bekend open: automatische inline-PiP op iPhone. Geen garantie dat JoeToep exclusieve systeemonderbrekingen door andere apps kan overnemen.
