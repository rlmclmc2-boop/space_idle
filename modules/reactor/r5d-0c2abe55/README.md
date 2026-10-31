# B01 R5d device-effect pixel-bound diagnostic

Production source: `implement/reactor-centered-godot@0c2abe55` (2026-10-31). The four native device work `ColorRect`s now cover conservative bounds around their shader's nonzero output, about 20k screen pixels rather than about 148k at the fixed 808×835 stage size. Fragment positions are mapped from stage `SCREEN_UV` to original full-device UV. There is no change to Owner workload, shader equations, phase, game tick, pipe transport, visibility semantics, or asset quality.

Godot 4.7.2, Linux/Xorg, Mesa llvmpipe, OpenGL Compatibility, 1440×900, normal game speed 1×, all four routes at 25%, no recording. Each 6-second window is in one game instance; the battlefield advances autonomously, so it is not an identical simulation frame sequence. The driver switches only the four work-rect extents between full and cropped, and holds game/visual time to compare the complete left stage at one phase. Absolute pixel error count for the 808×835 left stage is **0**.

| Condition | fps | mean ms | p50 ms | p95 ms | game seconds |
|---|---:|---:|---:|---:|---:|
| Full rectangle A1 | 33.72 | 29.66 | 28.70 | 34.73 | 6.02 |
| Cropped rectangle B1 | 35.06 | 28.52 | 28.16 | 33.69 | 5.42 |
| Full rectangle A2 | 33.68 | 29.69 | 28.63 | 34.69 | 6.03 |
| Cropped rectangle B2 | 34.24 | 29.21 | 28.16 | 34.32 | 6.02 |

The first B window advanced less game time, so its gain is confounded. The second pair advanced comparably and improved by 0.55 fps / 0.48 mean frame ms. This is a modest software-renderer result, not recovery of the user's reported roughly 10-fps loss. Same-version full-stage visible/hidden ABAB is 34.26→44.05 and 33.89→44.74 fps, mean 29.19→22.70 and 29.51→22.35 ms; the remaining active-stage cost is about 6.5–7.2 ms here. Hiding the stage is diagnostic only; the product leaves all effects visible. No target-hardware renderer/resolution profile is available.

Production code review found no steady-state node recreation: static cache copies rebuild only when enabled IDs change; the visible frame reads Owner presentation/quote only when dirty. The four shader work rectangles and the viewport redraw are the identified current render cost. R5b's core-only visible/hidden diagnostic changed roughly 0.4–0.9 ms, so core light alone does not explain the full gap. Repeated gimbal texture assignment may be avoidable but has no isolated cost measurement; it was not changed. The stage viewport redraw is required while real device/pipe/core animation advances. No further local change has a measured benefit under these conditions.
