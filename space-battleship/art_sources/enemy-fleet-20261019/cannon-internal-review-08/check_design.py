"""Verify fixed07 presentation sizes and unchanged production while checking edited art geometry."""
from pathlib import Path
import json,math,hashlib,subprocess
import numpy as np
from PIL import Image
from scipy import ndimage
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
meta=json.loads((HERE/'design-meta.json').read_text());baseline=json.loads((HERE.parent/'cannon-coverage-review-07/coverage-measurements.json').read_text())['cases'];manifest=json.loads((ROOT/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text())
old=np.array(Image.open(HERE.parent/'cannon-design-review-06/cannon-design.png'));new=np.array(Image.open(HERE/'cannon-design.png'));assert old.shape==new.shape
oldmask=old[:,:,3]>230;mask=new[:,:,3]>230;iou=float((oldmask&mask).sum()/(oldmask|mask).sum());assert iou>.99
lab,_=ndimage.label(mask);count=np.bincount(lab.ravel());y,x=np.where(lab==np.argmax(count[1:])+1);points=np.stack([x,y],1).astype(float)-meta['pivot_source_px'];radius=float(np.linalg.norm(points,axis=1).max())
probes=[];gaps=[];widths=[]
for key,case in baseline.items():
 hull=np.asarray(Image.open(ROOT/manifest['sprites'][key]['texture'].removeprefix('res://')))[:,:,3];level=case['levels'][1];screen=case['screen_per_canvas_pixel'];rs=[]
 for slot,(socket,width) in enumerate(zip(case['sockets'],level['width_screen'])):
  scale=width/screen/meta['housing_width_source_px'];rs.append(radius*scale);widths.append(width)
  for yaw in [-55,-35,0,35,55]:
   th=math.radians(yaw);rot=np.array([[math.cos(th),-math.sin(th)],[math.sin(th),math.cos(th)]]);p=np.rint((points@rot.T)*scale+socket['centre_px']).astype(int)
   inside=(p[:,0]>=0)&(p[:,0]<hull.shape[1])&(p[:,1]>=0)&(p[:,1]<hull.shape[0]);valid=np.zeros(len(p),bool);valid[inside]=hull[p[inside,1],p[inside,0]]>64
   outside=int((~valid).sum());assert outside==0,(key,slot,yaw,outside)
   probes.append({'case':key,'slot':slot,'yaw':yaw,'opaque_pixels':len(p),'outside':outside})
 for i in range(len(rs)):
  for j in range(i+1,len(rs)):
   distance=float(np.linalg.norm(np.array(case['sockets'][i]['centre_px'])-case['sockets'][j]['centre_px']));gap=(distance-rs[i]-rs[j])*screen;assert gap>0;gaps.append(gap)
for part in ['assets','data','scripts','config_excel','dev/qa','art_sources/enemy-fleet-20261019/prepare_ranked_assets.py']:
 assert not subprocess.check_output(['git','diff','3bed1e2e','--','space-battleship/'+part],cwd=ROOT.parent),part
assert not subprocess.check_output(['git','diff','3bed1e2e','--','test'],cwd=ROOT.parent)
for f in ['design-meta.json','coverage-measurements.json']:
 path=HERE.parent/'cannon-coverage-review-07'/f;assert path.read_bytes()==subprocess.check_output(['git','show','3bed1e2e:space-battleship/'+str(path.relative_to(ROOT))],cwd=ROOT.parent)
old_path=HERE.parent/'cannon-design-review-06/cannon-design.png';assert old_path.read_bytes()==subprocess.check_output(['git','show','3bed1e2e:space-battleship/'+str(old_path.relative_to(ROOT))],cwd=ROOT.parent)
result={'design_only':True,'baseline':'3bed1e2e','07_per_mount_dimensions_reused_exactly':True,'07_geometry_caps_and_coordinates_unchanged':True,'source_canvas':list(Image.open(HERE/'cannon-design.png').size),'opaque_alpha_outline_iou_with06':iou,'same_metadata_pivot_and_body_barrel_proportion':True,'native_width_min_max':[min(widths),max(widths)],'probes':probes,'outside_total':sum(p['outside'] for p in probes),'minimum_any_yaw_separation_pixels':min(gaps),'production_runtime_qa_importer_tests_unchanged':True,'06_source_unchanged':True,'source_sha256':hashlib.sha256((HERE/'cannon-design.png').read_bytes()).hexdigest(),'game_not_launched_or_integrated':True,'main_not_merged':True}
(HERE/'design-check.json').write_text(json.dumps(result,indent=2)+'\n');print('INTERNAL_ART CHECK PASS',len(probes),'hull probes; outside0; outline IoU',round(iou,5),'min gap',round(min(gaps),2))
