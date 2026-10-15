#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
review_tmp=$(mktemp -d /tmp/opening-extension-review.XXXXXX)
trap 'rm -rf "$review_tmp"' EXIT
magick source/extension-03-04-generated.png -resize 652x1955! -crop 572x960+43+18 +repage "$review_tmp/registered.png"
magick source/array-join-repair-generated.png -resize 572x500! -crop 572x250+0+0 +repage "$review_tmp/repair.png"
magick -size 572x64 gradient:black-white -size 572x186 xc:white -append "$review_tmp/mask.png"
magick "$review_tmp/registered.png" -crop 572x250+0+710 +repage "$review_tmp/repair.png" "$review_tmp/mask.png" -composite "$review_tmp/join.png"
magick "$review_tmp/registered.png" "$review_tmp/join.png" -geometry +0+710 -composite "$review_tmp/extension.png"
magick "$review_tmp/extension.png" ../phase-01-02-balanced/source/prepared-master.png -append source/candidate-through-04.png
magick source/candidate-through-04.png -crop 572x500+0+710 +repage review/join-failure.png
# Deliberately no runtime export: the painted source join has not passed review.
python3 - <<'PY'
from PIL import Image
master=Image.open('source/candidate-through-04.png').convert('RGB')
for stage,origin in [(3,480),(4,0)]:
    tile=master.crop((0,origin,572,origin+1440))
    pad=Image.new('RGB',(572,1444));pad.paste(tile,(0,2))
    for y in (0,1):
        pad.paste(tile.crop((0,0,572,1)),(0,y))
        pad.paste(tile.crop((0,1439,572,1440)),(0,1442+y))
    pad.save(f'review/stage-{stage}-candidate.png')
PY
