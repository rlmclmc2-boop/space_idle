#!/usr/bin/env python3
"""Adapt fixed e154 editable plates; static source only, no game execution."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
ASSETS = HERE / 'coherence-assets'
ROOT = HERE.parents[5]
BASE = 'e15484ceabfe953605eef132e71b6883a3590bf5'
HOST = '75d55275dadf57b84da62ce0e9ea8f4f0161f97d'

def url(data):
    return 'data:image/png;base64,' + base64.b64encode(data).decode()

host = (ASSETS/'host-75d55275.png').read_bytes()
env = dict(os.environ, FONTCONFIG_FILE='/tmp/space-idle-workbench-rebuild/fontconfig-local.xml')
# Resolve nested source-coordinate clips before composing text/controls. Inkscape
# can leak nested image clips into later nodes; a single rendered background cannot.
for stage in ['short','tall']:
    art = ASSETS/('hangar-'+stage+'-return.png')
    with Image.open(art) as im:
        iw, ih = im.size
    cuts = [0,540,1138 if stage=='short' else 1120,1218 if stage=='short' else 1180,iw]
    dest = [0,540,1198,1220,iw]
    background = f'<svg xmlns="http://www.w3.org/2000/svg" width="{iw}" height="{ih}" viewBox="0 0 {iw} {ih}"><defs><image id="return-art" href="{url(art.read_bytes())}" width="{iw}" height="{ih}"/></defs>'
    for a,b,c,d in zip(cuts,cuts[1:],dest,dest[1:]):
        clip = 'return-source-'+str(a)
        background += f'<svg x="{c}" y="0" width="{d-c}" height="{ih}" viewBox="{a} 0 {b-a} {ih}" preserveAspectRatio="none"><defs><clipPath id="{clip}"><rect x="{a}" y="0" width="{b-a}" height="{ih}"/></clipPath></defs><g clip-path="url(#{clip})"><use href="#return-art"/></g></svg>'
    background += '</svg>'
    drawing = ASSETS/('hangar-'+stage+'-return-layout.svg')
    drawing.write_text(background)
    subprocess.run(['inkscape',str(drawing),'--export-type=png','--export-filename='+str(drawing.with_suffix('.png'))],env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
records = []
for old in sorted(HERE.glob('*.svg')):
    if not old.name[:2].isdigit() or not 42 <= int(old.name[:2]) <= 62:
        continue
    relative = str(old.relative_to(ROOT))
    source = subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT).decode()
    original_nodes = re.sub(r'data:image/[^\"]+', 'EMBEDDED_ASSET', source)
    # Replace actual existing screenshot references, retaining original clip rectangles.
    source, count = re.subn(r'(<image id="asset[01]" href=")[^"]+(" width="1440" height="900"/>)',lambda m:m[1]+url(host)+m[2],source)
    assert count == 2
    stage = 'short' if old.name.startswith('42-') else 'tall'
    original = (ASSETS/('hangar-'+stage+'-carrier.png')).read_bytes()
    replacement = (ASSETS/('hangar-'+stage+'-return-layout.png')).read_bytes()
    assert source.count(url(original)) == 1
    # Generated architecture narrows the blank face. Adapt background geometry only:
    # keep its left anchor, extend the empty reading plane beneath unchanged targets,
    # and compress the architectural side cheek before the public x808 boundary.
    source = source.replace(url(original),url(replacement))
    assert re.sub(r'data:image/[^\"]+', 'EMBEDDED_ASSET', source) == original_nodes
    number = int(old.name[:2])+21
    output = HERE/(str(number)+'-host-return-'+old.stem[12:]+'.svg')
    output.write_text(source)
    subprocess.run(['inkscape',str(output),'--export-type=png','--export-filename='+str(output.with_suffix('.png'))],env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    im = Image.open(output.with_suffix('.png')).convert('RGB')
    reference = Image.open(ASSETS/'host-75d55275.png').convert('RGB')
    row={'file':output.with_suffix('.png').name,'source_plate':old.name,'sha256':hashlib.sha256(output.with_suffix('.png').read_bytes()).hexdigest(),'svg_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'size':list(im.size),'actually_viewed':False}
    for name,rect in [('header',(0,0,808,85)),('navigation_and_host',(808,0,1440,900))]:
        row[name+'_diff_bbox']=ImageChops.difference(im.crop(rect),reference.crop(rect)).getbbox()
        assert row[name+'_diff_bbox'] is None
    records.append(row)
(HERE/'host-return-manifest.json').write_text(json.dumps({'source_commit':BASE,'host_commit':HOST,'kind':'static environment source and exact shared host composition; no runtime acceptance','unchanged':'All e154 slot/control/text, hull/weapon transforms and clipped partial-row identity nodes retained byte-for-byte; original42–62 files untouched','plates':records},ensure_ascii=False,indent=2)+'\n')
