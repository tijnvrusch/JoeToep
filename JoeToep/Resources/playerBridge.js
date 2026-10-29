// Deze IIFE ("(() => { ... })()", een functie die zichzelf meteen aanroept) houdt de brug
// tussen de webpagina en de native (Swift) app in stand: hij houdt de video's in de gaten
// en stuurt statusupdates ("events") naar de app, en ontvangt opdrachten terug (PiP starten,
// fullscreen, enz.) via window.JoeToepBridge.
(() => {
  // "use strict": strenger JavaScript, fouten (zoals een typefout in een variabelenaam)
  // vallen meteen op in plaats van stil te falen.
  "use strict";
  // Voorkom dat dit script twee keer wordt geïnstalleerd.
  if (window.JoeToepBridge) return;
  // Een uniek ID voor dit documentbezoek: tijdstip + een willekeurig staartje, zodat de
  // native app berichten van verschillende pagina's/tabbladen uit elkaar kan houden.
  const documentID = String(Date.now()) + "-" + Math.random().toString(36).slice(2);
  // WeakSet/WeakMap onthouden welke video-elementen we al "gezien" hebben en info erover,
  // zonder te voorkomen dat de browser die elementen mag opruimen als ze uit de pagina gaan
  // ("weak" = geen geheugenlek).
  const observed = new WeakSet();
  const ids = new WeakMap();
  const originalStyle = new WeakMap();
  const legacyFullscreen = new WeakSet();
  // Gedeelde toestand: het laatste ID-nummer dat we uitgedeeld hebben, de actieve video,
  // de laatst verstuurde status (om dubbele berichten te voorkomen), enz.
  let serial = 0, active = null, lastSnapshot = "", requestToken = null, zoom = 1;
  let options = { fit: "fit", pinch: "video" };
  let gesture = null;
  // Stuurt een bericht naar de native (Swift) app via WebKit's message-handler-systeem.
  // "?." (optional chaining) zorgt dat dit stil faalt (in plaats van een foutmelding) als
  // die brug er niet is, bijvoorbeeld in een gewone browser tijdens het testen.
  const emit = (event, detail = {}) => {
    try { window.webkit?.messageHandlers?.joeToep?.postMessage({ event, documentID, ...detail }); }
    catch (_) { /* A detached document has no live native recipient. */ }
  };
  // Is deze video op dit moment in Picture-in-Picture?
  const isPiP = video => Boolean(video && (
    video.webkitPresentationMode === "picture-in-picture" || document.pictureInPictureElement === video
  ));
  // Is deze video in fullscreen (en dus NIET in PiP)? Kijkt zowel naar de moderne
  // Fullscreen-API als naar de oudere webkit-manier (legacyFullscreen).
  const isFullscreen = video => Boolean(video && !isPiP(video) && (
    video.webkitPresentationMode === "fullscreen" || legacyFullscreen.has(video) ||
    document.fullscreenElement === video || document.fullscreenElement?.contains?.(video)
  ));
  // Kiest, van alle <video>-elementen op de pagina, degene die het meest waarschijnlijk
  // "de" video is waar de gebruiker naar kijkt: als er al een actieve video in PiP staat,
  // blijf daarbij; anders geef punten (score) aan elke video en kies de hoogste score.
  const chooseVideo = () => {
    if (active?.isConnected && isPiP(active)) return active;
    // Array.from(...) zet de resultaten van querySelectorAll (geen "echte" array) om in
    // een gewone array, zodat we ermee kunnen filteren/sorteren.
    const videos = Array.from(document.querySelectorAll("video")).filter(v => v.isConnected !== false);
    // Een hoger getal = waarschijnlijker de hoofdvideo: YouTube's eigen hoofdvideo-klasse
    // telt het zwaarst, daarna of hij speelt, daarna hoe groot hij op het scherm is.
    const score = v => {
      const r = v.getBoundingClientRect();
      return (v.classList?.contains("html5-main-video") ? 1e12 : 0) +
        (!v.paused && !v.ended ? 1e10 : 0) + Math.max(0, r.width) * Math.max(0, r.height);
    };
    videos.sort((a, b) => score(b) - score(a));
    return videos[0] || null;
  };
  // Onthoudt hoe de video's CSS-stijl (object-fit/transform) er origineel uitzag, zodat we
  // die later precies kunnen terugzetten. Doet niets als we dat al eerder onthouden hebben.
  const rememberStyle = video => {
    if (originalStyle.has(video)) return;
    const values = {};
    for (const key of ["object-fit", "transform", "transform-origin"]) {
      values[key] = [video.style.getPropertyValue(key), video.style.getPropertyPriority(key)];
    }
    originalStyle.set(video, values);
  };
  // Zet één CSS-eigenschap terug naar de onthouden originele waarde (of verwijdert hem
  // helemaal als er origineel niets stond).
  const restoreProperty = (video, property) => {
    const [value, priority] = originalStyle.get(video)?.[property] || ["", ""];
    if (value) {
      if (video.style.getPropertyValue(property) !== value || video.style.getPropertyPriority(property) !== priority)
        video.style.setProperty(property, value, priority);
    } else if (video.style.getPropertyValue(property)) video.style.removeProperty(property);
  };
  // Past de zoom/opvulstijl van de video toe (of zet hem terug), afhankelijk van de
  // huidige presentatiemodus en de door de gebruiker gekozen instellingen (fit/pinch-zoom).
  const applyVisuals = video => {
    if (!video) return;
    if (isPiP(video) || isFullscreen(video) || document.documentElement?.hasAttribute?.("data-joetoep-stage")) {
      if (originalStyle.has(video)) {
        for (const key of ["object-fit", "transform", "transform-origin"]) restoreProperty(video, key);
      }
      return;
    }
    // V16 (iPad): no inline styles at all in the default "fit" mode without zoom. Toggling
    // object-fit around PiP/fullscreen made the PiP window start zoomed in, and fullscreen too small.
    if (options.fit !== "fill" && zoom === 1) {
      if (originalStyle.has(video)) for (const key of ["object-fit", "transform", "transform-origin"]) restoreProperty(video, key);
      return;
    }
    rememberStyle(video);
    video.style.setProperty("object-fit", options.fit === "fill" ? "cover" : "contain", "important");
    if (zoom === 1) {
      restoreProperty(video, "transform"); restoreProperty(video, "transform-origin");
    } else {
      video.style.setProperty("transform", "scale(" + zoom.toFixed(3) + ")", "important");
      video.style.setProperty("transform-origin", "center center", "important");
    }
  };
  const snapshot = () => {
    const next = chooseVideo();
    if (active !== next) {
      if (active && originalStyle.has(active) && !isPiP(active)) {
        for (const key of ["object-fit", "transform", "transform-origin"]) restoreProperty(active, key);
      }
      active = next;
      zoom = 1; gesture = null;
    }
    if (active) attach(active);
    const result = {
      videoID: active ? ids.get(active) : 0,
      playing: Boolean(active && !active.paused && !active.ended),
      buffering: Boolean(active && !active.paused && active.readyState < 3),
      fullscreen: isFullscreen(active),
      stage: Boolean(active && document.documentElement?.hasAttribute?.("data-joetoep-stage")),
      pip: isPiP(active),
      width: Math.max(0, Number(active?.videoWidth || 0)),
      height: Math.max(0, Number(active?.videoHeight || 0))
    };
    if (result.pip) requestToken = null;
    return result;
  };
  const report = () => {
    const state = snapshot();
    const encoded = JSON.stringify(state);
    if (encoded !== lastSnapshot) { lastSnapshot = encoded; emit("state", state); }
  };
  const distance = touches => Math.hypot(touches[0].clientX - touches[1].clientX, touches[0].clientY - touches[1].clientY);
  function attach(video) {
    if (!video || observed.has(video)) return;
    observed.add(video); ids.set(video, ++serial);
    const changed = () => { report(); if (video === active) applyVisuals(video); };
    for (const event of ["play", "playing", "pause", "waiting", "canplay", "ended", "emptied",
      "loadedmetadata", "resize", "enterpictureinpicture", "leavepictureinpicture"]) {
      video.addEventListener(event, changed, { passive: true });
    }
    video.addEventListener("webkitpresentationmodechanged", () => {
      if (video.webkitPresentationMode !== "fullscreen") legacyFullscreen.delete(video);
      changed();
    }, { passive: true });
    video.addEventListener("webkitbeginfullscreen", () => { legacyFullscreen.add(video); changed(); }, { passive: true });
    video.addEventListener("webkitendfullscreen", () => { legacyFullscreen.delete(video); changed(); }, { passive: true });
    video.addEventListener("touchstart", e => {
      if (options.pinch !== "video" || e.touches.length !== 2 || video !== chooseVideo() || isPiP(video)) return;
      const d = distance(e.touches);
      if (d > 0) gesture = { distance: d, zoom, video };
    }, { passive: true });
    video.addEventListener("touchmove", e => {
      if (!gesture || gesture.video !== video || options.pinch !== "video" || e.touches.length !== 2) return;
      e.preventDefault();
      zoom = Math.max(1, Math.min(3, gesture.zoom * distance(e.touches) / gesture.distance));
      applyVisuals(video);
    }, { passive: false });
    for (const event of ["touchend", "touchcancel"]) {
      video.addEventListener(event, () => { gesture = null; }, { passive: true });
    }
  }
  const scan = root => {
    const isVideo = root?.tagName === "VIDEO";
    if (isVideo) attach(root);
    const descendants = root?.querySelectorAll?.("video") || [];
    descendants.forEach(attach);
    return isVideo || descendants.length > 0;
  };
  const fail = (token, error) => {
    if (requestToken !== token) return;
    requestToken = null;
    emit("pipFailure", { token, message: String(error?.message || error).slice(0, 180) });
  };
  const requestPiP = token => {
    const state = snapshot();
    if (state.pip) { report(); return { status: "active" }; }
    if (requestToken !== null) return { status: "busy" };
    if (!active) return { status: "no-video" };
    if (active.readyState < 1 || !active.videoWidth) return { status: "not-ready" };
    const video = active;
    requestToken = token;
    try {
      // Never exit fullscreen first: doing so can invalidate the presentation handoff.
      if (typeof video.webkitSetPresentationMode === "function" &&
          typeof video.webkitSupportsPresentationMode === "function" &&
          video.webkitSupportsPresentationMode("picture-in-picture")) {
        video.webkitSetPresentationMode("picture-in-picture");
      } else if (typeof video.requestPictureInPicture === "function" && document.pictureInPictureEnabled !== false) {
        const request = video.requestPictureInPicture();
        request?.catch(error => fail(token, error));
      } else {
        requestToken = null; return { status: "unavailable" };
      }
      report();
      return { status: isPiP(video) ? "active" : "requested" };
    } catch (error) {
      requestToken = null;
      return { status: "rejected", message: String(error?.message || error).slice(0, 180) };
    }
  };
  const exitPiP = () => {
    const video = chooseVideo();
    if (!isPiP(video)) return { status: "inactive" };
    try {
      if (document.pictureInPictureElement && typeof document.exitPictureInPicture === "function") {
        document.exitPictureInPicture()?.catch(() => {});
      } else if (typeof video.webkitSetPresentationMode === "function") {
        video.webkitSetPresentationMode("inline");
      }
      return { status: "requested" };
    } catch (_) { return { status: "rejected" }; }
  };
  window.JoeToepBridge = Object.freeze({
    requestPiP, exitPiP,
    exitFullscreen: () => {
      const video = chooseVideo();
      if (isPiP(video)) return false;
      try {
        if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen()?.then(report).catch(() => {});
        else if (video?.webkitExitFullscreen) video.webkitExitFullscreen();
        else if (video?.webkitSetPresentationMode) video.webkitSetPresentationMode("inline");
        else return false;
        return true;
      } catch (_) { return false; }
    },
    enterFullscreen: () => {
      const video = chooseVideo();
      if (!video || isPiP(video)) return false;
      try {
        if (typeof video.webkitEnterFullscreen === "function") video.webkitEnterFullscreen();
        else if (typeof video.requestFullscreen === "function") video.requestFullscreen()?.catch(() => {});
        else return false;
        return true;
      } catch (_) { return false; }
    },
    cancelRequest: token => { if (requestToken === token) requestToken = null; },
    state: () => ({ ...snapshot(), documentID }),
    configure: config => {
      options = { fit: config?.fit === "fill" ? "fill" : "fit", pinch: config?.pinch || "off" };
      if (options.pinch !== "video") { gesture = null; zoom = 1; }
      snapshot(); applyVisuals(active);
      return true;
    },
    resetZoom: () => { zoom = 1; gesture = null; applyVisuals(active); return true; }
  });
  document.addEventListener("fullscreenchange", report, { passive: true });
  document.addEventListener("joetoep-stage-state", report);
  document.addEventListener("joetoep-exit-window-fullscreen", () => emit("exitWindowFullscreen"));
  document.addEventListener("joetoep-automatic-fullscreen", () => emit("automaticFullscreen"));
  document.addEventListener("joetoep-enter-window-fullscreen", () => emit("enterWindowFullscreen"));
  document.addEventListener("joetoep-window-fullscreen", () => emit("windowFullscreen"));
  document.addEventListener("webkitfullscreenchange", report, { passive: true });
  document.addEventListener("visibilitychange", report, { passive: true });
  document.addEventListener("joetoep-media-state", () => { report(); applyVisuals(active); });
  // V15: SponsorBlock skips (page world) are reported natively for the time-saved statistics.
  document.addEventListener("joetoep-sponsor-skipped", () => {
    try {
      const data = JSON.parse(document.documentElement.dataset.joetoepSponsorSkip || "{}");
      emit("sponsorSkipped", { message: String(data.category || "segment").slice(0, 40), seconds: Number(data.seconds) || 0 });
    } catch (_) {}
  });
  document.addEventListener("joetoep-presentation-state", () => {
    if (active?.webkitPresentationMode !== "fullscreen") legacyFullscreen.delete(active);
    report(); applyVisuals(active);
  });
  const observer = new MutationObserver(mutations => {
    let relevant = false;
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes || []) {
        if (scan(node)) relevant = true;
      }
      if (active && !active.isConnected) relevant = true;
    }
    if (relevant) { report(); applyVisuals(active); }
  });
  const start = () => {
    scan(document);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    emit("ready"); report(); applyVisuals(active);
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
