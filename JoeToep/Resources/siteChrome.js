(() => {
  "use strict";
  if (!window.JOETOEP_MOBILE || document.getElementById("joetoep-mobile-chrome")) return;
  const host = location.hostname.toLowerCase();
  if (!(host === "youtube.com" || host.endsWith(".youtube.com"))) return;
  const style = document.createElement("style");
  style.id = "joetoep-mobile-chrome";
  style.textContent = `
    ytm-pivot-bar-renderer, .pivot-bar-renderer, ytm-pivot-bar-item-renderer { display:none!important; }
    ytm-app, ytm-browse { padding-bottom:0!important; }
  `;
  (document.head || document.documentElement).appendChild(style);
})();
