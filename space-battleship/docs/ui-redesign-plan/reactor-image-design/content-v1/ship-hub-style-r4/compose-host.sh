#!/usr/bin/env bash
# Review-only full-screen montage: generated art in the fixed 808x835 content rectangle.
set -euo pipefail
art_dir="$(cd "$(dirname "$0")" && pwd)"
for mode in four three; do
  magick "$art_dir/shared-host-reference.png" \
    \( "$art_dir/reactor-${mode}-raw.png" -resize '808x' -gravity center -crop 808x835+0+0 +repage \) \
    -gravity northwest -geometry +0+65 -compose over -composite \
    "$art_dir/reactor-${mode}-host-layout.png"
done
