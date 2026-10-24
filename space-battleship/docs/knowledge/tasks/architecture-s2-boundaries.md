# Architecture S5 - cleanup and whole-system acceptance scope

## Authority and delivered base

Same existing executor task; no replacement task or new audit. S5 scope at 101501b5 has dot/high approval. Implementation is in progress, not accepted. Parent coordinates the existing dot/high review.

S4 approved candidate: faa24fbd48efc1558334dc42631b7324b7badec5, unanimously accepted by dot and high. Full S4 history is in this path at that commit. Original approved plan: d08f24e8344b5e0f7068b449005187c44ae122de:space-battleship/docs/GLOBAL_ARCHITECTURE_PLAN.md, S5 and responsibility-exit table.

Delivered main: 1795d5c5cef6a20060303e5f1c914542edc882a4; normal push and remote readback confirmed. Selected 37 runtime/build/current reusable test/document files; task history, evidence and temporary products excluded. Selected blobs and complete production scripts/tools/data/config_excel/manifest/export settings match the approved candidate. Actual filtered main entry: test/work/test_ordinary_entry-pxxa4or1, eight phases, 151 checks / 0 failures, restored-domain mismatches empty. Intentional configuration-corruption rejection and known certificate-store diagnostic remain visible.

S5 branch: work/architecture-s5-scope-20261024, based on delivered main. Runtime cleanup removes the empty Crew UI-event connection and mixed income query facade only.

## 1. Retire only responsibilities with proven absent consumers

Begin with exact symbols and current entry-derived consumers, then make small deletions/delegations with affected existing checks:
- crew_system.on_event is an empty fixture compatibility hook. Current hits: Game.install_prepared_game disconnect guard and four existing fixture calls. Verify all connection/call consumers; retire the empty hook/guard and move applicable assertions to actual event/committed-fact behavior without restoring event-driven scheduling.
- Game.resource_minute_total has one existing test consumer (test_opening_feedback). Move it to the appropriate named IncomeHistory query before retiring the mixed boolean facade; preserve existing clocks/bases and eligible enemy/top-resource drops. Resource-sample-name hits in main.gd are UI projections, not automatically obsolete state. Pruning delegates still doing work are not deletion candidates merely because their names are old.
- Confirm retired game_time_remainder/native_step_phase and equivalent duplicate ownership do not return. Review bool/int facades by consumers: retain genuine current UI APIs derived from full command results, remove only abandoned migration bridges. Domain cursors, writer locks and display state remain distinct owners.
- Audit S3 lifecycle/configuration and S4 Lab readers against supported_entrypoints.json for abandoned bypasses or duplicate authority. Existing native compiler, low-level workbook validation and ordinary report I/O keep their roles.
- Legacy field names in profile sanitation/save rejection are not automatically compatibility implementations. Distinguish intentional schema rejection from obsolete positive fixtures before changing anything. No historical save/formation compatibility is added.

Deliver a concise old symbol -> current owner -> remaining callers -> deletion/retention reason table. Do not hide an unresolved live consumer behind S5 completion.

## 2. Make current docs and test entry claims truthful

Use existing ARCHITECTURE.md, BALANCE_LAB.md, BALANCE_PERFORMANCE.md, TEST.md, README/build instructions, supported_entrypoints.json and test/guides. Reconcile S4 identity/admission ownership, unknown identity, native/Lab limits, and current F9/portable pages. Distinguish historical decisions from current research mechanics; do not reinterpret user gameplay decisions.

Concrete gaps found during scope inventory: test_balance_performance still overrides advance_hightech and logs hightechLevels/scientists; test_balance_research_performance assumes old jewel_serial/profile fixture setup. Some advertised tests retain obsolete fields. Check each reached test's unique behavioral coverage before migrating or retiring it; preserve real assertions and classify outdated expectations explicitly. Remove obsolete one-off acceptance claims, not reusable regressions. The two known formation compatibility failures remain disclosed and outside compatibility expansion.

## 3. Same-workload whole-system comparison, not a new benchmark framework

Use existing test/whole_game_perf.py + whole_game_perf.gd as the main comparison entry; existing crew/Lab performance probes only where needed to isolate a demonstrated cost. Repair the existing harness's current entry/capture omissions first (whole_game_perf.PARTS currently omits configuration_manifest.json); do not change production gameplay to make a benchmark run.

Proposed architecture baseline: approved S0 delivery 793f7c4cda5e480434f14663597ffbeee72163ff, an ancestor of current main. Preliminary Git check: runtime business JSON and accepted native sources/bundle are unchanged between it and S4 main; only published workbook copies were added under the compared configuration roots. Also retain S4 main as the local before-S5 baseline so cleanup is not confused with all earlier migration effects.

Pin this machine, official Godot 4.7.2 executable/hash, verified native DLL/hash, configuration contents, fixed seed, scenario setup, page order, entity population and logical-step count. Start with the existing normal/rich scenario families and pages 0,4,1,2,6,8 at 300 measured steps after the existing warmup; use three alternating before/after repetitions. Add a 15-enemy battlefield case only as the bounded existing dense scenario, not an unbounded stress expansion. Instrumentation is for attribution, excluded from final timing comparison. Reuse isolated imports only when their source/config fingerprints match.

Before comparing timings, record/check actual accepted time, completed work, domain/result/RNG counters and final workload population through the existing harness. Same duration or requested frames alone is insufficient. If earlier bugs or model differences produce different work, label that pair non-comparable, explain it, and measure a shared supported scenario; never report skipped/rejected work as speedup. Report median/tail CPU time, memory/retained-object observations and setup/report cost separately. Headless CPU/manual-step timings are not rendered FPS. No guaranteed speedup, global model equivalence or new precision accounting is inferred. Any performance code change needs the existing D007 hotspot/behavior/same-scene gate; scope is cleanup and verification, not speculative optimization.

## 4. Final acceptance and delivery

Use smallest affected current tests (e.g. commit/crew/income/snapshot and Lab/generator identity checks) as determined by actual edits, not a directory-wide suite. Check supported entry closure and current guide commands. Finish the actual candidate main/Presented save-reopen entry, F8/F9/portable paths that changed, admitted native subset and the existing release portability path when packaging/entry behavior changes. Reuse the proven editor/template/DLL and original verify_release.gd; no new installation or test platform.

Evidence and timings remain under ignored test/work; compact current findings and responsibility exits go in the task entry. Final candidate goes to the same dot/high pair; no S5 main merge before both agree. Necessary current code/tests/docs only are eligible for later main delivery.

## Constraints and stop conditions

Preserve the approved S2 freezing boundary (not arbitrary interruption recovery), all GrowthNumber discard semantics, and explicit Lab/native support limits. No new gameplay, timing/target/damage rules, refunds, exact ledger, save schema, old-result compatibility, capability registry or experimental framework. If a live responsibility or semantic mismatch cannot be resolved within those constraints, isolate and report it while continuing independent inventory. Final implementation still requires the existing dot/high review before any main merge.

## S5 implementation checkpoint (pending measurements / final review)

- Runtime: remove Crew.on_event, its attach connection and install disconnect; remove Game.resource_minute_total. Four tracked-crew fixtures now attach without empty UI wiring. Opening feedback and state-ownership checks call IncomeHistory.display_total explicitly.
- Existing harnesses: whole_game_perf stages an optional historical/current configuration manifest and refuses reuse across source-byte fingerprints; records actual work before/after measurement. Growth performance now runs the actual Runner without a shadow MeasuredGame/old scientist fields. F9 speed has bounded opt-in candidate/result counts and separate setup/CPU/wall records. No production numerical or timing semantics changed.
- ARCHITECTURE contains the eight-entry closure/retirement table, evidence reuse reasons, support limits and the existing extra-storage cross-domain example. BALANCE_PERFORMANCE and the performance guide distinguish unknown identity and historical fixtures.
- Current affected checks: commit boundary 131/0, state ownership 1230/0, opening feedback 21/0. Initial opening run timed out at the retired invalidate_stat_cache fixture call; replaced with notify_configuration_changed. Initial material economy test 156/1: transient per-instance configuration was assumed to survive S3 replacement. Formula cases remain; restoration now tests the captured published configuration. Recheck pending.
- Initial F9 benchmark generation timed out at 120 s; not reported as performance evidence. The opt-in small workload uses the existing runner regression's first-enemy/1-2 ship/module-level-10 setup. Same-input before/after timing and final actual entry remain pending.
- Logs and raw measurements remain ignored under test/work. No main merge, no overall S5 pass claimed. Two historical formation compatibility failures remain outside scope.
