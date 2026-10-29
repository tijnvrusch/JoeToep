// Dit bestand geeft de native app een manier om de videokwaliteit van YouTube's eigen
// speler uit te lezen en te wijzigen. Alles zit in een IIFE (meteen aangeroepen functie)
// zodat niets hiervan per ongeluk botst met YouTube's eigen scripts.
(() => {
  "use strict";
  // Niet nog een keer opzetten als het al bestaat.
  if (window.JoeToepQuality) return;
  // Set is een verzameling unieke waarden; .has(x) checkt supersnel of iets erin zit.
  // Dit zijn de kwaliteitsnamen die YouTube's speler zelf gebruikt.
  const known = new Set(["auto", "tiny", "small", "medium", "large", "hd720", "hd1080", "hd1440", "hd2160"]);
  // Zoekt het HTML-element van YouTube's videospeler op. getElementById zoekt op het
  // id-attribuut; querySelector zoekt op een CSS-selector (hier: de class-naam).
  const player = () => document.getElementById("movie_player") || document.querySelector(".html5-video-player");
  // Leest de huidige stand van zaken uit de speler: welke kwaliteiten zijn er, welke
  // kwaliteit speelt er nu echt, en ondersteunt deze speler het instellen van kwaliteit.
  const read = () => {
    // try/catch: als de speler-API onverwacht ontbreekt of een fout geeft, geven we
    // gewoon lege/veilige standaardwaarden terug in plaats van dat het script crasht.
    try {
      const p = player();
      // ?. (optional chaining): roep de functie alleen aan als p (en de functie) bestaat.
      const available = p?.getAvailableQualityLevels?.();
      return {
        // Alleen kwaliteiten overhouden die we herkennen (known).
        levels: Array.isArray(available) ? available.filter(x => known.has(x)) : [],
        actual: String(p?.getPlaybackQuality?.() || ""),
        // Boolean(...) zet de waarde om naar echt true/false.
        supported: Boolean(p && (typeof p.setPlaybackQualityRange === "function" || typeof p.setPlaybackQuality === "function"))
      };
    } catch (_) { return { levels: [], actual: "", supported: false }; }
  };
  // Object.freeze maakt het object hierna onveranderbaar: niemand kan later per ongeluk
  // (of expres, vanaf de website) de functies erin overschrijven.
  window.JoeToepQuality = Object.freeze({
    read,
    // Wordt aangeroepen door de native app om een kwaliteit aan te vragen.
    request: quality => {
      // Onbekende kwaliteitsnaam? Meteen afwijzen.
      if (!known.has(quality)) return { status: "invalid" };
      const p = player();
      const capabilities = read();
      if (!p || !capabilities.supported) return { status: "unavailable", ...capabilities };
      // Als de speler een lijst met beschikbare kwaliteiten geeft, en de gevraagde
      // kwaliteit staat er niet bij (en het is niet "auto"), dan kunnen we hem niet leveren.
      if (quality !== "auto" && capabilities.levels.length && !capabilities.levels.includes(quality)) {
        return { status: "not-offered", ...capabilities };
      }
      try {
        // Sommige spelers hebben een "range" methode (min/max kwaliteit), anders gebruiken
        // we de oudere, simpelere setPlaybackQuality.
        if (typeof p.setPlaybackQualityRange === "function") p.setPlaybackQualityRange(quality, quality);
        else p.setPlaybackQuality(quality);
        // A request is not a confirmation. The native UI displays measured quality separately.
        return { status: "requested", ...read() };
      } catch (_) { return { status: "rejected", ...read() }; }
    }
  });
})();
