# Battlefield readability on main 51a7e1b9

Production base: `51a7e1b9bc5784927e7d5b232a112194d990a41c`. The `before` worktree is that commit. This branch is not a merge of the older `d2f5db1a` art branch.

The eight `assets/ships/enemy/opening_v2` silhouettes and their one-to-one mapping in `scripts/enemy_visual_identity.gd` were already present at the production base. No ship asset, mapping, combat rule, spawn, timing, player UI, or right-side layout change is included here.

## Production diff

- `scripts/battlefield.gd`: warmer enemy hull modulation, six-pixel health/shield meters, and a short border on the actual meter struck.
- `scripts/enemy_recognition_visual.gd`: distinct physical bolt and energy streak, plus clearer contact mark in the script rendering path.
- `addons/native_battle/src/combat_presentation.h`: matching bolt/streak geometry in the native rendering path.
- `scripts/resource_art.gd`: thin pickup outline to separate rewards from moving fire.
- `scripts/game.gd` and `addons/native_battle/src/combat_execution_kernel.h`: publish the already calculated enemy shield absorption in hit feedback. No damage calculation changes.
- `scripts/battlefield.gd`: use that hit's absorption to choose the struck meter, including the shield-breaking hit. Keep at most 64 recent UID records with constant-cost replacement, avoiding an enemy scan or per-hit dictionary sweep.

The ship silhouettes still appear small and similar in the reviewed production screenshots. This candidate addresses meters, hit attribution, bullets, and pickups; it does not resolve overall ship identity or whole-ship visual quality. Further art changes need a targeted review decision.

## Original capture

`capture_live.gd` launches the normal scene at speed 1, starts stage 2 point 3, and samples frames 20, 60, and 100. It sets seed 24017 and disables save writing. It changes no health, damage, combat duration, delta, or pause state. The same script was used on both revisions. The PNGs and complete console logs are in `evidence/before` and `evidence/after` (1372 × 883, raw Godot OpenGL output). These screenshots were taken at the first visual candidate `a5f01b7e`, before the hit attribution correction. No further visual inspection or image selection was performed here.

| Frame | Base: enemies / hostile shots / draw calls | Candidate: enemies / hostile shots / draw calls |
| --- | --- | --- |
| 20 | 11 / 0 / 233 | 11 / 0 / 233 |
| 60 | 11 / 17 / 238 | 11 / 15 / 240 |
| 100 | 11 / 21 / 242 | 11 / 21 / 242 |

Both runs loaded `native=true`, `combat_presentation=true`, `speed=1.0` and ended with `BATTLE_DONE`. Frame 60 is not an identical event state (17 versus 15 hostile shots), so its draw calls are observational data rather than a strict same-state performance comparison. The draw-call observations do not establish frame-time performance.

Both DLLs were built from their respective 51-based source trees, using the pinned local godot-cpp release library. SHA-256: base `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`; candidate `A94D0A4D41393076DEE77C610871B47B50A527C0057E42287D28CD2E91A67D27`. DLLs are local build artifacts, not committed. Godot 4.7.2 editor import and four script syntax checks passed. Each run logged a root certificate-store warning, unrelated to rendering; neither logged a script error.

## Hit attribution and current-candidate load

`meter_feedback_test.gd` exercises actual legacy enemy hit events: shield retained, final shield-breaking hit, then direct hull hit. All three reported the expected `absorbed` and selected meter; the raw run is `evidence/meter-feedback.log`. The native kernel now publishes its existing absorbed amount through the already forwarded feedback field. The corrected candidate DLL SHA-256 is `0E2AA29E5180CD82C560B421806E3AD555D9719BF22585C26077F5D83E45170C`.

`run_perf_pair.py` reuses the repository's five-weapon `perf_driver.gd`, fixtures, and probes. It ran each of mixed, laser, cannon, missile, and longLaser once on the 51 base and once on the corrected candidate: 240 warmup plus 480 sampled logical steps, full GUI, native combat, actual speed 1, no VSync or FPS cap. Each pair had exactly matching event and stress counters, and every run passed native admission, focus, and 1× checks. Raw JSON, logs, and full-frame PNGs are in `evidence/performance-main51/`.

| Case | Whole-frame p95 base → candidate (ms) | Busy-frame p95 base → candidate (ms) | Draw-call p95 base → candidate |
| --- | --- | --- | --- |
| mixed | 14.252 → 11.984 | 16.305 → 13.713 | 782 → 782 |
| laser | 9.191 → 9.103 | 11.648 → 12.240 | 700 → 700 |
| cannon | 11.435 → 11.547 | 13.769 → 15.084 | 810 → 810 |
| missile | 10.279 → 10.137 | 11.853 → 11.479 | 769 → 769 |
| longLaser | 13.676 → 13.992 | 14.671 → 14.869 | 713 → 713 |

One run per version and case is a minimal diagnostic, not a stable FPS comparison. The mixed result and the busy-frame differences show run-to-run variation; no improvement claim is made. The corrected hit path has no per-hit enemy traversal and keeps at most 64 UID entries.
