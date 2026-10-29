/* JoeToep V15: link context for "Open in New Tab" (every site, isolated world). */
(() => {
  'use strict';
  if (window.JoeToepLinks) return;
  const post = message => { try { window.webkit?.messageHandlers?.joeToepLinks?.postMessage(message); } catch (_) {} };
  window.addEventListener('contextmenu', e => {
    const link = e.target?.closest?.('a[href]');
    const href = link ? link.href : '';
    post({ event: 'contextLink', url: /^https?:/i.test(href) ? href : '',
      title: link ? String(link.getAttribute('title') || link.getAttribute('aria-label') || link.textContent || '').trim().slice(0, 200) : '' });
  }, true);
  if (window.JOETOEP_MOBILE) {
    // Allow the system long-press menu on links (YouTube disables the callout on some tiles).
    const install = () => {
      if (document.getElementById('joetoep-link-callout')) return;
      const style = document.createElement('style');
      style.id = 'joetoep-link-callout';
      style.textContent = 'a[href]{-webkit-touch-callout:default!important}';
      (document.head || document.documentElement).appendChild(style);
    };
    install(); document.addEventListener('DOMContentLoaded', install, { once: true });
  }
  window.JoeToepLinks = true;
})();
