"""Prepare two opening textures from one refined painting. No creative image edits.
All resampling, cuts and edge padding are offline. Gameplay data is never read.
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/continuous-v2-refinement/phase-01-02/source'
OUTPUT=ROOT/'assets/backgrounds/opening'
WIDTH,VIEW,STRIDE,PADDING=572,960,235,2
height=VIEW+2*STRIDE
raw=Image.open(SOURCE/'refined-master.png').convert('RGB')
assert raw.width>=WIDTH and raw.height>=height, 'Do not upscale a low-resolution layout into production assets'
assert abs(raw.width/raw.height-WIDTH/height)<0.005, 'Refinement must preserve the approved section aspect'
master=raw.resize((WIDTH,height),Image.Resampling.LANCZOS)
master.save(SOURCE/'prepared-master.png',optimize=True)
padded=Image.new('RGB',(WIDTH,height+PADDING*2))
padded.paste(master,(0,PADDING))
for y in range(PADDING):
    padded.paste(master.crop((0,0,WIDTH,1)),(0,y))
    padded.paste(master.crop((0,height-1,WIDTH,height)),(0,height+PADDING+y))
for stage,origin in [(1,STRIDE),(2,0)]:
    padded.crop((0,origin,WIDTH,origin+VIEW+STRIDE+2*PADDING)).save(OUTPUT/f'stage_{stage:02d}.png',optimize=True)
a=Image.open(OUTPUT/'stage_01.png').crop((0,0,WIDTH,VIEW+2*PADDING))
b=Image.open(OUTPUT/'stage_02.png').crop((0,STRIDE,WIDTH,STRIDE+VIEW+2*PADDING))
assert ImageChops.difference(a,b).getbbox() is None
report={'parent_commit':'d45d9d79ca5132619074b9eaa3a2d33b909b23d0','parent_section_crop':[235,1538,488,2172], 'section_note':'stages 1–2 plus upper continuation context; layout coordinates are not gameplay distances','refined_source_sha256':hashlib.sha256((SOURCE/'refined-master.png').read_bytes()).hexdigest(),'refined_source_size':list(raw.size),'prepared_master_size':[WIDTH,height], 'runtime_tile_size':[WIDTH,VIEW+STRIDE+2*PADDING], 'edge_padding':PADDING, 'viewport_pixels':[WIDTH,VIEW], 'visual_stride':STRIDE, 'tile_master_origins':{'1':STRIDE,'2':0}, 'seam_including_filter_support_identical':True, 'resampling':'single offline Lanczos downsample; no upsampling, compositing or per-stage generation', 'resident_rgba8_bytes':2*WIDTH*(VIEW+STRIDE+2*PADDING)*4,'files':{}}
for name in ['stage_01.png','stage_02.png']:
    data=(OUTPUT/name).read_bytes();report['files'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
(SOURCE/'asset-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
