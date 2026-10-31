# Orbital models

Source: editable Blender scenes, refined from the approved procedural Godot meshes; no third-party model assets. Editable sources and scripts: `../../../../art_sources/orbital/`. Runtime: `scripts/orbital_facilities.gd`; card icons: `scripts/planet_art.gd`.

- `*.glb`: chunky matte cream/navy/amber/cyan forms, solid blue solar wings, without fine grids or antennae. Recognition comes from station wings, refinery tanks, a workshop press and an open docking cradle. Static hull and moving hardware are merged separately by material; budgets are checked by `test_orbital_blender_assets.gd`. Geometry statistics: `model-stats.json`.
- `*-icon.png`: transparent 768px Eevee renders of the matching models; import with mipmaps and alpha-border fixing. Scene models use the shared 1024x256 atlas; card icons occupy 76x64 logical pixels.
- Preserve the `Facility` root and `Motion` pivot, local origin, scale and axes when editing. Godot owns body spin, orbit and hardware motion; do not bake these into exported transforms or add autonomous animation.
- Edit the `.blend` files, then run `blender --background --python art_sources/orbital/export_models.py` from the project directory. This exports only the model hierarchy, excludes studio cameras/lights and regenerates icons. Reimport in Godot and run the asset and orbit acceptance tests.
- Geometry rebuilds: `simplify_refinery.py` replaces only the refinery; `simplify_facilities.py` replaces the other three sources/models/icons. Both preserve existing pivots and studio settings. Use `export_models.py` to export manual scene edits without rebuilding geometry. Check the normal game view and unscaled orbital crops; icon renders alone do not establish readability.
- `cartoon_pass.py` applies the palette and recognition details once to pre-pass sources; rerunning on edited scenes duplicates those details. Use `export_models.py` for normal edits.
- `polish.py` rebuilds the source files from `base-*.glb`, overwriting manual source edits; use only for an intentional procedural rebuild. The source directory is excluded from Godot import by `art_sources/.gdignore`.
