Current save import/export review candidate
Code: 40e54c9e327e4dc93b0d39ba755ee582c16f2bbe
Source branch: feature/save-import-export; no main merge or push.

REVIEW-FIXES.txt is the current report: both reproduced P2 blockers, fixes, tests, scope and limitations. Previous candidate6a70216 is superseded.

candidate.patch: complete candidate against main8b63137.
review-fixes.patch: changes from6a70216.
recovery-before.log: reproduced orphan-staging failure on6a70216.
graph-before.log: actual malformed-graph renderer failures on6a70216.
recovery.log and recovery/: eight fresh-process/active-owner scenarios, including four real SIGKILL exits(-9).
test_save_transfer.log: 51 checks / 0 failures.
gui.log: 22 checks / 0 failures on71f5005, actual demo import/render/round-trip/backup recovery.
settings.png, confirmation.png, galaxy-imported.png: current screenshots.
Old save-policy/boundary logs retain baseline-matched failures, not passes.
Library attempt failed before creation; this Git evidence is the authorized fallback.
SHA256SUMS.txt covers every retained artifact.
