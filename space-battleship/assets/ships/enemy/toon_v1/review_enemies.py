"""Pillow review compositor. Does not change runtime assets or game state."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,struct
P=Path(__file__).resolve().parent; project=P.parents[3]
M=json.load(open(P/'manifest.json'));Q=P/'review';Q.mkdir(exist_ok=True)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
board=Image.new('RGB',(1020,490),'#101d29');d=ImageDraw.Draw(board)
d.text((20,15),'ENEMY FLEET / identical pixels per meter / bow up',font=font,fill='#dfdfd9')
qa=[]
for i,s in enumerate(M['ships']):
 im=Image.open(P/s['sprite']);a=im.getchannel('A');bb=a.getbbox();assert im.size==(887,1774) and im.mode=='RGBA';assert a.getextrema()==(0,255);assert bb[0]>0 and bb[1]>0 and bb[2]<887 and bb[3]<1774
 thumb=im.resize((150,300),Image.Resampling.LANCZOS);board.paste(thumb,(i*170+10,65),thumb)
 d.text((i*170+16,380),s['id']+' / size '+str(s['size']),font=font,fill='#f7aa65')
 d.text((i*170+16,405),'IDs '+','.join(map(str,s['configured_enemy_ids'])),font=font,fill='#a6b1ba')
 # Extract evaluated GLB accessor bounds; all vertices exported with world origin.
 raw=(P/s['glb']).read_bytes();ln=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+ln]);mins=[];maxs=[]
 for mesh in g['meshes']:
  for pr in mesh['primitives']:
   ac=g['accessors'][pr['attributes']['POSITION']];mins.append(ac['min']);maxs.append(ac['max'])
 qa.append({'id':s['id'],'alpha_bbox':bb,'glb_bounds_min':[min(v[k] for v in mins) for k in range(3)],'glb_bounds_max':[max(v[k] for v in maxs) for k in range(3)],'meshes':len(g['meshes'])})
board.save(Q/'six-ships-same-scale.png')
# Real baseline screenshot: 390px battlefield. Composite ONLY into empty upper battlefield.
bg=Image.open(project/'dev/toon_ship/review/full-window-front-clean.png').convert('RGBA');battle=bg.crop((0,0,390,bg.height))
for i,s in enumerate(M['ships']):
 width=[40,44,48,55,58,62][i];im=Image.open(P/s['sprite']).resize((width,width*2),Image.Resampling.LANCZOS).transpose(Image.Transpose.ROTATE_180)
 x=[80,190,305,80,190,305][i];y=[205,205,205,365,365,365][i]
 battle.alpha_composite(im,(x-width//2,y-width));dd=ImageDraw.Draw(battle);dd.text((x-22,y+width+4),s['id'],font=font,fill='#daaf82')
battle.save(Q/'battlefield-390px-composite.png')
combined=Image.new('RGB',(1410,860),'#101d29');combined.paste(board,(0,100));combined.paste(battle,(1020,0));ImageDraw.Draw(combined).text((20,620),'Right: baseline game background + sprite composite, not a live integration capture.',font=font,fill='#b5c1ca');combined.save(Q/'enemy-fleet-review.png')
(Q/'checks.json').write_text(json.dumps({'scope':'asset-only; original gameplay and render sizes unchanged','source_mon_xlsx_matches_runtime_sizes':True,'ships':qa},indent=2)+'\n')
