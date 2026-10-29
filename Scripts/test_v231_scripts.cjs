// V23.1: Mac-fullscreen klikken (playbackControls.js) en iPhone-opmaak vanaf het eerste frame
// (phoneLayout.js) in een echte DOM (jsdom). Trusted muis-events kan jsdom niet maken; de klik-logica
// wordt daarom getest via JoeToepControls.surfaceClick — precies de weg die de app neemt als macOS
// de klik niet aan de pagina geeft (VisionKit-laag over een gepauzeerde fullscreen-video).
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);

function macPlayer({ fullscreen = true, popup = false } = {}) {
  const dom = new JSDOM(`<!doctype html><html><head></head><body><ytd-app><div id="movie_player" class="html5-video-player">
    <div class="html5-video-container"><video class="html5-main-video"></video></div>
    <div class="ytp-popup ytp-settings-menu" style="display:${popup ? 'block' : 'none'}"></div>
    <div class="ytp-chrome-bottom"><button class="ytp-play-button"></button></div></div></ytd-app></body></html>`,
    { url: 'https://www.youtube.com/watch?v=abcdefghijk', runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window, d = w.document, v = d.querySelector('video'), p = d.getElementById('movie_player');
  let paused = true; const log = [];
  Object.defineProperty(v, 'paused', { get: () => paused });
  Object.defineProperty(v, 'ended', { get: () => false });
  p.playVideo = () => { paused = false; log.push('play'); };
  p.pauseVideo = () => { paused = true; log.push('pause'); };
  p.getPlayerState = () => (paused ? 2 : 1);
  p.seekTo = () => {};
  let fsEl = fullscreen ? d.querySelector('ytd-app') : null;
  Object.defineProperty(d, 'fullscreenElement', { get: () => fsEl, configurable: true });
  d.exitFullscreen = () => { log.push('exit'); fsEl = null; return Promise.resolve(); };
  // Opgemaakte maten (jsdom rekent geen lay-out uit).
  w.HTMLElement.prototype.getBoundingClientRect = function () { return { width: 800, height: 450, top: 0, left: 0, right: 800, bottom: 450 }; };
  for (const el of d.querySelectorAll('.ytp-popup')) {
    Object.defineProperty(el, 'offsetWidth', { get: () => (popup ? 200 : 0) });
    Object.defineProperty(el, 'offsetHeight', { get: () => (popup ? 200 : 0) });
  }
  const quiet = [];
  w.JoeToepMedia = { noteIntent: a => log.push('intent:' + a), quiet: ms => quiet.push(ms), diagnostics: () => ({ rawVisibility: 'visible' }), allowExit() {} };
  w.JOETOEP_MOBILE = false;
  w.eval(read('playbackControls.js'));
  return { w, d, v, log, quiet, setPaused: x => { paused = x; } };
}

test('Mac: a click via the app on a paused fullscreen video plays it (and ends the "quiet" restore)', () => {
  const t = macPlayer();
  assert.equal(t.w.JoeToepControls.surfaceClick(1), 'playing');
  assert.deepEqual(t.log, ['intent:play', 'play']);
  assert.deepEqual(t.quiet, [0]);
  assert.ok(t.d.getElementById('joetoep-click-bezel'), 'play/pause bezel is shown');
  t.w.close();
});
test('Mac: a second single click (later) pauses again', async () => {
  const t = macPlayer();
  t.w.JoeToepControls.surfaceClick(1);
  await new Promise(r => setTimeout(r, 5));
  assert.equal(t.w.JoeToepControls.surfaceClick(1), 'paused');
  assert.equal(t.log.filter(x => x === 'pause').length, 1);
  t.w.close();
});
test('Mac: double-click on a paused video leaves fullscreen and stays paused', async () => {
  const t = macPlayer();
  t.w.JoeToepControls.surfaceClick(1);           // 1e klik → speelt even
  assert.equal(t.w.JoeToepControls.surfaceClick(2), 'exit');
  assert.ok(t.log.includes('exit'));
  assert.equal(t.v.paused, true, 'state from before the double-click is restored');
  assert.equal(t.w.__joetoepDblClickKeepPaused, true);
  t.w.close();
});
test('Mac: double-click on a playing video leaves fullscreen and keeps playing', () => {
  const t = macPlayer(); t.setPaused(false);
  t.w.JoeToepControls.surfaceClick(1);
  t.w.JoeToepControls.surfaceClick(2);
  assert.ok(t.log.includes('exit'));
  assert.equal(t.v.paused, false);
  assert.equal(t.w.__joetoepDblClickKeepPaused, false);
  t.w.close();
});
test('Mac: outside fullscreen the app path does nothing (YouTube handles inline clicks itself)', () => {
  const t = macPlayer({ fullscreen: false });
  assert.equal(t.w.JoeToepControls.surfaceClick(1), 'ignored');
  assert.deepEqual(t.log, []);
  t.w.close();
});
test('Mac: with a YouTube menu open the click is left to YouTube (closes the menu)', () => {
  const t = macPlayer({ popup: true });
  assert.equal(t.w.JoeToepControls.surfaceClick(1), 'ignored');
  assert.deepEqual(t.log, []);
  t.w.close();
});
test('Mac: stress — 2,000 single clicks always alternate play/pause, never a double toggle', async () => {
  const t = macPlayer();
  for (let i = 0; i < 2000; i++) {
    const before = t.v.paused;
    t.w.JoeToepControls.surfaceClick(1);
    assert.equal(t.v.paused, !before);
  }
  t.w.close();
});

function phonePage({ url = 'https://www.youtube.com/', mobile = true, ipad = false } = {}) {
  const dom = new JSDOM('<!doctype html><html></html>', { url, runScripts: 'outside-only' });
  const w = dom.window;
  w.eval(`window.JOETOEP_MOBILE = ${mobile}; window.JOETOEP_IPAD = ${ipad};`);
  w.eval(read('phoneLayout.js'));
  return w;
}
test('iPhone desktop-YouTube: one video per row and a device-width viewport from document start', () => {
  const w = phonePage();
  const css = w.document.getElementById('joetoep-phone-layout')?.textContent || '';
  assert.match(css, /--ytd-rich-grid-items-per-row:1!important/);
  assert.match(css, /ytd-rich-grid-row[^{]*\{display:contents!important\}/);
  assert.equal(w.document.querySelector('meta[name=viewport]')?.content, 'width=device-width,initial-scale=1,viewport-fit=cover');
  w.close();
});
test('iPhone: the layout survives YouTube replacing the head (re-attached on navigation)', () => {
  const w = phonePage();
  w.document.getElementById('joetoep-phone-layout').remove();
  w.document.dispatchEvent(new w.Event('yt-navigate-finish'));
  assert.ok(w.document.getElementById('joetoep-phone-layout'));
  w.close();
});
test('iPhone layout is never applied on iPad, Mac, the mobile site or other sites', () => {
  for (const opts of [{ ipad: true }, { mobile: false }, { url: 'https://m.youtube.com/' }, { url: 'https://music.youtube.com/' }, { url: 'https://www.vimeo.com/' }]) {
    const w = phonePage(opts);
    assert.equal(w.document.getElementById('joetoep-phone-layout'), null, JSON.stringify(opts));
    w.close();
  }
});
test('iPhone layout script is idempotent (installed twice → one stylesheet)', () => {
  const w = phonePage();
  w.eval(read('phoneLayout.js'));
  assert.equal(w.document.querySelectorAll('#joetoep-phone-layout').length, 1);
  w.close();
});

(async () => {
  let failed = 0;
  for (const [name, body] of tests) {
    try { await body(); console.log('PASS', name); } catch (error) { failed++; console.log('FAIL', name); console.log(error); }
  }
  console.log(failed ? `${failed} FAILED` : `PASS ${tests.length} V23.1 scenarios (jsdom)`);
  process.exit(failed ? 1 : 0);
})();
