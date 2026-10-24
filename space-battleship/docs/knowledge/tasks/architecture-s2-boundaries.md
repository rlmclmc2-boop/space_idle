# Architecture S5 - bounded closure candidate

## Authority / delivery state

Same executor task and branch `work/architecture-s5-scope-20261024`; no replacement task/audit. Scope 101501b56cbf9215c113bf030142b75689bb6110 approved by dot/high. Original plan: d08f24e8344b5e0f7068b449005187c44ae122de:space-battleship/docs/GLOBAL_ARCHITECTURE_PLAN.md. Main remains S4 1795d5c5cef6a20060303e5f1c914542edc882a4.

S5 runtime checkpoint 2e0fc2b4 has high limited approval for cleanup/entry coverage, not final S5 approval. Subsequent changes are harness/guide/evidence corrections; runtime production bytes remain that checkpoint. S4 final approval is faa24fbd48efc1558334dc42631b7324b7badec5, Windows release verification 43e53b8c; earlier ad08/fe94 checkpoints are not final approval. No S5 main merge. Final dual review remains required.

## Responsibility closure and actual scope

[ARCHITECTURE](../../ARCHITECTURE.md#supported-entry-closure) contains the eight supported entries (player, F8, F9, portable Lab, configuration, level editor, player build, tests), old responsibility -> sole owner -> consumers -> evidence/reuse/limits table and the existing drone-storage/reactor/lifecycle extension example.

Removed empty Crew.on_event, its attach connection and install disconnect; scheduling remains Crew.on_committed through CommitEffects. Removed Game.resource_minute_total's mixed boolean facade; current selected checks use IncomeHistory.display_total. Current code/selected consumers have no old references. Historical nested progression diagnostics retain old references and are explicitly not acceptance. Inert legacy scientist defaults/false APIs have no current business consumer; their historical diagnostic callers and save erasure are explained, not presented as current mechanics or whole-repository cleanup.

Runtime direct data/template readers in supported entries resolve captured configuration; publication remains ConfigPublication/ConfigSnapshot, ordinary report FileAccess remains report I/O. Lifecycle, StepProgress, domain cursors, native compiler and Lab ExecutionContract/Identity retain distinct responsibilities. No unexplained active second owner/bypass was found in the scoped entry trace. No gameplay, numeric precision, refund, historical save/formation compatibility or battle timing change.

Current guide corrections distinguish pre-domain saved-game/crew/research/metrics probes and test/progression/time_equivalence.gd, formal_scene_clock.gd, test_progression_scene_equivalence.gd from supported checks. Assertions remain as historical investigation material; no compatibility APIs were restored. This is not a claim that every repository test is current or green.

## Necessary verification

- Commit boundary 131/0; state ownership 1230/0; opening feedback 21/0. Logs: test/work/test_balance_database-v1_cwbfm/s5-test_commit_boundary.gd.log, s5-test_state_ownership.gd.log, s5-recheck-test_opening_feedback.gd.log. Reused isolated scripts were compared against candidate: no production script differences.
- Material economy candidate 157/0: s5-final-test_hyperspace_material_economy.gd.log in the same area. Preserve both storage formula variants; replacement assertion now uses the actual published configuration, not a transient mutation of the departing instance. The same corrected fixture passes S4 original runtime. Known fixture-exit ObjectDB/resource warnings remain disclosed.
- Actual final entry: test/work/test_ordinary_entry-g3rqnfy0, eight rendered phases 151/0; restored-domain mismatches empty. Deliberate configuration-corruption rejection and the known certificate-store diagnostic remain visible; no script errors..
- Unknown existing reuse directory, nonexistent reuse directory and empty/malformed fingerprint record all reject before any directory/content mutation, including with --ref. Evidence test/work/s5-reuse-rejection.json. Fingerprint check is before archive/copy/write. No unknown-source reused measurement is included: all three directories below were originally created by this runner and then reused with their recorded source fingerprint.
- S4 native subset 5717/0, portable S4 04 and full Windows release 43e53b8c are reused: compiler, native bundle, builders, dependency roots, templates and publication paths are unchanged by this runtime deletion. The current actual main entry and resident native measurements cover the changed Game/Crew integration. Do not claim new compatibility or release performance guarantees.

## Same-work comparison

Serial engines on this Windows host, official Godot 4.7.2, NVIDIA RTX 2060 / gl_compatibility / 1373x883. Engine SHA256 ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424; native DLL 4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f. Fixed seed 1701, manual 1/60 logical step, 15 warmup + 300 measured steps/page; normal and rich three alternating repetitions, dense 15-enemy one repetition. The normal fixture uses scripted execution; rich explicitly admits the existing native subset. These labelled CPU/manual-step observations are not rendered FPS or an average-player benchmark.

Baselines: S0 793f7c4cda5e480434f14663597ffbeee72163ff; S4 main 1795d5c5; candidate runtime 2e0fc2b4. All 19 data JSON contents match; 17 differ only by CRLF/LF normalization. Source fingerprints: S0 1f0447c835f0721898df33e5e7e8f1db04a18dcc45b0066186a71d09abd418dd; S4 7af118f962ddf55e3d85846e1ffa71d26c0bd6f25af0b70924adadad14a1931c; S5 ad792b4fb4f6a4b6d9789094fe2d8e3da8b52ec1dfe13dd7a8f1386fa809d234.

Observed start/end accepted time, RNG, stage/group, actor health/population, equipment, economy, research and projectile/attack counters match across all nine samples for each row below. Values are median of each run's p50 / p95 main CPU milliseconds:

| Scenario / page | S0 p50 / p95 | S4 p50 / p95 | S5 p50 / p95 |
|---|---|---|---|
| normal / 0 | 1.613 / 2.214 | 1.639 / 2.209 | 1.667 / 2.371 |
| normal / 4 | 1.698 / 2.691 | 1.935 / 2.927 | 1.885 / 2.851 |
| normal / 1 | 1.720 / 2.892 | 1.881 / 2.909 | 1.883 / 2.930 |
| normal / 2 | 2.007 / 3.376 | 2.139 / 3.380 | 2.171 / 3.434 |
| rich / 0 | 2.231 / 3.273 | 2.424 / 3.621 | 2.528 / 3.911 |
| rich / 4 | 1.842 / 2.667 | 2.017 / 2.856 | 2.031 / 2.815 |
| rich / 1 | 1.903 / 2.929 | 2.025 / 2.868 | 1.969 / 2.986 |
| rich / 2 | 2.043 / 3.036 | 2.161 / 2.968 | 2.130 / 2.982 |

Pages 6/8 are measured but not aggregated as same-work speed comparisons: asynchronous page preparation accepts different counts of game steps, and S0's later normal research-income peak differs from the corrected native-source rule. Existing gameplay was not paused/reset/modified to conceal that difference. Shared pages 0/4/1/2 supply the valid comparison. No universal speedup: some current CPU costs are higher; S5 cleanup is generally close to S4. No causal micro-optimization claim is made from uninstrumented totals.

All rich rows actually retain native execution for 300/300 measured frames and advance approximately five game seconds. Dense 15-enemy case also has equal full observed work and 300/300 residency: p50/p95 ms S0 3.320/5.538, S4 3.556/5.797, S5 3.337/5.528. Single dense observation only. Dense Godot static-memory delta ~0.706 MB, +1 node for all versions; shared normal page deltas 0.079-0.741 MB, rich 0.020-0.506 MB. These finite retained-object observations are not a long-run leak guarantee. Page switch CPU is separate: candidate medians pages 0/4/1/2 normal 456/7444/3939/14095 us, rich 447/10593/4076/14903 us; asynchronous preparation cost/time remains in raw reports.

Growth uses the existing actual BalanceRunner, 300 seconds / 18000 steps, seed 12345: stage 4, 8 upgrades, 2 reactor levels, 2 equips. S4 and S5 complete work dictionaries match exactly; setup seconds 2.035/2.045, execution plus report 32.695/32.741. S0 setup/run 1.064/30.961 seconds is NOT a same-work comparison: its Research progression differs. The initial 30-second/1800-step sample performed no growth and is only smoke evidence.

F9 final complete-cost observation: existing speed probe, 2 candidates per side, first enemy/1-2 ships/module level 10, 6 completed wins per budget, seeds 12345-12350. All physical result fields (IDs, seeds, battle times, HP ratios, damage, status) agree across versions/budgets; S4/S5 differ only in captured execution identity. A single complete observation per version and budget is recorded, not a statistically general speed result.

| F9 cost, seconds | S0 | S4 | S5 |
|---|---|---|---|
| Input generation setup | 1.120 | 2.901 | 2.921 |
| Batch start, 8 ms budget | 1.237 | 4.016 | 3.994 |
| Execution + report CPU, 8 ms budget | 4.061 | 5.222 | 5.078 |
| Execution wall incl. frame yields, 8 ms | 5.764 | 7.137 | 7.028 |
| Batch start, 24 ms budget | 1.162 | 3.998 | 3.918 |
| Execution + report CPU, 24 ms budget | 3.866 | 4.957 | 4.999 |
| Execution wall incl. frame yields, 24 ms | 3.871 | 4.962 | 5.004 |

Current F9 preparation and execution are more expensive than S0 in this small batch. The additional cost is observed, but causal attribution is not established; the phase totals do not identify which boundary or algorithm caused it. No savings or performance optimization has been demonstrated. S5 stays close to S4 in these observations. Raw complete-cost logs: s5-*-f9-complete-1.log under the three directories below; index test/work/s5-f9-complete-index.json. Physics output equality does not authorize report merge/retest across implementation identities; S0 lacks the later identity metadata. Identity/admission work and report production are part of current costs, not excluded to make a speedup.

Git-readable candidate evidence: [architecture-s5-final](../../../evidence/architecture-s5-final/README.md), with a portable review index, original result/log bytes, original source-hash inventories and a payload hash manifest. This evidence directory is excluded from any later main delivery. No rerun or Library upload was performed to package it. Original local evidence paths (retained for provenance): test/work/s5-render-perf-index.json (21 completed measurements / 111 page rows), s5-performance-summary.json; whole-perf-emeyxxwi (S0), whole-perf-51jfln82 (S4), whole-perf-jmdyo0ti (candidate), files s5r-*.json/log; s5-growth300-index.json and s5-*-growth300-1.log. Each report retains engine/native/probe/source hashes and actual work. Ordinary timing and instrumented attribution are not mixed.

## Failures / limits / stop

The initial headless candidate six-page sample produced DummyMesh renderer errors and is excluded from passing timing evidence. Actual rendering succeeded. One long matrix process ended during candidate dense import without a completion result; the eight completed indexed samples were retained and the unfinished item rerun in shorter chunks. Two initial larger F9 generation attempts timed out at 120 s; the bounded existing small fixture is a different workload and does not certify the larger generation pool. Initial opening feedback used removed invalidate_stat_cache (fixed to current notification); initial storage restore fixture assumed transient config inheritance (fixed without production changes).

The two known historical formation compatibility failures remain: unchanged combat-slot reuse and legacy formation snapshot execution, reproduced on S2 main a1b31ce1. No attempt to make the entire test repository green. Freezing remains narrower than arbitrary interrupted recovery; GrowthNumber discards precision-external amounts; Lab/native limits and HP-only Lab damage remain explicit. No new performance guarantee.

Stop after final dot/high agreement on this bounded candidate. No main merge is authorized by this S5 instruction; no further framework/gameplay/cleanup expansion is planned.
