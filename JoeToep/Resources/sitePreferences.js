/* Event-driven preferences. Never replace or move the playing video. */
(() => {
  'use strict';
  if (!window.JoeToepMedia || window.JoeToepPreferences) return;
  let config = {automaticFullscreen: !window.JOETOEP_NATIVE_HOST, disableCaptions: true, disablePreviewCaptions: true, theater: true};
  let theaterKey = '';
  let lastFullscreenKey = '', pendingFullscreenKey = '', queued = false;
  let configured = !window.JOETOEP_NATIVE_HOST;
  const volumeInitialized = new WeakMap();
  const watchPage = () => location.pathname === '/watch' || /^\/(live|embed|shorts)\//.test(location.pathname);
  const video = () => document.querySelector('video.html5-main-video') || document.querySelector('video');
  const key = () => new URL(location.href).searchParams.get('v') || location.pathname;
  function apply() {
    if (!window.document?.documentElement) return;
    if (!document.documentElement.hasAttribute('dark')) document.documentElement.setAttribute('dark', '');
    document.documentElement.style.colorScheme = 'dark';
    let style = document.getElementById('joetoep-preferences');
    if (!style) { style = document.createElement('style'); style.id = 'joetoep-preferences'; (document.head || document.documentElement).append(style); }
    const css = (config.disableCaptions && watchPage() ? '.ytp-caption-window-container{display:none!important}' : '') +
      (config.disablePreviewCaptions ? 'ytd-video-preview .ytp-caption-window-container, ytd-rich-item-renderer .ytp-caption-window-container, ytm-rich-item-renderer .ytp-caption-window-container, ytm-inline-player .ytp-caption-window-container{display:none!important}' : '');
    if (style.textContent !== css) style.textContent = css;
    const v = video();
    if(v && !v.paused && v.readyState >= 2 && watchPage() && volumeInitialized.get(v)!==key()) {
      v.volume=0.7;
      try { document.querySelector('#movie_player')?.setVolume?.(70); } catch (_) {}
      volumeInitialized.set(v,key());
    }
    if (v && ((watchPage() && config.disableCaptions) || (!watchPage() && config.disablePreviewCaptions))) {
      for (const track of Array.from(v.textTracks || [])) if (track.mode !== 'disabled') track.mode = 'disabled';
      const player = document.querySelector('#movie_player');
      try { if (player?.getOption?.('captions', 'track')?.languageCode) player.setOption?.('captions', 'track', {}); } catch (_) {}
    }
    // V16: theater mode by default (YouTube's T) so the video uses the full width before fullscreen.
    if (configured && config.theater && !document.fullscreenElement && watchPage() && theaterKey !== key()) {
      const watch = document.querySelector('ytd-watch-flexy');
      if (watch && !watch.hasAttribute('fullscreen')) {
        theaterKey = key();
        if (!watch.hasAttribute('theater')) document.querySelector('.ytp-size-button')?.click();
      }
    }
    if (window.JoeToepMedia.diagnostics().rawVisibility !== "visible" || !config.automaticFullscreen || !watchPage() || !v || v.paused || v.ended || v.readyState < 2 ||
        lastFullscreenKey === key() || v.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement) return;
    // Only one attempt per video; exiting fullscreen never immediately reopens it.
    lastFullscreenKey = key();
    if (window.JOETOEP_NATIVE_HOST) {
      pendingFullscreenKey = key();
      document.dispatchEvent(new Event('joetoep-automatic-fullscreen'));
    } else if (!window.JoeToepMedia.fullscreen()) lastFullscreenKey = '';
  }
  function fulfillFullscreenRequest(nativeKeyboard = false) {
    const pending = pendingFullscreenKey; pendingFullscreenKey = '';
    const v = video();
    if (!pending || pending !== key() || !config.automaticFullscreen || !watchPage() || !v || v.paused || v.ended ||
        window.JoeToepMedia.diagnostics().rawVisibility !== 'visible' ||
        v.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement) return false;
    if (nativeKeyboard && !window.JOETOEP_MOBILE) {
      const player = document.querySelector('#movie_player');
      if (player && !document.fullscreenElement) { player.focus(); return 'keyboard'; }
    }
    return window.JoeToepMedia.fullscreen();
  }
  function schedule() {
    if (queued) return;
    queued = true;
    queueMicrotask(() => { queued = false; apply(); });
  }
  for (const event of ['playing', 'loadedmetadata', 'canplay']) window.addEventListener(event, schedule, true);
  document.addEventListener('yt-navigate-finish', schedule);
  window.addEventListener('popstate', schedule);
  new MutationObserver(mutations => {
    if (mutations.some(m => Array.from(m.addedNodes).some(n => n.nodeType === 1 &&
      (n.matches?.('video, ytd-watch-flexy, .ytp-caption-window-container') || n.querySelector?.('video, ytd-watch-flexy'))))) schedule();
  }).observe(document.documentElement, {childList: true, subtree: true});
  // V11: type immediately in a new tab; '/' focuses search (YouTube's own shortcut) on every site layout.
  const editable = t => t?.closest?.('input,textarea,select,[contenteditable="true"],[role="textbox"]');
  const visible = el => Boolean(el && el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
  function searchInput() {
    return Array.from(document.querySelectorAll('input#search, input[name="search_query"], input.ytSearchboxComponentInput, input.searchbox-input, ytm-searchbox input, input[type="search"]')).find(visible) || null;
  }
  function focusSearch(attempt = 0) {
    const input = searchInput();
    if (input) { input.focus({preventScroll: true}); try { input.select(); } catch (_) {} return 'focused'; }
    const button = Array.from(document.querySelectorAll('button[aria-label="Search YouTube"], button[aria-label*="Search" i], button[aria-label*="Zoek" i], ytm-topbar-menu-button-renderer button, .topbar-menu-button-avatar-button, #search-icon-legacy'))
      .find(visible);
    if (button && attempt === 0) button.click();
    if (attempt < 12) { setTimeout(() => focusSearch(attempt + 1), 120); return 'pending'; }
    return 'unavailable';
  }
  window.addEventListener('keydown', e => {
    if (!e.isTrusted || e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey || editable(e.target)) return;
    e.preventDefault(); e.stopImmediatePropagation(); focusSearch();
  }, true);
  // V11: continue a reloaded/restored video exactly where it was (one bounded attempt per load).
  let resume = null;
  function expectResume(time, play) {
    if (!Number.isFinite(time) || time < 1) return false;
    resume = {time, play: Boolean(play), until: Date.now() + 20000, key: key()};
    applyResume(); return true;
  }
  function applyResume() {
    const v = video();
    if (!resume || !v || !watchPage()) return;
    if (Date.now() > resume.until || resume.key !== key()) { resume = null; return; }
    if (v.readyState < 1) return;
    const target = resume;
    const end = Number.isFinite(v.duration) && v.duration > 0 ? v.duration - 1 : target.time;
    if (Math.abs((v.currentTime || 0) - target.time) > 2) { try { v.currentTime = Math.max(0, Math.min(target.time, end)); } catch (_) {} }
    if (target.play && v.paused) v.play()?.catch(() => {});
    if (!target.play && !v.paused) v.pause();
    resume = null;
  }
  for (const event of ['loadedmetadata', 'canplay', 'playing']) window.addEventListener(event, applyResume, true);
  window.JoeToepPreferences = Object.freeze({fulfillFullscreenRequest, focusSearch, expectResume,
    configure(next) { configured = true; config = {...config, ...next}; schedule(); }});
  new MutationObserver(schedule).observe(document.documentElement, {attributes: true, attributeFilter: ['dark']});
  schedule();
})();
