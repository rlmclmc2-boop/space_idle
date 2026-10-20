# Battlefield motion acceptance evidence

## Fixed-seed native headless comparison

Local Windows 11, Godot 4.7.2, accepted `tools/player_runtime/space_native.dll` SHA-256 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`; copied only into this isolated checkout by the repository's documented installation procedure. Both runs disable saves and use seed `740221`. Run from `space-battleship` with isolated `APPDATA` and `LOCALAPPDATA`:

```powershell
& $Godot --headless --path . --script res://test/test_battlefield_motion_consistency.gd
$env:BATTLEFIELD_MOTION_MIXED='1'
& $Godot --headless --path . --script res://test/test_battlefield_motion_consistency.gd
$env:BATTLEFIELD_MOTION_FAST_PAUSE='1'
& $Godot --headless --path . --script res://test/test_battlefield_motion_consistency.gd
```

All three compared full snapshots: state, stage, wave, unit IDs and HP, shields, projectile positions and targets, drops, event counts, and combat RNG state. Off and on were exactly equal. [The base 180 frame result](headless-consistency.json) includes both complete snapshots. The 600 frame mixed weapon run had 63 fires, 55 hits, seven explosions and a wave clear, all equal. The mixed pause/10× run had 50 fires, 44 hits, five explosions and a wave clear, all equal; the display clock and pose stayed fixed during the pause. Godot exited these native test runs with code 0.

For the final 600 frame mixed run, the existing visual launch diagnostics reported `pulse_origin_max_error = 0`, `rail_origin_max_error = 0`, and `missile_origin_max_error = 0` pixels both off and on. These check the visual launch origin against the sampled visible muzzle; the screenshots below inspect long beam endpoints.

Counter deltas in the final 600 frame run, identical off and on:

| Counter | Off | On |
| --- | ---: | ---: |
| Hull builds | 0 | 0 |
| Loadout builds | 0 | 0 |
| Body attachment builds | 0 | 0 |
| Body texture bakes | 0 | 0 |
| Body material invalidations | 0 | 0 |
| Enemy hull scans | 13 | 13 |
| Enemy envelope builds | 4 | 4 |

The 13 scans and four envelope builds are initial work for newly spawned enemies, so the dynamic increment is zero. This is a native, headless logic and geometry comparison; it does not establish visible frame time.

## Historical local GPU frame measurement — not current high-load acceptance

Windows display, RTX 2060, Godot 4.7.2 OpenGL Compatibility, 1373×883 window. Existing `test/whole_game_perf.gd` was copied into this isolated project as a temporary probe. It uses a fixed Heavy Battleship with laser, missile, cannon and long laser weapons; three durable enemies; identical seed `1701`; page 0; 15 warmup frames, then 600 complete presented frames. Saves are disabled and user directories isolated. The game logic is advanced with 1/60 second steps to hold the same load. `frames_us` measures real wall time through `await process_frame` on the local GPU, not just logical tick time. Temporary probe and fixture files are not part of the deliverable.

| Final code, 600 frames | Average | P95 | Maximum | Main thread average |
| --- | ---: | ---: | ---: | ---: |
| Motion off | 6.327 ms | 8.589 ms | 30.813 ms | 3.713 ms |
| Motion on | 6.208 ms | 7.747 ms | 29.396 ms | 3.602 ms |
| On minus off | -0.119 ms | -0.842 ms | -1.417 ms | -0.111 ms |

Before the final missile endpoint continuity change, additional 600-frame off/on/off/on and 300-frame off/on pairs had worst paired increases of +0.189 ms average and +0.483 ms P95. These are valid observations for this fixture only. The user reported that model updates made the old three-enemy fixture insufficient as a high-load case. Consequently none of these numbers establish the +0.5 ms average or +1 ms P95 acceptance budget under current high load. A representative busy battle must be defined and measured again. Peaks are reported independently because they include scheduling noise.

[Motion off screenshot](gpu-final-0.png) · [Motion on screenshot](gpu-final-1.png). The visible long lasers begin at the turret muzzles and end on the enemy hulls in the original screenshot. These images are single-frame alignment evidence, not proof of visible enemy hull motion. The user observed stationary enemies in that candidate; the cached renderer cause and repair are recorded below. The workload uses actual GPU rendering but is a synthetic battle fixture; a normal player startup and fresh-machine installation are separate acceptance gates owned by the startup work.

## Retained enemy renderer repair

The main battle painter calls `draw_retained_enemy_contacts` first. In the previous candidate it was enabled, but `update_record` used the canonical `spatial.position` and `enemy_render_angle` for its visible Canvas nodes. The fallback painter had the motion code and was bypassed. The repair applies the already cached per-enemy offset and yaw to the actual retained root, hull, deck, protection and weapon mounts. Health and shield meters follow the translated root without rotating. Generic weapon muzzle sampling now uses the same transformed component anchor; the authored art path uses the same helper as the fallback painter.

The [300-frame native Canvas owner test](retained-visible.json) samples `record.root`, hull, protection and mount nodes with the retained path **enabled** while enemy logical coordinates remain fixed. The visible root moved 8.00 px horizontally and 12.99 px vertically including entry, hull angle spanned 1.04°, and the mount moved 7.74 px horizontally. Maximum root-to-pose, shield-angle and hit-anchor errors were zero; maximum visible muzzle-to-painted-tip error was 0.63 px. After settling, hull and protection Canvas rebuild counts stayed at zero. Fixed-seed mixed weapon, cross-wave, pause and 10× off/on comparisons still matched in full battle snapshots and rebuild counters.

[Before: stationary cached enemies](retained-before-300.png) · [After: pose applied to cached enemies](retained-after-300.png) are local-GPU frames from the same old synthetic fixture at the 300-frame capture point. They document the visible node wiring; the numeric node span across time is the motion evidence. This old fixture remains insufficient for high-load performance acceptance, and direct user observation of the repaired motion is pending.

The console logged `Failed to read the root certificate store` and shutdown-only Godot ObjectDB/RID leak notices; neither changed the test exit code, snapshot equality, or captured frames. These warnings should be investigated separately if reproduced in player startup.
## Current maximum-slot native GPU run

The older three-enemy data above is historical. The current 15-enemy, five-drone, real-1x full-frame GPU run and its acceptance status are recorded in [ENTRY.md](../ENTRY.md). Raw unoptimized off/on ABBA samples are `real1x-max15-{off,on}-{1,2}.json`. The retained-anchor candidate has five paired off/on samples in `real1x-max15-cached-{off,on}-{1..5}.json`, two complete-frame screenshots, and [fixed-seed](cached-consistency.json) and [visible-node](cached-retained-visible.json) checks. The pooled candidate samples satisfy the numeric thresholds, but one pair exceeds both; the performance gate remains open.

The predeclared follow-up used eight longer 1200-step samples in four pairs, retained in `real1x-max15-long-{off,on}-{1..4}.json`, with [off](real1x-max15-long-off.png) and [on](real1x-max15-long-on.png) screenshots. All four pairs meet both budgets; pooled mean/P95 increments are +0.272/+0.357 ms. The full protocol, peak values, uncertainty and post-sample diagnostic difference are in [ENTRY.md](../ENTRY.md). This longer run supersedes the shorter-run performance status above.

After merge of approved current `main` `90878d87`, [postmerge off](real1x-max15-postmerge-off.json) and [postmerge on](real1x-max15-postmerge-on.json) retain the additional predeclared 1200-step integration pair. Mean/P95 increments are +0.283/+0.497 ms; full-frame [off](real1x-max15-postmerge-off.png) and [on](real1x-max15-postmerge-on.png) captures and [fixed-seed](postmerge-consistency.json) and [visible-node](postmerge-retained-visible.json) checks accompany it.
