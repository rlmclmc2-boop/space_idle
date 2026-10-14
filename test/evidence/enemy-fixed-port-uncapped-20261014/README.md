# Uncapped QA full-wall-frame acceptance (new timing scope)

One ordered A/B only: A=e7cc31e026fd390b24daa188256ee7f5f33a67e9; B=4b79775a7402c9ef19ab9fc29071a190f8645f4e. Exact Git project archives and the same accepted DLL (45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e). QA only sets cap=0 and VSync off; production project files/settings unchanged. Full rich15 layer2 graphics, actual speed/time_scale 1, fixed logic 60 Hz. Both import and measured exits 0. No second group, retries or omitted samples.

Timing: previous post-draw resume P0 -> current main begin M0 -> main end M1 -> pre-draw D -> post-draw resume P1. Four disjoint spans are M1-M0, D-M1, P1-D, M0-P0. Their sum is P1-P0. The first P0 is sample_start after warmup. Post-sample screenshot readback is excluded. Every sampled frame is ordered and closure residual is exactly 0 us on both sides. These are wall intervals including synchronous driver/GPU and scheduling waits, not CPU-exclusive measurements; they must not be compared directly with earlier capped absolute values.

| Full wall frame, ms | A | B |
|---|---:|---:|
| count | 518.000000 | 520.000000 |
| mean_ms | 15.398940 | 15.374944 |
| median_ms | 14.711500 | 14.648000 |
| p95_ms | 20.748000 | 20.413000 |
| p99_ms | 43.327000 | 43.258000 |
| max_ms | 48.951000 | 50.307000 |
| total_ms | 7976.651000 | 7994.971000 |

| Disjoint wall span | A mean ms | B mean ms | A cumulative ms | B cumulative ms |
|---|---:|---:|---:|---:|
| main_callback | 7.371292 | 7.386956 | 3818.329 | 3841.217 |
| main_end_to_pre_draw | 4.308820 | 4.301794 | 2231.969 | 2236.933 |
| pre_to_post_draw | 3.664915 | 3.632858 | 1898.426 | 1889.086 |
| post_to_next_main | 0.053913 | 0.053337 | 27.927 | 27.735 |

Each side: 240 warmup steps and 480 measured steps / 8 game seconds. Measured fires=3458, hits=13053, purchased levels=96, handoffs=0. Warmup counts, entire fixture, RNG state and cumulative event totals match. Actual game/wall ratios A=1.002926, B=1.000627; both actual-1x checks pass. Both retained records cover all 15 enemies and all effects remain enabled. Sampled unfocused flags are always false.

Steps per rendered frame: A {0:61, 1:437, 2:18, 3:1, 4:1}; B {0:56, 1:450, 2:12, 3:2}. Both sums are 480 logical steps. Thus mean-per-frame is not a fixed per-step workload comparison. Cumulative phase walls, per-logic-step costs and all per-frame observations remain in summary.json/A.json/B.json. Draw-call and active-projectile sums are per-render-frame observation totals, not unique-object work counts.

Kernel metrics differ in physics_visits (264196 -> 264426) and since_hit (0.0333333 -> 0.0166667); all other exported kernel metrics match. The fixed birthplace is an authorized trajectory change, so no full-trajectory/state equivalence claim is made. No workload was reduced to achieve a threshold.

Result: full-wall mean B-A=-0.023996 ms; median -0.0635, p95 -0.335, p99 -0.069, max +1.356 ms. Main-callback mean is slightly higher (+0.015664 ms). B total sampled wall is 7994.971 ms versus 7976.651 ms with two more rendered frames. This single pair does not establish material net savings or the >=0.5 ms threshold. Complete measured wall-frame mean remains about 15.375 ms, above 10 ms; synchronous waits are still unsplit, so this is not an exclusive CPU-busy-time verdict. No new bottleneck/root cause is inferred from these coarse spans.

Files: driver.gd and combat_stress_fixture.gd are the shared measurement inputs; run.py records refs, DLL/engine/script hashes, commands and exits in receipt.json; analyze.py computes all-sample means/median/nearest-rank p95/p99/max, phase totals, closure, step groups and workload checks. Import logs remain local. A.png/B.png are complete post-sample screenshots; B was inspected.
