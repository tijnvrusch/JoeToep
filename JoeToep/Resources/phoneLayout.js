/* V23.1 — iPhone + desktop-YouTube ("Desktop site"): vanaf het EERSTE frame één video per rij,
 * net als de mobiele YouTube-site. Draait op documentStart (vóór YouTube's eigen scripts en
 * vóór de eerste opmaak), dus er is niets meer dat verspringt van twee kolommen naar één.
 * Alleen CSS + één viewport-tag: geen timers, geen polling, geen observers. */
(() => {
  "use strict";
  if (window.JOETOEP_MOBILE !== true || window.JOETOEP_IPAD === true || window.__joetoepPhoneLayout) return;
  const host = location.hostname.toLowerCase();
  if (!(host === "youtube.com" || host.endsWith(".youtube.com")) || host.startsWith("m.") || host.startsWith("music.")) return;
  window.__joetoepPhoneLayout = true;
  const root = document.documentElement;
  if (!root) return;
  // 1. Viewport = schermbreedte vanaf de eerste opmaak. (Zonder tag rekende YouTube eerst met een
  //    brede desktop-viewport: twee kolommen, en sprong pas daarna naar één.)
  if (!document.querySelector('meta[name="viewport"]')) {
    const meta = document.createElement("meta");
    meta.name = "viewport"; meta.id = "joetoep-phone-viewport";
    meta.content = "width=device-width,initial-scale=1,viewport-fit=cover";
    root.appendChild(meta);
  }
  // 2. Startpagina, abonnementen, kanalen: altijd één video per rij (Shorts blijven 2 naast elkaar,
  //    zoals op de mobiele site). !important wint van YouTube's eigen inline-variabelen, dus ook
  //    YouTube's eerste (te brede) berekening komt nooit in beeld.
  const css = [
    "ytd-rich-grid-renderer{--ytd-rich-grid-items-per-row:1!important;--ytd-rich-grid-posts-per-row:1!important;" +
      "--ytd-rich-grid-slim-items-per-row:2!important;--ytd-rich-grid-game-cards-per-row:2!important;" +
      "--ytd-rich-grid-mini-game-cards-per-row:2!important}",
    // Oudere opbouw met rijen van N video's: rijen "oplossen" zodat elke video een eigen regel krijgt.
    "ytd-rich-grid-renderer ytd-rich-grid-row,ytd-rich-grid-renderer ytd-rich-grid-row>#contents{display:contents!important}",
    "ytd-rich-grid-renderer>#contents{display:flex!important;flex-wrap:wrap!important}",
    "ytd-rich-grid-renderer ytd-rich-item-renderer:not([is-slim-media]):not([is-shorts]){width:calc(100% - var(--ytd-rich-grid-item-margin,16px))!important;max-width:none!important;min-width:0!important}",
    // Geen horizontale overloop door minimale breedtes van de desktop-opmaak.
    "ytd-app,ytd-page-manager,ytd-browse,ytd-two-column-browse-results-renderer,ytd-rich-grid-renderer{min-width:0!important}",
    "ytd-two-column-browse-results-renderer{max-width:100vw!important;width:100%!important;padding:0!important}",
    // Kijkpagina (V22.1, nu al vanaf het eerste frame): de kolom onder de speler past op het scherm.
    "@media (max-width:760px){ytd-watch-flexy{--ytd-watch-flexy-min-player-width:0px!important;--ytd-watch-flexy-sidebar-min-width:0px!important;min-width:0!important}" +
      "ytd-watch-flexy #columns,ytd-watch-flexy #primary,ytd-watch-flexy #primary-inner,ytd-watch-flexy #below,ytd-watch-flexy #secondary,ytd-watch-metadata,ytd-watch-flexy #player-container-outer{min-width:0!important;max-width:100vw!important;box-sizing:border-box!important}" +
      "ytd-watch-flexy #primary,ytd-watch-flexy #secondary{margin-left:0!important;margin-right:0!important;padding-left:12px!important;padding-right:12px!important;width:100%!important}" +
      "ytd-watch-flexy #columns{display:block!important}}",
    "html{overscroll-behavior-x:none!important}"
  ].join("\n");
  const style = document.createElement("style");
  style.id = "joetoep-phone-layout";
  style.textContent = css;
  root.appendChild(style);
  // YouTube vervangt soms <head>/<body>-inhoud bij navigeren; het stijlblad hoort altijd mee te gaan.
  const keep = () => { if (!style.isConnected) (document.head || document.documentElement).appendChild(style); };
  document.addEventListener("DOMContentLoaded", keep, {once: true});
  document.addEventListener("yt-navigate-finish", keep);
})();
