# 第6阶段历史：旧构建性能测量

[唯一入口](../README.md) → [当前验收边界](../11-stage6-contract.md)。以下按原记录保留提交/平台/版本；其中“当前/待复审/已通过”只属于当时构建，不能覆盖新的模块验收。旧探针名是证据标识，不是当前运行命令。

## 历史测量（977e602之前的本机构建）

**Current performance acceptance policy:** per user instruction, only uncapped (`Engine.max_fps=0`) and VSync-disabled results are used for performance acceptance. Capped/VSync-enabled records below are diagnostic comparisons only and must not be used to fail performance. These are historical measurements; current cloud input coverage and latest-build measurement limits are recorded above.

### Final maximum OpenGL and full warehouse run

`_stage6_max_gpu_window_probe.gd` reuses the real-window probe and the maximum native fixture. NVIDIA GeForce RTX2060, driver610.88, OpenGL3.3 Compatibility; 5 weapons,3 defence modules,4 drones,15 enemies, missiles/cannon/beams with chain/secondary, ten1/60 business steps per display frame. This is ten steps/frame, not proof of real10x:600 game seconds over74.548 wall seconds is actual8.048x. Main's automatic Session stepping is disabled in this controlled native run, so it does not measure Session time acceptance or backlog. The real BattleView/shaders run, with no second combat implementation. Player defence retains Amount1e1000; enemy health1e12 keeps the wave alive while allowing nonzero losses/labels. The initial1e1000 enemy-health fixture failed its label assertion because ordinary damage fell below Amount precision; it is not counted as successful.

| Measurement | Battle visible | Full warehouse visible over battle |
|---|---:|---:|
| Display frames / wall seconds | 1800 /37.012 | 1800 /37.537 |
| Wall p95 /p99 /max ms | 21.917 /22.011 /247.537 | 21.952 /26.019 /40.825 |
| Wall frames >17 />33.3 />100 ms | 1799 /2 /2 | 1800 /1 /0 |
| Measured viewport GPU samples | 1794 | 1800 |
| GPU p95 /peak ms | 0.548 /162.385 | 0.741 /20.959 |
| Process monitor peak ms | 230.788 | 56.746 |
| Static /video memory peak MiB | 113.514 /14.199 | 115.855 /14.668 |
| Draw calls /flights /damage labels peak | 77 /57 /48 | 173 /55 /48 |

Total measured phases:3600 frames,74.548 seconds,600 controlled game seconds. Full warehouse assertion checks200 visible-list rows plus10 overflow entries. Its normal production panel refresh remains enabled. Both bounded screenshots were exported and inspected (Temp `space-idle-max-gpu-0.png` and `-1.png`). Wall times include the60fps cap, presentation scheduling and driver waits; they are not GPU-only work. Cold spikes are retained in the table rather than discarded. The log reports shader cache writes unavailable in user://, so no persistent shader-cache benefit is assumed. Additional25 one-second NVIDIA device samples measured3% average/peak utilization,946/6144MiB device memory and35.24W peak; these are whole-device values including other desktop clients, not process-exclusive attribution.

### Targeted real-time budget clarification

One targeted `_stage6_realtime_gpu_budget_probe.gd` run resolves the earlier fixed-steps/frame limitation. It uses the same renderer, maximum ship/15-enemy sustained wave and visible200+10 warehouse, but mounts four drones through the real Hyperspace loadout and uses owner armour level1000 for survivability. It feeds measured wall dt into actual `Session.frame(dt,true)` at requested chrono speed10 with a funded chrono wallet. Main's duplicate auto-step is disabled; normal production UI/render children remain active. After150 warmup frames, it compares two10-second phases. No production timing policy was changed.

| Steady measurement | Comparison only: cap60 /VSync enabled | Acceptance: uncapped /VSync disabled |
|---|---:|---:|
| Display frames /wall seconds | 435 /10.010468 | 3923 /9.999934 |
| Requested /processed game seconds | 100.104680 /100.116667 | 99.999340 /99.983333 |
| Actual game-time multiplier | 10.001197x | 9.998399x |
| Fixed1/60 steps /maximum per display frame | 6007 /19 | 5999 /6 |
| Pending game seconds peak /end | 0.016590 /0.000310 | 0.016663 /0.016317 |
| Time-bank error (game+pending delta-request) | 5.12e-11 sec | 1.34e-11 sec |
| Wall p95 /p99 /max ms | 24.097 /29.571 /30.976 | 3.795 /4.543 /9.751 |
| Wall busy >17 />33.3 />100 ms | 435 /0 /0 | 0 /0 /0 |
| Session work p95 /p99 /max ms | 4.107 /4.391 /5.500 | 0.988 /1.273 /2.111 |
| Session busy >17 />33.3 />100 ms | 0 /0 /0 | 0 /0 /0 |
| Non-Session tail p95 ms | 20.861 | 2.875 |
| Measured viewport CPU p95 ms | 0.896 | 0.822 |
| GPU p95 /max ms | 0.935 /2.043 | 0.886 /2.156 |

The non-Session tail is the interval from the previous Session call's end to the next process-frame signal; it includes child UI/render processing, waits, frame limiting, VSync and scheduling. It is not a pure sleep measurement, and separate percentiles must not be added. The controlled comparison shows that disabling the cap/VSync removes most of the22-24ms wall interval while both phases keep real10x with no growing bank; all residual pending stays below one1/60 step. The slight multiplier difference is retained fractional-step time, not dropped work. Per-frame logic never reaches Session's64-step budget.

Cold/startup spikes remain separate: the previous cold-inclusive run observed wall247.537ms/GPU162.385ms peaks and two frames over100ms. They are not relabeled as steady logic stalls. The150-frame warmup of this targeted run is explicitly excluded from the steady table; shader-cache write failure remains an environment diagnostic. No additional long test was run to hide these spikes.

Acceptance result uses only the uncapped/VSync-disabled phase:3923 frames in9.999934 seconds, wall p95/p99/max3.795/4.543/9.751ms, zero wall or Session-work frames above17/33.3/100ms, Session work p95/p99/max0.988/1.273/2.111ms, GPU p95/max0.886/2.156ms. Actual speed is9.998399x;5999 fixed steps advance99.983333 game seconds, with pending peak0.016663 and end0.016317 game seconds. The time bank retains the fractional step and differs from accepted time by only1.34e-11 seconds. This satisfies the recorded steady maximum-load/real10x/time-preservation performance requirements. The capped phase's43.45fps and longer wall interval are comparison data only, not a performance failure or an extra acceptance gate. Historical capped cold-start spikes likewise remain diagnostics, not uncapped pass/fail measurements. This historical run did not supply operator acceptance; the later cloud keyboard/mouse coverage is recorded in the current ledger.

`STAGE6_MAX_GPU_WINDOW_OK` and the final `STAGE6_WINDOW_OPS_OK` both exited0. The latter emitted an embedded-file-dialog focus warning in this non-enumerable window environment, yet its visible-state assertions and exported picker frame passed. Certificate/log/cache and shutdown ObjectDB warnings remain captured as environment diagnostics. Eight final PNG exports plus one151-byte settings file occupy well below1MiB; `.godot` remains186.7MiB and the reused Temp native build159.6MiB. No new repository/build clone or unbounded capture was created; these files remain local outputs.

- C01: zero damage before contact; shield loses 30 and armour loses 40 at contact. The native oracle also checks shield-only sortie/depletion and first defence slot empty/refit behavior as partial C13/C15 evidence.
- Real OpenGL on NVIDIA RTX 2060: 3,600 frames / 64.84 s; p95 wall 18.946 ms, p99 18.978 ms, two frames over 33 ms, one over 100 ms, peak 50 draw calls, 19 damage labels, 18 flights, 0.016661 s pending game time, 112.46 MiB static and 13.85 MiB video memory. The 60 fps cap explains most frames over 17 ms.
- Production 15-slot group at 10x: 4,800 headless frames / 784 game seconds; average work 1.20 ms, peak 11.55 ms, zero frames over 17 ms, 22 peak flights, 0.0167 s peak pending time. Combat occupied 1,207 frames.
- Sustained native 15-slot wave at 10x: 3,600 frames / 600 game seconds; average work 0.462 ms, peak 1.235 ms, zero frames over 17 ms, average 18.88 and peak 23 flights, peak 16 queued effects, 25 flight slots, 32 active and feedback capacities, 73.15 MiB static memory. This holds one wave alive; it does not measure full campaign progress.
- After the deferred-tick correction, a 600-frame native 15-slot wave at 10x measured 0.408 ms average, 0.811 ms peak, zero frames over 17 ms, peak 23 flights and 73.16 MiB static. The 600-frame production group measured 1.139 ms average, 7.641 ms peak, zero frames over 17 ms, peak 22 flights and 0.0167 s pending game time. These are headless CPU measurements on the local machine, not the remaining maximum-load GPU matrix.
