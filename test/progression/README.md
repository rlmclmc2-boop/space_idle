> 2026-10-02 scope correction: all earlier formal+scene progression and wave results omitted the scene event hook and are retained as approximations only. See `evidence/scene-hook-scope-correction.json`. The corrected driver connects the production event handler; new acceptance requires native-frame equivalence and fresh reruns.

# Progression calibration evidence

**Correctness boundary:** earlier exact runs inherit base BattleGame. Actual main uses PresentedBattleGame (real missile ejection/retarget and rail motion). All earlier progression timings are base-rule diagnostics, not formal player acceptance. New default `--engine formal`; add builder/runner `--scene` for actual scene providers. The initial formal-vs-native scene comparison passed900 seconds through6-4. Full formal long-run timing is pending.


Experimental branch only. Source baseline: main b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f plus enemy-pair candidate 04a5a307bcef9325efa9026e1ca94affa577e10d. The inherited 6/32 loss-to-win changes remain unresolved baseline evidence; paired copies are not equivalent difficulty.

## Independent reproduction

Requires Python 3 and Godot 4.6.3 (official 7d41c59c4); package builder uses standard library only. Default builds copy reachable rule scripts and JSON. Formal scene acceptance requires `--scene`, which also includes authored scene/assets dependencies. Neither build includes engine, credentials or player saves. Configuration edits require openpyxl 3.1.5 and the formal import command below.

```sh
python test/progression/build_qa.py --output /tmp/progression-qa --scene
python test/progression/run_qa.py --project /tmp/progression-qa --label fresh120 --engine formal --scene --duration 64800 --stop-clear 20 --visit-seconds 120 --seed 20261002 --thematic --bulk --timeout 10000
```

Runs are EXACT original-rule fixed 1/60 X1 steps. QA acceleration saves wall time only. Results include fingerprints, settings, engine, action JSONL, wave/state durations, clear times, resource/growth state, RNG and checkpoints. Each label must be unique; preserve failed results. A save checkpoint resumes according to formal journey rules, not arbitrary enemy/projectile state.

Current pilot policy is a documented diagnostic proxy: 10s teaching visits; post-teaching 120/300/900s sensitivity assumptions, never a user-required cadence. Each visit uses the existing BALANCED transaction policy (bounded 12 module purchases, mixed unlocked weapons, danger-sensitive defense). This policy still chooses purchases algorithmically and is NOT a validated human playthrough. Manual drops are collected only at visits; unlock acknowledgment delays and automatic collection loss remain. Planet, builder, reforge and legal crew handling use existing action APIs; legal full journey remains unverified. Per-second legacy autoplayer is only an optimistic diagnostic comparison.

## Ordered work and acceptance gates

1. Freeze baseline; run 0–10 budget and sparse-policy sensitivity; record actual blockers. Generate level source Excel: 1–5 four normal+elite, 6–19 five normal+three elite+Boss, themed by level. Levels 4/5 defense pairing/resource upgrades are suggestions.
2. Tune early growth and wave difficulty together. Targets: teaching 2–4 minutes each (first about 2), stage 10 cumulative 2–3h; waves 10/20/30/60s for advantaged weapons, normal +3 worst-case reserve. Keep 32% neutral disparity as starting point, not proof.
3. Expand to stage 20 (5 elite/3 Boss/region Boss, cumulative 12–18h); repeat special structure every fifth level 25–70 and every tenth from 80. Preserve stage/node distinction.
4. Planet stage 30: approximately 4h preparation, shipyard construction 75% (3h), smoothly advance two levels; numeric stall at 34 lasts at least 12h without reforge, no hard lock/immunity. Reforge return 34 <=2h, clear35 at 4–6h. Record fragments of upgrades across all systems.
5. Expand fifth-stage cycles to 60 galaxy unlock, then every building in first galaxy maximum at fresh cumulative 50–60h. Later planets repeating exactly 4h preparation remains undecided.
6. After segmented tuning, fresh-profile end-to-end run on ONE frozen code/config/policy version. Never splice mixed-version sections into a full pass.

Offline audit: formal game grants only chrono, capacity 12h. With configured speed M consuming M−1 particles per real second and earning 1 per offline second, retained chrono adds exactly the offline X1 budget when spent, once. Verify actual main conversion and formal reload tests before equivalence claims; no offline resources or second catch-up simulation.

All changes go through config_excel fields without deleting existing columns, then:

```sh
python space-battleship/tools/config_workbooks.py import
```

Evidence categories: diagnosis, checkpoint regression, full fresh run; facts versus hypotheses; numeric fixes versus experience recommendations. Every candidate records reason, affected stages/systems, prior failure and retest. The parent independently runs this package; this branch does not claim that happened.

## Formal v9 milestone (not full acceptance)

Frozen v9 source at9efd2c4, formal+scene package fingerprint `c4d5fa9b18efea35d89b1fc0a4a3af6408019b4d1eff2eaf7506989dbc619607`, seed20261002: first5 clear737.5667s, clear10 at8408.65s (2.336h). Teaching intervals2.07–3.04min. Before clear10:114 active action sessions and784 API events, not mouse clicks. The same fresh run continues through20; same-package300/900s visit sensitivity is running. This is one seed/strategy proof, not validated human experience or full0–galaxy acceptance.

v9 changes11–20 income coefficient .1 with exponent9 per stage, enemy exponent13 retained; existing hightech cost-growth threshold400→50. First planet reforge effect levels25 equipment/20 research; later15/10 remain provisional. Numeric21+ still contains unaccepted earlier prototypes. See `evidence/v9-freeze.json` and `evidence/formal-scene-v9-milestone10/`.

Parent reports independently executing native Presented/adapter actual-scene comparison1800s through6-5, identical every second; local proof executes900s through6-4. Both scopes are limited. Controlled basic clock151 checks do not establish actual scene/frame/boost equivalence. New `formal_scene_clock.gd` checks actual provider geometry plus main.advance_game_time at60/144fps andX1/X10; it is a diagnostic, not full GUI execution.

Private actual-scene compensation for the known6 inherited early wins restores the adjacent loss/win gates at physical-pair damage factors1.4 beam elite,1.3 neutral1 elite,1.5 physical Boss,1.8 energy region Boss. No source compensation has been applied yet; remaining groups and target timing still require checking.

First reforge QA strategy now allows action after clear32 plus existing ready conditions; this is no gameplay gate change. Successful reforge clears stale farm/best-won state. That policy change is not injected into the frozen in-progress v9 package; below30 outcomes are unaffected.

## Clock repair and version boundary

The parent independently reproduced X10 furnace peak amplification in `qa/parent-probes-20261002` at `4d81bed07d88c008a02bcbd42eff25eb217214e4`. The experimental repair gives production its own persisted game clock while HUD receipts retain wall time, routes galaxy production to the same direct-input window, and uses 1/60 steps in formal main at every multiplier. Existing old historical peaks are retained; their historical acceleration cannot be reconstructed.

Run the controlled receipt/save/offline-clock regression in a freshly built package:

```sh
godot --headless --path /tmp/progression-v3 --script qa/time_equivalence.gd
```

Controlled 600 X1 seconds: X1 and X10 both receive iron 7854, retain furnace peak650 and direct production window600; HUD real-minute totals intentionally differ. This is a rule fixture, not a full offline catch-up playthrough. Main time139/furnace32/research70/galaxy2344 assertions passed. `test_offline_resources.gd` retained failure: immediate reload reports offline particles again from the same unsaved snapshot, although resulting reserve is unchanged. Current timed/manual-only saving leaves startup settlement unsaved; changing this needs an explicit persistence decision and is not concealed by this repair.

Pre-repair v3 is frozen evidence: 120s visits cleared10 at8045.9s,30 deaths; 300s and900s budgets ended at10800s without clearing10. Teaching with thematic choices took124.22/138.75/150.85/136.27/154.7s,0 deaths. Stage6 consumed4663.23s and farmed the previous level repeatedly: a pacing bottleneck to redistribute. Recorded action events are API/domain events rather than literal mouse clicks; early acknowledgment instrumentation overcounted pending notices and is retained as a known measurement defect. Complete all final acceptance on the repaired single version.

## Phase 20 / systems candidate v4

The v4 source extends the new roster through20 (20 uses5 elites/3 Boss/1 region Boss), reduces the stage6 difficulty step, bounds the reactor capacity growth at1.06, and uses a slower income budget for11–20. These are numeric candidates, not accepted timing. A fresh0–20 EXACT run has started with120s visits and existing all-module bulk buttons. A targeted-policy defect was found: after choosing a new push stage at the end of a visit, weapons retained the preceding stage's mixed refit until the next visit. Fixed by refitting during that same actual visit; earlier runs remain diagnostic evidence.

First planet uses60s minimum exploration trips, shipyard unlock60+build180; controlled10/60s visit cases measured14490/14940s ready,10803s shipyard construction. The subsequent station threshold reduction1+1 addresses repeated manual exploration dispatch latency; remeasure before accepting. Later planets keep the old150+10 shipyard thresholds (preparation repetition remains undecided). A `previous_id` source field only migrates earlier building save identity when splitting first/later shipyard configuration, preserving built/ready/in-flight state. Workshop/refinery degree growth is restrained to avoid passive exploration dwarfing reforge.

Galaxy unlock is60 with existing six-conquered-planet condition; first galaxy work30000 and per-building upgrade work2520 (total75600). Controlled construction is only a phase budget; legal crew availability and fresh cumulative50–60h remain unverified. Preserve continuous0/5/10/20/30/32/34/reforge/35/every5/60/all-max snapshots; no cross-version concatenation.


Sparse policy v4c returns to a normal point actually won in the current stage, travels there normally and only toggles guarding at a visit after arrival. Previous-level-first-point failures remain retained. Conquered explorers are manually recalled after galaxy unlock; the two-idle-crew reserve then ends. All are test strategy assumptions. Parent independently compared formal BattleGame and exact BalanceGame on d41d622 for3600 seconds, same config/seed/purchases, each-second combat/resources/RNG/research: identical through6-3; no later-system extrapolation.


## v4 failures / v5 pending

v4c current-stage farming cleared10 at7583.05s (2.11h),20 at12773.40s (3.55h),144 retreats. Independent parent756ad15 seed20261004/300s visits cleared10 at9265s (2.574h),20 at16416.95s (4.56h),246 retreats. Both fail20 timing; bulk exposed overly fast real growth. v5 lowers11–20 drop income coefficient from0.1 to0.001, without restricting purchase frequency. Numeric gates still pending.

The sparse node5 selection can overshoot into elite/Boss before the next visit. v5b selects a previously won current-stage first normal point at departure, using normal start/toggle actions and real travel. This removes that strategy error; fresh retest is running. Saved evidence is immutable.

Structural generation now covers all220 levels: teaching5 nodes; later9;20/25/…70 special;80/90/…220 special. Numeric calibration stops at20; uncalibrated later formulas are recomputed rather than silently retaining stale caches. Stage4/5 suggested topics remain in candidate metadata.

Checkpoint experiments require `--resume PATH`; data mismatch requires explicit `--allow-version-change`, and run metadata labels all resumed experiments diagnostic. They restore formal journey behavior, not live projectile state, and assign zero offline interval. Final acceptance must still start fresh on one frozen version. `--stop-galaxy --stop-clear220` ends only when first galaxy all buildings are max. Reforge/reach checkpoints and phase timestamps are now collected.

Operation measurement now counts each batch once and includes manual collect/scientist events. It remains an API event estimate, not literal mouse clicks; old event totals are retained with their measurement version.


## Future prototype v6 / outstanding gates

The provisional30–60 budget replaces inherited tenfold difficulty steps with explicit staged curves. First reforge bonus candidate+15 equipment/+10 research effect levels (formerly+5/+5), retaining existing mechanisms and later original preparation times. Nothing beyond20 is accepted. A fresh no-reforge run stops on first reaching34; use that same-version checkpoint for the12h stall diagnostic, then replay the eligible reforge and return/35 timing.

Sparse first-normal farming now respects guarding during clear settlement. The formal old-ID shipyard import path now restores builders through previous_id, not only direct state sync; negative reproduction on the previous code fails, corrected full-import cases pass. Six legally unlocked crew can be assigned in a controlled60/six-conquered fixture; this proves capacity/action validity only. Final galaxy strategy respects authored maxCrew6 and retains other growth assignments.

v5 40-template rule matrix uses exact BattleGame geometry (not the earlier Presented fixture). Paired copies show early wins across additional elites/Bosses, so private factor diagnostics are running before any source compensation. Ordinary+3 guarantee and target bands require complete matrix and retest.


## Reproduce the formal scene path

```sh
python test/progression/build_qa.py --output /tmp/formal-qa --scene
python test/progression/run_qa.py --project /tmp/formal-qa --label fresh-formal --engine formal --scene --duration 64800 --stop-clear 20 --visit-seconds 300 --seed 20261004 --thematic --bulk
```

Use actual spaced CLI forms (`--duration 64800 --stop-clear 20 --visit-seconds 300 --seed 20261004`). The core no-scene package remains small; optional scene dependencies copy authored project assets/scripts and exclude engine, Blender source, credentials and player saves. Source fingerprint includes every dependency.

`PROGRESSION_COMPARE_SCENE=1 PROGRESSION_COMPARE_DURATION=900 python test/run.py test_progression_scene_equivalence.gd --godot /usr/local/bin/godot --headless --timeout 1800` independently compares adapter/native Presented class, actual scene providers, same sparse operations, every-second state/RNG/resources/research/queue. This tests the adapter and selected scene update path; it is not a claim of all viewport/frame-rate equivalence.

Main now carries frame tails in a fixed1/60 accumulator. Prior1/60 maximum still performed shorter tail ticks each render frame, allowing144fps X1/X10 combat drift even with equal production clocks.151 checks pass including45/60/144fps budgets, pause/background and original particle accounting. Runtime pending time is under1/60 second; save/reload does not persist that substep.

Source v7 smooths11–13 income with at least1.4× preceding income, eliminating the99% reward drop;14–20 coefficient remains prior v5 until next linked adjustment. Source/import transaction locks avoid intermediate formula-cache reads.
