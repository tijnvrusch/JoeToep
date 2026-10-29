/* JoeToep V17 — automatisch cookiebanners weigeren (of verbergen), op ELKE website.
 *
 * Hoe werkt het?
 *  1. Veel sites gebruiken een standaard "consent-platform" (OneTrust, Cookiebot, Didomi,
 *     Quantcast, Usercentrics, …). Die hebben vaste knop-namen. Die lijst proberen we eerst.
 *  2. Lukt dat niet, dan zoeken we een knop waarvan de tekst "Alles weigeren", "Reject all",
 *     "Alleen noodzakelijk", … is, maar alleen binnen een blok dat over cookies/privacy gaat.
 *  3. In de stand "alleen verbergen" klikken we niets en verbergen we de banner met CSS.
 * Een MutationObserver (een "waakhond" die ziet wanneer de pagina verandert) houdt 20 seconden
 * na het laden in de gaten of er nog een banner verschijnt; daarna stopt hij (performance).
 * De app zet vooraf `window.JOETOEP_COOKIE_MODE` = "rejectAll" | "hideOnly" | "off".
 */
(() => {
  "use strict";
  // Leest de stand die de app heeft meegegeven; standaard: weigeren.
  const mode = window.JOETOEP_COOKIE_MODE || "rejectAll";
  // Stand "uit" of het script draait al in deze pagina → niets doen.
  if (mode === "off" || window.__joetoepCookie) return;
  window.__joetoepCookie = true;

  // ── 1. Bekende consent-platforms: [selector van de WEIGER-knop] ──────────────────────
  const rejectSelectors = [
    "#onetrust-reject-all-handler",                         // OneTrust
    ".ot-pc-refuse-all-handler",                            // OneTrust (voorkeurenscherm)
    "#CybotCookiebotDialogBodyButtonDecline",               // Cookiebot
    "#CybotCookiebotDialogBodyLevelButtonLevelOptinDeclineAll",
    "#didomi-notice-disagree-button",                       // Didomi
    ".didomi-continue-without-agreeing",
    ".qc-cmp2-summary-buttons button[mode='secondary']",    // Quantcast
    "button[data-testid='uc-deny-all-button']",             // Usercentrics
    "#truste-consent-required",                             // TrustArc
    ".cmplz-deny",                                          // Complianz (WordPress)
    ".cky-btn-reject",                                      // CookieYes
    ".osano-cm-denyAll",                                    // Osano
    ".cm-btn-decline", ".cm-btn-danger",                    // Klaro
    ".iubenda-cs-reject-btn",                               // iubenda
    "a[data-cookie-refuse]", "[data-borlabs-cookie-refuse]",// Borlabs
    ".fc-cta-do-not-consent",                               // Google Funding Choices
    "button.sp_choice_type_REJECT_ALL",                     // Sourcepoint (in eigen iframe)
    "[data-cookiefirst-action='reject']",                   // CookieFirst
    ".js-cookie-consent-reject", ".cookie-consent-reject", ".cc-deny", ".cc-dismiss-deny"
  ];
  // Containers van banners, om ze in de stand "verbergen" onzichtbaar te maken.
  const bannerSelectors = [
    "#onetrust-consent-sdk", "#CybotCookiebotDialog", "#didomi-host", ".qc-cmp2-container",
    "#usercentrics-root", "#truste-consent-track", ".cmplz-cookiebanner", ".cky-consent-container",
    ".osano-cm-window", ".klaro", "#iubenda-cs-banner", "#BorlabsCookieBox", ".fc-consent-root",
    "[id^='sp_message_container']", ".cc-window", "#cookie-law-info-bar", "#cookiebanner",
    "#cookie-banner", ".cookie-banner", "#cookie-notice", ".cookie-notice", "#gdpr-consent", ".gdpr-banner"
  ];
  // ── 2. Teksten van weiger-knoppen (Nederlands, Engels, Duits, Frans, Spaans) ─────────
  // `^` en `$` betekenen: de HELE knoptekst moet dit zijn (niet "weigeren" als deel van iets).
  const rejectText = /^(alles? (weigeren|afwijzen)|weiger( alle)?( cookies)?|afwijzen|alleen (noodzakelijke?|functionele|essenti[eë]le)( cookies)?|noodzakelijke cookies( accepteren)?|niet akkoord|reject( all)?( cookies)?|decline( all)?( cookies)?|deny( all)?|refuse( all)?|disagree|only (necessary|essential)( cookies)?|(use )?(necessary|essential) cookies only|continue without (accepting|agreeing)|alle ablehnen|ablehnen|nur (notwendige|erforderliche)( cookies)?|tout refuser|refuser( tout)?|continuer sans accepter|rechazar( todo)?|rechazar todas)$/i;
  // Woorden die verraden dat een blok over cookies/toestemming gaat.
  const contextText = /(cookie|consent|toestemming|privacy|gdpr|tracking|datenschutz|confidentialit)/i;

  // Is dit element echt zichtbaar (niet verborgen of 0×0 pixels)?
  const visible = el => {
    if (!el || !el.isConnected) return false;
    const r = el.getBoundingClientRect();              // afmetingen en positie op het scherm
    if (r.width < 2 || r.height < 2) return false;
    const st = getComputedStyle(el);                   // de uiteindelijke CSS-stijl
    const opacity = st.opacity === "" ? 1 : Number(st.opacity);   // lege waarde = volledig zichtbaar
    return st.visibility !== "hidden" && st.display !== "none" && opacity > 0.05;
  };
  // Zoekt ook in "shadow DOM" (afgeschermde stukjes pagina, gebruikt door o.a. Usercentrics).
  const queryDeep = (root, selector) => {
    const found = root.querySelector(selector);
    if (found) return found;
    for (const host of root.querySelectorAll("*")) {
      if (host.shadowRoot) { const inner = queryDeep(host.shadowRoot, selector); if (inner) return inner; }
    }
    return null;
  };

  let done = false;           // true zodra we één keer met succes geweigerd hebben
  // Probeert één keer een weigerknop te vinden en te klikken. Geeft true als dat lukte.
  function tryReject() {
    for (const sel of rejectSelectors) {
      const button = queryDeep(document, sel);
      if (visible(button)) { button.click(); return true; }
    }
    // Algemene zoektocht: alle knoppen/links met een passende tekst …
    const candidates = document.querySelectorAll("button, [role='button'], a, input[type='button'], input[type='submit']");
    for (const el of candidates) {
      const label = (el.innerText || el.textContent || el.value || el.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ");
      if (!label || label.length > 60 || !rejectText.test(label) || !visible(el)) continue;
      // … maar alleen als een omliggend blok over cookies/privacy gaat (veiligheid: we willen
      // nooit per ongeluk op "weigeren" in een heel ander formulier klikken).
      let box = el, ok = false;
      for (let depth = 0; box && depth < 8; depth++, box = box.parentElement) {
        if (contextText.test((box.id || "") + " " + (box.className || "") + " " + (box.innerText || box.textContent || "").slice(0, 600))) { ok = true; break; }
      }
      if (ok) { el.click(); return true; }
    }
    return false;
  }
  // Verbergt bekende banners en maakt het scrollen van de pagina weer vrij.
  function hideBanners() {
    let style = document.getElementById("joetoep-cookie-hide");
    if (!style) {
      style = document.createElement("style");
      style.id = "joetoep-cookie-hide";
      style.textContent = bannerSelectors.join(",") + "{display:none !important}" +
        "html.joetoep-unlock,body.joetoep-unlock{overflow:auto !important;position:static !important}";
      (document.head || document.documentElement).appendChild(style);
    }
    document.documentElement.classList.add("joetoep-unlock");
    document.body?.classList.add("joetoep-unlock");
  }

  // Eén controle-ronde: in weigerstand eerst klikken; verbergen doen we in beide standen
  // alleen voor wat na het klikken nog overblijft.
  function pass() {
    if (done) return;
    if (mode === "rejectAll" && tryReject()) { done = true; setTimeout(hideLeftovers, 800); return; }
    if (mode === "hideOnly") hideBanners();
  }
  // Na een geslaagde klik: sommige sites laten een lege schaduwlaag achter → opruimen.
  function hideLeftovers() { if (bannerSelectors.some(s => visible(document.querySelector(s)))) hideBanners(); }

  // Ronde 1 meteen, en daarna telkens als de pagina verandert (max. 20 s, hooguit elke 250 ms).
  let scheduled = 0;
  const observer = new MutationObserver(() => {
    if (done || scheduled) return;
    scheduled = setTimeout(() => { scheduled = 0; pass(); }, 250);
  });
  const start = () => {
    pass();
    observer.observe(document.documentElement, { childList: true, subtree: true });
    setTimeout(() => observer.disconnect(), 20000);   // daarna geen werk meer (snelheid)
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
