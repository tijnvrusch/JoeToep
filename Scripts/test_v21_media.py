#!/usr/bin/env python3
"""V21: test de JavaScript van de media-extra's (alleen audio, herhalen, boost) met een nep-DOM."""
import re, subprocess, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
s = (root / 'JoeToep/Support/MediaExtras.swift').read_text()
script = re.search(r'static let script = #"""\n(.*?)\n    """#', s, re.S).group(1)
js = '''
const assert=require('assert');
const styles={};
const v={paused:false,loop:false,addEventListener(){}};
global.document={head:{appendChild(el){styles[el.id]=el;el.remove=()=>{delete styles[el.id]}}},documentElement:{},
  querySelectorAll:()=>[v],querySelector:(q)=>q.startsWith('video')?v:null,getElementById:(id)=>styles[id]||null,
  createElement:()=>({})};
let gainValue=null;
global.window={AudioContext:function(){return{createMediaElementSource:()=>({connect(){}}),createGain:()=>({gain:{set value(x){gainValue=x}},connect(){}}),
  createDynamicsCompressor:()=>({threshold:{},knee:{},ratio:{},connect(){}}),destination:{},resume(){}}}};
const f=(%s);
f(1,true,true); assert.ok(styles['joetoep-audio-only']); assert.equal(v.loop,true); assert.equal(gainValue,null,'no audio graph without boost');
f(2.5,false,false); assert.ok(!styles['joetoep-audio-only']); assert.equal(v.loop,false); assert.equal(gainValue,2.5);
f(9,false,false); assert.equal(gainValue,3,'boost is capped at 300%%');
f(1,false,false); assert.equal(gainValue,1,'back to normal keeps the graph at 100%%');
console.log('PASS V21 media extras (audio only, loop, boost cap)');
''' % script.strip()
r = subprocess.run(['node', '-e', js], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip()); sys.exit(r.returncode)
