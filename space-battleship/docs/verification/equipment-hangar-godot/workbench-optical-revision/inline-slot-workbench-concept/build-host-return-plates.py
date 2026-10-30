#!/usr/bin/env python3
"""Adapt fixed e154 editable plates; static source only, no game execution."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
ASSETS = HERE / 'coherence-assets'
ROOT = HERE.parents[5]
BASE = 'e15484ceabfe953605eef132e71b6883a3590bf5'
HOST = '75d55275dadf57b84da62ce0e9ea8f4f0161f97d'
EARLY_ONLY = '--early-only' in sys.argv

def url(data):
    return 'data:image/png;base64,' + base64.b64encode(data).decode()

host = (ASSETS/'host-75d55275.png').read_bytes()
env = dict(os.environ, FONTCONFIG_FILE='/tmp/space-idle-workbench-rebuild/fontconfig-local.xml')
# Current short and long environment sources are used directly at the original
# transform; prior piecewise background compression is retained only in Git history.
records = []
previous = json.loads((HERE/'host-return-manifest.json').read_text()) if EARLY_ONLY else None
for old in sorted(HERE.glob('*.svg')):
    if not old.name[:2].isdigit() or not 42 <= int(old.name[:2]) <= 62:
        continue
    if EARLY_ONLY and not old.name.startswith('42-'):
        continue
    relative = str(old.relative_to(ROOT))
    source = subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT).decode()
    original_nodes = re.sub(r'data:image/[^\"]+', 'EMBEDDED_ASSET', source)
    # Replace actual existing screenshot references, retaining original clip rectangles.
    source, count = re.subn(r'(<image id="asset[01]" href=")[^"]+(" width="1440" height="900"/>)',lambda m:m[1]+url(host)+m[2],source)
    assert count == 2
    stage = 'short' if old.name.startswith('42-') else 'tall'
    original = (ASSETS/('hangar-'+stage+'-carrier.png')).read_bytes()
    replacement = (ASSETS/('hangar-short-subordinate.png' if stage=='short' else 'hangar-tall-wallfixed.png')).read_bytes()
    assert source.count(url(original)) == 1
    # Both current carriers preserve a usable blank plane without source remapping.
    source = source.replace(url(original),url(replacement))
    assert re.sub(r'data:image/[^\"]+', 'EMBEDDED_ASSET', source) == original_nodes
    if stage == 'short':
        # Static viewing hierarchy: enlarge existing hull+authored weapons together
        # about the same bottom anchor; this is not battle or manifest geometry.
        hull_start = source.index('<svg x="16" y="475" width="314" height="165"')
        hull_end = source.index('<text ', hull_start)  # following static-plate watermark
        identity_start = source.index('<defs><clipPath id="paint', source.index('x="-27" y="85"'))
        identity = source[identity_start:hull_start]
        ship = source[hull_start:hull_end]
        source = source[:identity_start] + '<g id="early-hull-identity" transform="translate(0,-95)">' + identity + '</g><g id="early-hull-view" transform="translate(173,640) scale(1.5757575757575757) translate(-173,-640)">' + ship + '</g>' + source[hull_end:]
    number = int(old.name[:2])+21
    output = HERE/(str(number)+'-host-return-'+old.stem[12:]+'.svg')
    output.write_text(source)
    subprocess.run(['inkscape',str(output),'--export-type=png','--export-filename='+str(output.with_suffix('.png'))],env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    im = Image.open(output.with_suffix('.png')).convert('RGB')
    reference = Image.open(ASSETS/'host-75d55275.png').convert('RGB')
    row={'file':output.with_suffix('.png').name,'source_plate':old.name,'sha256':hashlib.sha256(output.with_suffix('.png').read_bytes()).hexdigest(),'svg_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'size':list(im.size),'actually_viewed':False}
    if stage == 'short':
        row['early_display_transform']={'hull_and_existing_weapons':'translate(173,640) scale(260/165) translate(-173,-640)','identity_translation':[0,-95],'purpose':'Viewing hierarchy only; authored hull ratio/mounts/anchors and slot controls unchanged.'}
    for name,rect in [('header',(0,0,808,85)),('navigation_and_host',(808,0,1440,900))]:
        row[name+'_diff_bbox']=ImageChops.difference(im.crop(rect),reference.crop(rect)).getbbox()
        assert row[name+'_diff_bbox'] is None
    records.append(row)
if previous:
    changed = {row['file']:row for row in records}
    previous['plates'] = [changed.get(row['file'],row) for row in previous['plates']]
else:
    previous = {'source_commit':BASE,'host_commit':HOST,'kind':'static environment source and exact shared host composition; no runtime acceptance','unchanged':'All original slot/quote/control nodes and authored mounts/anchors retained. Current63 adds declared whole-preview/identity transforms; other plates only swap embedded context/environment. Original42–62 files untouched.','plates':records}
(HERE/'host-return-manifest.json').write_text(json.dumps(previous,ensure_ascii=False,indent=2)+'\n')
