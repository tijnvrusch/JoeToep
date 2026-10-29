// Real DOM event propagation via jsdom; media/OS APIs are simulated explicitly.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM, VirtualConsole } = require('jsdom');
const unhandled = [];
const source = fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/mediaCompatibility.js'), 'utf8');
const chrome = fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/siteChrome.js'), 'utf8');
const stageSource = fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/videoStage.js'), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);

function harness({ mobile = true, url = 'https://m.youtube.com/watch?v=fixture', standard = false, delayedPiP = false } = {}) {
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', error => unhandled.push(error));
  const dom = new JSDOM('<!doctype html><html><head></head><body><main id="player"><video class="html5-main-video"></video></main><aside id="other"></aside><ytm-pivot-bar-renderer id="youtube-nav"></ytm-pivot-bar-renderer></body></html>', {
    url, runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole
  });
  const w = dom.window, d = w.document, data = new WeakMap();
  let visibility = 'visible', now = 10000, timerCalls = 0, containerFullscreenCalls = 0;
  const nativeCalls = { play: 0, pause: 0, pip: 0, fullscreen: 0 };
  w.Date.now = () => now;
  const originalTimer = w.setTimeout, originalClear = w.clearTimeout;
  const activeTimers = new Set();
  w.setTimeout = (fn, ...args) => {
    timerCalls++; let id = originalTimer(() => { activeTimers.delete(id); fn(); }, ...args);
    activeTimers.add(id); return id;
  };
  w.clearTimeout = id => { activeTimers.delete(id); originalClear(id); };
  Object.defineProperty(w.Document.prototype, 'visibilityState', { configurable: true, get() { return visibility; } });
  Object.defineProperty(w.Document.prototype, 'hidden', { configurable: true, get() { return visibility !== 'visible'; } });
  const state = v => { if (!data.has(v)) data.set(v, { paused: false, ended: false, mode: 'inline' }); return data.get(v); };
  for (const key of ['paused', 'ended']) Object.defineProperty(w.HTMLMediaElement.prototype, key, { configurable: true, get() { return state(this)[key]; } });
  Object.defineProperty(w.HTMLMediaElement.prototype, 'readyState', { configurable: true, get() { return 4; } });
  for (const [key, value] of [['videoWidth',1920],['videoHeight',1080]]) Object.defineProperty(w.HTMLVideoElement.prototype, key, { configurable: true, get() { return value; } });
  Object.defineProperty(w.HTMLVideoElement.prototype, 'webkitPresentationMode', { configurable: true, get() { return state(this).mode; } });
  const fire = (target, type) => target.dispatchEvent(new w.Event(type, { bubbles: false }));
  const setMode = (v, mode) => { if (state(v).mode === mode) return; state(v).mode = mode; fire(v, 'webkitpresentationmodechanged'); };
  const rawPause = v => { nativeCalls.pause++; state(v).paused = true; fire(v, 'pause'); };
  const rawPlay = v => { nativeCalls.play++; state(v).paused = false; state(v).ended = false; fire(v, 'playing'); return Promise.resolve(); };
  w.HTMLMediaElement.prototype.play = function() { return rawPlay(this); };
  w.HTMLMediaElement.prototype.pause = function() { rawPause(this); };
  w.HTMLVideoElement.prototype.webkitSupportsPresentationMode = () => !standard;
  if (!standard) w.HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) {
    if (mode === 'picture-in-picture') { nativeCalls.pip++; if (delayedPiP) return; }
    setMode(this, mode);
  };
  d.exitPictureInPicture = () => { const v = d.pictureInPictureElement; d.pictureInPictureElement = null; if (v) fire(v, 'leavepictureinpicture'); return Promise.resolve(); };
  w.HTMLVideoElement.prototype.requestPictureInPicture = function() { nativeCalls.pip++; d.pictureInPictureElement = this; fire(this, 'enterpictureinpicture'); return Promise.resolve(); };
  w.HTMLVideoElement.prototype.webkitExitFullscreen = function() { setMode(this, 'inline'); fire(this, 'webkitendfullscreen'); };
  w.HTMLVideoElement.prototype.webkitEnterFullscreen = function() { nativeCalls.fullscreen++; setMode(this, 'fullscreen'); fire(this, 'webkitbeginfullscreen'); };
  w.Element.prototype.requestFullscreen = function() { containerFullscreenCalls++; return Promise.resolve(); };
  class MockMediaSession {
    constructor() { this.handlers = new Map(); this.playbackState = 'none'; }
    setActionHandler(action, handler) { this.handlers.set(action, handler); }
    invoke(action) { this.handlers.get(action)?.({action}); }
  }
  Object.defineProperty(w.navigator, 'mediaSession', {value: new MockMediaSession()});
  w.JOETOEP_MOBILE = mobile;
  // V16.2.1: remember the page script's window listeners so a test can deliver a TRUSTED
  // (real user) click; jsdom itself can only create untrusted events.
  const captured = {}; const originalAdd = w.addEventListener.bind(w);
  w.addEventListener = (type, fn, options) => { (captured[type] ??= []).push(fn); return originalAdd(type, fn, options); };
  const install = () => w.eval(source);
  install();
  w.addEventListener = originalAdd;
  const userClick = target => (captured.pointerdown || []).forEach(fn => fn({ isTrusted: true, target }));
  return { w, d, state, v: d.querySelector('video'), api: w.JoeToepMedia, nativeCalls, rawPause, rawPlay, fire, setMode, install, userClick,
    hide() { visibility = 'hidden'; fire(d, 'visibilitychange'); },
    show() { visibility = 'visible'; fire(d, 'visibilitychange'); },
    advance(ms) { now += ms; },
    get timerCalls() { return timerCalls; }, get activeTimers() { return activeTimers.size; }, get containerFullscreenCalls() { return containerFullscreenCalls; },
    close() { w.close(); }
  };
}

test('outside YouTube the page prototypes stay untouched', () => {
  const h = harness({url:'https://accounts.google.com/'}); assert.equal(h.api, undefined); h.close();
});
test('installation is idempotent', () => {
  const h=harness(), pause=h.w.HTMLMediaElement.prototype.pause; h.install();
  assert.equal(h.w.HTMLMediaElement.prototype.pause,pause); h.close();
});
test('presentation reaches the site but a destructive site exit is blocked', () => {
  const h=harness(); let site=0, bridge=0;
  h.v.addEventListener('webkitpresentationmodechanged',()=>{ site++; h.v.webkitSetPresentationMode('inline'); });
  h.d.addEventListener('joetoep-presentation-state',()=>bridge++);
  assert.equal(h.api.enterPiP().status,'active');
  assert.equal(site,1); assert.equal(bridge,1); assert.equal(h.v.webkitPresentationMode,'picture-in-picture'); h.close();
});
test('site cannot programmatically close active native PiP', () => {
  const h=harness(); h.api.enterPiP(); h.v.webkitSetPresentationMode('inline');
  assert.equal(h.v.webkitPresentationMode,'picture-in-picture'); h.close();
});
test('site cannot pause active PiP but system pause remains respected', () => {
  const h=harness(); h.api.enterPiP(); h.v.pause(); assert.equal(h.v.paused,false);
  h.rawPause(h.v); assert.equal(h.v.paused,true); h.hide(); assert.equal(h.nativeCalls.play,0); h.close();
});
test('normal foreground pause is never overridden', () => {
  const h=harness(); h.v.pause(); h.hide(); assert.equal(h.nativeCalls.pip,0); assert.equal(h.v.paused,true); h.close();
});
test('protection can be disabled without reloading', () => {
  const h=harness(); h.api.configure({protect:false}); h.api.enterPiP(); h.v.pause();
  assert.equal(h.v.paused,true); h.v.webkitSetPresentationMode('inline'); assert.equal(h.v.webkitPresentationMode,'inline'); h.close();
});
test('background transition invokes native PiP before late website listeners (Mac)', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'}); let site=0; h.d.addEventListener('visibilitychange',()=>{site++;h.v.pause();});
  h.hide(); assert.equal(h.nativeCalls.pip,1); assert.equal(site,0); assert.equal(h.v.paused,false);
  assert.equal(h.d.visibilityState,'visible'); assert.equal(h.d.hidden,false); h.close();
});
test('V10 iOS hidden inline page never issues a futile PiP request but keeps protecting playback', () => {
  const h=harness(); let site=0; h.d.addEventListener('visibilitychange',()=>{site++;h.v.pause();});
  h.hide(); assert.equal(h.nativeCalls.pip,0); assert.equal(site,0); assert.equal(h.v.paused,false);
  assert.equal(h.d.visibilityState,'visible'); h.close();
});
test('auto-PiP can be disabled independently of compatibility protection', () => {
  const h=harness(); h.api.configure({automatic:false}); h.hide(); assert.equal(h.nativeCalls.pip,0); h.close();
});
test('one recent system pause is recovered at background transition', () => {
  const h=harness(); h.api.prepareHandoff(); h.rawPause(h.v); h.advance(100); h.hide();
  assert.equal(h.nativeCalls.play,1); assert.equal(h.nativeCalls.pip,0,'native host already has an in-flight request');
  h.hide(); assert.equal(h.nativeCalls.play,1); h.close();
});
test('an old paused video is not restarted', () => {
  const h=harness(); h.rawPause(h.v); h.advance(2000); h.hide();
  assert.equal(h.nativeCalls.play,0); assert.equal(h.nativeCalls.pip,0); h.close();
});
test('a system pause after hiding is recovered once, with no retry loop', () => {
  const h=harness({delayedPiP:true}); h.hide(); h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,1); h.rawPause(h.v); assert.equal(h.nativeCalls.play,1);
  h.advance(2000); h.rawPause(h.v); assert.equal(h.nativeCalls.play,1); h.close();
});
test('homepage preview videos cannot start automatic PiP or mask visibility', () => {
  const h=harness({url:'https://m.youtube.com/'}); h.hide();
  assert.equal(h.nativeCalls.pip,0);assert.equal(h.d.visibilityState,'hidden');h.close();
});
test('an ended video cannot trigger auto-PiP', () => {
  const h=harness(); h.state(h.v).ended=true; h.fire(h.v,'ended'); h.hide(); assert.equal(h.nativeCalls.pip,0); h.close();
});
test('audio interruptions prevent automatic resume and PiP', () => {
  const h=harness(); h.api.setInterrupted(true); h.rawPause(h.v); h.hide();
  assert.equal(h.nativeCalls.play,0); assert.equal(h.nativeCalls.pip,0); h.close();
});
test('native host and visibility event cannot issue duplicate simultaneous PiP requests', () => {
  const h=harness(); h.api.prepareHandoff(); h.hide(); assert.equal(h.nativeCalls.pip,0);
  h.api.enterPiP(); assert.equal(h.nativeCalls.pip,1); h.hide(); assert.equal(h.nativeCalls.pip,1); h.close();
});
test('fallback buttons directly invoke native video presentation', () => {
  const h=harness(); assert.equal(h.api.showFallback(),true);
  h.d.querySelector('#joetoep-native-controls button').click(); assert.equal(h.nativeCalls.pip,1);
  assert.equal(h.d.querySelector('#joetoep-native-controls').hidden,true); h.close();
});
test('disabled fallback creates no extra page controls', () => {
  const h=harness(); h.api.configure({fallback:false}); assert.equal(h.api.showFallback(),false);
  assert.equal(h.d.querySelector('#joetoep-native-controls'),null); h.close();
});
test('standard PiP API is available when prefixed native API is absent', () => {
  const h=harness({standard:true}); assert.equal(h.api.enterPiP().status,'active');
  assert.equal(h.d.pictureInPictureElement,h.v); h.close();
});
test('iPad/iPhone container fullscreen redirects to the native VIDEO', async () => {
  const h=harness(); await h.d.querySelector('#player').requestFullscreen();
  assert.equal(h.nativeCalls.fullscreen,1); assert.equal(h.containerFullscreenCalls,0); h.close();
});
test('Mac keeps its own element fullscreen route', async () => {
  const h=harness({mobile:false}); await h.d.querySelector('#player').requestFullscreen();
  assert.equal(h.nativeCalls.fullscreen,0); assert.equal(h.containerFullscreenCalls,1); h.close();
});
test('ordinary native fullscreen changes still reach website controls', () => {
  const h=harness();let calls=0;h.v.addEventListener('webkitpresentationmodechanged',()=>calls++);
  h.api.fullscreen();h.setMode(h.v,'inline');assert.equal(calls,2);h.close();
});
test('native fullscreen override can be disabled', async () => {
  const h=harness(); h.api.configure({nativeFullscreen:false}); await h.d.querySelector('#player').requestFullscreen();
  assert.equal(h.nativeCalls.fullscreen,0); assert.equal(h.containerFullscreenCalls,1); h.close();
});
test('non-video elements keep their original fullscreen behavior', async () => {
  const h=harness(); await h.d.querySelector('#other').requestFullscreen();
  assert.equal(h.containerFullscreenCalls,1); h.close();
});
test('main video wins over an unrelated playing preview', () => {
  const h=harness(); const preview=h.d.createElement('video');h.d.body.prepend(preview);
  h.api.enterPiP(); assert.equal(h.state(preview).mode,'inline'); assert.equal(h.state(h.v).mode,'picture-in-picture'); h.close();
});
test('closing native PiP does not reopen a paused video', () => {
  const h=harness(); h.api.enterPiP();h.rawPause(h.v);h.setMode(h.v,'inline');h.hide();
  assert.equal(h.nativeCalls.pip,1);assert.equal(h.nativeCalls.play,0);h.close();
});
test('new SPA video resets previous user pause intent', () => {
  const h=harness();h.v.pause();h.v.remove();const next=h.d.createElement('video');next.className='html5-main-video';h.d.querySelector('#player').append(next);
  assert.notEqual(h.api.beginAutomaticHandoff().status,'paused','new video is not treated as user-paused');h.close();
});
test('10,000 hide/return/native-close cycles create no application timers', () => {
  const h=harness();
  for(let i=0;i<10000;i++){h.hide();h.show();h.setMode(h.v,'inline');h.advance(3000);}
  assert.equal(h.nativeCalls.pip,0);assert.equal(h.timerCalls,0);assert.equal(h.nativeCalls.play,0);h.close();
});
test('mobile replacement navigation hides the YouTube footer only', () => {
  const h=harness();h.w.eval(chrome);h.w.eval(chrome);
  assert.equal(h.d.querySelectorAll('#joetoep-mobile-chrome').length,1);
  assert.equal(h.w.getComputedStyle(h.d.querySelector('#youtube-nav')).display,'none');
  assert.notEqual(h.w.getComputedStyle(h.d.querySelector('#player')).display,'none');h.close();
});
test('Mac website navigation is not modified by mobile chrome', () => {
  const h=harness({mobile:false});h.w.eval(chrome);assert.equal(h.d.querySelector('#joetoep-mobile-chrome'),null);h.close();
});

test('iOS fullscreen swipe leaves the first PiP transition to the system', () => {
  const h=harness(); h.setMode(h.v,'fullscreen'); h.api.prepareHandoff(true); h.hide();
  assert.equal(h.nativeCalls.pip,0); h.setMode(h.v,'picture-in-picture');
  assert.equal(h.nativeCalls.pip,0); h.close();
});
test('one OS pause during swipe handoff recovers even after PiP is visible', () => {
  const h=harness(); h.api.prepareHandoff(true); h.setMode(h.v,'picture-in-picture'); h.hide();
  h.rawPause(h.v); assert.equal(h.nativeCalls.play,1); assert.equal(h.v.paused,false);
  h.rawPause(h.v); assert.equal(h.nativeCalls.play,1); assert.equal(h.v.paused,true); h.close();
});
test('a native PiP pause after the handoff deadline stays paused', () => {
  const h=harness();h.api.prepareHandoff(true);h.setMode(h.v,'picture-in-picture');h.hide();h.advance(6000);
  h.rawPause(h.v);assert.equal(h.nativeCalls.play,0);assert.equal(h.v.paused,true);h.close();
});
test('rearming a pending handoff does not replenish its pause recovery budget', () => {
  const h=harness();h.api.prepareHandoff(true);h.setMode(h.v,'picture-in-picture');h.hide();
  h.rawPause(h.v);assert.equal(h.nativeCalls.play,1);h.api.prepareHandoff(true);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,1);h.close();
});
test('explicit pause intent is respected even during the swipe handoff', () => {
  const h=harness();h.api.prepareHandoff(true);h.setMode(h.v,'picture-in-picture');h.api.allowExit();h.v.pause();
  assert.equal(h.nativeCalls.play,0);assert.equal(h.v.paused,true);h.close();
});
test('fullscreen teardown cannot trigger site pause or layer removal during PiP', () => {
  const h=harness();let calls=0;h.v.addEventListener('webkitendfullscreen',()=>{calls++;h.v.remove();});
  h.api.prepareHandoff(true);h.setMode(h.v,'picture-in-picture');h.fire(h.v,'webkitendfullscreen');
  assert.equal(calls,0);assert.equal(h.v.isConnected,true);h.close();
});
test('ordinary fullscreen exit still reaches website outside PiP handoff', () => {
  const h=harness();let calls=0;h.v.addEventListener('webkitendfullscreen',()=>calls++);
  h.fire(h.v,'webkitendfullscreen');assert.equal(calls,1);h.close();
});
test('Mac prefers the standardized native PiP API over the prefixed mode switch', () => {
  const h=harness({mobile:false});h.api.enterPiP();
  assert.equal(h.d.pictureInPictureElement,h.v);assert.equal(h.state(h.v).mode,'inline');h.close();
});
test('mobile play sets inline attributes before media playback', () => {
  const h=harness();h.v.play();assert.equal(h.v.hasAttribute('playsinline'),true);
  assert.equal(h.v.hasAttribute('webkit-playsinline'),true);h.close();
});

function stageHarness(options={}) {
  const h=harness(options);h.w.eval(stageSource);
  Object.defineProperty(h.v,'duration',{configurable:true,value:120});h.v.currentTime=50;
  h.stage=h.w.JoeToepStage;
  h.button=label=>h.d.querySelector('#joetoep-stage-controls').shadowRoot.querySelector(`button[aria-label="${label}"]`);
  return h;
}
test('safe fullscreen keeps the original video, parent and source', () => {
  const h=stageHarness(),parent=h.v.parentNode;h.v.setAttribute('src','fixture.mp4');
  const original=h.v.getAttribute('style');assert.equal(h.stage.enter(),true);
  assert.equal(h.v.parentNode,parent);assert.equal(h.d.querySelectorAll('video').length,1);
  assert.equal(h.v.getAttribute('src'),'fixture.mp4');h.stage.exit();
  assert.equal(h.v.getAttribute('style'),original);assert.equal(h.d.querySelector('[data-joetoep-ancestor]'),null);
  assert.equal(h.d.querySelector('#joetoep-stage-style'),null);assert.equal(h.stage.active(),false);h.close();
});
test('safe mode intercepts native and container fullscreen without Apple presenter', async () => {
  const h=stageHarness();h.api.configure({nativeFullscreen:false});
  h.v.webkitEnterFullscreen();assert.equal(h.stage.active(),true);h.stage.exit();
  await h.d.querySelector('#player').requestFullscreen();assert.equal(h.stage.active(),true);
  assert.equal(h.nativeCalls.fullscreen,0);assert.equal(h.containerFullscreenCalls,0);h.close();
});
test('fallback play pause and ten-second controls operate on the same video', () => {
  const h=stageHarness();h.stage.enter();h.button('Pause').click();assert.equal(h.v.paused,true);
  h.button('Play').click();assert.equal(h.v.paused,false);
  h.button('Rewind 10 seconds').click();assert.equal(h.v.currentTime,40);
  h.button('Forward 10 seconds').click();assert.equal(h.v.currentTime,50);h.close();
});
test('progress follows playback, seeks on release and clamps to duration', () => {
  const h=stageHarness();h.stage.enter();const shadow=h.d.querySelector('#joetoep-stage-controls').shadowRoot;
  const seek=shadow.querySelector('input');h.v.currentTime=75;h.fire(h.v,'timeupdate');assert.equal(Number(seek.value),75);
  seek.value='100';h.fire(seek,'input');h.fire(seek,'change');assert.equal(h.v.currentTime,100);
  h.v.currentTime=119;h.button('Forward 10 seconds').click();assert.equal(h.v.currentTime,120);
  h.v.currentTime=2;h.button('Rewind 10 seconds').click();assert.equal(h.v.currentTime,0);h.close();
});
test('live seek bar uses DVR seekable bounds, not an infinite duration', () => {
  const h=stageHarness();Object.defineProperty(h.v,'duration',{value:Infinity});
  Object.defineProperty(h.v,'seekable',{value:{length:1,start:()=>900,end:()=>1200}});
  h.v.currentTime=1150;h.stage.enter();const seek=h.d.querySelector('#joetoep-stage-controls').shadowRoot.querySelector('input');
  assert.equal(seek.min,'900');assert.equal(seek.max,'1200');h.close();
});
test('unknown duration disables seeking without NaN', () => {
  const h=stageHarness();Object.defineProperty(h.v,'duration',{value:NaN});h.stage.enter();
  const seek=h.d.querySelector('#joetoep-stage-controls').shadowRoot.querySelector('input');assert.equal(seek.disabled,true);h.close();
});
test('PiP entry removes safe fullscreen styling without pausing or detaching video', () => {
  const h=stageHarness();h.stage.enter();h.api.enterPiP();assert.equal(h.stage.active(),false);
  assert.equal(h.v.isConnected,true);assert.equal(h.v.paused,false);assert.equal(h.nativeCalls.pause,0);h.close();
});
test('navigation and back remove fullscreen layers immediately', () => {
  const h=stageHarness();h.stage.enter();h.fire(h.d,'yt-navigate-start');assert.equal(h.stage.active(),false);
  h.stage.enter();h.fire(h.w,'popstate');assert.equal(h.stage.active(),false);h.close();
});
test('removed video or controls cannot leave the website hidden', async () => {
  const h=stageHarness();h.stage.enter();h.v.remove();await Promise.resolve();
  assert.equal(h.stage.active(),false);assert.equal(h.d.documentElement.hasAttribute('data-joetoep-stage'),false);h.close();
  const k=stageHarness();k.stage.enter();k.d.querySelector('#joetoep-stage-controls').remove();await Promise.resolve();
  assert.equal(k.stage.active(),false);k.close();
});
test('Mac fallback exposes an explicit native window fullscreen action', () => {
  const h=stageHarness({mobile:false});let called=0;h.d.addEventListener('joetoep-window-fullscreen',()=>called++);
  h.stage.enter();h.button('Fullscreen window').click();assert.equal(called,1);h.close();
});
test('2,000 fullscreen open/close cycles leave no overlays or application timers', () => {
  const h=stageHarness();for(let i=0;i<2000;i++){h.stage.enter();h.stage.enter();h.stage.exit();}
  assert.equal(h.d.querySelectorAll('#joetoep-stage-controls,#joetoep-stage-style').length,0);
  assert.equal(h.d.querySelector('[data-joetoep-ancestor]'),null);assert.equal(h.activeTimers,0);h.close();
});


test('site cannot close Mac standard PiP but explicit app return can', () => {
  const h=harness({mobile:false,standard:true});h.api.enterPiP();h.d.exitPictureInPicture();
  assert.equal(h.d.pictureInPictureElement,h.v);h.api.returnToApp();assert.equal(h.d.pictureInPictureElement,null);h.close();
});
test('V10 iOS automatic inline handoff is left to the prepared native presenter', () => {
  const h=harness();assert.equal(h.api.beginAutomaticHandoff().status,'inline-background');
  assert.equal(h.v.webkitPresentationMode,'inline');h.hide();assert.equal(h.nativeCalls.pip,0);
  h.api.setNativeOwner(true);assert.equal(h.api.beginAutomaticHandoff().status,'native-owner');h.close();
});
test('V10 native presenter handoff silences the web video without user-pause intent and resumes at its time', () => {
  const h=harness();h.api.setNativeOwner(true);const r=h.api.nativeHandoff();assert.equal(r.status,'paused');assert.equal(h.v.paused,true);
  h.v.play();assert.equal(h.v.paused,true,'site cannot restart the web video while native PiP is audible');
  h.api.nativeReturn(42,true,true);assert.equal(h.v.currentTime,42);assert.equal(h.v.paused,false);
  h.api.nativeHandoff();h.api.nativeReturn(50,false,false);assert.equal(h.v.paused,true);h.close();
});
test('automatic fullscreen handoff leaves native ownership to iOS', () => {
  const h=harness();h.setMode(h.v,'fullscreen');assert.equal(h.api.beginAutomaticHandoff().status,'system-fullscreen');
  assert.equal(h.nativeCalls.pip,0);h.close();
});
test('automatic handoff skips a user-paused video and homepage previews', () => {
  const h=harness();h.v.pause();assert.equal(h.api.beginAutomaticHandoff().status,'paused');h.close();
  const k=harness({url:'https://m.youtube.com/'});assert.equal(k.api.beginAutomaticHandoff().status,'skipped');k.close();
});
test('native PiP return reaches YouTube and clears its simulated placeholder', () => {
  const h=harness();let placeholder=false,exits=0;
  h.v.addEventListener('webkitpresentationmodechanged',()=>{placeholder=h.v.webkitPresentationMode==='picture-in-picture';if(!placeholder)exits++;});
  h.api.enterPiP();h.hide();assert.equal(placeholder,true);h.show();h.api.returnToApp('origin');
  assert.equal(placeholder,false);assert.equal(exits,1);assert.equal(h.v.paused,false);assert.equal(h.nativeCalls.pip,1);h.close();
});
test('Mac standard PiP return dispatches the real leave event', () => {
  const h=harness({mobile:false,standard:true});let placeholder=false;
  h.v.addEventListener('enterpictureinpicture',()=>placeholder=true);
  h.v.addEventListener('leavepictureinpicture',()=>placeholder=false);
  h.api.beginAutomaticHandoff();assert.equal(placeholder,true);h.api.returnToApp();
  assert.equal(placeholder,false);assert.equal(h.d.pictureInPictureElement,null);h.close();
});
test('delayed native pause after PiP return recovers once, never in a loop', () => {
  const h=harness();h.api.enterPiP();h.hide();h.show();h.api.returnToApp('origin');
  h.advance(400);h.rawPause(h.v);assert.equal(h.nativeCalls.play,1);assert.equal(h.v.paused,false);
  h.rawPause(h.v);assert.equal(h.nativeCalls.play,1);assert.equal(h.v.paused,true);h.close();
});
test('explicit pause after PiP return remains paused', () => {
  const h=harness();h.api.beginAutomaticHandoff();h.api.returnToApp();h.api.allowExit();h.v.pause();
  assert.equal(h.nativeCalls.play,0);assert.equal(h.v.paused,true);h.close();
});
test('a pause after the return recovery deadline is not overridden', () => {
  const h=harness();h.api.enterPiP();h.api.returnToApp('origin');h.advance(3100);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,0);h.close();
});
test('V15 without keep-playing the short 1.5 s return window applies', () => {
  const h=harness();h.api.configure({keepPlaying:false});h.api.enterPiP();h.api.returnToApp('origin');h.advance(1600);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,0);h.close();
});
test('V15 return target inline never turns a PiP return into fullscreen', () => {
  const h=harness();h.api.configure({returnTarget:'inline'});h.api.enterPiP();h.hide();h.show();h.api.returnToApp('origin');
  assert.notEqual(h.v.webkitPresentationMode,'fullscreen');assert.equal(h.api.restoreFullscreen(),false);h.close();
});
test('V15 return target fullscreen brings even an inline PiP back in fullscreen', () => {
  const h=harness();h.api.configure({returnTarget:'fullscreen'});h.api.enterPiP();h.hide();h.show();h.api.returnToApp('origin');
  assert.equal(h.v.webkitPresentationMode,'fullscreen');assert.equal(h.v.paused,false);h.close();
});
test('one delayed pause at three seconds after automatic entry is recovered', () => {
  const h=harness();h.api.beginAutomaticHandoff();h.hide();h.advance(3000);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,1);assert.equal(h.v.paused,false);h.advance(3000);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,1);assert.equal(h.v.paused,true);h.close();
});


test('Control Center pause wins during automatic handoff and never recovers', () => {
  const h=harness();h.api.beginAutomaticHandoff();h.hide();
  h.w.navigator.mediaSession.invoke('pause');assert.equal(h.v.paused,true);
  assert.equal(h.nativeCalls.play,0);h.show();h.api.returnToApp();assert.equal(h.v.paused,true);
  assert.equal(h.w.navigator.mediaSession.playbackState,'paused');h.close();
});
test('Control Center play resumes the actual background video without another PiP request', () => {
  const h=harness();h.api.enterPiP();h.hide();
  h.w.navigator.mediaSession.invoke('pause');h.w.navigator.mediaSession.invoke('play');
  assert.equal(h.v.paused,false);assert.equal(h.nativeCalls.pip,1);
  assert.equal(h.w.navigator.mediaSession.playbackState,'playing');h.close();
});
test('YouTube replacing play/pause handlers cannot bypass explicit remote intent', () => {
  const h=harness();let wrong=0;
  h.w.navigator.mediaSession.setActionHandler('pause',()=>wrong++);
  h.api.beginAutomaticHandoff();h.w.navigator.mediaSession.invoke('pause');
  assert.equal(h.v.paused,true);assert.equal(wrong,0);assert.equal(h.nativeCalls.play,0);h.close();
});
test('site clearing a handler does not disable background pause', () => {
  const h=harness();h.w.navigator.mediaSession.setActionHandler('pause',null);
  h.api.beginAutomaticHandoff();h.w.navigator.mediaSession.invoke('pause');assert.equal(h.v.paused,true);h.close();
});
test('other media actions retain their original website handler', () => {
  const h=harness();let calls=0;h.w.navigator.mediaSession.setActionHandler('seekto',()=>calls++);
  h.w.navigator.mediaSession.invoke('seekto');assert.equal(calls,1);h.close();
});
test('remote commands follow SPA replacement instead of a stale video', () => {
  const h=harness();h.v.remove();const next=h.d.createElement('video');next.className='html5-main-video';h.d.body.append(next);
  h.w.navigator.mediaSession.invoke('pause');assert.equal(next.paused,true);
  h.w.navigator.mediaSession.invoke('play');assert.equal(next.paused,false);h.close();
});
test('remote play cannot override an active audio interruption', () => {
  const h=harness();h.api.setInterrupted(true);h.rawPause(h.v);h.w.navigator.mediaSession.invoke('play');
  assert.equal(h.v.paused,true);assert.equal(h.nativeCalls.play,0);h.close();
});
test('V10 mobile PiP from fullscreen returns straight to fullscreen (no inline hop) without play commands', () => {
  const h=harness();h.setMode(h.v,'fullscreen');h.api.enterPiP();assert.equal(h.v.webkitPresentationMode,'picture-in-picture');
  const modes=[];h.v.addEventListener('webkitpresentationmodechanged',()=>modes.push(h.v.webkitPresentationMode));
  h.api.returnToApp('origin');assert.deepEqual(modes,['fullscreen']);
  assert.equal(h.api.restoreFullscreen(),true);assert.equal(h.nativeCalls.play,0);h.close();
});
test('V10 mobile PiP started inline returns inline with the "where PiP started" target', () => {
  const h=harness();h.api.configure({returnTarget:'origin'});h.api.enterPiP();h.api.returnToApp('origin');assert.equal(h.v.webkitPresentationMode,'inline');
  assert.equal(h.api.restoreFullscreen(),false);h.close();
});
test('V10 a stale PiP state can never make fullscreen unreachable', () => {
  const h=harness();h.api.enterPiP();assert.equal(h.api.fullscreen(),true);assert.equal(h.v.webkitPresentationMode,'fullscreen');h.close();
});
test('paused PiP returns to fullscreen while staying paused', () => {
  const h=harness();h.setMode(h.v,'fullscreen');h.api.enterPiP();h.w.navigator.mediaSession.invoke('pause');h.api.returnToApp('origin');h.api.restoreFullscreen();
  assert.equal(h.v.webkitPresentationMode,'fullscreen');assert.equal(h.v.paused,true);h.close();
});
test('fullscreen restore does not compete with an active PiP presenter', () => {
  const h=harness();h.api.enterPiP();assert.equal(h.api.restoreFullscreen(),false);assert.equal(h.nativeCalls.fullscreen,0);h.close();
});
test('2,000 remote pause/play cycles preserve one handler per action and create no timers', () => {
  const h=harness();h.api.enterPiP();h.hide();
  for(let i=0;i<2000;i++){h.w.navigator.mediaSession.invoke('pause');assert.equal(h.v.paused,true);h.w.navigator.mediaSession.invoke('play');assert.equal(h.v.paused,false);}
  assert.equal(h.nativeCalls.pip,1);assert.equal(h.timerCalls,0);assert.equal(h.w.navigator.mediaSession.handlers.size,2);h.close();
});

test('remote pause does not let a site tear down standard PiP', () => {
  const h=harness({mobile:false,standard:true});h.api.beginAutomaticHandoff();
  h.w.navigator.mediaSession.invoke('pause');h.d.exitPictureInPicture();
  assert.equal(h.v.paused,true);assert.equal(h.d.pictureInPictureElement,h.v);
  h.api.returnToApp();assert.equal(h.d.pictureInPictureElement,null);h.close();
});

test('feed navigation clears safe fullscreen visibility without detaching the video', () => {
  const h=stageHarness();h.stage.enter();assert.equal(h.d.documentElement.hasAttribute('data-joetoep-stage'),true);
  h.api.leaveForNavigation();assert.equal(h.stage.active(),false);
  assert.equal(h.d.documentElement.hasAttribute('data-joetoep-stage'),false);assert.equal(h.v.isConnected,true);h.close();
});
test('feed navigation exits native fullscreen and does not request PiP', () => {
  const h=harness();h.api.fullscreen();h.api.leaveForNavigation();
  assert.equal(h.v.webkitPresentationMode,'inline');assert.equal(h.nativeCalls.pip,0);assert.equal(h.nativeCalls.play,0);h.close();
});
test('navigation leaves paused standard PiP without resuming it', () => {
  const h=harness({mobile:false,standard:true});h.api.beginAutomaticHandoff();h.w.navigator.mediaSession.invoke('pause');
  h.api.leaveForNavigation();assert.equal(h.d.pictureInPictureElement,null);assert.equal(h.v.paused,true);h.close();
});

test('website play cannot undo a remote pause but the next remote play can', () => {
  const h=harness();h.api.beginAutomaticHandoff();h.hide();h.w.navigator.mediaSession.invoke('pause');h.advance(6000);
  h.v.play();assert.equal(h.v.paused,true);assert.equal(h.nativeCalls.play,0);
  h.w.navigator.mediaSession.invoke('play');assert.equal(h.v.paused,false);assert.equal(h.nativeCalls.play,1);h.close();
});


test('V8 one PiP request owns delayed inline presentation across lifecycle calls', () => {
  const h=harness({delayedPiP:true});
  h.api.beginAutomaticHandoff();h.hide();h.api.beginAutomaticHandoff();h.api.enterPiP();
  assert.equal(h.nativeCalls.pip,1);h.setMode(h.v,'picture-in-picture');
  assert.equal(h.api.diagnostics().requestPending,false);h.close();
});
test('V8 interruption ending with permission resumes previous playback exactly once', () => {
  const h=harness();h.api.enterPiP();h.api.setInterrupted(true);h.rawPause(h.v);
  assert.equal(h.v.paused,true);assert.equal(h.api.diagnostics().userPause,false);
  h.api.setInterrupted(false,true);assert.equal(h.v.paused,false);assert.equal(h.nativeCalls.play,1);
  h.api.setInterrupted(false,true);assert.equal(h.nativeCalls.play,1);h.close();
});
test('V8 interruption without shouldResume does not force playback', () => {
  const h=harness();h.api.setInterrupted(true);h.rawPause(h.v);h.api.setInterrupted(false,false);
  assert.equal(h.v.paused,true);assert.equal(h.nativeCalls.play,0);h.close();
});
test('V8 remote pause during interruption cancels pending recovery', () => {
  const h=harness();h.api.enterPiP();h.api.setInterrupted(true);h.rawPause(h.v);
  h.w.navigator.mediaSession.invoke('pause');h.api.setInterrupted(false,true);
  assert.equal(h.v.paused,true);assert.equal(h.nativeCalls.play,0);h.close();
});
test('V8 duplicate interruption-began does not erase intent', () => {
  const h=harness();h.api.setInterrupted(true);h.rawPause(h.v);h.api.setInterrupted(true);
  h.api.setInterrupted(false,true);assert.equal(h.nativeCalls.play,1);h.close();
});
test('V8 paused video stays paused through an interruption', () => {
  const h=harness();h.v.pause();h.api.setInterrupted(true);h.api.setInterrupted(false,true);
  assert.equal(h.v.paused,true);assert.equal(h.nativeCalls.play,0);h.close();
});
test('V8 native fullscreen cleans safe-stage styling before presenting', () => {
  const h=stageHarness();h.stage.enter();h.api.fullscreen();
  assert.equal(h.stage.active(),false);assert.equal(h.v.webkitPresentationMode,'fullscreen');h.close();
});
test('V8 1000 navigation-prompt interruptions retain one playback owner', () => {
  const h=harness();h.api.enterPiP();
  for(let i=0;i<1000;i++){h.api.setInterrupted(true);h.rawPause(h.v);h.api.setInterrupted(false,true);}
  assert.equal(h.nativeCalls.play,1000);assert.equal(h.nativeCalls.pip,1);assert.equal(h.timerCalls,0);h.close();
});

const preferencesSource = fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/sitePreferences.js'), 'utf8');
test('V8 fullscreen default enters once per video and does not reopen after exit', async () => {
  const h=harness();h.w.eval(preferencesSource);await Promise.resolve();
  assert.equal(h.nativeCalls.fullscreen,1);h.setMode(h.v,'inline');h.fire(h.v,'playing');await Promise.resolve();
  assert.equal(h.nativeCalls.fullscreen,1);assert.equal(h.d.documentElement.hasAttribute('dark'),true);h.close();
});
test('V16 Mac: pause from the PiP window stays paused (no automatic resume)', () => {
  const h=harness({mobile:false,standard:true});h.api.beginAutomaticHandoff();h.hide();h.advance(1000);
  h.rawPause(h.v);assert.equal(h.nativeCalls.play,0);assert.equal(h.v.paused,true);
  h.advance(2000);assert.equal(h.v.paused,true);h.close();
});
test('V16 iOS: pause in settled PiP is user intent; the first handoff moments may still recover', () => {
  const h=harness();h.api.enterPiP();h.hide();h.advance(900);h.rawPause(h.v);
  assert.equal(h.nativeCalls.play,0);assert.equal(h.v.paused,true);h.close();
});
test('V16 another tab starts a video: PiP closes to inline, paused, never fullscreen', () => {
  const h=harness();h.api.enterPiP();h.advance(900);h.api.remoteAction('pause');assert.equal(h.api.closePiPInline(),true);
  assert.equal(h.v.webkitPresentationMode,'inline');assert.equal(h.v.paused,true);assert.equal(h.api.restoreFullscreen(),false);h.close();
});
test('V10 desktop theater does not race automatic fullscreen or unconfigured native preferences', async () => {
  const h=harness({mobile:false});h.w.JOETOEP_NATIVE_HOST=true;
  const watch=h.d.createElement('ytd-watch-flexy');h.d.body.append(watch);
  const button=h.d.createElement('button');button.className='ytp-size-button';watch.append(button);
  let clicks=0;button.addEventListener('click',()=>{clicks++;watch.setAttribute('theater','');});
  h.w.eval(preferencesSource);await Promise.resolve();assert.equal(clicks,0,'not before native configuration');
  h.w.JoeToepPreferences.configure({automaticFullscreen:false,theater:false});await Promise.resolve();assert.equal(clicks,0);
  h.w.JoeToepPreferences.configure({automaticFullscreen:false,theater:true});await Promise.resolve();assert.equal(clicks,1,'V16 theater by default');
  watch.removeAttribute('theater');h.w.JoeToepPreferences.configure({theater:true});await Promise.resolve();
  assert.equal(clicks,1,'once per video: a user leaving theater mode is respected');
  h.close();
});
test('V19.1 exact playback speed via setRate (0.01 precision, clamped)', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  const c=h.w.JoeToepControls;
  assert.equal(c.setRate(1.15),1.15);assert.equal(h.v.playbackRate,1.15);
  assert.equal(c.setRate(9),4);assert.equal(c.setRate(0.01),0.1);assert.equal(c.setRate(1.234),1.23);
  c.configure({nativeWheel:true});h.close();
});
test('V19.2 pause leaves fullscreen after 350 ms; a quick pause/play does not', async () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  // V22.2: standaard uit (zoals in Swift); hier expliciet aangezet.
  h.w.JoeToepControls.configure({exitFullscreenOnPause:true});
  let exits=0;const fsEl=h.d.body;
  Object.defineProperty(h.d,'fullscreenElement',{configurable:true,get:()=>exits?null:fsEl});
  h.d.exitFullscreen=()=>{exits++;return Promise.resolve();};
  h.rawPause?h.rawPause(h.v):h.v.pause();h.v.dispatchEvent(new h.w.Event('pause',{bubbles:true}));
  await new Promise(r=>setTimeout(r,450));assert.equal(exits,1,'paused → out of fullscreen');
  h.close();
});
test('V19.2 F and double-click leave a fullscreen that YouTube does not own', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  let exits=0;Object.defineProperty(h.d,'fullscreenElement',{configurable:true,get:()=>h.d.documentElement});
  h.d.exitFullscreen=()=>{exits++;return Promise.resolve();};
  h.w.dispatchEvent(new h.w.KeyboardEvent('keydown',{key:'f',bubbles:true}));
  assert.equal(exits,0,'untrusted synthetic key is ignored');
  assert.equal(typeof h.w.JoeToepControls.exitFullscreen,'function');
  assert.equal(h.w.JoeToepControls.exitFullscreen(),true);assert.equal(exits,1);
  h.close();
});
test('V19 theater mode comes first, automatic fullscreen only after YouTube applied it', async () => {
  const h=harness({mobile:false});h.w.JOETOEP_NATIVE_HOST=true;
  const watch=h.d.createElement('ytd-watch-flexy');h.d.body.append(watch);
  const button=h.d.createElement('button');button.className='ytp-size-button';watch.append(button);
  const order=[];let applyTheater=false;
  button.addEventListener('click',()=>{order.push('theater');if(applyTheater)watch.setAttribute('theater','');});
  h.d.addEventListener('joetoep-automatic-fullscreen',()=>order.push('fullscreen'));
  h.w.eval(preferencesSource);
  h.w.JoeToepPreferences.configure({automaticFullscreen:true,theater:true});await Promise.resolve();
  assert.deepEqual(order,['theater'],'fullscreen waits while theater is being applied');
  watch.setAttribute('theater','');await new Promise(r=>setTimeout(r,0));await Promise.resolve();
  assert.deepEqual(order,['theater','fullscreen'],'then fullscreen follows exactly once');
  watch.setAttribute('fullscreen','');watch.removeAttribute('theater');await new Promise(r=>setTimeout(r,0));
  assert.equal(order.filter(x=>x==='theater').length,1,'never toggles theater while fullscreen');
  h.close();
});
test('V10 native automatic fullscreen waits for preferences and consumes exactly one request', async () => {
  const h=harness();h.w.JOETOEP_NATIVE_HOST=true;let requests=0;
  h.d.addEventListener('joetoep-automatic-fullscreen',()=>requests++);
  h.w.eval(preferencesSource);await Promise.resolve();assert.equal(requests,0);
  h.w.JoeToepPreferences.configure({automaticFullscreen:true});await Promise.resolve();
  assert.equal(requests,1);assert.equal(h.nativeCalls.fullscreen,0);
  assert.equal(h.w.JoeToepPreferences.fulfillFullscreenRequest(),true);
  assert.equal(h.w.JoeToepPreferences.fulfillFullscreenRequest(),false);
  h.setMode(h.v,'inline');h.fire(h.v,'playing');await Promise.resolve();
  assert.equal(requests,1);assert.equal(h.nativeCalls.fullscreen,1);h.close();
});
test('V10 Mac automatic fullscreen focuses YouTube and hands off one F request', async () => {
  const h=harness({mobile:false});h.w.JOETOEP_NATIVE_HOST=true;
  const player=h.d.querySelector('#player');player.id='movie_player';player.tabIndex=-1;
  h.w.eval(preferencesSource);h.w.JoeToepPreferences.configure({automaticFullscreen:true});await Promise.resolve();
  assert.equal(h.w.JoeToepPreferences.fulfillFullscreenRequest(true),'keyboard');
  assert.equal(h.d.activeElement,player);
  assert.equal(h.w.JoeToepPreferences.fulfillFullscreenRequest(true),false);
  assert.equal(h.nativeCalls.fullscreen,0);h.close();
});
test('V10 queued native fullscreen cannot open a changed, paused, hidden or disabled page', async () => {
  for(const change of ['navigation','pause','hidden','disabled']) {
    const h=harness();h.w.JOETOEP_NATIVE_HOST=true;h.w.eval(preferencesSource);
    h.w.JoeToepPreferences.configure({automaticFullscreen:true});await Promise.resolve();
    if(change==='navigation')h.w.history.replaceState({},'', '/watch?v=another');
    if(change==='pause')h.v.pause();
    if(change==='hidden')h.hide();
    if(change==='disabled')h.w.JoeToepPreferences.configure({automaticFullscreen:false});
    assert.equal(h.w.JoeToepPreferences.fulfillFullscreenRequest(),false);
    assert.equal(h.nativeCalls.fullscreen,0);h.close();
  }
});
test('V8 fullscreen preference can be disabled before playback', async () => {
  const h=harness();h.w.eval(preferencesSource);h.w.JoeToepPreferences.configure({automaticFullscreen:false});await Promise.resolve();
  assert.equal(h.nativeCalls.fullscreen,0);h.close();
});
test('V8 fullscreen never starts for homepage previews or hidden playback', async () => {
  for(const url of ['https://www.youtube.com/','https://www.youtube.com/watch?v=test']) {
    const h=harness({url});h.hide();h.w.eval(preferencesSource);await Promise.resolve();
    assert.equal(h.nativeCalls.fullscreen,0);h.close();
  }
});
test('V8 captions have independent preview and player settings', async () => {
  const h=harness();h.w.eval(preferencesSource);await Promise.resolve();
  const style=h.d.getElementById('joetoep-preferences');assert.ok(style.textContent.includes('ytd-video-preview'));
  h.w.JoeToepPreferences.configure({disablePreviewCaptions:false});await Promise.resolve();
  assert.equal(style.textContent,'.ytp-caption-window-container{display:none!important}');
  h.w.JoeToepPreferences.configure({disableCaptions:false});await Promise.resolve();assert.equal(style.textContent,'');h.close();
});


test('V10 direct mobile PiP return enters Apple fullscreen without an inline hop', () => {
  const h=harness();h.api.enterPiP();const modes=[];
  h.v.addEventListener('webkitpresentationmodechanged',()=>modes.push(h.v.webkitPresentationMode));
  h.api.returnToApp(true);assert.deepEqual(modes,['fullscreen']);assert.equal(h.nativeCalls.pause,0);h.close();
});
test('V10 reset clears stale requests and permits another PiP entry', () => {
  const h=harness();for(let i=0;i<1000;i++){
    h.api.enterPiP();assert.equal(h.api.resetPiP(),'exiting');assert.equal(h.v.webkitPresentationMode,'inline');
    assert.equal(h.api.enterPiP().status,'active');h.api.returnToApp(true);
  }assert.equal(h.nativeCalls.pause,0);assert.equal(h.timerCalls,0);h.close();
});
test('V10 AirPlay picker belongs to the video and removes remote playback opt-outs', () => {
  const h=harness();let picked=null;
  h.v.setAttribute('disableremoteplayback','');h.v.webkitWirelessVideoPlaybackDisabled=true;
  h.v.webkitShowPlaybackTargetPicker=function(){picked=this;};
  assert.equal(h.api.showVideoAirPlay(),'requested');assert.equal(picked,h.v);
  assert.equal(h.v.hasAttribute('disableremoteplayback'),false);assert.equal(h.v.webkitWirelessVideoPlaybackDisabled,false);h.close();
});
test('V10 seeking clamps both edges and live DVR bounds; volume is bounded', () => {
  const h=harness({mobile:false});h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  const c=h.w.JoeToepControls;Object.defineProperty(h.v,'duration',{value:120,configurable:true});
  h.v.currentTime=20;c.seek(-60);assert.equal(h.v.currentTime,0);c.seek(300);assert.equal(h.v.currentTime,120);
  Object.defineProperty(h.v,'seekable',{value:{length:1,start:()=>60,end:()=>100}});c.seek(-300);assert.equal(h.v.currentTime,60);
  h.v.volume=.7;c.volume(.05);assert.equal(h.v.volume,.75);c.volume(10);assert.equal(h.v.volume,1);c.volume(-10);assert.equal(h.v.volume,0);
  c.toggle();assert.equal(h.v.paused,true);c.toggle();assert.equal(h.v.paused,false);h.close();
});


test('V18 arrow keys drive YouTube\'s own player API and keep its controls hidden', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  const p=h.w.document.getElementById('movie_player')||(()=>{const d=h.w.document.createElement('div');d.id='movie_player';h.w.document.body.appendChild(d);return d;})();
  let t=50,vol=40,muted=false,rate=1;
  Object.assign(p,{seekTo:(x)=>{t=x;},getCurrentTime:()=>t,getDuration:()=>100,setVolume:(v)=>{vol=v;},getVolume:()=>vol,
    mute:()=>{muted=true;},unMute:()=>{muted=false;},getPlaybackRate:()=>rate,setPlaybackRate:(r)=>{rate=r;}});
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  const c=h.w.JoeToepControls;
  c.seek(5);assert.equal(t,55);c.seek(-100);assert.equal(t,0);c.seek(500);assert.equal(t,100);
  c.volume(.05);assert.equal(vol,45);c.volume(-1);assert.equal(vol,0);assert.equal(muted,true);c.volume(.1);assert.equal(muted,false);
  assert.ok(p.classList.contains('joetoep-quiet'),'YouTube controls stay invisible while we adjust');
  assert.ok(h.w.document.getElementById('joetoep-quiet-controls'));
  assert.equal(c.rate(1),1.25);assert.equal(rate,1.25);assert.equal(c.rate(1),1.5);assert.equal(c.rate(-1),1.25);
  assert.equal(c.rate(0),1);assert.equal(c.rate(-1),0.75);
  rate=2;assert.equal(c.rate(1),2.5);assert.equal(h.v.playbackRate,2.5,'above 2x the element is set directly');
  h.close();
});

test('V16.2.1 clicking the video to pause right after a PiP return stays paused (Mac)', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  h.api.enterPiP(); h.api.returnToApp('origin'); h.advance(500);   // inside the 3 s return window
  const plays=h.nativeCalls.play;
  h.userClick(h.v); h.v.pause();                                    // real click → YouTube pauses
  assert.equal(h.v.paused,true); h.advance(300); h.fire(h.v,'pause');
  assert.equal(h.nativeCalls.play,plays,'no automatic resume after a user pause'); h.close();
});
test('V16.2.1 clicking the video (iPhone/iPad) during the return window stays paused too', () => {
  const h=harness(); h.api.enterPiP(); h.hide(); h.show(); h.api.returnToApp('origin'); h.advance(400);
  const plays=h.nativeCalls.play; h.userClick(h.v); h.rawPause(h.v);
  assert.equal(h.v.paused,true); assert.equal(h.nativeCalls.play,plays); h.close();
});
test('V16.2.1 without a user click the return window still recovers a system pause', () => {
  const h=harness(); h.api.enterPiP(); h.api.returnToApp('origin'); h.advance(400);
  h.rawPause(h.v); assert.equal(h.v.paused,false,'system pause is undone once'); h.close();
});
test('V16.2.1 a click on a child of the player counts as user intent', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  const player=h.d.createElement('div'); player.className='html5-video-player';
  const overlay=h.d.createElement('div'); player.appendChild(overlay); h.d.body.appendChild(player);
  h.api.enterPiP(); h.api.returnToApp('origin'); h.advance(300);
  h.userClick(overlay); h.rawPause(h.v); assert.equal(h.v.paused,true); h.close();
});
test('V16.2.1 hand-over: closing PiP for another tab never restores fullscreen and keeps it paused', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  h.api.configure({returnTarget:'fullscreen'}); h.api.enterPiP();
  h.api.remoteAction('pause'); assert.equal(h.api.closePiPInline(),true);
  assert.equal(h.api.restoreFullscreen(),false,'no fullscreen for the old tab');
  assert.equal(h.v.paused,true); h.advance(1000); h.fire(h.v,'pause'); assert.equal(h.v.paused,true); h.close();
});
test('V16.2.1 500 rapid click-pause/play cycles never auto-resume and leave no timers', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'});
  for(let i=0;i<500;i++){ h.userClick(h.v); h.v.pause(); assert.equal(h.v.paused,true); h.advance(50); h.userClick(h.v); h.v.play(); assert.equal(h.v.paused,false); h.advance(50); }
  assert.equal(h.timerCalls,0); h.close();
});
test('V10 keyboard modifiers map to 5/30/60 seconds and ignore text entry', () => {
  const h=harness({mobile:false}), listeners={};
  h.w.addEventListener=(type,fn)=>{listeners[type]=fn;};
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  Object.defineProperty(h.v,'duration',{value:600});h.v.currentTime=100;
  const key=(key,extra={})=>listeners.keydown({key,isTrusted:true,target:h.v,preventDefault(){},stopImmediatePropagation(){},...extra});
  key('ArrowRight');assert.equal(h.v.currentTime,105);
  key('ArrowLeft',{altKey:true});assert.equal(h.v.currentTime,75);
  key('ArrowRight',{altKey:true,metaKey:true});assert.equal(h.v.currentTime,135);
  key('ArrowRight',{metaKey:true});assert.equal(h.v.currentTime,135);
  const input=h.d.createElement('input');key('ArrowRight',{target:input});assert.equal(h.v.currentTime,135);
  key(' ',{target:input});assert.equal(h.v.paused,false);
  h.v.volume=.7;key('ArrowDown');assert.equal(h.v.volume,.65);key('ArrowUp');assert.equal(h.v.volume,.7);
  key(' ');assert.equal(h.v.paused,true);key(' ');assert.equal(h.v.paused,false);h.close();
});
test('V10 trackpad changes only the fullscreen video and preserves page scrolling', () => {
  const h=harness({mobile:false}), listeners={};
  h.w.addEventListener=(type,fn)=>{listeners[type]=fn;};
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  Object.defineProperty(h.v,'duration',{value:600});h.v.currentTime=100;h.v.volume=.7;
  let prevented=0;const wheel=(x,y,extra={})=>listeners.wheel({isTrusted:true,target:h.v,deltaMode:0,deltaX:x,deltaY:y,preventDefault(){prevented++;},stopImmediatePropagation(){},...extra});
  wheel(60,0);assert.equal(h.v.currentTime,100);assert.equal(prevented,0);
  // V19: every 28 px = one small step (5 s / 1 %), so a 60 px swipe = 2 steps.
  h.d.documentElement.setAttribute('data-joetoep-stage','');wheel(60,0);assert.equal(h.v.currentTime,110);
  wheel(0,-60);assert.equal(h.v.volume,.72);wheel(0,60);assert.equal(h.v.volume,.7);
  wheel(60,0,{ctrlKey:true});assert.equal(h.v.currentTime,110);
  h.w.JoeToepControls.configure({swipeSeek:1,volumeStep:.05});wheel(30,0);assert.equal(h.v.currentTime,111,'step size is configurable');
  h.close();
});

test('V11 slash focuses the YouTube search field and typing in fields is untouched', async () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/'});
  const input=h.d.createElement('input');input.id='search';h.d.body.append(input);
  h.w.Element.prototype.getClientRects=function(){return [{width:10,height:10}];};
  const add=h.w.addEventListener.bind(h.w);let keydown=null;
  h.w.addEventListener=(type,fn,opt)=>{if(type==='keydown')keydown=fn;return add(type,fn,opt);};
  h.w.eval(preferencesSource);await Promise.resolve();
  let prevented=0;const ev=t=>({key:'/',isTrusted:true,target:t,preventDefault(){prevented++;},stopImmediatePropagation(){}});
  keydown(ev(h.d.body));assert.equal(h.d.activeElement,input);assert.equal(prevented,1);
  keydown(ev(input));assert.equal(prevented,1,'typing / inside search stays normal');
  assert.equal(h.w.JoeToepPreferences.focusSearch(),'focused');h.close();
});
test('V11 mobile new-tab focus opens the search overlay then focuses its input', async () => {
  const h=harness({url:'https://m.youtube.com/'});
  h.w.Element.prototype.getClientRects=function(){return this.hidden?[]:[{width:10,height:10}];};
  const button=h.d.createElement('button');button.setAttribute('aria-label','Search YouTube');h.d.body.append(button);
  button.addEventListener('click',()=>{const i=h.d.createElement('input');i.className='searchbox-input';h.d.body.append(i);});
  h.w.eval(preferencesSource);await Promise.resolve();
  assert.equal(h.w.JoeToepPreferences.focusSearch(),'pending');
  await new Promise(r=>setTimeout(r,200));assert.equal(h.d.activeElement.className,'searchbox-input');h.close();
});
test('V11 refresh/relaunch resumes the same video at the saved time and plays', async () => {
  const h=harness();h.w.eval(preferencesSource);await Promise.resolve();
  Object.defineProperty(h.v,'duration',{value:600});h.v.currentTime=0;h.rawPause(h.v);
  assert.equal(h.w.JoeToepPreferences.expectResume(123.4,true),true);
  assert.equal(Math.round(h.v.currentTime),123);assert.equal(h.v.paused,false);
  h.v.currentTime=5;h.fire(h.v,'loadedmetadata');assert.equal(h.v.currentTime,5,'one bounded attempt only');
  assert.equal(h.w.JoeToepPreferences.expectResume(0.2,true),false);h.close();
});
test('V11 Space toggles exactly once on Mac (YouTube owns it; Enhanced stage uses the player API)', () => {
  const h=harness({mobile:false,url:'https://www.youtube.com/watch?v=fixture'}), listeners={};
  const player=h.d.createElement('div');player.id='movie_player';h.d.body.append(player);
  let api=[];player.playVideo=()=>{api.push('play');h.v.play();};player.pauseVideo=()=>{api.push('pause');h.v.pause();};
  h.w.addEventListener=(type,fn)=>{listeners[type]=fn;};
  h.w.eval(fs.readFileSync(path.join(__dirname,'../JoeToep/Resources/playbackControls.js'),'utf8'));
  h.rawPause(h.v);const key=k=>listeners.keydown({key:k,isTrusted:true,target:h.v,preventDefault(){},stopImmediatePropagation(){}});
  key(' ');assert.deepEqual(api,[],'on a normal YouTube page Space is left to YouTube (single toggle)');
  h.d.documentElement.setAttribute('data-joetoep-stage','');
  key(' ');assert.deepEqual(api,['play']);assert.equal(h.v.paused,false);
  key(' ');assert.deepEqual(api,['play','pause']);assert.equal(h.v.paused,true);h.close();
});
test('V11 a lock/unlock pause of PiP is recovered once, an explicit pause is not', () => {
  const h=harness();h.api.enterPiP();h.api.platformTransition();h.rawPause(h.v);
  assert.equal(h.v.paused,false);h.rawPause(h.v);assert.equal(h.v.paused,true,'only one recovery');
  const h2=harness();h2.api.enterPiP();h2.w.navigator.mediaSession.invoke('pause');h2.api.platformTransition();h2.rawPause(h2.v);
  assert.equal(h2.v.paused,true,'user pause wins');h.close();h2.close();
});

test('V12 mobile page lifecycle signals are masked while the protected video plays', () => {
  const h=harness();let site=0;
  for(const n of ['webkitvisibilitychange','pagehide','freeze','blur'])h.w.addEventListener(n,()=>site++);
  h.hide();for(const n of ['webkitvisibilitychange','freeze','blur'])h.w.dispatchEvent(new h.w.Event(n));
  assert.equal(site,0);assert.equal(h.d.hasFocus(),true);h.close();
});
test('V12 rotating back to portrait leaves Apple fullscreen and keeps playing inline', async () => {
  const h=harness();h.setMode(h.v,'fullscreen');h.v.webkitExitFullscreen=()=>{h.setMode(h.v,'inline');h.rawPause(h.v);};
  assert.equal(h.api.exitFullscreenKeepPlaying(),true);assert.equal(h.v.webkitPresentationMode,'inline');
  await new Promise(r=>setTimeout(r,500));assert.equal(h.v.paused,false);h.close();
});
test('V12 optional YouTube element fullscreen uses the player container, not the Apple player', () => {
  const h=harness();let target=null;h.w.Element.prototype.requestFullscreen; 
  h.api.configure({elementFullscreen:true});
  const container=h.d.querySelector('#player');container.classList.add('player-container');
  h.w.document.fullscreenElement;h.api.fullscreen();
  assert.equal(h.nativeCalls.fullscreen,0,'no Apple video fullscreen');h.close();
});

// V22 — ✕ in het PiP-venster: gepauzeerd blijven, geen fullscreen terug, niet hervatten.
test('V22 closing PiP with X keeps the video paused and never restores fullscreen', () => {
  const h=harness(); h.api.enterPiP(); h.advance(2000);
  h.rawPause(h.v);                         // WebKit pauzeert eerst…
  h.setMode(h.v,'inline');                 // …en verlaat dan PiP
  h.advance(500); h.rawPause(h.v);
  assert.equal(h.v.paused,true); assert.equal(h.nativeCalls.play,0);
  assert.equal(h.api.restoreFullscreen(true),false); h.close();
});
test('V22 PiP return button (still playing) keeps playing as before', () => {
  const h=harness(); h.api.enterPiP(); h.advance(2000); h.setMode(h.v,'inline');
  assert.equal(h.v.paused,false); h.close();
});
test('V22 native PiP closed with X stays paused', () => {
  const h=harness(); h.api.nativeReturn(42, true, false);
  assert.equal(h.v.paused,true); assert.equal(h.nativeCalls.play,0); h.close();
});
// V22 — een tab die door sync werd bijgewerkt mag niet zelf gaan spelen.
test('V22 sync quiet window blocks autoplay but allows a real click or JoeToep command', () => {
  const h=harness(); h.rawPause(h.v); h.api.quiet(10000);
  h.rawPlay(h.v); assert.equal(h.v.paused,true);
  h.userClick(h.v); h.rawPlay(h.v); assert.equal(h.v.paused,false);
  h.rawPause(h.v); h.advance(3000); h.api.quiet(10000);
  h.api.remoteAction('play'); assert.equal(h.v.paused,false);
  h.close();
});
test('V22 quiet window expires by itself', () => {
  const h=harness(); h.rawPause(h.v); h.api.quiet(1000); h.advance(1500);
  h.rawPlay(h.v); assert.equal(h.v.paused,false); h.close();
});

(async()=>{
  const failed=[];
  if (process.env.LIST_FAILS) { for(const [name,body] of tests){ try { await body(); } catch(e) { failed.push(name+' :: '+String(e.message).split('\n')[0]); } unhandled.length=0; } console.log(failed.join('\n')); return; }
  for(const [name,body] of tests){ await body();await new Promise(resolve=>setImmediate(resolve));assert.equal(unhandled.length,0,unhandled.map(e=>e.stack).join('\n'));console.log('PASS '+name); }
  console.log('PASS '+tests.length+' DOM scenarios, including 10,000 transitions + 2,000 fullscreen cycles; Apple media APIs simulated');
})().catch(error=>{console.error(error);process.exitCode=1;});
