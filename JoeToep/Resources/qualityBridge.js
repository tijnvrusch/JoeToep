(() => {
  "use strict";
  if (window.JoeToepQuality) return;
  const known = new Set(["auto", "tiny", "small", "medium", "large", "hd720", "hd1080", "hd1440", "hd2160"]);
  const player = () => document.getElementById("movie_player") || document.querySelector(".html5-video-player");
  const read = () => {
    try {
      const p = player();
      const available = p?.getAvailableQualityLevels?.();
      return {
        levels: Array.isArray(available) ? available.filter(x => known.has(x)) : [],
        actual: String(p?.getPlaybackQuality?.() || ""),
        supported: Boolean(p && (typeof p.setPlaybackQualityRange === "function" || typeof p.setPlaybackQuality === "function"))
      };
    } catch (_) { return { levels: [], actual: "", supported: false }; }
  };
  window.JoeToepQuality = Object.freeze({
    read,
    request: quality => {
      if (!known.has(quality)) return { status: "invalid" };
      const p = player();
      const capabilities = read();
      if (!p || !capabilities.supported) return { status: "unavailable", ...capabilities };
      if (quality !== "auto" && capabilities.levels.length && !capabilities.levels.includes(quality)) {
        return { status: "not-offered", ...capabilities };
      }
      try {
        if (typeof p.setPlaybackQualityRange === "function") p.setPlaybackQualityRange(quality, quality);
        else p.setPlaybackQuality(quality);
        // A request is not a confirmation. The native UI displays measured quality separately.
        return { status: "requested", ...read() };
      } catch (_) { return { status: "rejected", ...read() }; }
    }
  });
})();
