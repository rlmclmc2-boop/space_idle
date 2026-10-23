# Architecture S4 — execution contracts and identity

## Entry and authority

Same executor task; scope preparation only. No S4 production changes or new audit thread.
Base/main: `4acfc04b90491cdf98fdee6e535be136647c150b`.
Approved S3 candidate: `cf9a1dd3ab42f278f36e5af6933fd80cb804db17` (dot + independent high agreed).
Prior full task history remains at that candidate, this same path.
Original approved plan: `d08f24e8344b5e0f7068b449005187c44ae122de:space-battleship/docs/GLOBAL_ARCHITECTURE_PLAN.md`, sections 6, 8, 9/S4 and responsibility-exit table.
Branch: `work/architecture-s4-scope-20261024`, based on delivered main to keep historical evidence out of later delivery.

## S3 delivery completed

Normal push and remote readback confirmed main `4acfc04b90491cdf98fdee6e535be136647c150b`.
65 selected files: runtime, configuration capture/publication and build consumers, current reusable tests and documentation.
Excluded task documents, evidence and temporary outputs. Kept main's correct S2 progression guide and reconciled ARCHITECTURE's S2 paragraphs with approved S3 boundaries.
All 356 production blobs in scripts/tools/data/config_excel plus manifest/export settings match the approved candidate. All 23 manifest members match working and committed bytes (size and SHA-256).
Actual filtered delivery entry: `test/work/test_ordinary_entry-svt4ai8g`, 8 phases, 151 checks, 0 failures; restored-domain mismatch lists empty. The intentional configuration-corruption case emits the expected generation mismatch. Windows certificate-store diagnostic remains known.
Command: `python test/run.py test_ordinary_entry.gd --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe --timeout 240 --scenario all`.
Earlier S3 acceptance and evidence remain on the approved review branch; they are not additional main files.

Known baseline failures remain disclosed: old formation policy reuse and legacy formation snapshot execution. Both reproduced on S2 main `a1b31ce166d73e9a00f8d457dc4fe9cea2a0413c`. S3 does not claim the entire formation suite passes or introduce historical formation compatibility.

S3 old responsibilities exited: lifecycle readiness alone no longer establishes imported-target success; actual installed source/target and writer ownership do. Session installation uses the actual game subtype and retires old session state. Runtime, F9, Lab and builders consume captured configuration; implicit source-neighbor reads and postcommit public rereads no longer determine results. Native compiler and low-level workbook/IO validation remain their existing owners.

## S4 implementation slices to review

### 1. Lab number and research ownership

Start with `scripts/balance_game.gd` slot_stat/jewel_attack, research_rate/active_research/advance_hightech and metrics; `scripts/player_loadout_generator.gd` upgraded_profile and start_validated_battle; follow actual callers into Game/Research.
Replace legacy hightechLevels/scientistAssignments/techPoints assumptions with the current Research owner, preserving research advancement and established scheduling.
Audit attack, armour/shield, cost/balance, rewards and aggregated metrics for float coercion. Use existing GrowthNumber and shared contribution/rule owners for large quantities; unsupported inputs must be rejected before lossy coercion. Positions, time and finite simulation scalars stay finite where appropriate.
Do not create exact bookkeeping, residual compensation or a second numeric system.

### 2. Explicit execution capability

PresentedBattleGame remains the formal model. BalanceGame exact is its declared Lab model, not a promise of formal movement equivalence. Fast has an explicit model/version and cannot silently switch modes.
Start with `scripts/native_execution_compiler.gd` compile/native_scalar/native_fields/native_integer and actual runner entrypoints. Native compiler remains the authoritative native support check; the common capability result wraps it, without a parallel set of gameplay rules.
Declare existing supported capabilities and evaluate on input/config changes, not every combat iteration. Unknown/unsupported capability must explicitly reject or use a proven safe formal handoff; no partial native/shared coexistence. Do not add native capabilities merely to widen coverage.

### 3. Actual experiment identity and consumers

Start with `balance_runner.gd` start, `player_loadout_generator.gd` config_fingerprint/replay, `fleet_battle_runner.gd` input construction/retest, `fleet_batch_retest.gd` merge, `fleet_result_analyzer.gd` report, and `fleet_level_generator.gd` output metadata. Trace actual F8/F9 and standalone analyzer entrypoints plus existing build provenance.
Replace incomplete data-only hashes and scattered model labels with one identity construction for actual rule-source contents (including dirty edits), captured data identity, model/capability/numeric versions, engine, native binary hash and applicable source/toolchain provenance, seed and time parameters. Compute once per batch. Pure visual assets must not unnecessarily invalidate combat identity.
External workbook identity includes its stable captured bytes and transformed data. Reuse S3 capture and entry mapping; ordinary reports are not configuration transactions.
Old reports remain readable; missing identity is explicitly unknown. Retests/comparisons expose mismatches and do not equate unknown with current identity. No new old-save or historical formation compatibility promise.
Build provenance does not prove native correctness; preserve actual native admission checks.

## Required responsibility exits

| Old responsibility | Single owner after S4 | Remaining consumers to close |
|---|---|---|
| Lab float economic/stat arithmetic and obsolete research field assumptions | Existing GrowthNumber/contribution/Research rules | Lab setup, progression, metrics and player loadouts |
| Implicit exact/fast/inheritance support assumptions | Common capability result backed by actual model/native checks | F8/F9, batch runners, native handoff, standalone Lab |
| Data-only fingerprints and independently assembled experiment labels | Common execution identity from captured inputs and actual implementation | Reports, retests, merge, generators and build provenance |

For each implementation commit record exact removed/delegated symbols, all live consumers and validation. No parallel rule owner or indefinite compatibility bridge. S5 later checks remaining dead bridges and full documentation; S4 does not absorb all S5 work.

## Acceptance and limits

Reuse current public tests, adding focused assertions for supported and explicitly rejected inputs, quantities beyond float range, current Research advancement, dirty rule/config/model identity changes, missing identity and batch capture stability. Cover actual F8/F9, portable Lab, report/retest and native supported subset; then verify actual main entry for the candidate.
Track the two old formation failures separately. If current product execution needs correction, prove it from the current path; do not widen compatibility merely to satisfy obsolete assertions.
No global simulator equivalence or new performance guarantee. No changes to gameplay eligibility, research timing, strategy defaults, save schema or numerical accuracy policy without a concrete separately reviewed decision.
User decisions persist: all large-number algorithms use existing large-number semantics and discard out-of-precision quantities; eligible native battlefield pickups include enemy drops and timed top resource blocks, excluding derived income.
Parent coordinates dot + existing independent high. S4 implementation candidates must obtain both approvals before main integration. This scope-only commit has no gameplay/runtime changes and needs no additional game test.

## S4 checkpoint 1 — Lab adapters and current Research

WIP production slice, not S4 completion; main remains 4acfc04b. Parent confirmed high accepts the S4 scope. Further admission must also re-evaluate on existing versions when equipment/research/growth changes during execution; batch identity must capture actual executed contents before running, not reread after. Comparison, retest and merge need their own explicit allowed-difference rules, with unknown never equal by default.

Changed: BalanceGame stat/attack multipliers and raw projectile adapter preserve GrowthNumber; private loadout upgrade funding uses GrowthNumber.subtract. Autoplayer weapon estimates, gain/cost scoring and defence comparison use the same algorithms. Lab automatic research retains active selection, otherwise calls the current Research.shortest_available and select_tech; no new research priority formula or input policy. The old random-strategy draw is retained to preserve its RNG cadence.

Exited: BalanceGame research_scope/rates/active and its advance_hightech override, skip_empty_batch_research and fleet setter, unused scientist metrics override, performance references to the deleted caches. The shared Game/Research advance path owns progression. Autoplayer scientist purchase/distribution and old hightech-table iteration are removed; current Research owns eligibility and selection. Existing stale cache assertions/skip-only test are removed or replaced, not retained as compatibility requirements.

Validation: existing test_balance_database.gd extended with current Research, real Lab policy, large attribute/attack/raw projectile and large-balance upgrade fixtures. 144 checks / 0 failures, headless Godot 4.7.2, isolated fixture test/work/test_balance_database-v1_cwbfm, s4-adapter.log. Production files were copied byte-for-byte to this fixture before execution. The final test was rerun in its imported isolated project. Earlier failed attempts exposed a duplicate test variable, obsolete jewel-table assertion and attempts to mutate read-only equipment views; final fixtures use Equipment.install_snapshot. A test requesting 6000 upgrades exceeded current equipment caps; replaced with supported one-level upgrade from a large wallet, without widening gameplay caps. Those failed/time-out runs are not acceptance.

Not claimed: full metrics/fleet legacy suites pass (only affected references updated); large quantities through metrics/report/analysis are not yet closed. Still required: metrics/timeline/report and actual F8/F9/periodic/standalone consumers, capability/version admission, actual-content identity and build/retest/merge consumers, actual entry validation and dual review. No damage timing change or new performance claim.

## S4 checkpoint 2 — metric collection (still WIP)

BalanceGame metric capture, BalanceMetrics and BalanceTimeline now preserve shared large quantities for damage, defence, spending, income, DPS and samples. Ratios use GrowthNumber.ratio, no precision compensation. Timeline research discovery reads current ai_tech_tree eligibility. This is collection and per-run metric projection only: BalanceReport aggregate/sensitivity, BalanceAnalyzer, comparison and UI consumers are NOT yet migrated and must not be labelled end-to-end large-number support.

Validation: extended the same existing database test; final isolated s4-metrics.log reports 149 checks / 0 failures with no script errors. Covers large metric income/DPS/shares/minimum health/timeline and a real large player hit. Both checkpoints' production scripts were copied into the imported isolated project. Full legacy metric/fleet suites were not claimed.

New proven capability boundary for the next slice: synthetic large enemy HP reaches existing Game.hit_enemy scalar HP comparison, then settle_enemy_shield's float HP guard. A probe emitted script errors despite its test's final assertion count; correctly rejected as validation. Exploratory Game comparison edits were reverted. No shared combat timing/settlement changes are part of this checkpoint. Current Lab admission must explicitly reject this unsupported enemy-state range before execution (and recheck version-driven runtime changes), or separately prove support without changing timing; do not assume adapter/metric GrowthNumber support proves the combat model supports every quantity.

Next work remains: report/analysis numerical consumers and truthful unsupported results, shared capability results and existing-version admission, immutable actual execution identity, F8/F9/periodic/standalone/build/retest/merge closure and end-to-end tests. Main untouched. The two known old formation failures remain baseline failures.

## S4 checkpoint 3 — reports and research spending

Environment reconnected in this same task; read-only Git check confirmed ad08e7df and clean state before continuing. No replacement environment/task.

BalanceReport aggregation now treats GrowthNumber as one metric (not separate m/e paths), uses shared arithmetic for mean/variance and preserves quantity CSV values. BalanceAnalyzer comparisons, baseline loading/comparison and F8 text/table display accept large quantities. Signed finite report derivatives outside their range return explicit unavailable metadata rather than silently coercing a dictionary. No new precision representation/compensation. Current arithmetic/ordinary signed fields keep their existing meaning.

High feedback addressed: Lab-specific ProgressRuntime subclass calls the existing research commit implementation and records proposal wallet differences only after a committed result; UI throttle is irrelevant and rejected proposals add no spend. No second research progression algorithm. Scientist metrics/idle warnings exited. Per-run/combined reports explicitly label damage_basis=enemy_hp_removed_excluding_shield. This documents existing HP-only accounting, not a change to combat damage.

Existing test_balance_database now reports 166 checks / 0 failures, s4-report.log in the same isolated fixture. Added real one-second F8 Runner completion, large aggregation/stddev, CSV, baseline roundtrip, view formatting, real research spending with UI throttled and rejected stale proposal. Final run has no script errors. Earlier parse failure from editing the obsolete scientist decision-map key was fixed before this result.

Remaining S4: capability admission (including finite HP + large max_shield) and runtime version re-evaluation; immutable actual-content batch identity; F9/cycle/portable/build/retest/merge consumers; full actual-entry acceptance and dual review. Formal game has not been restricted or rewritten. The existing shared finite enemy-shield limitation still requires explicit Lab rejection and separate actual formal-impact accounting.

## S4 checkpoint 4 — explicit Lab admission (identity still pending)

Connection confirmation: exec_command read-only status/rev-parse/task-entry read succeeded with exit 0 at ad08e7df; worktree was clean. Environment is restored; checkpoint 3 was subsequently committed/pushed as 2f4efcb33d3fe1dcc48f9fedd611ddb2fbd79daf.

ExecutionContract declares existing Lab exact/fast and numeric version, rejects unknown models, checks current enemy HP/max HP/shield/max shield before unsupported scalar paths, and validates encounter source/projection before spawn. Lab admission is invalidated by existing configuration inputs and enhancement counters; _tick_combat_step rechecks after shared research/equipment work in the same tick. Failure becomes explicit F8 error without counting the rejected step and F9 error results; no implicit fallback. Fleet HP ratios now consume shared large player quantities. Native compiler access points delegate through the same contract to the original compiler, without duplicated capability rules or altered native lifecycle.

Validation: same existing test now 172 checks / 0 failures, s4-admission.log, no script errors. Includes current normal F8 run, unknown mode, large HP, finite HP with large max shield, actual runtime configuration-version rejection with zero consumed runner steps, and source shield rejection before construction. Native end-to-end acceptance and actual F9/portable entry verification remain pending; wrapper delegation alone is not their acceptance.

Formal impact: no new restriction applied to PresentedBattleGame. Only native compiler call access is delegated unchanged. Existing Game/ShipDatabase enemy capacity and shield settlement use finite scalar values, so manually supplied large enemy HP/max_shield were already unsupported; Lab now reports that boundary instead of crashing. This does not prove all authored configuration ranges or native cases; retain actual-entry regression as a gate. No timing/target/damage rewrite.

Remaining: immutable execution identity from actual loaded rule contents and captured data, external workbook provenance, explicit compare/retest/merge difference policy, builders and all F8/F9/cycle/standalone consumers; finish actual-entry and native verification; dual review before main. No S4 completion claim.

## S4 checkpoint 5 - batch identity and rejected-result consumers

High P2 fixes: BalanceGame.start no longer clears spawn rejection from super.start(checkpoint). Baseline loading remains a successful load operation, but an admission-error result has comparison compatible=false/no_comparable_report instead of accessing missing config/summary.

F8/F9 capture loaded GDScript contents, retained dependency resources, actual private database input, auxiliary captured configuration, model/capability/numeric/engine and parameters before execution. Disk edits after capture do not relabel a batch; dirty loaded implementation changes identity. Unknown source/model identity is not equal. Comparison explicitly allows disclosed configuration differences; retest and merge require compatible execution and physical settings. F9 validators now use batch-private data. Merged outputs retain constituent batch identities. F9 retest UI uses original mode/duration.

JSON parsing demonstrably changes some double tail bits. F9 retains its actual input arrays using built-in Marshalls Variant serialization (objects disabled on decode), and retest executes that snapshot. Identity metadata represents nonintegral floats using standard Variant bytes. This is serialization only: no accounting precision, numeric algorithm, compensation, or combat timing change. Human-readable JSON views remain. Published workbook origin is captured by its bytes hash.

Validation: existing test_balance_database, isolated imported project, 191 checks / 0 failures, no script errors; s4-identity.log. Covers both P2 paths, F8, F9 actual batch, loaded/disk source differences, unknown/change refusal, persisted identity, actual followup and combine. Earlier serialization mismatches and parser failures were observed and fixed before this result. Root certificate-store diagnostic remains environment-only.

Remaining S4: generator fingerprints and existing-pair reuse admission; fleet/cycle generated outputs; portable/build provenance and native actual-entry acceptance. Source-less exported scripts currently yield unknown, not fabricated source identity. This is a production checkpoint, not full S4 completion or authorization to merge main. Existing two formation baseline failures unchanged.

## S4 review candidate - generator and entry closure

Production checkpoint: 2bfb8e1a (following pushed d05887d464f8d9e2da1125ffa7ac01bd5aad010f). Main remains unchanged. Await dot + existing independent high; no substitute audit/task.

Closed consumers: player/enemy generator fingerprints include loaded rules; player scoring uses existing GrowthNumber operations and unchanged formulas, enemy scalar scoring explicitly refuses unsupported quantities. Fleet auto-level copies its database, admits old measured pairs through the same Runner identity capture/compare, and retains actual supplement identities. Cycle generation captures input/rules at execution; Excel has a workbook-hash-linked execution metadata companion. Analysis preserves merged batch identities and accurately labels player armor+shield versus enemy HP-only ratios. Builders record actual staged bytes; portable runtime engine hash is also part of batch identity. No new capability registry or experiment framework.

Responsibility exits: data-only generator fingerprints no longer establish execution equivalence; source rereading after a run does not name its implementation; blind old-pair reuse and unknown-identity equality are retired. F8/F9 use ExecutionIdentity for identity policy and ExecutionContract for Lab admission/native compiler access. Research progression stays in the shared implementation; Lab observes successful spend only. Player quantity scoring no longer owns float-only arithmetic. Native compiler remains the existing sole rule authority. Public contract updated in docs/BALANCE_LAB.md.

Validation completed:
- test_balance_database: 194 checks / 0 failures, final s4-final-identity.log, 26.86 seconds. Includes both high P2s, actual F8/F9, persisted replay/merge, source identity, large player generation and rejected large enemy source. No script errors.
- test_fleet_level_generator: 0 failures. Initial 60-second run timed out; diagnostic 120-second allowance completed successfully. Retain timeout as an observation, not a performance claim.
- test_analyzer_dependencies: 5 / 0. Initial introspection regex was mistaken for a packaged file path by static closure scanning; prefix construction corrected before pass.
- Built actual portable package test/work/s4-portable-identity-04, imported successfully. All 78 staged script hashes plus engine hash verified against execution-provenance.json. Actual standalone test: 0 failures, 10461 workbook enemies, two fleets to one multiencounter level, cycle identity/Excel companion, deliberate startup rejection cases. Expected invalid-input diagnostics occur; no SCRIPT ERROR.
- Actual main: test_ordinary_entry-onedks5b, all 8 phases / 151 checks / 0 failures. The configuration_generation_mismatch in planet-loading is its deliberate corruption case. Later edits affect Lab consumers/build metadata, not the shared formal-runtime paths validated here.
- Native supported subset: test_dynamic_native_ports-bm3bvn0h, 5717 checks / 0 failures. Actual binary SHA256 4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f. No native timing/capability expansion.

Limits: full Windows release export was not invoked in this checkout because its expected engine executable, release template and bin/space_native.dll are absent. build_release.ps1 parses successfully; portable build and actual main/native entry validation above are completed. The release provenance records prebuilt native source/toolchain as unknown; compiled source-less Lab identity is unknown, never inferred from working-tree files. No new model-equivalence or performance guarantee. Two previously known formation compatibility failures remain recorded; no legacy bridge added to satisfy them. Test work/products remain local ignored artifacts, not main deliverables.
