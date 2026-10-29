/* JoeToep's reversible, same-video fullscreen/floating fallback. No clones, stream
 * downloads, canvas capture, permanent polling or video reparenting. */
(() => {
  "use strict";
  if (!window.JoeToepMedia || window.JoeToepStage) return;
  let video = null, root = null, sheet = null, observer = null, chain = [];
  let abort = null, time = null, seek = null, play = null, dragging = false, volume = null, volumeLabel = null, hideTimer = null;
  const pip = v => v && (v.webkitPresentationMode === "picture-in-picture" || document.pictureInPictureElement === v);
  const signal = () => document?.dispatchEvent(new Event("joetoep-stage-state"));
  const pick = () => document.querySelector("video.html5-main-video") || document.querySelector("video");
  const clock = seconds => {
    if (!Number.isFinite(seconds)) return "LIVE";
    const s = Math.max(0, Math.floor(seconds));
    return (s >= 3600 ? Math.floor(s / 3600) + ":" : "") +
      (s >= 3600 ? String(Math.floor(s / 60) % 60).padStart(2, "0") : Math.floor(s / 60)) + ":" + String(s % 60).padStart(2, "0");
  };
  const bounds = () => {
    try {
      if (video.seekable.length) return [video.seekable.start(0), video.seekable.end(video.seekable.length - 1)];
    } catch (_) {}
    return Number.isFinite(video?.duration) && video.duration > 0 ? [0, video.duration] : null;
  };
  const update = () => {
    if (!video || !root) return;
    if (!video.isConnected || pip(video)) { exit(); return; }
    const range = bounds();
    seek.disabled = !range;
    if (range) {
      seek.min = range[0]; seek.max = range[1];
      if (!dragging) seek.value = Math.min(range[1], Math.max(range[0], video.currentTime));
    }
    play.textContent = video.paused ? "▶" : "❚❚";
    play.setAttribute("aria-label", video.paused ? "Play" : "Pause");
    if (volume) volume.value = video.muted ? 0 : video.volume;
    if (volumeLabel) volumeLabel.textContent = Math.round((video.muted ? 0 : video.volume) * 100) + "%";
    time.textContent = clock(video.currentTime) + " / " + clock(video.duration);
  };
  const jump = delta => {
    const range = bounds();
    if (range) video.currentTime = Math.min(range[1], Math.max(range[0], video.currentTime + delta));
    update();
  };
  function exit() {
    clearTimeout(hideTimer); hideTimer = null;
    abort?.abort(); abort = null;
    observer?.disconnect(); observer = null;
    for (const node of chain) node.removeAttribute("data-joetoep-ancestor");
    chain = [];
    video?.removeAttribute("data-joetoep-video");
    document?.documentElement?.removeAttribute("data-joetoep-stage");
    sheet?.remove(); root?.remove(); sheet = root = video = null;
    time = seek = play = volume = volumeLabel = null;
    dragging = false; signal();
    return true;
  }
  function enter() {
    const selected = pick();
    if (!selected || pip(selected) || selected.readyState < 1) return false;
    if (video === selected && root?.isConnected) return true;
    exit(); video = selected; abort = new AbortController();
    video.setAttribute("playsinline", ""); video.setAttribute("webkit-playsinline", "");
    video.setAttribute("data-joetoep-video", "");
    for (let p = video.parentElement; p; p = p.parentElement) {
      chain.push(p); p.setAttribute("data-joetoep-ancestor", "");
    }
    document.documentElement.setAttribute("data-joetoep-stage", "");
    sheet = document.createElement("style"); sheet.id = "joetoep-stage-style";
    sheet.textContent = `
      html[data-joetoep-stage],html[data-joetoep-stage] body {overflow:hidden!important;background:#000!important}
      html[data-joetoep-stage] body * {visibility:hidden!important}
      [data-joetoep-ancestor] {transform:none!important;perspective:none!important;filter:none!important;backdrop-filter:none!important;contain:none!important;clip:auto!important;clip-path:none!important;overflow:visible!important;opacity:1!important;isolation:auto!important;z-index:auto!important}
      video[data-joetoep-video] {visibility:visible!important;position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;min-width:0!important;margin:0!important;transform:none!important;object-fit:contain!important;background:#000!important;z-index:2147483645!important}
      #joetoep-stage-controls {visibility:visible!important;position:fixed!important;inset:auto 0 0!important;z-index:2147483647!important;display:block!important}
    `;
    (document.head || document.documentElement).appendChild(sheet);
    root = document.createElement("div"); root.id = "joetoep-stage-controls";
    const shadow = root.attachShadow({mode:"open"});
    const style = document.createElement("style");
    style.textContent = `:host{color-scheme:dark} .bar{display:flex;align-items:center;gap:8px;padding:8px max(8px,env(safe-area-inset-right)) max(8px,env(safe-area-inset-bottom));background:rgba(0,0,0,.88);color:#fff;font:12px system-ui} button{flex-shrink:0;min-width:40px;min-height:40px;border:0;border-radius:7px;background:#202020;color:#fff;font:14px system-ui} input{flex:1;min-width:40px;accent-color:#f00} span{font-variant-numeric:tabular-nums;white-space:nowrap} @media(max-width:450px){.bar{gap:3px}button{min-width:36px}span{font-size:10px}}`;
    shadow.appendChild(style);
    const bar = document.createElement("div"); bar.className = "bar";
    style.textContent += `.bar{flex-wrap:wrap} input[aria-label="Video progress"]{order:-1;flex:1 0 96%;width:96%;min-height:24px}.bar{transition:opacity .18s} :host([data-quiet]) .bar{opacity:0;pointer-events:none} :host(:focus-within) .bar{opacity:1;pointer-events:auto}@media(prefers-reduced-motion:reduce){.bar{transition:none}}`;
    const reveal = () => {
      root?.removeAttribute("data-quiet");clearTimeout(hideTimer);
      hideTimer=setTimeout(()=>{if(root&&!dragging)root.setAttribute("data-quiet","");},2500);
    };
    for(const event of ["pointermove","pointerdown","joetoep-controls-used"])
      document.addEventListener(event,reveal,{signal:abort.signal,passive:true});
    reveal();
    bar.setAttribute("role", "group"); bar.setAttribute("aria-label", "JoeToep video controls");
    const button = (label, text, action) => {
      const b = document.createElement("button"); b.type = "button"; b.textContent = text;
      b.setAttribute("aria-label", label); b.title = label;
      b.addEventListener("click", e => { e.stopPropagation(); action(); }, {signal:abort.signal});
      bar.appendChild(b); return b;
    };
    button("Close fullscreen", "✕", () => {
      exit(); document.dispatchEvent(new Event("joetoep-exit-window-fullscreen"));
    });
    button("Rewind 10 seconds", "−10", () => jump(-10));
    play = button("Pause", "❚❚", () => {
      if (video.paused) video.play()?.catch(() => {});
      else { window.JoeToepMedia.allowExit(); video.pause(); }
      update();
    });
    button("Forward 10 seconds", "+10", () => jump(10));
    button("Rewind 30 seconds", "−30", () => jump(-30));
    button("Forward 30 seconds", "+30", () => jump(30));
    button("Rewind 1 minute", "−60", () => jump(-60));
    button("Forward 1 minute", "+60", () => jump(60));
    seek = document.createElement("input"); seek.type = "range"; seek.step = "0.1";
    seek.setAttribute("aria-label", "Video progress");
    seek.addEventListener("input", () => { dragging = true; }, {signal:abort.signal});
    seek.addEventListener("change", () => { const range=bounds(); if(range) video.currentTime=Math.min(range[1],Math.max(range[0],Number(seek.value))); dragging=false; update(); }, {signal:abort.signal});
    bar.appendChild(seek); time=document.createElement("span"); bar.appendChild(time);
    volume = document.createElement("input"); volume.type="range";volume.min="0";volume.max="1";volume.step="0.05";
    volume.setAttribute("aria-label","Volume");volume.style.cssText="flex:0 1 110px;min-width:60px";
    volume.addEventListener("input",()=>{video.volume=Number(volume.value);video.muted=video.volume===0;update();},{signal:abort.signal});
    bar.appendChild(volume); volumeLabel=document.createElement("span");bar.appendChild(volumeLabel);
    button("Native Picture in Picture", "PiP", () => window.JoeToepMedia.enterPiP());
    if (!window.JOETOEP_MOBILE)
      button("Fullscreen window", "⛶", () => document.dispatchEvent(new Event("joetoep-window-fullscreen")));
    shadow.appendChild(bar); document.body.appendChild(root);
    for (const name of ["timeupdate","durationchange","progress","play","pause","ended","loadedmetadata","volumechange","enterpictureinpicture"])
      video.addEventListener(name, update, {signal:abort.signal,passive:true});
    document.addEventListener("joetoep-presentation-state", update, {signal:abort.signal});
    document.addEventListener("yt-navigate-start", exit, {signal:abort.signal});
    window.addEventListener("popstate", exit, {signal:abort.signal});
    window.addEventListener("pagehide", exit, {signal:abort.signal});
    window.addEventListener("keydown", e => {
      if (e.key === "Escape") { e.preventDefault(); exit(); }
    }, {signal:abort.signal,capture:true});
    observer = new MutationObserver(() => { if (!video?.isConnected || !root?.isConnected) exit(); });
    observer.observe(document.body, {childList:true,subtree:true});
    update(); signal(); return true;
  }
  Object.defineProperty(window,"JoeToepStage",{value:Object.freeze({enter,exit,active:()=>Boolean(video && root?.isConnected)})});
})();
