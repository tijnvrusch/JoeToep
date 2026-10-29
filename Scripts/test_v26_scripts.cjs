// V26: iPhone — omlaag vegen uit fullscreen = inline blijven (niet meteen weer fullscreen), ook na pauze.
// Mac — theatermodus mag automatische fullscreen nooit breken (fullscreen-venster met theater-video).
// jsdom; WebKit/AVKit gesimuleerd.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);
const sleep = ms => new Promise(r => setTimeout(r, ms));

function page({ mobile = true, prefs = {} } = {}) {
  const dom = new JSDOM(`<!doctype html><html><head></head><body><ytd-watch-flexy><div id="movie_player">
    <button class="ytp-size-button"></button><video class="html5-main-video"></video></div></ytd-watch-flexy></body></html>`,
    { url: 'https://www.youtube.com/watch?v=abcdefghijk', runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window, d = w.document;
  const st = { paused: true, mode: 'inline' };
  let fsEl = null;
  Object.defineProperty(w.HTMLMediaElement.prototype, 'paused', { configurable: true, get() { return st.paused; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'ended', { configurable: true, get() { return false; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'readyState', { configurable: true, get() { return 4; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'duration', { configurable: true, get() { return 600; } });
  for (const [k, val] of [['videoWidth', 1920], ['videoHeight', 1080]]) Object.defineProperty(w.HTMLVideoElement.prototype, k, { configurable: true, get() { return val; } });
  Object.defineProperty(w.HTMLVideoElement.prototype, 'webkitPresentationMode', { configurable: true, get() { return st.mode; } });
  Object.defineProperty(w.HTMLVideoElement.prototype, 'webkitDisplayingFullscreen', { configurable: true, get() { return st.mode === 'fullscreen'; } });
  Object.defineProperty(d, 'fullscreenElement', { configurable: true, get() { return fsEl; } });
  const fire = (t, type) => t.dispatchEvent(new w.Event(type));
  const calls = { play: 0, pause: 0, exitFullscreen: 0, theater: 0, autoFullscreen: 0 };
  const rawPlay = v => { if (!st.paused) return; st.paused = false; fire(v, 'play'); if (!st.paused) fire(v, 'playing'); };
  const rawPause = v => { if (st.paused) return; st.paused = true; fire(v, 'pause'); };
  w.HTMLMediaElement.prototype.play = function() { calls.play++; rawPlay(this); return Promise.resolve(); };
  w.HTMLMediaElement.prototype.pause = function() { calls.pause++; rawPause(this); };
  w.HTMLVideoElement.prototype.webkitSupportsPresentationMode = () => true;
  w.HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) { st.mode = mode; fire(this, 'webkitpresentationmodechanged'); };
  w.HTMLVideoElement.prototype.webkitEnterFullscreen = function() { st.mode = 'fullscreen'; fire(this, 'webkitbeginfullscreen'); };
  w.HTMLVideoElement.prototype.webkitExitFullscreen = function() { st.mode = 'inline'; fire(this, 'webkitendfullscreen'); };
  d.exitFullscreen = () => { calls.exitFullscreen++; fsEl = null; fire(d, 'fullscreenchange'); return Promise.resolve(); };
  d.querySelector('.ytp-size-button').addEventListener('click', () => {
    calls.theater++; const f = d.querySelector('ytd-watch-flexy');
    f.hasAttribute('theater') ? f.removeAttribute('theater') : f.setAttribute('theater', '');
  });
  d.addEventListener('joetoep-automatic-fullscreen', () => calls.autoFullscreen++);
  w.JOETOEP_MOBILE = mobile; w.JOETOEP_NATIVE_HOST = true;
  w.eval(read('mediaCompatibility.js'));
  w.eval(read('sitePreferences.js'));
  w.eval(read('playbackControls.js'));
  w.JoeToepPreferences.configure({ automaticFullscreen: false, fullscreenOnPlay: false, theater: false, ...prefs });
  const v = d.querySelector('video');
  return {
    w, d, v, st, calls, fire,
    nativePlay() { rawPlay(v); }, nativePause() { rawPause(v); }, scriptPlay() { v.play(); },
    enterNative() { st.mode = 'fullscreen'; fire(v, 'webkitbeginfullscreen'); fire(v, 'webkitpresentationmodechanged'); },
    // Omlaag vegen in Apple's speler: WebKit pauzeert zelf en sluit de presentatie.
    swipeDown() { rawPause(v); st.mode = 'inline'; fire(v, 'webkitpresentationmodechanged'); fire(v, 'webkitendfullscreen'); },
    enterPageFullscreen() { fsEl = d.getElementById('movie_player'); fire(d, 'fullscreenchange'); },
    get playing() { return !st.paused; }
  };
}

test('iPhone: swipe down from playing fullscreen → keeps playing inline, no automatic fullscreen again', async () => {
  const t = page({ prefs: { fullscreenOnPlay: true } });
  t.scriptPlay(); await sleep(5);
  t.enterNative(); await sleep(400);
  t.swipeDown(); await sleep(150);
  assert.equal(t.playing, true, 'continues inline');
  assert.equal(t.st.mode, 'inline');
  assert.equal(t.calls.autoFullscreen, 0, 'no automatic fullscreen request after leaving');
  assert.ok((t.w.__jtSkipFSUntil || 0) > Date.now() + 2000);
});
test('iPhone: pause in fullscreen, then swipe down quickly → stays paused and inline', async () => {
  const t = page({ prefs: { fullscreenOnPlay: true } });
  t.scriptPlay(); await sleep(5);
  t.enterNative(); await sleep(400);
  t.nativePause(); await sleep(300);
  t.swipeDown(); await sleep(150);
  assert.equal(t.playing, false, 'your pause stands');
  assert.equal(t.calls.autoFullscreen, 0);
});
test('iPhone: 500× fullscreen → swipe down cycles never re-enter fullscreen by themselves', async () => {
  const t = page({ prefs: { fullscreenOnPlay: true } });
  t.scriptPlay(); await sleep(5);
  for (let i = 0; i < 500; i++) { t.enterNative(); t.swipeDown(); }
  await sleep(150);
  assert.equal(t.calls.autoFullscreen, 0);
  assert.equal(t.st.mode, 'inline');
});
test('Mac: theater + automatic fullscreen — no theater click before/while fullscreen starts', async () => {
  const t = page({ mobile: false, prefs: { automaticFullscreen: true, theater: true } });
  t.scriptPlay(); await sleep(20);
  assert.equal(t.calls.autoFullscreen, 1, 'fullscreen requested right away');
  assert.equal(t.calls.theater, 0, 'theater button not pressed during the fullscreen transition');
  t.w.JoeToepPreferences.fulfillFullscreenRequest(true);
  t.fire(t.v, 'canplay'); await sleep(20);
  assert.equal(t.calls.theater, 0);
});
// V26.1: herstelde tab na een herstart (stil tot een gebaar) → YouTube's autoplay mag geen fullscreen starten.
test('Mac: restored quiet tab — YouTube autoplay blip never requests automatic fullscreen', async () => {
  const t = page({ mobile: false, prefs: { automaticFullscreen: true, theater: true } });
  t.w.JoeToepMedia.quiet(-1);
  // In WebKit speelt de video heel even vóór de stil-bewaking pauzeert; dat moment nabootsen.
  t.st.paused = false; t.fire(t.v, 'canplay'); t.fire(t.v, 'timeupdate'); await sleep(20);
  assert.equal(t.calls.autoFullscreen, 0, 'no fullscreen while JoeToep keeps the video quiet');
  t.w.JoeToepMedia.quiet(0);                     // jouw klik op play (of een opdracht van JoeToep)
  t.st.paused = true; t.scriptPlay(); await sleep(20);
  assert.equal(t.calls.autoFullscreen, 1, 'after releasing quiet the normal automatic fullscreen works');
});

test('Mac: after leaving automatic fullscreen the video goes to theater mode', async () => {
  const t = page({ mobile: false, prefs: { automaticFullscreen: true, theater: true } });
  t.scriptPlay(); await sleep(20);
  t.w.JoeToepPreferences.fulfillFullscreenRequest(true);
  t.enterPageFullscreen(); t.d.querySelector('ytd-watch-flexy').setAttribute('fullscreen', ''); await sleep(10);
  t.d.querySelector('ytd-watch-flexy').removeAttribute('fullscreen'); t.d.exitFullscreen();
  await sleep(60);
  assert.equal(t.calls.theater, 1, 'theater once, after fullscreen');
  assert.ok(t.d.querySelector('ytd-watch-flexy').hasAttribute('theater'));
});
test('Mac: theater without automatic fullscreen still turns on immediately', async () => {
  const t = page({ mobile: false, prefs: { automaticFullscreen: false, theater: true } });
  t.fire(t.v, 'loadedmetadata'); await sleep(20);
  assert.equal(t.calls.theater, 1);
});
test('Mac: page fullscreen while YouTube shows theater (stuck) → resync, then leave fullscreen', async () => {
  const t = page({ mobile: false, prefs: { theater: true } });
  t.enterPageFullscreen();                  // fullscreen-element, maar YouTube zet geen [fullscreen]
  await sleep(1600);
  assert.equal(t.calls.exitFullscreen, 1, 'never left as a fullscreen window with an inline video');
});
test('Mac: a healthy fullscreen (YouTube agrees) is never touched', async () => {
  const t = page({ mobile: false, prefs: { theater: true } });
  t.enterPageFullscreen(); t.d.querySelector('ytd-watch-flexy').setAttribute('fullscreen', '');
  await sleep(1600);
  assert.equal(t.calls.exitFullscreen, 0);
});

(async () => {
  let failed = 0;
  for (const [name, body] of tests) {
    try { await body(); console.log('PASS', name); }
    catch (e) { failed++; console.log('FAIL', name, '\n ', e.message); }
  }
  console.log(failed ? `FAIL ${failed}/${tests.length}` : `PASS ${tests.length}/${tests.length} V26 fullscreen/theater scenarios (jsdom)`);
  process.exit(failed ? 1 : 0);
})();
