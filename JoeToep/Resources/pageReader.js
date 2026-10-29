/* JoeToep V26: leest de tekst van de open pagina voor de pagina-assistent (samenvatten, kernpunten, vragen).
 * Draait in de bridge-wereld en alleen op verzoek (JoeToepPageReader.extract): er draait niets op de
 * achtergrond en er wordt niets verstuurd — de app verwerkt de tekst op het apparaat zelf.
 * Resultaat: { title, url, description, text } met hooguit `maxChars` tekens tekst.
 */
(() => {
  'use strict';
  if (window.JoeToepPageReader) return;
  // Onderdelen zonder leesbare inhoud (menu's, knoppen, scripts) en YouTube's balk/zijmenu/aanbevelingen.
  const SKIP = new Set(['script', 'style', 'noscript', 'svg', 'canvas', 'iframe', 'video', 'audio', 'img', 'picture',
    'nav', 'footer', 'header', 'aside', 'button', 'input', 'select', 'textarea', 'template', 'form', 'menu', 'dialog',
    'ytd-masthead', 'tp-yt-app-drawer', 'ytd-guide-renderer', 'ytd-mini-guide-renderer', 'ytd-watch-next-secondary-results-renderer',
    'ytm-pivot-bar-renderer', 'ytm-mobile-topbar-renderer', 'ytd-popup-container', 'ytd-player', 'ytm-player']);
  const BLOCK = /^(p|div|section|article|main|li|ul|ol|h[1-6]|br|tr|td|th|blockquote|pre|dd|dt|figcaption|summary|details|ytd-comment-renderer|ytd-comment-view-model|yt-attributed-string|yt-formatted-string)$/;

  function collect(node, out, budget) {
    if (out.length >= budget) return;
    if (node.nodeType === 3) {
      const text = node.nodeValue.replace(/\s+/g, ' ');
      if (text.trim()) { out.parts.push(text); out.length += text.length; }
      return;
    }
    if (node.nodeType !== 1) return;
    const tag = node.localName;
    if (SKIP.has(tag) || node.hidden || node.getAttribute('aria-hidden') === 'true' || node.getAttribute('data-joetoep')) return;
    const block = BLOCK.test(tag);
    if (block) out.parts.push('\n');
    for (const child of node.childNodes) {
      collect(child, out, budget);
      if (out.length >= budget) break;
    }
    if (block) out.parts.push('\n');
  }

  const clean = text => text.replace(/[ \t ]+/g, ' ').replace(/ *\n */g, '\n').replace(/\n{2,}/g, '\n').trim();
  const meta = name => document.querySelector(`meta[name="${name}"], meta[property="${name}"]`)?.getAttribute('content') || '';

  function description() {
    // YouTube: de beschrijving onder de video (desktop en mobiel), anders de metabeschrijving.
    const yt = document.querySelector('ytd-watch-metadata #description-inline-expander, #description-inline-expander, ytd-text-inline-expander, ytm-expandable-video-description-body-renderer');
    if (yt) {
      const out = { parts: [], length: 0 };
      collect(yt, out, 4000);
      const text = clean(out.parts.join(''));
      if (text) return text;
    }
    return (meta('description') || meta('og:description')).trim().slice(0, 4000);
  }

  function mainRoot() {
    return document.querySelector('article') || document.querySelector('main') || document.querySelector('[role="main"]') ||
      document.querySelector('ytd-watch-flexy #primary') || document.querySelector('#primary') || document.body;
  }

  function extract(maxChars) {
    const budget = Math.max(1000, Math.min(Number(maxChars) || 30000, 200000));
    const out = { parts: [], length: 0 };
    const rootNode = mainRoot();
    if (rootNode) collect(rootNode, out, budget);
    let text = clean(out.parts.join(''));
    if (text.length > budget) text = text.slice(0, budget);
    const title = (meta('og:title') || document.title || '').replace(/\s+-\s+YouTube$/, '').trim();
    return { title, url: location.href, description: description(), text };
  }

  window.JoeToepPageReader = Object.freeze({ extract });
})();
