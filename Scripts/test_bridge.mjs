import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = fs.readFileSync(path.join(root, "JoeToep/Resources/playerBridge.js"), "utf8");
const qualitySource = fs.readFileSync(path.join(root, "JoeToep/Resources/qualityBridge.js"), "utf8");
let passed = 0;
const tests = [];
function test(name, action) { tests.push([name, action]); }
class Emitter {
  constructor() { this.listeners = new Map(); }
  addEventListener(name, fn, options = {}) {
    const entries = this.listeners.get(name) || [];
    entries.push({ fn, options }); this.listeners.set(name, entries);
  }
  emit(name, fields = {}) {
    const event = { target: this, touches: [], defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, ...fields };
    for (const entry of [...(this.listeners.get(name) || [])]) {
      entry.fn(event);
      if (entry.options.once) this.listeners.set(name, this.listeners.get(name).filter(x => x !== entry));
    }
    return event;
  }
}
class Style {
  constructor() { this.values = new Map(); }
  getPropertyValue(name) { return this.values.get(name)?.[0] || ""; }
  getPropertyPriority(name) { return this.values.get(name)?.[1] || ""; }
  setProperty(name, value, priority = "") { this.values.set(name, [value, priority]); }
  removeProperty(name) { this.values.delete(name); }
}
class Video extends Emitter {
  constructor(main = true) {
    super(); this.tagName = "VIDEO"; this.isConnected = true; this.videoWidth = 1920; this.videoHeight = 1080;
    this.readyState = 4; this.paused = false; this.ended = false; this.webkitPresentationMode = "inline";
    this.classList = { contains: c => c === "html5-main-video" && main };
    this.style = new Style(); this.rect = { width: 640, height: 360 };
    this.webkitSupportsPresentationMode = () => true;
    this.webkitSetPresentationMode = mode => { this.webkitPresentationMode = mode; this.emit("webkitpresentationmodechanged"); };
  }
  getBoundingClientRect() { return this.rect; }
  querySelectorAll() { return []; }
}
function harness({ videos = [new Video()], readyState = "complete", withHandler = true } = {}) {
  const messages = [], observers = [];
  const doc = new Emitter();
  doc.readyState = readyState; doc.fullscreenElement = null; doc.documentElement = {};
  doc.pictureInPictureEnabled = true;
  doc.querySelectorAll = () => videos.filter(v => v.isConnected);
  doc.getElementById = () => null; doc.querySelector = () => null;
  class Observer {
    constructor(callback) { this.callback = callback; this.calls = 0; observers.push(this); }
    observe() { this.calls++; }
  }
  const win = withHandler ? { webkit: { messageHandlers: { joeToep: { postMessage: x => messages.push(x) } } } } : {};
  const context = vm.createContext({ window: win, document: doc, MutationObserver: Observer, console });
  const install = () => vm.runInContext(source, context);
  install();
  const mutate = nodes => observers[0].callback([{ addedNodes: nodes }]);
  return { videos, messages, observers, doc, win, context, install, mutate, bridge: win.JoeToepBridge };
}
const latest = h => h.messages.filter(x => x.event === "state").at(-1);

test("snapshot reports one authoritative active main video", () => {
  const preview = new Video(false); const main = new Video(); const h = harness({ videos: [preview, main] });
  assert.equal(latest(h).width, 1920); assert.equal(latest(h).playing, true);
  const before = h.messages.length; preview.paused = true; preview.emit("pause");
  assert.equal(h.messages.length, before, "preview events must not change main state");
});
test("installation and video listeners are idempotent", () => {
  const h = harness(), v = h.videos[0]; h.install();
  for (let i = 0; i < 1000; i++) h.mutate([v]);
  assert.equal(v.listeners.get("play").length, 1); assert.equal(h.observers.length, 1);
  assert.equal(h.messages.filter(x => x.event === "ready").length, 1);
});
test("DOMContentLoaded starts exactly once", () => {
  const h = harness({ readyState: "loading" });
  assert.equal(h.messages.length, 0); h.doc.emit("DOMContentLoaded"); h.doc.emit("DOMContentLoaded");
  assert.equal(h.messages.filter(x => x.event === "ready").length, 1);
});
test("WebKit fullscreen to PiP is atomic and never calls exit or pause", () => {
  const h = harness(), v = h.videos[0];
  v.webkitPresentationMode = "fullscreen"; v.emit("webkitbeginfullscreen");
  assert.equal(latest(h).fullscreen, true);
  assert.equal(h.bridge.requestPiP(1).status, "active");
  assert.equal(latest(h).pip, true); assert.equal(latest(h).fullscreen, false); assert.equal(v.paused, false);
  v.emit("webkitendfullscreen");
  assert.equal(latest(h).pip, true); assert.equal(h.bridge.requestPiP(2).status, "active");
});
test("PiP exits cleanly and does not reopen itself", () => {
  const h = harness(); h.bridge.requestPiP(1); h.bridge.exitPiP();
  assert.equal(latest(h).pip, false); assert.equal(h.videos[0].webkitPresentationMode, "inline");
});
test("no video, insufficient metadata and unsupported return distinct outcomes", () => {
  assert.equal(harness({ videos: [] }).bridge.requestPiP(1).status, "no-video");
  const h = harness(); h.videos[0].readyState = 0;
  assert.equal(h.bridge.requestPiP(1).status, "not-ready");
  h.videos[0].readyState = 4; h.videos[0].webkitSupportsPresentationMode = () => false;
  assert.equal(h.bridge.requestPiP(2).status, "unavailable");
});
test("synchronous PiP failure frees the request gate", () => {
  const h = harness(); h.videos[0].webkitSetPresentationMode = () => { throw new Error("Denied"); };
  assert.equal(h.bridge.requestPiP(1).status, "rejected");
  assert.equal(h.bridge.requestPiP(2).status, "rejected");
});
test("asynchronous rejection carries the correct token", async () => {
  const h = harness(), v = h.videos[0]; v.webkitSupportsPresentationMode = () => false;
  v.requestPictureInPicture = () => Promise.reject(new Error("No activation"));
  assert.equal(h.bridge.requestPiP(77).status, "requested");
  await Promise.resolve();
  assert.equal(h.messages.at(-1).event, "pipFailure"); assert.equal(h.messages.at(-1).token, 77);
});
test("late rejection cannot undo confirmed PiP", async () => {
  const h = harness(), v = h.videos[0]; let reject;
  v.webkitSupportsPresentationMode = () => false;
  v.requestPictureInPicture = () => new Promise((resolve, r) => { reject = r; });
  h.bridge.requestPiP(9);
  h.doc.pictureInPictureElement = v; v.emit("enterpictureinpicture");
  reject(new Error("late")); await Promise.resolve();
  assert.equal(h.messages.filter(x => x.event === "pipFailure").length, 0);
  assert.equal(latest(h).pip, true);
});
test("overlapping requests are bounded; cancelled callbacks are ignored", async () => {
  const h = harness(), v = h.videos[0]; let reject;
  v.webkitSupportsPresentationMode = () => false;
  v.requestPictureInPicture = () => new Promise((resolve, r) => { reject = r; });
  assert.equal(h.bridge.requestPiP(1).status, "requested");
  assert.equal(h.bridge.requestPiP(2).status, "busy");
  h.bridge.cancelRequest(1); reject(new Error("cancelled")); await Promise.resolve();
  assert.equal(h.messages.filter(x => x.event === "pipFailure").length, 0);
});
test("removed video is released and replacements get new identities", () => {
  const h = harness(), first = latest(h).videoID;
  h.videos[0].isConnected = false; h.mutate([]); assert.equal(latest(h).videoID, 0);
  const next = new Video(); h.videos.push(next); h.mutate([next]); assert.notEqual(latest(h).videoID, first);
  assert.equal(next.listeners.get("playing").length, 1);
});
test("fill and pinch zoom are bounded; reset restores transform", () => {
  const h = harness(), v = h.videos[0];
  h.bridge.configure({ fit: "fill", pinch: "video" });
  assert.equal(v.style.getPropertyValue("object-fit"), "cover");
  const touch = d => [{ clientX: 0, clientY: 0 }, { clientX: d, clientY: 0 }];
  v.emit("touchstart", { touches: touch(100) });
  const event = v.emit("touchmove", { touches: touch(900) });
  assert.equal(event.defaultPrevented, true); assert.equal(v.style.getPropertyValue("transform"), "scale(3.000)");
  h.bridge.resetZoom(); assert.equal(v.style.getPropertyValue("transform"), "");
  h.bridge.configure({ fit: "fit", pinch: "off" }); v.emit("touchstart", { touches: touch(100) });
  assert.equal(v.emit("touchmove", { touches: touch(200) }).defaultPrevented, false);
});
test("missing native handler is safe", () => {
  const h = harness({ withHandler: false }); assert.equal(h.bridge.state().playing, true);
  h.bridge.requestPiP(1); assert.equal(h.bridge.state().pip, true);
});
test("10,000 presentation transitions have bounded listeners and no timers", () => {
  const h = harness(), v = h.videos[0];
  for (let i = 1; i <= 10000; i++) {
    v.webkitPresentationMode = "fullscreen"; v.emit("webkitpresentationmodechanged");
    assert.equal(h.bridge.requestPiP(i).status, "active");
    v.emit("webkitendfullscreen"); assert.equal(h.bridge.state().pip, true);
    h.bridge.exitPiP();
  }
  assert.equal(v.listeners.get("webkitpresentationmodechanged").length, 1);
  assert.equal(h.observers.length, 1); assert.equal(h.bridge.state().pip, false);
  assert.equal(source.includes("setInterval"), false); assert.equal(source.includes("setTimeout"), false);
});
test("2,000 SPA video replacements retain one observer and deduplicate events", () => {
  const h = harness();
  for (let i = 0; i < 2000; i++) {
    h.videos.at(-1).isConnected = false;
    const v = new Video(); h.videos.push(v); h.mutate([v]);
    const n = h.messages.length; v.emit("playing"); v.emit("playing"); assert.equal(h.messages.length, n);
  }
  assert.equal(h.observers.length, 1);
});
test("quality helper distinguishes requests from unavailable resolutions", () => {
  let quality = "hd720", calls = 0;
  const player = { getAvailableQualityLevels: () => ["hd1080", "hd720", "unknown"],
    getPlaybackQuality: () => quality,
    setPlaybackQualityRange: (a, b) => { calls++; assert.equal(a,b); /* simulate adaptive player ignoring request */ } };
  const win = {}; const doc = { getElementById: () => player };
  const ctx = vm.createContext({ window: win, document: doc }); vm.runInContext(qualitySource, ctx);
  assert.equal(win.JoeToepQuality.read().levels.length, 2);
  assert.equal(win.JoeToepQuality.request("hd2160").status, "not-offered");
  const reply = win.JoeToepQuality.request("hd1080");
  assert.equal(reply.status, "requested"); assert.equal(reply.actual, "hd720"); assert.equal(calls, 1);
  assert.equal(win.JoeToepQuality.request("bad-input").status, "invalid");
});
test("quality helper handles missing/changing site API without throwing", () => {
  const win = {}; const doc = { getElementById: () => null, querySelector: () => null };
  vm.runInContext(qualitySource, vm.createContext({ window: win, document: doc }));
  assert.equal(win.JoeToepQuality.read().supported, false);
  assert.equal(win.JoeToepQuality.request("auto").status, "unavailable");
});
for (const [name, fn] of tests) {
  await fn(); passed++; console.log("PASS " + name);
}
console.log("PASS " + passed + " bridge/quality scenarios, 10,000 PiP cycles and 2,000 replacements (mocked APIs; not Apple-device tests)");
