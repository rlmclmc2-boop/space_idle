"""Normalize imagegen elite/boss atlas. Only alpha cleanup, crop and uniform fit."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).with_name('elite-boss-transparent.png')
OUTPUT=ROOT/'assets/ships/enemy/elite_boss_20261020'
COLUMNS=[0,472,878,1327,1774]
KEYS=['anchor','reactive','shielded','command']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 image=Image.open(SOURCE).convert('RGBA');alpha=np.asarray(image.getchannel('A'))
 labels,_=ndimage.label(alpha>20);sizes=np.bincount(labels.ravel());keep=sizes>=200;keep[0]=False
 mask=ndimage.binary_dilation(keep[labels],iterations=3);rgba=np.array(image);rgba[~mask]=0;clean=Image.fromarray(rgba)
 OUTPUT.mkdir(parents=True,exist_ok=True)
 report={'approved_concept_commit':'3887ead570b7c1a58aed84a5dd15669fc6d03195','source_sha256':sha(SOURCE),'source_size':list(image.size),'canvas':[887,1774],'body_width':720,'weapons_baked':False,'sprites':{}}
 for row,rank in enumerate(['elite','boss']):
  for col,key in enumerate(KEYS):
   region=(COLUMNS[col],0 if row==0 else 440,COLUMNS[col+1],440 if row==0 else 887)
   tile=clean.crop(region);box=tile.getbbox();assert box and min(box[0],box[1],tile.width-box[2],tile.height-box[3])>0,(key,rank,box)
   body=tile.crop(box);size=(720,round(body.height*720/body.width));body=body.resize(size,Image.Resampling.LANCZOS)
   canvas=Image.new('RGBA',(887,1774));canvas.alpha_composite(body,((887-size[0])//2,(1774-size[1])//2))
   target=OUTPUT/(key+'-'+rank+'.png');canvas.save(target)
   report['sprites'][key+'_'+rank]={'region':list(region),'source_bounds':[region[0]+box[0],region[1]+box[1],region[0]+box[2],region[1]+box[3]],'body_size':list(size),'texture':'res://'+str(target.relative_to(ROOT)),'sha256':sha(target),'display_span':[2,2] if rank=='elite' else [3,2],'display_size':[204.8,212.6666666667] if rank=='elite' else [319.2,194.6666666667]}
 (OUTPUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
