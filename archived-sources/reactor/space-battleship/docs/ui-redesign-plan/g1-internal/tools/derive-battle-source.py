import json,math,hashlib,openpyxl
from PIL import Image
from pathlib import Path
root=Path(__file__).resolve().parents[4];out=root/'docs/ui-redesign-plan/g1-internal'
visual=json.loads((root/'data/ship_weapon_visuals.json').read_text());wm=json.loads((root/'assets/weapons/fleet_20261019/manifest.json').read_text())['weapons']
def facts(path):
 im=Image.open(root/path).convert('RGBA');a=im.getchannel('A');box=a.getbbox();return im,a,box
def hull(points):
 pts=sorted(set(points))
 def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
 low=[];high=[]
 for arr,seq in [(low,pts),(high,reversed(pts))]:
  for p in seq:
   while len(arr)>1 and cross(arr[-2],arr[-1],p)<=0:arr.pop()
   arr.append(p)
 return low[:-1]+high[:-1]
def asset(path):
 path=path.replace('res://','');im,a,box=facts(path);pts=[]
 # Exact nonzero pixel-cell corner hull; same alpha>0 convention, not a runtime Godot polygon parity claim.
 for y in range(im.height):
  row=[x for x in range(im.width) if a.getpixel((x,y))>0]
  if row:pts.extend([(row[0],y),(row[-1]+1,y),(row[0],y+1),(row[-1]+1,y+1)])
 return {'texture':path,'sha256':hashlib.sha256((root/path).read_bytes()).hexdigest(),'size':list(im.size),'alpha_bounds':list(box),'alpha_pixels':sum(a.histogram()[1:]),'alpha_hull':hull(pts)}
weapons={k:{**v,**asset(v['texture'])} for k,v in wm.items()}
ships={};params=[1.3,1.1,1.2,1.3,1.4];names=['游隼侦察艇','飞燕护卫舰','云鳐巡洋舰','玄甲战列舰','白鲸无畏舰']
for i,k in enumerate(['Frigate','Destroyer','Cruiser','Battleship','Heavy_Battleship']):
 s=visual['ships'][k];a=asset(s['texture']);h=s['static_height']*1.7*params[i];q=h/(a['alpha_bounds'][3]-a['alpha_bounds'][1]);dims=[x*q for x in a['size']];b=a['alpha_bounds'];bounds=[286+(b[0]-a['size'][0]/2)*q,520+(b[1]-a['size'][1]/2)*q,286+(b[2]-a['size'][0]/2)*q,520+(b[3]-a['size'][1]/2)*q];pivots=[[286+s['hardpoints'][j]['pos'][0]*dims[0],520+s['hardpoints'][j]['pos'][1]*dims[1]] for j in s['slot_map']];radii={}
 for wk,w in weapons.items():
  sc=[h/s['model_span']*s['weapon_scale']*w['visual_scale']/p for p in w['pixels_per_model']]
  radii[wk]=max(math.hypot((p[0]-w['anchor'][0])*sc[0],(p[1]-w['anchor'][1])*sc[1]) for p in w['alpha_hull'])
 R=max(radii.values());sweep=[min(bounds[0],min(p[0]-R for p in pivots)),min(bounds[1],min(p[1]-R for p in pivots)),max(bounds[2],max(p[0]+R for p in pivots)),max(bounds[3],max(p[1]+R for p in pivots))]
 ships[k]={**s,**a,'name':names[i],'capacity':i+1,'defence_slots':[1,1,2,2,3][i],'current_multiplier':params[i],'height':h,'dimensions':dims,'body_bounds':bounds,'visible_area':a['alpha_pixels']*q*q,'pivots':pivots,'weapon_sweep_radii':radii,'assembly_sweep_bounds':sweep}
enemies={k:{**v,**asset(v['texture'])} for k,v in visual['ships'].items() if k.startswith('enemy_opening_')}
geometry={r[0]:r[1] for r in list(openpyxl.load_workbook(root/'config_excel/battle_geometry.xlsx',data_only=True).active.values)[2:] if r[0]}
data={'kind':'read-only source facts and conservative alpha-cell sweep; no gameplay configuration or approved dimensions','baseline':'2ed4f18dabe6dc9b360734c94a2b92633efae49d','source_files':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['data/ship_weapon_visuals.json','assets/weapons/fleet_20261019/manifest.json','config_excel/battle_geometry.xlsx','config_excel/config.xlsx','config_excel/ship.xlsx','config_excel/hyperspace_config.xlsx','config_excel/monGroup.xlsx','config_excel/mon.xlsx','scripts/approved_weapon_art.gd','scripts/ship_geometry_convention.gd','scripts/hyperspace_appearance.gd']},'geometry':geometry,'ships':ships,'weapons':weapons,'enemies':enemies,'ranked':{**visual['enemy_rotating_art'],**asset(visual['enemy_rotating_art']['texture'])},'design':{'visual_bounds':[-32,-100,604,960],'shield_margin':12,'player_bar_gap':14,'enemy_bar_gap':8,'effect_margin':24,'drone_centres':[[105,768],[195,850],[286,768],[377,850],[467,768]],'drone_radius':48,'drone_note':'Candidate only. Not existing native origins; no drone shot emitted by browser.'}}
(out/'battle-source-data.js').write_text('/* Derived by tools/derive-battle-source.py; browser design only. */\nwindow.BattleSource='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n')
(out/'art/battle/geometry.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print([(k,round(s['visible_area'],2),[round(x,2) for x in s['assembly_sweep_bounds']]) for k,s in ships.items()])
