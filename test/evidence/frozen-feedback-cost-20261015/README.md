# Frozen laser and mixed feedback cost attribution (2026-10-15)

Production pulse-feedback changes from `75a662d2`, `392c5683`, and `d65051d3` were rejected and removed in `c1413b93`. The eight affected production files now have the exact Git blobs from verified `b6ab391e`. This study used the previously verified compact-laser DLL SHA-256 `1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5`, not the rejected pulse-feedback DLL. No production code, cadence, damage, or display policy changed.

The isolated laser and mixed projects copied the exact frozen `five-environment-20261015/baseline` fixtures. Laser uses `WEAPON_CASE=laser`, layer 2, eight ordinary lasers, five valid drones with `scatter_pulse` and `laser_charge`. Mixed uses the frozen `mixed_fixture.gd`, also layer 2 with five drones. Each run's complete manifest equals the matching frozen `stress.config`. `receipt.json` lists the fixture, manifest, script, engine, and DLL hashes; `source-after.json` confirms the two QA patches stayed fixed and 154 other GDScript files per project match the branch. The fixture's QA event observer was disconnected before stepping; the battle load stayed intact.

Each case ran timer off / on / off with identical QA wrappers and counters, 120 warm logical steps, then 240 sampled steps at actual speed 1, GL Compatibility, uncapped FPS, VSync off. Every sampled frame was focused. Within each case, all three arms had identical initial, before, after, and complete manifest values, including kernel metrics, game and kernel RNG states, loadout, resources, player, enemy count, and feedback rows. Laser produced 27,632 rows in each arm; mixed produced 15,089. These are synthetic held-health workloads, not natural play.

## Inclusive timer-on costs

All values are milliseconds per **logical step**. `consume_feedback` encloses `take_feedback` and every row category. `hit_label` is inside `hit`; do not add it again. The row scopes include payload creation, signal delivery, and listeners. Their measured values include QA clock overhead and are gross ceilings, not removable cost.

| Scope | Laser calls / ms | Mixed calls / ms | Boundary |
|---|---:|---:|---|
| `consume_feedback` | 240 / 2.987 | 240 / 1.698 | Whole feedback path, including probe work. |
| `take_feedback` | 240 / 0.417 | 240 / 0.230 | Native ordered feedback to GDScript rows and dictionaries. |
| `fire_impact` | 13,092 / 1.018 | 5,953 / 0.515 | Kind 0/1 dispatch, payload, event listeners. |
| `hit` | 9,217 / 0.902 | 6,406 / 0.612 | Kind 2 dispatch and listeners, including `hit_label`. |
| `hit_label` | 9,217 / 0.418 | 6,406 / 0.283 | `queue_damage_number` inclusive, nested in `hit`. |
| `chain_secondary` | 5,323 / 0.330 | 2,532 / 0.156 | Kind 4/8 dispatch and listeners. |
| `other` | 0 / 0 | 198 / 0.021 | Other feedback kinds. |

Unassigned `consume_feedback` time after `take_feedback` and the four disjoint row groups is 0.320 ms/step laser and 0.164 ms/step mixed. It includes loop work, wrapper dispatch, timer/counter overhead, and gaps between measured scopes. It is not a separate handler estimate.

## Probe effect and budget

| Case | Off A / timer on / off B full-frame mean ms | Timer on above off midpoint | Off/off drift | Off A / on / off B one-step busy-frame mean ms |
|---|---:|---:|---:|---:|
| Laser | 7.350 / 7.631 / 7.285 | +0.314 ms | 0.065 ms | 10.833 / 11.145 / 10.803 |
| Mixed | 8.490 / 8.629 / 8.707 | +0.030 ms | 0.217 ms | 10.793 / 10.949 / 10.992 |

These controls estimate incremental enabled-timer effect plus scheduling drift; timer-off still executes QA wrappers and counters. The laser timer adds an observable 0.314 ms/full frame relative to the off midpoint, larger than control drift. Mixed's +0.030 ms is below its 0.217 ms drift. Do not subtract either figure mechanically from individual scopes.

Across all displayed frames in the timer-on arms, `fire_impact` costs 0.465 ms/frame laser and 0.266 ms/frame mixed. On a one-logical-step busy frame, its gross scope is 1.018 / 0.515 ms respectively. The mixed margin above 0.5 ms is only 0.015 ms, smaller than observed timer effect and drift. `hit_label`, `take_feedback`, and `chain_secondary` are each below 0.5 ms/busy step in both cases. No isolated category currently proves a **recoverable** 0.5 ms whole-frame improvement. The full path has a larger gross cost but cannot be removed without preserving all ordered gameplay and display effects. Both busy-frame means remain above 10 ms.

Next decision for parent: if investigation continues, examine the fire/impact listener work with a narrower semantics-preserving cost boundary. Do not implement a new production route from these gross timings alone. The rejected pure-pulse whole-batch gate, final-payload, and upgrade-local routes remain rejected.

`analyze.py` recomputes scope means, frame means/P95, controls, and raw hashes. Raw `laser-*.json`, `mixed-*.json`, their logs, import logs, `receipt.json`, and `source-after.json` are retained. The timing study does not cover natural deaths, wave progression, drops, or purchase quote transitions.
