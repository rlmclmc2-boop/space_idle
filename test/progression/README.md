# Progression calibration evidence

Current evidence: full production event-hook fresh0–10 passes at8032.1167 X1 seconds for seed20261002 and120s visits; full native-frame comparison includes projectile/queue/drop contents for900s. Source40 critical176 and normal+3 64 fixtures pass. Runtime220-stage/1960-point tier and final-only completion checks pass. These are separate scoped checks, not a full0–galaxy journey.

Earlier basic-BattleGame results and all pre-hook formal+scene results remain approximate diagnostics. Scope corrections and negative results are preserved under `evidence/`. Current stage20, numeric34 stall, reforge recovery and all-buildings50–60h acceptance remain pending.

Experimental branch only. Source baseline: main b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f plus enemy-pair candidate 04a5a307bcef9325efa9026e1ca94affa577e10d. The inherited 6/32 loss-to-win changes remain unresolved baseline evidence; paired copies are not equivalent difficulty.

## Independent reproduction

Requires Python 3 and Godot 4.6.3 (official 7d41c59c4); package builder uses standard library only. Default builds copy reachable rule scripts and JSON. Formal scene acceptance requires `--scene`, which also includes authored scene/assets dependencies. Neither build includes engine, credentials or player saves. Configuration edits require openpyxl 3.1.5 and the formal import command below.

```sh
python test/progression/build_qa.py --output /tmp/progression-qa --scene
python test/progression/run_qa.py --project /tmp/progression-qa --label fresh120 --engine formal --scene --duration 64800 --stop-clear 20 --visit-seconds 120 --seed 20261002 --thematic --timeout 15000
```

Runs are EXACT original-rule fixed 1/60 X1 steps. QA acceleration saves wall time only. Results include fingerprints, settings, engine, action JSONL, wave/state durations, clear times, resource/growth state, RNG and checkpoints. Each label must be unique; preserve failed results. A save checkpoint resumes according to formal journey rules, not arbitrary enemy/projectile state.

Current pilot policy is a documented diagnostic proxy: 10s teaching visits; post-teaching 120/300/900s sensitivity assumptions, never a user-required cadence. Each visit uses the existing BALANCED transaction policy (bounded 12 module purchases, mixed unlocked weapons, danger-sensitive defense). This policy still chooses purchases algorithmically and is NOT a validated human playthrough. Manual drops are collected only at visits; unlock acknowledgment delays and automatic collection loss remain. Optional `--bulk` now means real per-card+10/+1 sweeps, not an imaginary manual all-module button. Major reforge recovery uses per-card+10 actions and counts every successful card. Planet, builder, reforge and legal crew handling use existing action APIs; legal full journey remains unverified. Per-second legacy autoplayer is only an optimistic diagnostic comparison.

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


## Sparse v6 recovery diagnostic

The corrected full-UI fresh seed20261002/120s run reproduces clear10 at8032.1167s (2.231h),116 active visits/800 domain action events. No enhancement branch is eligible by10; the 1,000,000-fragment controlled restored-clock fixture separately proves13 enhancement levels and first A branches, while the old modulo-clock policy buys zero. Evidence `full-ui-fresh120-through10` and `sparse-v6-phase-branches`.

Sparse v6 adds real per-card +10/+1 recovery visits after reforge, ends this recovery strategy after clearing the corresponding next planet gate, and restores its state in diagnostic checkpoints. This is a test strategy change, not a new mechanic or source-number change. Frozen ec82741 parent full run keeps its v5 policy and remains an independent comparison. The v15b ongoing fork predates the v6 stop/restore correction; its dirty code fingerprint is retained and it is only a segment diagnosis.

The v15 first-preparation segment cleared31 at42985.1667 and32 at44947.9000 from30 at41963.7333:17.02min to31 and49.74min to32. This fails the intended smooth progression over approximately4h preparation. Its later forge/recovery timings remain pending; do not infer success from the numerical coefficients.


The v16 hint candidate fixes the reforge dialog to match formal retained chrono/resources and ongoing exploration; it displays ordered conquest reward descriptions directly from `planet_buff` and reminds players that next-planet stage gates still apply. Source building/unlock hints now say iron/U rather than ambiguously all materials. Native actual-dialog confirmation plus queued module invalidation passes with no script errors; catalog1761 and protected543-source-row/normal-import checks pass. These text fixes do not change numerics and do not modify frozen parent evidence. `experience-ledger.json` tracks observed defects, numeric failures and separate hypotheses.


## v16 preparation-only numerical candidate

Source31–34 growth steps relative30 change28/42/54/76 ->38/52/66/86;35 endpoint100, all income, reforge benefits and stages36–60 remain unchanged. Normal exported JSON differs only in eight attack/life cells; protected543 rows and original header positions pass. Stage35 intermediate points inherit the changed34 endpoint via the existing interpolation rule. `prep31-32-v16` is a cross-version checkpoint segment, pending measurement; final fresh acceptance is still pending. The workbook generator now caches next row indices instead of rescanning worksheet max_row on every replacement. Interrupted pre-export attempt and premature unused package are recorded; no result uses that package.

Checkpoint reload now checks package code fingerprint alongside data/engine. Same-data different-code reload rejects without override; explicitly allowed1s diagnostic records its scope. Source and failed guard logs remain under `evidence/code-version-guard`. Parent separately reports676 frozen seed20261004/300 fresh20 at45796.62s (12.721h),264 retreats/206 visits, old enhancement policy; this is independent reported evidence, not this environment's run and not acceptance for ec827 policy.


## Additional sparse-policy and native-clock controls

Native scene reserve fixture (seed1701, starter slot structure, missile13/armour13, repeated original group1002, no input) gives700 X1 seconds from100 real+600 reserved seconds; reserve0, speed1. Continuous700 X1 gives885 kills versus883 with reserve, differing RNG while Iron0/U63 match. This proves budget consumption, not universal strict combat equivalence; render pose/recoil is only a suspected cause. Evidence `native-chrono-budget700`; invalid short-loadout first fixture is archived separately.

Native full-scene comparison from legal30 for900s passes full every-second projectile/queue/drop/resource/growth signatures. Optional `--ui-refresh-seconds 1` refreshes display cards/navigation once per simulated second, retaining every1/60 game, pose, turret, event and VFX step; fresh900 and late30/120 comparison with native every-frame display both pass. Display throttling is a diagnostic setting, not a player-progress shortcut or UI acceptance claim. Default remains every-frame.

Sparse v7 counts two retreats across visits: v6 loses the first retreat when resetting the counter after each visit; actual frozen-v6 controlled case does not farm, v7 does. Diagnostic restore offsets this marker against new metrics, retaining unhandled losses. `--policy-ref REF` builder option explicitly freezes one compatible policy and records its Git provenance; it is not default-strategy acceptance. Optional `--scientist-batch` uses the real +10 button after teaching when its full cost fits the same10% reserve budget, otherwise+1; controlled actual visit buys10 in one action. It is a declared alternative test strategy; no numerical source changes.

Old v14 no-forge/old enhancement policy was stopped after5.606h observed at34 to prioritize the stronger growth counterfactual; its manifest/save/trajectory and partial scope remain archived. This is not12h stall proof. Current forge/noforge/preparation segments and parent full run remain pending.

## Current v17/v18 segment evidence and native chrono repair

Completed segment results are in `evidence/v17-segment-results`: first preparation4.0667h, reforge→enter34 at0.4583h, reforge→clear35 at2.0058h (v5) or2.1529h (v7), both FAIL the4–6h clear35 budget. Entry34 and clear35 are distinct gates. v16 two-stage preparation2.0314h is too early; v17 raises31/32 offsets48/62 and reruns actual cards. v18 raises first35 endpoint100→112, leaving34 unchanged; Excel dependency propagation also changes61–220 attack/health ratios, which remain uncalibrated. Normal importer/protected543-source-row checks pass. Generation's timestamp-only mon/monGroup rewrites were removed after all cells/formulas were checked identical and import cache refreshed; exported JSON bytes remain exactly the frozen v18 QA payload.

The preserved stage20:9 legal-profile wave control takes216.417s with advantage sustained beam. v17 health/shield×0.26 and attack×2 for generated11–20 Boss/Ult gives58.217s; mixed74.083s and all-laser110.350s. This supports that profile's beam duration only, not every advantage weapon or fresh cumulative20 timing. Parent separately reports frozen b2dc seed20261004/300s/fullscene/actual-button fresh10 at9293.40s (2.582h),20 at43184.72s (11.996h), still running; this environment has not run that parent's save/version.

Fresh900s visits with v7 real per-card/scientist+10 clears10 at10726.483s (2.9796h),480 observed events/67 sessions; weaker900 policy4.498h remains a failure. No30min user requirement is assumed. `operation-burden.json` separates teaching and normal intervals and reports large118–119-event reforge bursts; these are domain events, not literal mouse clicks. Restored segment operation gaps now begin at their actual input clock rather than treating the earlier journey as a single idle interval.

Native chrono production fix is a separate commit from v18 numerics. `evidence/chrono-fix-iterations` isolates the first provider mismatch and preserves intermediate failures, then validates360 logical kinematic inputs/1301 real provider calls, unchanged pre-fix X1 trajectory,700-second reserve accounting with exact kills/resources/RNG, fresh900/late30900 native-vs-Driver signatures, and nativeX1/X10 active planet exploration/shipyard construction/researcher60s signatures. Active galaxy equivalence and one-version full-fresh all-max completion still need their own saved-state tests. See that evidence README for exact entrypoints/manifests and successful own-package import requirements.
