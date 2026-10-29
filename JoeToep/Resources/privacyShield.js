/* JoeToep V17 — privacyschild voor ELKE website.
 *  • Global Privacy Control: `navigator.globalPrivacyControl = true` vertelt sites (wettelijk
 *    erkend in o.a. Californië, en gerespecteerd door veel EU-sites) dat je niet gevolgd wilt worden.
 *  • Volg-parameters (utm_…, fbclid, gclid, YouTube-`si` …) worden uit links gehaald vóór je klikt,
 *    en uit het adres van de huidige pagina (zonder de pagina te herladen).
 *  • Bekende volg-scripts/pixels worden tegengehouden als ze via JavaScript worden toegevoegd.
 * De app zet vooraf: window.JOETOEP_PRIVACY = {gpc:true, strip:true, trackers:true}.
 */
(() => {
  "use strict";
  const cfg = window.JOETOEP_PRIVACY || { gpc: true, strip: true, trackers: true };
  if (window.__joetoepPrivacy) return;           // niet twee keer installeren
  window.__joetoepPrivacy = true;

  // ── Global Privacy Control ─────────────────────────────────────────────────────────
  if (cfg.gpc) {
    try {
      // `defineProperty` maakt een eigenschap die de site kan lezen maar niet kan veranderen.
      Object.defineProperty(Navigator.prototype, "globalPrivacyControl", { get: () => true, configurable: true });
      Object.defineProperty(Navigator.prototype, "doNotTrack", { get: () => "1", configurable: true });
    } catch (_) {}
  }

  // ── Volg-parameters uit URL's halen ────────────────────────────────────────────────
  const exact = new Set(["fbclid","gclid","dclid","gbraid","wbraid","msclkid","yclid","twclid","ttclid","igshid","igsh",
    "mc_eid","mc_cid","_hsenc","_hsmi","mkt_tok","ref_src","ref_url","si","pp","spm","vero_id","__s","s_cid"]);
  const prefixes = ["utm_", "hsa_", "pk_", "mtm_"];
  // Geeft de schone URL-tekst terug, of null als er niets te verwijderen viel.
  function clean(href) {
    let url;
    try { url = new URL(href, location.href); } catch (_) { return null; }   // ongeldige link
    if (!/^https?:$/.test(url.protocol)) return null;                         // alleen web-links
    let changed = false;
    for (const key of [...url.searchParams.keys()]) {
      const k = key.toLowerCase();
      if (exact.has(k) || prefixes.some(p => k.startsWith(p))) { url.searchParams.delete(key); changed = true; }
    }
    return changed ? url.toString() : null;
  }
  if (cfg.strip) {
    // 1) Het adres van de pagina zelf: vervangen in de geschiedenis (geen herladen, geen flits).
    const own = clean(location.href);
    if (own) try { history.replaceState(history.state, "", own); } catch (_) {}
    // 2) Links: net vóór een klik (pointerdown) de link opschonen. `true` = vóór de site zelf.
    const scrub = e => {
      const a = e.target?.closest?.("a[href]");
      if (!a) return;
      const cleaned = clean(a.href);
      if (cleaned) a.href = cleaned;
    };
    window.addEventListener("pointerdown", scrub, true);
    window.addEventListener("auxclick", scrub, true);      // middelklik
    window.addEventListener("contextmenu", scrub, true);   // rechtsklik → "Kopieer link" is dan ook schoon
  }

  // ── Volg-scripts tegenhouden ───────────────────────────────────────────────────────
  if (cfg.trackers) {
    // Domeinen die alleen dienen voor tracking/analytics/advertentiepixels (geen inhoud!).
    const blocked = /(^|\.)(google-analytics\.com|googletagmanager\.com|doubleclick\.net|facebook\.net|connect\.facebook\.net|hotjar\.com|clarity\.ms|scorecardresearch\.com|quantserve\.com|criteo\.(com|net)|taboola\.com|outbrain\.com|adnxs\.com|amazon-adsystem\.com|bat\.bing\.com|analytics\.tiktok\.com|snap\.licdn\.com|px\.ads\.linkedin\.com|mixpanel\.com|segment\.(io|com)|fullstory\.com|mouseflow\.com|newrelic\.com|nr-data\.net|chartbeat\.(com|net)|parsely\.com)$/i;
    const isBlocked = src => { try { return blocked.test(new URL(src, location.href).hostname); } catch (_) { return false; } };
    // Scripts en pixel-plaatjes die de pagina toevoegt, onderscheppen we vóór ze laden.
    const originalAppend = Element.prototype.appendChild;
    const originalInsert = Element.prototype.insertBefore;
    const guard = node => (node?.tagName === "SCRIPT" || node?.tagName === "IMG" || node?.tagName === "IFRAME") && node.src && isBlocked(node.src);
    Element.prototype.appendChild = function (node) { return guard(node) ? node : originalAppend.call(this, node); };
    Element.prototype.insertBefore = function (node, ref) { return guard(node) ? node : originalInsert.call(this, node, ref); };
    // "Beacons" (stille meldingen bij het verlaten van een pagina) naar trackers: negeren.
    const originalBeacon = navigator.sendBeacon?.bind(navigator);
    if (originalBeacon) navigator.sendBeacon = (url, data) => isBlocked(url) ? true : originalBeacon(url, data);
  }
})();
