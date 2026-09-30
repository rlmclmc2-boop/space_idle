# Weapon-motion checkpoint (work in progress)

This is a runnable development-scene milestone, **not visual acceptance or production integration**. The normal `main.tscn` still creates ordinary `BattleGame`; `toon_ship_test.tscn` creates `prototype_battle_game.gd` through a default-preserving factory hook.

## Current mechanics

- Own missile salvo payloads are resolved once through the existing gem/critical attack path, then ejected at 0.10-second intervals. Each release samples its actual carrier muzzle and records a real projectile origin and mount. Existing per-salvo count, damage payload, attack counter and cooldown remain; arrival times change
- Two tube offsets and real initial headings feed bounded steering (4.5 radians/s), with initial speed 180 and cruise speed 620 logical units/s. The old cosmetic fan/offset trajectory is bypassed for these projectiles. Target loss never retargets or damages a dead entity; orphans coast up to 0.55 seconds, and total lifetime is bounded at 3 seconds
- Own rail projectile speed is 12 times the original. The same shared hit/damage functions apply, with earlier arrival. Its white-gold stroke and short electrical residual are one attack identity; onward residual causes no extra hits
- Beam width/brightness/color follow actual ramp power. Near-full violet is distinct from full magenta/white; full entry gets one bounded contact cue per actual beam serial. Invalid beams disappear immediately
- Saved balance tables and the equipment panel's base specifications are not rewritten by these prototype overrides

## Shared seams

`main.gd`: `create_battle_game()` factory, plus prior default-false beam/body rendering hooks.

`game.gd`: `launch_player_attack()`, `prepare_projectile()`, `advance_custom_projectile()`, and optional salvo index/count passed through the existing normal/repeat firing paths. Their production defaults preserve the previous behavior. The prototype does not copy the whole combat loop.

## Verified / pending

Headless import and sparse beam/missile/rail review runs pass. The missile target-death sample launches 12 rounds, hits 10, and preserves the remaining orphan motion without ghost hits; steering-bound error is zero. Pause checks pass. These paired tests compare old/new **renderers using current prototype mechanics**, not equivalence with the previous game behavior.

Single-source and representative mixed captures are generated. The mixed fixture exercises all four weapon families and real beam target resets. An explicit pending-queue interruption fixture ejects all 4 committed rounds after target loss, produces 0 ghost hits, and expires all 4 orphans; pause and viewport-origin invariance pass. Visual acceptance is still subject to user review; production integration/main merge is not implied.

The existing production projectile-iteration test passes 8 checks. The existing projectile-lifecycle test stops at its stale “missile retargets” assertion (line 60); the identical error was reproduced on the unchanged remote base. It is not reported as a pass or repaired in this work.

## Resume commands

Run from `space-battleship` with Python 3 and Godot 4:

- `python dev/toon_ship/run_ordnance_review.py --godot /path/to/godot --kind beam --single-source --durable-target 2000 --check-only`
- `python dev/toon_ship/run_ordnance_review.py --godot /path/to/godot --single-source --durable-target 300 --check-only`
- `python dev/toon_ship/run_ordnance_review.py --godot /path/to/godot --kind mixed --durable-target 4500 --check-only`
- `python dev/toon_ship/run_ordnance_review.py --godot /path/to/godot --single-source --durable-target 300 --check-only --interrupt-target` checks forced target loss while ejections are pending; it is explicitly a lifecycle fixture, not captured ordinary combat
- `python dev/toon_ship/run_rail_review.py --godot /path/to/godot --single --check-only`
- Replace `--check-only` with `--after-only` for continuous captured frames. These are explicitly synthetic fixtures; target HP overrides are test inputs, not balance-file changes
- `python dev/toon_ship/preview.py --godot /path/to/godot --fixture Heavy_Battleship --interactive` opens the mixed fixture without player-save writes

Use the launchers' returned isolated work directory with `--reuse` to avoid repeated asset imports. Rendered clips use explicit 30 Hz simulation steps and are not real-time performance measurements. Windows remains untested.

## Electric / heavy-rocket identity revision

The accepted pulse and cyan→violet continuous beam are unchanged. Rail retains its real 12× speed but now uses cross-rail charge bridges, one irregular blue-white electrical discharge, and broken corona lasting 0.18 s; its straight core exists only for 0.022 s. No additional penetration damage is introduced.

Only the developer BattleGame instance changes missile database rows in memory: 2 rockets per 2.4 s cycle, 0.28 s ejection spacing, doubled per-rocket damage, 120→420 logical px/s acceleration from 0.22–0.65 s, seeking after 0.40 s at at most 4 rad/s. Real tube offsets and ±50° departure create separate curved routes. The near-edge departure bound remains. Body/fins and ignition exhaust accompany actual motion; no fake lateral spread is used. Queued dead-target shots coast without ghost hits and expire after 0.8 s; all missiles have a 4.5 s lifetime ceiling.

Sparse off-center fixture uses one active port missile pod and an inert center module. It passes with 6 launches, 5 impacts and one target-loss shot. Forced queued-target loss passes with 2 launches, 0 impacts, 2 orphan expirations; queue, pause and viewport-origin checks pass. These are synthetic fixtures, not a player save. The 2.5 rad/s initial tuning missed and was rejected; 4 rad/s produces the demonstrated bounded curve and real contact. User visual review is pending.

The 15 s representative mixed fixture (4 missile pods, 2 continuous beams, 1 pulse, 1 rail; synthetic initial enemy HP 4500) passes with 40 missile launches / 32 impacts, 7 orphan expirations, maximum 12 active projectiles, 12 rail fires, 24 pulse fires and 6 actual full-beam cues. Real target sharing still makes rockets converge near enemies. This is intentional targeting, not a rendered merge. Fresh starter guide capture keeps the intro panel above the frigate; the raised Heavy synthetic fixture was the source of overlap. Weapon diagnostics hide the guide only in their test harnesses.
