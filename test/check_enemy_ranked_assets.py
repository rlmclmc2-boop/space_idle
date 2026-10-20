"""Validate ranked display additions and frozen base/geometry/mount/config contract."""
from pathlib import Path
import copy,hashlib,json,subprocess
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'space-battleship';BASE='108080a7'
def prior(p):return subprocess.check_output(['git','show',BASE+':space-battleship/'+p],cwd=ROOT)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads(prior('data/ship_weapon_visuals.json'));new=json.loads((P/'data/ship_weapon_visuals.json').read_text());manifest=json.loads((P/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text());rows=[]
for key in ['anchor','reactive','shielded','command']:
 base=old['ships']['enemy_opening_'+key]
 for rank,span,available in [('elite',[2,2],[204.8,212.6666666667]),('boss',[3,2],[319.2,194.6666666667])]:
  row=new['ships'].pop('enemy_opening_'+key+'_'+rank);expected=copy.deepcopy(base);expected.update(texture='res://assets/ships/enemy/elite_boss_20261020/'+key+'-'+rank+'.png',display_span=span,display_size=available);assert row==expected
  geometry=P/base['geometry_texture'].removeprefix('res://');assert geometry.read_bytes()==prior(str(geometry.relative_to(P)))
  p=P/row['texture'].removeprefix('res://');im=Image.open(p);assert im.mode=='RGBA' and im.size==(887,1774)
  box=im.getbbox();assert min(box[0],box[1],im.width-box[2],im.height-box[3])>=32
  labels,_=ndimage.label(np.asarray(im.getchannel('A'))>20);areas=np.bincount(labels.ravel());assert sum(areas[1:]>2000)==1
  item=manifest['sprites'][key+'_'+rank];assert sha(p)==item['sha256'];b=item['source_bounds'];assert abs((box[2]-box[0])/(box[3]-box[1])/((b[2]-b[0])/(b[3]-b[1]))-1)<.005
  assert im.getpixel(((box[0]+box[2])//2,(box[1]+box[3])//2))[3]>230,(key,rank,'centre must remain visible core')
  rows.append({'key':key+'_'+rank,'alpha_bounds':box,'sha256':sha(p),'geometry_sha256':sha(geometry),'display_span':span,'display_size':available})
interface=new.pop('enemy_weapon_interface');assert interface['slot_counts']=={'normal':1,'elite':2,'boss':4}
assert interface['coordinate_space']=='alpha_centered_display_canvas'
for key in ['anchor','reactive','shielded','command']:
 for rank,count in interface['slot_counts'].items():
  points=interface['archetypes'][key][rank];assert len(points)==count and len({tuple(p['pos']) for p in points})==count
  assert all(p['mode']=='main' and p['rotation_limit']>0 for p in points)
  path=P/('assets/ships/enemy/fleet_20261019/'+key+'.png' if rank=='normal' else 'assets/ships/enemy/elite_boss_20261020/'+key+'-'+rank+'.png')
  im=Image.open(path);b=im.getbbox();cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
  for point in points:
   x=round(cx+point['pos'][0]*im.width);y=round(cy+point['pos'][1]*im.height)
   assert im.getpixel((x,y))[3]>80,(key,rank,point['pos'],'mount lies outside hull')
assert new==old,'Only eight ranked presentation rows and the dormant interface may change' 
for p in (P/'assets/ships/enemy/fleet_20261019').glob('*.png'):assert p.read_bytes()==prior(str(p.relative_to(P)))
for path in ['scripts/game.gd','scripts/enemy_formation.gd','scripts/enemy_fixed_layout.gd','scripts/simulation_geometry_authority.gd','scripts/simulation_geometry_view.gd','scripts/battle_slice_runtime.gd','scripts/battlefield.gd','scripts/retained_enemy_contacts.gd']:assert (P/path).read_bytes()==prior(path),path
assert not subprocess.check_output(['git','diff',BASE,'--','space-battleship/data/game_data.json','space-battleship/config_excel'],cwd=ROOT)
result={'baseline':BASE,'all_original_visual_rows_unchanged':True,'eight_base_pngs_unchanged':True,'active_geometry_mounts_slots_gameplay_formation_runtime_unchanged':True,'reserved_slot_counts_not_applied':interface['slot_counts'],'sprites':rows}
out=P/'evidence/elite-boss-four-20261020';out.mkdir(parents=True,exist_ok=True);(out/'asset-check.json').write_text(json.dumps(result,indent=2)+'\n');print('RANKED_ASSETS PASS eight alpha/aspect/core/geometry/mount/config checks')
