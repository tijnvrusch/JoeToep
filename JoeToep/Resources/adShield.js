/* JoeToep V15: in-page ad handling, tuned by the ad-blocking strictness level.
 *  balanced+   : press YouTube's own "Skip" button as soon as it appears
 *  strict+     : fast-forward unskippable ads (muted), hide overlay banners
 *  aggressive+ : remove ad placements from player data (JSON.parse, fetch, ytInitialPlayerResponse)
 *  maximum     : also remove feed/search ad slots and close ad-blocker warnings
 * Installed at document start in the page world; configuration arrives in JOETOEP_ADSHIELD. */
(() => {
  'use strict';
  // Alleen op YouTube (of, voor onze eigen tests, een lokaal bestand met JOETOEP_TEST aan).
  const host = location.hostname.toLowerCase();
  if (!(host === 'youtube.com' || host.endsWith('.youtube.com') || (location.protocol === 'file:' && window.JOETOEP_TEST))) return;
  // Niet dubbel opzetten.
  if (window.JoeToepAdShield) return;
  // Object.assign kopieert eigenschappen van het tweede object over het eerste: zo krijgen
  // we standaardwaarden (allemaal uit) die overschreven worden door wat de native app al
  // vóór het laden van dit script in window.JOETOEP_ADSHIELD heeft klaargezet.
  const config = Object.assign({ enabled: false, skip: false, fastForward: false, prune: false, pruneFeed: false, dismissWarnings: false, cosmetic: false },
    window.JOETOEP_ADSHIELD || {});
  // Telt hoe vaak we elke actie hebben uitgevoerd, zodat de app dit kan tonen aan de gebruiker.
  const stats = { skipped: 0, fastForwarded: 0, pruned: 0, feedPruned: 0, warnings: 0 };
  // Als adblokkeren helemaal uitstaat, zetten we alleen de (lege) publieke API klaar en stoppen we.
  if (!config.enabled) {
    window.JoeToepAdShield = Object.freeze({ config: () => ({ ...config }), stats: () => ({ ...stats }) });
    return;
  }
  // Dit zijn de sleutels in YouTube's eigen data-objecten die advertentie-plaatsen beschrijven.
  const PLAYER_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams'];
  // Snelle check (op de rauwe tekst, vóór het JSON.parse'en) of een stuk data überhaupt
  // iets met advertenties te maken zou kunnen hebben — zo hoeven we niet elk stuk JSON op
  // de pagina te doorzoeken.
  const hasAdKeys = text => typeof text === 'string' && text.length > 60 &&
    (text.includes('"adPlacements"') || text.includes('"playerAds"') || text.includes('"adSlots"') ||
     (config.pruneFeed && text.includes('adSlotRenderer')));
  // Verwijdert de advertentie-sleutels (PLAYER_KEYS) uit het speler-object van YouTube,
  // zodat de speler zelf geen advertenties meer kan plannen. We checken drie mogelijke
  // plekken waar dat object zich kan bevinden, afhankelijk van hoe de data is opgebouwd.
  function prunePlayer(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    let removed = 0;
    for (const target of [obj, obj.playerResponse, obj.response?.playerResponse]) {
      if (!target || typeof target !== 'object') continue;
      // hasOwnProperty checkt of de sleutel er echt op dit object staat (niet via prototype).
      for (const key of PLAYER_KEYS) if (Object.prototype.hasOwnProperty.call(target, key)) { delete target[key]; removed++; }
    }
    if (removed) stats.pruned += removed;
    return obj;
  }
  // Herkent of een "item" uit de feed (startpagina/zoekresultaten) een advertentie is,
  // door te kijken of het één van de bekende advertentie-renderer-sleutels bevat.
  const isAdItem = item => item && typeof item === 'object' && (
    'adSlotRenderer' in item || 'promotedSparklesWebRenderer' in item || 'searchPyvRenderer' in item ||
    'promotedVideoRenderer' in item || 'compactPromotedVideoRenderer' in item || 'inFeedAdLayoutRenderer' in item ||
    (item.richItemRenderer && item.richItemRenderer.content && 'adSlotRenderer' in item.richItemRenderer.content) ||
    (item.richSectionRenderer && JSON.stringify(item.richSectionRenderer).includes('"adSlotRenderer"')));
  // Loopt recursief (roept zichzelf steeds opnieuw aan, dieper de boom in) door het hele
  // data-object en verwijdert advertentie-items uit arrays. "depth" voorkomt dat we bij een
  // heel diep genest object voor altijd doorgaan (veiligheidslimiet).
  function pruneFeed(node, depth = 0) {
    if (!node || typeof node !== 'object' || depth > 40) return;
    if (Array.isArray(node)) {
      // Van achteren naar voren doorlopen, want splice() verandert de lengte van de array
      // — van voren naar achteren zou items overslaan.
      for (let i = node.length - 1; i >= 0; i--) {
        if (isAdItem(node[i])) { node.splice(i, 1); stats.feedPruned++; }
        else pruneFeed(node[i], depth + 1);
      }
      return;
    }
    for (const key in node) {
      const value = node[key];
      if (value && typeof value === 'object') pruneFeed(value, depth + 1);
    }
  }
  // Combineert beide opschoon-stappen: altijd de speler-advertenties weg, en als
  // pruneFeed aanstaat ook de feed-advertenties.
  function clean(obj) {
    prunePlayer(obj);
    if (config.pruneFeed) pruneFeed(obj);
    return obj;
  }
  if (config.prune) {
    // We "hooken" (vervangen) de ingebouwde JSON.parse-functie door onze eigen versie die
    // eerst normaal parset en daarna, als het om speler-data lijkt te gaan, de advertenties
    // eruit haalt. YouTube gebruikt zelf JSON.parse om zijn data te lezen, dus zo grijpen
    // we in vóórdat YouTube de advertentie-info ooit ziet.
    const nativeParse = JSON.parse;
    const parse = function(text, reviver) {
      const result = nativeParse.call(this, text, reviver);
      try { if (hasAdKeys(text)) clean(result); } catch (_) {}
      return result;
    };
    // We doen ons best om onze vervangfunctie te vermommen als de originele (naam en
    // toString), zodat scripts die controleren "is dit nog de native functie?" niet raar
    // gaan doen. Dit is puur cosmetisch/compatibiliteit, geen beveiliging.
    try { Object.defineProperty(parse, 'name', { value: 'parse' }); } catch (_) {}
    parse.toString = () => 'function parse() { [native code] }';
    JSON.parse = parse;
    // YouTube zet zijn beginwaarden vaak direct in window.ytInitialPlayerResponse /
    // ytInitialData (los van JSON.parse, als een <script>-tag met een toewijzing).
    // Object.defineProperty met een eigen get/set laat ons "meeluisteren" zodra YouTube
    // zo'n waarde toekent: de set-functie hieronder schoont de data op vóórdat hij echt
    // wordt opgeslagen, en de get-functie geeft gewoon de (opgeschoonde) waarde terug.
    for (const name of ['ytInitialPlayerResponse', 'ytInitialData']) {
      let stored;
      try {
        Object.defineProperty(window, name, { configurable: true, enumerable: true,
          get() { return stored; },
          set(value) { try { stored = name === 'ytInitialData' ? (config.pruneFeed ? (pruneFeed(value), value) : value) : clean(value); } catch (_) { stored = value; } } });
      } catch (_) {}
    }
    // Ook de ingebouwde fetch-functie (waarmee de pagina later, zonder herladen, nieuwe
    // data ophaalt) vervangen we door een versie die de respons naleest en, als het om een
    // relevante YouTube-API-aanroep gaat, de advertentiedata eruit filtert vóór YouTube
    // het antwoord te zien krijgt.
    const nativeFetch = window.fetch;
    if (typeof nativeFetch === 'function') {
      const wrapped = async function(input, init) {
        // Eerst gewoon het echte netwerkverzoek laten gebeuren.
        const response = await nativeFetch.apply(this, arguments);
        try {
          const url = typeof input === 'string' ? input : (input && input.url) || '';
          // Alleen ingrijpen bij YouTube's eigen interne API-endpoints, en alleen bij een
          // geslaagd antwoord.
          if (!/\/youtubei\/v1\/(player|next|browse|search|reel)/.test(url) || !response.ok) return response;
          // response.clone() maakt een kopie van de respons, zodat we de tekst kunnen lezen
          // zonder de originele respons "op te maken" (een Response kan maar één keer gelezen worden).
          const text = await response.clone().text();
          if (!hasAdKeys(text)) return response;
          // De opgeschoonde data weer terug in een nieuwe Response stoppen, met dezelfde
          // status en headers, zodat YouTube niets merkt behalve dat de advertenties weg zijn.
          const body = JSON.stringify(clean(nativeParse(text)));
          return new Response(body, { status: response.status, statusText: response.statusText, headers: response.headers });
        } catch (_) { return response; }
      };
      wrapped.toString = () => 'function fetch() { [native code] }';
      window.fetch = wrapped;
    }
  }
  // Cosmetic: overlay banners and companion slots inside the player.
  function installStyle() {
    if (!config.cosmetic || document.getElementById('joetoep-adshield-style')) return;
    const style = document.createElement('style');
    style.id = 'joetoep-adshield-style';
    style.textContent = `.ytp-ad-overlay-container,.ytp-ad-overlay-slot,.ytp-ad-image-overlay,#player-ads,#masthead-ad,
      ytd-ad-slot-renderer,ytd-in-feed-ad-layout-renderer,ytd-banner-promo-renderer,ytd-promoted-sparkles-web-renderer,
      ytd-promoted-video-renderer,ytd-compact-promoted-video-renderer,ytd-search-pyv-renderer,ytm-promoted-sparkles-web-renderer,
      ytm-companion-ad-renderer,ytm-promoted-video-renderer,ad-slot-renderer,ytd-rich-item-renderer:has(ytd-ad-slot-renderer),
      ytd-statement-banner-renderer,ytd-player-legacy-desktop-watch-ads-renderer{display:none!important}`;
    (document.head || document.documentElement).appendChild(style);
  }
  installStyle();
  document.addEventListener('DOMContentLoaded', installStyle, { once: true });

  // In-player ads.
  let adState = null, observedPlayer = null;
  const skipSelectors = '.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-ad-skip-button-slot button, button.ytp-ad-skip-button-container, .ytm-skip-ad-button, ytm-skip-ad-button button';
  function handleAd() {
    const player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
    if (!player) return;
    const v = player.querySelector('video');
    const showing = player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting');
    if (showing && v) {
      if (config.skip) {
        const button = player.querySelector(skipSelectors) || document.querySelector(skipSelectors);
        if (button && button.offsetParent !== null) { button.click(); stats.skipped++; }
      }
      if (config.fastForward) {
        if (!adState) adState = { muted: v.muted, rate: v.playbackRate || 1 };
        v.muted = true;
        try { if (v.playbackRate < 8) v.playbackRate = 16; } catch (_) {}
        if (Number.isFinite(v.duration) && v.duration > 0 && v.currentTime < v.duration - 0.25) {
          try { v.currentTime = v.duration - 0.1; stats.fastForwarded++; } catch (_) {}
        }
      }
    } else if (adState && v) {
      v.muted = adState.muted;
      try { v.playbackRate = adState.rate >= 8 ? 1 : adState.rate; } catch (_) {}
      adState = null;
    }
  }
  const classObserver = new MutationObserver(handleAd);
  function watchPlayer() {
    const player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
    if (player && player !== observedPlayer) {
      observedPlayer = player;
      classObserver.disconnect();
      classObserver.observe(player, { attributes: true, attributeFilter: ['class'], subtree: false });
      handleAd();
    }
  }
  if (config.skip || config.fastForward) {
    // A skip button can appear without a class change; timeupdate covers that during an ad.
    window.addEventListener('timeupdate', e => {
      if (observedPlayer?.classList.contains('ad-showing') || adState) handleAd();
    }, true);
    window.addEventListener('loadedmetadata', () => { watchPlayer(); handleAd(); }, true);
    document.addEventListener('yt-navigate-finish', watchPlayer);
    document.addEventListener('DOMContentLoaded', watchPlayer, { once: true });
  }
  // Ad-blocker warnings ("Ad blockers are not allowed").
  function dismissWarnings() {
    const dialog = document.querySelector('ytd-enforcement-message-view-model');
    if (!dialog) return;
    const shell = dialog.closest('tp-yt-paper-dialog, ytd-popup-container > *') || dialog;
    shell.remove();
    document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach(n => n.remove());
    document.body?.style.removeProperty('overflow');
    const v = document.querySelector('video.html5-main-video');
    if (v && v.paused && !v.ended) v.play()?.catch?.(() => {});
    stats.warnings++;
  }
  if (config.dismissWarnings) {
    new MutationObserver(records => {
      for (const record of records) for (const node of record.addedNodes) {
        if (node.nodeType === 1 && (node.localName === 'ytd-enforcement-message-view-model' || node.localName === 'tp-yt-paper-dialog' ||
            (node.firstElementChild && node.getElementsByTagName('ytd-enforcement-message-view-model').length))) {
          dismissWarnings(); return;
        }
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
  }
  window.JoeToepAdShield = Object.freeze({ config: () => ({ ...config }), stats: () => ({ ...stats }), handleAd, dismissWarnings });
})();
