// V15: adShield.js and sponsorBlock.js in a real DOM (jsdom). Media APIs are simulated.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const shield = read('adShield.js'), sponsor = read('sponsorBlock.js');
const tests = [];
const test = (name, body) => tests.push([name, body]);

function page({ url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', config = null } = {}) {
  const dom = new JSDOM('<!doctype html><html><head></head><body><div id="movie_player" class="html5-video-player"><video class="html5-main-video"></video><div class="ytp-progress-bar"></div></div></body></html>',
    { url, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window, d = w.document, v = d.querySelector('video');
  let time = 0, duration = 600, muted = false, rate = 1;
  Object.defineProperty(v, 'currentTime', { get: () => time, set: x => { time = x; } });
  Object.defineProperty(v, 'duration', { get: () => duration });
  Object.defineProperty(v, 'muted', { get: () => muted, set: x => { muted = x; } });
  Object.defineProperty(v, 'playbackRate', { get: () => rate, set: x => { rate = x; } });
  v.play = () => Promise.resolve();
  if (config) w.eval('window.JOETOEP_ADSHIELD = ' + JSON.stringify(config));
  return { dom, w, d, v, fire: type => v.dispatchEvent(new w.Event(type)), set time(x) { time = x; }, get time() { return time; },
    set duration(x) { duration = x; }, get muted() { return muted; }, get rate() { return rate; }, close: () => dom.window.close() };
}
const all = { enabled: true, skip: true, fastForward: true, prune: true, pruneFeed: true, dismissWarnings: true, cosmetic: true };

test('adShield disabled leaves JSON.parse and fetch untouched', () => {
  const p = page({ config: { enabled: false } });
  const parse = p.w.JSON.parse; p.w.eval(shield);
  assert.equal(p.w.JSON.parse, parse); assert.ok(p.w.JoeToepAdShield); p.close();
});
test('aggressive: JSON.parse removes ad placements from player responses', () => {
  const p = page({ config: all }); p.w.eval(shield);
  const out = p.w.JSON.parse(JSON.stringify({ adPlacements: [1], playerAds: [2], adSlots: [3], streamingData: { ok: 1 }, videoDetails: { title: 't' } }));
  assert.equal(out.adPlacements, undefined); assert.equal(out.playerAds, undefined); assert.equal(out.adSlots, undefined);
  assert.equal(JSON.stringify(out.streamingData), '{"ok":1}'); assert.equal(p.w.JoeToepAdShield.stats().pruned, 3); p.close();
});
test('aggressive: ytInitialPlayerResponse assignment is pruned, normal JSON is not touched', () => {
  const p = page({ config: all }); p.w.eval(shield);
  p.w.eval('var ytInitialPlayerResponse = {adPlacements:[1], videoDetails:{title:"x"}}');
  assert.equal(p.w.ytInitialPlayerResponse.adPlacements, undefined); assert.equal(p.w.ytInitialPlayerResponse.videoDetails.title, 'x');
  assert.equal(JSON.stringify(p.w.JSON.parse('{"a":1,"b":[1,2]}')), '{"a":1,"b":[1,2]}'); p.close();
});
test('maximum: feed ad slots are removed from browse data', () => {
  const p = page({ config: all }); p.w.eval(shield);
  const data = { contents: { items: [{ richItemRenderer: { content: { videoRenderer: { id: 1 } } } }, { richItemRenderer: { content: { adSlotRenderer: {} } } }, { adSlotRenderer: {} }] } };
  const out = p.w.JSON.parse(JSON.stringify(data));
  assert.equal(out.contents.items.length, 1); assert.equal(p.w.JoeToepAdShield.stats().feedPruned, 2); p.close();
});
test('balanced: the Skip button is pressed as soon as an ad shows', () => {
  const p = page({ config: { enabled: true, skip: true } }); p.w.eval(shield);
  let clicks = 0;
  const button = p.d.createElement('button'); button.className = 'ytp-skip-ad-button';
  Object.defineProperty(button, 'offsetParent', { get: () => p.d.body });
  button.addEventListener('click', () => clicks++);
  p.d.querySelector('#movie_player').append(button);
  p.d.querySelector('#movie_player').classList.add('ad-showing');
  p.w.JoeToepAdShield.handleAd();
  assert.equal(clicks, 1); assert.equal(p.rate, 1, 'balanced does not fast-forward'); p.close();
});
test('strict: unskippable ads are muted and fast-forwarded, state is restored afterwards', () => {
  const p = page({ config: { enabled: true, skip: true, fastForward: true } }); p.w.eval(shield);
  p.duration = 15; p.time = 1;
  const player = p.d.querySelector('#movie_player');
  player.classList.add('ad-showing'); p.w.JoeToepAdShield.handleAd();
  assert.equal(p.muted, true); assert.equal(p.rate, 16); assert.ok(p.time > 14.8);
  player.classList.remove('ad-showing'); p.w.JoeToepAdShield.handleAd();
  assert.equal(p.muted, false); assert.equal(p.rate, 1); p.close();
});
test('maximum: ad-blocker warning dialog is removed', () => {
  const p = page({ config: all }); p.w.eval(shield);
  const dialog = p.d.createElement('tp-yt-paper-dialog');
  dialog.append(p.d.createElement('ytd-enforcement-message-view-model'));
  p.d.body.append(dialog);
  p.w.JoeToepAdShield.dismissWarnings();
  assert.equal(p.d.querySelector('ytd-enforcement-message-view-model'), null); p.close();
});

const segments = [{ start: 10, end: 30, category: 'sponsor', action: 'skip', uuid: 'a' },
                  { start: 100, end: 110, category: 'intro', action: 'skip', uuid: 'b' },
                  { start: 200, end: 220, category: 'music_offtopic', action: 'mute', uuid: 'c' }];
const options = { modes: { sponsor: 'skip', intro: 'ask', music_offtopic: 'mute' }, colors: {}, titles: { sponsor: 'Sponsor', intro: 'Intro' }, notice: true, noticeMs: 3000, markers: true, minimum: 1, once: true };
test('SponsorBlock skips a sponsor once, with an Undo notice, and reports the skip', () => {
  const p = page(); p.w.eval(sponsor);
  let reports = 0; p.d.addEventListener('joetoep-sponsor-skipped', () => reports++);
  assert.equal(p.w.JoeToepSponsorBlock.set('dQw4w9WgXcQ', segments, options), 3);
  p.time = 11; p.fire('timeupdate');
  assert.ok(p.time >= 30); assert.equal(reports, 1);
  const toast = p.d.getElementById('joetoep-sponsorblock-toast');
  assert.ok(toast && !toast.hidden && toast.textContent.includes('Sponsor'));
  // Undo returns to the start and does not skip again.
  toast.querySelector('button').click(); assert.equal(p.time, 10);
  p.time = 12; p.fire('timeupdate'); assert.equal(p.time, 12); p.close();
});
test('SponsorBlock "ask" shows a skip button instead of skipping', () => {
  const p = page(); p.w.eval(sponsor); p.w.JoeToepSponsorBlock.set('dQw4w9WgXcQ', segments, options);
  p.time = 101; p.fire('timeupdate'); assert.equal(p.time, 101);
  const toast = p.d.getElementById('joetoep-sponsorblock-toast');
  assert.ok(toast.textContent.includes('Skip')); toast.querySelector('button').click(); assert.ok(p.time >= 110); p.close();
});
test('SponsorBlock mutes non-music sections and restores sound after them', () => {
  const p = page(); p.w.eval(sponsor); p.w.JoeToepSponsorBlock.set('dQw4w9WgXcQ', segments, options);
  p.time = 205; p.fire('timeupdate'); assert.equal(p.muted, true);
  p.time = 221; p.fire('timeupdate'); assert.equal(p.muted, false); p.close();
});
test('SponsorBlock draws markers and ignores segments of another video', () => {
  const p = page(); p.w.eval(sponsor); p.w.JoeToepSponsorBlock.set('dQw4w9WgXcQ', segments, options);
  assert.equal(p.d.querySelectorAll('#joetoep-sponsorblock-markers .joetoep-sb-marker').length, 3);
  p.w.JoeToepSponsorBlock.set('otherVideo1', segments, options);
  p.time = 11; p.fire('timeupdate'); assert.equal(p.time, 11, 'segments for a different video are not applied'); p.close();
});

let failed = 0;
for (const [name, body] of tests) {
  try { body(); console.log('PASS ' + name); } catch (error) { failed++; console.error('FAIL ' + name); console.error(error); }
}
if (failed) { console.error(failed + ' failed'); process.exit(1); }
console.log(`PASS ${tests.length} V15 ad-shield and SponsorBlock scenarios (jsdom; media simulated)`);
