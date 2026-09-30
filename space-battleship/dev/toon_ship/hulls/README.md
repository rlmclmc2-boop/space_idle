# Friendly hull assets

Five independently authored silhouettes: Frigate dart, Destroyer twin booms,
Cruiser swept diamond, Battleship armored bulwark, Heavy_Battleship crown with
separated stern lobes. Broad ivory armor, navy structure and restrained cyan
energy use the existing runtime toon materials. Hulls contain no weapons.

Source authority: [generator](../build_hybrid_hulls.py); editable Blender sources
in `source/`. Generated paths, bounds and sockets: [manifest](../hybrid_manifest.json).
From `space-battleship`, regenerate only the five hulls with:

```sh
blender --background --factory-startup --python-exit-code 1 \
  --python dev/toon_ship/build_hybrid_hulls.py -- --hulls-only
```

This mode preserves the independent drone and weapons. Existing WeaponMount,
Engine and ExhaustSocket names/transforms, model lengths, display budgets and
gameplay configuration remain unchanged. No shared renderer changes are needed.

Each hull uses six solid materials, no texture maps, and 3–5 mesh nodes.
Triangles in class order: 4428 / 5320 / 6576 / 6240 / 8612. Runtime uses the
existing material replacement; these are asset counts, not performance claims.

## Review

- [Scale and battle sheet](review/five-hulls-scale-and-battle.png): upper row at
  one common model scale (19.15 physical px/m), lower row native battle pixels.
  Crops are repositioned on the sheet, never enlarged. Hull heights in the
  391px-wide field are 66.3 / 67.7 / 97.7 / 108.3 / 145.8px.
- [Actual battle](review/battle-391px.png): 1335×859 Godot capture, synthetic mixed
  full loadout, optional beginner guide hidden in the isolated capture only.
  Background, enemy and UI are the original branch baseline; integration owns
  their new art. No player save was opened or written.
- [Validation](review/validation.json): Godot 4.6.3 import, five headings and 180
  turret-angle samples per hull, socket hierarchy, projected formation bounds,
  node reuse, loadout removal/restoration, state/RNG preservation and live effects.
  Reproduce with `preview.py --fixture all --mode full-loadout` from the parent
  directory's [preview documentation](../README.md).

Known limits: Cruiser has 14 conservative projected weapon-AABB overlaps at
diagnostic rear-angle frames 104–117 (slots 2/3); exactly reproduced with the
unchanged `5fd7473d` GLB. Front view and the other four hull sweeps have none.
This is not a mesh-intersection test. The existing 2D VFX/3D depth-compositing
boundary remains. Verified on Linux software OpenGL, not Windows or a GPU/perf
matrix. Production-scene integration and latest equipment UI remain separate.
