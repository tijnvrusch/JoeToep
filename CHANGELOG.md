# 26.0.0 (39)

JoeToep wordt in deze versie een volwaardige browser in de stijl van Arc en Dia, met alles van de eerdere versies erbij. Alle nieuwe functies zijn uit te zetten en in te stellen onder **Instellingen › Spaces, Split View & Boosts**.

## Nieuw: Spaces (zoals Arc)
- **Wat je merkt:** je kunt je tabs verdelen over aparte Spaces (bijv. "Home", "Muziek", "Werk"), elk met een eigen naam, icoon (SF Symbol of emoji) en kleur. Een nieuwe tab komt in de Space waarin je zit; de tabbalk en de zijbalk tonen alleen de tabs van die Space.
- **Wisselen:** de icoontjes onderaan de zijbalk, de Space-knop links in de tabbalk, ⌃1…⌃9, ⌃⌘[ / ⌃⌘], of typ "space" in de zoekbalk (⌘T). Kies je (via de zoekbalk, de sync of ⌃Tab) een tab uit een andere Space, dan gaat JoeToep vanzelf mee naar die Space.
- **Favorieten:** vastgezette tabs blijven standaard in élke Space zichtbaar (instelbaar: per Space eigen vastgezette tabs).
- **Beheren:** rechtsklik op een Space: naam/icoon/kleur, links/rechts verplaatsen, verwijderen (tabs gaan mee naar de vorige Space, of worden gesloten). Rechtsklik op een tab › *Move to Space*. Tabgroepen horen bij de Space waarin je ze maakte. De laatste Space kan nooit weg.
- **Arc-gedrag:** sluit je de laatste tab van een Space, dan blijf je in die Space met een nieuwe lege tab, in plaats van ongemerkt naar een andere Space te springen. Elke Space onthoudt welke tab je het laatst open had. De zijbalk krijgt de kleur van de Space (sterkte instelbaar).
- Spaces worden gedeeld door al je vensters; de tabs zelf synchroniseren zoals altijd (een tab van een ander apparaat komt in de eerste Space).

## Nieuw: Split View
- **Wat je merkt:** twee tabs naast elkaar (of boven elkaar) in één venster: ⌘⇧\, rechtsklik op een tab › *Open in Split View*, het ⋯-menu of "split" in de zoekbalk. Zonder gekozen tab komt de vorige tab ernaast; is er geen andere tab, dan opent er een nieuwe.
- Beide pagina's zijn live. Klik op een paneel om het de focus te geven (knoppen en sneltoetsen werken dan daar); een video in het andere paneel speelt gewoon door tot je een andere video start (één video tegelijk blijft de regel).
- Sleep de scheidingslijn om de verdeling te kiezen (20–80 %); dubbelklik = 50/50. De laatst gekozen verdeling wordt de nieuwe standaard.
- Boven elk paneel een kleine titelbalk met *wisselen*, *naast/onder elkaar*, *alleen deze tab* en *sluiten*. Instelbaar: standaardverdeling, boven elkaar als standaard, titelbalken, focusrand, ruimte tussen de panelen en het andere paneel dimmen.
- Te smal venster (< 640 pt) → automatisch boven elkaar; te klein voor beide → alleen de tab met de focus. Kies je een tab buiten de Split View, dan eindigt hij (het andere paneel pauzeert, zoals bij een gewone tabwissel). Op de iPhone zit Split View niet in de menu's.
- **Techniek:** elke tab houdt zijn eigen webview; Split View geeft alleen een ander kader. Openen, sluiten, wisselen en slepen laden dus nooit een pagina opnieuw.

## Nieuw: Peek (zwevend voorbeeld)
- **Wat je merkt:** ⇧-klik op een link (Mac) of *Open in Peek* in het linkmenu (Mac en iPhone/iPad) opent de link in een zwevend venster boven de huidige pagina. Esc of een klik ernaast sluit hem; *Open as Tab* (⌘↩) maakt er een gewone tab van, rechts naast de tab waar hij vandaan kwam; *Open in Split View* zet hem er meteen naast.
- Een Peek is géén tab: hij wordt niet bewaard of gesynct zolang je hem niet houdt. Start er een video in, dan pauzeren de andere tabs (één video tegelijk).
- Instelbaar: grootte, hoe donker de pagina erachter wordt, sluiten bij klik ernaast, en ⇧-klik aan/uit.

## Nieuw: Boosts en Zap (zoals Arc)
- **Wat je merkt:** elke website blijvend naar je hand zetten via ⌘⌥B, het ⋯-menu of "boost" in de zoekbalk:
  - **Zap** (⌘⌥Z): klik op elk onderdeel van een pagina en het is voortaan weg op die site. Rode markering tijdens het kiezen, *Undo* en *Done* onderaan; Esc stopt.
  - **Snelle aanpassingen:** reacties verbergen, aanbevelingen naast de video, eindkaarten/infokaarten, live chat, merchandise, de hele startfeed (alleen zoeken/abonnementen), videovoorbeelden bij aanwijzen en meldingsgetallen verbergen (YouTube); animaties uit en alle links onderstrepen (elke site).
  - **Uiterlijk:** ander lettertype (systeem, afgerond, serif, monospace), kleurfilter (donker forceren, grijstinten, sepia, warm, meer contrast), eigen achtergrondkleur en een maximale leesbreedte.
  - **Eigen CSS** per site (wordt pas toegepast als je even stopt met typen).
- www.youtube.com en m.youtube.com delen één Boost; music.youtube.com heeft een eigen. Alle Boosts gaan bij het laden mee vóór de site zelf tekent, dus je ziet nooit eerst de oude pagina. Een wijziging werkt meteen in elk open venster.
- **Veiligheid:** Boosts draaien in JoeToep's eigen, afgeschermde scriptwereld (de site ziet en stoort ze niet), zonder `innerHTML` (werkt met YouTube's Trusted Types). Zap-meldingen worden alleen uit de hoofdpagina geaccepteerd en de site wordt bepaald door JoeToep's eigen adres, niet door het bericht. Selectors met tekens waarmee je uit een CSS-regel kunt breken worden geweigerd; `@import` in eigen CSS wordt genegeerd.

## Nieuw: pagina-assistent (zoals Dia)
- **Wat je merkt:** ⌘E (of het ⋯-menu, of "summarise" in de zoekbalk) opent een paneel rechts (Mac/iPad; op de iPhone een blad) dat de open pagina **samenvat**, de **kernpunten** geeft of een **vraag over de pagina** beantwoordt. Met leestijd, de belangrijkste onderwerpen (tik om ernaar te vragen) en een kopieerknop.
- Gebruikt **Apple Intelligence op het apparaat** als dat beschikbaar is; anders (en als terugval bij een fout) een snelle ingebouwde offline methode die de best passende zinnen van de pagina kiest. Er gaat nooit tekst van de pagina naar een server.
- Op YouTube leest hij de titel, de beschrijving onder de video en de reacties; menu's, knoppen, aanbevelingen en de speler worden overgeslagen.
- Instelbaar: Apple Intelligence aan/uit, lengte (2–12 zinnen), automatisch samenvatten bij openen, onderwerpen tonen en de paneelbreedte (Mac).

## Sneltoetsen (nieuw)
| Toets | Actie |
|---|---|
| ⌃1…⌃9 | Space 1–9 |
| ⌃⌘[ / ⌃⌘] | Vorige / volgende Space |
| ⌃⌘N | Nieuwe Space |
| ⌘⇧\ | Split View aan/uit |
| ⌘E | Pagina-assistent |
| ⌘⌥B / ⌘⌥Z | Boost-bewerker / Zap |
| ⇧-klik (Mac), ⌘↩ | Link in Peek / Peek als tab houden |

⌘1…⌘9 en volgende/vorige tab werken nu binnen de Space die je ziet.

## Opgelost: tabgroepen waren na een herstart leeg
- **Wat je merkte:** na het opnieuw starten van JoeToep stonden alle tabs uit je groepen in de zijbalk weer los; de groepen zelf bleven leeg.
- **Oorzaak:** de tab-opslag bouwde bij opslaan én herstellen elke tab opnieuw op en liet daarbij het groepsveld weg.
- **Oplossing:** alleen het adres wordt nog opgeschoond; alle andere velden (groep, Space, positie, vastgezet) blijven bewaard. Er is een test die dit bij elke build controleert.

## Ontwikkeling, tests en open source
- **Swift-tests in de cloud:** `Scripts/linux_swift_tests.sh` compileert alle pure modellen (Spaces, Split View, Boosts, pagina-assistent, voorkeuren, tab-opslag, PiP-statusmachine …) met Swift 6.1 op Linux en draait 37 unit tests, waaronder stresstests met duizenden willekeurige bewerkingen. Zo is ook zonder Mac te zien dat deze code compileert en klopt.
- **Nieuwe tests:** `JoeToepTests/LinuxV26Tests.swift` (pure logica, ook in Xcode), `JoeToepTests/V26FeatureTests.swift` (werkruimte: Spaces wisselen, sluiten, verwijderen, Split View, Peek, opslaan na herstart en een stresstest van 500 bewerkingen) en `Scripts/test_v26_arc_scripts.cjs` (15 jsdom-scenario's voor Boosts, Zap en de paginalezer). `npm test` draait nu álle JS-suites.
- **Projectcontrole:** `Scripts/validate_project.py` controleerde nog op versie 23.0.0 en faalde daardoor al een tijd; de versie staat nu op één plek en wordt overal vergeleken (alle targets, AppConstants, CHANGELOG). Nieuwe poort `check_v26`: pure modellen alleen Foundation, scripts in de afgeschermde wereld, geen `innerHTML`/timers/netwerk in de nieuwe scripts, uitleg bij elke nieuwe instelling, en hooguit 10 menu's per niveau in de menubalk (anders bouwt het menu niet).
- Het lege `Views/DebugHUD.swift` is weg. De V25-versietest eist nu "≥ 25" in plaats van precies "25.x".
- **GitHub Actions:** elke push bouwt de app nu met de nieuwste Xcode voor macOS en de iOS Simulator, draait daarna `JoeToepTests` op beide, plus alle JS-suites, de projectcontrole en de Swift-tests op Linux. Compilerfouten verschijnen als annotaties (ook leesbaar vanuit een cloudsessie). V26 is op beide platforms groen.
- **Nog op de toestellen te testen:** de lijst in `Docs/HANDOFF-V27.md` (Spaces, Split View, Peek, Boosts, assistent; plus de openstaande punten van V25: iPhone-rotatie, BenQ/HP-fullscreen, Live Activity-knoppen, Watch, UI-tests).

# 25.1.0 (38)

## iPhone: omlaag vegen uit fullscreen = inline blijven
- **Oorzaak 1:** "Fullscreen bij liggend houden" reageerde op elke oriëntatiemelding. Veegde je liggend omlaag uit fullscreen, dan bleef de telefoon "landscape" en zette de eerstvolgende melding de video meteen weer fullscreen. Nu opent alleen een échte draai van rechtop naar liggend fullscreen, en na het zelf verlaten pas weer nadat de telefoon één keer rechtop is geweest.
- **Oorzaak 2:** na het verlaten speelt JoeToep de video door (WebKit pauzeert hem zelf); dat "play" telde voor "fullscreen bij afspelen" als nieuwe start. Nu 3 s na het verlaten geen automatische fullscreen.
- **Pauze en dan snel omlaag vegen:** jouw pauze in fullscreen (meer dan 250 ms vóór het verlaten) blijft staan; de video gaat gepauzeerd inline, zonder terug te springen.

## Mac: de zoekbalk (⌘T) zoekt waar jij wilt
- De zoekbalk had een eigen instelling ("Search on", standaard YouTube), los van "Address bar searches with". Nu volgt hij standaard de adresbalk ("Same as address bar"); een expliciet gekozen platform blijft gelden. "Web" zoekt nooit meer op YouTube (dan Google).
- Enter voert altijd eerst het adres of de zoekopdracht uit, nooit een toevallig passende opdracht uit de lijst.

## Mac: theatermodus breekt automatische fullscreen niet meer
- De theaterknop werd soms ingedrukt midden in de overgang naar fullscreen; dan bleef het venster fullscreen terwijl YouTube terugviel naar theatermodus (brede inline-video in een fullscreen-browser). Gaat een video automatisch fullscreen, dan zet JoeToep theater pas aan ná het verlaten. Klopt fullscreen toch niet (pagina fullscreen, YouTube inline), dan laat JoeToep YouTube opnieuw kijken en verlaat hij anders netjes fullscreen.
- Een fullscreen-venster zonder fullscreen-pagina, of een "Click to Exit Full Screen"-plaatshouder zonder fullscreen-venster, wordt na 1,5 s vanzelf gesloten.

## Tests
- Nieuw: `Scripts/test_v26_scripts.cjs` (8 scenario's, o.a. 500× fullscreen → omlaag vegen); 3 daarvan falen op 25.0. De V19-test "eerst theater, dan fullscreen" is aangepast naar de nieuwe volgorde. `V25FeatureTests`: zoekbalk volgt de adresbalk.
- Op de Mac getest: ⌘T "openai sora" → Google; theatermodus aan + video uit de feed/eindscherm en 3× Shift+N → telkens echte fullscreen; Esc → inline.

# 25.0.0 (37)

## iPhone: play/pauze werkt altijd precies één keer
- **Oorzaak 1 — tik op ▶ in Apple's fullscreen-speler werd als "YouTube-autoplay" gezien.** Een herstelde tab of een tab die net door de sync werd bijgewerkt (het andere apparaat speelt) staat "stil": YouTube mag hem niet zelf starten, alleen een tik van jou. Maar tikken in Apple's eigen fullscreen-speler (en in het PiP-venster) komen nooit als klik in de pagina aan. JoeToep zag daardoor alleen "de video start zonder tik" en pauzeerde hem meteen weer — elke keer dat je op ▶ drukte.
  **Oplossing:** JoeToep weet nu wie een video start. Elk script (YouTube én JoeToep zelf) gaat via een bewaakte play()/pause(); een start in Apple's fullscreen-speler of PiP zonder zo'n script-verzoek is dus jouw tik → hij speelt, en de stil-bewaking voor die video is meteen voorbij. YouTube-autoplay blijft gewoon tegengehouden (ook in fullscreen).
- **Oorzaak 2 — de stil-bewaking ging opnieuw aan nadat jij al speelde.** Zodra de pagina klaar was met laden (dat kan seconden ná je eerste tik zijn) zette de app "stil tot je hem aanraakt" opnieuw aan. De eerstvolgende "playing" — na bufferen, na de overgang naar fullscreen of een kwaliteitswissel — pauzeerde de video dan "vanzelf", vaak midden in fullscreen.
  **Oplossing:** de bewaking beslist nu één keer per start (bij "play"); een toegestane start wordt daarna nooit meer gepauzeerd. Heb je een video zelf gestart, dan wordt "stil" voor die video niet opnieuw aangezet, en speelt hij 1,2 s, dan laat ook de app het stil-houden voor die tab los.
- **Oorzaak 3 — het hervatten van een herstelde tab ("gepauzeerd op 2:00") pauzeerde jouw eigen eerste ▶.** Op de iPhone laadt YouTube de video pas als je op play drukt; precies dan voerde JoeToep "spoel naar 2:00 en blijf gepauzeerd" uit. Nu spoelt hij nog steeds naar je plek, maar pauzeert hij niet als jij hem net startte. Hetzelfde voor het gelijkzetten van de positie met een ander apparaat.
- **❚❚ in Apple's fullscreen-speler is jouw pauze**: hij wordt nooit meer "hersteld" (binnen 3 s na terugkeer uit PiP of tijdens een overdracht sprong de video soms weer aan). Een pauze die WebKit zelf doet (fullscreen verlaten, app naar de achtergrond) telt niet als de jouwe, zodat PiP/achtergrond-afspelen gewoon blijft werken.
- **Video op de iPhone pauzeerde vanzelf als de Mac "wakker" werd**: begon je op de iPhone net (< 10 s) met kijken, dan nam alleen het activeren van JoeToep op de Mac (Xcode-Run, een melding, ⌘Tab erlangs) de video over en pauzeerde de iPhone. Dat gebeurt niet meer; een echte klik op de Mac, *Continue here* of *Play here* werkt gewoon. Geldt ook andersom.

## Mac: fullscreen is altijd te verlaten
- **Notch-fout in de fullscreen-bewaker (ingebouwd scherm MacBook Pro):** macOS houdt in fullscreen de strook van de camera vrij. De 100 %-bewaker van V23 zag dat als "video te klein" en zette fullscreen als laatste redmiddel uit en ná 1,1 s weer áán. Drukte je in die tijd zelf Esc/F, dan ging hij toch weer fullscreen — "fullscreen is niet te verlaten" — en elke fullscreen op het ingebouwde scherm haperde één keer. De bewaker meet nu tegen het bruikbare vlak (scherm min veilige marges) en gaat nooit meer uit-en-aan als jij fullscreen net zelf bediende.
- **Noodweg eruit:** gaf je Esc, F, dubbelklik of de fullscreen-knop terwijl de video fullscreen stond, dan controleert JoeToep na 0,7 s of WebKit er ook echt uit is. Hangt hij nog (WebKit midden in een overgang, YouTube's eigen fullscreen-stand "vast", een verweesd fullscreen-venster), dan eerst via de pagina eruit en YouTube's stand gelijkzetten, en daarna met WebKit's eigen noodknop (`closeAllMediaPresentations`). Nooit tijdens een lopende overgang; een nieuwe toets/klik breekt het af. Esc betekent altijd "eruit", ook tijdens de ingang.

## Sneller en zonder haperen
- De mediabewaking zoekt "de" video nu via een levende lijst in plaats van bij elke aanroep alle video's op te zoeken en te kopiëren. Die zoekactie draait tientallen keren per seconde (YouTube vraagt voortdurend `visibilityState`/`hasFocus` op) — minder werk en geheugen-afval tijdens afspelen.
- De fullscreen-bewaker gaat op het ingebouwde scherm niet meer onnodig fullscreen uit en weer in (zie hierboven).

## Tests
- Nieuw: `Scripts/test_v25_scripts.cjs` — 13 scenario's, o.a. ▶/❚❚ in Apple's fullscreen-speler onder elke stil-bewaking, laat opnieuw "stil" zetten na laden, bufferen na een toegestane start, hervatten van een herstelde tab, 2.000× ▶/❚❚-stresstest (elke tik werkt precies één keer) en 2.000 autoplay-pogingen (geen enkele lekt door). 7 van de 13 falen op de code van 24.0 (het probleem is dus nagebootst) en slagen op 25.
- Nieuw: `JoeToepTests/V25FeatureTests.swift` (versie, klokwaarde van de overdracht, gebundelde scripts bevatten de V25-bewaking). `testVersionIs24` → `testVersionIsAtLeast24`.
- Alle bestaande JS-suites groen: bridge 17, mediaCompatibility 134, V15 12, V17 13, V23.1 11, V24 10, V25 13.

## Overig
- Versie 25.0.0 (37). Alle aanpassingen van 23, 23.1 en 24 zitten erin (V24 was de nieuwste en volledige stand; niets ontbrak).

# 24.0.0 (36)

## Mac: de app crashte (opgelost)
- **Oorzaak (uit de crashrapporten van 14 en 15 oktober, alle 7 identiek):** `SpotifyController.shared` ververste zichzelf al tijdens zijn eigen initialisatie. Draaide Spotify níet, dan meldde hij meteen "Spotify staat uit" aan het mediacentrum; dat vroeg op zijn beurt `SpotifyController.shared` op — terwijl die nog aan het initialiseren was. libdispatch stopt de app dan hard ("BUG IN CLIENT OF LIBDISPATCH: trying to lock recursively", SIGTRAP), precies op het moment dat de spelerbalk met de mediacentrum-knop voor het eerst verscheen. Daarom crashte de app vaak meteen na het starten, en meerdere keren achter elkaar.
- **Oplossing:** de eerste Spotify-controle gebeurt pas één runloop-ronde ná de initialisatie, en het mediacentrum herbouwt zijn lijst bij Spotify-meldingen nooit meer synchroon (meerdere meldingen → één herbouw). Alle andere singletons zijn op hetzelfde patroon nagekeken: geen andere kringverwijzing.
- **Tweede crashrisico weggenomen:** een tab twee keer sluiten (sync én klik, of twee snelle ⌘W's) liep op een geforceerde index vast. Sluiten van een tab die al weg is doet nu niets.

## Mac: fullscreen verlaten = inline blijven (na test met Tijn)
- **Probleem:** ging je kort na het automatisch fullscreen gaan er zelf uit (F, Esc of dubbelklik), dan sprong de video binnen een seconde wéér fullscreen. De nieuwe zelfcontrole van 24.0 zag "niet fullscreen" en drukte zelf nog eens F.
- **Oplossing:** de controle stopt zodra fullscreen één keer bereikt is, zodra fullscreen verlaten wordt, én zodra jij zelf F, Esc of dubbelklik gebruikt. Na zo'n eigen keuze vraagt de pagina voor die video ook nooit meer automatisch fullscreen aan; je wisselt daarna zelf vrij tussen fullscreen en inline. Esc vlak vóór of tijdens het automatisch openen annuleert het verzoek; komt fullscreen toch nog binnen, dan gaat het meteen weer uit.
- Getest op de Mac (BenQ en HP): F in/uit, Esc, dubbelklik in/uit, en "nieuwe video → automatisch fullscreen → binnen 1 s F/dubbelklik" → blijft inline doorspelen. YouTube's eigen overlay (balk bij muisbeweging, verdwijnt na een paar seconden, blijft staan bij pauze) werkt in fullscreen.

## Mac: bediening in fullscreen zoals YouTube
- **Pijltjes:** in fullscreen gaan ←/→ (5 s spoelen) en ↑/↓ (5 % volume) weer naar YouTube zelf, met YouTube's eigen "5 seconden"-plaatje, volume-plaatje en bedieningsbalk. ⌥/⌘-combinaties (30/60 s) blijven van JoeToep.
- **Klik op het beeld:** pauze/afspelen direct (zoals in 23.1), nu met het ▶/❚❚-plaatje in YouTube's maat en animatie (52 px, 0,5 s vervagen en vergroten), én de bedieningsbalk met titel verschijnt even — bij spelen verbergt YouTube hem zelf weer, bij pauze blijft hij staan.
- **F, Esc, dubbelklik, spatie/K:** ongewijzigd YouTube-gedrag; na verlaten blijft de video inline doorspelen (zie hierboven).

## Mac: automatisch fullscreen altijd betrouwbaar
- **Oorzaak:** automatisch fullscreen was één poging per video. Kon de app het verzoek op dat moment niet uitvoeren (app net niet actief, PiP- of overdrachtsovergang, focus elders), dan was die video "op" en ging hij nooit meer vanzelf fullscreen. Daarnaast was er maar één controle (na 1,6 s), die alleen werkte als de app de video al als "spelend" zag.
- **Oplossing:** automatisch fullscreen controleert zichzelf. Na het verzoek meet de app tot 3× (1,2 / 2,4 / 4 s) of de video écht fullscreen staat; zo niet, dan opnieuw — maar alleen als twee metingen 0,3 s na elkaar het eens zijn én er geen WebKit-fullscreen-venster in aanmaak is (F is een aan/uit-knop, dus nooit sturen tijdens een overgang). Een verzoek dat niet uitgevoerd kon worden wordt in de pagina opnieuw "gewapend" en bij de volgende keer spelen of activeren van de app alsnog uitgevoerd. Nooit opnieuw als fullscreen voor die video al gelukt was: zelf verlaten blijft verlaten. Alles komt in het lifecycle-logboek ("auto-fullscreen requested / ok after retry / re-armed / FAILED").
- Werkt in alle drie de fullscreen-modi (YouTube, Enhanced, Safe).
- Eerdere fullscreen-wensen ongewijzigd behouden: 100 %-bewaker (V23), klik = pauze/afspelen en dubbelklik = fullscreen uit in fullscreen (V23.1), snel in/uit zonder zwarte tab (V23.1).

## iPhone: automatisch landscape — soepel, snel en stabiel
- **Landscape vanaf het eerste frame:** de draai startte pas als de pagina "fullscreen" meldde — ná het begin van de fullscreen-animatie. Je zag dan eerst een staande fullscreen-video die daarna nog eens draaide (twee bewegingen, verspringend beeld). Nu zet JoeToep de landscape-klem zodra WebKit/AVKit het fullscreen-venster zichtbaar maakt, en het venster vraagt vanaf het begin alleen landscape: iOS presenteert de video meteen liggend, in één beweging. Dat geldt ook voor de terugkeer uit Picture in Picture naar fullscreen.
- **Geen dubbele draaiverzoeken meer:** staat de interface al in landscape, dan volgt geen tweede verzoek (dat gaf een schok midden in de draai). De controles daarna (0,35 / 0,8 s) vragen alleen opnieuw als iOS echt niet gedraaid is.
- **Rotatievergrendeling + telefoon zelf kantelen:** kantelde je de telefoon tijdens automatisch-landscape-fullscreen, dan haalde JoeToep de klem eraf; met rotatievergrendeling aan sprong iOS daardoor terug naar portrait terwijl de video fullscreen bleef. De klem blijft nu tot fullscreen dicht gaat. "Rechtop = fullscreen uit" werkt nog steeds (via de apparaat-oriëntatie).
- **Telefoon al liggend bij openen:** met rotatievergrendeling aan en de telefoon al liggend werd er niet gedraaid (er werd naar de fysieke stand gekeken in plaats van de interface) → fullscreen bleef staand. Opgelost.
- **De pagina eronder draait niet meer mee:** zonder de portret-instelling draaide tijdens automatisch-landscape ook de hele YouTube-pagina mee, die na het sluiten opnieuw moest opmaken (verspringen bij terugkeer). Het app-venster blijft nu altijd rechtop onder een automatisch gedraaide video.
- **Vangnet:** blijkt een venster geen blijvend fullscreen-venster, dan gaat de klem na 1,5 s vanzelf weer los.

## Tests
- Nieuw: `Scripts/test_v24_scripts.cjs` (8 scenario's, o.a. 1.000 wegval/opnieuw-wapen-cycli) en `JoeToepTests/V24FeatureTests.swift` (singleton-regressie met 2.000 Spotify-meldingen, versie, iPhone-venster-oriëntaties).
- Alle bestaande JS-suites groen: bridge 17, mediaCompatibility 134, V15 12, V17 13, V23.1 11, V24 8.

## Overig
- Versie 24.0.0 (36).

# 23.1.0 (35)

## Mac: klikken in fullscreen werkt altijd
- **Oorzaak gevonden (gemeten in de app):** staat een video in fullscreen op **pauze**, dan legt macOS (VisionKit/Live Text, `VKCImageAnalysisOverlayView`) een onzichtbare tekstherkenningslaag over het beeld. Die slikte elke klik in: klik = verder spelen en dubbelklik = fullscreen uit deden niets; toetsen (F, Esc, spatie) gingen er langs en werkten wel.
- JoeToep ziet nu wanneer een klik in WebKit's fullscreen-venster op zo'n systeemlaag valt en geeft hem zelf door aan de pagina. Eén regel voor elke klik op het beeld in fullscreen:
  - **klik** = meteen pauze/afspelen (geen wachttijd), met een klein ▶/❚❚-plaatje in het midden;
  - **dubbelklik** = fullscreen uit; de afspeelstand van vóór de dubbelklik blijft (stond hij op pauze, dan blijft hij op pauze — geen "doorspelen" na het verlaten);
  - klikken op knoppen, tijdbalk, menu's, kaarten, eindschermen en advertenties gaan gewoon naar YouTube; staat een YouTube-menu open, dan sluit de klik eerst dat menu.
- (WebKit's eigen schakelaar voor Live Text in video's uitzetten is getest en bewust níet gebruikt: het webproces liep dan vast bij fullscreen.)

## Geen zwarte tab meer na fullscreen (Mac)
- Na het verlaten van fullscreen kon de tab zwart blijven, zelfs na herladen. JoeToep schakelde in sommige gevallen WebKit's eigen fullscreen-venster om terwijl WebKit dat zelf al aan het sluiten was (macOS 27 noemt dat venster `WebCoreFullScreenWindow`; de oude controle herkende het niet). Dat gebeurt nu nooit meer.
- Vangnet: hangt de webview na het verlaten van fullscreen 2 en 3,5 s later nog steeds nergens, dan zet de tab hem stil terug.

## Sneller
- Automatisch fullscreen bij het starten van een video: wacht 0,1 s i.p.v. 0,35 s (met "snelste overgangen" 0,04 s, animaties uit 0 s); de theatermodus-stap ervoor wacht hooguit 0,45 s i.p.v. 1,5 s.
- Fullscreen verlaten: de vervolgstappen (venster terug, portrait op iPhone) na 0,09/0,12/0,18 s i.p.v. 0,26/0,3/0,35 s.
- Pagina's laden lichter: de drie "waakhonden" die bij elke DOM-wijziging van YouTube keken of er een video bij kwam (speler-bridge, voorkeuren, adblock-melding) slaan tekst- en lege elementen meteen over en gebruiken `getElementsByTagName` i.p.v. `querySelectorAll` op elke toevoeging — YouTube voegt bij het laden duizenden elementen toe.

## iPhone: startpagina vanaf het eerste frame in één kolom
- In desktopweergave toonde de YouTube-startpagina eerst twee video's naast elkaar en sprong binnen een seconde naar één kolom. Nieuw script `phoneLayout.js` draait op **documentStart** (vóór YouTube's eigen scripts en vóór de eerste opmaak): viewport = schermbreedte en één video per rij (Shorts 2 naast elkaar, zoals de mobiele site). Alleen iPhone + desktop-YouTube; niet op iPad, Mac, m.youtube.com of andere sites. Ook de kijkpagina-kolom (V22.1) staat nu vanaf het eerste frame goed.

## iPhone: automatisch draaien bij fullscreen (extra wens)
- Nieuwe instelling **"Auto-rotate fullscreen (even with rotation lock)"** (Instellingen › Playback & Picture in Picture, iPhone, standaard aan): een video die fullscreen opent draait meteen naar landscape — óók met rotatievergrendeling aan — en bij het sluiten meteen terug naar portrait. Kantel je de telefoon zelf, dan neemt de normale rotatie het over (rechtop = fullscreen uit blijft werken). iOS weigert een draai soms tijdens de animatie van de speler; JoeToep controleert na 0,25 en 0,7 s en vraagt het zo nodig nog eens. Uit = het oude gedrag (fullscreen volgt hoe je de telefoon houdt).

## Overig
- Versie 23.1.0 (35).
- Nieuwe JS-tests `Scripts/test_v231_scripts.cjs` (11 scenario's, o.a. 2.000 klikken stresstest, dubbelklik vanuit pauze/spelen, iPhone-opmaak alleen waar hij hoort). Alle bestaande JS-suites groen.

# 23.0.0 (34)

## Fullscreen, apparaatwissel, volume, Live Activity en PiP
- **Fullscreen op de Mac altijd 100 %**: de video bleef soms op ±75 % staan met zwarte balken (BenQ 1440p én HP 1920x1200), tot een herstart. Oorzaak: na een monitorwissel, slaapstand of andere schaal hield de webview of WebKit's fullscreen-venster de maat van het vorige scherm vast (2560 ↔ 1920 = precies 75 %), of YouTube rekende de videogrootte uit vóór de fullscreen-animatie klaar was. Een nieuwe fullscreen-bewaker controleert na het ingaan van fullscreen en na elke scherm-/schaalwissel (0,15 / 0,6 / 1,4 / 3 s, geen doorlopende polling) of de video het scherm vult, en herstelt in stappen: trackpad-vergroting terug naar 1, webview-frame gelijk aan zijn venster, YouTube opnieuw laten meten, en zo nodig een regel die de video het hele vlak laat vullen (beeldverhouding blijft kloppen). Klopt het fullscreen-venster zelf niet, dan zet JoeToep het op het scherm; als laatste redmiddel gaat fullscreen één keer uit en weer aan. Alles komt in het lifecycle-logboek.
- **Nieuwe instelling "Switch devices automatically"** (Instellingen › Sync & devices): uit = dit apparaat neemt nooit vanzelf over en geeft zijn video ook niet vanzelf door als je het wegstopt; overnemen gaat dan alleen met *Continue here* / *Play here* (widget, Live Activity, overlay, Watch, ⌘K). Per apparaat instelbaar; standaard aan (zoals voorheen).
- **Volume in beeld**: bij een verticale veeg (trackpad/muis) en bij de pijltjestoetsen verschijnt het volumepercentage met luidsprekericoon bovenin de video, zoals YouTube dat doet — ook in fullscreen. YouTube's eigen bezel blijft weg, dus nooit twee plaatjes.
- **Live Activity blijft gesynchroniseerd en bedienbaar**:
  - knoppen (play/pauze, ±10 s, ±30 s) wachten nu tot de opdracht echt is afgeleverd: de app herstelt zo nodig eerst de verbinding met het andere apparaat (iOS verbreekt die op de achtergrond), verstuurt, en zet de Live Activity daarna gelijk met de nieuwe stand van dat apparaat;
  - je tik is meteen zichtbaar (play/pauze en spoelen worden direct getoond, de echte stand volgt binnen een paar tellen);
  - opdrachten voor een apparaat dat nog aan het herverbinden is, wachten max. 10 s in een outbox en gaan weg zodra het verbonden is (ook voor de Watch);
  - een video op een ander apparaat springt tijdens kort herverbinden (≤ 2 min) niet meer op "pauze";
  - de activiteit blijft vers tot het einde van de video (was 15 min), wordt bij terugkomst in de app altijd ververst, en een door iOS beëindigde activiteit wordt netjes vervangen;
  - na het wegleggen van de iPhone blijft de verbinding nog zo lang als iOS toestaat open, zodat bediening direct na vergrendelen zonder herverbinden werkt.
- **Picture in Picture ook na het verlaten van de kijkpagina**: speelde de video door in YouTube's miniplayer of op de startpagina, dan startte PiP op de achtergrond niet en kon de video pauzeren. Een hoorbare hoofdvideo die net speelde telt nu als "de" video (stille voorbeeldfilmpjes niet), zowel in de pagina als in de app (automatische PiP, bescherming op de achtergrond, Apple-presenter).

## Overig
- Versie 23.0.0 (34), ook in Instellingen (stond nog op 22.3.0 in de app).
- Twee verouderde unit tests bijgewerkt (aantal app-iconen is 193; Mac/iPad hebben sinds V19.2 de desktop-menubalk). Nieuwe tests: V23FeatureTests (instelling, outbox, fullscreen-script, Live Activity-houdbaarheid) en V23DeviceTests (instelling + 8× PiP-wissel).
- Getest: zie Docs/BUILD_REPORT.md.

# 22.3.0 (33)

## Stabiliteit, sync en zuinigheid (getest op Mac, iPhone en iPad)
- **Grote fix: "spook-overname" bij opstarten**: een ander apparaat stuurt bij verbinden de laatst bekende stand van déze Mac/iPhone/iPad terug. Die werd ten onrechte gezien als "een ander apparaat dat speelt", waarna het apparaat zichzelf overnam: een herstelde of heropende video begon vanzelf te spelen (en ging fullscreen). Eigen oude standen worden nu alleen nog gebruikt om de klok bij te werken.
- **Tabs kunnen niet meer in één klap verdwijnen**: komt er een snapshot binnen waarin ineens veel tabs ontbreken (≥ 8 en meer dan de helft), dan sluit JoeToep alleen de tabs die het andere apparaat echt als gesloten meldt. "Sluit andere tabs" op een ander apparaat werkt gewoon.
- **Herstel na het sync-incident**: 22.3 wist bij de eerste start eenmalig de oude sluit-markeringen, zodat een apparaat dat je tabs nog heeft (bijv. de iPhone) ze bij het samenvoegen terugbrengt op alle apparaten.
- **Sync alleen met JoeToep zelf**: een andere build op hetzelfde apparaat (zoals een QA-kopie met een eigen, kleine tablijst) kon via hetzelfde sync-kanaal meedoen en tabs op je andere apparaten overschrijven. Apparaten herkennen nu elkaars app en negeren de rest.
- **Nooit twee JoeToeps tegelijk op de Mac**: start je JoeToep terwijl er al een draait (bijv. vanuit Xcode of een tweede kopie), dan sluit de oude netjes af; ze schreven anders door elkaar in dezelfde tabopslag en zagen elkaar als "ander apparaat".
- **Gesloten vensters blijven gesloten**: tabs van een extra venster dat je sluit kwamen bij elke herstart terug (vaak als stapel "Home"-tabs). Nu verdwijnen ze met dat venster. Sluit je het hoofdvenster terwijl er nog een ander open is, dan verhuizen zijn tabs naar dat venster (niets kwijt, ook niet op je andere apparaten). Sluit je het laatste venster, dan blijven je tabs bewaard en haalt een nieuw venster ze gewoon terug. Speelt er iets in het venster dat je sluit, dan stopt dat. De selectie na een herstart is die van het hoofdvenster.
- **Mac opent met één venster**: macOS herstelde bij elke start alle vensters van de vorige keer; omdat het eerste venster alle tabs overneemt, stapelden zich lege "Home"-vensters op en kwam een venster soms in fullscreen op een eigen Space terug. Nu altijd één venster met al je tabs, op de plek en in de grootte van de vorige keer.
- **Geen autoplay meer bij het opstarten**: herstelde tabs (ook korter dan 3 s of zonder tijd) blijven gepauzeerd op hun plek tenzij "Hervatten bij starten" aan staat; YouTube-autoplay wordt tijdens het herstel tegengehouden.
- **Spoelen naar een positie** (sync/klik) start een afgelopen of gepauzeerde video niet meer opnieuw.
- **Snel typen na ⌘T** gaat niet meer verloren: het zoekveld houdt de focus, ook als de pagina nog laadt.
- **"Verder kijken"** toont elke video maar één keer (ook in widgets en de zoekbalk).
- **Tabbalk** scrollt na het opstarten meteen naar de geselecteerde tab.
- **Zuiniger tijdens afspelen met verbonden apparaten**: positie 1× per seconde i.p.v. 2× (halveert de JS-aanroepen), widgets alleen herschrijven bij een echte wijziging.
- **Geen vanzelf spelende video's meer na sync of sluiten**: een herstelde videotab speelt alleen meteen als jij hem zelf kiest (tik/klik/⌃Tab, nieuwe tab). Kwam hij in beeld door de sync, door het sluiten van een buurtab of door een trage eerste start, dan blijft hij gepauzeerd op zijn plek (de iPad begon na een herstart soms zelf te spelen).
- **Veel minder sync-verkeer tijdens afspelen**: de positie van de spelende video wordt doorgerekend; er gaat alleen een snapshot over de lijn bij spoelen, pauze of hooguit 1× per minuut (was elke 5 s) — zuiniger op alle apparaten en geen onnodige spoelacties op de andere apparaten.
- **Alleen echt verbonden apparaten zijn "online"**: een apparaat dat al weg was (bijv. de iPhone) kon via een doorgestuurde snapshot als bedienbaar verschijnen in de overlay, widgets en "Verder op …".
- **Sync robuuster in randgevallen**: oude sluit-markeringen (ouder dan 7 dagen) tellen niet meer mee, zodat twee apparaten het nooit eindeloos oneens kunnen blijven over gesloten tabs; houdt een ander apparaat een oudere stand van dit apparaat met een hoger versienummer vast (snelle herstart), dan publiceert dit apparaat zijn huidige stand opnieuw.
- **Sync herstelt zichzelf**: loopt een apparaat achter (gemiste snapshot of halve verbinding), dan stuurt het andere apparaat de huidige toestand vanzelf opnieuw; "In sync" klopt nu ook voor apparaten die hun update via een derde apparaat kregen.
- **Snel door tabs bladeren (⌃Tab)** start geen video's meer in tabs die je alweer voorbij bent (die speelden op de achtergrond en pauzeerden de tab die je wél zag); kom je later terug naar zo'n tab, dan speelt hij alsnog.
- **Gesloten tab heropenen (⇧⌘T)** herstelt ook de afspeelstand: speelde hij, dan speelt hij weer; stond hij op pauze, dan blijft hij gepauzeerd (startte eerst altijd, ook fullscreen).
- **Stil vanaf de eerste milliseconde**: een herstelde video die niet mag spelen wordt nu al bij het begin van het laden tegengehouden (YouTube was soms sneller dan de pagina klaar was).
- **⌘T/⌘L tijdens een fullscreen video**: de overlay verscheen onzichtbaar áchter de video; nu verlaat de video eerst fullscreen.
- **"Verder op iPad/iPhone"** in de overlay is één knop als er één ander apparaat is (het menu was lastig te raken).
- **Overlay › Andere apparaten**: afspeelknoppen en "Play here" alleen bij een video; staat het andere apparaat op een gewone pagina, dan kun je die met "Open here" openen.
- **Herstelde video's blijven echt stil**: YouTube kon een herstelde video na een paar seconden alsnog gedempt laten starten (en fullscreen openen, gezien op de iPhone). Nu blijft hij gepauzeerd tot je hem zelf aanraakt, op play drukt of hem vanaf een ander apparaat/de Watch/een widget start.
- **Eén video tegelijk, ook met meerdere Mac-vensters**: start je een video in een tweede venster, dan pauzeert het andere venster én het apparaat dat nu speelt. "Pauzeer alles" en de pauzeknop in widgets gebruiken een echte pauze-opdracht (kan een video nooit per ongeluk starten).
- **Geen tabsprong meer door een herstart elders**: kwam je terug op de Mac terwijl de iPad net (her)startte, dan sprong de Mac naar de tab die de iPad toevallig open had. Nu volgt een apparaat alleen een échte tabwissel op het andere apparaat.
- **"Verder op …" laat je nooit in stilte achter**: neemt het andere apparaat de video niet binnen 8 seconden over (scherm op slot, app op de achtergrond, verbinding weg), dan speelt hij hier gewoon verder met een melding — niet als het andere apparaat hem wél even speelde of hier intussen iets anders speelt.
- **Tabkeuze terwijl een ander apparaat speelt**: je eigen keuze wordt alleen overschreven als je echt terugkomt (app geactiveerd of lang inactief).


# 22.2.0 (32)

## Fixes na uitgebreid testen (Mac, iPhone, iPad)
- **Esc op de Mac** sluit nu altijd eerst de zoekbalk/overlay, Instellingen of de zoekbalk in de bibliotheek — ook als de video/webpagina de focus heeft. Alleen in het venster waar je drukt; zonder open paneel verlaat Esc gewoon fullscreen.
- **Zwarte tab op iPhone/iPad opgelost**: als iOS het webproces van een tab op de achtergrond afsloot, bleef die tab leeg. Nu herstelt hij vanzelf (gepauzeerd, zonder fullscreen) zodra je hem weer ziet; met een rem tegen herstel-lussen.
- **Webview raakt nooit meer "los"** na een mislukte fullscreen-/PiP-terugkeer (iOS en Mac): de tab pakt hem stil terug.
- **"Pause Everything"** pauzeert nu écht alles, ook een video die net begon (wachtte eerst op een trage scan).
- **Overdracht**: een overname-verzoek pauzeert alleen díe video, nooit een andere video op het andere apparaat; een overdracht wordt maar één keer overgenomen (ook als de exacte tijd later nog binnenkomt).
- **Geen video meer op de achtergrond** na een tik: tikte je (na even weg te zijn) op een andere tab terwijl de Mac speelde, dan nam de iPhone de video over in een andere tab die op de achtergrond bleef spelen. Nu wint je eigen tabkeuze en wordt die overname netjes ingetrokken.
- **Achtergrondtabs gaan nooit meer vanzelf fullscreen** (alleen de tab die je ziet).
- **Gesloten tabs blijven gesloten**, ook als een ander apparaat uit stond en daarna opnieuw verbindt.
- **Pauzeren op het andere apparaat wordt altijd opgemerkt**, ook als dat bericht de tab-vergelijking "verloor" — geen overname meer op een verkeerde (doorgerekende) tijd.
- **Instellingen via zoeken** (bijv. "Sync & devices") hebben weer de nette gegroepeerde opmaak; tekst steekt niet meer buiten het paneel.

## Grote reviewronde (afspelen, PiP, UI, Watch, widgets)
**Afspelen & PiP**
- iOS-native PiP is nu echt te stoppen (Pause Everything, één-video-tegelijk, sync, tab-icoon) — er speelden soms twee video's.
- Een PiP-verzoek dat nog loopt telt als PiP; wordt netjes geannuleerd bij pauzeren.
- Achtergrondtabs gaan nooit fullscreen, ook niet bij terugkeer uit PiP; een verborgen tab herstelt een gecrasht webproces pas als je hem bekijkt.
- "Fullscreen bij afspelen" werkt ook na fullscreen verlaten terwijl gepauzeerd.
- Standaard "fullscreen verlaten bij pauze" = uit, nu ook in de pagina zelf (was even "aan" vóór de instellingen binnen waren).
- Status van een tab die (weer) zichtbaar wordt klopt altijd (fullscreen bij laden/afspelen faalde soms na PiP-sluiten op de achtergrond).

**Interface & instellingen**
- Zijbalk-breedte slepen schiet niet meer door naar min/max.
- Vastpinnen door te slepen in de zijbalk zet de tab op de juiste plek en wordt bewaard.
- Instellingen zoeken: ±30 resultaten openden de verkeerde pagina — alles klopt nu, ook geavanceerde opties (alleen zichtbaar in Geavanceerde modus).
- Animaties "uit" = écht overal uit (ook auto-verbergen, nieuwe-tabpagina, per-onderdeel-stijlen).
- Return in een lege nieuwe-tab-overlay springt niet meer naar een onzichtbare suggestie; ⌘L terwijl de overlay open is vult het adres.
- "Reset animations" gebruikt de juiste standaardsnelheid (1,6×); diverse schakelaars werken nu direct zichtbaar bij.
- Klik op het geluid-icoon in een zijbalkrij wisselt niet ook nog van tab.
- Opgeslagen overlay-indeling blijft bewaard bij toekomstige updates.
- Esc: sluit het paneel in het juiste venster (registratie per venster gerepareerd).

**Apple Watch, widgets & Live Activity**
- Bediening voor een offline apparaat stuurt niet stiekem de iPhone aan; offline apparaten tonen "Offline".
- Je gekozen apparaat op de Watch springt niet meer elke 2 s terug naar "wat speelt".
- Live Activity verschijnt ook als de eerste poging op de achtergrond mislukte, en verdwijnt 10 min na stoppen.
- Watch- en widgetknoppen werken ook als iOS de app op de achtergrond start (of geven een duidelijke melding).
- "Ontvangen…" op de Watch blijft niet meer hangen; mislukte overdrachten worden gemeld.
- Offline audio op de Watch speelt door met scherm uit; foutmelding als audio niet start.
- Spotify-scherm stuurt niet meer onbedoeld een volume-commando; snelheid/duur/positie-wijzigingen komen door.
- Complicatie "Zoeken" opent echt zoeken; complicaties krijgen ook gegevens zonder dat de app open is.

## Wat is er nieuw

- Animaties overal sneller (standaardsnelheid 1.6×, alle stijlen ~30% korter); met animaties 'uit' geen vertraging meer in fullscreen/rotatie/overdracht.
- Sync: overdracht wordt maar één keer overgenomen, positie elke 0,5 s, reconnect elke 2 s, 'quiet'-bewaking zodat geen andere tab gaat spelen.
- PiP ✕ stopt de video op alle apparaten zonder terug naar fullscreen; iPad gaat bij terughalen direct fullscreen.
- iPhone: pagina sluit links en rechts precies aan (zoom- en x-vergrendeling, smalle desktop-layout).
- Tab-geluidsicoon: pauzeren/afspelen + automatisch wisselen, met instellingen; Geavanceerde modus verbergt nerd-opties.
- Watch-app, complicaties, widgets en Live Activity afgerond.


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
