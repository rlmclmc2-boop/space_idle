# Ordinary enemy port acceptance: one short A/B

A: `e7cc31e026fd390b24daa188256ee7f5f33a67e9`; B: `85c76e794838be595be1722ccbb08b9a24bca852`. Exact Git project snapshots; production difference is only the retained ordinary-enemy port renderer and its SVGs. Same accepted DLL SHA256 `45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e`. No procurement/GPU/float candidates, native rebuild, or production instrumentation.

One A then B, each 240 warmup logic steps + 240 measured steps. Existing rich15 layer2 fixed fixture, 15 supported ordinary enemies, enhancement/drone load and normal equipment upgrades. Full 1373×883 graphics, OpenGL compatibility/RTX 2060, default 60 FPS cap and VSync, speed/time_scale 1, native execution and all existing effects enabled. Isolated saves disabled. Both actual-1x checks pass (game/wall A 1.00031, B 1.00330); both exits 0. Root reports unfocused at completion on both, but every sampled background_unfocused flag is false; no focus or OS setting was changed.

| Full frame cadence (ms) | A | B |
|---|---:|---:|
| Samples | 231 | 231 |
| Mean, all samples | 17.310593 | 17.259052 |
| Median | 16.647 | 16.647 |
| p95 | 22.877 | 21.184 |
| p99 | 43.903 | 46.040 |
| Max | 45.053 | 47.271 |

No samples excluded. Median uses the middle value(s); p95/p99 use nearest rank. Both measured windows: 240 logical steps / 4 game seconds, 1,751 fires, 6,533 hits, 48 purchased levels, 0 handoffs; final RNG `4413361150658287999`. Complete fixture and warmup+sample event totals are equal. Raw frame cadence, per-frame workload, runtime configuration and kernel metrics remain in A.json/B.json; summary.json includes full workload checks. Screenshots are captured after measurement.

Interpretation: no obvious aggregate slowdown in this one capped short pair. Mean difference B−A is −0.051541 ms, median unchanged, while p99/max increase 2.137/2.218 ms. Tail variability and the cap prevent a net-savings claim; neither >=0.5 ms improvement nor absence of tail regression is established. Stop after this pair; no second group or threshold chasing.

Startup failure retained in startup-driver-error.log: an extra observer registration referenced an optional method absent on accepted main. It failed before warmup/sample, produced zero timing samples, and the runner exited 1 after its own 90-second timeout. Removed only that extra call, reused successful imports, then obtained the sole A/B above. run.py records the repair and rejects overwriting existing samples. Long import logs remain local and are not committed.
