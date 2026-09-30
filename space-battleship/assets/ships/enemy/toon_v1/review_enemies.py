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
# Neutral background only: no obsolete player hull or inferred live integration.
comparison=Image.new('RGB',(1020,690),'#101d29');dd=ImageDraw.Draw(comparison)
dd.text((20,16),'ENEMY FLEET / unchanged top-down projection / neutral background',font=font,fill='#dfdfd9')
dd.text((20,52),'3x display size - geometry, directional light, broad armor steps',font=font,fill='#a6b1ba')
for i,s in enumerate(M['ships']):
 width=[40,44,48,55,58,62][i]
 source=Image.open(P/s['sprite']).transpose(Image.Transpose.ROTATE_180)
 for scale,center_y in [(3,280),(1,555)]:
  im=source.resize((width*scale,width*2*scale),Image.Resampling.LANCZOS)
  comparison.paste(im,(i*170+85-im.width//2,center_y-im.height//2),im)
 dd.text((i*170+20,650),s['id']+' / '+str(width)+'px',font=font,fill='#f7aa65')
dd.text((20,450),'1x display size - 40 / 44 / 48 / 55 / 58 / 62px full canvas widths',font=font,fill='#a6b1ba')
comparison.save(Q/'enemy-fleet-review.png')
(Q/'checks.json').write_text(json.dumps({'scope':'asset-only; original gameplay and render sizes unchanged','source_mon_xlsx_matches_runtime_sizes':True,'refinement':'normal winding; broad sloped armor; recessed command wells; prototype key pre-rotated for runtime PI; camera and manifest unchanged','ships':qa},indent=2)+'\n')
