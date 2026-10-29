#!/usr/bin/env python3
from pathlib import Path
import json
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parents[1]/'JoeToep'
variants={'AppIcon':('#b9bbc1','#ff0000'),'White':('#ffffff','#ff0000'),'Ocean':('#9fd9f3','#005eaa'),'Mint':('#c4f5d3','#137f56'),'Sunset':('#ffbd9d','#bc2464'),'Neon':('#291046','#c1ff00'),'Candy':('#f78adc','#4025df')}
template=json.loads((p/'Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
for name,(bg,fg) in variants.items():
 base=Image.new('RGB',(2048,2048),bg);d=ImageDraw.Draw(base)
 if name in ['Neon','Candy']:
  for x in range(-2048,4096,256):d.polygon([(x,0),(x+100,0),(x+2148,2048),(x+2048,2048)],fill=('#74339c' if name=='Neon' else '#ffe378'))
 d.rounded_rectangle((412,592,1636,1456),radius=224,fill=fg)
 d.polygon([(900,796),(900,1252),(1296,1024)],fill='white')
 out=p/f'Assets.xcassets/{name}.appiconset';out.mkdir(exist_ok=True)
 (out/'Contents.json').write_text(json.dumps(template,indent=2))
 for spec in template['images']:
  size=round(float(spec['size'].split('x')[0])*float(spec.get('scale','1x')[:-1]));base.resize((size,size),Image.Resampling.LANCZOS).save(out/spec['filename'])
 images=p/f'Assets.xcassets/IconPreview{name}.imageset';images.mkdir(exist_ok=True)
 base.resize((256,256),Image.Resampling.LANCZOS).save(images/'icon.png')
 (images/'Contents.json').write_text(json.dumps({'images':[{'idiom':'universal','filename':'icon.png'}],'info':{'author':'xcode','version':1}}))
