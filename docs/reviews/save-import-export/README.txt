Save import/export review candidate
Code: 6a7021687e8978b7d00ca5ac96eb128790e2f14b
Branch: feature/save-import-export
Base main: 8b631374a4c8f217af0ce3c68bd1a233ad289b6c. No main push or merge. Current equipment.xlsx and weapon_motion.xlsx preserved byte-identically.

Use Settings > Save settings > Export save to choose a JSON destination.
Import save opens a JSON picker, validates a separate fresh game, and asks explicitly to back up and replace all progress. Cancel does not alter progress. Confirmation installs the canonical migrated save and reloads main.tscn through normal startup. No extra save envelope; raw save version 4, accepts legacy 2/3.

Before replacement, user://save-import-backups/<timestamp-ticks>/current-progress.json stores latest unsaved progress. original-progress.json and original-recovery.json preserve exact disk bytes where present. Restore by choosing current-progress.json in Import save. Backups persist through ordinary saves.

New backend: 33 checks / 0 failures, exit 0. Huge GrowthNumber, permanent planet state, migration, pure export/preview, invalid types/JSON/version, backup and installation failures, rollback, repeated imports and interrupted startup recovery.
GUI: 22 checks / 0 failures, exit 0. Real InputEvent mouse/key inputs select buttons, file-list entries and confirmation. Existing save settings is opened directly as fixture setup; the top Settings menu is not asserted. Initial synthetic profile is isolated; successful imports reload the production main scene. Verified demo confirmation/cancel, future-version refusal, exported JSON, normal scene replacement, galaxy navigation/render, all 30 slots after UI round-trip, and restoration of prior unsaved 789 iron / 456 uranium through backup import.
Demo bytes are from galaxy evidence commit 6328711, not invented state or merged galaxy art. Image shows current main artwork. Paths under isolated test/work; no real user save touched.

Existing test_save_policy: 48 checks / 4 failures; existing test_save_boundaries: 20 checks / 4 failures. The same failure labels and counts reproduce on exact unmodified main 8b631374a4c8f217af0ce3c68bd1a233ad289b6c; logs from both retained. Existing failures are not claimed as passes.
GUI runtime emits a teardown ObjectDB/resource-in-use warning after live 3D rendering; no assertion failure or crash, exit 0. Godot software OpenGL Linux file-window fallback tested. Native Windows dialog and physical touch not tested. Web transfer buttons are disabled with explanatory text. Native dialogs are requested where supported. No gameplay/config strength changes.

Evidence: settings.png, confirmation.png, galaxy-imported.png; gui.log/exit; test_save_transfer.log/exit; candidate and baseline old-test logs/exit; demo JSON/readme; candidate.patch. README in test directory documents reusable entry points.

Library upload was attempted with the current official prepared-upload helper; the connection failed before creating any Library item. No Library file IDs exist for these deliverables. Git evidence is the authorized fallback.
