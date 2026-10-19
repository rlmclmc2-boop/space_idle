"""Split supplied art, preserve interiors, and fit visuals to existing rotation/muzzle nodes."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/weapons/fleet_20261019'
EMISSION={'cannon':[[298,20]],'missile':[[694,189],[976,189]],'laser':[[1371,139]],'longLaser':[[1900,65]]}
ROWS=[('cannon',(298,505),(437,437)),('missile',(835,510),(415,648)),('laser',(1371,517),(461,461)),('longLaser',(1900,510),(586,586))]
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 src=Path(__file__).with_name('turrets-transparent.png');p=np.array(Image.open(src).convert('RGBA'));a=p[:,:,3]
 lab,_=ndimage.label(a>127);counts=np.bincount(lab.ravel());ids=[int(i) for i in np.flatnonzero(counts>10000) if i];ids.sort(key=lambda i:np.nonzero(lab==i)[1].mean());assert len(ids)==4
 dist,near=ndimage.distance_transform_edt(~np.isin(lab,ids),return_indices=True);owner=lab[tuple(near)]
 report={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'weapons':{}}
 for ident,(key,anchor,ppm) in zip(ids,ROWS):
  mask=(owner==ident)&(a>16)&(dist<=2);yy,xx=np.nonzero(mask);box=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
  crop=p[box[1]:box[3],box[0]:box[2]].copy();crop[~mask[box[1]:box[3],box[0]:box[2]]]=0
  im=Image.new('RGBA',(crop.shape[1]+32,crop.shape[0]+32));im.paste(Image.fromarray(crop),(16,16));file=OUT/(key+'.png');im.save(file)
  report['weapons'][key]={'texture':'res://'+str(file.relative_to(ROOT)),'source_bounds':box,'source_anchor':list(anchor),'anchor':[anchor[0]-box[0]+16,anchor[1]-box[1]+16],'pixels_per_model':list(ppm),'source_emission_pixels':EMISSION[key],'emission_pixels':[[x-box[0]+16,y-box[1]+16] for x,y in EMISSION[key]],'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
 bolt=Image.open(Path(__file__).with_name('pulse-bolt.png')).convert('RGBA');arr=np.array(bolt);alpha=arr[:,:,3];ys,xs=np.nonzero(alpha>8);box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));bolt=bolt.crop(box);bolt.thumbnail((128,256),Image.Resampling.LANCZOS);bolt.save(OUT/'pulse-bolt.png')
 report['pulse']={'texture':'res://assets/weapons/fleet_20261019/pulse-bolt.png','source_bounds':box,'size':[14,34],'orientation':'up'}
 (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
