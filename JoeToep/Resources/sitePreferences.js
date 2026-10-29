/* Event-driven preferences. Never replace or move the playing video. */
// IIFE die allerlei kijkvoorkeuren afdwingt op YouTube: donker thema, ondertitels uit,
// standaardvolume, theatermodus en automatische fullscreen. Werkt op basis van events
// (video begint te spelen, navigatie, etc.) in plaats van steeds te herhalen ("polling").
(() => {
  'use strict';
  if (!window.JoeToepMedia || window.JoeToepPreferences) return;
  // De instellingen die de app kan aanpassen via configure(); dit zijn de standaardwaarden.
  // JOETOEP_NATIVE_HOST geeft aan of we in de native app draaien (dan regelt de app zelf
  // de automatische fullscreen, dus die staat hier standaard uit).
  let config = {automaticFullscreen: !window.JOETOEP_NATIVE_HOST, fullscreenOnPlay: false, disableCaptions: true, disablePreviewCaptions: true, theater: true};
  // Onthoudt voor welke video (key) we theatermodus al hebben aangezet, zodat we dat niet
  // telkens opnieuw proberen te doen (en de gebruiker de knop niet kan uitzetten).
  let theaterKey = '';
  // V19: volgorde theater → fullscreen, en geen theater-klik vlak rond een fullscreen-verzoek.
  let theaterRequestedAt = 0, waitingForTheater = false;
  const observedWatch = new WeakSet();
  // Luistert (zonder timers) naar YouTube's theater/fullscreen-attributen op de kijkpagina.
  function watchAttributes(el) {
    if (observedWatch.has(el)) return;
    observedWatch.add(el);
    new MutationObserver(() => schedule()).observe(el, {attributes: true, attributeFilter: ['theater', 'fullscreen']});
  }
  // lastFullscreenKey: video waarvoor we al één keer automatische fullscreen probeerden.
  // pendingFullscreenKey: een fullscreen-verzoek dat wacht op bevestiging van de native app.
  // queued: voorkomt dat we apply() meerdere keren inplannen binnen dezelfde "tick".
  let lastFullscreenKey = '', pendingFullscreenKey = '', queued = false;
  let startedKey = '', resumeRequested = false, wasPausedInline = false;
  let configured = !window.JOETOEP_NATIVE_HOST;
  // WeakMap: een soort Map (sleutel/waarde-opslag), maar de sleutels (hier: video-elementen)
  // mogen door de browser opgeruimd worden uit het geheugen zodra ze nergens anders meer
  // gebruikt worden — handig om geen geheugen te lekken als video's verdwijnen.
  const volumeInitialized = new WeakMap();
  // Is de huidige pagina een "kijk-pagina" (video, live, embed of shorts)?
  const watchPage = () => location.pathname === '/watch' || /^\/(live|embed|shorts)\//.test(location.pathname);
  const video = () => document.querySelector('video.html5-main-video') || document.querySelector('video');
  // Een unieke sleutel per video: het video-ID uit de URL (?v=...), of anders het pad.
  const key = () => new URL(location.href).searchParams.get('v') || location.pathname;
  // Wordt telkens opnieuw uitgevoerd (via schedule()) om alle voorkeuren opnieuw toe te
  // passen zodra er iets relevants verandert op de pagina.
  function apply() {
    // Als de pagina nog niet eens een <html>-element heeft, is er nog niets te doen.
    if (!window.document?.documentElement) return;
    // Zet YouTube in donkere modus door het "dark"-attribuut op <html> te zetten, en
    // vertel de browser zelf ook dat we donker thema gebruiken (colorScheme).
    if (!document.documentElement.hasAttribute('dark')) document.documentElement.setAttribute('dark', '');
    document.documentElement.style.colorScheme = 'dark';
    // Eén <style>-element hergebruiken/aanmaken voor onze eigen CSS-regels.
    let style = document.getElementById('joetoep-preferences');
    if (!style) { style = document.createElement('style'); style.id = 'joetoep-preferences'; (document.head || document.documentElement).append(style); }
    // CSS opbouwen die ondertitels verstopt: op de kijkpagina zelf (disableCaptions) en/of
    // in de voorvertoningen van video's in de feed (disablePreviewCaptions).
    const css = (config.disableCaptions && watchPage() ? '.ytp-caption-window-container{display:none!important}' : '') +
      (config.disablePreviewCaptions ? 'ytd-video-preview .ytp-caption-window-container, ytd-rich-item-renderer .ytp-caption-window-container, ytm-rich-item-renderer .ytp-caption-window-container, ytm-inline-player .ytp-caption-window-container{display:none!important}' : '');
    // Alleen aanpassen als de tekst echt anders is, om onnodig herschilderen te voorkomen.
    if (style.textContent !== css) style.textContent = css;
    const v = video();
    // Bij de eerste keer dat een nieuwe video (per key()) écht speelt, zetten we het
    // volume op 70% — zowel op het <video>-element als via YouTube's eigen speler-API.
    if(v && !v.paused && v.readyState >= 2 && watchPage() && volumeInitialized.get(v)!==key()) {
      v.volume=0.7;
      try { document.querySelector('#movie_player')?.setVolume?.(70); } catch (_) {}
      volumeInitialized.set(v,key());
    }
    // Ondertitel-sporen (textTracks) van de video zelf uitzetten, en YouTube's eigen
    // ondertitel-optie leegmaken zodat hij niet stiekem weer aangaat.
    if (v && ((watchPage() && config.disableCaptions) || (!watchPage() && config.disablePreviewCaptions))) {
      for (const track of Array.from(v.textTracks || [])) if (track.mode !== 'disabled') track.mode = 'disabled';
      const player = document.querySelector('#movie_player');
      try { if (player?.getOption?.('captions', 'track')?.languageCode) player.setOption?.('captions', 'track', {}); } catch (_) {}
    }
    // V16: theater mode by default (YouTube's T) so the video uses the full width before fullscreen.
    // V19: NOOIT tijdens (of vlak na een verzoek om) fullscreen: de theaterknop indrukken terwijl
    // fullscreen start, liet de video terugvallen naar theatermodus i.p.v. fullscreen te blijven.
    const watch = document.querySelector('ytd-watch-flexy');
    // (Apple's eigen speler ligt over de pagina heen; daar stoort de theaterknop niet.)
    const anyFullscreen = Boolean(document.fullscreenElement || document.webkitFullscreenElement || watch?.hasAttribute('fullscreen'));
    if (watch) watchAttributes(watch);
    if (configured && config.theater && !anyFullscreen && !pendingFullscreenKey && watchPage() && theaterKey !== key()) {
      if (watch) {
        theaterKey = key();
        if (!watch.hasAttribute('theater')) { theaterRequestedAt = Date.now(); document.querySelector('.ytp-size-button')?.click(); }
      }
    }
    // V19: eerst theatermodus (brede video → soepelere overgang, en na fullscreen blijf je in
    // theater), pas daarna fullscreen. Wacht op YouTube's 'theater'-attribuut, hooguit 1,5 s.
    if (configured && config.theater && watch && !watch.hasAttribute('theater') && !anyFullscreen &&
        Date.now() - theaterRequestedAt < 1500) { waitingForTheater = true; return; }
    waitingForTheater = false;
    // Een hele reeks voorwaarden die allemaal waar moeten zijn voordat we automatisch
    // fullscreen mogen gaan: de pagina moet zichtbaar zijn, de instelling moet aanstaan,
    // het moet een kijkpagina zijn met een video die al speelt en genoeg geladen is
    // (readyState >= 2), we mogen dit nog niet gedaan hebben voor déze video, en er mag
    // geen Picture-in-Picture actief zijn.
    // V22: twee aparte opties — "bij laden" (eerste start van een video) en "bij afspelen"
    // (weer op play drukken terwijl hij inline stond).
    const firstStart = startedKey !== key();
    if (firstStart && Date.now() <= (window.__jtSkipFSUntil || 0) && v && !v.paused) startedKey = key();
    const allowed = Date.now() > (window.__jtSkipFSUntil || 0) && (firstStart ? config.automaticFullscreen : (config.fullscreenOnPlay && resumeRequested));
    if (window.JoeToepMedia.diagnostics().rawVisibility !== "visible" || !allowed || !watchPage() || !v || v.paused || v.ended || v.readyState < 2 ||
        lastFullscreenKey === key() || v.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement) return;
    // Only one attempt per video; exiting fullscreen never immediately reopens it.
    lastFullscreenKey = key(); startedKey = key(); resumeRequested = false;
    if (window.JOETOEP_NATIVE_HOST) {
      // In de native app kunnen we niet zomaar zelf fullscreen aanzetten (dat vereist vaak
      // een echte gebruikersactie); we sturen een event en wachten tot de app het bevestigt
      // via fulfillFullscreenRequest.
      pendingFullscreenKey = key();
      document.dispatchEvent(new Event('joetoep-automatic-fullscreen'));
    } else if (!window.JoeToepMedia.fullscreen()) lastFullscreenKey = '';
  }
  // Wordt door de native app aangeroepen als antwoord op het 'joetoep-automatic-fullscreen'
  // event hierboven, om te bevestigen dat fullscreen nu echt mag/kan gebeuren.
  function fulfillFullscreenRequest(nativeKeyboard = false) {
    const pending = pendingFullscreenKey; pendingFullscreenKey = '';
    const v = video();
    // Nog steeds dezelfde checks als bij het oorspronkelijke verzoek — intussen kan er
    // van alles veranderd zijn (video gepauzeerd, andere video geopend, enzovoort).
    if (!pending || pending !== key() || !(config.automaticFullscreen || config.fullscreenOnPlay) || !watchPage() || !v || v.paused || v.ended ||
        window.JoeToepMedia.diagnostics().rawVisibility !== 'visible' ||
        v.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement) return false;
    // Op desktop kan het richten van het toetsenbord op de speler ('focus') soms als
    // vervanger dienen voor echte fullscreen wanneer dit via het toetsenbord kwam.
    if (nativeKeyboard && !window.JOETOEP_MOBILE) {
      const player = document.querySelector('#movie_player');
      if (player && !document.fullscreenElement) { player.focus(); return 'keyboard'; }
    }
    return window.JoeToepMedia.fullscreen();
  }
  // Plant apply() in om één keer uit te voeren zodra de browser even niets anders te doen
  // heeft (queueMicrotask). Zo voorkomen we dat meerdere events vlak na elkaar (bijv.
  // 'playing' én 'loadedmetadata') apply() meerdere keren na elkaar laten draaien.
  function schedule() {
    if (queued) return;
    queued = true;
    queueMicrotask(() => { queued = false; apply(); });
  }
  // Bij deze video-events, bij YouTube's eigen "pagina-navigatie klaar"-event, en bij de
  // browser-terugknop (popstate) plannen we een nieuwe toepassing van onze voorkeuren.
  for (const event of ['playing', 'loadedmetadata', 'canplay']) window.addEventListener(event, schedule, true);
  // V19.2: pauze haalde de video uit fullscreen → bij verder spelen weer fullscreen (één keer).
  window.addEventListener('playing', () => {
    if (window.__joetoepExitedByPause) { window.__joetoepExitedByPause = false; lastFullscreenKey = ''; resumeRequested = true; schedule(); return; }
    // V22: "fullscreen bij afspelen": inline gepauzeerd → weer play → fullscreen.
    if (config.fullscreenOnPlay && wasPausedInline && startedKey === key() && Date.now() > (window.__jtSkipFSUntil || 0)) { lastFullscreenKey = ''; resumeRequested = true; schedule(); }
    wasPausedInline = false;
    if (startedKey !== key() && !config.automaticFullscreen) startedKey = key();
  }, true);
  window.addEventListener('pause', e => {
    const v = video();
    if (e.target !== v || v.ended) return;
    wasPausedInline = !(document.fullscreenElement || document.webkitFullscreenElement || v.webkitDisplayingFullscreen);
  }, true);
  // V19.3: na het VERLATEN van fullscreen altijd weer theatermodus (als die instelling aan staat).
  // YouTube zet theater soms uit bij het verlaten van fullscreen; dan zie je een kleine speler.
  document.addEventListener('fullscreenchange', () => {
    if (document.fullscreenElement || !configured || !config.theater || !watchPage()) return;
    queueMicrotask(() => requestAnimationFrame(() => {
      const w = document.querySelector('ytd-watch-flexy');
      if (w && !w.hasAttribute('theater') && !w.hasAttribute('fullscreen') && !document.fullscreenElement) {
        document.querySelector('.ytp-size-button')?.click();
      }
    }));
  });
  // Vangnet als het theater-attribuut nooit komt: bij de eerstvolgende tijd-update opnieuw kijken.
  window.addEventListener('timeupdate', () => { if (waitingForTheater) schedule(); }, true);
  document.addEventListener('yt-navigate-finish', schedule);
  window.addEventListener('popstate', schedule);
  // Een MutationObserver houdt veranderingen in de HTML-boom in de gaten (hier: de hele
  // pagina, childList/subtree = ook diep genest). Zodra er een nieuwe <video> of
  // watch-pagina-element bijkomt, plannen we opnieuw apply(), want YouTube bouwt de
  // pagina dynamisch op zonder hem helemaal te herladen.
  new MutationObserver(mutations => {
    if (mutations.some(m => Array.from(m.addedNodes).some(n => n.nodeType === 1 &&
      (n.matches?.('video, ytd-watch-flexy, .ytp-caption-window-container') || n.querySelector?.('video, ytd-watch-flexy'))))) schedule();
  }).observe(document.documentElement, {childList: true, subtree: true});
  // V11: type immediately in a new tab; '/' focuses search (YouTube's own shortcut) on every site layout.
  const editable = t => t?.closest?.('input,textarea,select,[contenteditable="true"],[role="textbox"]');
  // Checkt of een element daadwerkelijk op het scherm zichtbaar is (heeft afmetingen, en
  // is niet verborgen via CSS visibility).
  const visible = el => Boolean(el && el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
  // Zoekt het zoekveld van YouTube op — er zijn meerdere mogelijke CSS-selectors omdat
  // YouTube per pagina-type (desktop/mobiel/nieuw-mobiel) een andere opbouw gebruikt.
  function searchInput() {
    return Array.from(document.querySelectorAll('input#search, input[name="search_query"], input.ytSearchboxComponentInput, input.searchbox-input, ytm-searchbox input, input[type="search"]')).find(visible) || null;
  }
  // Zet de cursor in het zoekveld. Als het veld nog niet zichtbaar is, wordt eerst
  // geprobeerd op de zoek-knop te klikken (die het veld opent), en wordt dit tot 12 keer
  // opnieuw geprobeerd met 120ms tussenpozen (het veld kan even nodig hebben om te verschijnen).
  function focusSearch(attempt = 0) {
    const input = searchInput();
    if (input) { input.focus({preventScroll: true}); try { input.select(); } catch (_) {} return 'focused'; }
    const button = Array.from(document.querySelectorAll('button[aria-label="Search YouTube"], button[aria-label*="Search" i], button[aria-label*="Zoek" i], ytm-topbar-menu-button-renderer button, .topbar-menu-button-avatar-button, #search-icon-legacy'))
      .find(visible);
    if (button && attempt === 0) button.click();
    if (attempt < 12) { setTimeout(() => focusSearch(attempt + 1), 120); return 'pending'; }
    return 'unavailable';
  }
  // De '/' toets is YouTube's eigen sneltoets om naar zoeken te springen; wij vangen hem
  // af zodat dit ook werkt op pagina-indelingen waar YouTube dat zelf niet goed doet.
  window.addEventListener('keydown', e => {
    if (!e.isTrusted || e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey || editable(e.target)) return;
    e.preventDefault(); e.stopImmediatePropagation(); focusSearch();
  }, true);
  // V11: continue a reloaded/restored video exactly where it was (one bounded attempt per load).
  // resume onthoudt: op welk tijdstip (time) moet de video verdergaan, moet hij dan afspelen
  // (play), tot wanneer proberen we dit nog (until), en voor welke video (key).
  let resume = null;
  // Wordt aangeroepen door de native app om te zeggen: "deze video moet verdergaan vanaf
  // tijdstip X (en eventueel meteen afspelen)".
  function expectResume(time, play) {
    // Een ongeldig tijdstip (geen getal, of bijna het begin) hoeft niet hervat te worden.
    if (!Number.isFinite(time) || time < 1) return false;
    // We geven onszelf 20 seconden (until) om dit lukken; daarna geven we het op.
    resume = {time, play: Boolean(play), until: Date.now() + 20000, key: key()};
    applyResume(); return true;
  }
  // Probeert het opgeslagen "resume"-verzoek uit te voeren zodra de video daadwerkelijk
  // klaar is om te spoelen. Wordt telkens opnieuw aangeroepen totdat het lukt of verloopt.
  function applyResume() {
    const v = video();
    if (!resume || !v || !watchPage()) return;
    // Te lang gewacht, of ondertussen een andere video geopend: opgeven.
    if (Date.now() > resume.until || resume.key !== key()) { resume = null; return; }
    // readyState < 1 betekent: de video weet nog niet eens zijn eigen lengte, dus nog even wachten.
    if (v.readyState < 1) return;
    const target = resume;
    // Nooit precies tot het allerlaatste moment spoelen (duration - 1), dat kan raar gedrag geven.
    const end = Number.isFinite(v.duration) && v.duration > 0 ? v.duration - 1 : target.time;
    // Alleen echt spoelen als het verschil met het gewenste tijdstip groter is dan 2 seconden
    // (anders zitten we toch al ongeveer goed, bijvoorbeeld omdat de video daar al stond).
    if (Math.abs((v.currentTime || 0) - target.time) > 2) { try { v.currentTime = Math.max(0, Math.min(target.time, end)); } catch (_) {} }
    if (target.play && v.paused) v.play()?.catch(() => {});
    if (!target.play && !v.paused) v.pause();
    resume = null;
  }
  for (const event of ['loadedmetadata', 'canplay', 'playing']) window.addEventListener(event, applyResume, true);
  // De publieke API voor de native app: fullscreen bevestigen, zoeken activeren, een
  // hervat-tijdstip doorgeven, en de instellingen (config) bijwerken.
  window.JoeToepPreferences = Object.freeze({fulfillFullscreenRequest, focusSearch, expectResume,
    configure(next) { configured = true; config = {...config, ...next}; schedule(); }});
  // Als YouTube zelf het "dark"-attribuut op <html> verandert (bijvoorbeeld doordat de
  // gebruiker zelf het thema wisselt), passen we onze voorkeuren opnieuw toe.
  new MutationObserver(schedule).observe(document.documentElement, {attributes: true, attributeFilter: ['dark']});
  // Meteen bij het laden van het script één keer alles toepassen.
  schedule();
})();
