# Existing high-load before/after — local Linux diagnostics

Baseline `c4a5e259`; candidate uses the source/library hashes in `builds/manifest.json`. Both use identical current static assets. Five frozen high-load cases ran serially at the original full window size, 1× game speed, uncapped, VSync disabled, 15 held-health enemies and five drones. The mixed pair was rerun after other checks ended; only the serial rerun is retained here.

**No shipping performance acceptance conclusion:** Godot4.6.3 Linux/Xorg dummy/llvmpipe differs from the supported Windows4.7.2 GPU environment. Most exact warm/sample or actual1x gates failed. The driver advances on rendered boundaries, so step overshoot and warm-up progression differ; event counts and final hashes from these runs must not be used as matched numeric-state evidence. Exact-step numeric invariance is checked separately in `correctness.json`.

| Case | Wall mean ms before → after | p95 ms before → after | Logic Hz before → after | Warm steps before/after | Sample steps before/after | Local gates before/after |
|---|---:|---:|---:|---:|---:|---|
| mixed | 56.16 → 54.06 | 74.44 → 71.15 | 60.02 → 60.65 | 241/240 | 482/482 | False/False |
| laser | 107.21 → 75.73 | 195.97 → 137.79 | 54.71 → 59.30 | 241/243 | 481/485 | False/False |
| cannon | 43.67 → 45.54 | 57.81 → 57.86 | 59.86 → 59.89 | 240/241 | 481/480 | False/False |
| missile | 49.71 → 45.87 | 79.72 → 64.84 | 60.35 → 60.39 | 240/241 | 480/482 | True/False |
| longLaser | 56.87 → 55.58 | 73.91 → 72.21 | 60.29 → 59.98 | 242/242 | 480/480 | False/False |

The locally valid missile baseline alone does not establish a valid paired sample. All ten runs admitted native execution and had zero script errors. Candidate retained metrics show `old_advance=0`; `old_prepare=1` and `old_draw=1` are startup totals, while retained advances/draws range from 158 to 255. GPU batches remain active; no CPU per-projectile fallback was selected. Candidate visual-port feedback counts are mixed1115, laser1503, cannon86, missile345 and longLaser10.

| Case | Before/after main mean ms | Before/after submit mean ms | Before/after render-wait mean ms |
|---|---:|---:|---:|
| mixed | 11.24/11.48 | 3.24/3.35 | 41.39/38.71 |
| laser | 15.99/13.31 | 2.42/2.40 | 88.33/59.47 |
| cannon | 6.77/7.27 | 3.59/3.60 | 33.04/34.36 |
| missile | 8.15/7.86 | 3.14/3.01 | 38.17/34.68 |
| longLaser | 10.73/10.47 | 4.56/4.52 | 40.99/39.96 |

All four disjoint wall spans, raw phases, validity flags, event counts, active projectile counts, rendering primitives/draw calls and cold state exports are preserved in `linux/*.json.gz`. Windows process CPU/GetProcessTimes and physical GPU timing/utilization are unavailable; no replacement low-load numbers are presented. The existing Windows build and frozen suite remain pending for formal validation.

Additional check not completed: `test_native_geometry_scale.gd` was stopped in headless mode. Its existing fire observer unconditionally reads `info.shot` and rejects compact native-laser feedback, and its frame-post-draw wait requires a graphical run. It is not counted as passed. The unchanged native kernel (485 checks), weapon numeric boundary (54 checks) and static seat checks (90 samples) passed; the new dedicated interface check covers the changed display-port contract.
