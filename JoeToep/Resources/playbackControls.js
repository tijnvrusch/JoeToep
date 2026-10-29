/* Shared keyboard/trackpad controls; no periodic work, no duplicate media player. */
(() => {
  'use strict';
  if (!window.JoeToepMedia || window.JoeToepControls) return;
  const pick = () => document.querySelector('video.html5-main-video') || document.querySelector('video');
  const editable = target => target?.closest?.('input,textarea,select,[contenteditable="true"],[role="textbox"]');
  function bounds(v) {
    try { if (v.seekable.length) return [v.seekable.start(0),v.seekable.end(v.seekable.length-1)]; } catch (_) {}
    return Number.isFinite(v.duration) && v.duration > 0 ? [0,v.duration] : null;
  }
  function seek(delta) {
    const v=pick(), range=v && bounds(v);if (!range) return false;
    v.currentTime=Math.max(range[0],Math.min(range[1],v.currentTime+delta));return true;
  }
  function volume(delta) {
    const v=pick();if(!v)return false;
    v.volume=Math.round(Math.max(0,Math.min(1,v.volume+delta))*100)/100;
    if(v.volume>0)v.muted=false;return true;
  }
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
  window.addEventListener('keydown', e => {
    const v=pick();if(!e.isTrusted || !v || editable(e.target) || e.ctrlKey)return;
    let handled=false;
    // V11: YouTube's own player already toggles on Space (like K). Handling it here as well
    // toggled twice, so Space from pause played and immediately paused again on Mac.
    const youtubeOwnsSpace=Boolean(document.getElementById('movie_player')) && !document.documentElement.hasAttribute('data-joetoep-stage');
    if(e.key===' ' && !e.metaKey && !e.altKey && !youtubeOwnsSpace)handled=toggle();
    if(['ArrowLeft','ArrowRight'].includes(e.key)) {
      const step=e.altKey?(e.metaKey?60:30):5;
      if(!e.metaKey||e.altKey)handled=seek(e.key==='ArrowRight'?step:-step);
    }
    if(!e.metaKey && !e.altKey && ['ArrowUp','ArrowDown'].includes(e.key))handled=volume(e.key==='ArrowUp'?.05:-.05);
    if(handled){e.preventDefault();e.stopImmediatePropagation();document.dispatchEvent(new Event('joetoep-controls-used'));}
  },true);
  let dx=0,dy=0,lastWheel=0;
  window.addEventListener('wheel',e=>{
    const v=pick();if(!e.isTrusted||e.ctrlKey||!v||editable(e.target))return;
    const fullscreen=document.fullscreenElement||document.documentElement.hasAttribute('data-joetoep-stage');
    if(!fullscreen)return;
    if(Date.now()-lastWheel>180){dx=0;dy=0;}lastWheel=Date.now();
    const scale=e.deltaMode===1?16:e.deltaMode===2?120:1;
    dx+=e.deltaX*scale;dy+=e.deltaY*scale;
    if(Math.abs(dx)>Math.abs(dy) && Math.abs(dx)>=45){seek(dx>0?5:-5);dx=dy=0;}
    else if(Math.abs(dy)>=45){volume(dy<0?.05:-.05);dx=dy=0;}
    e.preventDefault();e.stopImmediatePropagation();document.dispatchEvent(new Event('joetoep-controls-used'));
  },{capture:true,passive:false});
  window.JoeToepControls=Object.freeze({seek,volume,toggle,bounds});
})();
