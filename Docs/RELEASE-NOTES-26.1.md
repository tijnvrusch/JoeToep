
Eerste test van V26 op echte apparaten (Mac). Gebouwd en geïnstalleerd op de Mac en de eiFoon; `JoeToepTests` op de Mac: 169 geslaagd, 0 mislukt.

## Opgelost: pagina-assistent toonde "https", "com" en "oct" als onderwerpen
- **Wat merkte je**: bij een YouTube-video stonden onder "Topics" woorden als `https`, `com`, `oct` en `18th` in plaats van echte onderwerpen.
- **Oorzaak**: `PageDigest.keywords` telde ook de woorden uit links in de videobeschrijving mee, plus maandafkortingen en datums zoals "18th".
- **Oplossing**: links (`https://…`, `www.…`, `iets.com/…`) gaan eruit vóór het tellen; webwoorden en maandafkortingen worden overgeslagen, net als woorden die met een cijfer beginnen. Nieuwe test `testKeywordsSkipLinksAndDates`.

## Opgelost: na een herstart vast in fullscreen met een draaiend laadrondje
- **Wat merkte je**: bij het openen van JoeToep ging de laatste YouTube-video meteen fullscreen (op de HP-monitor), bleef gepauzeerd met YouTube's laadrondje, F en Esc deden niets en de spatiebalk werkte maar één keer.
- **Oorzaak**: een herstelde tab wordt stil gehouden tot je zelf iets aanraakt. YouTube's eigen autoplay speelt dan heel even voordat JoeToep pauzeert. Sinds V26 wacht automatische fullscreen niet meer eerst op de theatermodus, waardoor het fullscreen-verzoek precies in dat korte moment viel; daarna stond een gepauzeerde video in een fullscreen die nergens meer op reageerde.
- **Oplossing**: `sitePreferences.js` vraagt nooit automatisch fullscreen aan zolang de stil-bewaking actief is. Zodra jij op play drukt (of JoeToep zelf laat spelen) werkt automatische fullscreen gewoon. Nieuwe jsdom-test (faalt zonder de fix).

## Opgelost: Zap verborg niets bij knoppen op YouTube
- **Wat merkte je**: Zap op de Join-knop meldde "1 hidden — saved for this site", maar de knop bleef gewoon staan.
- **Oorzaak**: boven elke YouTube-knop ligt een onzichtbare klik-animatielaag (`yt-touch-feedback-shape`). Zap koos die lege laag in plaats van de knop.
- **Oplossing**: `boosts.js` klimt bij het aanwijzen en klikken over zulke lagen heen (klik-animaties, ripples en lege, absoluut gepositioneerde lagen die precies over hun ouder liggen) naar het echte onderdeel. Nieuwe jsdom-test (faalt zonder de fix).

## Opgelost: Split View liet lege Home-tabs achter
- **Wat merkte je**: Split View openen in een Space met maar één tab maakte een lege Home-tab als tweede paneel; na het sluiten bleef die staan, en bij elke nieuwe split kwam er weer een bij.
- **Oorzaak**: `openSplit` maakt een nieuwe tab als er geen andere is, maar sluiten ruimde hem nooit op.
- **Oplossing**: JoeToep onthoudt welke tab de split zelf maakte en sluit die weer als de split eindigt (sluiten, of een tab buiten de split kiezen), maar alleen als hij nog onaangeroerd is (nog de nieuwe-tabpagina toont) en niet het paneel is dat je houdt. Nieuwe unit test `testSplitRemovesItsUntouchedBlankTabWhenClosed`; op de Mac nagetest.

## Getest op de Mac (OK)
- Spaces: nieuwe Space maken (opent met een Home-tab), heen en terug wisselen.
- Split View: openen via het menu; een opgeschorte tab is een paar seconden wit tot hij geladen is, daarna staan beide panelen goed.
- Boosts: reacties en aanbevelingen verbergen en weer tonen werkt direct, in beide panelen.
- Pagina-assistent: samenvatten met Apple Intelligence werkt.
- Fullscreen: F erin en eruit, Esc eruit, spatie pauzeert/speelt elke keer (getest 3×).
- Zap: Undo zet gezapte onderdelen terug, Done sluit Zap.
- Instellingen › Spaces, Split View & Boosts: alle schakelaars met uitleg; Split View uit → de functie verdwijnt meteen.
- Stresstest: Spaces en Split View snel wisselen — geen crash, geheugen stabiel (274 → 285 MB).

## Nog open (zie Docs/HANDOFF-V27.md › 26.1)
- `V21FeatureTests.testPaletteCommandsAreUniqueAndFindable` faalde één keer in de volledige run (testproces herstartte), daarna twee keer los groen: wisselvallig, niet door 26.1.
- Peek (⇧-klik / rechtsklikmenu) niet getest: kan niet op de achtergrond bediend worden.
- iPhone, iPad, Watch, widgets en Live Activity zijn nog niet getest (iPhone Mirroring is in deze regio niet beschikbaar).

