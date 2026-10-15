"""Prepare two opening textures from one refined painting. No creative image edits.
All resampling, cuts and edge padding are offline. Gameplay data is never read.
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/continuous-v2-refinement/phase-01-02-hierarchy/source'
OUTPUT=ROOT/'assets/backgrounds/opening'
WIDTH,VIEW,PADDING=572,960,2
STRIDES={1:720,2:426}
height=VIEW+sum(STRIDES.values())
raw=Image.open(SOURCE/'refined-master.png').convert('RGB')
assert raw.width>=WIDTH and raw.height>=height, 'Do not upscale a low-resolution layout into production assets'
assert raw.height==height
left=(raw.width-WIDTH)//2
master=raw.crop((left,0,left+WIDTH,height)) # Native-density central ribbon, no resizing
master.save(SOURCE/'prepared-master.png',optimize=True)
padded=Image.new('RGB',(WIDTH,height+PADDING*2))
padded.paste(master,(0,PADDING))
for y in range(PADDING):
    padded.paste(master.crop((0,0,WIDTH,1)),(0,y))
    padded.paste(master.crop((0,height-1,WIDTH,height)),(0,height+PADDING+y))
for stage,origin in [(1,STRIDES[2]),(2,0)]:
    padded.crop((0,origin,WIDTH,origin+VIEW+STRIDES[stage]+2*PADDING)).save(OUTPUT/f'stage_{stage:02d}.png',optimize=True)
a=Image.open(OUTPUT/'stage_01.png').crop((0,0,WIDTH,VIEW+2*PADDING))
b=Image.open(OUTPUT/'stage_02.png').crop((0,STRIDES[2],WIDTH,STRIDES[2]+VIEW+2*PADDING))
assert ImageChops.difference(a,b).getbbox() is None
report={'parent_commit':'d45d9d79ca5132619074b9eaa3a2d33b909b23d0','parent_section_crop':[235,1538,488,2172], 'section_note':'stages 1–2 plus upper continuation context; layout coordinates are not gameplay distances','refined_source_sha256':hashlib.sha256((SOURCE/'refined-master.png').read_bytes()).hexdigest(),'refined_source_size':list(raw.size),'prepared_master_size':[WIDTH,height], 'runtime_tile_sizes':{str(k):[WIDTH,VIEW+v+2*PADDING] for k,v in STRIDES.items()}, 'edge_padding':PADDING, 'viewport_pixels':[WIDTH,VIEW], 'visual_strides':STRIDES, 'tile_master_origins':{'1':STRIDES[2],'2':0}, 'seam_including_filter_support_identical':True, 'resampling':'native pixel crop [87,0,659,2106]; no resampling, upsampling, compositing or per-stage generation', 'resident_rgba8_bytes':sum(WIDTH*(VIEW+v+2*PADDING)*4 for v in STRIDES.values()),'files':{}}
for name in ['stage_01.png','stage_02.png']:
    data=(OUTPUT/name).read_bytes();report['files'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
(SOURCE/'asset-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
