# S04 review entry — complete recovery selection (A02)

Status: **review**. Parent and original astra must independently review the same runtime SHA and final audit evidence commit. No main merge, stage closure, or S04a start is authorized by this entry.

| Item | SHA |
| --- | --- |
| Starting main | `0d01530bdce168a55d0ce7c835f17072d66d6bc7` |
| Pure runtime candidate | `3d24f84a10d6aa415f73008b2059356eb9e749b9` |
| Runtime tree | `b5a8788dd3b7cc190152e07fa8c19619de5cd774` |
| Audit starting point | `b4216a436896fc0170932c9f45ee7f2a8ca14068` |
| Audit evidence | Final SHA is the audit branch tip containing this file and `PLAN_SHA256SUMS.json`; inspect both before review. |

## Scope and runtime file necessity

| Runtime file | Why main needs it |
| --- | --- |
| `space-battleship/scripts/progress_writer.gd` | Applies one semantic validation/legacy normalization path to primary, interrupted-import previous file, and backup; returns `loaded/invalid/absent` with source, quality and rejection reasons. Complete committed saves outrank compatible sparse saves; equal quality retains primary/previous/backup order. File selection has no writes. A later save cannot rotate a sparse primary over a complete backup; failed installation restores the previous path. |
| `space-battleship/scripts/game.gd` | Loads only a validated candidate and finalizes interrupted-import staging after live loading. If finalization fails, it reports `progress_recovery_pending`, keeps the selected live progress and disk files, and disables manual and timed saves. Supplies the current database to shared validation. |
| `space-battleship/scripts/save_transfer.gd` | Defines the full v5 core structure separately from allowed sparse legacy defaults. Sparse v2–v5 saves remain loadable when no complete committed copy exists. Missing `highestLevel` receives the old loader's default `1` on a copy; sparse negative balances receive the old fresh-profile default. It also protects `.rejected` from export targets. |

The full v5 core requires `resources`, `highestLevel`, `cleared`, `unlocked`, `selectedShip`, `loadout.weapons`, `loadout.defence`, and `moduleVersion`. Earlier versions use their smaller historical core. Missing core fields lower a save to `compatible_sparse`; they do not make it outrank a complete copy. Legacy normalization is in memory. No save is rewritten by candidate selection. Unknown portable metadata is still removed by the existing cleaner; known malformed values still fail. This stage does not add multi-instance ownership or merge progress.

## First review and repair

Parent and original astra rejected runtime `d51d9cab27a510b79094519674ce92303e12158f` with evidence `e04e6a9aa8b973aae8986743a1f61891e980a696`. A sparse v5 primary with `version/resources/highestLevel` still masked a complete backup and could replace that backup on the next save. A failed `finish_loaded_recovery` was also silently ignored. The new matrix contains both exact regressions; this new candidate requires fresh independent verdicts. No existing PASS is carried forward.

## Audit-side file necessity

| Audit file | Purpose |
| --- | --- |
| `test/test_save_recovery_s04.gd` | Isolated recovery matrix including both review counterexamples, no-loss backup selection and rotation, pending-finalization write blocking, double failure, historical sparse compatibility, interrupted import, and byte preservation. Never enters main. |
| `test/test_save_transfer.gd` | Updates two S03 assertions to the S04 read-only selection contract and tests cleanup after successful game load. Existing durable round-trip checks remain. Never enters main. |
| `docs/audits/20261020-e3db2838/stages/S01/gate.py` | Registers the new test's exact completion marker under the existing S01 exit/diagnostic gate. Audit only. |
| `docs/audits/20261020-e3db2838/stages/S04/README.md` | This review handoff, commands, file reasons, results, and open review state. |
| `docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md` and `PLAN_VALIDATION.json` | Advance only S04 to review and correct S03's obsolete “待父级统一关闭” summary. |
| `docs/audits/20261020-e3db2838/PLAN_SHA256SUMS.json` | Final Git blob byte digests of audit evidence and prior manifest entries. |

## Verification on Windows

Host `BJNLPC-0459`; Godot `4.7.2.stable.official.ed1daf0bf`; Python 3.12. Each `test/run.py` invocation created its own generated project and isolated user directory under `test/work`. Synthetic saves only. The runtime candidate and audit test/gate files were overlaid locally for the audit runs; only the three runtime files are committed in the runtime candidate. Run from repository root with `PYTHONIOENCODING=utf-8` and `--godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`:

1. `python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_recovery_s04.gd --headless ...` — `S04_RECOVERY: 27 checks 0 failures`, one completion marker, `S01_GATE_PASS`.
2. `python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_transfer.gd --headless ...` — `SAVE TRANSFER: 155 checks, 0 failures`, one completion marker, `S01_GATE_PASS`.
3. `python test/run.py test_save_policy.gd --headless ...` with the S02 audit fixture — `Save policy: 51 checks, 0 failures`. The unpatched main fixture's three known setup failures remain excluded from acceptance, and its legacy v2 assertion initially exposed the compatibility gap fixed by this candidate.
4. `python test/run.py test_save_startup_rejection.gd --headless ...` — 7 checks, 0 failures.
5. `python test/run.py test_hyperspace_disk_migration.gd --headless ...` — 15 checks, 0 failures.
6. `python test/run.py test_hyperspace_state.gd --headless ...` — `HYPERSPACE_CURRENT 284 checks 0 failures`; covers an existing direct `read_progress` caller.
7. `python test/run.py test_save_boundaries.gd --headless ...` — 21 checks, 0 failures; retains the existing sparse v5 and negative-balance migration behavior.
8. `git diff --check 0d01530bdce168a55d0ce7c835f17072d66d6bc7 3d24f84a10d6aa415f73008b2059356eb9e749b9` — clean.

The generated logs stayed outside Git. Godot printed its existing Windows root certificate store warning during import; the S01 gate found no script/parse errors. The older `test_save_import_recovery.py` driver assumes a POSIX `test/work` path on Windows and expects `read_progress` itself to mutate disk; its assumptions no longer describe this read-only API. The S04 matrix and updated S03 transfer test exercise the affected recovery paths in isolated Godot projects. Fresh-process power-loss and multi-instance behavior are not claimed by this evidence.

## Review boundary

The current review target is exactly runtime SHA `3d24f84a10d6aa415f73008b2059356eb9e749b9` plus the frozen audit branch commit. Both parent and original astra verdicts on this object are **PENDING**. If runtime or evidence changes, recheck the final objects before approving. Main is still `0d01530bdce168a55d0ce7c835f17072d66d6bc7`; integration and actual player entry verification belong to the parent after both PASS verdicts.
