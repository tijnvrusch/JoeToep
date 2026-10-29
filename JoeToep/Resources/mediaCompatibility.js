/* JoeToep V10: scoped YouTube presentation compatibility, installed before site scripts.
 * Independent implementation informed by Brave's media-backgrounding design.
 * No polling, stream extraction, screenshots, or fake background activity.
 */
(() => {
  "use strict";
  const host = location.hostname.toLowerCase();
  if (!(host === "youtube.com" || host.endsWith(".youtube.com") ||
        host === "youtube-nocookie.com" || host.endsWith(".youtube-nocookie.com") ||
        (location.protocol === "file:" && window.JOETOEP_TEST))) return;
  if (window.JoeToepMedia) return;
  const platform = window.JOETOEP_MOBILE === true;
  let config = { protect: true, automatic: true, nativeFullscreen: true, macFullscreen: "youtube", fallback: true, elementFullscreen: false, returnTarget: "fullscreen", keepPlaying: true };
  const originalRequest = Element.prototype.requestFullscreen || Element.prototype.webkitRequestFullscreen;
  // V12: YouTube's own player container in WebKit element fullscreen, as on the desktop site.
  // WebKit prepares its automatic-PiP standby presenter for element fullscreen only.
  const playerContainer = v => v.closest("#player-container-id, .player-container, #movie_player, .html5-video-player, ytm-player") || v.parentElement || v;
  const elementFullscreen = v => {
    if (document.fullscreenElement || document.webkitFullscreenElement) return true;
    if (typeof originalRequest !== "function") return false;
    window.JoeToepStage?.exit();
    try {
      const result = originalRequest.call(playerContainer(v));
      result?.catch?.(() => { lastStatus = "element-fullscreen-declined"; signal(); });
      return true;
    } catch (_) { lastStatus = "element-fullscreen-declined"; return false; }
  };
  const native = {
    play: HTMLMediaElement.prototype.play,
    pause: HTMLMediaElement.prototype.pause,
    exitPiP: document.exitPictureInPicture,
    presentation: HTMLVideoElement.prototype.webkitSetPresentationMode,
    fullscreen: HTMLVideoElement.prototype.webkitEnterFullscreen,
    visibility: Object.getOwnPropertyDescriptor(Document.prototype, "visibilityState"),
    hidden: Object.getOwnPropertyDescriptor(Document.prototype, "hidden")
  };
  let main = null, desiredPlaying = false, lastPauseAt = 0, userPause = false;
  let handoffUntil = 0, allowPauseUntil = 0, interrupted = false, recoveryUsed = false;
  let backgroundEpisode = false, fallbackRoot = null, lastStatus = "ready";
  let externalRequestUntil = 0;
  let lastPiPVideo = null;
  // Presentation the video had right before PiP began: return exactly there (no inline hop).
  let lastMode = "inline", pipOrigin = "inline";
  let systemHandoff = false;
  // V15 (Mac): YouTube element fullscreen right before PiP counts as a fullscreen origin.
  let pageFullscreenAt = 0;
  const pageFullscreen = () => Boolean(document.fullscreenElement || document.webkitFullscreenElement);
  for (const name of ["fullscreenchange", "webkitfullscreenchange"])
    document.addEventListener(name, () => { pageFullscreenAt = Date.now(); if (pageFullscreen()) pageFullscreenAt = Infinity; }, true);
  const wantsFullscreenReturn = () => config.returnTarget === "fullscreen" ||
    (config.returnTarget === "origin" && pipOrigin === "fullscreen");
  // V10: while a prepared native AVKit presenter owns background PiP, the web video must not
  // request its own (inline PiP cannot start after deactivation and would compete).
  let nativeOwner = false, nativeActive = false;
  // V11: lock/unlock and similar OS transitions may pause PiP without user intent; recover once.
  let transitionUntil = 0, transitionRecovered = false;
  let requestUntil = 0, interruptionWantsPlay = false;
  const handoffDuration = 5000;
  let returnUntil = 0, returnWantsPlay = false, returnRecoveryUsed = false;
  const rawVisibility = () => native.visibility?.get?.call(document) || "visible";
  const isPiP = v => Boolean(v && (v.webkitPresentationMode === "picture-in-picture" || document.pictureInPictureElement === v));
  const pick = () => {
    if (main?.isConnected && isPiP(main)) return main;
    const videos = Array.from(document.querySelectorAll("video"));
    const candidate = videos.find(v => v.classList.contains("html5-main-video")) ||
      videos.find(v => !v.paused && !v.ended) || videos[0] || null;
    if (candidate !== main) {
      main = candidate; desiredPlaying = Boolean(main && !main.paused && !main.ended);
      userPause = false; lastPauseAt = 0; recoveryUsed = false;
    }
    return main;
  };
  const signal = () => document.dispatchEvent(new Event("joetoep-media-state"));
  const isMediaPage = () => location.pathname === "/watch" ||
    ["/shorts/", "/live/", "/embed/"].some(prefix => location.pathname.startsWith(prefix)) ||
    (location.protocol === "file:" && window.JOETOEP_TEST);
  const eligible = v => Boolean(config.protect && !interrupted && v && v === pick() && !v.ended &&
    (isMediaPage() || isPiP(v) || Date.now() < handoffUntil));
  const protectedNow = v => eligible(v) && (isPiP(v) || Date.now() < handoffUntil ||
    (returnWantsPlay && Date.now() < returnUntil));
  const shouldMaskVisibility = () => {
    const v = pick();
    return eligible(v) && (isPiP(v) || desiredPlaying || Date.now() < handoffUntil);
  };
  // V12: mobile YouTube (unlike desktop) stops playback when it detects background use.
  // Mask every page-lifecycle signal it can read while the protected video plays or is in PiP.
  const webkitVisibility = Object.getOwnPropertyDescriptor(Document.prototype, "webkitVisibilityState");
  const webkitHidden = Object.getOwnPropertyDescriptor(Document.prototype, "webkitHidden");
  const nativeHasFocus = Document.prototype.hasFocus;
  if (typeof nativeHasFocus === "function") {
    Document.prototype.hasFocus = function() { return (this === document && shouldMaskVisibility()) || nativeHasFocus.call(this); };
  }
  for (const [key, descriptor, value] of [["visibilityState", native.visibility, "visible"], ["hidden", native.hidden, false],
                                          ["webkitVisibilityState", webkitVisibility, "visible"], ["webkitHidden", webkitHidden, false]]) {
    if (descriptor?.configurable && descriptor.get) {
      Object.defineProperty(Document.prototype, key, { ...descriptor,
        get() { return this === document && shouldMaskVisibility() ? value : descriptor.get.call(this); }
      });
    }
  }
  HTMLMediaElement.prototype.pause = function(...args) {
    if (protectedNow(this) && Date.now() >= allowPauseUntil && !userPause) {
      lastStatus = "blocked-site-pause"; return;
    }
    if (this === pick() && !interrupted) { desiredPlaying = false; userPause = true; }
    return native.pause.apply(this, args);
  };
  HTMLMediaElement.prototype.play = function(...args) {
    if (nativeActive && this === pick()) { lastStatus = "blocked-site-play-native-pip"; return Promise.resolve(); }
    if (config.protect && this === pick() && userPause &&
        (isPiP(this) || rawVisibility() !== "visible") && Date.now() >= allowPauseUntil) {
      lastStatus = "blocked-site-resume-after-user-pause";
      return Promise.resolve();
    }
    if (platform && this.tagName === "VIDEO") {
      this.setAttribute("playsinline", ""); this.setAttribute("webkit-playsinline", "");
    }
    if (this === pick()) { desiredPlaying = true; userPause = false; }
    return native.play.apply(this, args);
  };
  if (typeof native.presentation === "function") {
    HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) {
      if (mode !== "picture-in-picture" && isPiP(this) && protectedNow(this) && Date.now() >= allowPauseUntil) {
        lastStatus = "blocked-site-pip-exit"; return;
      }
      return native.presentation.call(this, mode);
    };
  }

  if (typeof native.exitPiP === "function") {
    document.exitPictureInPicture = function(...args) {
      const v = document.pictureInPictureElement;
      if (v && protectedNow(v) && Date.now() >= allowPauseUntil) return Promise.resolve();
      return native.exitPiP.apply(this, args);
    };
  }

  // One media owner: WebKit's Media Session delivers system controls to the
  // actual video. No competing MPRemoteCommandCenter or duplicate AVPlayer.
  const mediaSession = navigator.mediaSession;
  const nativeSetAction = mediaSession?.setActionHandler;
  function remoteAction(action) {
    const v = pick();
    if (!v || !(isMediaPage() || isPiP(v))) return false;
    // Cancel every recovery budget BEFORE touching playback.
    handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
    recoveryUsed = true; returnRecoveryUsed = true;
    if (action === "pause") {
      userPause = true; desiredPlaying = false; interruptionWantsPlay = false;
      native.pause.call(v);
    } else {
      if (interrupted) return true;
      userPause = false; desiredPlaying = true;
      native.play.call(v)?.catch(() => { lastStatus = "remote-play-declined"; signal(); });
    }
    lastStatus = "remote-" + action;
    updateMediaState(); signal(); return true;
  }
  function updateMediaState() {
    if (!mediaSession) return;
    const v = pick();
    if (!v || !(isMediaPage() || isPiP(v))) return;
    try { mediaSession.playbackState = v.ended ? "none" : v.paused ? "paused" : "playing"; } catch (_) {}
  }
  if (typeof nativeSetAction === "function") {
    const proto = Object.getPrototypeOf(mediaSession);
    const wrappedSetAction = function(action, handler) {
      if (this !== mediaSession || !["play", "pause"].includes(action))
        return nativeSetAction.call(this, action, handler);
      return nativeSetAction.call(this, action, details => {
        if (!remoteAction(action) && typeof handler === "function") handler(details);
      });
    };
    try {
      // Preserve wrapping when YouTube registers/replaces its own callbacks.
      Object.defineProperty(proto, "setActionHandler", { value: wrappedSetAction, configurable: true, writable: true });
      wrappedSetAction.call(mediaSession, "play", null);
      wrappedSetAction.call(mediaSession, "pause", null);
      for (const event of ["playing", "pause", "ended", "loadedmetadata"])
        window.addEventListener(event, updateMediaState, true);
    } catch (_) { lastStatus = "media-session-unavailable"; }
  }

  // Real presentation events MUST reach the website. Blocking the exit notification
  // in V4 left YouTube's 'playing in PiP' placeholder behind after the system returned.
  const presentationChanged = e => {
    const v = e.target;
    if (v?.tagName !== "VIDEO" || v !== pick()) return;
    const leavingPiP = !isPiP(v) && lastPiPVideo === v;
    if (isPiP(v) && lastPiPVideo !== v) {
      pipOrigin = lastMode;
      if (!platform && (pageFullscreen() || pageFullscreenAt === Infinity || Date.now() - pageFullscreenAt < 2500)) pipOrigin = "fullscreen";
    }
    lastPiPVideo = isPiP(v) ? v : null;
    lastMode = isPiP(v) ? "picture-in-picture" : (v.webkitPresentationMode || "inline");
    if (isPiP(v)) {
      requestUntil = 0;
      lastStatus = "system-pip-active";
      if (fallbackRoot) fallbackRoot.hidden = true;
    } else if (leavingPiP) {
      lastStatus = "system-pip-returned";
      systemHandoff = false; handoffUntil = 0; externalRequestUntil = 0; requestUntil = 0;
      returnWantsPlay = (desiredPlaying || (config.keepPlaying && !userPause)) && !interrupted && !v.ended;
      returnUntil = Date.now() + (config.keepPlaying ? 3000 : 1500); returnRecoveryUsed = false;
      recoverReturn();
    } else { lastStatus = "system-fullscreen-exit"; }
    document.dispatchEvent(new Event("joetoep-presentation-state"));
  };
  for (const name of ["webkitpresentationmodechanged", "enterpictureinpicture", "leavepictureinpicture"])
    window.addEventListener(name, presentationChanged, true);

  function recoverReturn() {
    const v = pick();
    if (!config.protect || !v || isPiP(v) || rawVisibility() !== "visible" ||
        !returnWantsPlay || userPause || interrupted || v.ended || Date.now() >= returnUntil || returnRecoveryUsed) return;
    if (v.paused) {
      returnRecoveryUsed = true;
      native.play.call(v)?.catch(() => { lastStatus = "return-resume-declined"; });
    }
  }

  // Fullscreen teardown events can arrive AFTER PiP begins. Do not let the site
  // tear down the same video during that transition. Native controls are untouched.
  window.addEventListener("webkitendfullscreen", e => {
    if (e.target !== pick() || !isPiP(e.target) || !protectedNow(e.target)) return;
    document.dispatchEvent(new Event("joetoep-presentation-state"));
    e.stopImmediatePropagation();
  }, true);

  const enterPiP = () => {
    const v = pick();
    if (!v || v.readyState < 1 || !v.videoWidth) return { status: "not-ready" };
    if (isPiP(v)) return { status: "active" };
    if (Date.now() < requestUntil) return { status: "requested" };
    requestUntil = Date.now() + 1800;
    handoffUntil = Math.max(handoffUntil, Date.now() + handoffDuration);
    try {
      v.removeAttribute("disablepictureinpicture");
      if (!platform && typeof v.requestPictureInPicture === "function" && document.pictureInPictureEnabled !== false) {
        v.requestPictureInPicture().catch(error => { requestUntil = 0; lastStatus = "declined: " + error.name; signal(); });
      } else if (typeof native.presentation === "function" && v.webkitSupportsPresentationMode?.("picture-in-picture")) {
        native.presentation.call(v, "picture-in-picture");
      } else if (typeof v.requestPictureInPicture === "function") {
        v.requestPictureInPicture().catch(error => { requestUntil = 0; lastStatus = "declined: " + error.name; signal(); });
      } else { requestUntil = 0; return { status: "unavailable" }; }
      signal();
      return { status: isPiP(v) ? "active" : "requested" };
    } catch (error) { requestUntil = 0; lastStatus = "declined: " + error.name; return { status: "rejected", message: error.message }; }
  };
  function youtubeFullscreen(v, direct = false) {
    // V15: a stale .ytp-fullscreen class after PiP made this return without entering fullscreen.
    if (pageFullscreen()) return true;
    const button = document.querySelector('.ytp-fullscreen-button');
    if (button && !direct) { button.click(); return true; }
    try {
      const player=document.querySelector('#movie_player') || v;
      if(player.requestFullscreen){player.requestFullscreen().catch(()=>{lastStatus="fullscreen-declined";signal();});return true;}
    } catch (_) {}
    return false;
  }
  const fullscreen = () => {
    const v = pick();
    if (!v || v.readyState < 1) return false;
    if (isPiP(v)) {
      if (!platform || nativeActive || typeof native.presentation !== "function") return false;
      // A stale or active WebKit PiP must never make fullscreen unreachable.
      try { native.presentation.call(v, "fullscreen"); return true; } catch (_) { return false; }
    }
    if (!platform) {
      if(config.macFullscreen !== "youtube" && window.JoeToepStage?.enter()) {
        document.dispatchEvent(new Event("joetoep-enter-window-fullscreen"));return true;
      }
      return youtubeFullscreen(v);
    }
    if (config.elementFullscreen) return elementFullscreen(v);
    if (!config.nativeFullscreen) return window.JoeToepStage?.enter() || false;
    window.JoeToepStage?.exit();
    try {
      if (typeof native.fullscreen === "function") { native.fullscreen.call(v); return true; }
    } catch (_) { lastStatus="apple-fullscreen-declined";signal(); }
    return false;
  };
  // Route YouTube's container fullscreen to Apple's video fullscreen on mobile.
  if (platform) {
    if (typeof native.fullscreen === "function") {
      HTMLVideoElement.prototype.webkitEnterFullscreen = function() {
        if (config.elementFullscreen && this === pick()) { elementFullscreen(this); return; }
        if (!config.nativeFullscreen && this === pick()) {
          window.JoeToepStage?.enter(); return;
        }
        return native.fullscreen.call(this);
      };
    }
    for (const key of ["requestFullscreen", "webkitRequestFullscreen", "webkitRequestFullScreen"]) {
      const original = Element.prototype[key];
      if (typeof original !== "function") continue;
      Element.prototype[key] = function(...args) {
        const v = pick();
        if (config.elementFullscreen && v && this.contains(v) && this !== v) return original.apply(this, args);
        if (v && (this === v || this.contains(v)) && fullscreen()) {
          return key === "requestFullscreen" ? Promise.resolve() : undefined;
        }
        return original.apply(this, args);
      };
    }
    window.addEventListener("click", e => {
      if (!e.isTrusted) return;
      const button = e.target?.closest?.(".ytp-fullscreen-button, ytm-fullscreen-button-renderer, .player-control-fullscreen-icon, .player-fullscreen-button, button.fullscreen-icon, .fullscreen-icon");
      if (button && fullscreen()) { e.preventDefault(); e.stopImmediatePropagation(); }
    }, true);
  }

  window.addEventListener("pointerdown", e => {
    if (!e.isTrusted) return;
    const target = e.target;
    if (target?.closest?.(".ytp-play-button, .player-control-play-pause-icon, a[href]")) {
      allowPauseUntil = Date.now() + 800;
    }
  }, true);
  window.addEventListener("keydown", e => {
    if (e.isTrusted && [" ", "k", "K", "MediaPlayPause"].includes(e.key) &&
        !e.target?.closest?.("input, textarea, [contenteditable='true']")) allowPauseUntil = Date.now() + 800;
  }, true);
  window.addEventListener("playing", e => {
    if (e.target === pick()) { desiredPlaying = true; userPause = false; lastPauseAt = 0; }
  }, true);
  window.addEventListener("pause", e => {
    if (e.target !== pick()) return;
    lastPauseAt = Date.now();
    if (interrupted) return; // An interruption is not a user pause.
    if (isPiP(main) && Date.now() < transitionUntil && !transitionRecovered && desiredPlaying && !userPause) {
      transitionRecovered = true; lastStatus = "pip-transition-pause-recovered";
      native.play.call(main)?.catch(() => { lastStatus = "pip-transition-resume-declined"; });
      return;
    }
    if (!isPiP(main) && returnWantsPlay && Date.now() < returnUntil) {
      recoverReturn();
      if (main.paused) { desiredPlaying = false; userPause = true; }
      return;
    }
    // An OS pause during the short swipe handoff is not necessarily user intent.
    // Recover at most once, including the brief period when PiP is already visible.
    if (systemHandoff && eligible(main) && desiredPlaying && !userPause &&
        Date.now() < handoffUntil && Date.now() >= allowPauseUntil && !recoveryUsed) {
      recoveryUsed = true;
      native.play.call(main)?.catch(() => { lastStatus = "resume-declined"; });
    } else if (isPiP(main)) { desiredPlaying = false; userPause = true; }
    else if (eligible(main) && backgroundEpisode && rawVisibility() !== "visible" &&
             desiredPlaying && !userPause && Date.now() < handoffUntil && !recoveryUsed) {
      // Some OS versions pause after visibilitychange instead of before it.
      recoveryUsed = true;
      native.play.call(main)?.catch(() => { lastStatus = "resume-declined"; });
    }
  }, true);
  window.addEventListener("ended", e => {
    if (e.target === pick()) { desiredPlaying = false; handoffUntil = 0; }
  }, true);
  for (const name of ["webkitvisibilitychange", "pagehide", "freeze", "blur"]) {
    window.addEventListener(name, e => {
      if (name === "blur" && e.target !== window && e.target !== document) return;
      if (name === "pagehide" && e.persisted === false && !isPiP(pick())) return; // real unload
      const hidden = rawVisibility() !== "visible" || name === "blur";
      if (platform && hidden && shouldMaskVisibility()) e.stopImmediatePropagation();
    }, true);
  }
  window.addEventListener("visibilitychange", e => {
    const v = pick(), hidden = rawVisibility() !== "visible";
    if (!hidden) { backgroundEpisode = false; recoveryUsed = false; handoffUntil = 0; systemHandoff = false; recoverReturn(); }
    if (hidden && !backgroundEpisode) {
      backgroundEpisode = true;
      const recentSystemPause = v?.paused && lastPauseAt > 0 && Date.now() - lastPauseAt < 750;
      if (config.automatic && eligible(v) && !userPause && desiredPlaying && (!v.paused || recentSystemPause)) {
        handoffUntil = Date.now() + handoffDuration;
        systemHandoff = true;
        // Exactly one recovery for a system pause immediately before backgrounding.
        if (v.paused && !isPiP(v) && lastPauseAt > 0 && Date.now() - lastPauseAt < 750 && !recoveryUsed) {
          recoveryUsed = true;
          native.play.call(v)?.catch(() => { lastStatus = "resume-declined"; });
        }
        // Fullscreen iOS owns automatic PiP. Swift observes it before attempting rescue.
        const nativeFullscreen = platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen);
        if (!platform && !nativeFullscreen && Date.now() >= externalRequestUntil) enterPiP();
      }
    }
    if (shouldMaskVisibility()) e.stopImmediatePropagation();
    signal();
  }, true);

  function showFallback() {
    if (!config.fallback || !pick() || !document.body) return false;
    if (!fallbackRoot) {
      fallbackRoot = document.createElement("div");
      fallbackRoot.id = "joetoep-native-controls";
      fallbackRoot.style.cssText = "position:fixed;right:10px;top:10px;z-index:2147483647;gap:4px;background:#000;border-radius:10px;padding:4px;color:white";
      for (const [title, action] of [["PiP", enterPiP], ["Fullscreen", fullscreen]]) {
        const button = document.createElement("button");
        button.textContent = title; button.type = "button";
        button.style.cssText = "color:white;background:#161616;border:0;border-radius:7px;min-width:44px;min-height:44px;font:13px system-ui;padding:0 10px";
        button.addEventListener("click", e => { e.stopPropagation(); action(); });
        fallbackRoot.appendChild(button);
      }
      document.body.appendChild(fallbackRoot);
    }
    fallbackRoot.hidden = false; return true;
  }
  function prepareHandoff(system = false) {
    pick(); returnUntil = 0; returnWantsPlay = false;
    const continuing = system && systemHandoff && Date.now() < handoffUntil;
    if (!continuing) { recoveryUsed = false; handoffUntil = Date.now() + handoffDuration; }
    systemHandoff = Boolean(system); externalRequestUntil = Date.now() + 2200; return true;
  }
  function beginAutomaticHandoff() {
    const v = pick();
    if (!config.automatic || !isMediaPage() || interrupted) return { status: "skipped" };
    if (!v || v.ended || userPause || (!desiredPlaying && v.paused)) return { status: "paused" };
    if (v.paused && !(lastPauseAt && Date.now() - lastPauseAt < 750)) return { status: "paused" };
    prepareHandoff(true);
    if (isPiP(v)) return { status: "active" };
    if (platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen))
      return { status: "system-fullscreen" };
    if (nativeOwner) return { status: "native-owner" };
    // iOS cannot start an inline PiP once the scene deactivates (AVKit refuses; WebKit only
    // prepares automatic PiP in fullscreen). A futile request flashed PiP and hitched audio.
    if (platform) return { status: "inline-background" };
    return enterPiP();
  }
  const isURLSource = v => Boolean(v?.currentSrc && !v.currentSrc.startsWith("blob:") && /^https?:/.test(v.currentSrc));
  function sourceInfo() {
    const v = pick();
    if (!v) return { status: "none" };
    return { status: "ok", url: isURLSource(v) ? v.currentSrc : null, blob: Boolean(v.currentSrc?.startsWith("blob:")),
      time: v.currentTime || 0, playing: !v.paused && !v.ended, userPause, ended: v.ended,
      fullscreen: Boolean(platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen)),
      pip: isPiP(v), media: isMediaPage(), ready: v.readyState, width: v.videoWidth || 0,
      wireless: Boolean(v.webkitCurrentPlaybackTargetIsWireless), ua: navigator.userAgent };
  }
  // Native presenter became audible: silence the web video without recording user intent.
  function nativeHandoff() {
    const v = pick();
    nativeActive = true; handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
    if (!v) return { status: "none" };
    const wasPlaying = !v.paused && !v.ended;
    if (wasPlaying) native.pause.call(v);
    lastStatus = "native-pip-handoff"; signal();
    return { status: "paused", wasPlaying, time: v.currentTime || 0 };
  }
  // Native PiP ended: continue the same web video exactly where PiP was.
  function nativeReturn(time, play, restore) {
    const v = pick();
    nativeActive = false;
    if (!v) return { status: "none" };
    try { if (Number.isFinite(time) && time >= 0 && Math.abs((v.currentTime || 0) - time) > 0.3) v.currentTime = time; } catch (_) {}
    if (play) {
      userPause = false; desiredPlaying = true;
      native.play.call(v)?.catch(() => { lastStatus = "native-return-play-declined"; signal(); });
    } else { desiredPlaying = false; userPause = true; }
    lastStatus = restore ? "native-pip-restored" : "native-pip-closed"; signal();
    return { status: "ok" };
  }
  function returnToApp(fullscreenReturn = false) {
    const v = pick();
    if (!v) return false;
    if (!isPiP(v)) { recoverReturn(); return true; }
    returnWantsPlay = (desiredPlaying || (config.keepPlaying && !userPause)) && !v.ended && !interrupted;
    returnUntil = Date.now() + (config.keepPlaying ? 3000 : 1500); returnRecoveryUsed = false;
    handoffUntil = 0; systemHandoff = false; externalRequestUntil = 0;
    try {
      // iOS: the standard exitPictureInPicture() always lands inline first, which produced the
      // visible fullscreen -> small -> fullscreen sequence. Go PiP -> fullscreen in one step.
      const toFullscreen = platform && config.nativeFullscreen && native.presentation && config.returnTarget !== "inline" &&
        (fullscreenReturn === "origin" ? wantsFullscreenReturn() : fullscreenReturn === true);
      if (toFullscreen) native.presentation.call(v, "fullscreen");
      else if (document.pictureInPictureElement && native.exitPiP)
        native.exitPiP.call(document)?.catch(() => { lastStatus = "return-declined"; });
      else if (native.presentation) native.presentation.call(v, "inline");
      return true;
    } catch (_) { lastStatus = "return-declined"; return false; }
  }
  Object.defineProperty(window, "JoeToepMedia", { value: Object.freeze({
    configure(next) { config = { ...config, ...next }; if (!config.fallback && fallbackRoot) fallbackRoot.hidden = true; return true; },
    prepareHandoff, beginAutomaticHandoff, returnToApp, remoteAction, sourceInfo, nativeHandoff, nativeReturn,
    // Record explicit user intent when the site's own player performs the action.
    noteIntent(action) {
      handoffUntil = 0; systemHandoff = false; returnWantsPlay = false; recoveryUsed = true; returnRecoveryUsed = true;
      if (action === "pause") { userPause = true; desiredPlaying = false; allowPauseUntil = Date.now() + 1200; }
      else { userPause = false; desiredPlaying = true; }
      return true;
    },
    // V12: rotating back to portrait leaves fullscreen and keeps the same video playing inline.
    exitFullscreenKeepPlaying() {
      const v = pick();
      if (!v || isPiP(v)) return false;
      const wasPlaying = !v.paused && !v.ended;
      try {
        if (document.fullscreenElement || document.webkitFullscreenElement) (document.exitFullscreen || document.webkitExitFullscreen)?.call(document)?.catch?.(() => {});
        else if (v.webkitDisplayingFullscreen || v.webkitPresentationMode === "fullscreen") v.webkitExitFullscreen?.();
        else return false;
      } catch (_) { return false; }
      if (wasPlaying) {
        returnWantsPlay = true; returnUntil = Date.now() + 2000; returnRecoveryUsed = false; desiredPlaying = true; userPause = false;
        setTimeout(() => { const now = pick(); if (now === v && v.paused && !userPause && !interrupted) native.play.call(v)?.catch(() => {}); }, 450);
      }
      return true;
    },
    platformTransition() { transitionUntil = Date.now() + 2500; transitionRecovered = false; return true; },
    setNativeOwner(value) { nativeOwner = Boolean(value); if (!nativeOwner) nativeActive = false; return nativeOwner; },
    showVideoAirPlay() {
      const v = pick();
      if (!v || v.readyState < 1) return "not-ready";
      v.removeAttribute("disableremoteplayback");
      v.disableRemotePlayback = false;
      v.webkitWirelessVideoPlaybackDisabled = false;
      v.setAttribute("x-webkit-airplay", "allow");
      try {
        if (typeof v.webkitShowPlaybackTargetPicker !== "function") return "unavailable";
        v.webkitShowPlaybackTargetPicker(); return "requested";
      } catch (_) { return "unavailable"; }
    },
    resetPiP() {
      requestUntil = handoffUntil = externalRequestUntil = returnUntil = 0;
      systemHandoff = false; recoveryUsed = false; returnWantsPlay = false;
      const v = pick();
      if (!v) return "not-ready";
      if (isPiP(v)) { returnToApp(false); return "exiting"; }
      return "ready";
    },
    actualPresentation() { const v = pick(); return isPiP(v) ? "picture-in-picture" : v?.webkitPresentationMode || "inline"; },
    cancelHandoff() { requestUntil = 0; handoffUntil = 0; externalRequestUntil = 0; systemHandoff = false; return true; },
    setInterrupted(value, canResume = false) {
      const v = pick();
      if (value) {
        if (!interrupted) interruptionWantsPlay = Boolean(v && desiredPlaying && !userPause && !v.ended);
        interrupted = true; handoffUntil = 0;
      } else {
        const resume = interrupted && canResume && interruptionWantsPlay && !userPause && v && !v.ended;
        interrupted = false; interruptionWantsPlay = false;
        if (resume) {
          desiredPlaying = true;
          native.play.call(v)?.catch(() => { lastStatus = "interruption-resume-declined"; signal(); });
        }
      }
      updateMediaState(); signal();
    },
    allowExit() { allowPauseUntil = Date.now() + 1200; handoffUntil = 0; systemHandoff = false; returnWantsPlay = false; },
    enterPiP, fullscreen, showFallback,
    leaveForNavigation() {
      const v = pick();
      allowPauseUntil = Date.now() + 1200;
      handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
      desiredPlaying = false; userPause = true;
      window.JoeToepStage?.exit();
      returnToApp();
      try {
        if (v && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen)) v.webkitExitFullscreen?.();
        if (document.fullscreenElement) document.exitFullscreen?.()?.catch(() => {});
      } catch (_) {}
      return true;
    },
    restoreFullscreen(retry = false) {
      const v = pick();
      if (!v || isPiP(v) || v.readyState < 1) return false;
      if (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen) return true;
      if (!wantsFullscreenReturn()) return false; // e.g. inline PiP with "where PiP started"
      if (!platform && config.macFullscreen === "youtube") {
        if (pageFullscreen()) return true;
        // Retry: request the player element directly (the button may be mid-transition).
        return youtubeFullscreen(v, retry);
      }
      return fullscreen();
    },
    diagnostics: () => {
      const v = pick();
      return { status: lastStatus, mediaSessionAvailable: typeof nativeSetAction === "function", interrupted, rawVisibility: rawVisibility(), recoveryUsed, platform,
          pipOrigin, lastMode, nativeOwner, nativeActive, systemHandoff, requestPending: Date.now() < requestUntil, desiredPlaying, userPause, interruptionWantsPlay, protectedHandoff: Date.now() < handoffUntil,
        videoConnected: Boolean(v?.isConnected), paused: v?.paused, readyState: v?.readyState,
        width: v?.videoWidth, height: v?.videoHeight, time: v?.currentTime,
        mode: v?.webkitPresentationMode || "unknown",
        standardPiP: typeof v?.requestPictureInPicture === "function",
        standardEnabled: document.pictureInPictureEnabled,
        prefixedPiP: Boolean(v?.webkitSupportsPresentationMode?.("picture-in-picture")),
        sourceKind: v?.currentSrc?.startsWith("blob:") ? "MediaSource/blob" : v?.currentSrc ? "URL" : "none" };
    }
  }), configurable: false, writable: false });
})();
