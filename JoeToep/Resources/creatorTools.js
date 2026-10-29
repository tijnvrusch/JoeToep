/* JoeToep V17 — Creator tools voor muziek, DJ en design (werkt op elke site met een <video>/<audio>).
 *  • Afspeelsnelheid 0.25×–4× met of zonder toonhoogte-behoud ("keep pitch"): handig om een
 *    solo, drop of dansstap langzamer te bestuderen, of om een track in een andere toonhoogte te horen.
 *  • A-B-loop: herhaal een stukje (bijv. 4 maten) eindeloos om te oefenen of te analyseren.
 *  • Frame-stap: 1 beeldje (1/30 s) voor- of achteruit, voor animatie/design-studie.
 *  • Tap tempo (BPM) doet de app zelf; dit script levert de huidige tijd voor cue-punten.
 * De app praat met `window.JoeToepCreator`.
 */
(() => {
  "use strict";
  if (window.JoeToepCreator) return;
  // De hoofdvideo (of audio): de spelende, anders de grootste.
  const media = () => {
    const all = [...document.querySelectorAll("video, audio")];
    return all.find(m => !m.paused) || all.sort((a, b) => (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight))[0] || null;
  };
  let loop = null;                 // {a: seconden, b: seconden} of null
  // Bij elke tijd-update: voorbij punt B? Terug naar A. (timeupdate komt ~4× per seconde.)
  const onTime = e => {
    const m = e.target;
    if (!loop || m !== media()) return;
    if (m.currentTime >= loop.b || m.currentTime < loop.a - 0.25) m.currentTime = loop.a;
  };
  window.addEventListener("timeupdate", onTime, true);

  window.JoeToepCreator = Object.freeze({
    // Snelheid instellen. `keepPitch` true = stem/toon blijft gelijk (tijdrek), false = als een plaat.
    setRate(rate, keepPitch) {
      const m = media(); if (!m) return "no-media";
      const r = Math.min(4, Math.max(0.25, Number(rate) || 1));
      m.preservesPitch = m.webkitPreservesPitch = Boolean(keepPitch);
      m.playbackRate = r;
      m.defaultPlaybackRate = r;
      return r;
    },
    // A-B-loop zetten (in seconden). Leeg laten = huidige tijd gebruiken.
    setLoopPoint(which) {
      const m = media(); if (!m) return "no-media";
      loop = loop || { a: 0, b: m.duration || 0 };
      loop[which] = m.currentTime;
      if (loop.b <= loop.a) loop.b = Math.min(m.duration || loop.a + 4, loop.a + 4);   // B altijd na A
      return loop;
    },
    clearLoop() { loop = null; return true; },
    // Stap vooruit/achteruit: `frames` beeldjes van 1/30 seconde. Pauzeert eerst.
    step(frames) {
      const m = media(); if (!m) return "no-media";
      m.pause();
      m.currentTime = Math.max(0, m.currentTime + frames / 30);
      return m.currentTime;
    },
    seek(seconds) { const m = media(); if (m) m.currentTime = Math.max(0, seconds); return Boolean(m); },
    // Alle video's op deze pagina (on)dempen: "tab dempen".
    mute(on) { document.querySelectorAll("video, audio").forEach(m => { m.muted = Boolean(on); }); return Boolean(on); },
    state() {
      const m = media();
      return m ? { time: m.currentTime, duration: m.duration || 0, rate: m.playbackRate,
        keepPitch: m.preservesPitch !== false, loop, paused: m.paused, muted: m.muted } : { none: true };
    }
  });
})();
