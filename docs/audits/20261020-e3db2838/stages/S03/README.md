# S03 review handoff — awaiting dual review

- Stage: S03 durable fields and portable round trip (A01)
- Base main: `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`
- Runtime candidate: `0d01530bdce168a55d0ce7c835f17072d66d6bc7` (remote `s03/durable-portable`, one runtime file)
- Audit base: `6486727dfec23a94a0f9cce93ffc2da8610bf6ad`
- Status: **review**. Parent and astra verdicts are pending; no main integration or stage closure.

## File necessity

| File | Destination | Why it is needed |
| --- | --- | --- |
| `space-battleship/scripts/save_transfer.gd` | Runtime candidate only | Its portable schema and cleaner dropped eight already durable top-level fields and `resourceSamples[].production_time`. The accepted save versions remain 2, 3, 4, and `BattleGame.SAVE_VERSION`. |
| `test/test_save_transfer.gd` | Audit evidence only | Covers the ordinary durable field inventory, values through save/export/prepare/pre-import backup/reload, rejected malformed values, and existing recovery behavior. Includes one exact completion marker for the S01 gate. |
| `docs/audits/20261020-e3db2838/stages/S01/gate.py` | Audit evidence only | Adds this S03 transfer test to the existing completion/error gate; it changes no gate rule. |
| `docs/audits/20261020-e3db2838/stages/S03/README.md` | Audit evidence only | Records scope, source SHA, verification and open review status. |
| `docs/audits/20261020-e3db2838/stages/S03/reproduction.json` | Audit evidence only | Records executable baseline failure and candidate pass. |

## Ownership and time semantics

The ordinary writer keeps ownership of the saved profile; `save_transfer.gd` owns the portable field whitelist and type checks. The AI level/progress/selection/input/peak/unread fields, `productionElapsed`, and `equipmentSwitchUntil` are copied without time conversion. `resourceSamples[].production_time` remains in the existing production clock domain. `game.gd` continues to restore and filter these values using its prior rules; this candidate changes no clock, deadline, offline reward, or migration rule. Unknown metadata remains stripped. Known fields with wrong types still fail `prepare_data` before live or disk replacement. No new time policy decision arose.

## Reproduction and verification

Platform: Windows `BJNLPC-0459`, Python 3.12, Godot `4.7.2.stable.official.ed1daf0bf`. All game runs used generated projects under `test/work` with isolated user directories. No personal save data was used.

1. Baseline reproduction: the modified transfer test against baseline `e3db2838`'s `save_transfer.gd` exits 1 with `Portable contract covers durable fields and sample production time` failed. The diagnostic lists exactly the eight absent top-level fields and `sample.production_time=false`; see `reproduction.json`. No game implementation file was changed for this repro.
2. Candidate test: set `PYTHONIOENCODING=utf-8`, then run `python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_transfer.gd --headless --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe` with the audit test patch overlaid on the runtime candidate. Result: `SAVE TRANSFER: 154 checks, 0 failures` and `S01_GATE_PASS: test_save_transfer.gd`.
3. Static diff: `git diff --check e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3 944f8e65a77d1a5dfc2bf0fee2ecd6fc933188cc` passed on the identical local tree. Candidate commit changes only `space-battleship/scripts/save_transfer.gd`.

The first candidate test run reported four failures from directly comparing parsed JSON integer maps with in-memory maps. The fixture now compares their integer values; the final S01-gated rerun above is the review result. Godot also printed a system CA certificate warning, but the game test and gate both completed successfully.

## Review handoff

The parent and astra should review the same runtime candidate and this evidence snapshot. If the runtime SHA changes, repeat both reviews. The audit-side test and evidence are excluded from the runtime commit and from main. The remote runtime commit has the same tree `10bf32ba2e060cde7269b6f54459a989e5b5538b` as the locally tested candidate `944f8e65a77d1a5dfc2bf0fee2ecd6fc933188cc`. Publication used the user's explicit repository push authorization after the initial auto-review rejection.
