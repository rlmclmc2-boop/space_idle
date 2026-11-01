"""Pack only a complete matching original volume recipe, not preview frames."""
from pathlib import Path
from PIL import Image
import json,hashlib,os
ROOT=Path(__file__).resolve().parent;build=Path(os.environ.get('REACTOR_PLASMA_BUILD','/tmp/reactor-plasma-clean'))
meta=json.loads((build/'render.json').read_text());assert meta['frames']==32
assert meta['recipe_sha256']==hashlib.sha256((ROOT/'generate_plasma_atlas.py').read_bytes()).hexdigest()
w,h=meta['tile'];atlas=Image.new('RGBA',(w*8,h*4),(0,0,0,0));hashes=[]
for i in range(32):
 p=build/f'plasma-{i:02d}.png';im=Image.open(p);assert im.size==(w,h) and im.mode=='RGBA'
 atlas.paste(im,((i%8)*w,(i//8)*h));hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
path=ROOT/'plasma-volume.png';atlas.save(path,optimize=True)
meta.update({'grid':[8,4],'emission_gain':2.0,'atlas_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'frame_sha256':hashes})
(ROOT/'plasma-volume.json').write_text(json.dumps(meta,indent=2)+'\n')
print('PLASMA_ATLAS',path,atlas.size,path.stat().st_size,meta['atlas_sha256'])
