"""Split the approved atlas without redrawing hull pixels. Requires Pillow, numpy, scipy."""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name('hulls-transparent.png')
OUTPUT = ROOT / 'assets/ships/fleet_20261019/player'
KEYS = ['Frigate', 'Destroyer', 'Cruiser', 'Battleship', 'Heavy_Battleship']
NAMES = ['01-frigate', '02-destroyer', '03-cruiser', '04-battleship', '05-heavy-battleship']
# Socket centres in the supplied gun-free atlas, matched to the approved lineup.
POINTS = [[(118, 480)], [(327, 374), (466, 374)],
          [(770, 216), (657, 455), (887, 455)],
          [(1064, 218), (1329, 218), (1068, 509), (1328, 509)],
          [(1694, 171), (1524, 298), (1864, 298), (1524, 457), (1864, 457)]]


def main():
    pixels = np.array(Image.open(SOURCE).convert('RGBA'))
    alpha = pixels[:, :, 3]
    labels, _ = ndimage.label(alpha > 127)
    counts = np.bincount(labels.ravel())
    ids = [int(i) for i in np.flatnonzero(counts > 10000) if i]
    ids.sort(key=lambda i: np.nonzero(labels == i)[1].mean())
    assert len(ids) == 5, ids
    # Reassign only the immediate anti-aliased fringe to its nearest solid hull.
    # This removes isolated alpha noise and separates the touching 3/4 fringes.
    solid = np.isin(labels, ids)
    distance, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
    owner = labels[tuple(nearest)]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'alpha_floor': 16, 'fringe_radius': 2, 'hulls': {}}
    for key, name, ident, points in zip(KEYS, NAMES, ids, POINTS):
        mask = (owner == ident) & (alpha > 16) & (distance <= 2)
        yy, xx = np.nonzero(mask)
        box = [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)]
        crop = pixels[box[1]:box[3], box[0]:box[2]].copy()
        crop[~mask[box[1]:box[3], box[0]:box[2]]] = 0
        # Zero RGB outside alpha too, so filtering cannot pick up stray colour.
        crop[crop[:, :, 3] == 0] = 0
        padded = Image.new('RGBA', (crop.shape[1]+32, crop.shape[0]+32))
        padded.paste(Image.fromarray(crop), (16, 16))
        path = OUTPUT / (name+'.png')
        padded.save(path)
        normalized = [[round((x-box[0]+16)/padded.width-.5, 6),
                       round((y-box[1]+16)/padded.height-.5, 6)] for x, y in points]
        for x,y in points:
            assert mask[y,x], (key,x,y)
        report['hulls'][key] = {'texture': 'res://'+str(path.relative_to(ROOT)),
            'source_bounds': box, 'canvas': list(padded.size),
            'opaque_size': [box[2]-box[0], box[3]-box[1]],
            'hardpoints': normalized, 'static_height': round((box[3]-box[1])*.2, 2),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    ui_dir = ROOT / 'assets/ui/ships/fleet_20261019'
    ui_dir.mkdir(parents=True, exist_ok=True)
    for key, name in zip(KEYS, NAMES):
        row = report['hulls'][key]
        image = Image.open(ROOT / row['texture'].removeprefix('res://'))
        scaled = image.resize((round(image.width*.95), round(image.height*.95)), Image.Resampling.LANCZOS)
        ui = Image.new('RGBA', (768, 768))
        offset = ((768-scaled.width)//2, (768-scaled.height)//2)
        ui.paste(scaled, offset)
        ui_path = ui_dir / (name+'.png')
        ui.save(ui_path)
        row['ui_texture'] = 'res://'+str(ui_path.relative_to(ROOT))
        row['ui_mounts'] = [[round(offset[0]+(p[0]+.5)*scaled.width, 4),
                             round(offset[1]+(p[1]+.5)*scaled.height, 4)] for p in row['hardpoints']]
        row['ui_height'] = round(row['opaque_size'][1]*scaled.height/image.height, 4)
    Path(__file__).with_name('split-report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
