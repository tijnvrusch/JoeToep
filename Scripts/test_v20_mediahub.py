#!/usr/bin/env python3
"""V20: test de JavaScript van het mediacentrum (probe + bediening) met een nep-DOM in Node."""
import re, subprocess, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
s = (root / 'JoeToep/Support/MediaHub.swift').read_text()
probe = re.search(r'static let probeScript = #"""\n(.*?)\n    """#', s, re.S).group(1)
helpers = re.search(r'static let helpers = #"""\n(.*?)\n    """#', s, re.S).group(1)
js = '''
const assert=require('assert');
const els=[{tagName:'VIDEO',paused:true,ended:false,currentSrc:'x',readyState:4,duration:100,currentTime:5,volume:0.8,muted:false,
 play(){this.paused=false;return Promise.resolve()},pause(){this.paused=true}}];
global.document={querySelectorAll:()=>els,getElementById:()=>null};
Object.defineProperty(globalThis,'navigator',{configurable:true,value:{mediaSession:{metadata:{title:'Song',artist:'Band',artwork:[{src:'a.jpg'}]}}}});
const probe=()=>(%s);
let o=JSON.parse(probe()); assert.equal(o.p,false); assert.equal(o.t,'Song'); assert.equal(o.i,'a.jpg');
const h=(%s);
h('play'); assert.equal(els[0].paused,false); assert.equal(JSON.parse(probe()).p,true);
h('volume',0.3); assert.equal(els[0].volume,0.3);
h('volume',0); assert.equal(els[0].muted,true);
h('mute'); assert.equal(els[0].muted,false);
h('skip',10); assert.equal(els[0].currentTime,15);
h('skip',-100); assert.equal(els[0].currentTime,0);
h('pause'); assert.equal(els[0].paused,true);
global.document={querySelectorAll:()=>[],getElementById:()=>null};
assert.equal(probe(),null); h('play');
console.log('PASS V20 media hub probe + controls (8 checks)');
''' % (probe.strip(), helpers.strip())
r = subprocess.run(['node', '-e', js], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip()); sys.exit(r.returncode)
