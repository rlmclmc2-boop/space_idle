# Enemy fleet — toon v1

Asset-only handoff from `5fd7473d81f7340dc7e075c6c51d62e1c8478b4a`. Six authored Blender hulls share graphite structure, slate armor, rust identification panels and amber engines. Broad facets and modest bevels match the prototype's orthographic science-fiction language. No installed weapons are baked in.

| Runtime key / size | Configured enemy IDs | File stem | Silhouette |
|---|---|---|---|
| enemy_1 / 1 | 3, 4 | enemy-scout-1slot | Short wedge, single drive |
| enemy_2 / 2 | 1, 2 | enemy-medium-1slot | Forked twin hull, twin drive |
| enemy_3 / 3 | 5, 6 | enemy-medium-2slot | Swept wide shoulders |
| enemy_4 / 4 | 7, 8 | enemy-large-4slot | Transverse hammerhead |
| enemy_5 / 5 | 9, 10 | enemy-large-6slot | Long parallel outriggers, triple drive |
| enemy_6 / 6 | 11, 12 | enemy-super-8slot | Broad citadel, four drives |

The `mon.xlsx` size column matches `data/game_data.json`. Runtime uses `enemy_` plus clamped size, not enemy ID or filename slot count. `manifest.json` snapshots the existing slot maps and hardpoints for handoff; `data/ship_weapon_visuals.json` remains authoritative. Hull generation never changes loadouts or combat data.

## Consume

Use `res://assets/ships/enemy/toon_v1/<stem>.png` as the texture for the corresponding existing key. Sprites are RGBA, 887×1774, bow up, center pivot `(0.5,0.5)` with transparent safe margins. Preserve the existing `PI + angle` rotation, draw dimensions, depth modulation, config scaling and weapon overlay placement. No alpha-bounds cropping or automatic fit-to-visible-content: that would enlarge these assets and move the pivot. Source art is intentionally compact; the full canvas is the sizing contract. Existing hardpoint overlays should be visually checked after integration; no muzzle coordinates were edited.

Optional GLB: same stem, meter units, origin at sprite center; Blender +Y bow exports to Godot -Z, +Y up in Godot. These files contain meshes/materials only. Reuse a shared scene or the sprites; six per-enemy live viewports are unnecessary. Warm emissive engine faces are static identification, not attack VFX. Keep the integration branch's simplified enemy projectile/laser effects and existing attack parameters.

## Rebuild / review

Run from the repository root:

```sh
blender -b -t 4 --python-exit-code 1 --python space-battleship/assets/ships/enemy/toon_v1/build_enemies.py
python space-battleship/assets/ships/enemy/toon_v1/review_enemies.py
```

Requires Blender 4.3+; review compositor requires Pillow and DejaVu Sans. Each `.blend` is editable source with the exact sprite camera and lighting. The generator is the procedural authority; hand edits in Blend files must be ported back before regeneration. CPU Cycles, 24 samples, no optional denoiser. Rendering uses a common top-down orthographic camera and a directional key matching the prototype’s (-35, -50, 0) Godot rotation and low ambient fill (the baked key is pre-rotated by PI to compensate the existing enemy sprite rotation); no background or ground shadow.

`review/six-ships-same-scale.png` uses one pixels-per-meter scale for all six hulls. `review/enemy-fleet-review.png` shows downward-facing sprites on a neutral background at 1× and 3× display sizes, using full-canvas widths 40/44/48/55/58/62px. It is a readability review, not a live gameplay screenshot or formation prescription. No player hull is shown. `review/checks.json` records alpha and evaluated GLB bounds. Runtime integration and final weapon-overlay capture belong to the scene integration task.

The refinement retains the vertical orthographic camera, framing and XY footprints. Broad sloping armor shoulders, darker lower skirts, recessed command wells and raised bow shields provide readable volume without dense panel lines. Polygon winding is normalized before export so mirrored hulls have outward-facing normals. No slot projection or configuration changed.
