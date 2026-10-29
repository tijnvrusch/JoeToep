# 22.1.0 (31)

## iPhone: pagina van rand tot rand (echt opgelost)
- Oorzaak gevonden met een meting op je iPhone zelf: de iPhone laadde de *desktop*-versie van YouTube. De kolom onder de video had daarin een minimale breedte van 443 px, breder dan je scherm van 390 px, en viel links en rechts ±18 px weg.
- In smalle vensters (< 760 px) krimpt die kolom nu tot de schermbreedte. De desktop-startpagina past weer precies op het scherm en staat altijd op "passend".

## Verder
- Tab-icoon: starten via het icoon wisselt nu ook echt naar die tab en gaat niet ineens fullscreen (instelbaar).
- Bij overnemen door een ander apparaat sluit de Mac altijd zijn PiP; er blijft geen "Playing in picture in picture"-placeholder meer staan.
- Getest via het live iPhone-scherm op de Mac:
  - PiP ✕ stopt de video, zonder fullscreen terug;
  - iPhone → Mac: de video speelt direct verder;
  - Mac → iPhone: de iPhone neemt over.

# 22.0.0 (30)

## Sync Mac ⇄ iPhone (topprioriteit)
- **Precies doorspelen na wisselen, ook als de iPhone naar de achtergrond gaat.** Vlak voordat de iPhone naar de achtergrond gaat (en zelf pauzeert), stuurt hij de exacte positie. Open je daarna JoeToep op de Mac, dan speelt dezelfde video daar verder op precies die seconde.
- **Geen verkeerde video meer.** Tabs die door de sync werden bijgewerkt, mogen 8 tot 20 s niet zelf gaan spelen (YouTube-autoplay, spoelen op een gepauzeerde speler). Dat gebeurde vroeger bij het openen van de Mac: een andere tab ging dan fullscreen spelen. Een echte klik of een JoeToep-opdracht start hem wel.
- Sneller en vaker bijgewerkt:
  - De positie wordt elke 0,5 s bijgehouden met verbonden apparaten.
  - De spelende tab wordt al vanaf 1 s verschil gedeeld.
  - Titelwijzigingen tellen ook mee.
  - Na terugkomst wordt direct (en na 0,6 en 1,5 s nog een keer) opnieuw verbonden.
  - Er wordt elke 2 s gezocht zolang er niets verbonden is.
- Het sluiten van een tab is meteen zichtbaar op het andere apparaat.

## Picture in Picture
- **✕ in het PiP-venster = stoppen** op alle platforms. De video blijft gepauzeerd, het PiP-venster verdwijnt en er komt géén fullscreen-video meer tevoorschijn.
- iPad: de terugknop in PiP gaat nu rechtstreeks naar fullscreen, zonder tussenstap via de kleine YouTube-speler.

## Fullscreen-opties (alle platforms)
- "Fullscreen wanneer een video laadt en start" (standaard aan): op een video klikken → meteen fullscreen.
- "Fullscreen wanneer je op play drukt" (standaard aan): een gepauzeerde video weer starten → fullscreen.
- "Fullscreen verlaten bij pauzeren" (nu standaard uit).

## iPhone
- De pagina staat weer precies van rand tot rand. Een te brede balk kan de layout niet meer oprekken en een hangende horizontale verschuiving wordt meteen hersteld; ook op de iPhone 13 Pro.

## Tabs slepen (Mac)
- De hele tab beweegt mee met de muis en de andere tabs schuiven opzij.
- Heel vergevingsgezind: te hoog, te laag of iets ernaast loslaten maakt niet uit. Hij snapt naar de dichtstbijzijnde plek.

## Nieuwe-tab-overlay
- Aanpasbaar dashboard:
  - platforms;
  - wat er nu speelt (met bediening, PiP en "verder op…");
  - je andere apparaten (play/pauze, +10 s, "hier spelen");
  - Spotify (shuffle, vorige, play/pauze, volgende, herhalen, volume);
  - snelle acties;
  - favorieten;
  - verder kijken;
  - open tabs.
- Met het schuifjes-icoon pas je het aan: blokken slepen (of pijltjes), oogje aan/uit, acties kiezen, aantallen instellen, compacte weergave. Het dashboard is ook uit te zetten.
- Zoeken op een platform vanuit een widget verandert je standaardplatform niet meer.

## Widgets en Live Activity
- Nieuw:
  - Afstandsbediening (±10/±30 s, alle apparaten, alles pauzeren);
  - Apparaat wisselen ("Hier" / "Stuur");
  - Voortgangsring;
  - Spotify compact (ook op het vergrendelscherm);
  - Spotify groot (hoes, voortgang, volume);
  - Dashboard;
  - Apparaten op het vergrendelscherm.
- Widgets tonen de videolengte en voortgang, en worden vaker ververst (max. elke seconde).
- **Live Activity** (iPhone/iPad): wat er waar speelt, op het vergrendelscherm, in het Dynamic Island en in de Smart Stack van je Watch. Met ±10/±30 s, play/pauze, "hier verder" en Spotify. De voortgang loopt vanzelf door.

## Apple Watch
- Live overzicht van al je apparaten (iPhone, Mac, iPad) met voortgang. Bediening per apparaat en "verder op …" (ook van Mac naar iPad).
- Spotify-bediening: vorige, play/pauze, volgende, shuffle, herhalen en volume.
- Zoeken (met recente zoekopdrachten), de home-feed, en downloads van je iPhone.
- **Downloads op de Watch.** Zet een iPhone-download (van websites, geen YouTube) op de Watch:
  - Handmatig, automatisch, of meteen met "download huidige iPhone-pagina".
  - Kwaliteit instelbaar: laag, 480p, 540p of alleen audio.
  - Daarna offline af te spelen op de Watch, met onthouden positie.
- **Complicaties:** Nu aan het spelen (met voortgang), Spotify, Apparaten en JoeToep-snelstart. Voor alle wijzerplaatvormen: rond, hoek, rechthoek en inline.
- Instellingen: kwaliteit, automatisch synchroniseren, "volg wat speelt" en de spoelstap.

# 21.0.0 (29)

## Wisselen tussen Mac en iPhone (topprioriteit)
- **Automatisch verder spelen bij wisselen.** Open JoeToep op het andere apparaat (of klik/tik erin na ≥ 4 s niet gebruiken): de video speelt daar meteen verder op de geschatte tijd. Het oude apparaat pauzeert en stuurt zijn exacte tijd; die wordt tot op ±0,3 s gecorrigeerd, zonder hapering.
- Net terug uit de achtergrond? Eerst wordt de verbinding afgewacht (max. 3 s) voor verse info; nooit afgaan op verouderde gegevens.
- **"Verder op iPhone/Mac"**: via het tabmenu, het mediacentrum of de zoekbalk ("Continue on …"). De video speelt daar door op precies hetzelfde moment. "Take over from …" doet het omgekeerde.
- Een tab kiezen neemt nooit ongevraagd over. Geen dubbele overdrachtsaanvragen meer.
- Instelbaar (Sync & devices › Switching devices): aan/uit, na hoeveel seconden een klik telt als wisselen, tijdcompensatie en maximale leeftijd. Het sync-logboek toont elke overdracht.
- Na het opnieuw openen van de app speelt de laatste video niet meer vanzelf (fullscreen); hij staat klaar op de juiste plek. Instelbaar.

## Browser zoals Safari, Arc en Dia
- **Eén balk** (Mac en iPad): tabs en knoppen in één rij, helemaal bovenin naast de venster-knopjes. De lege plek sleept het venster; dubbelklik maximaliseert.
- De **+ en "nieuw venster"** staan overal vlak tegen de laatste tab aan.
- **Verticale tabs in een zijbalk** (Mac en iPad, zoals Arc):
  - vastgezette tabs als tegels bovenaan;
  - groepen met naam, kleur en in-/uitklappen;
  - tabs slepen tussen groepen, vastgezet en los;
  - "Clear" sluit alle losse tabs;
  - mini Now Playing onderaan, breedte versleepbaar;
  - ⌘S verbergt de zijbalk; de muis naar de linkerrand laat hem weer zien.
- **Zwevende zoekbalk** (⌘T, ⌘L, of een klik op de actieve tab). Hij verschijnt boven de licht getinte pagina en toont voorstellen uit open tabs, favorieten en geschiedenis.
  - **Tab om te zoeken**: typ "youtube", "spotify", "twitch", "sc", "yt music" … en druk op Tab. Wat je daarna typt, wordt op dat platform gezocht. Standaard wordt op YouTube gezocht.
  - **Opdrachten**: typ ">" of gewoon "pin", "clear", "audio", "loop", "boost", "sidebar", "sleep" … voor 25+ acties.
- Scrubben met trackpad of muis beweegt de pagina niet meer mee (geen elastische overscroll).

## Media-extra's (elke site)
- Volumeboost tot 300 % met begrenzer, alleen-audio (beeld uit, bespaart batterij), herhalen, huidig frame opslaan. Via het ⋯-menu en de zoekbalk.
- Doorspelen na het verlaten van fullscreen op iPhone/iPad.

## Widgets (iPhone, iPad, Mac)
- 11 widgets:
  - Now Playing, in 4 varianten: standaard, hoes, minimaal en vergrendelscherm;
  - Alle apparaten;
  - Zoeken;
  - Bibliotheek;
  - Verder kijken;
  - Geschiedenis;
  - Tabs op alle apparaten;
  - Spotify;
  - Snelkoppelingen.
- Alle formaten: klein, middel, groot, extra groot, en op het vergrendelscherm rond, rechthoekig en inline.
- Play/pauze en spoelen voor elk apparaat (ook op afstand via sync), en "Continue here".
- De data komt uit de app via een gedeelde App Group, gebundeld hooguit 2× per seconde. Omdat de sync alle apparaten binnenhaalt, tonen de widgets overal hetzelfde.

## Ontwerp
- Liquid Glass voor de actieve tab, de zijbalk en de zwevende panelen (instelbaar).
- Het kruisje in de instellingen is even groot als de terugknop (Mac 28 pt, iPhone/iPad 44 pt glas).
- Nieuwe instellingenpagina "Tabs, sidebar & search bar".

## Tests
- V21FeatureTests (12 tests) en een extra validatiepoort: de widgetbestanden zijn in app en extensie gelijk, de App Group ids zijn consistent en de extensie is ingebed.

# 20.0.0 (28)

## Nieuw
- **Mediacentrum in de menubalk** (golfje-knop): alle tabs met video of audio, spelend én gepauzeerd, in élk venster (YouTube, Twitch, SoundCloud, Vimeo, Spotify Web …) plus Spotify. Per bron: play/pauze, ±10 s of vorige/volgende, "alleen deze" (pauzeert de rest), dempen en een volumeschuif. Vasthouden = alles pauzeren. Bolletje toont hoeveel er spelen.
- **Spotify-integratie**
  - Mac: bedient de Spotify-desktopapp rechtstreeks (nummer, artiest, album, hoes, positie, play/pauze, vorige/volgende, spoelen, volume, shuffle, repeat). Spotify meldt wijzigingen zelf, dus er wordt niet voortdurend gepold.
  - iPhone/iPad: ziet en bedient Spotify op je Mac via de sync-verbinding; anders opent de Spotify-app.
  - Spotify pauzeren of zachter zetten zodra een video start, en daarna hervatten (instelbaar).
  - Slaaptimer (15–90 min) die Spotify en alle tabs pauzeert.
  - Menu "Spotify" met sneltoetsen: ⌥⌘P, ⌥⌘←/→, ⌥⌘↑/↓, en ⌥⌘. voor alles pauzeren.
  - Zoeken op de nieuwe-tab-pagina met Spotify opent op de Mac direct in de Spotify-app.
- **Nieuwe-tab-pagina, volledig aanpasbaar**: 12 onderdelen (klok en begroeting, zoekveld, platforms, Spotify-speler, Nu aan het spelen, eigen snelkoppelingen, verder kijken, favorieten, tabs op andere apparaten, recent gesloten, geschiedenis, snelle links). Elk onderdeel kan aan of uit, en slepen bepaalt de volgorde (potlood rechtsboven). Instelbaar: compact, uitlijning, breedte, aantal items, kolommen, achtergrond (thema, verloop of vervaagde albumhoes), kaartstijl, logo, zoekveld-focus, zichtbare platforms, begroetingsnaam en reset.
- **Bovenbalk automatisch verbergen**: nooit, tijdens afspelen of altijd; kies tabs, knoppen of beide, plus vertraging en animatie. Hij komt terug als je de muis naar de rand beweegt of op de rand tikt.
- **Icoonstijlen**: 7 nieuwe outline-varianten (hairline, light, bold, in cirkel, in vierkant, soft, duotone) en 6 clean/minimalistische stijlen (minimal, stip of streep bij actief, gedempt, capsule, groot dun). Met een voorbeeldgalerij om te tikken.
- **40 nieuwe app-iconen**: de series Outline (20) en Minimal (20).

## Instellingen
- Altijd een kruisje rechtsboven, ook op subpagina's; Esc sluit. Klik buiten het venster sluit op de Mac; op de iPad sluit tikken buiten het venster.
- Overzichtelijker: groepen (Basis · Kijken & luisteren · Apparaten & bestanden · Privacy & blokkeren · Geavanceerd), en elk onderdeel heeft een korte uitleg.
- Nieuwe pagina's: New tab page, Music & Spotify, Top bar auto-hide. Ook doorzoekbaar.

## Tests
- V20FeatureTests (10 tests) en Scripts/test_v20_mediahub.py (JavaScript van het mediacentrum).

# 20.0.0 (27) — tussenversie
Bundelt alle 19.3-wijzigingen hieronder in één nieuwe hoofdversie (eigen map "JoeToep V20").

# 19.3.0 (26) — ook: dubbelklik voor fullscreen start niet meer YouTube's 2×-spoelen (houd-timer geblokkeerd + vangnet).
# 19.3.0 (26)
- Menubalkknoppen (alle apparaten): één tik werkt direct (iPad-bug waarbij je moest vasthouden opgelost). Vasthouden = extra functie: Terug→Home, Vooruit→gesloten tab heropenen, Vernieuwen→geforceerd, Startpagina's→nieuwe tab, Favoriet→Bibliotheek, Download→downloadlijst, PiP→reset, Creator tools→snelheidspaneel, Instellingen→tabs zoeken, AirPlay→fullscreen, logo→nieuwe tab, −/+→1×.
- iPad: alle menu's en sneltoetsen van de Mac werken nu ook met een toetsenbord (⌘T, ⌘W, ⌘R, ⌘[ ], ⌘1–9, ⌥Tab, zoom…).
- Mac: dubbelklik op de lege balk bovenin maximaliseert het venster (volgt de macOS-instelling).
- Theater → fullscreen: macOS-fullscreen-venster zonder videofullscreen wordt hersteld en opnieuw geprobeerd; verlaat de video fullscreen, dan verlaat ook het venster fullscreen.
- Terug uit fullscreen (tijdens of na afspelen): theatermodus wordt altijd opnieuw toegepast als die instelling aan staat.
- Sync: sneller herverbinden (elke 4 s i.p.v. 8 s, back-upuitnodiging na 1,5 s).

# 19.2.0 (build 25) — 29-09-2026

- **Scrubben ultra-responsief**: rode bolletje, rode balk en tijd bewegen per frame mee met je veeg; YouTube spoelt gedoseerd op de achtergrond (instelbaar "Seek rate limit", standaard 60 ms) + altijd een laatste seek als je stopt. Vegen stapelt vanaf het eigen doel, dus geen terugspringen.
- **Vast in macOS-fullscreen opgelost**: stond het venster in macOS-fullscreen terwijl de video zelf al niet meer fullscreen was, dan deden F/dubbelklik/Esc niets. Nu verlaten ze dan ook het venster-fullscreen (alleen op videopagina's).
- **Crash bij openen van Instellingen voorkomen**: dubbele uitleg-sleutel ("New tab page") hernoemd; nieuwe projectcontrole bewaakt dit.

- **Crashfix macOS**: de apparaatzoeker (Bonjour) wordt nooit meer gestopt/vervangen; herverbinden door bekende apparaten opnieuw uit te nodigen (crashlog `_MonitorCancel`).
- **Fullscreen ⇄ pauze**: pauze → na 0,35 s terug naar de pagina; verder spelen → weer fullscreen. Instelbaar ("Leave fullscreen when paused").
- **Nooit meer vast in fullscreen**: dubbelklik, F en YouTube's fullscreenknop verlaten fullscreen ook als YouTube zelf niet de eigenaar is.
- **Vegen**: horizontaal = altijd scrubben, ook op de gewone speler (Mac-trackpad/muis; iPhone/iPad met één vinger over de video). Terug-vegen standaard uit; Terug-knop altijd in de menubalk.
- **Omlaag trekken = fullscreen** (op videopagina's), of verversen/uit.
- **Gebaren**: voorinstellingen Precise/Balanced/Fast + alles terugzetten; aanraak-snelheid en -richting op iPhone/iPad.
- **Nieuwe-tab-pagina**: meteen typen, standaard YouTube, of YouTube Music/Vimeo/Twitch/SoundCloud/Dailymotion/Spotify/Web; verder kijken, favorieten, recent gesloten, snelknoppen. Uit te zetten. PiP bij een nieuwe tab ongewijzigd.
- **Tabs**: 1 tab ≈ halve breedte, 2 = volle breedte, 3+ kleiner; + direct achter de laatste tab; slepen tot helemaal achteraan.
- **Mac/iPad**: desktop-indeling (meer knoppen) één keer toegepast; automatisch fullscreen aan.
- **Browserfuncties**: zoom per website, leesweergave, bewaren als PDF, afdrukken (Mac), tabs doorzoeken.
- **Zoeken in de instellingen** (naam + uitleg, springt naar de juiste pagina).
- **Tests**: +5 unit-tests (o.a. 10.000 door elkaar binnenkomende berichten Mac↔iPhone, offline wijzigingen, dubbele/late berichten), +2 JS-tests (127 scenario's).

# 19.1.0 (build 24) — 28-09-2026

- **Theatermodus-bug (Mac) — oorzaak gevonden:** de controle "is het fullscreen?" keek naar de app i.p.v. de pagina; YouTube's eigen fullscreen werd dan gemist en er werd nog eens F gestuurd → fullscreen weer UIT (terug in theatermodus). Nu vraagt elke F-aanroep eerst de pagina en stuurt alleen F als hij écht niet fullscreen is (ook bij de tab-overdracht).
- **Eén klik pauzeert op de Mac**, ook als het venster nog niet actief was.
- **Tabs slepen om te herordenen** (Mac, iPad, iPhone).
- **Trekken om te verversen**: iPhone/iPad (omlaag trekken), Mac (twee vingers omlaag bovenaan de pagina). Instelbaar.
- **Snelheid**: − / + (kleine stap) in de menubalk; tik op de snelheid → paneel met klein/medium/groot omlaag en omhoog, schuif (0,25–4×, per 0,01) en vaste waarden. Mac-sneltoetsen ⌥, ⌥. (klein) · ⌥⇧ (medium) · ⌃⌥ (groot) · ⌥0 (1×). Stapgroottes instelbaar.
- **Vegen op de Mac, native**: trackpad en muis (Mac Mouse Fix) herkend, elk met eigen richting (omdraaien per as) en gevoeligheid; vloeiend (continu) of in stappen; horizontaal = scrubben, verticaal = volume; as-vergrendeling, momentum negeren, diagnose "Last gesture" voor nerds.
- **Apparaatwissel op de seconde**: begin je een video die op het andere apparaat speelt (of daar < 30 s geleden stopte), dan pauzeert dat apparaat en stuurt het zijn exacte tijd; hier wordt precies daar verder gespeeld. Positie wordt met verbonden apparaten elke seconde gedeeld.

# 19.0.0 (build 23) — 28-09-2026

- **Ctrl+Tab / Ctrl+Shift+Tab**: door je recent gebruikte tabs (houd Ctrl vast, tik Tab), ook vanuit fullscreen — de nieuwe video gaat dan fullscreen verder.
- **Automatisch fullscreen gerepareerd**: eerst theatermodus, pas daarna fullscreen (wacht op YouTube); de theaterknop wordt nooit meer tijdens fullscreen ingedrukt; controle + één nieuwe poging na 1,6 s op de Mac.
- **Vegen/scrubben**: kleine stapjes (standaard 5 s en 1% volume per stapje), werkt ook met Mac Mouse Fix; tijdens vegen YouTube-bediening + voorbeeldplaatje van de positie. Alles instelbaar (Playback › Gestures & scrubbing).
- **Redesign**: rustige "Minimal"-menubalk (één keer toegepast), lichtere iconen, meer ruimte; menubalk-indelingen Minimal/Standard/Everything, elke knop apart aan/uit.
- **Sync**: bevestigingen (✓), activiteitenlog, zelf herstellende verbinding zonder doorlopende timer, samenvoegen bij eerste contact, wissel-vriendelijk (geen beelden op het apparaat dat je verliet).
- **Standaardbrowser**: Mac-knop + uitleg; iPhone/iPad-omweg via `joetoep://` en een "Open in JoeToep"-opdracht in het deelmenu.
- **Apple Watch**: eigen schema "JoeToepWatch" om direct op de Watch te installeren.

# 18.0.0 (build 22) — 28-09-2026

## Nieuw
- **Live tab-sync** tussen Mac, iPad en iPhone (MultipeerConnectivity, geen iCloud nodig): tabs openen/sluiten/wisselen, video en afspeelpositie synchroniseren direct; nieuwste wijziging wint (hybride klok); één apparaat speelt tegelijk.
- **Apple Watch-app**: home-feed, zoeken, downloads en afstandsbediening (play/pauze, ±10 s, snelheid, kies apparaat). Afspelen gebeurt op iPhone/Mac/iPad.
- **Slimme PiP bij meerdere schermen (Mac)**: alleen PiP als de nieuwe app op hetzelfde scherm als JoeToep komt; met alleen de MacBook ongewijzigd.
- **Pijltjestoetsen via YouTube's eigen speler**, met onzichtbare YouTube-bediening.
- **Snelheidsknoppen** − 1× + (0,25–4×).
- **Downloads** van openlijk aangeboden mediabestanden (MP4 of AAC-audio 64–320 kbit/s), Downloads-scherm, offline speler, lijst synchroniseert tussen apparaten. YouTube → YouTube's eigen Premium-downloads.
- **Uitleg onder elke instelling**; nieuwe pagina's "Sync & devices" en "Downloads".

## Sync-verbeteringen (na eerste test)
- Crash op de Mac opgelost (Bonjour-browser werd gestopt en direct herstart).
- Eerste contact voegt tabs samen i.p.v. te vervangen; snapshots die binnenkomen vóór het venster er is worden bewaard.
- Automatisch opnieuw verbinden (elke 8 s zoeken als er niemand verbonden is; beide kanten mogen uitnodigen).
- Bevestiging (✓ "In sync · N tabs") en activiteitenlog in Instellingen › Sync & devices.
- Wisselen van apparaat: nieuwe en gesloten tabs verschijnen direct, maar een andere video/selectie wordt pas geladen zodra je dat apparaat weer gebruikt (klik, toets, aanraking of app openen) — gepauzeerd, op de juiste positie.
- Standaardbrowser: `joetoep://`-links + stappenplan voor "Open in JoeToep" in het deelmenu (iPhone/iPad); Mac: extra uitleg en knop naar Bureaublad en Dock.

## Tests
- V18FeatureTests (15 tests): multi-monitor-regel, sync-klok/conflicten/diff, 500-stappen simulatie met 3 apparaten, feedparser, instellingen.
- JS: pijltjes/volume/snelheid via YouTube-API (123 scenario's groen).

# V17.1 — 17.1.0 (21)

**Instellingen: eenvoudiger ingedeeld**
- De hoofdlijst is nu:
  - Algemeen
  - Weergave
  - Afspelen & PiP
  - Privacy & cookies
  - Advertenties & SponsorBlock
  - Geavanceerd
- Onder Weergave staan nu Tabs, Menubalk & knoppen, Audiovisualizer en App-icoon.
- Focusfilters staan nu onder Geavanceerd.

**Standaardbrowser**
- Mac: JoeToep kan http/https-links en HTML-bestanden openen. De knop "Maak JoeToep de standaardbrowser" staat bij Instellingen › Algemeen. Links van buitenaf openen in een nieuwe tab van het bestaande venster.
- iPhone/iPad: iOS staat dit alleen toe voor browsers met Apple's speciale browserrecht, en dat krijgt een gratis ontwikkelaarsaccount niet. De instellingen leggen dit uit.

**Tabs en menu's**
- Mac en iPad: met 1 tot 3 tabs is een tab maximaal 220 pt breed. Pas vanaf 4 tabs delen ze de hele breedte.
- De menubalk scrolt nooit meer. De knoppen staan vast en worden zo nodig gelijkmatig iets kleiner.
- iPhone/iPad: het "…"-menu toont alle opties meteen, in een raster in een uitklapvenster zonder scrollen.
- Ingedrukt houden of rechtsklikken op een link geeft "Open in nieuwe tab" en, op Mac en iPad, ook "Open in nieuw venster".

**Audiovisualizer**
- Staat standaard uit.
- 8 stijlen: staven, gespiegelde staven, golf, spectrumlijn, stippen, retro-ledblokken, gloed en puls.
- Instelbaar:
  - kleurmodus: accent, verloop, regenboog, wit of eigen kleur;
  - dekking, gloed;
  - aantal staven (8–160), hoogte, intensiteit, positie, spiegelen, afgeronde staven;
  - snelheid en vloeiendheid;
  - pulseren op een BPM (bijvoorbeeld uit Tap tempo).
- Hij beweegt met het afspelen mee, niet met het echte geluid. WebKit geeft dat geluid niet vrij zonder risico op stilte in PiP.

**110 nieuwe app-iconen** (153 in totaal), op iPhone, iPad en Mac, per serie in de kiezer:
- 20 Unique
- 20 Creative
- 20 Eccentric
- 20 Bold
- 30 YouTube Red, met verschillende strakke achtergronden

**Bugfixes tijdens het testen**
- ⌘← op een net geopende tab sloot soms ook de tab eronder. Nu sluit één gebaar altijd precies één tab. Toetsherhaling wordt genegeerd en er zit 0,7 s rem op.
- Mac: "Tekstgrootte" en "Snelheid" stonden dubbel in de instellingen (label van de schuifregelaar).

**Testen**
- Mac: 62/62 unittests. De UI-tests slagen op vier na; die vier worden verstoord door een venster van de app Vowen dat bovenaan het scherm de klikken opvangt (geen JoeToep-fout).
- iPhone: alle UI-suites groen:
  - 13 algemene UI-tests;
  - 6 PiP-apparaattests;
  - 9 V15/V17.1-apparaattests, waaronder 8 PiP-cycli onder zware processorbelasting, het "…"-paneel zonder scrollen, pauze in PiP, de PiP-overdracht bij een nieuwe tab en de stresstest met tabs en de Camera-app.
- Handmatig op de Mac:
  - compacte tabs;
  - nieuwe indeling van de instellingen;
  - rechtsklik › Open in nieuwe tab / nieuw venster;
  - terug sluit tab en keert terug naar de bron-tab;
  - meldingen.
- JS: 122 + 12 + 13 scenario's.

# V17 — 17.0.0 (20)

Van YouTube-wrapper naar een complete browser voor media en multitasking, op Mac, iPad en iPhone.

**Bediening en tabs**
- Terug op de eerste pagina van een tab sluit die tab en toont de tab waar je vandaan kwam. Dat werkt met:
  - de terugknop;
  - de muisknop "terug" (Mac);
  - ⌘← (Mac, niet tijdens typen);
  - vegen met twee vingers (Mac);
  - vegen vanaf de linkerrand (iPhone/iPad).
  Een gesloten tab haal je terug met ⌘⇧T. Dit gedrag is uit te zetten.
- Een link openen in een nieuwe tab (middelklik, rechtsklik) toont die tab meteen. Ook dit is uit te zetten.
- ⌥ Option + Tab wisselt naar de vorige (recentste) tab op Mac en iPad. Dit was Ctrl+Tab.
- De muisknop "vooruit" en ⌘→ gaan vooruit.

**Picture in Picture op elke website**
- De PiP-knop werkt nu ook op andere sites (Vimeo, Twitch, nieuwssites, video's in iframes van dezelfde site). JoeToep kiest de spelende of de grootste video en haalt PiP-blokkades weg.
- Een video op een andere site gaat bij een tab-wissel ook naar PiP en pauzeert bij een overdracht.

**Privacy**
- Cookiebanners worden automatisch geweigerd (standaard aan). Andere keuzes: alleen verbergen, of uit. Dit herkent:
  - OneTrust, Cookiebot, Didomi, Quantcast, Usercentrics, TrustArc, Google Funding Choices, Sourcepoint en meer;
  - algemene knoppen als "Alles weigeren", "Reject all" of "Alleen noodzakelijk" (in het Nederlands, Engels, Duits, Frans en Spaans), maar alleen binnen een cookie- of privacyblok.
- Bekende trackers en advertentiepixels worden geblokkeerd, zoals Google Analytics, Facebook-pixel, Hotjar en TikTok-pixel.
- Volg-parameters (utm_, fbclid, gclid, YouTube-si …) worden uit links en adressen gehaald.
- JoeToep stuurt Global Privacy Control mee (niet verkopen of delen).
- Websitegegevens zijn nu meteen te wissen, of automatisch bij het afsluiten.

**Audio: AirPods Pro 3**
- Ruimtelijke audio op iPhone en iPad: filmmodus (ruimtelijk stereo met head tracking) en meerkanaals doorvoer voor Dolby Atmos en 5.1. Dit is uit te zetten. Op de Mac regelt macOS dit zelf.

**Snelheid**
- Met animaties uit gebruikt JoeToep ook zijn kortste wachttijden. Terug naar schermvullend na PiP gaat dan meteen (0 ms in plaats van 120 ms). Draaien naar schermvullend duurt 40 ms, sluiten 120 ms, automatisch schermvullend 0,2 s.
- Door het blokkeren van trackers laden pagina's minder scripts.

**Creator tools: muziek, DJ en design**
- Snelheid van 0,25× tot 4×, met of zonder behoud van toonhoogte (tijdrek, of als een draaitafel).
- A-B-loop, en loops van precies 1, 4, 8 of 16 maten op basis van het getikte tempo.
- Tap tempo (BPM, ook met de T-toets).
- Frame-stap (1/30 s) terug en vooruit.
- Tab dempen, en een link naar het huidige tijdstip kopiëren (cue-punten).

**Leren van de code**
- Ongeveer 1.750 regels Nederlandse uitleg toegevoegd in 60 bestanden. Een script controleert dat daarbij geen code is veranderd.

**Testen**
- 58 unittests op de Mac (waaronder de nieuwe V17-tests).
- 122 + 12 + 13 JS-scenario's.

# V16.2 — 16.2.0 (18)

Bevat alle features van V15 en V16. Deze versie draait om PiP-stabiliteit en performance.

**Picture in Picture**
- Terug uit PiP met de knop in het PiP-venster gaat nu elke keer in één stap naar schermvullend en blijft spelen. Voorheen kwam de video vanaf de tweede keer inline terug. De oorzaak: JoeToep greep in terwijl iOS de terug-animatie nog uitvoerde, waardoor WebKit in een "spook-PiP"-toestand bleef hangen. JoeToep wacht nu tot de animatie klaar is en grijpt alleen in als de video echt nog in PiP staat (terugkeer via het app-icoon).
- Blijft WebKit toch in zo'n spook-PiP-toestand hangen, dan herstelt JoeToep die naar schermvullend in plaats van inline.
- Vangnet: komt een spelende video na PiP toch inline terecht, dan gaat hij nog één keer naar schermvullend. Sluiten met ✕ pauzeert de video en valt daar niet onder.

**Performance**
- Audiovisualizer: 30 in plaats van 60 beelden per seconde, asynchroon getekend. Hij staat stil als de app op de achtergrond is, in de energiebesparingsmodus, en tijdens schermvullend of PiP.

**Tabs**
- Een nieuwe tab die je niet gebruikt hebt, opent het toetsenbord niet meer als je er later naar terugwisselt.

**Testen** (iPhone, iOS 27)
- 55 unittests, 116 JS-scenario's (waaronder 10.000 overgangen en 2.000 fullscreen-cycli) en 12 V15/V16-scriptscenario's.
- Apparaattests op de iPhone:
  - acht keer achter elkaar PiP en terug;
  - de PiP-terugknop;
  - pauze in PiP blijft pauze;
  - een nieuwe tab houdt de video in PiP;
  - draaien naar landscape (schermvullend binnen 1,5 s);
  - stresstest met tabs, PiP en de Camera-app.
- Het testprobe toont nu het levenscyclus-logboek van de app, zodat een fout in een test zijn eigen oorzaak laat zien.

# V16 — 16.0.0 (16)

**Tabs en navigatie**
- Ctrl+Tab wisselt naar de laatst gebruikte tab (MRU), niet links/rechts.
- Middelklik op een tab sluit hem (macOS).
- Vasthouden of middelklik op Home, Bibliotheek en Abonnementen opent ze in een nieuwe tab.
- Vasthouden of middelklik op Vernieuwen doet een geforceerde herstart van de pagina en het webproces (noodknop als PiP of YouTube vastloopt, ook ⌘⇧R).
- De adresbalk verdwijnt als je ergens anders tikt of klikt. Instelling om vanuit de adresbalk met Google te zoeken.
- Nieuwe sneltoetsen: ⌘⇧D dupliceren, ⌘⇧C link kopiëren, ⌘K adres openen.
- Zoeken op pagina (⌘F) zoals in Chrome: meteen typen, Enter voor volgende (⇧Enter vorige, ⌘G), markering op de pagina en een teller.

**Video en PiP**
- Theatermodus standaard aan op alle platforms.
- Pauze in PiP blijft pauze; hervatten gebeurt alleen als jij opnieuw drukt (alle platforms).
- Een nieuwe tab openen houdt de spelende video in PiP. Start er een nieuwe video in de actieve tab, dan pauzeert de PiP-video en speelt de nieuwe schermvullend.
- iPad: de korte inzoom bij het starten van PiP is weg (geen inline object-fit-wisselingen meer).
- Sneller naar schermvullend bij het draaien van de iPhone.
- Datasparen op mobiel netwerk of de hotspot van eiFoon (standaard uit, kwaliteit instelbaar).

**Uiterlijk**
- Accentkleur "YouTube Red (Tjoep)" (#FF0033), nu de standaard.
- Audiovisualizer over de hele breedte van de tab- en menubalk (staven, golf, gloed of uit; intensiteit instelbaar).
- Menubalk op iPhone en iPad scrolt alleen als de knoppen niet passen. Elke knop is apart aan en uit te zetten.
- Het "…"-menu is altijd volledig uitgeklapt.

**Geavanceerd** (met waarschuwing)
- Snelheid en curve van alle animaties samen en per soort (tabs, adresbalk, menubalk, meldingen, panelen, zoekbalk, visualizer).
- Interne instellingen voor PiP, schermvullend, website en adblock, plus de SponsorBlock-server en diagnostiek.

**Beperkingen**
- De visualizer is gesimuleerd. WebKit geeft de audio niet vrij zonder PiP te breken.
- De animaties van het PiP-venster en schermvullend zelf zijn van het systeem. JoeToep haalt alleen zijn eigen vertragingen weg.
- De iPad kan niet automatisch getest worden: de testrunner crasht op de A10X-chip. De PiP-fixes zijn daar handmatig te controleren.

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
