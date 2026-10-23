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
