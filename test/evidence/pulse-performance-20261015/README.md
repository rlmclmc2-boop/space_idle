# Native pulse feedback full-frame gate (2026-10-15)

**Fixture correction:** These laser and mixed labels do not denote the frozen five-environment workloads. This runner copied `test/combat_stress_fixture.gd`; its laser used layer 1, with no five-drone legendary load. Its mixed used the generic fixture, not `five-environment-20261015/baseline/mixed_fixture.gd`. Keep the raw results as measurements of those specific configurations only. Do not compare their timings or feedback volumes with the accepted five-environment baseline. The [corrected frozen-laser uptake probe](../pulse-fixture-correction-20261015/README.md) governs candidate coverage.

Candidate source `d46e93b8ec56490df2d574c748e2a2afcad3f2a7`, production gate **off**. Same DLL SHA-256 `483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f` in both isolated D: projects. `run_perf.py` creates those projects, checks source/DLL bytes before the series, and adds only four integer QA counters to the session in **both** copies. The `on` copy additionally toggles the pulse gate. The QA counter source hashes are in `source-manifest.json`; `source-after.json` confirms those hashes remained identical after sampling and checks 155 other GDScript files per copy against the branch. No QA event listener remains connected during timing. Preflight confirms the production listener guard passes. All timing includes gate scans, prospective map copies, label synchronization, fallback, and the QA counters.

The first laser/off pilot had `root.has_focus=false` on every frame and is retained as `focus-invalid-laser-off-a.*`, **excluded** from results. A 30-frame GL focus preflight then saw focus on 29 frames. The accepted runs use `DisplayServer.window_move_to_foreground()` before warmup; every sampled frame passed focus, no unfocused limiter, uncapped FPS, VSync off, actual speed 1, Engine scale 1, GL Compatibility on NVIDIA RTX 2060. Each arm warmed 240 logical steps and sampled 480 steps at fixed 60 Hz. `frames_us` measures complete postdraw wall frames; `frame_steps` records 0, 1 or multiple logical steps. `full-frame.png` is one uncropped mixed/on GL frame.

| Run (ABBA order) | Full mean / P95 ms | 0 / 1 / multi-step frames | One-step mean / P95 ms | Fast / cold batches |
|---|---:|---:|---:|---:|
| laser off A | 4.370 / 6.419 | 1354 / 476 / 2 | 5.982 / 7.822 | 0 / 380 |
| laser on A | 4.969 / 8.327 | 1133 / 474 / 3 | 6.901 / 10.777 | 12 / 368 |
| laser on B | 4.547 / 6.860 | 1279 / 478 / 1 | 6.243 / 8.201 | 12 / 368 |
| laser off B | 4.827 / 7.239 | 1175 / 477 / 1 | 6.523 / 9.281 | 0 / 380 |
| mixed off A | 8.672 / 13.144 | 450 / 466 / 7 | 10.892 / 14.062 | 0 / 480 |
| mixed on A | 8.592 / 12.958 | 458 / 468 / 6 | 10.885 / 13.524 | 0 / 480 |
| mixed on B | 8.908 / 13.404 | 421 / 476 / 2 | 11.127 / 13.902 | 0 / 480 |
| mixed off B | 8.734 / 12.811 | 441 / 468 / 6 | 10.895 / 13.456 | 0 / 480 |

ABBA arm means: laser off 4.599 ms, on 4.758 ms (**0.159 ms slower**); mixed off 8.703 ms, on 8.750 ms (**0.047 ms slower**). Laser off/off drift is 0.457 ms and on/on drift 0.421 ms. Mixed off/off drift is 0.062 ms and on/on drift 0.315 ms. Neither reaches the required ≥0.5 ms net gain above drift. The mixed one-step mean and P95 remain above the <10 ms full busy-frame target. This candidate direction is stopped; do not enable the production gate or use these results to claim all environments pass.

Uptake explains the limit: laser on used 12/380 feedback batches and 41/2099 rows (3.2% / 2.0%); mixed on used **0/480 batches**, while the listener guard remained clear. This strict whole-batch route spends its eligibility cost and falls back whenever mixed ordered feedback is present. In every arm, hot rows + cold rows equal the total feedback count.

The 480-step work is identical across ABBA arms within each fixture: complete kernel metrics, player/resources/loadout, game and kernel RNG state, 40-row history count, enemy count, flight count, 96 auto-upgrade levels, and zero drops. The held-health fixture deliberately prevents natural deaths and drops. Quote display is visible in the screenshot; a purchase quote transition is **not** separately proven by this performance run. The earlier targeted correctness tests and the parent's separate play test remain distinct evidence.

Next evidence-backed investigation, if requested: further split the *remaining cold feedback handling* while preserving full event order and single kernel authority. The earlier [cost localization](../compact-laser-cost-20261015/README.md) measured 1.566 ms/step mixed and 2.720 ms/step pulse after `take_feedback`, a gross inclusive ceiling. That study did not isolate which handler now consumes the budget. Measure before designing another route; do not retry the rejected final-payload or upgrade-local schemes under a new name. No new implementation is proposed from this failed gate alone.

`analyze_perf.py` recomputes all stats and compares raw workload fields; `analysis.json` lists every raw SHA-256. All added logs use LF so their repository blob hashes match the receipt. No game cache, player save, credentials or generated build files are included.
