"""Import approved integrated hull foundations + independent rotating gun. No hull drawing."""
from pathlib import Path
import hashlib,json,copy
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).with_name('integrated-empty-bases-atlas.png')
GUN_SOURCE=SOURCE.parent/'cannon-em-appearance-review-10/cannon-design.png'
GUN_DESIGN=GUN_SOURCE.with_name('design-meta.json')
COVERAGE=SOURCE.parent/'cannon-coverage-review-07/coverage-measurements.json'
OUTPUT=ROOT/'assets/ships/enemy/elite_boss_20261020'
GUN_OUTPUT=ROOT/'assets/weapons/integrated_ranked_20261020'
KEYS=['anchor','reactive','shielded','command']
SEEDS={'anchor_elite':[(127,159),(386,161)],'reactive_elite':[(588,257),(799,258)],'shielded_elite':[(983,168),(1243,168)],'command_elite':[(1430,169),(1660,169)],'anchor_boss':[(129,534),(387,533),(129,685),(388,686)],'reactive_boss':[(593,538),(793,537),(588,690),(801,690)],'shielded_boss':[(979,544),(1244,543),(985,689),(1237,689)],'command_boss':[(1430,552),(1663,551),(1430,686),(1662,684)]}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def isolate(im,labels,idx):
 mask=ndimage.binary_dilation(labels==idx,iterations=3)&((labels==0)|(labels==idx));rgba=np.array(im);rgba[~mask]=0
 return Image.fromarray(rgba)
def socket(im,seed):
 x,y=seed;ox=x-30;oy=y-28;a=np.array(im)[oy:y+29,ox:x+31];rgb=a[:,:,:3].astype(int)
 mask=(a[:,:,3]>230)&(rgb.max(2)<82)&((rgb.max(2)-rgb.min(2))<24);lab,_=ndimage.label(mask);idx=lab[28,30];assert idx>0
 p=np.argwhere(lab==idx);cy,cx=p.mean(0)
 return [float(ox+cx),float(oy+cy)],float(p[:,1].max()-p[:,1].min()+1)
def main():
 im=Image.open(SOURCE).convert('RGBA');labels,_=ndimage.label(np.asarray(im.getchannel('A'))>20);areas=np.bincount(labels.ravel());objects=ndimage.find_objects(labels)
 ids=[i for i in range(1,len(areas)) if areas[i]>10000];assert len(ids)==8
 ids.sort(key=lambda i:objects[i-1][0].start);ids=sorted(ids[:4],key=lambda i:objects[i-1][1].start)+sorted(ids[4:],key=lambda i:objects[i-1][1].start)
 OUTPUT.mkdir(parents=True,exist_ok=True)
 report={'approved_concept_commit':'15a102ac3bee1b43d14e6f9666b8f19c10b21a06','source':'res://art_sources/enemy-fleet-20261019/integrated-empty-bases-atlas.png','source_sha256':sha(SOURCE),'canvas':[887,1774],'stationary_foundations_baked':True,'movable_weapons_baked':False,'sprites':{}}
 for n,idx in enumerate(ids):
  rank=['elite','boss'][n//4];key=KEYS[n%4];tile=isolate(im,labels,idx);box=tile.getbbox();assert box and min(box[0],box[1],tile.width-box[2],tile.height-box[3])>0
  body=tile.crop(box);size=(720,round(body.height*720/body.width));sx=size[0]/body.width;sy=size[1]/body.height
  offset=((887-size[0])//2,(1774-size[1])//2);canvas=Image.new('RGBA',(887,1774));canvas.alpha_composite(body.resize(size,Image.Resampling.LANCZOS),offset)
  path=OUTPUT/(key+'-'+rank+'.png');canvas.save(path);used=canvas.getbbox();centre=[(used[0]+used[2])/2,(used[1]+used[3])/2];points=[]
  for seed in SEEDS[key+'_'+rank]:
   source_centre,well_width=socket(im,seed);pixel=[offset[0]+(source_centre[0]-box[0])*sx,offset[1]+(source_centre[1]-box[1])*sy]
   points.append({'pos':[(pixel[0]-centre[0])/887,(pixel[1]-centre[1])/1774],'socket_centre_px':pixel,'source_centre_px':source_centre,'socket_well_width_uv':well_width*sx/887,'stationary_base':True})
  report['sprites'][key+'_'+rank]={'source_bounds':list(box),'body_size':list(size),'source_body_size':[body.width,body.height],'texture':'res://'+str(path.relative_to(ROOT)),'sha256':sha(path),'display_span':[2,2] if rank=='elite' else [3,2],'display_frame_body_size':[204.8,212.6666666667] if rank=='elite' else [319.2,194.6666666667],'sockets':points}
 # One source-pixel scale per elite/BOSS pair preserves the approved tier hierarchy.
 for key in KEYS:
  pair=[report['sprites'][key+'_'+rank] for rank in ['elite','boss']]
  scale=min(cap/dim for item in pair for cap,dim in zip(item['display_frame_body_size'],item['source_body_size']))
  for item in pair:item['display_size']=[v*scale for v in item['source_body_size']]
 # Separate movable assembly; source faces up, runtime faces down, pivot is housing centre.
 gun=Image.open(GUN_SOURCE).convert('RGBA');gl,_=ndimage.label(np.asarray(gun.getchannel('A'))>20);ga=np.bincount(gl.ravel());clean=isolate(gun,gl,int(np.argmax(ga[1:])+1));box=clean.getbbox();crop=clean.crop(box);size=(256,round(crop.height*256/crop.width));offset=((320-size[0])//2,(640-size[1])//2)
 assert min(offset)>=24
 runtime=Image.new('RGBA',(320,640));runtime.alpha_composite(crop.resize(size,Image.Resampling.LANCZOS),offset);runtime=runtime.transpose(Image.Transpose.ROTATE_180);GUN_OUTPUT.mkdir(parents=True,exist_ok=True);target=GUN_OUTPUT/'cannon-rotating.png';runtime.save(target)
 def convert(p):return [319-(offset[0]+(p[0]-box[0])*size[0]/crop.width),639-(offset[1]+(p[1]-box[1])*size[1]/crop.height)]
 design=json.loads(GUN_DESIGN.read_text());coverage=json.loads(COVERAGE.read_text())['cases']
 gun_meta={'approved_art_commit':'51aae1ac','coverage_commit':'3bed1e2e','source':'res://'+str(GUN_SOURCE.relative_to(ROOT)),'source_sha256':sha(GUN_SOURCE),'source_bounds':list(box),'source_pivot':design['pivot_source_px'],'source_muzzle':design['visual_aperture_source_px'],'pivot_px':convert(design['pivot_source_px']),'muzzle_px':convert(design['visual_aperture_source_px']),'canvas':[320,640],'housing_width_px':design['housing_width_source_px']*size[0]/crop.width,'runtime_forward':'down','stationary_base_in_sprite':False,'appearance_only':True,'weapon_type_unchanged':True,'texture':'res://'+str(target.relative_to(ROOT)),'sha256':sha(target),'coverage':{}}
 for case,data in coverage.items():
  selected=data['levels'][1];rows=[]
  for point,pixels,factor in zip(data['sockets'],selected['width_screen'],selected['applied_coverages']):
   canvas_width=pixels/data['screen_per_canvas_pixel']
   rows.append({'housing_canvas_width_px':canvas_width,'housing_width_uv':canvas_width/887,'outer_bearing_width_uv':point['outer_canvas_span']/887,'applied_bearing_coverage':factor,'reference_screen_width':pixels})
  gun_meta['coverage'][case]=rows
 (GUN_OUTPUT/'manifest.json').write_text(json.dumps(gun_meta,indent=2)+'\n');report['gun']=gun_meta
 (OUTPUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 sync_visual_contract(report)
def sync_visual_contract(report):
 path=ROOT/'data/ship_weapon_visuals.json';text=path.read_text();data=json.loads(text);contract=data['enemy_weapon_interface']
 contract['movable_gun']={'texture':report['gun']['texture'],'manifest':'res://assets/weapons/integrated_ranked_20261020/manifest.json','scale_basis':'outer_bearing95_percent_hull_clamped_07','coverage_source':'res://art_sources/enemy-fleet-20261019/cannon-coverage-review-07/coverage-measurements.json','stationary_foundation':'baked into hull; do not draw or rotate another base'}
 names=[]
 for key in KEYS:
  for rank in ['elite','boss']:
   item=report['sprites'][key+'_'+rank];name='enemy_opening_'+key+'_'+rank;names.append(name);data['ships'][name]['display_size']=item['display_size']
   template=copy.deepcopy(contract['archetypes'][key][rank][0]);points=[]
   for socket in item['sockets']:
    point=copy.deepcopy(template);point.update(socket);points.append(point)
   contract['archetypes'][key][rank]=points
 lines=text.splitlines()
 for i,line in enumerate(lines):
  for name in names:
   if line.startswith('    "'+name+'":'):lines[i]='    '+json.dumps(name)+': '+json.dumps(data['ships'][name],separators=(',',':'))+(',' if line.rstrip().endswith(',') else '')
  if line.startswith('  "enemy_weapon_interface":'):lines[i]='  "enemy_weapon_interface": '+json.dumps(contract,separators=(',',':'))
 path.write_text('\n'.join(lines)+'\n')
if __name__=='__main__':main()
