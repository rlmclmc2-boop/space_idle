# Enemy-area ruler only — 2026-10-19

Candidate baseline `02725575`. This follow-up adds one preview image and a QA-only ruler; no hull resizing, art normalization, production scripts/config, capacity, encounters, collision or damage changes. Elite/BOSS multi-cell specifications remain out of this step.

`enemy-area-grid-5x3.png` is an unedited1372×883 actual-main-scene window PNG with a5-column/3-row ruler drawn by the isolated test. It retains the previous eight actors' sizes and positions. The underlying save-disabled held-health QA battle fired and settled damage before pausing. This is a ruler overlay, not a new15-actor formation.

| Measurement | Logical battle units | Pixels in this PNG |
|---|---:|---:|
| Full battle clip |572×960|approximately402×675|
| Enemy band |572×499.2|approximately402×351|
| One of15 equal cells |114.4×166.4|approximately80.4×117.0|

Boundary basis: the existing `enemy_fixed_layout.gd` fifteen-contact `fixed_rows` forward limit is `BATTLE_VIEW_SIZE.y*0.52=499.2`. The ruler spans from the battle clip top0 to this limit. Existing `top=100` is a unit-centre inset inside the band, allowing first-row hull/status space; it is not the band's top edge. The ruler reserves no new exclusion zone and does not redefine a unit footprint. Blood-bar/status deductions and hull-fit decisions have not been applied.

`grid-measurements.json` records transforms, source boundaries, eight identities and unchanged model widths; `pixel-check.json` independently locates the six vertical/four horizontal cyan lines in the PNG. Raster columns are80–81px and rows117px, with clipping/AA rounding. `preview.log` records the actual run. Local runtime Godot4.6.3 Linux/OpenGL llvmpipe, GDS path; no native/performance claim.

Replay: copy `test/test_enemy_grid_preview.gd` into an isolated imported project and run it graphically via `--script res://test_enemy_grid_preview.gd` with `ENEMY_BASE_OUTPUT=<output>` and isolated XDG user directories. The ruler exists only in this test, not in the production UI.
