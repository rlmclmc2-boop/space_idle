# architecture-s2-boundaries

- Entry: d08f24e8344b5e0f7068b449005187c44ae122de:docs/GLOBAL_ARCHITECTURE_PLAN.md section 12. Base: c3cdf98e5e6fdd8b0e2dba507d840b796ead0bc7. Branch: work/architecture-s2-boundaries-20261024. Candidate only; no main merge. Parent coordinates independent high, whose scope approval was relayed; no new reviewer agent.
- Preserve personal saves/unrelated work. No refunds, cross-process continuation, schema migration or new testing framework. Existing rules proceed without asking again; only actual conflicts are escalated. Compaction requires a Git handoff and stop.
- Scope inventory gap resolved by reading current Game/Progress/Galaxy/Hyperspace writers, direct script consumers, owner APIs and snapshot call sites. Below records current boundaries before changing them. It does not classify every battle entity mutation as a persistent command.

## Public writer / consumer / failure inventory

| Entry / owner | Actual runtime consumers | Smallest install and failure / continuation boundary |
|---|---|---|
| Game equipment/loadout/hull; Progress crew/planet/research commands | equipment_tab, ship_panel, main, crew_panel, galaxy_panel, planet_panel, crew_system; balance_autoplayer, player_loadout_generator | S1 result boundary already installed. Reuse it; planet/research time wrappers still discard blocked status and have no stable per-step item cursor. |
| Game upgrade_reactor, set_reactor_allocation, equalize_reactor_allocation | reactor_panel, crew_system, balance_autoplayer, BalanceGame wrappers | Native handoff can callback; purchase then wallet debit + reactor install; allocation follows prepared proposal. Remaining completion/event handling still local. |
| Game upgrade_enhancement/set_enhancement_order/set_enhancement_branch | enhancement_panel, crew_system, balance_autoplayer, BalanceGame wrappers | Currency + growth configuration; native handoff precedes install. Combat counters are separate execution-owned writes, not purchase commands. |
| Game start_galaxy; galaxy_runtime refresh_unlocks/advance/flush_pending/publish | galaxy_panel, Progress assignment flush, Game shared phase, native preparation | Income credit and income-time retirement precede callbacks. Multi-region add_pending/flush can fail after earlier regions commit. native_refit caches session/proposal; stale-context recheck is required on resume. block currently writes native flags + pauses. |
| hyperspace_runtime start/complete/claim/start_idle/stop_idle/set_auto/start_auto/complete_auto | Game facades, hyperspace_manual_session, hyperspace_commands, _advance bounded auto loop | Receipt/state + optional material wallet. Current commit validates owner/wallet around handoff, then installs; capacity reconciliation currently follows configuration publication. `_advance` owns pending_time but command notification happens before caller-loop continuation is finalized. |
| hyperspace_runtime set_equipped/equip_drone/unequip_drone, attach_hangings, set_favorites, set_preset/clear_preset/apply_preset, remove_unprotected/claim_sealed, set_filter/import_filter, set_legendary_collection, forge/exchange_materials | hyperspace_equipment_ui, hyperspace_panel, hyperspace_commands, Game exchange facade | All converge through commit. No new algorithm needed; migrate one common completion owner and retain existing result wrappers/plan algorithms. Reforge and interrupted-load policy remain lifecycle scope. |
| Game collect/settle_jewel_fragments/pickup_jewel_fragment; Galaxy income | Game automatic collection, main pointer collection, auto_gen, BalanceGame fragment override, Galaxy shared phase | Drop erasure / wallet credit / sample append / peak update / callbacks are currently separate. Their minimum unit must be fixed before returning retained work; resource origin/time/value qualification must not be silently changed. |
| Progress refresh_factory_inputs | Game shared phase | Owner advances interval and refreshes inputs; no returned consumed interval. Must occupy a specific shared-stage position, not be replayed after later failure. |
| Game consume_external_time/prepare_logical_step/tick; Presented _tick_logical_step; native session advance/handoff/cancel | main._process/capture path, original main scene, BattleSliceRuntime before/after, BalanceGame tick and analysis runners | External chrono debit precedes dispatched float budget. Shared progress precedes combat; Presented has local remaining and due-missile substeps. Native advance may fail before combat, but feedback after success can callback. Phase identity must move before notification. Existing phase/remaining/cancelled compensation must be replaced, not mirrored. |
| save_progress/_build_save_data/portable_save_data | timed/manual save, main, hyperspace_reward_feedback; SaveTransfer export/import backup; fleet_battle_runner and player_loadout_generator | Gate all persisted/exported/full replacement snapshots at complete shared steps. `_compose_save_data` alone is not an adequate gate if callers bypass it. UI read-only projections are not persistence snapshots. |
| load_progress_data, Progress install_loaded_domains/reforge_planet; Game reset/load/read markers | boot, SaveTransfer/main import, player_loadout_generator private fixtures | Full lifecycle remains S3, but S2 entry gate must reject/defer replacement while a shared step is incomplete. Read/unread UI markers are separate from economic configuration and must be classified explicitly. |
| Direct owner installs outside coordinators | main capture economy restore; player_loadout_generator private loadout/economy construction | Capture rollback must not overwrite a partial step. Private generator initialization is not a live user command but its final portable snapshot must respect the same readiness boundary. |

## Shared-time ordering and failure facts

Current shared order is manual time, productionElapsed, Hyperspace, legacy weapon effects, planets, Galaxy, crew, auto_gen, research, ordinary drop aging/collection, factory refresh. Preserve this ordering. Game then runs combat; Presented divides legacy work by 1/60 and missile due times. Native `kernel.advance` success retires combat before feedback, while a failed handoff retains native ownership. Galaxy block/cancel currently uses `blocked_shared_step` and `native_cancelled_step`, so simply retrying tick would replay already committed shared work.

S2 must keep stable item lists and a single authoritative stage/substep position, finalize installation and position before notification, detect invalidated blocked context, and release continuation records on completion. Complete-step snapshot gating includes manual/timed save, export, import backup, offline load composition, capture and tool-generated snapshots. No additional time ledger or process-restart promise.

## Income and decision boundary

Actual writers are collect, fragment settlement and Galaxy income; load/clear are restoration paths. Queries are HUD real-time resource_minute_total, production-minute filtered totals, research game-minute inputs and income_peak_proposal; save/export and balance diagnostics also consume the history. One bounded owner must retain the distinct coordinates/amount fields needed by these existing queries. Compatibility migration is not proof that source qualification is correct.

Existing completion truncation and inactive-work policies are not automatically changed into backlog/rewards. If an actual conflict is found, report current behavior, impact and recommendation to parent; do not reopen settled rules merely because section 12 listed a verification question.

## Implementation status

Inventory established; implementation begins with cold Hyperspace command completion, independent of time remainder or income-qualification decisions. No S2 acceptance claimed yet. Later units still require shared-step, per-domain cursor, snapshot and income closure plus failure evidence.

## Previous compaction handoff — unvalidated WIP at ab825e29

Implementation stopped on context compaction as instructed. The candidate changes only this inventory and `scripts/hyperspace_runtime.gd`; it is not ready for acceptance or main merge. Independent high approved the section 12 scope, not this implementation.

The runtime WIP adds `commit_result` with the existing bool `commit` wrapper, rejects active commits, detaches/freezes the proposal, validates owner/wallet/configuration around native handoff, and routes completion through CommitEffects. Reactor capacity reconciliation now precedes configuration publication. Results report actual wallet changes; existing resource notifications retain credited-only material IDs. These changes have not been imported, syntax-checked, or gameplay-tested. No S2 test result exists; diff hygiene is not correctness validation.

Next executor should inspect this exact diff and the current CommandResult/CommitEffects contracts before validating Hyperspace command failures and callbacks. Continue section 12 with authoritative shared-step progress, stable domain cursors, invalidated blocked contexts, all snapshot gates, and the single income-history owner; none of those remaining units is implemented here. Reuse existing boundary tests, without a new test framework. `test_hyperspace_material_economy.gd` has current owner fixtures and handoff fakes; inspect it before selection. The guide-mentioned `test_hyperspace_manual.gd` is absent, and `test_hyperspace_player_feedback.gd` uses stale profile fixtures.

Legacy `test_time_steps.gd` remains unresolved from S1 (206 checks, one failure, plus missing `Runtime.detach_requested` and nil `screen_mount_for_slot` errors); do not count it as passed or as fixed by this WIP. Protect personal saves and cache, use isolated test storage, and deliver by normal candidate branch push only. No main changes are authorized for S2.

## Continuation: cold command completion and income ownership

Exact starting candidate was ab825e293e32c9c888a2cadcd1253e3f13390bbe. The previous Hyperspace WIP now imports and passes the material-economy test, including added assertions for detached proposal envelopes, configuration invalidation across handoff, one scheduling fact before immutable UI notices, rejected command/time reentry, and stale replay without another debit/notification.

Reactor purchase/allocation/equalization and enhancement purchase/order/branch now have full result methods. They reject active commits, recheck configuration after handoff (and wallet revision for purchases), install without callbacks, and delegate dirty/scheduling/notices to CommitEffects. Existing bool/int UI and BalanceGame wrappers derive their answer from the full result; pricing, health clamping, branch reconciliation and purchased-count behavior are unchanged. Equalization retains its existing scheduler dependency update rather than starting another allocation cycle.

IncomeHistory now owns the one receipt array, detached recording/reads, current-schema restore/export, rolling retention and named display/peak/research/production queries. All production script writers and consumers moved; old Game query methods are stateless forwards only. The retention predicate still preserves facts live on either existing 60-second coordinate, with the existing periodic pruning cadence. Source qualification, base versus credited amount and all existing window semantics are preserved. This extraction does NOT yet make collection/peak/native preparation atomic, and does not fix the unresolved income-qualification gameplay question.

| Old responsibility | New sole owner / retained consumers | Exit in this candidate |
|---|---|---|
| Hyperspace local dirty/resource/UI completion | commit_result -> CommitEffects; existing command facades remain | Old local completion removed in ab825e29, now exercised |
| Game six reactor/enhancement command completion sequences | *_result -> CommitEffects; panels/crew/BalanceGame still call value wrappers | Local dirty/scheduling/event sequences replaced, no second implementation |
| crew.on_event reactor level/equalization business branches | crew.on_committed reactor facts, including equalized dependency semantics | Reactor UI-event bridge deleted; income/currency/unlock bridge remains pending its writer migration |
| Game.resource_samples and Main mutable projection | IncomeHistory; actual runtime, restore/export, diagnostics and fixture consumers migrated | Both old array properties deleted; no dual writes |
| Game filtering/cropping query algorithms | IncomeHistory named queries | Game functions only forward; AI/Galaxy/HUD call purpose-specific owner methods |

Verification uses Godot 4.7.2 at `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe`, existing `python test/run.py <file> --godot <path> --timeout 300`, isolated project/user directories. Completed: material economy 144/0, commit boundary 54/0, reactor 39/0, enhancement cost 53/0, AI tech tree 142/0. Logic tests used `--headless`; original-main rendering workflow is pending. A first new branch-choice fixture at level 20 failed after order reversal moved its threshold to 30; it was corrected to level 40, preserving all assertions, and the complete boundary test passed. Certificate warnings and ObjectDB/resource exit warnings are present in some logs; they are not hidden or counted as assertion success.

Still outstanding for full S2: collection/fragment/peak joint receipt completion, Galaxy public completion and native cached-context invalidation, removal of remaining crew UI business bridge, single paid-budget/StepProgress owner, per-domain stable cursors and retirement-before-notification, Hyperspace retained/drain distinction, every snapshot/replacement gate and capture/tool consumers, required native/script failure matrix, legacy time fixture repairs and comparable performance evidence. No time fields/cancellation compensation were replaced in this continuation. Do not present these partial units or the original-main smoke test as S2 acceptance. Independent high remains parent-coordinated.

Original-main validation completed on the runtime tree committed as 7359286e: 128 checks, zero failures across all eight phases (16/26/18/7/25/8/20/8), with no domain differences after reopening. Product-save and factory-reopen screenshots were inspected. Raw completed test logs are in `test/evidence/architecture-s2-cold-income/`; earlier cold-command tests preceded the income extraction, while AI tech and original-main ran with the extraction installed. No standalone stale UI fixture or legacy time test is represented as passed.

Income precision decision is CLOSED by the user's later instruction: all large-number algorithms use the existing GrowthNumber operations and discard amounts outside their precision; no exact-difference accounting, tail compensation or separate precision mechanism. The continuation below applies this to fragments and income. The earlier recommendation to derive income from balance differences is withdrawn.


## Compaction handoff: shared-step WIP (2026-10-24)

Implementation stopped on context compaction as explicitly required. This branch is `work/architecture-s2-step-wip-20261024`, separate from the reviewable cold-command candidate. Its history starts with d83155a7 and includes 26517f23 (the Galaxy review correction, equivalent to candidate b59ed5cc). The current handoff commit preserves subsequent incomplete work; it is NOT merge-ready or S2 acceptance.

Historical clarification at that handoff preserved computed earned amounts. The later, now final user instruction is project-wide reuse of existing big-number arithmetic, with precision-external amounts discarded and no exact bookkeeping. See the current continuation; this is no longer a pending decision.

StepProgress now replaces production `game_time_remainder`, `native_step_phase`, `native_step_remaining`, `native_cancelled_step` and native `blocked_shared_step`. It owns paid budget segments, one reserved interval, shared/combat phases, substep and stable item cursors, and blocked/frozen context. Presented substeps and native completion retirement use this record. Shared order is preserved. Galaxy, planet, research and Hyperspace paths have partial acceptance/retirement markers; direct domain calls use scopes on the same record. Save/export/import/load/capture and BalanceGame consumers have initial complete-step gates. These are implementation intentions, not verified guarantees.

Required next work, before claiming closure:
- Audit cancellation, retreat, start/reset and native ownership release: some callers can clear a session after cancel freezes an incomplete interval. Prove failed native advance has no partial kernel mutation.
- Close direct domain retry scope/context validation and reason clearing, especially Hyperspace and planets/research. Review Galaxy block assumptions, native cache context and callback-mutated region references.
- Complete ordinary collection/fragment/peak atomic receipt boundaries and remaining crew UI business bridges. Preserve computed-earned semantics.
- Audit snapshot/tool/lifecycle consumers and all partial shared/combat failure paths (including jewel repair); no hidden discard, replay or double charge.
- Migrate existing tests that still refer to removed fields. `test_time_steps.gd` has pre-existing Runtime.detach_requested and screen_mount_for_slot fixture failures; repair current production seams without deleting assertions. GameProbe must retire the real StepProgress path. Adapt native blocked-transfer cancellation assertions to retained/frozen work, not old discard compensation. Include reserved interval plus undispatched segments in conservation assertions.
- Run targeted shared/native/failure/snapshot tests, then required performance comparison. No expanded testing or standalone reviewer was started.

Only an EARLY intermediate time tree passed AI tech 142/0 (`test/work/test_ai_tech_tree-1fnha6j9/test.log`); subsequent domain and consumer edits were not imported or tested. Do not attribute that pass to the final WIP. No final WIP correctness, syntax or performance claim. No main merge; independent high remains parent-coordinated.


## Current continuation — 2026-10-24, from 6abcea2f (validation in progress)

Same branch and same task; local isolated checkout is `task-4/s2`. Git acquisition was resolved from the preceding task's object store; HEAD was checked against the exact requested commit. No original player checkout, save or main branch was changed. Remote branch readback still showed 6abcea2f before delivery. Independent high remains parent-coordinated; no reviewer task was opened.

Final numeric direction: **all project large-number algorithms reuse GrowthNumber; precision-external small amounts are discarded, without exact differences, tail compensation, or a special precision ledger.** Fragment credit now uses the same N.add path as other resources, removing the extra 0.01 balance snap. Income queries continue N.add/N.divide on computed earned receipts, never reconstructing credit by subtracting large balances. Source qualification and existing windows are unchanged. Exact bounded integer material quantities remain the existing material domain contract, not a new large-number accounting mechanism.

### Responsibility exits in this continuation

| Prior responsibility | Sole completion owner and consumer change |
|---|---|
| collect/fragment drop erase, wallet credit, history append, peak handoff and UI split | `Game.commit_income_receipt` prepares peak before native transfer, revalidates configuration/wallet/receipt, installs all owners synchronously, retires a shared collection item, then CommitEffects schedules and publishes. Failed preparation leaves the drop and all receipt owners unchanged. `collect`, `settle_jewel_fragments`, pickup remain value facades. |
| BalanceGame fragment override depended on one particular caller | Metrics consume successful receipt completion, including collected fragment drops, exactly once. |
| crew UI-event business bridge | `on_event` is a stateless compatibility no-op; resources/currency/unlocks and lifecycle completion send committed facts directly. No UI event schedules work. |
| Galaxy start/unlock local dirty/notices; unqualified native cache reuse | Start/unlock completion uses CommitEffects. Cached preparation is qualified by session, duration, region revision and configuration. Region installation retires its cursor before map/UI publication. |
| factory input refresh local notification | Lightweight CommitEffects progress completion; shared stage is retired before notification. |
| direct planet/research/Hyperspace replay and uncleared blocked reason | Same StepProgress validates context, freezes invalidated context, drains the reserved interval, and rejects mismatched phases. Hyperspace completed-count retirement precedes its completion notices. |
| native cancel caller always clearing session | Cancel reports success; failure freezes incomplete work and retains owner, kernel and paid interval. Start/reset reject incomplete external replacement. Existing automatic clear-to-next-stage transition stays inside its executing combat stage. |
| auto/drop iteration replay after income preparation failure | Stable item list and item movement/aging marker; receipt and item retirement precede notification. Failed item resumes without adding age/time twice. |
| partial save/load/export/capture/tool results | Complete-step gate covers save composers, portable/export/import backup, load/load_hightech/load_journey, reforge, capture, and private tool final snapshots; fleet validation reports an incomplete snapshot rather than accepting an empty profile. UI read markers remain non-economic projections. |

`StepProgress` remains the only paid-budget / reserved-step / substep / stage / item position. Production no longer references game_time_remainder, native_step_phase, native_step_remaining, native_cancelled_step or blocked_shared_step. Source segments are released on completion; frozen work is retained, not refunded, serialized or silently abandoned.

Native failure basis: `combat_execution_kernel.h::advance` has its only false return before mutation (`can_advance`); the rest completes and returns true. The real-kernel blocked-transfer test compares full export and RNG before/after refused advance, and checks reserved plus undispatched budget. Successful native advance sets combat_done before notifications; handoff continues only unconsumed work.

### Validation status and evidence (to finalize before delivery)

Use Godot 4.7.2, isolated test projects/user directories. The existing runner's imported project `test/work/test_time_steps-ak2cifhs` was reused for focused reruns by copying changed scripts/tests and invoking the same Godot script entry with isolated APPDATA/LOCALAPPDATA. Raw failures were retained; no old failure is treated as a pass.

Passing results so far: time steps 237/0 (current battlefield fixture, old assertions retained); commit boundary 82/0 (income atomicity, snapshot gates, invalidated context, second planet, second region, second combat subdivision); Hyperspace material economy 144/0; save boundaries 31/0; AI tech 142/0; native blocked transfer 38/0; native Galaxy boundary 137/0; native Galaxy refit 301/0; native handoff 55/0. Final affected reruns and performance are in progress.

The real original-main rendering workflow passed all 8 phases, 128 checks total, with empty reopened-domain mismatch lists. Product save and factory reopen images were inspected. A final affected-tree rendering run is pending. Certificate-store and ObjectDB/resource exit warnings are retained in raw evidence. The first performance attempts exposed stale synthetic geometry initialization; fixture preparation was repaired, without changing production rendering. One baseline attempt then emitted a DummyMesh RID exit leak; it is not recorded as a clean performance pass. Final comparison must run serially after correctness tests finish, using equal engine, configuration, seed, frame count and workload.

No S2 acceptance or main merge is claimed by this interim record. Frozen context/cancellation intentionally requires stopping that session; no new abandonment/recovery policy is introduced.
