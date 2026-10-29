/* JoeToep V15: built-in SponsorBlock. Segments are fetched natively (hash-prefix API) and
 * handed to this page script. Event-driven (timeupdate/seeked), no polling. */
(() => {
  'use strict';
  const host = location.hostname.toLowerCase();
  if (!(host === 'youtube.com' || host.endsWith('.youtube.com') || (location.protocol === 'file:' && window.JOETOEP_TEST))) return;
  if (window.JoeToepSponsorBlock) return;
  let state = { videoID: '', segments: [], options: { modes: {}, colors: {}, titles: {}, notice: true, noticeMs: 4000, markers: true, minimum: 1, once: true }, enabled: false };
  const skipped = new Set();
  const allowed = new Set();
  let muting = null, askSegment = null, noticeTimer = 0, markerKey = '';
  const video = () => document.querySelector('video.html5-main-video') || document.querySelector('video');
  const currentVideoID = () => {
    try {
      const url = new URL(location.href);
      if (url.pathname === '/watch') return url.searchParams.get('v') || '';
      const m = url.pathname.match(/^\/(shorts|live|embed)\/([A-Za-z0-9_-]{10,16})/);
      return m ? m[2] : (window.JOETOEP_TEST ? state.videoID : '');
    } catch (_) { return ''; }
  };
  const modeOf = s => state.options.modes[s.category] || 'off';
  const active = () => state.enabled && state.videoID && state.videoID === currentVideoID();
  const container = () => document.querySelector('#movie_player') || document.querySelector('.html5-video-player') || document.body;

  function ensureStyle() {
    if (document.getElementById('joetoep-sponsorblock-style')) return;
    const style = document.createElement('style');
    style.id = 'joetoep-sponsorblock-style';
    style.textContent = `
      .joetoep-sb-layer{position:absolute;inset:0;pointer-events:none;z-index:40}
      .joetoep-sb-marker{position:absolute;top:0;bottom:0;opacity:.85;border-radius:1px}
      .joetoep-sb-toast{position:absolute;right:14px;bottom:72px;z-index:2147483000;display:flex;gap:10px;align-items:center;
        background:rgba(20,20,20,.88);color:#fff;font:600 13px -apple-system,system-ui,sans-serif;padding:8px 10px 8px 12px;
        border-radius:12px;box-shadow:0 6px 24px rgba(0,0,0,.35);pointer-events:auto;transition:opacity .25s,transform .25s;
        -webkit-backdrop-filter:blur(12px);backdrop-filter:blur(12px)}
      .joetoep-sb-toast[hidden]{display:none}
      .joetoep-sb-toast button{all:unset;cursor:pointer;background:rgba(255,255,255,.16);padding:6px 10px;border-radius:8px;font-weight:700}
      .joetoep-sb-dot{width:9px;height:9px;border-radius:50%}`;
    (document.head || document.documentElement).appendChild(style);
  }
  let toast = null;
  function showToast(text, color, buttonText, action, duration) {
    ensureStyle();
    const parent = container();
    if (!parent) return;
    if (!toast || !toast.isConnected || toast.parentElement !== parent) {
      toast?.remove();
      toast = document.createElement('div');
      toast.className = 'joetoep-sb-toast';
      toast.id = 'joetoep-sponsorblock-toast';
      if (getComputedStyle(parent).position === 'static' && parent !== document.body) parent.style.position = 'relative';
      parent.appendChild(toast);
    }
    toast.textContent = '';
    const dot = document.createElement('span'); dot.className = 'joetoep-sb-dot'; dot.style.background = color || '#00d400';
    const label = document.createElement('span'); label.textContent = text;
    toast.append(dot, label);
    if (buttonText) {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = buttonText;
      button.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); action?.(); }, true);
      toast.appendChild(button);
    }
    toast.hidden = false;
    clearTimeout(noticeTimer);
    if (duration > 0) noticeTimer = setTimeout(() => { if (toast) toast.hidden = true; }, duration);
  }
  const hideToast = () => { clearTimeout(noticeTimer); if (toast) toast.hidden = true; };
  function report(segment, seconds) {
    try {
      document.documentElement.dataset.joetoepSponsorSkip = JSON.stringify({ category: segment.category, seconds, uuid: segment.uuid });
      document.dispatchEvent(new Event('joetoep-sponsor-skipped'));
    } catch (_) {}
  }
  function skip(segment, automatic) {
    const v = video();
    if (!v) return;
    const end = Math.min(segment.end, Number.isFinite(v.duration) && v.duration > 0 ? v.duration - 0.05 : segment.end);
    const from = v.currentTime || segment.start;
    skipped.add(segment.uuid);
    try { v.currentTime = end + 0.01; } catch (_) { return; }
    report(segment, Math.max(0, end - from));
    if (state.options.notice) {
      const title = state.options.titles[segment.category] || segment.category;
      showToast((automatic ? 'Skipped: ' : '') + title, state.options.colors[segment.category], 'Undo', () => {
        allowed.add(segment.uuid); skipped.delete(segment.uuid);
        try { v.currentTime = segment.start; } catch (_) {}
        hideToast();
      }, state.options.noticeMs || 4000);
    }
  }
  function evaluate() {
    const v = video();
    if (!v || !active()) { restoreMute(); return; }
    const t = v.currentTime || 0;
    let inside = null;
    for (const s of state.segments) {
      if (t >= s.start && t < s.end - 0.2) { inside = s; break; }
    }
    if (!inside) { restoreMute(); if (askSegment) { askSegment = null; hideToast(); } return; }
    const mode = modeOf(inside);
    if (inside.end - inside.start < (state.options.minimum || 0) || allowed.has(inside.uuid)) return;
    if (mode === 'skip' && inside.action !== 'mute') {
      if (state.options.once && skipped.has(inside.uuid)) return;
      skip(inside, true);
    } else if (mode === 'mute' || (mode === 'skip' && inside.action === 'mute')) {
      if (!muting) { muting = { uuid: inside.uuid, wasMuted: v.muted }; v.muted = true; }
    } else if (mode === 'ask') {
      if (askSegment?.uuid !== inside.uuid) {
        askSegment = inside;
        const title = state.options.titles[inside.category] || inside.category;
        showToast(title, state.options.colors[inside.category], 'Skip ▸', () => { skip(inside, false); askSegment = null; },
          Math.max(1500, (inside.end - t) * 1000));
      }
    }
  }
  function restoreMute() {
    if (!muting) return;
    const v = video();
    if (v) v.muted = muting.wasMuted;
    muting = null;
  }
  function drawMarkers() {
    const v = video();
    const key = state.videoID + ':' + state.segments.length + ':' + (v?.duration || 0) + ':' + state.options.markers;
    const bar = document.querySelector('.ytp-progress-bar') || document.querySelector('.ytm-progress-bar, .ytProgressBarLineProgressBarLine, .progress-bar-line');
    const existing = document.getElementById('joetoep-sponsorblock-markers');
    if (!active() || !state.options.markers || !bar || !v || !Number.isFinite(v.duration) || v.duration <= 0) {
      existing?.remove(); markerKey = ''; return;
    }
    if (existing && existing.parentElement === bar && markerKey === key) return;
    existing?.remove();
    ensureStyle();
    const layer = document.createElement('div');
    layer.id = 'joetoep-sponsorblock-markers'; layer.className = 'joetoep-sb-layer';
    for (const s of state.segments) {
      if (modeOf(s) === 'off') continue;
      const mark = document.createElement('div');
      mark.className = 'joetoep-sb-marker';
      mark.style.left = (Math.max(0, s.start) / v.duration * 100) + '%';
      mark.style.width = (Math.max(0.2, (Math.min(s.end, v.duration) - s.start) / v.duration * 100)) + '%';
      mark.style.background = state.options.colors[s.category] || '#00d400';
      layer.appendChild(mark);
    }
    if (getComputedStyle(bar).position === 'static') bar.style.position = 'relative';
    bar.appendChild(layer);
    markerKey = key;
  }
  window.addEventListener('timeupdate', e => { if (e.target === video()) evaluate(); }, true);
  window.addEventListener('seeked', e => {
    const v = e.target;
    if (v !== video()) return;
    // Seeking back before a skipped segment allows skipping it again (unless undone).
    for (const s of state.segments) if (v.currentTime < s.start - 1) skipped.delete(s.uuid);
    evaluate();
  }, true);
  window.addEventListener('durationchange', drawMarkers, true);
  window.addEventListener('loadedmetadata', drawMarkers, true);
  document.addEventListener('yt-navigate-finish', () => { hideToast(); restoreMute(); markerKey = ''; setTimeout(drawMarkers, 400); });
  window.JoeToepSponsorBlock = Object.freeze({
    set(videoID, segments, options, enabled = true) {
      if (videoID !== state.videoID) { skipped.clear(); allowed.clear(); askSegment = null; hideToast(); restoreMute(); }
      state = { videoID: String(videoID || ''), enabled: Boolean(enabled),
        segments: Array.isArray(segments) ? segments.filter(s => Number.isFinite(s.start) && Number.isFinite(s.end) && s.end > s.start) : [],
        options: { ...state.options, ...(options || {}) } };
      markerKey = ''; drawMarkers(); evaluate();
      return state.segments.length;
    },
    clear() { state = { ...state, videoID: '', segments: [] }; hideToast(); restoreMute(); drawMarkers(); },
    status() { return { videoID: state.videoID, current: currentVideoID(), count: state.segments.length, enabled: state.enabled, skipped: skipped.size }; }
  });
})();
