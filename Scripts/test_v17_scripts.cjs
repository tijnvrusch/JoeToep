// V17: cookieConsent.js, privacyShield.js, webPiP.js en creatorTools.js in een echte DOM (jsdom).
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);

// Maakt een pagina met `html`; `prefix` wordt vóór het script uitgevoerd (zoals de app doet).
function page(html, { url = 'https://www.nieuwssite.nl/artikel?utm_source=mail&id=5', prefix = '', scripts = [] } = {}) {
  const dom = new JSDOM(`<!doctype html><html><head></head><body>${html}</body></html>`, { url, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window;
  // jsdom rekent geen lay-out uit: geef elk element een zichtbaar formaat.
  w.HTMLElement.prototype.getBoundingClientRect = function () { return { width: 120, height: 40, top: 0, left: 0, right: 120, bottom: 40 }; };
  if (prefix) w.eval(prefix);
  for (const s of scripts) w.eval(read(s));
  return w;
}

test('cookies: OneTrust "Reject all" is clicked automatically', () => {
  const w = page('<div id="onetrust-consent-sdk"><button id="onetrust-accept-btn-handler">Accept</button><button id="onetrust-reject-all-handler">Reject all</button></div>', { scripts: ['cookieConsent.js'] });
  let rejected = 0, accepted = 0;
  w.document.getElementById('onetrust-reject-all-handler').addEventListener('click', () => rejected++);
  w.document.getElementById('onetrust-accept-btn-handler').addEventListener('click', () => accepted++);
  w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  assert.equal(rejected, 1); assert.equal(accepted, 0); w.close();
});
test('cookies: generic Dutch "Alles weigeren" inside a cookie banner is clicked', () => {
  const w = page('<section class="cookie-melding">Wij gebruiken cookies voor analyse.<button>Alles accepteren</button><button>Alles weigeren</button></section>', { scripts: ['cookieConsent.js'] });
  const [accept, reject] = w.document.querySelectorAll('button'); let r = 0, a = 0;
  reject.addEventListener('click', () => r++); accept.addEventListener('click', () => a++);
  w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  assert.equal(r, 1); assert.equal(a, 0); w.close();
});
test('cookies: a "Weigeren" button outside any cookie/privacy context is never clicked', () => {
  const w = page('<form class="betaling">Bestelling bevestigen?<button>Weigeren</button></form>', { scripts: ['cookieConsent.js'] });
  let r = 0; w.document.querySelector('button').addEventListener('click', () => r++);
  w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  assert.equal(r, 0); w.close();
});
test('cookies: "hide only" mode clicks nothing and hides the banner', () => {
  const w = page('<div id="CybotCookiebotDialog"><button id="CybotCookiebotDialogBodyButtonDecline">Decline</button></div>', { prefix: 'window.JOETOEP_COOKIE_MODE="hideOnly";', scripts: ['cookieConsent.js'] });
  let r = 0; w.document.getElementById('CybotCookiebotDialogBodyButtonDecline').addEventListener('click', () => r++);
  w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  assert.equal(r, 0); assert.ok(w.document.getElementById('joetoep-cookie-hide')); w.close();
});
test('cookies: "off" mode does nothing at all', () => {
  const w = page('<div id="onetrust-consent-sdk"><button id="onetrust-reject-all-handler">Reject all</button></div>', { prefix: 'window.JOETOEP_COOKIE_MODE="off";', scripts: ['cookieConsent.js'] });
  let r = 0; w.document.getElementById('onetrust-reject-all-handler').addEventListener('click', () => r++);
  w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  assert.equal(r, 0); assert.equal(w.document.getElementById('joetoep-cookie-hide'), null); w.close();
});
test('privacy: tracking parameters are removed from the page address and from links', () => {
  const w = page('<a id="l" href="https://shop.nl/p?fbclid=abc&utm_medium=x&kleur=rood">x</a>', { scripts: ['privacyShield.js'] });
  assert.equal(w.location.href, 'https://www.nieuwssite.nl/artikel?id=5');
  const a = w.document.getElementById('l');
  w.dispatchEvent(Object.assign(new w.Event('pointerdown'), {})); // geen target → niets
  a.dispatchEvent(new w.Event('pointerdown', { bubbles: true }));
  assert.equal(a.href, 'https://shop.nl/p?kleur=rood'); w.close();
});
test('privacy: Global Privacy Control is announced', () => {
  const w = page('', { scripts: ['privacyShield.js'] });
  assert.equal(w.navigator.globalPrivacyControl, true); w.close();
});
test('privacy: tracker scripts are not added, normal scripts are', () => {
  const w = page('', { scripts: ['privacyShield.js'] });
  const tracker = w.document.createElement('script'); tracker.src = 'https://www.google-analytics.com/analytics.js';
  const normal = w.document.createElement('script'); normal.src = 'https://cdn.nieuwssite.nl/app.js';
  w.document.head.appendChild(tracker); w.document.head.appendChild(normal);
  assert.equal(tracker.isConnected, false); assert.equal(normal.isConnected, true); w.close();
});
test('privacy: everything can be switched off', () => {
  const w = page('', { prefix: 'window.JOETOEP_PRIVACY={gpc:false,strip:false,trackers:false};', scripts: ['privacyShield.js'] });
  assert.ok(w.location.href.includes('utm_source')); w.close();
});
test('web PiP: picks the playing video, removes PiP blocks and requests PiP', async () => {
  const w = page('<video id="small"></video><video id="main" disablepictureinpicture></video>', { url: 'https://vimeo.com/123', scripts: ['webPiP.js'] });
  const [small, main] = w.document.querySelectorAll('video');
  for (const v of [small, main]) Object.defineProperty(v, 'readyState', { value: 4 });
  Object.defineProperty(small, 'paused', { value: true }); Object.defineProperty(main, 'paused', { value: false });
  let requested = null; w.HTMLVideoElement.prototype.requestPictureInPicture = function () { requested = this; return Promise.resolve(); };
  assert.equal(await w.JoeToepWebPiP.toggle(), 'active');
  assert.equal(requested, main); assert.equal(main.hasAttribute('disablepictureinpicture'), false); w.close();
});
test('web PiP: not installed on YouTube (YouTube has its own PiP script)', () => {
  const w = page('<video></video>', { url: 'https://www.youtube.com/watch?v=x', scripts: ['webPiP.js'] });
  assert.equal(w.JoeToepWebPiP, undefined); w.close();
});
test('web PiP: tab switch only starts PiP when something is playing', async () => {
  const w = page('<video></video>', { url: 'https://twitch.tv/x', scripts: ['webPiP.js'] });
  const v = w.document.querySelector('video'); Object.defineProperty(v, 'readyState', { value: 4 }); Object.defineProperty(v, 'paused', { value: true });
  assert.equal(await w.JoeToepWebPiP.enterIfPlaying(), 'skipped'); w.close();
});
test('creator tools: speed with/without pitch, A–B loop and frame step', () => {
  const w = page('<video></video>', { url: 'https://www.youtube.com/watch?v=x', scripts: ['creatorTools.js'] });
  const v = w.document.querySelector('video');
  Object.defineProperty(v, 'duration', { value: 200 }); let t = 10; Object.defineProperty(v, 'currentTime', { get: () => t, set: x => { t = x; } });
  v.pause = () => {};
  assert.equal(w.JoeToepCreator.setRate(0.5, false), 0.5); assert.equal(v.playbackRate, 0.5); assert.equal(v.preservesPitch, false);
  assert.equal(w.JoeToepCreator.setRate(9, true), 4);
  w.JoeToepCreator.setLoopPoint('a'); t = 18; w.JoeToepCreator.setLoopPoint('b');
  t = 18.1; v.dispatchEvent(new w.Event('timeupdate', { bubbles: true })); assert.equal(t, 10, 'jumps back to A');
  w.JoeToepCreator.step(3); assert.ok(Math.abs(t - 10.1) < 1e-9);
  w.JoeToepCreator.clearLoop(); assert.equal(w.JoeToepCreator.state().loop, null); w.close();
});

(async () => {
  for (const [name, body] of tests) { await body(); console.log('PASS ' + name); }
  console.log('PASS ' + tests.length + ' V17 cookie, privacy, web-PiP and creator-tools scenarios (jsdom)');
})().catch(e => { console.error(e); process.exit(1); });
