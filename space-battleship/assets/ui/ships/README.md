# Static live-hull previews

The five transparent hull PNGs are static snapshots of the friendly GLBs in `dev/toon_ship/hybrid_manifest.json`. They contain no installed weapons. Weapon modules use one physical hull mount per active slot.

`manifest.json` records the live model path, projected socket centers, framing, material settings and source SHA-256 fingerprints. `ship_panel.gd` caches one Texture2D per hull and uses `hybrid_layout.assign`, the same slot assignment as battle. Empty slots remain empty rows; candidate actions are read-only. Locked hulls use the same texture with the silhouette shader. No runtime preview viewport or frame update is introduced.

Regenerate in an isolated, imported runtime project that includes `dev` and `addons` but excludes Blender authoring files (or has Blender configured): set `SHIP_PREVIEW_OUTPUT` to the intended asset directory and run Godot with `--path <isolated-project> --script res://dev/toon_ship/bake_panel_previews.gd`. Use the normal graphical renderer; headless rendering does not produce these images. The producer reads the current normal scene's presentation defaults without entering it in the tree.

Focused regression: run `test/test_single_slot_visual.gd` with an isolated user directory. It captures all five equipped hulls and reports physical mount, module and carrier counts. The fixture reads no player save.
