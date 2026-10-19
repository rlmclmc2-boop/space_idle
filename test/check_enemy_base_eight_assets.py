"""Minimal import checks: eight display paths only; centre geometry stays frozen."""
from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'space-battleship'
BASE='5b3eb6b'
old=json.loads(subprocess.check_output(['git','show',BASE+':space-battleship/data/ship_weapon_visuals.json'],cwd=ROOT))
new=json.loads((PROJECT/'data/ship_weapon_visuals.json').read_text())
manifest=json.loads((PROJECT/'assets/ships/enemy/fleet_20261019/manifest.json').read_text())
keys=['scout','sentry','interceptor','swarm','anchor','reactive','shielded','command']
rows=[]
for key in keys:
 row=new['ships']['enemy_opening_'+key];before=old['ships']['enemy_opening_'+key]
 assert row['texture']!=before['texture']
 assert row['geometry_texture']==before['geometry_texture']
 path=PROJECT/row['texture'].removeprefix('res://')
 image=Image.open(path);assert image.mode=='RGBA' and image.size==(887,1774)
 box=image.getbbox();assert min(box[0],box[1],image.width-box[2],image.height-box[3])>=32
 bounds=manifest['sprites'][key]['source_bounds'];ratio=(bounds[2]-bounds[0])/(bounds[3]-bounds[1])
 assert abs((box[2]-box[0])/(box[3]-box[1])/ratio-1)<.005
 labels,count=ndimage.label(np.array(image.getchannel('A'))>20)
 areas=np.bincount(labels.ravel());components=sum(areas[1:]>=2000)
 assert components==(4 if key=='swarm' else 1),(key,components)
 assert hashlib.sha256(path.read_bytes()).hexdigest()==manifest['sprites'][key]['sha256']
 geometry=PROJECT/row['geometry_texture'].removeprefix('res://')
 expected=subprocess.check_output(['git','show',BASE+':space-battleship/'+row['geometry_texture'].removeprefix('res://')],cwd=ROOT)
 assert geometry.read_bytes()==expected
 rows.append({'key':key,'alpha_bounds':box,'components':int(components),'geometry_sha256':hashlib.sha256(expected).hexdigest()})
 row['texture']=before['texture']
assert new==old,'Non-display configuration changed'
result={'baseline':BASE,'display_only_rows':8,'all_other_config_unchanged':True,'all_geometry_bytes_unchanged':True,'sprites':rows}
out=PROJECT/'evidence/enemy-base-eight-20261019';out.mkdir(parents=True,exist_ok=True)
(out/'asset-check.json').write_text(json.dumps(result,indent=2)+'\n')
print('ENEMY_BASE_ASSETS PASS eight alpha/aspect/component/config/geometry checks')
