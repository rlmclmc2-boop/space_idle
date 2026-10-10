# Battle publication boundary

`battle_read_model.gd` separates event-owned fleet shape (components, width coefficients, frontline) from exact-clock moving positions. It does not copy GameState, roll RNG, defer hit events, change combat order, alter fixed substeps, or change rendering quality.

The scene activates the publication during logical advancement and native drawing. Exact clock/XY and entity identity remain part of the moving contract. Configuration and hull changes invalidate shape; encounter, state, equipment, and membership events invalidate shape and layout. Counter-only equipment-stat events preserve the publication; their original combat counters and UI callbacks still run. Death membership is checked separately even without a clock change. Outside the active boundary canonical geometry remains available.

`retained_enemy_contacts.gd` consumes complete display packets containing positions, width, angle, native appearance, protection state, layout and mount poses. Packet generation uses canonical recognition and aim rules; native painters retain the existing commands, order, shading and viewport.

## Validation

Run `whole_game_perf.py --battle-only --boundary-check` on the candidate only. It compares canonical and published positions, frontline, widths, recognition contours, mount poses and damage layouts, plus same-clock death membership, paused configuration changes and same-UID replacement. This instrumentation is not a throughput result. It runs only in a copied project with isolated userdata. The direct canonical methods provide a reference and fallback, not a second simulation.

Run clean comparisons without `--boundary-check`, `--phase-account`, `--instrument` or `--dynamic-replay`. Use identical workload options and alternating pinned Git refs. `--capture` reads back only after the measured interval. Fixed 1/60 workload throughput does not establish natural 1x FPS. Frame mean/P95/P99 and combat/RNG equality must be checked; a reduction in query counts alone is not acceptance.

All measurements and screenshots remain private under ignored `test/work`. This is an experimental independent branch; it must not be merged without parent acceptance.
