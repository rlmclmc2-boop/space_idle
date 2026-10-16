# Final-source enemy intelligence presence control (2026-10-16)

## Exact source and workload

Both isolated projects came from candidate commit `e4c2543ed1577c71ab85b4039cf51e5d8d944a25`. `source-manifest.json` hashes every archived source/asset before the identical QA counter instrumentation; `source-manifest-instrumented.json` hashes those same 1190 shared files plus the candidate-only page after instrumentation. The only control changes are the removal of enemy-page wiring from `scripts/beginner_guide.gd`, `scripts/main.gd`, and `scripts/shell_presentation.gd`, and deletion of `scripts/enemy_intel_page.gd`. Their exact source diff is `control-removal.patch`. The generic `select_system` change and the four authored `intelName` changes are present identically on both sides. No page is constructed in the control.

The existing `five-environment-20261015/baseline` driver and mixed/combat stress fixtures were used unchanged. Driver SHA-256: `789154ddaba074cdcad6a75c9e721d93f5fc3bafa4ea5f2685929d3fd0ab331c`; counter instrumentation: `d61d9f6ba1505ebc2b5ff4aadfccfdd5797a6aea16ce8b4c71c928a5ab2ded37`; accepted native DLL: `2cf90edabbb55576b1e99027889c708007e51df87861caf3c03bbdddcecae96a`; Godot 4.7.2 console executable: `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`. `summary-lite.json` lists per-run fixture, DLL, JSON and screenshot hashes; `system-load.json.gz` preserves CPU samples.

The five suites ran serially, each control → candidate → control, with 240 warm-up and 480 measured logic steps at actual 1×/60Hz, full GL compatibility rendering, stat cache on, save off, FPS 0 and VSync 0. Every raw trace passed full-frame timing closure, focus, speed, sample, and native-admission checks. Events, fires, hits, fixture and DLL were identical within each bracket. All 15 `.json.gz` full-frame traces, logs and screenshots are included here.

| Suite | First control | Candidate | Second control | Candidate minus bracket |
| --- | ---: | ---: | ---: | ---: |
| mixed | 8.365ms | 8.212ms | 8.249ms | −0.095ms |
| laser | 5.848ms | 5.805ms | 5.802ms | −0.020ms |
| cannon | 6.965ms | 6.275ms | 6.388ms | −0.402ms |
| missile | 7.306ms | 7.161ms | 7.064ms | −0.024ms |
| longLaser | 11.414ms | 10.530ms | 10.565ms | −0.459ms |

These are mean full-wall-frame observations, not proof that the page speeds up the game. The first cannon control had 18.1% mean system CPU busy versus 11.4%/10.9% in the next two runs; first longLaser control had 13.7% versus 9.5%/10.1%. Both explain why their negative bracket differences should be read cautiously. The longLaser controls themselves average above 10ms; mixed and longLaser p95 frames are also above 10ms. No every-frame-under-10ms claim follows from this evidence.

## Identity and functional checks

Stage-three points 2 and 4 each contain two distinct enemy IDs. Their respective authored rows differ in iron drop amount (38/37 and 33/32), so they remain separate entries with table-authored `甲型` and `乙型` names. Only four `intelName` fields changed in `game_data.json`; no damage, cooldown, reward or combat formula changed. `stage-three-authored-names.png` shows both pairs and reactive-armour detail in the actual main scene. Godot reported a 1600×1000 root/window, while its saved render texture is 1554×1000; the PNG dimensions are reported here rather than relabeled. The real enemy-tab chain passed 27/27 checks, including both name pairs. The import validator passed.

This presence control samples the page unopened. The earlier targeted opening trace at commit `a6de59ac` measured 5.898ms synchronous and 17.129ms through the next rendered frame; that latter interval includes waiting for draw and sits slightly above 16.7ms. The final source changes after that trace were authored names only; the opening timing was not remeasured. The unchanged `test_resource_display.gd` still has two known failures out of 19, reproduced on both `origin/main def6185e` and the candidate in `enemy-intel-perf-20261016`. Those failures are outside this targeted page acceptance.
