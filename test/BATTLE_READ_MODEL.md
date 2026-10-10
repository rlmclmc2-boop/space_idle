# Battle publication boundary

`battle_read_model.gd` separates event-owned fleet shape (components, width coefficients, frontline) from exact-clock moving positions. It does not copy GameState, roll RNG, defer hit events, change combat order, alter fixed substeps, or change rendering quality.

The scene activates the publication during logical advancement and native drawing. Exact clock/XY and entity identity remain part of the moving contract. Configuration and hull changes invalidate shape; encounter, state, equipment, and membership events invalidate shape and layout. Counter-only equipment-stat events preserve the publication; their original combat counters and UI callbacks still run. Death membership is checked separately even without a clock change. Outside the active boundary canonical geometry remains available.

`retained_enemy_contacts.gd` consumes complete display packets containing positions, width, angle, native appearance, protection state, layout and mount poses. Packet generation uses canonical recognition and aim rules; native painters retain the existing commands, order, shading and viewport.

## Validation

Run `whole_game_perf.py --battle-only --boundary-check` on the candidate only. It compares canonical and published positions, frontline, widths, recognition contours, mount poses and damage layouts, plus same-clock death membership, paused configuration changes and same-UID replacement. This instrumentation is not a throughput result. It runs only in a copied project with isolated userdata. The direct canonical methods provide a reference and fallback, not a second simulation.

Run clean comparisons without `--boundary-check`, `--phase-account`, `--instrument` or `--dynamic-replay`. Use identical workload options and alternating pinned Git refs. `--capture` reads back only after the measured interval. Fixed 1/60 workload throughput does not establish natural 1x FPS. Frame mean/P95/P99 and combat/RNG equality must be checked; a reduction in query counts alone is not acceptance.

All measurements and screenshots remain private under ignored `test/work`. This is an experimental independent branch; it must not be merged without parent acceptance.

## Appearance and pose ownership

The immutable appearance packet owns weapon components, recognition mount descriptors, attack types and their signature together. The active spatial row holds this packet by exact uid/entity identity. Recognition and type queries read the packet directly; they do not rely on component lookup initializing another mutable pose. Canonical queries outside the boundary build the same packet with the original composition and descriptor rules.

The legacy slot pose remains independently mutable and is pruned for dead/departed entities. Residual turret/fleet-clearance/projectile queries may still ask for those entities and recreate a deterministic slot pose; this preserves the original position/entry solver and never consumes combat RNG. A same-clock pose replacement invalidates only that row's moving solve/bounds, while its immutable appearance remains usable. A persistent contact binds the current pose and refreshes pose-dependent protection/status packets without rebuilding native mounts. New uid membership retires the prior row/contact; the same uid with a different Dictionary creates a new owner. An old residual entity cannot take the new entity's spatial row.

`test_enemy_appearance_ownership.gd` covers same-entity pose recreation, current display binding and retained mount nodes, exact canonical position and combat/RNG preservation, a dead first fleet member still referenced by a turret, and same/new uid entity replacement. The old candidate raises the QA `recognition_mounts` error in this regression. Detailed natural QA transition and timing evidence stays local.
