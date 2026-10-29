/* JoeToep V26: Boosts (zoals Arc) — eigen stylesheet per website en "Zap" (klik een element weg).
 * Draait in de bridge-wereld (eigen JavaScript-wereld, dezelfde DOM): de site kan dit script niet zien of
 * uitschakelen. Alleen DOM-API's (createElement/textContent), nooit HTML als tekst → werkt ook met YouTube's
 * Trusted Types. De app stuurt de configuratie als JSON: { enabled, css, site }.
 *   JoeToepBoosts.apply(config)  stylesheet zetten of weghalen
 *   JoeToepBoosts.startZap()     Zap-modus: element onder de muis oplichten, klik = verbergen + melden aan de app
 *   JoeToepBoosts.stopZap()      Zap-modus uit (ook met Esc)
 *   JoeToepBoosts.undoZap()      laatst gezapte element weer tonen (de app haalt de selector uit de boost)
 *   JoeToepBoosts.selectorFor(el) stabiele CSS-selector voor een element (ook gebruikt in de tests)
 */
(() => {
  'use strict';
  if (window.JoeToepBoosts) {
    if (window.JOETOEP_BOOST) window.JoeToepBoosts.apply(window.JOETOEP_BOOST);
    return;
  }
  const STYLE_ID = 'joetoep-boost-style';
  const post = message => { try { window.webkit?.messageHandlers?.joeToepLinks?.postMessage(message); } catch (_) {} };
  let config = { enabled: false, css: '', site: '' };
  // Zelfde sleutel als BoostStore.siteKey in Swift: zonder "www.", "m." of "mobile." (alleen bij 3+ delen).
  const siteKey = host => {
    let h = String(host || '').toLowerCase();
    for (const prefix of ['www.', 'm.', 'mobile.']) {
      if (h.startsWith(prefix) && h.split('.').length > 2) { h = h.slice(prefix.length); break; }
    }
    return h;
  };
  let style = null;

  const root = () => document.head || document.documentElement;

  // Stylesheet zetten, bijwerken of weghalen. Staat hij er al met dezelfde inhoud, dan gebeurt er niets
  // (geen onnodige herberekening van de opmaak).
  function ensureStyle() {
    if (!config.enabled || !config.css) {
      if (style && style.isConnected) style.remove();
      return null;
    }
    if (!style) {
      style = document.getElementById(STYLE_ID) || document.createElement('style');
      style.id = STYLE_ID;
      style.setAttribute('data-joetoep', 'boost');
    }
    if (style.textContent !== config.css) style.textContent = config.css;
    const parent = root();
    // Achteraan in <head>: dan wint onze CSS bij gelijke specificiteit van die van de site.
    if (parent && (!style.isConnected || style.parentNode !== parent || parent.lastElementChild !== style)) parent.appendChild(style);
    return style;
  }

  function apply(next) {
    const value = next && typeof next === 'object' ? next : {};
    config = { enabled: value.enabled === true, css: typeof value.css === 'string' ? value.css : '', site: typeof value.site === 'string' ? value.site : '' };
    ensureStyle();
    return !!(style && style.isConnected);
  }

  // Sommige sites (en YouTube bij navigeren) vervangen <head> of halen onbekende <style>'s weg:
  // dan zet de watcher hem terug. Alleen directe kinderen, geen hele boom → kost niets.
  let watcher = null;
  function watch() {
    if (watcher || typeof MutationObserver !== 'function') return;
    watcher = new MutationObserver(() => { if (config.enabled && config.css && !(style && style.isConnected)) ensureStyle(); });
    watcher.observe(document.documentElement, { childList: true });
    if (document.head) watcher.observe(document.head, { childList: true });
  }
  const settle = () => { if (document.head && watcher) watcher.observe(document.head, { childList: true }); ensureStyle(); };
  document.addEventListener('DOMContentLoaded', settle, { once: true });
  window.addEventListener('load', settle, { once: true });
  document.addEventListener('yt-navigate-finish', () => ensureStyle());

  // ── Zap ──────────────────────────────────────────────────────────────────────────────────────
  const plain = /^[A-Za-z_][A-Za-z0-9_-]{0,63}$/;
  // Klassen die per bezoek/toestand wisselen, maken een selector onbruikbaar.
  const volatile = c => /\d{3,}/.test(c) || c.length > 40 ||
    /^(style-scope|active|is-|has-|hover|focus|focused|selected|hidden|visible|open|opened|expanded|collapsed|ng-|css-|sc-|jsx-|svelte-|emotion-)/i.test(c);
  const stableID = id => plain.test(id) && !/\d{4,}/.test(id);
  function unique(selector) {
    try { return document.querySelectorAll(selector).length === 1; } catch (_) { return false; }
  }
  function part(el) {
    const tag = /^[a-z][a-z0-9-]*$/.test(el.localName) ? el.localName : '*';
    const classes = Array.from(el.classList || []).filter(c => plain.test(c) && !volatile(c)).slice(0, 2);
    return tag + classes.map(c => '.' + c).join('');
  }
  function nthOfType(el) {
    let index = 1, sibling = el;
    while ((sibling = sibling.previousElementSibling)) if (sibling.localName === el.localName) index++;
    return index;
  }
  function selectorFor(el) {
    if (!el || el.nodeType !== 1) return '';
    if (el.id && stableID(el.id) && unique('#' + el.id)) return '#' + el.id;
    const path = [];
    let node = el;
    while (node && node.nodeType === 1 && node.localName !== 'html' && path.length < 7) {
      let piece;
      if (node.id && stableID(node.id) && unique('#' + node.id)) piece = '#' + node.id;
      else {
        piece = part(node);
        const parent = node.parentElement;
        if (parent) {
          let same = 0;
          for (const child of parent.children) { try { if (child.matches(piece)) same++; } catch (_) {} }
          if (same > 1) piece += ':nth-of-type(' + nthOfType(node) + ')';
        }
      }
      path.unshift(piece);
      const candidate = path.join(' > ');
      if (piece.startsWith('#') || unique(candidate)) return candidate;
      if (node.localName === 'body') break;
      node = node.parentElement;
    }
    return path.join(' > ');
  }

  let zap = null;
  const zapped = [];
  const ignorable = el => !el || el.nodeType !== 1 || el === document.documentElement || el === document.body ||
    (zap && (el === zap.box || el === zap.label || zap.box.contains(el)));

  function place(target) {
    if (!zap) return;
    if (ignorable(target)) { zap.box.style.display = 'none'; zap.current = null; return; }
    zap.current = target;
    const rect = target.getBoundingClientRect();
    const box = zap.box.style;
    box.display = 'block';
    box.left = rect.left + 'px'; box.top = rect.top + 'px';
    box.width = Math.max(0, rect.width) + 'px'; box.height = Math.max(0, rect.height) + 'px';
    zap.label.textContent = selectorFor(target).slice(0, 120);
  }

  function hide(el) {
    zapped.push({ el, display: el.style.getPropertyValue('display'), priority: el.style.getPropertyPriority('display') });
    if (zapped.length > 50) zapped.shift();
    el.style.setProperty('display', 'none', 'important');
  }

  function startZap(options) {
    if (zap) return true;
    if (!document.body) return false;
    const highlight = !(options && options.highlight === false);
    const box = document.createElement('div');
    box.setAttribute('data-joetoep', 'zap');
    const s = box.style;
    s.position = 'fixed'; s.zIndex = '2147483647'; s.pointerEvents = 'none'; s.display = 'none';
    s.boxSizing = 'border-box'; s.borderRadius = '6px'; s.transition = 'all 60ms linear';
    s.outline = highlight ? '2px solid #ff3b30' : '1px dashed #ff3b30';
    s.background = highlight ? 'rgba(255,59,48,0.16)' : 'transparent';
    const label = document.createElement('div');
    const l = label.style;
    l.position = 'absolute'; l.left = '0'; l.top = '-22px'; l.font = '11px -apple-system, system-ui, sans-serif';
    l.color = '#fff'; l.background = '#ff3b30'; l.padding = '2px 6px'; l.borderRadius = '4px'; l.whiteSpace = 'nowrap';
    box.appendChild(label);
    document.body.appendChild(box);
    const swallow = e => { e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation(); };
    const onMove = e => place(e.target);
    const onClick = e => {
      swallow(e);
      const target = ignorable(e.target) ? zap.current : e.target;
      if (ignorable(target)) return;
      const selector = selectorFor(target);
      if (!selector) return;
      hide(target);
      place(null);
      post({ event: 'boostZap', selector, site: config.site || location.hostname });
    };
    const onKey = e => { if (e.key === 'Escape') { swallow(e); stopZap(); post({ event: 'boostZapEnded' }); } };
    zap = { box, label, current: null, onMove, onClick, onKey, swallow };
    document.addEventListener('mouseover', onMove, true);
    document.addEventListener('pointermove', onMove, true);
    document.addEventListener('click', onClick, true);
    for (const type of ['mousedown', 'mouseup', 'pointerdown', 'pointerup', 'auxclick', 'dblclick', 'contextmenu']) {
      document.addEventListener(type, swallow, true);
    }
    document.addEventListener('keydown', onKey, true);
    return true;
  }

  function stopZap() {
    if (!zap) return false;
    document.removeEventListener('mouseover', zap.onMove, true);
    document.removeEventListener('pointermove', zap.onMove, true);
    document.removeEventListener('click', zap.onClick, true);
    for (const type of ['mousedown', 'mouseup', 'pointerdown', 'pointerup', 'auxclick', 'dblclick', 'contextmenu']) {
      document.removeEventListener(type, zap.swallow, true);
    }
    document.removeEventListener('keydown', zap.onKey, true);
    zap.box.remove();
    zap = null;
    return true;
  }

  function undoZap() {
    const last = zapped.pop();
    if (!last) return false;
    if (last.display) last.el.style.setProperty('display', last.display, last.priority);
    else last.el.style.removeProperty('display');
    return true;
  }

  window.JoeToepBoosts = Object.freeze({
    apply, startZap, stopZap, undoZap, selectorFor, siteKey,
    get zapping() { return !!zap; },
    get config() { return { ...config }; },
  });
  watch();
  // De app geeft bij documentStart óf één Boost (JOETOEP_BOOST) óf alle Boosts per site (JOETOEP_BOOSTS_ALL):
  // dan kiest het script zelf die van deze site, zodat er nooit een flits van de oorspronkelijke pagina is.
  const all = window.JOETOEP_BOOSTS_ALL;
  if (window.JOETOEP_BOOST) apply(window.JOETOEP_BOOST);
  else if (all && typeof all === 'object' && Object.prototype.hasOwnProperty.call(all, siteKey(location.hostname))) {
    apply(all[siteKey(location.hostname)]);
  }
})();
