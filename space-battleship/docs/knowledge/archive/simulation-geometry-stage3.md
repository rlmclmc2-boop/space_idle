# simulation-geometry-stage3
Goal: persistent shared simulation geometry authority for formal legacy/native and simulation.
Scope: geometry descriptors, battlefield/provider/slice ownership, duplicated geometry functions and affected regression.
Forbidden: gameplay/numbers/config/save changes, original checkout writes, Library, new test project, unrelated edits.
Base: b2d91c21c1ecfdbd056049edbeb654292abc9434.
Stop: substantive behavior difference requiring parent decision; context compaction; required closure and verification complete.
Locate: scripts/game.gd direct geometry callers; battlefield and simulation_geometry_authority files found by filename/symbol search.
Risk: initial pose/timing, weapon mount/head placement, native/legacy mismatch.
Read expansion: locate exact geometry ownership symbols and existing validation entrypoints (docs/TEST.md); inspect only relevant implementations.
Next: enumerate consumers and send precise plan before implementation.

Safe partial completed: 26 shared geometry bodies extracted and unused authority beam_style removed; consumer/dependency matrix and evidence at test/evidence/simulation-geometry-stage3. Coordinate inverse 10015/0 and seating 90/0 passed. weapon_fx stopped at obsolete profile.loadout fixture before attacks. Full lifecycle not implemented; pending user behavior baseline for static_height vs prepared PNG heights. Parent dot review pending; Astra high normalized-body audit passed.
