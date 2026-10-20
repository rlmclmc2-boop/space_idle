# Repository cleanup and test audit (in progress)

Baseline: `108080a747e3182ee8447d0ba8b41988e68cd2bc`. No gameplay-balance or production-art edits; confirmed logic/import/UI defects are being repaired in this branch. Cleanup is recoverable from that Git revision; Git history is not purged.

Removed historical run directories are listed in `removed-historical-runs.json`. They are completed old run outputs with no external tracked textual consumer found; reusable fixtures, candidates, current release/performance receipts and current art evidence remain.

Retired test removal: old scientist factory affordability/workshop/production/rate tests and old jewel table import test. Current AI technology and enhancement tests supersede those systems. Current test routes are updated.

Audit is NOT complete. Python syntax scanning passed before edits; initial isolated Python runs and Godot 4.6.3 parse results are retained here. Parse success is not behavioral acceptance. Per-test runtime checks, fixture repairs, native/Windows and GUI classification are ongoing. The work folder holds detailed logs until relevant fixes are verified; final evidence will replace intermediate summaries.

Continuation after `6aa0bdf2`: removed the six planetary hightech virtual-level rewards (IDs 2, 12, 16, 20, 24, 28) from the workbook and generated data; runtime no longer adds planet levels to researched technology. Equipment and enhancement level bonuses remain. A structural comparison confirmed that all other generated data are unchanged. The repaired `test_planet_buffs.gd` passed 23/23 checks in isolated Godot 4.6.3; `test_planet_build_config.py` passed. Planet UI fixtures were updated for the removed reward rows, but GUI behavior has not been accepted: this Linux workspace has no display, and the old `test_planet_buff_ui.gd` headless route stops before rendering a planet card. `test_game.gd` remains an unaccepted historical mixed probe; its handed-off annotation patch was reviewed and not applied because execution still fails earlier on an obsolete equipment-array assumption. Do not count those UI or mixed-probe scripts as passing.

Observed failures include obsolete aggregate-workbook fixtures, missing frozen reward-source dependency in isolated data directories, removed APIs/UI, stale editable-value assertions and outdated subclass method signatures. Do not delete a still-useful failing test or weaken its rule solely to get green results.
