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

## Local GPU frame measurement

Windows display, RTX 2060, Godot 4.7.2 OpenGL Compatibility, 1373×883 window. Existing `test/whole_game_perf.gd` was copied into this isolated project as a temporary probe. It uses a fixed Heavy Battleship with laser, missile, cannon and long laser weapons; three durable enemies; identical seed `1701`; page 0; 15 warmup frames, then 600 complete presented frames. Saves are disabled and user directories isolated. The game logic is advanced with 1/60 second steps to hold the same load. `frames_us` measures real wall time through `await process_frame` on the local GPU, not just logical tick time. Temporary probe and fixture files are not part of the deliverable.

| Final code, 600 frames | Average | P95 | Maximum | Main thread average |
| --- | ---: | ---: | ---: | ---: |
| Motion off | 6.327 ms | 8.589 ms | 30.813 ms | 3.713 ms |
| Motion on | 6.208 ms | 7.747 ms | 29.396 ms | 3.602 ms |
| On minus off | -0.119 ms | -0.842 ms | -1.417 ms | -0.111 ms |

Before the final missile endpoint continuity change, additional 600-frame off/on/off/on and 300-frame off/on pairs had worst paired increases of +0.189 ms average and +0.483 ms P95. The final-code pair is the acceptance measurement; earlier pairs only show measurement variation. Both are within the +0.5 ms average and +1 ms P95 budgets. Peaks are reported independently because they include scheduling noise.

[Motion off screenshot](gpu-final-0.png) · [Motion on screenshot](gpu-final-1.png). The visible long lasers begin at the turret muzzles and end on the enemy hulls in the final on screenshot. The two images are single-frame alignment evidence, not proof of every transition. The workload uses actual GPU rendering but is a synthetic battle fixture; a normal player startup and fresh-machine installation are separate acceptance gates owned by the startup work.

The console logged `Failed to read the root certificate store` and shutdown-only Godot ObjectDB/RID leak notices; neither changed the test exit code, snapshot equality, or captured frames. These warnings should be investigated separately if reproduced in player startup.
