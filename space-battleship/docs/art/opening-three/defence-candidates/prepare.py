"""Mechanical extraction/standardization of imagegen source; no procedural hull drawing."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects

ROOT = Path(__file__).resolve().parent
source = Image.open(ROOT / 'source/six-hulls.png').convert('RGBA')
pixels = np.array(source)
labels, count = label(pixels[:, :, 3] > 0)
sizes = np.bincount(labels.ravel())
components = sorted(np.argsort(sizes[1:])[-6:] + 1,
                    key=lambda n: (find_objects(labels)[n-1][0].start // 512,
                                   find_objects(labels)[n-1][1].start))
boxes = find_objects(labels)
ships = json.loads((ROOT.parents[3] / 'data/ship_weapon_visuals.json').read_text())['ships']
records = []
u_pixels = np.array(Image.open(ROOT / 'source/u-structure-revision.png').convert('RGBA'))
u_labels, _ = label(u_pixels[:, :, 3] > 0)
u_sizes = np.bincount(u_labels.ravel())
u_boxes = find_objects(u_labels)
u_components = sorted([n for n in np.argsort(u_sizes[1:])[-6:] + 1
                       if u_boxes[n-1][1].start > 1000], key=lambda n:u_boxes[n-1][0].start)
for i, component in enumerate(components):
    family = ['triangle', 'slab', 'u'][i % 3]
    defence = 'physical' if i < 3 else 'energy'
    name = f'{family}-{defence}'
    active_pixels, active_labels, active_boxes = pixels, labels, boxes
    if family == 'u':
        component = u_components[i // 3]
        active_pixels, active_labels, active_boxes = u_pixels, u_labels, u_boxes
    ys, xs = active_boxes[component-1]
    crop = active_pixels[ys, xs].copy()
    crop[:, :, 3][active_labels[ys, xs] != component] = 0
    crop[crop[:, :, 3] == 0, :3] = 0
    hull = Image.fromarray(crop)
    # One authored family canvas extent, both materials share the same layout.
    target = {'triangle': (720,640), 'slab': (720,710), 'u': (700,720)}[family]
    hull = hull.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (887, 1774))
    canvas.paste(hull, ((887-hull.width)//2, (1774-hull.height)//2))
    canvas.save(ROOT / f'hulls/{name}.png')
    reference = ['enemy_1', 'enemy_4', 'enemy_6'][i % 3]
    records.append(dict(name=name, family=family, armourType=2 if i < 3 else 1,
                        texture=f'hulls/{name}.png', source_file='source/u-structure-revision.png' if family=='u' else 'source/six-hulls.png',
                        source_box=[xs.start,ys.start,xs.stop,ys.stop], family_extent=list(target),
                        bounds=list(canvas.getbbox()), reference_key=reference,
                        reference_texture=ships[reference]['texture'],
                        hardpoints=ships[reference]['hardpoints'], slot_map=ships[reference]['slot_map']))
(ROOT / 'candidates.json').write_text(json.dumps(dict(enabled=False, records=records), indent=2)+'\n')
