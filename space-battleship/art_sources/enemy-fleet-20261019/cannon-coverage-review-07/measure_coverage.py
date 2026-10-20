"""Read-only geometry/color measurement of existing hull and gun PNGs, no image painting."""
from pathlib import Path
import json,re,math
import numpy as np
from PIL import Image
from scipy import ndimage
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
meta=json.loads((HERE/'design-meta.json').read_text())
manifest=json.loads((ROOT/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text())
snaps={s['case']:s for s in json.loads((ROOT/'evidence/cannon-redesign-20261020/revision2/ranked.json').read_text())['snapshots']}
a=np.array(Image.open(ROOT/'art_sources/enemy-fleet-20261019/integrated-empty-bases-atlas.png'))
gun=np.array(Image.open(HERE/meta['source_texture']));lab,_=ndimage.label(gun[:,:,3]>230);sizes=np.bincount(lab.ravel());ys,xs=np.where(lab==np.argmax(sizes[1:])+1)
# Dense opaque samples are geometry probes, not a derivative image.
points=np.stack([xs,ys],1).astype(float)-meta['pivot_source_px']
maxradius=float(np.linalg.norm(points,axis=1).max())
def edge(x,y,d):
 found=False;last=None;gap=0
 for radius in range(8,66):
  R,G,B,A=map(int,a[y,x+d*radius]);red=A>220 and R>45 and R>G*1.35 and R>B*1.05
  if red:found=True;last=radius;gap=0
  elif found:
   gap+=1
   if gap>=3:return last+2
 return None
result={'source':'existing06 PNG, unchanged','bearing_measurement':'three horizontal source scanlines ±2px; first burgundy ring run plus 2px outer rim; symmetric span uses shorter measured radius','cases':{}}
for key,item in manifest['sprites'].items():
 hull=np.array(Image.open(ROOT/item['texture'].removeprefix('res://')))[:,:,3];box=Image.open(ROOT/item['texture'].removeprefix('res://')).getbbox()
 body=[float(v) for v in re.findall(r'[-\d.]+',snaps[key]['body'])][-2:];screen_scale=body[0]*meta['screen_scale']/(box[2]-box[0]);source_to_png=item['body_size'][0]/item['source_body_size'][0]
 sockets=[]
 for socket in item['sockets']:
  x,y=map(round,socket['source_centre_px']);rays=[(edge(x,y+dy,-1),edge(x,y+dy,1)) for dy in [-2,0,2]];assert all(v is not None for row in rays for v in row)
  left=float(np.median([r[0] for r in rays]));right=float(np.median([r[1] for r in rays]));outer=2*min(left,right)
  coarse=points[::24]
  def fits(coverage):
   k=outer*source_to_png*coverage/meta['housing_width_source_px']
   for angle in [-55,-35,0,35,55]:
    t=math.radians(angle);rot=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);q=np.rint((coarse@rot.T)*k+socket['socket_centre_px']).astype(int)
    valid=(q[:,0]>=0)&(q[:,0]<hull.shape[1])&(q[:,1]>=0)&(q[:,1]<hull.shape[0])
    if not valid.all() or not (hull[q[:,1],q[:,0]]>64).all():return False
   return True
  lo,hi=.30,1.10
  for _ in range(12):
   mid=(lo+hi)/2
   if fits(mid):lo=mid
   else:hi=mid
  safe=min(.95,lo-.015)
  sockets.append({'centre_px':socket['socket_centre_px'],'source_centre':socket['source_centre_px'],'horizontal_rays':rays,'outer_source_span':outer,'outer_canvas_span':outer*source_to_png,'outer_screen_span':outer*source_to_png*screen_scale,'hull_fit_coverage_cap':safe})
 levels=[]
 for cover in meta['coverage_levels']:
  probes=[];radiuses=[]
  for slot,socket in enumerate(sockets):
   width=socket['outer_canvas_span']*min(cover,socket['hull_fit_coverage_cap']);scale=width/meta['housing_width_source_px'];radiuses.append(maxradius*scale)
   for angle in [-55,-35,0,35,55]:
    th=math.radians(angle);rot=np.array([[math.cos(th),-math.sin(th)],[math.sin(th),math.cos(th)]]);p=(points@rot.T)*scale+socket['centre_px'];ij=np.rint(p).astype(int)
    inside=(ij[:,0]>=0)&(ij[:,0]<hull.shape[1])&(ij[:,1]>=0)&(ij[:,1]<hull.shape[0]);valid=np.zeros(len(ij),bool);valid[inside]=hull[ij[inside,1],ij[inside,0]]>64
    probes.append({'slot':slot,'yaw':angle,'outside_samples':int((~valid).sum()),'total_samples':len(ij)})
  gaps=[]
  for i in range(len(sockets)):
   for j in range(i+1,len(sockets)):
    distance=float(np.linalg.norm(np.array(sockets[i]['centre_px'])-sockets[j]['centre_px']));gaps.append((distance-radiuses[i]-radiuses[j])*screen_scale)
  levels.append({'coverage':cover,'width_screen':[s['outer_screen_span']*min(cover,s['hull_fit_coverage_cap']) for s in sockets],'applied_coverages':[min(cover,s['hull_fit_coverage_cap']) for s in sockets],'outside_samples':sum(x['outside_samples'] for x in probes),'rotation_probes':probes,'minimum_any_yaw_separation_pixels':min(gaps) if gaps else None})
 result['cases'][key]={'screen_per_canvas_pixel':screen_scale,'sockets':sockets,'levels':levels}
(HERE/'coverage-measurements.json').write_text(json.dumps(result,indent=2)+'\n')
for key,item in result['cases'].items():print(key,[(r['coverage'],[round(x,1) for x in r['width_screen']],r['outside_samples'],round(r['minimum_any_yaw_separation_pixels'],2)) for r in item['levels']])
