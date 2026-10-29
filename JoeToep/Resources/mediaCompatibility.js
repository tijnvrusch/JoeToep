/* JoeToep V10: scoped YouTube presentation compatibility, installed before site scripts.
 * Independent implementation informed by Brave's media-backgrounding design.
 * No polling, stream extraction, screenshots, or fake background activity.
 */
// Dit hele bestand is één grote IIFE: "(() => { ... })()" betekent een functie die je meteen
// (Immediately) aanroept (Invoked) en die zelf een functie is (Function Expression).
// Alles wat je hierbinnen met "const"/"let" aanmaakt blijft privé: de rest van de pagina
// (YouTube's eigen script) kan er niet bij komen. Zo voorkomen we dat onze variabelen
// per ongeluk botsen met variabelen van YouTube.
(() => {
  // "use strict" zet een strengere modus van JavaScript aan: typefouten (zoals een variabele
  // gebruiken die je vergat te declareren) geven meteen een fout in plaats van stil te falen.
  "use strict";
  // location.hostname is de domeinnaam van de huidige pagina (bijv. "www.youtube.com").
  // .toLowerCase() zet alles om naar kleine letters zodat de vergelijking hieronder altijd klopt.
  const host = location.hostname.toLowerCase();
  // Dit script mag alleen actief zijn op YouTube-pagina's (of, voor tests, op een lokaal
  // testbestand met de vlag JOETOEP_TEST). Klopt het domein niet, dan stoppen we meteen
  // met "return": de rest van de IIFE wordt dan gewoon niet uitgevoerd.
  if (!(host === "youtube.com" || host.endsWith(".youtube.com") ||
        host === "youtube-nocookie.com" || host.endsWith(".youtube-nocookie.com") ||
        (location.protocol === "file:" && window.JOETOEP_TEST))) return;
  // Voorkomt dat het script twee keer wordt geïnstalleerd (bijv. bij een dubbele injectie).
  if (window.JoeToepMedia) return;
  // JOETOEP_MOBILE wordt door de native app gezet: true op iPhone/iPad, anders (Mac) false/undefined.
  const platform = window.JOETOEP_MOBILE === true;
  // De standaardinstellingen. "let" (in plaats van "const") omdat configure() dit object later
  // mag vervangen/aanvullen.
  let config = { protect: true, automatic: true, nativeFullscreen: true, macFullscreen: "youtube", fallback: true, elementFullscreen: false, returnTarget: "fullscreen", keepPlaying: true };
  // Bewaar de originele (niet aangepaste) requestFullscreen-functie van de browser, vóórdat
  // we die verderop eventueel overschrijven. "||" pakt de webkit-variant als de gewone ontbreekt.
  const originalRequest = Element.prototype.requestFullscreen || Element.prototype.webkitRequestFullscreen;
  // V12: YouTube's own player container in WebKit element fullscreen, as on the desktop site.
  // WebKit prepares its automatic-PiP standby presenter for element fullscreen only.
  // Zoekt vanaf een <video>-element omhoog (closest = "dichtstbijzijnde voorouder die matcht")
  // naar de omringende YouTube-spelercontainer, zodat we DIE in fullscreen kunnen zetten
  // in plaats van alleen het kale video-element.
  const playerContainer = v => v.closest("#player-container-id, .player-container, #movie_player, .html5-video-player, ytm-player") || v.parentElement || v;
  // Vraagt "element fullscreen" aan (de browser-fullscreen van één stukje pagina, niet Apple's
  // eigen videofullscreen). "v" is het video-element.
  const elementFullscreen = v => {
    // Al in fullscreen? Dan is er niets te doen.
    if (document.fullscreenElement || document.webkitFullscreenElement) return true;
    if (typeof originalRequest !== "function") return false;
    // "?." is optional chaining: roep exit() alleen aan als JoeToepStage bestaat, anders
    // gebeurt er niets (geen foutmelding over "undefined is not a function").
    window.JoeToepStage?.exit();
    try {
      const result = originalRequest.call(playerContainer(v));
      // requestFullscreen() geeft een Promise terug. ".catch()" vangt op als de browser
      // de aanvraag afwijst (bijv. omdat er geen echte gebruikersklik aan vooraf ging).
      result?.catch?.(() => { lastStatus = "element-fullscreen-declined"; signal(); });
      return true;
    } catch (_) { lastStatus = "element-fullscreen-declined"; return false; }
  };
  // Bewaar hier de ORIGINELE, ongewijzigde browserfuncties vóórdat we ze verderop vervangen
  // door onze eigen versies. Zo kunnen we straks nog steeds "het echte werk" laten doen.
  const native = {
    play: HTMLMediaElement.prototype.play,
    pause: HTMLMediaElement.prototype.pause,
    exitPiP: document.exitPictureInPicture,
    presentation: HTMLVideoElement.prototype.webkitSetPresentationMode,
    fullscreen: HTMLVideoElement.prototype.webkitEnterFullscreen,
    visibility: Object.getOwnPropertyDescriptor(Document.prototype, "visibilityState"),
    hidden: Object.getOwnPropertyDescriptor(Document.prototype, "hidden")
  };
  // Al deze "let"-variabelen zijn de gedeelde toestand van het script: ze onthouden wat er
  // op dit moment aan de hand is (welke video, of de gebruiker pauzeerde, tot wanneer we
  // nog mogen "herstellen", enz.). "let" (niet "const") omdat hun waarde steeds verandert.
  let main = null, desiredPlaying = false, lastPauseAt = 0, userPause = false;
  let handoffUntil = 0, allowPauseUntil = 0, interrupted = false, recoveryUsed = false;
  let backgroundEpisode = false, fallbackRoot = null, lastStatus = "ready";
  let externalRequestUntil = 0;
  let lastPiPVideo = null;
  // Presentation the video had right before PiP began: return exactly there (no inline hop).
  let lastMode = "inline", pipOrigin = "inline";
  // Of de HUIDIGE PiP-overgang door het systeem zelf gestart is (bijv. schermvergrendeling)
  // in plaats van doordat de gebruiker zelf op de PiP-knop drukte.
  let systemHandoff = false;
  // V16: once PiP has settled, a pause (PiP window button, media key) is the user's intent and
  // must never be "recovered". Only the first moments of the handoff may be.
  let pipSince = 0, noFullscreenReturnUntil = 0;
  // Date.now() geeft het huidige tijdstip als getal (milliseconden sinds 1970). Door twee
  // van die getallen van elkaar af te trekken, meet je hoeveel tijd er verstreken is.
  // Hier: is de video al langer dan 600 ms in PiP? Dan is de overgang "settled" (klaar).
  const pipSettled = v => isPiP(v) && pipSince > 0 && Date.now() - pipSince > 600;
  // V15 (Mac): YouTube element fullscreen right before PiP counts as a fullscreen origin.
  let pageFullscreenAt = 0;
  // Boolean(...) zet een waarde om naar echt true/false. Hier: is er op dit moment een
  // fullscreen-element (gewoon of met webkit-prefix)?
  const pageFullscreen = () => Boolean(document.fullscreenElement || document.webkitFullscreenElement);
  // Luister naar het moment dat fullscreen AAN- of UITgaat. addEventListener's derde
  // argument "true" betekent "capture": wij horen de gebeurtenis eerder dan YouTube's
  // eigen code, zodat we altijd op tijd kunnen reageren.
  for (const name of ["fullscreenchange", "webkitfullscreenchange"])
    document.addEventListener(name, () => { pageFullscreenAt = Date.now(); if (pageFullscreen()) pageFullscreenAt = Infinity; }, true);
  // Moet PiP straks teruggaan naar fullscreen? Ja als dat expliciet ingesteld staat, of als
  // "origin" is gekozen én de PiP begon vanuit fullscreen.
  const wantsFullscreenReturn = () => config.returnTarget === "fullscreen" ||
    (config.returnTarget === "origin" && pipOrigin === "fullscreen");
  // V10: while a prepared native AVKit presenter owns background PiP, the web video must not
  // request its own (inline PiP cannot start after deactivation and would compete).
  let nativeOwner = false, nativeActive = false;
  // V11: lock/unlock and similar OS transitions may pause PiP without user intent; recover once.
  let transitionUntil = 0, transitionRecovered = false;
  let requestUntil = 0, interruptionWantsPlay = false;
  // Hoeveel milliseconden een "overdracht" (handoff) maximaal mag duren: 5 seconden.
  const handoffDuration = 5000;
  let returnUntil = 0, returnWantsPlay = false, returnRecoveryUsed = false;
  // Leest de ECHTE zichtbaarheid van het document, los van onze eigen "vermomming"
  // hieronder. native.visibility is de originele property-descriptor; ".get" is de
  // functie die de browser normaal zou gebruiken om de waarde op te vragen.
  const rawVisibility = () => native.visibility?.get?.call(document) || "visible";
  // Is deze video op dit moment in Picture-in-Picture (via Safari's webkit-modus of de
  // standaard PiP-API)?
  const isPiP = v => Boolean(v && (v.webkitPresentationMode === "picture-in-picture" || document.pictureInPictureElement === v));
  // Kiest de "hoofdvideo" waar dit script zich mee bemoeit: als de huidige er nog is en in
  // PiP staat, blijf daarbij; anders kies de speler-video, of anders de eerst spelende video.
  const pick = () => {
    // ?. (optional chaining): als "main" null is, wordt dit gewoon "undefined" in plaats
    // van een foutmelding. isConnected checkt of het element nog echt in de pagina zit.
    if (main?.isConnected && isPiP(main)) return main;
    const videos = Array.from(document.querySelectorAll("video"));
    const candidate = videos.find(v => v.classList.contains("html5-main-video")) ||
      videos.find(v => !v.paused && !v.ended) || videos[0] || null;
    // Is de gekozen video anders dan voorheen? Dan is dit een "nieuwe" video: reset alle
    // bijhorende status (of hij speelt, of de gebruiker pauzeerde, enz.).
    if (candidate !== main) {
      main = candidate; desiredPlaying = Boolean(main && !main.paused && !main.ended);
      userPause = false; lastPauseAt = 0; recoveryUsed = false;
    }
    return main;
  };
  // Stuurt een eigen (custom) event de pagina in, zodat andere delen van JoeToep (zoals
  // playerBridge.js) weten dat er iets veranderd is in de mediastatus.
  const signal = () => document.dispatchEvent(new Event("joetoep-media-state"));
  // Is dit een pagina waar echt een video wordt afgespeeld (kijkpagina, shorts, livestream
  // of embed)? .some() geeft true zodra minstens één van de voorvoegsels klopt.
  const isMediaPage = () => location.pathname === "/watch" ||
    ["/shorts/", "/live/", "/embed/"].some(prefix => location.pathname.startsWith(prefix)) ||
    (location.protocol === "file:" && window.JOETOEP_TEST);
  // Mag deze video door JoeToep "beschermd" worden tegen ongewenste pauzes? Alleen als
  // bescherming aanstaat, er geen onderbreking bezig is, het de gekozen hoofdvideo is,
  // hij niet afgelopen is, en we op een mediapagina/PiP/handoff-venster zitten.
  const eligible = v => Boolean(config.protect && !interrupted && v && v === pick() && !v.ended &&
    (isMediaPage() || isPiP(v) || Date.now() < handoffUntil));
  // Is deze video OP DIT MOMENT beschermd (dus mag een pauze geweigerd worden)?
  const protectedNow = v => eligible(v) && (isPiP(v) || Date.now() < handoffUntil ||
    (returnWantsPlay && Date.now() < returnUntil));
  // Moeten we doen alsof het document zichtbaar/op de voorgrond is, zodat YouTube niet
  // zelf besluit te pauzeren omdat de app "op de achtergrond" lijkt?
  const shouldMaskVisibility = () => {
    const v = pick();
    return eligible(v) && (isPiP(v) || desiredPlaying || Date.now() < handoffUntil);
  };
  // V12: mobile YouTube (unlike desktop) stops playback when it detects background use.
  // Mask every page-lifecycle signal it can read while the protected video plays or is in PiP.
  // Ook de "webkit"-varianten van visibility ophalen, voor oudere Safari-code die deze
  // nog gebruikt in plaats van de standaard "visibilityState"/"hidden".
  const webkitVisibility = Object.getOwnPropertyDescriptor(Document.prototype, "webkitVisibilityState");
  const webkitHidden = Object.getOwnPropertyDescriptor(Document.prototype, "webkitHidden");
  const nativeHasFocus = Document.prototype.hasFocus;
  // We overschrijven document.hasFocus() zodat die ook "true" teruggeeft wanneer we net
  // doen alsof de pagina zichtbaar is (shouldMaskVisibility), ook al is de app eigenlijk
  // naar de achtergrond gegaan.
  if (typeof nativeHasFocus === "function") {
    Document.prototype.hasFocus = function() { return (this === document && shouldMaskVisibility()) || nativeHasFocus.call(this); };
  }
  // Voor elke van deze vier eigenschappen (visibilityState, hidden, en hun webkit-varianten):
  // Object.defineProperty herschrijft de "getter" zodat die een neppe waarde (bijv. "visible")
  // teruggeeft zolang shouldMaskVisibility() true is; anders gewoon het echte antwoord.
  // "..." (spread) kopieert de rest van de originele descriptor (bijv. of hij configureerbaar is).
  for (const [key, descriptor, value] of [["visibilityState", native.visibility, "visible"], ["hidden", native.hidden, false],
                                          ["webkitVisibilityState", webkitVisibility, "visible"], ["webkitHidden", webkitHidden, false]]) {
    if (descriptor?.configurable && descriptor.get) {
      Object.defineProperty(Document.prototype, key, { ...descriptor,
        get() { return this === document && shouldMaskVisibility() ? value : descriptor.get.call(this); }
      });
    }
  }
  // We vervangen de PROTOTYPE-functie pause() van ELK <video>-element in de hele pagina.
  // Een "prototype" is het gedeelde sjabloon waar alle video-elementen hun functies vandaan
  // halen; door dat sjabloon aan te passen, verandert het gedrag van élke video tegelijk.
  // "...args" (rest-parameters) vangt alle meegegeven argumenten op in een array.
  HTMLMediaElement.prototype.pause = function(...args) {
    // Is deze video beschermd en heeft de gebruiker net niet zelf iets gedaan? Dan
    // weigeren we de pauze gewoon (we roepen native.pause niet aan) en stoppen.
    if (protectedNow(this) && Date.now() >= allowPauseUntil && !userPause) {
      lastStatus = "blocked-site-pause"; return;
    }
    // Anders: het is een "echte" pauze. Onthoud dat en voer de originele pause() uit.
    // ".apply(this, args)" roept de oorspronkelijke functie aan met dezelfde "this" en
    // argumenten alsof wij er nooit tussen hadden gezeten.
    if (this === pick() && !interrupted) { desiredPlaying = false; userPause = true; }
    return native.pause.apply(this, args);
  };
  // Hetzelfde principe, maar dan voor play(): soms willen we een afspeelverzoek van de
  // site zelf blokkeren (bijv. omdat een andere presentator al actief is, of de
  // gebruiker net zelf pauzeerde).
  HTMLMediaElement.prototype.play = function(...args) {
    if (nativeActive && this === pick()) { lastStatus = "blocked-site-play-native-pip"; return Promise.resolve(); }
    if (config.protect && this === pick() && userPause &&
        (isPiP(this) || rawVisibility() !== "visible") && Date.now() >= allowPauseUntil) {
      lastStatus = "blocked-site-resume-after-user-pause";
      return Promise.resolve();
    }
    // Op mobiel: zorg dat video's altijd "inline" mogen afspelen (niet automatisch
    // fullscreen), zodat JoeToep zelf de fullscreen/PiP-overgangen kan regisseren.
    if (platform && this.tagName === "VIDEO") {
      this.setAttribute("playsinline", ""); this.setAttribute("webkit-playsinline", "");
    }
    if (this === pick()) { desiredPlaying = true; userPause = false; }
    return native.play.apply(this, args);
  };
  // Als de browser de (verouderde) webkitSetPresentationMode-functie kent, overschrijven
  // we ook die: verlaat een video zijn PiP niet zomaar terwijl hij nog beschermd is.
  if (typeof native.presentation === "function") {
    HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) {
      if (mode !== "picture-in-picture" && isPiP(this) && protectedNow(this) && Date.now() >= allowPauseUntil) {
        lastStatus = "blocked-site-pip-exit"; return;
      }
      return native.presentation.call(this, mode);
    };
  }

  // Overschrijf ook het GLOBALE document.exitPictureInPicture(): als de video beschermd is,
  // negeren we het verzoek en geven we gewoon een "opgeloste" (lege) Promise terug.
  if (typeof native.exitPiP === "function") {
    document.exitPictureInPicture = function(...args) {
      const v = document.pictureInPictureElement;
      if (v && protectedNow(v) && Date.now() >= allowPauseUntil) return Promise.resolve();
      return native.exitPiP.apply(this, args);
    };
  }

  // One media owner: WebKit's Media Session delivers system controls to the
  // actual video. No competing MPRemoteCommandCenter or duplicate AVPlayer.
  // navigator.mediaSession is de browser-API die systeem-mediaknoppen (lockscreen,
  // koptelefoon, AirPods) aan de website koppelt.
  const mediaSession = navigator.mediaSession;
  const nativeSetAction = mediaSession?.setActionHandler;
  // Wordt aangeroepen wanneer het SYSTEEM (dus niet de website zelf) play/pause vraagt,
  // bijvoorbeeld via een knop op de koptelefoon of het vergrendelscherm.
  function remoteAction(action) {
    const v = pick();
    if (!v || !(isMediaPage() || isPiP(v))) return false;
    // Cancel every recovery budget BEFORE touching playback.
    handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
    recoveryUsed = true; returnRecoveryUsed = true;
    if (action !== "pause") quietUntil = 0;
    if (action === "pause") {
      userPause = true; desiredPlaying = false; interruptionWantsPlay = false;
      native.pause.call(v);
    } else {
      if (interrupted) return true;
      userPause = false; desiredPlaying = true;
      native.play.call(v)?.catch(() => { lastStatus = "remote-play-declined"; signal(); });
    }
    lastStatus = "remote-" + action;
    updateMediaState(); signal(); return true;
  }
  // Vertelt het systeem of de video nu speelt, gepauzeerd is, of klaar is, zodat het
  // vergrendelscherm/koptelefoonscherm de juiste play/pause-knop laat zien.
  function updateMediaState() {
    if (!mediaSession) return;
    const v = pick();
    if (!v || !(isMediaPage() || isPiP(v))) return;
    try { mediaSession.playbackState = v.ended ? "none" : v.paused ? "paused" : "playing"; } catch (_) {}
  }
  if (typeof nativeSetAction === "function") {
    // Object.getPrototypeOf haalt het "sjabloon"-object op waar mediaSession zijn functies
    // vandaan haalt, zodat we setActionHandler daar globaal kunnen vervangen.
    const proto = Object.getPrototypeOf(mediaSession);
    // Onze vervangende setActionHandler: voor play/pause proberen we EERST zelf te
    // reageren (remoteAction); lukt dat niet, dan geven we het door aan YouTube's eigen
    // handler ("handler"), zodat niets stuk gaat.
    const wrappedSetAction = function(action, handler) {
      if (this !== mediaSession || !["play", "pause"].includes(action))
        return nativeSetAction.call(this, action, handler);
      return nativeSetAction.call(this, action, details => {
        if (!remoteAction(action) && typeof handler === "function") handler(details);
      });
    };
    try {
      // Preserve wrapping when YouTube registers/replaces its own callbacks.
      Object.defineProperty(proto, "setActionHandler", { value: wrappedSetAction, configurable: true, writable: true });
      // Registreer onze wrapper meteen voor play en pause, zelfs vóórdat YouTube dat zelf doet.
      wrappedSetAction.call(mediaSession, "play", null);
      wrappedSetAction.call(mediaSession, "pause", null);
      // Bij elk van deze video-gebeurtenissen: werk het systeemstatusje bij.
      for (const event of ["playing", "pause", "ended", "loadedmetadata"])
        window.addEventListener(event, updateMediaState, true);
    } catch (_) { lastStatus = "media-session-unavailable"; }
  }

  // Real presentation events MUST reach the website. Blocking the exit notification
  // in V4 left YouTube's 'playing in PiP' placeholder behind after the system returned.
  // Wordt aangeroepen zodra de "presentatiemodus" van een video verandert: inline, PiP,
  // of fullscreen. "e.target" is het element waarop de gebeurtenis plaatsvond.
  const presentationChanged = e => {
    const v = e.target;
    if (v?.tagName !== "VIDEO" || v !== pick()) return;
    // Verlaat de video PiP net nu (was hij in PiP, en is hij dat nu niet meer)?
    const leavingPiP = !isPiP(v) && lastPiPVideo === v;
    if (isPiP(v) && lastPiPVideo !== v) {
      pipOrigin = lastMode;
      if (!platform && (pageFullscreen() || pageFullscreenAt === Infinity || Date.now() - pageFullscreenAt < 2500)) pipOrigin = "fullscreen";
    }
    lastPiPVideo = isPiP(v) ? v : null;
    lastMode = isPiP(v) ? "picture-in-picture" : (v.webkitPresentationMode || "inline");
    if (isPiP(v)) {
      // De video is (net) in PiP gegaan: onthoud sinds wanneer, en verberg onze eigen
      // fallback-knoppen (die zijn dan overbodig).
      if (!pipSince) pipSince = Date.now();
      requestUntil = 0;
      lastStatus = "system-pip-active";
      if (fallbackRoot) fallbackRoot.hidden = true;
    } else if (leavingPiP) {
      // De video komt terug uit PiP: bepaal of hij door moet spelen, en voor hoelang we
      // dat mogen "herstellen" als het systeem hem toch pauzeert.
      pipSince = 0;
      // V22: ✕ in het PiP-venster = stoppen. WebKit pauzeert de video vóórdat PiP eindigt;
      // de terugknop laat hem doorspelen. Gepauzeerd bij het verlaten → gesloten: niet hervatten,
      // geen fullscreen terug (ook niet via JoeToep), en blijven staan.
      if (v.paused && !v.ended) {
        desiredPlaying = false; userPause = true; returnWantsPlay = false;
        systemHandoff = false; handoffUntil = 0; externalRequestUntil = 0; requestUntil = 0;
        noFullscreenReturnUntil = Date.now() + 5000;
        window.__joetoepPiPClosedAt = Date.now();
        lastStatus = "system-pip-closed";
        try { if (v.webkitDisplayingFullscreen) v.webkitExitFullscreen(); } catch (_) {}
        document.dispatchEvent(new Event("joetoep-presentation-state"));
        return;
      }
      lastStatus = "system-pip-returned";
      systemHandoff = false; handoffUntil = 0; externalRequestUntil = 0; requestUntil = 0;
      returnWantsPlay = (desiredPlaying || (config.keepPlaying && !userPause)) && !interrupted && !v.ended;
      returnUntil = Date.now() + (config.keepPlaying ? 3000 : 1500); returnRecoveryUsed = false;
      recoverReturn();
    } else { lastStatus = "system-fullscreen-exit"; }
    // Laat de rest van JoeToep (playerBridge.js) weten dat de presentatiemodus veranderd is.
    document.dispatchEvent(new Event("joetoep-presentation-state"));
  };
  for (const name of ["webkitpresentationmodechanged", "enterpictureinpicture", "leavepictureinpicture"])
    window.addEventListener(name, presentationChanged, true);

  // Als de video net terugkwam uit PiP en eigenlijk door moest spelen, maar per ongeluk
  // gepauzeerd is blijven staan: hervat het afspelen (één keer, binnen het tijdvenster
  // "returnUntil").
  function recoverReturn() {
    const v = pick();
    if (!config.protect || !v || isPiP(v) || rawVisibility() !== "visible" ||
        !returnWantsPlay || userPause || interrupted || v.ended || Date.now() >= returnUntil || returnRecoveryUsed) return;
    if (v.paused) {
      returnRecoveryUsed = true;
      // native.play (de ONGEWIJZIGDE play-functie) aanroepen, met .catch om een eventuele
      // weigering van de browser (bijv. geen toestemming voor autoplay) af te vangen.
      native.play.call(v)?.catch(() => { lastStatus = "return-resume-declined"; });
    }
  }

  // Fullscreen teardown events can arrive AFTER PiP begins. Do not let the site
  // tear down the same video during that transition. Native controls are untouched.
  window.addEventListener("webkitendfullscreen", e => {
    if (e.target !== pick() || !isPiP(e.target) || !protectedNow(e.target)) return;
    document.dispatchEvent(new Event("joetoep-presentation-state"));
    // stopImmediatePropagation voorkomt dat YouTube's EIGEN listeners deze gebeurtenis
    // ook nog te zien krijgen, zodat de site niet in de war raakt door de dubbele events.
    e.stopImmediatePropagation();
  }, true);

  // Probeert Picture-in-Picture te starten voor de gekozen video. Geeft een object terug
  // met een "status" (bijv. "active", "requested", "not-ready", "unavailable"), zodat de
  // native app (Swift) weet wat er gebeurd is.
  const enterPiP = () => {
    const v = pick();
    if (!v || v.readyState < 1 || !v.videoWidth) return { status: "not-ready" };
    if (isPiP(v)) return { status: "active" };
    // Nog een verzoek in behandeling? Voorkom dubbele aanvragen kort na elkaar.
    if (Date.now() < requestUntil) return { status: "requested" };
    requestUntil = Date.now() + 1800;
    // Math.max pakt het grootste van de twee: verleng de handoff-periode, maar verkort
    // hem nooit als er al een langere loopt.
    handoffUntil = Math.max(handoffUntil, Date.now() + handoffDuration);
    try {
      v.removeAttribute("disablepictureinpicture");
      // Probeer eerst de standaard PiP-API (niet op mobiel: daar gebruiken we liever de
      // webkit-variant hieronder), anders de webkit-presentatiemodus, anders alsnog de
      // standaard API als niets anders werkt.
      if (!platform && typeof v.requestPictureInPicture === "function" && document.pictureInPictureEnabled !== false) {
        v.requestPictureInPicture().catch(error => { requestUntil = 0; lastStatus = "declined: " + error.name; signal(); });
      } else if (typeof native.presentation === "function" && v.webkitSupportsPresentationMode?.("picture-in-picture")) {
        native.presentation.call(v, "picture-in-picture");
      } else if (typeof v.requestPictureInPicture === "function") {
        v.requestPictureInPicture().catch(error => { requestUntil = 0; lastStatus = "declined: " + error.name; signal(); });
      } else { requestUntil = 0; return { status: "unavailable" }; }
      signal();
      return { status: isPiP(v) ? "active" : "requested" };
    } catch (error) { requestUntil = 0; lastStatus = "declined: " + error.name; return { status: "rejected", message: error.message }; }
  };
  // Probeert YouTube's EIGEN fullscreen-knop te gebruiken (liever dan onze eigen aanroep),
  // zodat het uiterlijk en gedrag exact hetzelfde blijft als wanneer de gebruiker zelf klikt.
  function youtubeFullscreen(v, direct = false) {
    // V15: a stale .ytp-fullscreen class after PiP made this return without entering fullscreen.
    if (pageFullscreen()) return true;
    const button = document.querySelector('.ytp-fullscreen-button');
    if (button && !direct) { button.click(); return true; }
    try {
      const player=document.querySelector('#movie_player') || v;
      if(player.requestFullscreen){player.requestFullscreen().catch(()=>{lastStatus="fullscreen-declined";signal();});return true;}
    } catch (_) {}
    return false;
  }
  // De centrale functie om fullscreen te starten, ongeacht platform of huidige modus:
  // ze kijkt naar de configuratie en kiest de juiste weg (Mac-vensterfullscreen, YouTube's
  // eigen knop, Apple's native video-fullscreen, of gewone elementfullscreen).
  const fullscreen = () => {
    const v = pick();
    if (!v || v.readyState < 1) return false;
    if (isPiP(v)) {
      if (!platform || nativeActive || typeof native.presentation !== "function") return false;
      // A stale or active WebKit PiP must never make fullscreen unreachable.
      try { native.presentation.call(v, "fullscreen"); return true; } catch (_) { return false; }
    }
    if (!platform) {
      // Op de Mac: als de instelling "eigen venster-fullscreen" wil in plaats van YouTube's
      // eigen fullscreen, gebruik dan JoeToepStage (een andere module) om dat te doen.
      if(config.macFullscreen !== "youtube" && window.JoeToepStage?.enter()) {
        document.dispatchEvent(new Event("joetoep-enter-window-fullscreen"));return true;
      }
      return youtubeFullscreen(v);
    }
    if (config.elementFullscreen) return elementFullscreen(v);
    if (!config.nativeFullscreen) return window.JoeToepStage?.enter() || false;
    window.JoeToepStage?.exit();
    try {
      if (typeof native.fullscreen === "function") { native.fullscreen.call(v); return true; }
    } catch (_) { lastStatus="apple-fullscreen-declined";signal(); }
    return false;
  };
  // Route YouTube's container fullscreen to Apple's video fullscreen on mobile.
  // Dit blok geldt alleen op mobiel (platform === true).
  if (platform) {
    if (typeof native.fullscreen === "function") {
      // Overschrijf webkitEnterFullscreen (wat YouTube zelf aanroept) zodat het, afhankelijk
      // van de instellingen, ofwel element-fullscreen, ofwel ons eigen "Stage"-venster,
      // ofwel de normale Apple-videofullscreen gebruikt.
      HTMLVideoElement.prototype.webkitEnterFullscreen = function() {
        if (config.elementFullscreen && this === pick()) { elementFullscreen(this); return; }
        if (!config.nativeFullscreen && this === pick()) {
          window.JoeToepStage?.enter(); return;
        }
        return native.fullscreen.call(this);
      };
    }
    // Overschrijf ook de gewone requestFullscreen-varianten van ELK element, zodat een
    // klik ergens in de spelercontainer altijd via onze eigen fullscreen()-functie loopt.
    for (const key of ["requestFullscreen", "webkitRequestFullscreen", "webkitRequestFullScreen"]) {
      const original = Element.prototype[key];
      if (typeof original !== "function") continue;
      Element.prototype[key] = function(...args) {
        const v = pick();
        if (config.elementFullscreen && v && this.contains(v) && this !== v) return original.apply(this, args);
        if (v && (this === v || this.contains(v)) && fullscreen()) {
          return key === "requestFullscreen" ? Promise.resolve() : undefined;
        }
        return original.apply(this, args);
      };
    }
    // Vang ook directe klikken op YouTube's eigen fullscreen-knoppen af (verschillende
    // CSS-selectors voor de diverse spelervarianten van YouTube), zodat wij de controle
    // houden in plaats van YouTube's eigen fullscreen-logica.
    window.addEventListener("click", e => {
      if (!e.isTrusted) return;
      const button = e.target?.closest?.(".ytp-fullscreen-button, ytm-fullscreen-button-renderer, .player-control-fullscreen-icon, .player-fullscreen-button, button.fullscreen-icon, .fullscreen-icon");
      if (button && fullscreen()) { e.preventDefault(); e.stopImmediatePropagation(); }
    }, true);
  }

  // ── Recognising a REAL pause by the user ───────────────────────────────────────────────
  // JoeToep protects playback against pauses the user did not ask for (YouTube pausing when
  // the app goes to the background, macOS pausing during a PiP hand-over, …). To do that it
  // must know the difference between "YouTube/the system paused" and "Tijn paused".
  // The only reliable sign of the user is a trusted pointer or keyboard event: a click
  // that really came from the mouse/finger (e.isTrusted is true; scripts cannot fake it).
  //
  // V16.2.1 bug fix: before, only the play/pause BUTTON counted. Clicking on the video
  // picture itself (YouTube pauses on a click there too) was not recognised, so inside the
  // protected windows (3 s after returning from PiP, during a hand-over) the pause was
  // treated as unwanted and playback resumed: "it pauses for a moment and plays again".
  // These selectors cover every place where a click pauses/plays a YouTube video.
  const userPauseTargets = [
    ".ytp-play-button",                 // desktop player: the ▶/❚❚ button in the control bar
    ".player-control-play-pause-icon",  // mobile player: the big centre ▶/❚❚ button
    "video",                            // the video picture itself (click = pause/play)
    ".html5-video-container",           // the box around the video picture
    ".ytp-cued-thumbnail-overlay",      // the still image shown before a video starts
    ".html5-video-player",              // the whole desktop player area (fullscreen included)
    "#movie_player",                    // YouTube's id for that same player element
    ".player-controls-background",      // mobile: the dark layer that toggles pause on tap
    "a[href]"                           // following a link also stops the current video
  ].join(", ");                         // one CSS selector string: "a, b, c, …"
  // Marks the next 1.2 s as "the user is in control": pauses in that window are respected.
  const markUserIntent = () => { allowPauseUntil = Date.now() + 1200; };
  // V22: "stil" na een sync-wijziging: een video in een tab die van een ander apparaat komt,
  // mag niet zelf gaan spelen (YouTube-autoplay, seekTo op een gepauzeerde speler). Alleen een
  // echte klik/toets of een opdracht van JoeToep zelf (remoteAction) start hem.
  let quietUntil = 0, lastGestureAt = 0;
  for (const t of ["pointerdown", "touchstart", "keydown", "mousedown"])
    window.addEventListener(t, e => { if (e.isTrusted) lastGestureAt = Date.now(); }, true);
  const quietGuard = e => {
    if (Date.now() >= quietUntil || Date.now() - lastGestureAt < 1500) return;
    const v = e.target; if (!(v instanceof HTMLMediaElement)) return;
    desiredPlaying = false; userPause = true; returnWantsPlay = false;
    try { native.pause.call(v); } catch (_) {}
    lastStatus = "sync-quiet-blocked-autoplay";
  };
  window.addEventListener("play", quietGuard, true);
  window.addEventListener("playing", quietGuard, true);
  window.addEventListener("pointerdown", e => {  // fires on every mouse press / finger touch
    if (!e.isTrusted) return;                     // ignore clicks that scripts simulate
    // closest() walks up from the clicked element to its parents and returns the first one
    // that matches the selector (or null). So a click on any child of the player counts too.
    if (e.target?.closest?.(userPauseTargets)) markUserIntent();
  }, true);                                       // true = capture: we see it before YouTube does
  // Keyboard: space, K (YouTube shortcut) and the media play/pause key are user intent too,
  // unless the user is typing in a text field (then space is just a space).
  window.addEventListener("keydown", e => {
    if (e.isTrusted && [" ", "k", "K", "MediaPlayPause"].includes(e.key) &&
        !e.target?.closest?.("input, textarea, [contenteditable='true']")) markUserIntent();
  }, true);
  // Zodra de video echt begint te spelen: onthoud dat we willen dat hij speelt, en dat de
  // gebruiker hem niet (meer) gepauzeerd heeft.
  window.addEventListener("playing", e => {
    if (e.target === pick()) { desiredPlaying = true; userPause = false; lastPauseAt = 0; }
  }, true);
  // The "pause" event fires AFTER a video has paused, whoever paused it. Below we decide
  // whether that pause should stand or be undone (resumed).
  window.addEventListener("pause", e => {
    if (e.target !== pick()) return;              // only the main video matters
    lastPauseAt = Date.now();                     // remember when it happened
    if (interrupted) return; // An interruption (phone call, Siri, …) is not a user pause.
    // V16.2.1: the user just clicked the video / pressed space: always respect it, never
    // resume. Clearing returnWantsPlay/handoff stops every recovery path below.
    if (Date.now() < allowPauseUntil) {
      desiredPlaying = false; userPause = true;   // the user wants it paused
      returnWantsPlay = false; handoffUntil = 0; systemHandoff = false;
      lastStatus = "user-pause"; return;
    }
    // PiP is al een tijdje "settled" (rustig, geen overgang meer bezig): een pauze nu is
    // dus echt de gebruiker die op de PiP-pauzeknop drukte, niet het systeem.
    if (pipSettled(main) && Date.now() >= transitionUntil) {
      desiredPlaying = false; userPause = true; handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
      lastStatus = "pip-user-pause"; return;
    }
    // Vlak na een OS-overgang (bijv. schermvergrendeling) tijdens PiP: dit is waarschijnlijk
    // geen echte gebruikerspauze, dus hervat het afspelen (maximaal één keer).
    if (isPiP(main) && Date.now() < transitionUntil && !transitionRecovered && desiredPlaying && !userPause) {
      transitionRecovered = true; lastStatus = "pip-transition-pause-recovered";
      native.play.call(main)?.catch(() => { lastStatus = "pip-transition-resume-declined"; });
      return;
    }
    // We zitten in het "terugkeer uit PiP"-venster en willen doorspelen: probeer te
    // herstellen; lukt dat niet (nog steeds gepauzeerd), accepteer dan alsnog de pauze.
    if (!isPiP(main) && returnWantsPlay && Date.now() < returnUntil) {
      recoverReturn();
      if (main.paused) { desiredPlaying = false; userPause = true; }
      return;
    }
    // An OS pause during the short swipe handoff is not necessarily user intent.
    // Recover at most once, including the brief period when PiP is already visible.
    if (systemHandoff && eligible(main) && desiredPlaying && !userPause &&
        Date.now() < handoffUntil && Date.now() >= allowPauseUntil && !recoveryUsed) {
      recoveryUsed = true;
      native.play.call(main)?.catch(() => { lastStatus = "resume-declined"; });
    } else if (isPiP(main)) { desiredPlaying = false; userPause = true; }
    else if (eligible(main) && backgroundEpisode && rawVisibility() !== "visible" &&
             desiredPlaying && !userPause && Date.now() < handoffUntil && !recoveryUsed) {
      // Some OS versions pause after visibilitychange instead of before it.
      recoveryUsed = true;
      native.play.call(main)?.catch(() => { lastStatus = "resume-declined"; });
    }
  }, true);
  // Zodra de video is afgelopen: we willen hem niet meer als "moet spelen" beschouwen.
  window.addEventListener("ended", e => {
    if (e.target === pick()) { desiredPlaying = false; handoffUntil = 0; }
  }, true);
  // Deze vier gebeurtenissen kunnen allemaal signaleren dat de pagina naar de achtergrond
  // gaat. We onderscheppen ze (stopImmediatePropagation) zodat YouTube's EIGEN code ze niet
  // ziet en daardoor niet zelf besluit te pauzeren, zolang we toch "zichtbaar" doen alsof.
  for (const name of ["webkitvisibilitychange", "pagehide", "freeze", "blur"]) {
    window.addEventListener(name, e => {
      if (name === "blur" && e.target !== window && e.target !== document) return;
      if (name === "pagehide" && e.persisted === false && !isPiP(pick())) return; // real unload
      const hidden = rawVisibility() !== "visible" || name === "blur";
      if (platform && hidden && shouldMaskVisibility()) e.stopImmediatePropagation();
    }, true);
  }
  // De belangrijkste gebeurtenis: de pagina wordt zichtbaar of onzichtbaar (bijv. de app
  // gaat naar de achtergrond of komt terug). Hier beslissen we of we automatisch PiP
  // moeten starten om het afspelen te laten doorgaan.
  window.addEventListener("visibilitychange", e => {
    const v = pick(), hidden = rawVisibility() !== "visible";
    // Wordt de pagina weer zichtbaar? Reset dan alle "achtergrond"-status.
    if (!hidden) { backgroundEpisode = false; recoveryUsed = false; handoffUntil = 0; systemHandoff = false; recoverReturn(); }
    if (hidden && !backgroundEpisode) {
      backgroundEpisode = true;
      const recentSystemPause = v?.paused && lastPauseAt > 0 && Date.now() - lastPauseAt < 750;
      if (config.automatic && eligible(v) && !userPause && desiredPlaying && (!v.paused || recentSystemPause)) {
        handoffUntil = Date.now() + handoffDuration;
        systemHandoff = true;
        // Exactly one recovery for a system pause immediately before backgrounding.
        if (v.paused && !isPiP(v) && lastPauseAt > 0 && Date.now() - lastPauseAt < 750 && !recoveryUsed) {
          recoveryUsed = true;
          native.play.call(v)?.catch(() => { lastStatus = "resume-declined"; });
        }
        // Fullscreen iOS owns automatic PiP. Swift observes it before attempting rescue.
        const nativeFullscreen = platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen);
        if (!platform && !nativeFullscreen && Date.now() >= externalRequestUntil) enterPiP();
      }
    }
    if (shouldMaskVisibility()) e.stopImmediatePropagation();
    signal();
  }, true);

  // Bouwt (of toont) een noodknopje rechtsboven in beeld waarmee de gebruiker zelf PiP of
  // fullscreen kan starten, voor als de automatische aanpak een keer niet lukt.
  function showFallback() {
    if (!config.fallback || !pick() || !document.body) return false;
    if (!fallbackRoot) {
      // document.createElement maakt een nieuw HTML-element aan (nog niet zichtbaar tot je
      // het ergens in de pagina plakt met appendChild).
      fallbackRoot = document.createElement("div");
      fallbackRoot.id = "joetoep-native-controls";
      fallbackRoot.style.cssText = "position:fixed;right:10px;top:10px;z-index:2147483647;gap:4px;background:#000;border-radius:10px;padding:4px;color:white";
      // Maak voor elke actie (PiP, Fullscreen) een eigen knop aan en koppel de bijbehorende
      // functie aan de klik.
      for (const [title, action] of [["PiP", enterPiP], ["Fullscreen", fullscreen]]) {
        const button = document.createElement("button");
        button.textContent = title; button.type = "button";
        button.style.cssText = "color:white;background:#161616;border:0;border-radius:7px;min-width:44px;min-height:44px;font:13px system-ui;padding:0 10px";
        button.addEventListener("click", e => { e.stopPropagation(); action(); });
        fallbackRoot.appendChild(button);
      }
      document.body.appendChild(fallbackRoot);
    }
    fallbackRoot.hidden = false; return true;
  }
  // Bereidt een "overdracht" voor: markeert een tijdsvenster waarin een pauze niet meteen
  // als definitief wordt gezien, zodat de video kan doorspelen tijdens een overgang
  // (bijv. het wisselen van app of het starten van PiP).
  function prepareHandoff(system = false) {
    pick(); returnUntil = 0; returnWantsPlay = false;
    const continuing = system && systemHandoff && Date.now() < handoffUntil;
    if (!continuing) { recoveryUsed = false; handoffUntil = Date.now() + handoffDuration; }
    systemHandoff = Boolean(system); externalRequestUntil = Date.now() + 2200; return true;
  }
  // Wordt door de native app aangeroepen wanneer de gebruiker de app verlaat (bijv. naar
  // het beginscherm) terwijl er een video speelt: probeert automatisch PiP te starten
  // zodat het afspelen gewoon doorgaat.
  function beginAutomaticHandoff() {
    const v = pick();
    if (!config.automatic || !isMediaPage() || interrupted) return { status: "skipped" };
    if (!v || v.ended || userPause || (!desiredPlaying && v.paused)) return { status: "paused" };
    if (v.paused && !(lastPauseAt && Date.now() - lastPauseAt < 750)) return { status: "paused" };
    prepareHandoff(true);
    if (isPiP(v)) return { status: "active" };
    if (platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen))
      return { status: "system-fullscreen" };
    if (nativeOwner) return { status: "native-owner" };
    // iOS cannot start an inline PiP once the scene deactivates (AVKit refuses; WebKit only
    // prepares automatic PiP in fullscreen). A futile request flashed PiP and hitched audio.
    if (platform) return { status: "inline-background" };
    return enterPiP();
  }
  // Is de bron van deze video een gewone (http/https) URL, en geen "blob:"-URL (die
  // JavaScript zelf in het geheugen opbouwt)? /^https?:/ is een regular expression (patroon)
  // dat controleert of de tekst begint met "http:" of "https:".
  const isURLSource = v => Boolean(v?.currentSrc && !v.currentSrc.startsWith("blob:") && /^https?:/.test(v.currentSrc));
  // Geeft een overzicht (object) van alles wat de native app moet weten over de huidige
  // video: waar hij vandaan komt, of hij speelt, in welke modus hij staat, enzovoort.
  function sourceInfo() {
    const v = pick();
    if (!v) return { status: "none" };
    return { status: "ok", url: isURLSource(v) ? v.currentSrc : null, blob: Boolean(v.currentSrc?.startsWith("blob:")),
      time: v.currentTime || 0, duration: Number.isFinite(v.duration) ? v.duration : 0, rate: v.playbackRate || 1, playing: !v.paused && !v.ended, userPause, ended: v.ended,
      fullscreen: Boolean(platform && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen)),
      pip: isPiP(v), media: isMediaPage(), ready: v.readyState, width: v.videoWidth || 0,
      wireless: Boolean(v.webkitCurrentPlaybackTargetIsWireless), ua: navigator.userAgent };
  }
  // Native presenter became audible: silence the web video without recording user intent.
  function nativeHandoff() {
    const v = pick();
    nativeActive = true; handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
    if (!v) return { status: "none" };
    const wasPlaying = !v.paused && !v.ended;
    if (wasPlaying) native.pause.call(v);
    lastStatus = "native-pip-handoff"; signal();
    return { status: "paused", wasPlaying, time: v.currentTime || 0 };
  }
  // Native PiP ended: continue the same web video exactly where PiP was.
  function nativeReturn(time, play, restore) {
    const v = pick();
    nativeActive = false;
    if (!v) return { status: "none" };
    try { if (Number.isFinite(time) && time >= 0 && Math.abs((v.currentTime || 0) - time) > 0.3) v.currentTime = time; } catch (_) {}
    if (!restore) {  // V22: ✕ = stoppen, geen fullscreen terug
      noFullscreenReturnUntil = Date.now() + 5000; window.__joetoepPiPClosedAt = Date.now();
      returnWantsPlay = false; play = false;
      try { if (!v.paused) native.pause.call(v); } catch (_) {}
    }
    if (play) {
      userPause = false; desiredPlaying = true;
      native.play.call(v)?.catch(() => { lastStatus = "native-return-play-declined"; signal(); });
    } else { desiredPlaying = false; userPause = true; }
    lastStatus = restore ? "native-pip-restored" : "native-pip-closed"; signal();
    return { status: "ok" };
  }
  // Brengt de video terug vanuit (systeem-)PiP naar de app, eventueel rechtstreeks naar
  // fullscreen in plaats van eerst "inline" te tonen.
  function returnToApp(fullscreenReturn = false) {
    const v = pick();
    if (!v) return false;
    if (!isPiP(v)) { recoverReturn(); return true; }
    returnWantsPlay = (desiredPlaying || (config.keepPlaying && !userPause)) && !v.ended && !interrupted;
    returnUntil = Date.now() + (config.keepPlaying ? 3000 : 1500); returnRecoveryUsed = false;
    handoffUntil = 0; systemHandoff = false; externalRequestUntil = 0;
    try {
      // iOS: the standard exitPictureInPicture() always lands inline first, which produced the
      // visible fullscreen -> small -> fullscreen sequence. Go PiP -> fullscreen in one step.
      const toFullscreen = platform && config.nativeFullscreen && native.presentation && config.returnTarget !== "inline" &&
        (fullscreenReturn === "origin" ? wantsFullscreenReturn() : fullscreenReturn === true);
      if (toFullscreen) native.presentation.call(v, "fullscreen");
      else if (document.pictureInPictureElement && native.exitPiP)
        native.exitPiP.call(document)?.catch(() => { lastStatus = "return-declined"; });
      else if (native.presentation) native.presentation.call(v, "inline");
      return true;
    } catch (_) { lastStatus = "return-declined"; return false; }
  }
  // Hier maken we het "publieke" object waarmee de native (Swift) app dit script bestuurt:
  // window.JoeToepMedia. Object.defineProperty met writable:false/configurable:false zorgt
  // dat de website dit object later niet kan overschrijven of verwijderen.
  // Object.freeze maakt het object zelf onveranderlijk: niemand kan er functies aan
  // toevoegen of bestaande vervangen.
  Object.defineProperty(window, "JoeToepMedia", { value: Object.freeze({
    // Past de instellingen aan met nieuwe waarden ("next"). De spread "..." kopieert eerst
    // alle bestaande instellingen, en overschrijft daarna alleen wat in "next" zit.
    configure(next) { config = { ...config, ...next }; if (!config.fallback && fallbackRoot) fallbackRoot.hidden = true; return true; },
    quiet(ms) { quietUntil = ms > 0 ? Date.now() + ms : 0; return true; },
    prepareHandoff, beginAutomaticHandoff, returnToApp, remoteAction, sourceInfo, nativeHandoff, nativeReturn,
    // Record explicit user intent when the site's own player performs the action.
    noteIntent(action) {
      handoffUntil = 0; systemHandoff = false; returnWantsPlay = false; recoveryUsed = true; returnRecoveryUsed = true;
      if (action === "pause") { userPause = true; desiredPlaying = false; allowPauseUntil = Date.now() + 1200; }
      else { userPause = false; desiredPlaying = true; }
      return true;
    },
    // V12: rotating back to portrait leaves fullscreen and keeps the same video playing inline.
    exitFullscreenKeepPlaying() {
      const v = pick();
      if (!v || isPiP(v)) return false;
      const wasPlaying = !v.paused && !v.ended;
      try {
        if (document.fullscreenElement || document.webkitFullscreenElement) (document.exitFullscreen || document.webkitExitFullscreen)?.call(document)?.catch?.(() => {});
        else if (v.webkitDisplayingFullscreen || v.webkitPresentationMode === "fullscreen") v.webkitExitFullscreen?.();
        else return false;
      } catch (_) { return false; }
      if (wasPlaying) {
        returnWantsPlay = true; returnUntil = Date.now() + 2000; returnRecoveryUsed = false; desiredPlaying = true; userPause = false;
        // setTimeout voert de functie pas na 450 milliseconden uit: geef de browser even de
        // tijd om de fullscreen echt af te sluiten voordat we proberen door te spelen.
        setTimeout(() => { const now = pick(); if (now === v && v.paused && !userPause && !interrupted) native.play.call(v)?.catch(() => {}); }, 450);
      }
      return true;
    },
    // Wordt aangeroepen bij een OS-overgang (bijv. scherm ontgrendelen): geeft 2,5 seconden
    // waarin een pauze mogelijk hersteld mag worden in plaats van als "echt" gezien te worden.
    platformTransition() { transitionUntil = Date.now() + 2500; transitionRecovered = false; return true; },
    // Vertelt dit script of een NATIVE presentator (bijv. AVKit-PiP van Swift zelf) nu de
    // baas is over het geluid/beeld, zodat de webvideo niet gaat concurreren.
    setNativeOwner(value) { nativeOwner = Boolean(value); if (!nativeOwner) nativeActive = false; return nativeOwner; },
    // Opent de systeem-AirPlay-kiezer voor deze video (om draadloos naar tv/speaker te sturen).
    showVideoAirPlay() {
      const v = pick();
      if (!v || v.readyState < 1) return "not-ready";
      v.removeAttribute("disableremoteplayback");
      v.disableRemotePlayback = false;
      v.webkitWirelessVideoPlaybackDisabled = false;
      v.setAttribute("x-webkit-airplay", "allow");
      try {
        if (typeof v.webkitShowPlaybackTargetPicker !== "function") return "unavailable";
        v.webkitShowPlaybackTargetPicker(); return "requested";
      } catch (_) { return "unavailable"; }
    },
    // Zet alle "wachttimers" terug op nul en verlaat PiP indien nodig: een schone lei.
    resetPiP() {
      requestUntil = handoffUntil = externalRequestUntil = returnUntil = 0;
      systemHandoff = false; recoveryUsed = false; returnWantsPlay = false;
      const v = pick();
      if (!v) return "not-ready";
      if (isPiP(v)) { returnToApp(false); return "exiting"; }
      return "ready";
    },
    // V16: another tab's video starts: leave PiP to inline (paused), never to fullscreen.
    closePiPInline() {
      const v = pick();
      returnWantsPlay = false; handoffUntil = 0; systemHandoff = false; desiredPlaying = false; userPause = true;
      allowPauseUntil = Date.now() + 1500; noFullscreenReturnUntil = Date.now() + 3000;
      if (!v || !isPiP(v)) return false;
      try {
        if (document.pictureInPictureElement && native.exitPiP) native.exitPiP.call(document)?.catch(() => {});
        else if (native.presentation) native.presentation.call(v, "inline");
      } catch (_) { return false; }
      return true;
    },
    // Geeft de huidige presentatiemodus terug als tekst, voor de native app.
    actualPresentation() { const v = pick(); return isPiP(v) ? "picture-in-picture" : v?.webkitPresentationMode || "inline"; },
    // Breekt een lopende "overdracht" meteen af (bijv. als de gebruiker toch weer terug is).
    cancelHandoff() { requestUntil = 0; handoffUntil = 0; externalRequestUntil = 0; systemHandoff = false; return true; },
    // Meldt een ONDERBREKING (bijv. een telefoontje of Siri) die begint (value=true) of
    // eindigt (value=false, met canResume of we daarna mogen doorspelen).
    setInterrupted(value, canResume = false) {
      const v = pick();
      if (value) {
        if (!interrupted) interruptionWantsPlay = Boolean(v && desiredPlaying && !userPause && !v.ended);
        interrupted = true; handoffUntil = 0;
      } else {
        const resume = interrupted && canResume && interruptionWantsPlay && !userPause && v && !v.ended;
        interrupted = false; interruptionWantsPlay = false;
        if (resume) {
          desiredPlaying = true;
          native.play.call(v)?.catch(() => { lastStatus = "interruption-resume-declined"; signal(); });
        }
      }
      updateMediaState(); signal();
    },
    // Geeft de gebruiker 1,2 seconden "vrije wil": een pauze in die tijd wordt zeker
    // gerespecteerd (bijv. omdat de app zelf iets aan het afsluiten is).
    allowExit() { allowPauseUntil = Date.now() + 1200; handoffUntil = 0; systemHandoff = false; returnWantsPlay = false; },
    // Deze drie functies (hierboven al gedefinieerd) worden gewoon met hun bestaande naam
    // toegevoegd aan het publieke object, als kortere schrijfwijze van bijv. "enterPiP: enterPiP".
    enterPiP, fullscreen, showFallback,
    // Wordt aangeroepen wanneer de gebruiker WEGNAVIGEERT (bijv. een andere video kiest):
    // stop het beschermen en sluit fullscreen/PiP netjes af.
    leaveForNavigation() {
      const v = pick();
      allowPauseUntil = Date.now() + 1200;
      handoffUntil = 0; systemHandoff = false; returnWantsPlay = false;
      desiredPlaying = false; userPause = true;
      window.JoeToepStage?.exit();
      returnToApp();
      try {
        if (v && (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen)) v.webkitExitFullscreen?.();
        if (document.fullscreenElement) document.exitFullscreen?.()?.catch(() => {});
      } catch (_) {}
      return true;
    },
    // Probeert fullscreen te herstellen nadat de video ergens anders vandaan komt
    // (bijv. terug uit PiP), maar alleen als dat volgens de instellingen ook gewenst is.
    restoreFullscreen(retry = false) {
      const v = pick();
      if (!v || isPiP(v) || v.readyState < 1) return false;
      if (v.webkitPresentationMode === "fullscreen" || v.webkitDisplayingFullscreen) return true;
      if (!wantsFullscreenReturn()) return false; // e.g. inline PiP with "where PiP started"
      if (Date.now() < noFullscreenReturnUntil) return false; // V16: handed over to another tab
      if (!platform && config.macFullscreen === "youtube") {
        if (pageFullscreen()) return true;
        // Retry: request the player element directly (the button may be mid-transition).
        return youtubeFullscreen(v, retry);
      }
      return fullscreen();
    },
    // Verzamelt een groot overzicht van de interne status, handig om problemen op te sporen
    // (debuggen) vanuit de native app zonder de website zelf te hoeven aanpassen.
    diagnostics: () => {
      const v = pick();
      return { status: lastStatus, mediaSessionAvailable: typeof nativeSetAction === "function", interrupted, rawVisibility: rawVisibility(), recoveryUsed, platform,
          pipOrigin, lastMode, nativeOwner, nativeActive, systemHandoff, requestPending: Date.now() < requestUntil, desiredPlaying, userPause, interruptionWantsPlay, protectedHandoff: Date.now() < handoffUntil,
        videoConnected: Boolean(v?.isConnected), paused: v?.paused, readyState: v?.readyState,
        width: v?.videoWidth, height: v?.videoHeight, time: v?.currentTime,
        mode: v?.webkitPresentationMode || "unknown",
        standardPiP: typeof v?.requestPictureInPicture === "function",
        standardEnabled: document.pictureInPictureEnabled,
        prefixedPiP: Boolean(v?.webkitSupportsPresentationMode?.("picture-in-picture")),
        sourceKind: v?.currentSrc?.startsWith("blob:") ? "MediaSource/blob" : v?.currentSrc ? "URL" : "none" };
    }
  }), configurable: false, writable: false });
})();
