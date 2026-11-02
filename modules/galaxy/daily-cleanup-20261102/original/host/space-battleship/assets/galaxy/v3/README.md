# Galaxy orbital assets

GLB is the runtime authority. The separate central headquarters anchors 30 functional nodes in the first Galaxy; types, IDs, rotation, prerequisites and counts come from the saved construction blueprint; view positions use the approved individual-platform mapping documented in [GALAXY](../../../docs/GALAXY.md).

## Rebuild and provenance

All geometry and the static [space field](galaxy_field.svg) are original, repository-authored work. No downloaded models, textures, add-ons or external license dependencies are used. The core's selected rounded concept is modeled by [galaxy_core_stylized.py](../../../tools/galaxy_core_stylized.py) with [baked shading](../../../tools/galaxy_core_detail.py). It remains a separate headquarters, never a functional slot.

All six functional families have five unique progressive levels: habitat rings, open-rail shipyards, solar paddles, orbital alloy foundries, clamped crystal processing rigs and heavy-element pressure vessels. Broad matte ivory armor and navy hulls match the accepted ship world. Blue solar paddles, cyan crystals and warm foundry roofs separate the functional families at normal map size; open shipyard frames and pressure vessels omit subpixel fittings. Headquarters keeps its rounded silhouette with the same ivory/navy/teal palette. Floating hulls, cargo berths and service collars keep the stations orbital; no ground stairs, smoke or terrain are baked into them.

From the project directory with Blender 4.3 or newer:

```
blender --background --python tools/galaxy_toon_buildings.py -- --shuttle
```

Add `--family colony_ring interstellar_refinery --levels 1 5` for a filtered rebuild. Add `--preview-dir PATH` to render a level lineup; `--preview-only` avoids re-exporting. Disable Cycles denoising where OpenImageDenoise is unavailable (the generator does this). To rebuild only the preserved headquarters, use `tools/galaxy_assets_blender.py -- --core-only`.

[manifest.json](manifest.json) records exact paths, bounds, triangle counts and bytes. Geometry is bounded per model; levels change the silhouette without exceeding the plan's reserved footprint. There is no runtime Blender dependency.

## Runtime contract

- Godot Y-up; one Blender unit equals one Godot unit. Functional roots are planar/bottom centered. The core adapter in `galaxy_city_layout.gd` corrects its audited unscaled bottom Y=0.09 and X/Z center `(0.43235588,1.19500065)`. Apply blueprint `rotation_y`; functional renderer scale is `galaxy_map.gd::BUILDING_SCALE`, while the core stays at 1.2. Model and dock extensions must remain inside the complete 14×14 functional footprint (core 32×32)
- `Structure` is merged static geometry. `DockSocket` is a child transform; find it recursively beneath the imported root. The shuttle nose points toward Godot -Z
- `Core*` and `GalaxyToon*` materials use white albedo with baked tint/shading in `COLOR_0`; enable vertex-color albedo after import. Preserve this attribute on re-export. Material names are shared cache keys
- Opaque meshes only. No per-building lights, cameras, physics, embedded animation, live viewports or transparency stacks. The entire Galaxy uses one independent orthographic viewport and one opaque imported backdrop texture
- Each functional building has one independent static platform, mounting collar and service ports, with mixed types across the city. The local PipeSocket is Y=-0.9 with outward +Z; 4.8×1.8 bridges join opposed equal-height ports. Empty slots retain selectable planned foundations. Platforms and bridges are baked on region selection; upgrades reuse them. Traffic follows independent elevated dock-to-dock routes and its count is hidden; construction vessels remain separate. A building under construction reveals its real model using full `node_progress`, with a restrained gantry; upgrading retains the current-level model
- Visible sampling updates affected model/state nodes only. Cached assets/materials/static routes are reused; hidden and paused pages stop viewport rendering, traffic and construction motion. The backdrop is static, with no shader clock. Small UI-scaled windows bound viewport fill cost while retaining 4× edge AA

Display traffic is tuned in `config_excel/galaxy_config.xlsx`: `transport_buildings_per_ship` (completed buildings/boat), `max_transport_ships` (upper bound), `transport_initial_delay` and `transport_departure_interval` (seconds). These never affect work or income. The pool grows with completed buildings, reuses scenes/materials and departs in staggered batches.

Use the logic-owned [complete fixture](../../../../test/fixtures/galaxy_1_complete.json) for normal-UI full-build QA. `test_galaxy_assets.gd` verifies all level imports, vertex tint and scaled footprint; `test_galaxy_ui.gd` verifies exact plan consumption, normal UI captures, picking, pan/zoom, construction/upgrade states and stopping/reuse behavior.
