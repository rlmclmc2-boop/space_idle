# Progression calibration evidence

Experimental branch only. Source baseline: main b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f plus enemy-pair candidate 04a5a307bcef9325efa9026e1ca94affa577e10d. The inherited 6/32 loss-to-win changes remain unresolved baseline evidence; paired copies are not equivalent difficulty.

## Independent reproduction

Requires Python 3 and Godot 4.6.3 (official 7d41c59c4); package builder uses standard library only. Build copies only the reachable game-rule scripts and JSON, never assets, engine, credentials or player saves. Configuration edits require openpyxl 3.1.5 and the formal import command below.

```sh
python test/progression/build_qa.py --output /tmp/progression-qa
export XDG_DATA_HOME=/tmp/progression-qa/userdata
export XDG_CONFIG_HOME=/tmp/progression-qa/config
export XDG_CACHE_HOME=/tmp/progression-qa/cache
godot --headless --editor --path /tmp/progression-qa --import --quit
export PROGRESSION_OPTIONS='{"label":"baseline120","duration":10800,"stop_clear":10,"seed":20261002,"visit_seconds":120,"teaching_seconds":10,"strategy":"BALANCED"}'
godot --headless --path /tmp/progression-qa --script qa/progression_probe.gd
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
