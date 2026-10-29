// V25: play/pauze precies één keer — de stil-bewaking (quiet) en het hervatten na herstel mogen een
// start door JOU (tik op de speler, ▶ in Apple's fullscreen-speler of PiP) nooit meer terugdraaien.
// jsdom; WebKit/AVKit gesimuleerd: een "native" start zet de video aan zonder play() van een script.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const media = read('mediaCompatibility.js');
const prefs = read('sitePreferences.js');
const tests = [];
const test = (name, body) => tests.push([name, body]);

function page({ mobile = true, id = 'abcdefghijk', quietVideo = '', withPrefs = false } = {}) {
  const dom = new JSDOM(`<!doctype html><html><head></head><body><ytd-watch-flexy><div id="movie_player">
    <video class="html5-main-video"></video></div></ytd-watch-flexy><div id="elsewhere"></div></body></html>`,
    { url: 'https://www.youtube.com/watch?v=' + id, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window, d = w.document;
  let now = 50000, visibility = 'visible';
  w.Date.now = () => now;
  Object.defineProperty(w.Document.prototype, 'visibilityState', { configurable: true, get() { return visibility; } });
  Object.defineProperty(w.Document.prototype, 'hidden', { configurable: true, get() { return visibility !== 'visible'; } });
  const st = new WeakMap();
  const s = v => { if (!st.has(v)) st.set(v, { paused: true, mode: 'inline', ready: 4 }); return st.get(v); };
  for (const key of ['paused']) Object.defineProperty(w.HTMLMediaElement.prototype, key, { configurable: true, get() { return s(this).paused; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'ended', { configurable: true, get() { return false; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'readyState', { configurable: true, get() { return s(this).ready; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'duration', { configurable: true, get() { return 600; } });
  for (const [k, val] of [['videoWidth', 1920], ['videoHeight', 1080]]) Object.defineProperty(w.HTMLVideoElement.prototype, k, { configurable: true, get() { return val; } });
  Object.defineProperty(w.HTMLVideoElement.prototype, 'webkitPresentationMode', { configurable: true, get() { return s(this).mode; } });
  Object.defineProperty(w.HTMLVideoElement.prototype, 'webkitDisplayingFullscreen', { configurable: true, get() { return s(this).mode === 'fullscreen'; } });
  const fire = (t, type) => t.dispatchEvent(new w.Event(type));
  const calls = { scriptPlay: 0, pause: 0 };
  // De "echte" (WebKit) play/pause: zet de stand en stuurt de events zoals Safari dat doet.
  const rawPlay = v => { if (!s(v).paused) return; s(v).paused = false; fire(v, 'play'); if (!s(v).paused) fire(v, 'playing'); };
  const rawPause = v => { if (s(v).paused) return; calls.pause++; s(v).paused = true; fire(v, 'pause'); };
  w.HTMLMediaElement.prototype.play = function() { calls.scriptPlay++; rawPlay(this); return Promise.resolve(); };
  w.HTMLMediaElement.prototype.pause = function() { rawPause(this); };
  w.HTMLVideoElement.prototype.webkitSupportsPresentationMode = () => true;
  w.HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) { s(this).mode = mode; fire(this, 'webkitpresentationmodechanged'); };
  w.HTMLVideoElement.prototype.webkitEnterFullscreen = function() { s(this).mode = 'fullscreen'; fire(this, 'webkitbeginfullscreen'); };
  w.HTMLVideoElement.prototype.webkitExitFullscreen = function() { s(this).mode = 'inline'; fire(this, 'webkitendfullscreen'); };
  w.JOETOEP_MOBILE = mobile;
  w.JOETOEP_QUIET_VIDEO = quietVideo;
  // Echte (trusted) aanrakingen kan jsdom niet maken: luisteraars onthouden en zelf aanroepen.
  const captured = {}; const add = w.addEventListener.bind(w);
  w.addEventListener = (type, fn, o) => { (captured[type] ??= []).push(fn); return add(type, fn, o); };
  w.eval(media);
  if (withPrefs) { w.JOETOEP_NATIVE_HOST = true; w.eval(prefs); w.JoeToepPreferences.configure({ automaticFullscreen: false, theater: false }); }
  w.addEventListener = add;
  const v = d.querySelector('video');
  const touch = target => { for (const t of ['pointerdown', 'touchstart']) (captured[t] || []).forEach(fn => fn({ isTrusted: true, type: t, target })); };
  return {
    w, d, v, api: w.JoeToepMedia, calls, fire,
    advance(ms) { now += ms; },
    nativePlay() { rawPlay(v); },                 // ▶ in Apple's fullscreen-speler / PiP-venster
    nativePause() { rawPause(v); },               // ❚❚ in Apple's fullscreen-speler
    autoplay() { v.play(); },                     // YouTube's eigen script
    enterNativeFullscreen() { s(v).mode = 'fullscreen'; fire(v, 'webkitbeginfullscreen'); fire(v, 'webkitpresentationmodechanged'); },
    stall() { fire(v, 'waiting'); fire(v, 'playing'); },
    touchPlayer() { touch(v); },
    touchElsewhere() { touch(d.getElementById('elsewhere')); },
    hide() { visibility = 'hidden'; fire(d, 'visibilitychange'); },
    setReady(n) { s(v).ready = n; },
    get playing() { return !v.paused; }
  };
}

test('restored tab: YouTube autoplay is still blocked (quiet until gesture)', () => {
  const t = page({ quietVideo: 'abcdefghijk' });
  t.autoplay();
  assert.equal(t.playing, false);
  assert.equal(t.api.diagnostics().status, 'sync-quiet-blocked-autoplay');
});
test('restored tab in Apple fullscreen: ▶ plays immediately and stays playing (the V24 bug)', () => {
  const t = page({ quietVideo: 'abcdefghijk' });
  t.enterNativeFullscreen(); t.advance(1500);
  t.nativePlay();
  assert.equal(t.playing, true, 'native ▶ must not be paused');
  assert.equal(t.calls.pause, 0);
  assert.match(t.api.diagnostics().status, /quiet-released/);
  assert.equal(t.api.userPlayIntent(), true);
});
test('after you played it, a late quiet(-1) (page finished loading) is ignored; buffering never pauses', () => {
  const t = page({ quietVideo: 'abcdefghijk' });
  t.enterNativeFullscreen(); t.advance(1500); t.nativePlay();
  t.advance(4000);
  assert.equal(t.api.quiet(-1), false, 'didFinish re-arm is skipped for a video you started');
  t.stall(); t.stall();
  assert.equal(t.playing, true);
  assert.equal(t.calls.pause, 0);
});
test('a quiet armed WHILE playing never pauses the running video on its next "playing"', () => {
  const t = page();
  t.touchPlayer(); t.autoplay(); assert.equal(t.playing, true);
  t.advance(5000); t.api.quiet(8000);
  t.stall();
  assert.equal(t.playing, true);
});
test('sync quiet (other device plays): native ▶ in fullscreen plays, script autoplay does not', () => {
  const t = page();
  t.enterNativeFullscreen(); t.advance(2000);
  t.api.quiet(8000); t.autoplay();
  assert.equal(t.playing, false, 'autoplay blocked');
  t.advance(1200); t.nativePlay();
  assert.equal(t.playing, true, 'your tap wins');
});
test('a real tap on the inline player plays exactly once; a tap elsewhere does not unlock autoplay', () => {
  const t = page({ quietVideo: 'abcdefghijk' });
  t.touchElsewhere(); t.advance(200); t.autoplay();
  assert.equal(t.playing, false);
  t.advance(3000); t.touchPlayer(); t.autoplay();
  assert.equal(t.playing, true);
  assert.equal(t.calls.pause, 1, 'only the blocked autoplay was paused');
});
test('Mac: no native-origin shortcut (clicks reach the page there) — autoplay under quiet stays blocked', () => {
  const t = page({ mobile: false, quietVideo: 'abcdefghijk' });
  t.enterNativeFullscreen(); t.advance(2000); t.nativePlay();
  assert.equal(t.playing, false);
});
test('❚❚ in Apple fullscreen is your pause (no recovery), but a system pause before backgrounding is not', () => {
  const t = page();
  t.touchPlayer(); t.autoplay(); t.enterNativeFullscreen(); t.advance(2000);
  t.nativePause();
  let d = t.api.diagnostics();
  assert.equal(d.status, 'native-user-pause'); assert.equal(d.userPause, true);
  t.nativePlay(); t.advance(3000);
  t.nativePause(); t.advance(200); t.hide();
  d = t.api.diagnostics();
  assert.equal(d.userPause, false, 'pause right before the app left = system, background protection stays');
});
test('native pause right after a presentation change (WebKit leaving fullscreen) is not taken as yours', () => {
  const t = page();
  t.touchPlayer(); t.autoplay(); t.advance(3000);
  t.enterNativeFullscreen(); t.advance(100); t.nativePause();
  assert.notEqual(t.api.diagnostics().status, 'native-user-pause');
});
test('restore "paused at 2:00": your own first ▶ is never paused by the resume step', () => {
  const t = page({ withPrefs: true });
  t.setReady(0);
  t.w.JoeToepPreferences.expectResume(120, false);
  t.setReady(4);
  t.enterNativeFullscreen(); t.advance(1500); t.nativePlay();
  t.fire(t.v, 'loadedmetadata');
  assert.equal(t.playing, true);
  assert.equal(Math.round(t.v.currentTime), 120, 'still seeks to the saved spot');
});
test('restore "paused": YouTube autoplay IS paused by the resume step', () => {
  const t = page({ withPrefs: true });
  t.setReady(0);
  t.w.JoeToepPreferences.expectResume(120, false);
  t.setReady(4); t.autoplay();
  assert.equal(t.playing, false);
});
test('stress: 2,000 native ▶/❚❚ in fullscreen with quiet re-armed every time — each tap acts exactly once', () => {
  const t = page({ quietVideo: 'abcdefghijk' });
  t.enterNativeFullscreen(); t.advance(2000);
  let wrong = 0;
  for (let i = 0; i < 2000; i++) {
    t.api.quiet(i % 2 ? 8000 : -1);
    t.advance(1000); t.nativePlay(); if (!t.playing) wrong++;
    t.stall(); if (!t.playing) wrong++;
    t.advance(1000); t.nativePause(); if (t.playing) wrong++;
  }
  assert.equal(wrong, 0);
});
test('stress: 2,000 script autoplays under quiet are all blocked, none leaks through', () => {
  const t = page();
  let leaked = 0;
  for (let i = 0; i < 2000; i++) { t.api.quiet(8000); t.advance(1600); t.autoplay(); if (t.playing) leaked++; t.advance(10); }
  assert.equal(leaked, 0);
});

(async () => {
  let failed = 0;
  for (const [name, body] of tests) {
    try { await body(); console.log('PASS', name); }
    catch (e) { failed++; console.log('FAIL', name, '\n ', e.message); }
  }
  console.log(failed ? `FAIL ${failed}/${tests.length}` : `PASS ${tests.length}/${tests.length} V25 play/pause scenarios (jsdom)`);
  process.exit(failed ? 1 : 0);
})();
