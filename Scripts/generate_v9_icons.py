from pathlib import Path
import json,math
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parents[1]/'JoeToep'
names=['Arcade','Vinyl','Orbit','Aurora','Lava','Blueprint','Cassette','Prism','Monochrome','Jelly','Sunrise','Cyberpunk']
template=json.loads((p/'Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
for n,name in enumerate(names):
 im=Image.new('RGB',(1024,1024),(12,15,28));d=ImageDraw.Draw(im)
 colors=[('#141236','#44ffff'),('#191919','#f74465'),('#0b1439','#f2b94f'),('#13314e','#79ffdc'),('#311027','#ffae32'),('#063169','#bbf7ff'),('#e3c8a5','#28263b'),('#35136b','#ee69b8'),('#f3f3f1','#181818'),('#ffbad9','#9447dc'),('#ffc581','#e83b4b'),('#1c1029','#e2ff00')]
 bg,fg=colors[n];d.rectangle((0,0,1024,1024),fill=bg)
 if name in ['Aurora','Lava','Sunrise']:
  for y in range(1024):
   if name=='Aurora': c=(18+int(y*.035),40+int(y*.1),70+int(y*.11))
   elif name=='Lava': c=(80+int(y*.15),15+int(y*.05),70-int(y*.035))
   else:c=(255,100+int(y*.11),70+int(y*.08))
   d.line((0,y,1024,y),fill=c)
  for j in range(5):
   points=[(x, int(650+j*54+70*math.sin(x/170+j))) for x in range(0,1025,8)]
   d.line(points,fill=fg,width=8)
 if name in ['Blueprint','Cyberpunk']:
  for x in range(64,1024,64):d.line((x,0,x,1024),fill=('#245892' if name=='Blueprint' else '#432f56'),width=2);d.line((0,x,1024,x),fill=('#245892' if name=='Blueprint' else '#432f56'),width=2)
 if name=='Vinyl':
  for r in range(400,170,-18):d.ellipse((512-r,512-r,512+r,512+r),outline='#48484f',width=3)
  d.ellipse((300,300,724,724),fill=fg)
 elif name=='Orbit':
  d.ellipse((140,340,884,684),outline=fg,width=20);d.ellipse((330,210,694,814),outline='#5488cd',width=12);d.ellipse((300,300,724,724),fill=fg);d.ellipse((145,455,225,535),fill='white')
 elif name=='Cassette':
  d.rounded_rectangle((125,230,899,794),radius=60,fill=fg);d.rounded_rectangle((175,280,849,594),radius=25,fill='#ff718f')
  d.ellipse((225,360,385,520),fill=bg);d.ellipse((640,360,800,520),fill=bg);d.polygon([(330,680),(694,680),(744,790),(280,790)],fill='#565462')
 elif name=='Prism':
  d.polygon([(512,140),(890,360),(890,725),(512,930),(134,725),(134,360)],fill=fg)
  d.polygon([(512,140),(512,535),(890,360)],fill='#ffe177');d.polygon([(134,360),(512,535),(512,930),(134,725)],fill='#665eff')
 elif name=='Arcade':
  for x in range(200,825,80):
   for y in range(280,745,80):d.rectangle((x,y,x+68,y+68),fill=fg)
 elif name=='Jelly':
  d.rounded_rectangle((210,170,814,854),radius=240,fill=fg);d.ellipse((350,310,408,385),fill='white');d.ellipse((620,310,678,385),fill='white')
 else:d.rounded_rectangle((200,285,824,739),radius=100 if name!='Blueprint' else 24,fill=fg)
 # The recognizable play glyph remains legible in every variant.
 d.polygon([(442,398),(442,626),(646,512)],fill='#ffffff' if name not in ['Monochrome','Cyberpunk','Arcade'] else '#ff253d')
 out=p/f'Assets.xcassets/{name}.appiconset';out.mkdir(exist_ok=True);(out/'Contents.json').write_text(json.dumps(template,indent=2))
 for spec in template['images']:
  size=int(float(spec['size'].split('x')[0])*float(spec.get('scale','1x')[:-1]));im.resize((size,size),Image.Resampling.LANCZOS).save(out/spec['filename'])
 preview=p/f'Assets.xcassets/IconPreview{name}.imageset';preview.mkdir(exist_ok=True);im.save(preview/'icon.png');(preview/'Contents.json').write_text(json.dumps({'images':[{'idiom':'universal','filename':'icon.png'}],'info':{'author':'xcode','version':1}}))
