/* JoeToep V15: in-page ad handling, tuned by the ad-blocking strictness level.
 *  balanced+   : press YouTube's own "Skip" button as soon as it appears
 *  strict+     : fast-forward unskippable ads (muted), hide overlay banners
 *  aggressive+ : remove ad placements from player data (JSON.parse, fetch, ytInitialPlayerResponse)
 *  maximum     : also remove feed/search ad slots and close ad-blocker warnings
 * Installed at document start in the page world; configuration arrives in JOETOEP_ADSHIELD. */
(() => {
  'use strict';
  const host = location.hostname.toLowerCase();
  if (!(host === 'youtube.com' || host.endsWith('.youtube.com') || (location.protocol === 'file:' && window.JOETOEP_TEST))) return;
  if (window.JoeToepAdShield) return;
  const config = Object.assign({ enabled: false, skip: false, fastForward: false, prune: false, pruneFeed: false, dismissWarnings: false, cosmetic: false },
    window.JOETOEP_ADSHIELD || {});
  const stats = { skipped: 0, fastForwarded: 0, pruned: 0, feedPruned: 0, warnings: 0 };
  if (!config.enabled) {
    window.JoeToepAdShield = Object.freeze({ config: () => ({ ...config }), stats: () => ({ ...stats }) });
    return;
  }
  const PLAYER_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams'];
  const hasAdKeys = text => typeof text === 'string' && text.length > 60 &&
    (text.includes('"adPlacements"') || text.includes('"playerAds"') || text.includes('"adSlots"') ||
     (config.pruneFeed && text.includes('adSlotRenderer')));
  function prunePlayer(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    let removed = 0;
    for (const target of [obj, obj.playerResponse, obj.response?.playerResponse]) {
      if (!target || typeof target !== 'object') continue;
      for (const key of PLAYER_KEYS) if (Object.prototype.hasOwnProperty.call(target, key)) { delete target[key]; removed++; }
    }
    if (removed) stats.pruned += removed;
    return obj;
  }
  const isAdItem = item => item && typeof item === 'object' && (
    'adSlotRenderer' in item || 'promotedSparklesWebRenderer' in item || 'searchPyvRenderer' in item ||
    'promotedVideoRenderer' in item || 'compactPromotedVideoRenderer' in item || 'inFeedAdLayoutRenderer' in item ||
    (item.richItemRenderer && item.richItemRenderer.content && 'adSlotRenderer' in item.richItemRenderer.content) ||
    (item.richSectionRenderer && JSON.stringify(item.richSectionRenderer).includes('"adSlotRenderer"')));
  function pruneFeed(node, depth = 0) {
    if (!node || typeof node !== 'object' || depth > 40) return;
    if (Array.isArray(node)) {
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
  function clean(obj) {
    prunePlayer(obj);
    if (config.pruneFeed) pruneFeed(obj);
    return obj;
  }
  if (config.prune) {
    const nativeParse = JSON.parse;
    const parse = function(text, reviver) {
      const result = nativeParse.call(this, text, reviver);
      try { if (hasAdKeys(text)) clean(result); } catch (_) {}
      return result;
    };
    try { Object.defineProperty(parse, 'name', { value: 'parse' }); } catch (_) {}
    parse.toString = () => 'function parse() { [native code] }';
    JSON.parse = parse;
    for (const name of ['ytInitialPlayerResponse', 'ytInitialData']) {
      let stored;
      try {
        Object.defineProperty(window, name, { configurable: true, enumerable: true,
          get() { return stored; },
          set(value) { try { stored = name === 'ytInitialData' ? (config.pruneFeed ? (pruneFeed(value), value) : value) : clean(value); } catch (_) { stored = value; } } });
      } catch (_) {}
    }
    const nativeFetch = window.fetch;
    if (typeof nativeFetch === 'function') {
      const wrapped = async function(input, init) {
        const response = await nativeFetch.apply(this, arguments);
        try {
          const url = typeof input === 'string' ? input : (input && input.url) || '';
          if (!/\/youtubei\/v1\/(player|next|browse|search|reel)/.test(url) || !response.ok) return response;
          const text = await response.clone().text();
          if (!hasAdKeys(text)) return response;
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
        if (node.nodeType === 1 && (node.matches?.('ytd-enforcement-message-view-model, tp-yt-paper-dialog') || node.querySelector?.('ytd-enforcement-message-view-model'))) {
          dismissWarnings(); return;
        }
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
  }
  window.JoeToepAdShield = Object.freeze({ config: () => ({ ...config }), stats: () => ({ ...stats }), handleAd, dismissWarnings });
})();
