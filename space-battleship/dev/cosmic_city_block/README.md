# Cosmic city block — design prototype

Review-only scene, not wired into the production galaxy renderer. Reuses the original level-3 habitat, alloy refinery and heavy-element refinery GLBs. No gameplay, blueprint, configuration workbook or save changes. Reference: `design/cosmic-city-reference@bcc0d8e`, `reference/cosmic-city-direction.png` (user-approved).

## Interface proposal

- Y-up, platform origin at the building contact plane Y=0. Building root sits on that plane; functional model scale remains 1.4. Existing `DockSocket` is aircraft-only.
- Building envelope remains 14×14. This separate district prototype adds a 16×16 chamfered structural deck with hull depth 3.2; its street margin is not yet mapped to saved lots. Production layout ownership/clearance must be resolved before rollout.
- Each used platform side owns a `PipeSocket` marker at local `(±8,-0.9,0)` or `(0,-0.9,±8)`. Its local +Z points outward, +Y upward. Use the marker's complete global transform, never guessed building-center offsets.
- Matching closed service bridges have outer section 4.8 wide ×1.8 high, deck surface Y=0. Hollow side skins, roof and floor mate to a real open collar; platform walls are split around the aperture. The collar has a narrow assembly clearance, not a decorative plate over a wall.
- Straight spans require opposed socket normals and equal transformed heights. They terminate at the two mating planes. Roof guardrails stop before collars. The shared elbow chamber uses the same section and two open mouths; unequal spans follow actual platform spacing.
- The third platform rotates 90°; its local east/north ports become the required world north/west ports. Four connections exercise straight and elbow joins. No per-frame rebuild, added lights or extra viewport.

## Compatibility findings and limits

The preview audits all 30 functional GLBs plus headquarters. The functional models are bottom-centered and fit the existing 14-unit footprint after scaling (maximum 13.644). None contains a pipe socket. Headquarters is an exception: unscaled Structure bottom is Y=0.09 and X/Z center is approximately `(0.4324,1.1950)`; its future adapter must offset the model before placing it on a wider hub deck. Do not use the old presumed origin as a service connection.

Only these three families are visually prototyped. No automatic conversion of all levels, hub platform, branches or normal-game picking is claimed. Geometry is kept inspectable for review; approved modules should be exported/merged before production rollout.

## Preview

Use an isolated project and user directory per [TEST](../../docs/TEST.md), with the repository's `test/fixtures/galaxy_1_complete.json` placed at `res://../test/fixtures/`. Run Godot with `--script res://dev/cosmic_city_block/preview.gd`. It uses real `main.tscn` and the existing galaxy viewport, replaces only its presentation with this design scene, then exports full UI/overview/two connection close-ups and the 31-asset audit beside the isolated project. No player save is read or written.
