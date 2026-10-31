#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# The source sheets only supply device surfaces. The eight conduit layers are
# separately rendered by generate_modular_pipes.py and animated by Godot.
magick modular-core-source.png -crop 615x850+285+0 +repage -resize '418x638!' modular-core.png
magick modular-modules-source.png -crop 570x430+0+100 +repage -resize '359x271!' modular-weapons.png
magick modular-modules-source.png -crop 467x430+720+105 +repage -resize '294x271!' modular-defence.png
magick modular-modules-source.png -crop 595x520+25+585 +repage -resize '315x276!' modular-smelting.png
magick modular-modules-source.png -crop 520x505+655+635 +repage -resize '291x283!' modular-condensation.png
# The console is a separate architectural shell. Reuse its approved compact
# cavity for 1/2/3 rows, keeping every slider/label native above it.
magick -size 1187x70 gradient:none-white -size 1187x586 xc:white -append /tmp/b01-modular-console-fade.png
for state in compact four; do
  source=one-idle-console.png
  if [ "$state" = four ]; then source=idle-console.png; fi
  magick "$source" -crop 1187x656+0+670 +repage /tmp/b01-modular-console-color.png
  magick /tmp/b01-modular-console-color.png /tmp/b01-modular-console-fade.png -compose CopyOpacity -composite "modular-console-$state.png"
done
# Blender renders each independent physical layer on the source canvas. Tight
# alpha bounds keep the eight transparent quads from shading the whole bay.
for id in weapons defence smelting condensation; do
  for layer in shell front; do
    file="modular-pipe-$id-$layer.png"
    magick "$file" -trim +repage "$file.trim.png"
    mv "$file.trim.png" "$file"
  done
done
for side in left right; do
  x=395
  if [ "$side" = right ]; then x=603; fi
  file="modular-core-clamp-$side.png"
  magick "$file" -crop "190x45+$x+300" +repage "$file.crop.png"
  mv "$file.crop.png" "$file"
done
magick modular-core-rotor.png -crop 240x240+475+210 +repage modular-core-rotor.crop.png
mv modular-core-rotor.crop.png modular-core-rotor.png
