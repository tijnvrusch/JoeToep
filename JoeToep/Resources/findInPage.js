/* JoeToep V16: Chrome-style find on page (all platforms). Highlights every match, marks the
 * current one and scrolls it into view. Runs in the isolated bridge world. */
// IIFE (meteen aangeroepen functie) die "zoeken op de pagina" implementeert, zoals
// Cmd+F in een browser: elke tekst-match krijgt een gele markering (<mark>), de huidige
// match wordt oranje en scrollt in beeld.
(() => {
  'use strict';
  // Niet dubbel opzetten.
  if (window.JoeToepFind) return;
  // Bovengrens: we doorzoeken/markeren nooit meer dan 2000 stukjes tekst, om de pagina
  // niet traag te maken op erg lange sites.
  const MAX = 2000;
  // marks: lijst met alle <mark>-elementen die we hebben toegevoegd.
  // index: welke van die marks nu "actief" (geselecteerd) is; -1 = geen.
  // query: de tekst waarnaar we op dit moment zoeken.
  let marks = [], index = -1, query = '';
  // Voegt eenmalig de CSS toe die onze markeringen geel (normaal) en oranje (actief) kleurt.
  function ensureStyle() {
    if (document.getElementById('joetoep-find-style')) return;
    const s = document.createElement('style');
    s.id = 'joetoep-find-style';
    s.textContent = 'mark.joetoep-find{background:#ffe36e;color:#111;border-radius:2px;padding:0 1px}' +
      'mark.joetoep-find.joetoep-find-active{background:#ff9632;box-shadow:0 0 0 2px #ff9632}';
    (document.head || document.documentElement).appendChild(s);
  }
  // Verwijdert alle markeringen weer en herstelt de originele tekst. Voor elke <mark>
  // zetten we op zijn plek weer gewone tekst terug (createTextNode), en normalize()
  // voegt aangrenzende tekst-stukjes weer samen tot één stuk.
  function clear() {
    for (const m of marks) {
      const parent = m.parentNode;
      if (!parent) continue;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize();
    }
    marks = []; index = -1;
  }
  // Checkt of een element (en al zijn voorouders tot aan <body>) zichtbaar is, door
  // getComputedStyle te vragen naar de uiteindelijke, berekende CSS-stijl van dat element.
  function visible(el) {
    for (let e = el; e && e !== document.body; e = e.parentElement) {
      const cs = getComputedStyle(e);
      if (cs.display === 'none' || cs.visibility === 'hidden') return false;
    }
    return true;
  }
  // Zoekt naar "text" in de hele pagina en markeert elke gevonden plek.
  function find(text) {
    clear(); query = String(text || '');
    if (!query || !document.body) return state();
    ensureStyle();
    // toLocaleLowerCase: alles kleine letters maken zodat het zoeken niet hoofdlettergevoelig is.
    const needle = query.toLocaleLowerCase();
    // Een TreeWalker loopt door de HTML-boom en levert alleen de knooppunten die je vraagt
    // (hier: tekst-knooppunten, SHOW_TEXT). acceptNode filtert welke tekst-stukjes we
    // meenemen: we slaan scripts, stijlen en invoervelden over, en houden alleen stukjes
    // tekst over die onze zoekterm bevatten.
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const p = node.parentElement;
        if (!p || /^(SCRIPT|STYLE|NOSCRIPT|TEXTAREA|INPUT|MARK)$/.test(p.tagName)) return NodeFilter.FILTER_REJECT;
        return node.nodeValue.toLocaleLowerCase().includes(needle) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    // Eerst alle passende tekst-knooppunten verzamelen in een gewone array (tot MAX stuks),
    // vóórdat we de pagina gaan aanpassen (aanpassen tijdens het lopen kan de walker in de war brengen).
    const nodes = [];
    while (walker.nextNode() && nodes.length < MAX) nodes.push(walker.currentNode);
    for (const node of nodes) {
      if (!visible(node.parentElement)) continue;
      let current = node;
      // Eén tekst-knooppunt kan de zoekterm meerdere keren bevatten, dus we blijven
      // splitsen tot er geen match meer is.
      while (current && marks.length < MAX) {
        const pos = current.nodeValue.toLocaleLowerCase().indexOf(needle);
        if (pos < 0) break;
        // splitText knipt een tekst-knooppunt in tweeën op positie "pos". "match" is het
        // stuk vanaf de gevonden tekst; daarna knippen we "match" opnieuw af op de lengte
        // van de zoekterm, zodat "rest" alles is wat er na de match nog komt.
        const match = current.splitText(pos);
        const rest = match.splitText(query.length);
        // We vervangen het gevonden tekststukje door een <mark>-element met diezelfde tekst erin.
        const mark = document.createElement('mark');
        mark.className = 'joetoep-find';
        match.parentNode.replaceChild(mark, match);
        mark.appendChild(match);
        marks.push(mark);
        current = rest;
      }
    }
    // Als er iets gevonden is, selecteren we meteen de eerste match.
    if (marks.length) select(0);
    return state();
  }
  // Maakt markering "i" de actieve (oranje) match en scrollt hem in beeld. De modulo (%)
  // zorgt dat we rondlopen: na de laatste match kom je weer bij de eerste terecht.
  function select(i) {
    if (!marks.length) return state();
    marks[index]?.classList.remove('joetoep-find-active');
    index = (i + marks.length) % marks.length;
    const m = marks[index];
    m.classList.add('joetoep-find-active');
    try { m.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' }); } catch (_) { m.scrollIntoView(); }
    return state();
  }
  // Kleine samenvatting van de huidige zoekstatus, die we telkens teruggeven aan de app.
  const state = () => ({ count: marks.length, index: marks.length ? index + 1 : 0, query });
  // De publieke API die de native app kan aanroepen; Object.freeze voorkomt dat de
  // website deze functies zou kunnen overschrijven.
  window.JoeToepFind = Object.freeze({
    find, clear: () => { clear(); query = ''; return state(); },
    next: () => select(index + 1), previous: () => select(index - 1), state
  });
})();
