/* JoeToep V17 — Picture in Picture voor ELKE website (niet-YouTube).
 * YouTube heeft zijn eigen, veel uitgebreidere script (mediaCompatibility.js). Op alle andere
 * sites (Vimeo, Twitch, nieuwssites, Netflix-achtige spelers, <video> in iframes van dezelfde site …)
 * zorgt dit script ervoor dat de PiP-knop van JoeToep werkt:
 *  • het kiest de "beste" video: die speelt, of anders de grootste zichtbare;
 *  • het haalt blokkades weg (`disablePictureInPicture`, `disableremoteplayback`);
 *  • het gebruikt de standaard-API (requestPictureInPicture) of Apple's variant
 *    (webkitSetPresentationMode) — welke de browser ondersteunt.
 * De app roept `window.JoeToepWebPiP.toggle()` aan en leest `state()` voor de knop.
 */
(() => {
  "use strict";
  const host = location.hostname.toLowerCase();
  // YouTube wordt door mediaCompatibility.js geregeld.
  if (host === "youtube.com" || host.endsWith(".youtube.com") || window.JoeToepWebPiP) return;

  // Verzamelt alle <video>-elementen, ook in iframes van dezelfde site en in shadow DOM.
  function allVideos(root = document, out = []) {
    root.querySelectorAll("video").forEach(v => out.push(v));
    root.querySelectorAll("*").forEach(el => { if (el.shadowRoot) allVideos(el.shadowRoot, out); });
    root.querySelectorAll("iframe").forEach(f => { try { if (f.contentDocument) allVideos(f.contentDocument, out); } catch (_) { /* andere site: geen toegang */ } });
    return out;
  }
  // Punten voor een video: spelend telt het zwaarst, daarna het oppervlak op het scherm.
  const score = v => {
    const r = v.getBoundingClientRect();
    const area = Math.max(0, r.width) * Math.max(0, r.height);
    return (v.paused ? 0 : 1e9) + (v.readyState >= 2 ? 1e8 : 0) + area;
  };
  const best = () => allVideos().filter(v => v.readyState > 0 || !v.paused).sort((a, b) => score(b) - score(a))[0] || null;
  const inPiP = v => Boolean(v && (document.pictureInPictureElement === v || v.webkitPresentationMode === "picture-in-picture" ||
    v.ownerDocument?.pictureInPictureElement === v));
  // Haalt blokkades weg die sites soms zetten om PiP te verbieden.
  function unlock(v) {
    v.disablePictureInPicture = false;
    v.removeAttribute("disablepictureinpicture");
    v.removeAttribute("disableremoteplayback");
    v.setAttribute("playsinline", "");
  }
  // Start PiP voor video `v`. Geeft een belofte (Promise) terug; fouten worden gemeld, niet gegooid.
  async function enter(v) {
    unlock(v);
    try {
      if (typeof v.requestPictureInPicture === "function") { await v.requestPictureInPicture(); return "active"; }
      if (v.webkitSupportsPresentationMode?.("picture-in-picture")) { v.webkitSetPresentationMode("picture-in-picture"); return "active"; }
      return "unsupported";
    } catch (e) { return "failed: " + (e?.message || e); }
  }
  async function exit(v) {
    try {
      const doc = v?.ownerDocument || document;
      if (doc.pictureInPictureElement) { await doc.exitPictureInPicture(); return "inline"; }
      if (v?.webkitPresentationMode === "picture-in-picture") { v.webkitSetPresentationMode("inline"); return "inline"; }
    } catch (_) {}
    return "inline";
  }
  // De API waar de app mee praat. `Object.freeze` = de site kan hem niet aanpassen.
  window.JoeToepWebPiP = Object.freeze({
    // Aan/uit: staat er een video in PiP → terug; anders de beste video in PiP.
    async toggle() {
      const current = allVideos().find(inPiP);
      if (current) return exit(current);
      const v = best();
      if (!v) return "no-video";
      return enter(v);
    },
    // Voor tab-wissel: alleen starten als er echt een video SPEELT.
    async enterIfPlaying() {
      const v = best();
      if (!v || v.paused || inPiP(v)) return "skipped";
      return enter(v);
    },
    // Pauzeert alle video's op de pagina (overdracht naar een andere tab) en sluit PiP.
    async pauseAll() {
      for (const v of allVideos()) { try { v.pause(); } catch (_) {} if (inPiP(v)) await exit(v); }
      return "paused";
    },
    state() { const v = best(); return { video: Boolean(v), playing: Boolean(v && !v.paused), pip: allVideos().some(inPiP) }; }
  });
})();
