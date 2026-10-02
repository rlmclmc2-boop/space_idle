# Individual-platform city direction

Static native game preview after rejection of shared district decks. Start from the approved three-building sample branch, not the rejected runtime district implementation.

`preview.gd` loads the isolated 30-slot fixture into the real game UI and renders `direction.gd`: 30 separate 16×16 functional platforms, 30 original mixed-level GLBs, one headquarters and 32 socket-matched service bridges. Families are interleaved instead of forming same-type precincts. Uneven outer branches and varying gaps break the perimeter; all 30 platforms connect to the headquarters. The shared module implementation retains approved hull, flange and mount geometry, with static mesh baking.

This is an art-direction preview only. It does not replace the production map, its picking or saved positions. Per-building interaction, construction reveal, moving aircraft, pause/visibility and level coverage must be adapted and checked after visual direction approval. No economy, save, configuration workbook, planet or Windows performance changes.

Run only in an isolated project with `test/fixtures/galaxy_1_complete.json` copied beside it, following the project test instructions. The preview writes native root and galaxy viewport PNGs beside the isolated project and exits. No user saves are loaded or written.
