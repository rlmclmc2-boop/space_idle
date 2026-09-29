# Galaxy 3D assets

Runtime source is GLB. Rebuild with the installed Blender executable:

```powershell
& 'I:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/galaxy_assets_blender.py
```

Run from the project directory. Optional `-- --preview-dir <directory>` renders an inspection lineup. No add-ons, textures, downloaded assets, or `.blend` runtime dependency. Geometry and materials are authored procedurally in [the generator](../../../tools/galaxy_assets_blender.py); [manifest.json](manifest.json) records exact paths, dimensions and triangle counts.

Use `-- --core-only` to rebuild only the central station and its manifest entry. Its current geometry lives in [galaxy_core_stylized.py](../../../tools/galaxy_core_stylized.py): a thick rounded ring, six soft armor clasps, three curved bridges, a squat panoramic command tower and two landing pads. [galaxy_core_detail.py](../../../tools/galaxy_core_detail.py) supplies baked local ambient occlusion. Vertex colors carry tint and shading; preserve `COLOR_0` when re-exporting. The core uses baked occlusion instead of casting hard runtime shadows.

## Scope and art brief

The central core now trials the subsequently selected rounded cartoon 3D direction. The other assets remain from the earlier C-direction trial: five colony levels, a shuttle, and one model for each of the other five families. Those families still share their first model across gameplay levels; this is not the completed 30-model set. Previous static PNGs are not the final 3D presentation.

Current core brief: broad ivory armor, deep navy recesses, large teal glazing and a few warm amber lamps. Rounded silhouettes and restrained surface detail must read at normal gameplay size. Geometry follows the selected imagegen concept; no concept image is used as a runtime background. Other buildings retain their earlier silhouettes until this sample is accepted.

## Integration contract

- Godot Y-up; one Blender unit equals one Godot unit. Root origin is bottom center. Runtime does not need axis correction.
- Use manifest dimensions to check slot clearance when changing geometry. Visual framing does not change saved slot positions or gameplay progress.
- `Structure` is merged static geometry. `DockSocket` is a child transform for route endpoints. Find nodes recursively beneath the imported root.
- Optional `ActivityRing` is separate geometry centered on its rotation axis; animate low-frequency rotation about Godot Y. Stop presentation processing when hidden.
- Shuttle nose points toward Godot -Z. Its runtime footprint is approximately 1.3 × 1.7 units.
- Materials use stable `Galaxy*` names across the initial families and separate `Core*` names for the detailed station, with opaque surfaces, metallic roughness and emission. The renderer may cache materials by name across imported models. No per-building lights, cameras, physics, embedded animation or transparency layers.
- Use fixed isometric orthographic projection (45-degree azimuth, approximately 35-degree downward pitch) to expose both sides and the top. Dragging must follow screen-space pointer motion under this camera orientation.

Preview lineup order: core, colony Lv1, Lv2, Lv3; colony Lv4, Lv5, shipyard, energy; iron refinery, crystal refinery, heavy refinery, shuttle. Preview scales core to 45% and shuttle to 300% for inspection only; exported GLBs retain real scale.
