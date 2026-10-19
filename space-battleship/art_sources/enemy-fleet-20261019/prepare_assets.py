"""Crop approved base fleet without repainting. Requires Pillow, numpy, scipy."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).with_name('base-eight-transparent.png')
OUTPUT=ROOT/'assets/ships/enemy/fleet_20261019'
# Wide anchor crosses the nominal quarter-grid. Boundaries lie in actual gaps.
REGIONS={'scout':(0,0,396,440),'sentry':(396,0,887,440),'interceptor':(887,0,1301,440),'swarm':(1301,0,1774,440),'anchor':(0,440,495,887),'reactive':(495,440,896,887),'shielded':(896,440,1323,887),'command':(1323,440,1774,887)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 OUTPUT.mkdir(parents=True,exist_ok=True)
 image=Image.open(SOURCE).convert('RGBA')
 alpha=np.asarray(image.getchannel('A'))
 labels,_=ndimage.label(alpha>20)
 sizes=np.bincount(labels.ravel());keep=sizes>=200;keep[0]=False
 # Preserve source RGBA and three pixels of soft fringe; remove disconnected
 # near-transparent background residue. All eleven substantial components stay.
 mask=ndimage.binary_dilation(keep[labels],iterations=3)
 rgba=np.array(image);rgba[~mask]=0;clean=Image.fromarray(rgba)
 report={'source_commit':'f9af84734145a6df6bcc1998fff15730936aa78a','source_sha256':sha(SOURCE),'source_size':list(image.size),'canvas':[887,1774],'opaque_width':720,'weapons_baked':False,'sprites':{}}
 for key,region in REGIONS.items():
  tile=clean.crop(region);box=tile.getbbox();assert box
  # No retained foreground may touch a crop boundary.
  assert box[0]>0 and box[1]>0 and box[2]<tile.width and box[3]<tile.height,(key,box)
  body=tile.crop(box);size=(720,round(body.height*720/body.width))
  assert size[1]<1774-64
  body=body.resize(size,Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(887,1774));canvas.alpha_composite(body,((887-size[0])//2,(1774-size[1])//2))
  target=OUTPUT/(key+'.png');canvas.save(target)
  report['sprites'][key]={'region':list(region),'source_bounds':[region[0]+box[0],region[1]+box[1],region[0]+box[2],region[1]+box[3]],'body_size':list(size),'texture':'res://'+str(target.relative_to(ROOT)),'sha256':sha(target)}
 (OUTPUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
