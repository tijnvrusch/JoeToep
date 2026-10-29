/* JoeToep V16: Chrome-style find on page (all platforms). Highlights every match, marks the
 * current one and scrolls it into view. Runs in the isolated bridge world. */
(() => {
  'use strict';
  if (window.JoeToepFind) return;
  const MAX = 2000;
  let marks = [], index = -1, query = '';
  function ensureStyle() {
    if (document.getElementById('joetoep-find-style')) return;
    const s = document.createElement('style');
    s.id = 'joetoep-find-style';
    s.textContent = 'mark.joetoep-find{background:#ffe36e;color:#111;border-radius:2px;padding:0 1px}' +
      'mark.joetoep-find.joetoep-find-active{background:#ff9632;box-shadow:0 0 0 2px #ff9632}';
    (document.head || document.documentElement).appendChild(s);
  }
  function clear() {
    for (const m of marks) {
      const parent = m.parentNode;
      if (!parent) continue;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize();
    }
    marks = []; index = -1;
  }
  function visible(el) {
    for (let e = el; e && e !== document.body; e = e.parentElement) {
      const cs = getComputedStyle(e);
      if (cs.display === 'none' || cs.visibility === 'hidden') return false;
    }
    return true;
  }
  function find(text) {
    clear(); query = String(text || '');
    if (!query || !document.body) return state();
    ensureStyle();
    const needle = query.toLocaleLowerCase();
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const p = node.parentElement;
        if (!p || /^(SCRIPT|STYLE|NOSCRIPT|TEXTAREA|INPUT|MARK)$/.test(p.tagName)) return NodeFilter.FILTER_REJECT;
        return node.nodeValue.toLocaleLowerCase().includes(needle) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    const nodes = [];
    while (walker.nextNode() && nodes.length < MAX) nodes.push(walker.currentNode);
    for (const node of nodes) {
      if (!visible(node.parentElement)) continue;
      let current = node;
      while (current && marks.length < MAX) {
        const pos = current.nodeValue.toLocaleLowerCase().indexOf(needle);
        if (pos < 0) break;
        const match = current.splitText(pos);
        const rest = match.splitText(query.length);
        const mark = document.createElement('mark');
        mark.className = 'joetoep-find';
        match.parentNode.replaceChild(mark, match);
        mark.appendChild(match);
        marks.push(mark);
        current = rest;
      }
    }
    if (marks.length) select(0);
    return state();
  }
  function select(i) {
    if (!marks.length) return state();
    marks[index]?.classList.remove('joetoep-find-active');
    index = (i + marks.length) % marks.length;
    const m = marks[index];
    m.classList.add('joetoep-find-active');
    try { m.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' }); } catch (_) { m.scrollIntoView(); }
    return state();
  }
  const state = () => ({ count: marks.length, index: marks.length ? index + 1 : 0, query });
  window.JoeToepFind = Object.freeze({
    find, clear: () => { clear(); query = ''; return state(); },
    next: () => select(index + 1), previous: () => select(index - 1), state
  });
})();
