/* Shared keyboard/trackpad controls; no periodic work, no duplicate media player. */
// Deze IIFE (meteen aangeroepen functie) voegt toetsenbord- en trackpad-bediening toe
// aan de video: pijltjes om te spoelen/volume te wijzigen, spatie om te pauzeren, en
// twee-vinger swipes (wheel-event) in fullscreen.
(() => {
  'use strict';
  // Alleen actief als de basisbridge (JoeToepMedia) er al is, en niet dubbel opzetten.
  if (!window.JoeToepMedia || window.JoeToepControls) return;
  // Zoekt het video-element van de pagina op (YouTube's hoofdvideo, of anders de eerste
  // <video> die er is).
  // V19: instelbaar vanuit de app (Instellingen › Playback › Gestures).
  const cfg = {swipeSeek: 5, keySeek: 5, volumeStep: 0.01, swipeThreshold: 28, showControlsOnSwipe: true, scrubThumbnail: true, showControlsOnKeys: false};
  const pick = () => document.querySelector('video.html5-main-video') || document.querySelector('video');
  // Checkt of het element waarop getypt wordt een tekstveld is (input, textarea, etc.),
  // zodat onze sneltoetsen daar niet per ongeluk ingrijpen terwijl iemand aan het typen is.
  const editable = target => target?.closest?.('input,textarea,select,[contenteditable="true"],[role="textbox"]');
  // Geeft het bereik terug waarbinnen je mag spoelen: [begin, eind] in seconden.
  // v.seekable is de info die de browser bijhoudt over welk deel van de video al
  // beschikbaar is om naartoe te springen (bij livestreams is dat niet [0, duration]).
  function bounds(v) {
    try { if (v.seekable.length) return [v.seekable.start(0),v.seekable.end(v.seekable.length-1)]; } catch (_) {}
    return Number.isFinite(v.duration) && v.duration > 0 ? [0,v.duration] : null;
  }
  // Spoelt "delta" seconden vooruit (positief) of achteruit (negatief), maar nooit
  // buiten het toegestane bereik (Math.max/Math.min knijpen de waarde daartussen).
  // V18: bij YouTube via de eigen speler (movie_player) — dan blijven YouTube's tijdbalk,
  // volumeschuif en interne status gelijk — terwijl de bedieningslaag onzichtbaar blijft.
  const ytPlayer = () => { const p=document.getElementById('movie_player'); return p && typeof p.seekTo==='function' ? p : null; };
  // Verbergt YouTube's controls/"bezel" (het ◀◀ 5 / 🔊-plaatje) heel even na onze bediening.
  function hideOverlay() {
    const p=document.getElementById('movie_player'); if(!p) return;
    let st=document.getElementById('joetoep-quiet-controls');
    if(!st){st=document.createElement('style');st.id='joetoep-quiet-controls';
      st.textContent='#movie_player.joetoep-quiet .ytp-chrome-bottom,#movie_player.joetoep-quiet .ytp-chrome-top,#movie_player.joetoep-quiet .ytp-gradient-bottom,#movie_player.joetoep-quiet .ytp-gradient-top,#movie_player.joetoep-quiet .ytp-bezel,#movie_player.joetoep-quiet .ytp-bezel-text-wrapper,#movie_player.joetoep-quiet .ytp-doubletap-ui-legacy,#movie_player.joetoep-quiet .ytp-seek-overlay,#movie_player.joetoep-quiet .ytp-volume-hud{opacity:0 !important;visibility:hidden !important;transition:none !important}';
      (document.head||document.documentElement).appendChild(st);}
    p.classList.add('joetoep-quiet');
    // Zonder "ytp-autohide" toont YouTube de balk bij de eerstvolgende muisbeweging; met blijft hij weg.
    p.classList.add('ytp-autohide');
    clearTimeout(hideOverlay.t);
    hideOverlay.t=setTimeout(()=>p.classList.remove('joetoep-quiet'),1200);
  }
  // V19: YouTube's bediening tonen (en optioneel het voorbeeldplaatje op de tijdbalk) tijdens
  // het scrubben met een veeg: we "bewegen" de muis over de tijdbalk op de nieuwe positie, dan
  // tekent YouTube zelf zijn balk + storyboard-thumbnail.
  function revealAt(p, time, duration) {
    try {
      p.classList.remove('joetoep-quiet','ytp-autohide');
      p.dispatchEvent(new MouseEvent('mousemove',{bubbles:true,clientX:10,clientY:10}));
      if (!cfg.scrubThumbnail || !Number.isFinite(duration) || duration <= 0) return;
      const bar=p.querySelector('.ytp-progress-bar'); if(!bar) return;
      const r=bar.getBoundingClientRect(); if(!r.width) return;
      const x=r.left+r.width*Math.max(0,Math.min(1,time/duration)), y=r.top+r.height/2;
      for (const type of ['mouseover','mousemove']) bar.dispatchEvent(new MouseEvent(type,{bubbles:true,clientX:x,clientY:y}));
      clearTimeout(revealAt.t);
      revealAt.t=setTimeout(()=>{ try{ bar.dispatchEvent(new MouseEvent('mouseout',{bubbles:true,clientX:x,clientY:y})); }catch(_){} },900);
    } catch (_) {}
  }
  function seek(delta, reveal=false) {
    const p=ytPlayer();
    if(p){ try {
      const now=Number(p.getCurrentTime()), dur=Number(p.getDuration?.())||Infinity;
      if(Number.isFinite(now)){
        const target=Math.max(0,Math.min(dur,now+delta));
        p.seekTo(target,true);
        if (reveal) revealAt(p,target,dur); else hideOverlay();
        return true;
      }
    } catch(_){} }
    const v=pick(), range=v && bounds(v);if (!range) return false;
    v.currentTime=Math.max(range[0],Math.min(range[1],v.currentTime+delta));return true;
  }
  // Verandert het volume met "delta" (bijvoorbeeld 0.05 = 5%), afgerond op hele procenten
  // en geknepen tussen 0 en 1. Als het volume boven 0 komt, zetten we mute automatisch uit.
  function volume(delta, reveal=false) {
    const p=ytPlayer();
    if(p && typeof p.setVolume==='function' && typeof p.getVolume==='function'){ try {
      const next=Math.round(Math.max(0,Math.min(100,Number(p.getVolume())+delta*100)));
      p.setVolume(next); if(next>0) p.unMute?.(); else p.mute?.();
      if (reveal) revealAt(p, Number(p.getCurrentTime?.())||0, NaN); else hideOverlay();
      return true;
    } catch(_){} }
    const v=pick();if(!v)return false;
    v.volume=Math.round(Math.max(0,Math.min(1,v.volume+delta))*100)/100;
    if(v.volume>0)v.muted=false;return true;
  }
  // V18: afspeelsnelheid met één klik (0.25–4×), via YouTube's speler als die er is.
  const RATES=[0.25,0.5,0.75,1,1.25,1.5,1.75,2,2.5,3,4];
  function rate(direction) {
    const p=ytPlayer(), v=pick();
    const cur=Number(p?.getPlaybackRate?.() ?? v?.playbackRate ?? 1)||1;
    let i=RATES.findIndex(r=>r>=cur-1e-6); if(i<0)i=RATES.length-1;
    if(direction>0 && RATES[i]<=cur+1e-6) i=Math.min(RATES.length-1,i+1);
    if(direction<0) i=Math.max(0,(RATES[i]>=cur-1e-6?i:i+1)-1);
    const next=direction===0?1:RATES[i];
    // YouTube's eigen API kent alleen 0.25–2; daarboven zetten we het element zelf.
    if(p && typeof p.setPlaybackRate==='function' && next<=2){ try{p.setPlaybackRate(next);}catch(_){} }
    if(v){ v.playbackRate=next; v.defaultPlaybackRate=next; }
    return next;
  }
  // Wisselt tussen afspelen en pauzeren.
  function toggle() {
    const v=pick();if(!v)return false;
    const play=v.paused, player=document.getElementById('movie_player');
    // V11: go through YouTube's own player (as its K key does). Starting the element directly
    // left YouTube's player state 'paused', which paused the video again right after Space.
    if(player && typeof player.playVideo==='function' && typeof player.pauseVideo==='function'){
      window.JoeToepMedia.noteIntent?.(play?'play':'pause');
      try { play?player.playVideo():player.pauseVideo(); return true; } catch (_) {}
    }
    window.JoeToepMedia.remoteAction(play?'play':'pause');return true;
  }
  // Luistert naar toetsaanslagen op het hele window. e.isTrusted is true als de toets
  // écht door de gebruiker is ingedrukt (niet door een script nagemaakt) — een
  // veiligheidscheck. We negeren ook typwerk in tekstvelden en als Ctrl ingedrukt is.
  window.addEventListener('keydown', e => {
    const v=pick();if(!e.isTrusted || !v || editable(e.target) || e.ctrlKey)return;
    let handled=false;
    // V11: YouTube's own player already toggles on Space (like K). Handling it here as well
    // toggled twice, so Space from pause played and immediately paused again on Mac.
    const youtubeOwnsSpace=Boolean(document.getElementById('movie_player')) && !document.documentElement.hasAttribute('data-joetoep-stage');
    // Spatie pauzeert/speelt af, maar alleen als YouTube's eigen speler dat nog niet zelf doet.
    if(e.key===' ' && !e.metaKey && !e.altKey && !youtubeOwnsSpace)handled=toggle();
    // Pijl-links/rechts spoelt: normaal 5 seconden, met Alt 30, met Alt+Cmd 60.
    if(['ArrowLeft','ArrowRight'].includes(e.key)) {
      const step=e.altKey?(e.metaKey?60:30):cfg.keySeek;
      if(!e.metaKey||e.altKey)handled=seek(e.key==='ArrowRight'?step:-step,cfg.showControlsOnKeys);
    }
    // Pijl-omhoog/omlaag verandert het volume met 5%, tenzij Cmd of Alt ingedrukt is
    // (die combinaties zijn dan voor iets anders, zoals browser-sneltoetsen).
    if(!e.metaKey && !e.altKey && ['ArrowUp','ArrowDown'].includes(e.key))handled=volume(e.key==='ArrowUp'?cfg.volumeStep*5:-cfg.volumeStep*5,cfg.showControlsOnKeys);
    // preventDefault stopt het standaardgedrag van de browser voor deze toets;
    // stopImmediatePropagation zorgt dat geen andere listener de toets ook nog verwerkt.
    // We sturen ook een eigen event ('joetoep-controls-used') zodat andere delen van de
    // app weten dat er net bediend is (bijv. om besturingsknoppen even te tonen).
    if(handled){e.preventDefault();e.stopImmediatePropagation();document.dispatchEvent(new Event('joetoep-controls-used'));}
  },true);
  // dx/dy tellen de sleepafstand van een trackpad-swipe op; lastWheel onthoudt wanneer de
  // vorige wheel-beweging was, zodat een nieuwe swipe na een korte stilte weer bij 0 begint.
  let dx=0,dy=0,lastWheel=0;
  // 'wheel' is het event voor scrollen/swipen (muiswiel of trackpad).
  window.addEventListener('wheel',e=>{
    const v=pick();if(!e.isTrusted||e.ctrlKey||!v||editable(e.target))return;
    // Alleen in fullscreen (echte browser-fullscreen, of onze eigen "stage"-fullscreen).
    const fullscreen=document.fullscreenElement||document.documentElement.hasAttribute('data-joetoep-stage');
    if(!fullscreen)return;
    // Als er meer dan 180ms stilte was, begint een nieuwe swipe-telling (anders zou een
    // kleine beweging lang geleden nog meetellen bij een nieuwe swipe).
    if(Date.now()-lastWheel>180){dx=0;dy=0;}lastWheel=Date.now();
    // e.deltaMode vertelt in welke eenheid deltaX/deltaY zijn: 0=pixels, 1=regels, 2=pagina's.
    // We schalen regels/pagina's om naar ongeveer pixel-grootte, zodat de drempels hieronder
    // (>=45) overal ongeveer even gevoelig aanvoelen.
    const scale=e.deltaMode===1?16:e.deltaMode===2?120:1;
    dx+=e.deltaX*scale;dy+=e.deltaY*scale;
    // Horizontale swipe (groter dan verticale, en groot genoeg): spoelen. Verticale swipe:
    // volume aanpassen. Na een actie beginnen we de teller weer op 0.
    // V19: kleine, gelijkmatige stapjes: elke `swipeThreshold` px = één stap van `swipeSeek` s
    // (standaard 5 s) of `volumeStep` (standaard 1%). Werkt ook met Mac Mouse Fix (die stuurt
    // gewone scroll-events, soms in regels i.p.v. pixels — daarom de schaal hierboven).
    const t=cfg.swipeThreshold;
    while(Math.abs(dx)>Math.abs(dy) && Math.abs(dx)>=t){seek(dx>0?cfg.swipeSeek:-cfg.swipeSeek,cfg.showControlsOnSwipe);dx-=Math.sign(dx)*t;dy=0;}
    while(Math.abs(dy)>=t && Math.abs(dy)>=Math.abs(dx)){volume(dy<0?cfg.volumeStep:-cfg.volumeStep,cfg.showControlsOnSwipe);dy-=Math.sign(dy)*t;dx=0;}
    e.preventDefault();e.stopImmediatePropagation();document.dispatchEvent(new Event('joetoep-controls-used'));
  },{capture:true,passive:false});
  // Deze functies ook buiten dit bestand beschikbaar maken, maar wel bevroren (Object.freeze)
  // zodat niemand ze per ongeluk kan overschrijven.
  window.JoeToepControls=Object.freeze({seek,volume,toggle,bounds,rate,
    configure(next){ Object.assign(cfg, next||{}); return {...cfg}; },rateNow:()=>Number(ytPlayer()?.getPlaybackRate?.() ?? pick()?.playbackRate ?? 1)});
})();
