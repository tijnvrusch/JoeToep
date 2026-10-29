/* JoeToep V15: link context for "Open in New Tab" (every site, isolated world). */
// Dit hele bestand staat in een IIFE (Immediately Invoked Function Expression): een functie
// die je meteen aanroept door hem tussen haakjes te zetten en er "()" achter te plakken.
// Alles wat je hierbinnen met "const"/"let" maakt blijft privé en lekt niet naar de rest
// van de pagina (zo botsen we niet met scripts van de website zelf).
(() => {
  // 'use strict' zet JavaScript in een strengere modus: typefouten (zoals een variabele
  // gebruiken die je vergeten bent te declareren) geven meteen een fout in plaats van
  // stilletjes iets geks te doen.
  'use strict';
  // Als dit script al eerder is uitgevoerd (window.JoeToepLinks bestaat al), stoppen we
  // meteen. Dat voorkomt dat we dezelfde event-listeners dubbel toevoegen.
  if (window.JoeToepLinks) return;
  // Kleine hulpfunctie om een boodschap naar de native iOS/macOS-app te sturen via de
  // "bridge": window.webkit.messageHandlers is een speciaal object dat Safari/WKWebView
  // aanbiedt om vanuit JavaScript met de app te praten. De "?." (optional chaining) zorgt
  // dat er geen fout ontstaat als een van die tussenstappen niet bestaat.
  const post = message => { try { window.webkit?.messageHandlers?.joeToepLinks?.postMessage(message); } catch (_) {} };
  // addEventListener luistert naar een gebeurtenis (event) op de pagina; hier op het hele
  // window-object. 'contextmenu' is het rechtsklik-/lang-indrukken-menu. De laatste "true"
  // betekent dat we luisteren in de "capture"-fase (vroeg, voordat de pagina zelf reageert),
  // zodat we ook events opvangen die de website later zou tegenhouden.
  window.addEventListener('contextmenu', e => {
    // e.target is het element waarop geklikt is. closest('a[href]') zoekt vanaf dat element
    // omhoog in de HTML-boom naar de dichtstbijzijnde link (<a> met een href).
    const link = e.target?.closest?.('a[href]');
    const href = link ? link.href : '';
    // We sturen alleen echte http(s)-links door, en een titel (max 200 tekens) die we halen
    // uit het title-attribuut, anders aria-label, anders de zichtbare tekst van de link.
    post({ event: 'contextLink', url: /^https?:/i.test(href) ? href : '',
      title: link ? String(link.getAttribute('title') || link.getAttribute('aria-label') || link.textContent || '').trim().slice(0, 200) : '' });
  }, true);
  // Alleen op mobiel: YouTube blokkeert soms het systeemmenu bij lang indrukken op een link.
  if (window.JOETOEP_MOBILE) {
    // Allow the system long-press menu on links (YouTube disables the callout on some tiles).
    // We maken een <style>-element aan en zetten er CSS in die het lang-indrukken-menu
    // (touch-callout) weer aanzet voor links. document.createElement maakt een nieuw,
    // nog onzichtbaar HTML-element; pas met appendChild plakken we het echt in de pagina.
    const install = () => {
      // Niet twee keer hetzelfde style-element toevoegen.
      if (document.getElementById('joetoep-link-callout')) return;
      const style = document.createElement('style');
      style.id = 'joetoep-link-callout';
      style.textContent = 'a[href]{-webkit-touch-callout:default!important}';
      (document.head || document.documentElement).appendChild(style);
    };
    // Meteen proberen, en ook nog eens zodra de basis-HTML van de pagina klaar is
    // geladen (DOMContentLoaded), voor het geval document.head er nog niet was.
    // { once: true } zorgt dat deze listener zichzelf na één keer weer opruimt.
    install(); document.addEventListener('DOMContentLoaded', install, { once: true });
  }
  // Zet een vlaggetje zodat een volgende keer dat dit script per ongeluk wordt geladen
  // (regel hierboven bij "if (window.JoeToepLinks) return") niets dubbel gebeurt.
  window.JoeToepLinks = true;
})();
