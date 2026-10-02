# Individual-platform city direction

Static native game preview after rejection of shared district decks. Start from the approved three-building sample branch, not the rejected runtime district implementation.

`preview.gd` loads the isolated 30-slot fixture into the real game UI and renders `direction.gd`: 30 separate 16×16 functional platforms, 30 original mixed-level GLBs, one headquarters and 32 socket-matched service bridges. Families are interleaved instead of forming same-type precincts. Uneven outer branches and varying gaps break the perimeter; all 30 platforms connect to the headquarters. The shared module implementation retains approved hull, flange and mount geometry, with static mesh baking.

This remains the static approved-direction preview. The formal runtime now uses `scripts/galaxy_city_layout.gd`, `galaxy_city_structure.gd` and the same `galaxy_city_modules.gd`; the preview is not the runtime input handler. `test_galaxy_ui.gd` verifies individual picking, construction/upgrade, flight and pause/visibility behavior. No economy, save, configuration workbook, planet or Windows performance changes.

Run only in an isolated project with `test/fixtures/galaxy_1_complete.json` copied beside it, following the project test instructions. The preview writes native root and galaxy viewport PNGs beside the isolated project and exits. No user saves are loaded or written.
