// V24: automatische fullscreen op de Mac is zelfcontrolerend (sitePreferences.js):
// een verzoek dat de app niet kon uitvoeren wordt opnieuw "gewapend", maar nooit nadat
// fullscreen voor die video al gelukt is (zelf verlaten = verlaten). jsdom, media gesimuleerd.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);
const tick = () => new Promise(r => setTimeout(r, 0));

function page(id = 'abcdefghijk') {
  const dom = new JSDOM(`<!doctype html><html><head></head><body><ytd-watch-flexy theater><div id="movie_player">
    <video class="html5-main-video"></video></div></ytd-watch-flexy></body></html>`,
    { url: 'https://www.youtube.com/watch?v=' + id, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window, d = w.document, v = d.querySelector('video');
  let paused = true, fsEl = null;
  Object.defineProperty(v, 'paused', { get: () => paused });
  Object.defineProperty(v, 'ended', { get: () => false });
  Object.defineProperty(v, 'readyState', { get: () => 4 });
  Object.defineProperty(d, 'fullscreenElement', { get: () => fsEl, configurable: true });
  const requests = [];
  d.addEventListener('joetoep-automatic-fullscreen', () => requests.push(Date.now()));
  w.JOETOEP_NATIVE_HOST = true;
  w.JoeToepMedia = { diagnostics: () => ({ rawVisibility: 'visible' }), fullscreen: () => true };
  w.eval(read('sitePreferences.js'));
  const P = w.JoeToepPreferences;
  P.configure({ automaticFullscreen: true, fullscreenOnPlay: false, theater: false });
  const play = async () => { paused = false; v.dispatchEvent(new w.Event('playing', { bubbles: true })); await tick(); };
  const pause = async () => { paused = true; v.dispatchEvent(new w.Event('pause', { bubbles: true })); await tick(); };
  const enterFS = async () => { fsEl = d.querySelector('ytd-watch-flexy'); d.dispatchEvent(new w.Event('fullscreenchange')); await tick(); };
  const exitFS = async () => { fsEl = null; d.dispatchEvent(new w.Event('fullscreenchange')); await tick(); };
  const state = () => JSON.parse(P.automaticFullscreenState());
  return { w, d, v, P, requests, play, pause, enterFS, exitFS, state };
}

test('first play sends exactly one automatic-fullscreen request', async () => {
  const t = page(); await t.play(); await t.play();
  assert.equal(t.requests.length, 1);
  assert.equal(t.P.fulfillFullscreenRequest(true), 'keyboard');
  assert.equal(t.P.fulfillFullscreenRequest(true), false, 'a request is consumed once');
});
test('a request the app could not fulfil is re-armed and requested again on the next play', async () => {
  const t = page(); await t.play();
  assert.equal(t.requests.length, 1);
  // app was niet actief: verzoek nooit ingelost
  assert.equal(t.P.rearmAutomaticFullscreen(), true);
  await tick();
  assert.equal(t.requests.length, 2, 'immediately re-requested while still playing');
  assert.equal(t.P.fulfillFullscreenRequest(true), 'keyboard');
});
test('re-arm while paused waits for the next play', async () => {
  const t = page(); await t.play(); await t.pause();
  assert.equal(t.P.rearmAutomaticFullscreen(), true); await tick();
  assert.equal(t.requests.length, 1, 'no request while paused');
  await t.play();
  assert.equal(t.requests.length, 2);
});
test('never re-armed after fullscreen succeeded for this video (user exit stays exit)', async () => {
  const t = page(); await t.play();
  t.P.fulfillFullscreenRequest(true); await t.enterFS();
  assert.equal(t.state().achieved, true);
  await t.exitFS();
  assert.equal(t.P.rearmAutomaticFullscreen(), false);
  await t.pause(); await t.play();
  assert.equal(t.requests.length, 1);
});
test('never re-armed while the page is already fullscreen', async () => {
  const t = page(); await t.play(); await t.enterFS();
  assert.equal(t.P.rearmAutomaticFullscreen(), false);
});
test('re-arm is a no-op when no request was made for this video', async () => {
  const t = page();
  assert.equal(t.P.rearmAutomaticFullscreen(), false);
  assert.equal(t.requests.length, 0);
});
test('state probe reports fullscreen / playing / watch page', async () => {
  const t = page();
  assert.deepEqual(t.state(), { fs: false, watch: true, playing: false, achieved: false, key: 'abcdefghijk' });
  await t.play(); await t.enterFS();
  const s = t.state(); assert.equal(s.fs, true); assert.equal(s.playing, true);
});
test('stress: 1,000 drop/re-arm cycles never produce more than one pending request', async () => {
  const t = page(); await t.play();
  for (let i = 0; i < 1000; i++) { t.P.rearmAutomaticFullscreen(); await tick(); }
  assert.equal(t.requests.length, 1001);
  assert.equal(t.P.fulfillFullscreenRequest(true), 'keyboard');
  assert.equal(t.P.fulfillFullscreenRequest(true), false);
  await t.enterFS();
  for (let i = 0; i < 200; i++) assert.equal(t.P.rearmAutomaticFullscreen(), false);
});

test('24.0.1: after the user leaves fullscreen (F/Esc/double-click) nothing ever re-requests it', async () => {
  const t = page(); await t.play();
  t.P.fulfillFullscreenRequest(true); await t.enterFS(); await t.exitFS();
  assert.equal(t.P.userTookOverFullscreen(), true);
  assert.equal(t.P.rearmAutomaticFullscreen(), false);
  for (let i = 0; i < 50; i++) { await t.pause(); await t.play(); }
  assert.equal(t.requests.length, 1);
  assert.equal(t.state().achieved, true);
});
test('24.0.1: user takes over before the automatic request is fulfilled → request is dropped', async () => {
  const t = page(); await t.play();
  t.P.userTookOverFullscreen();
  assert.equal(t.P.fulfillFullscreenRequest(true), false);
  assert.equal(t.P.rearmAutomaticFullscreen(), false);
});
(async () => {
  let ok = 0;
  for (const [name, body] of tests) {
    try { await body(); ok++; console.log('PASS', name); }
    catch (e) { console.log('FAIL', name, '\n ', e.message); process.exitCode = 1; }
  }
  console.log(`${ok === tests.length ? 'PASS' : 'FAIL'} ${ok}/${tests.length} V24 auto-fullscreen scenarios (jsdom)`);
})();
