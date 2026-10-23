# architecture-s1-commit-boundary

- Goal: S1 pilot from approved 76ed4b58: equipment upgrade/loadout/hull changes and Progress completion contract, committed-fact scheduler entry, compatibility facade. Deliver candidate only.
- Base: 793f7c4cda5e480434f14663597ffbeee72163ff (S0 main, remotely verified).
- Constraints: no S2 time/accounting redesign, gameplay/balance/frozen data/save changes, or main merge. Preserve personal saves/unrelated edits. Existing independent reviewer is coordinated by parent; do not create another review agent. Compaction requires Git handoff and stop.
- User decision boundary: questionable/wrong/ambiguous old behavior goes to parent with current behavior, impact and recommendation, not automatic compatibility or unilateral semantic changes.
- Initial read gap: no architecture route. Read approved plan section 4 and S1/exit requirements; inspect game.gd configuration_committed, commit_loadout_change, commit_equipment_upgrades and direct facade callers; progress_runtime.gd command/advance/completion functions; crew_system.gd event/scheduler invalidation; equipment/economy proposal/commit methods; attribute_projection dependency table; native prepare/batch boundaries; directly relevant existing tests and equipment/crew/progression guides. No unrelated task records.
- Risks: native callbacks stale plans, reentrant writes/notifications, duplicate scheduler wakeups, capacity/health order, tests of current owner APIs. Retain existing business algorithms and native fast path, establish actual failure boundary before implementation.
- Next: inventory selected command callers and commit/install invariants, then implement minimal shared result/completion support and targeted tests.

## Compaction handoff — WIP, not accepted

- Stop reason: context compaction; user requires Git handoff and immediate stop. No further implementation or verification after compaction.
- Main delivery completed before S1: 793f7c4cda5e480434f14663597ffbeee72163ff, normal push and remote full-SHA readback. No S1 main merge.
- Candidate branch: work/architecture-s1-commit-boundary-20261024, based on that main commit.
- Implemented WIP: immutable command results; shared commit completion boundary; equipment upgrade/loadout/hull result facades with stale-wallet/configuration checks; capacity reconciliation before contribution publication; committed-fact crew scheduling; reentrant command/tick guards; Progress crew/planet/research result paths. Existing gameplay algorithms are intended to remain unchanged.
- Tests completed on earlier launch snapshots: test_crew_dirty.gd 59 checks / 0 failures; test_commit_boundary.gd 16 checks / 0 failures; test_native_numeric_upgrade.gd 146 checks / 0 failures. Godot import succeeded. Root certificate store warning occurred; crew test also reported exit resource leaks. Test artifacts remain ignored locally under test/work and are not delivery files.
- IMPORTANT: latest progress_runtime.gd research income/advance and prepare-helper changes occurred after these test snapshots. Final committed tree has NOT been validated by those passes. git diff --check was clean before handoff.
- Remaining: validate current-tree parsing and affected correctness; review all selected public callers and rejection propagation; decide exact S1/S2 boundary for void time APIs and incomplete planet steps; verify native failure atomicity, contribution descriptors and scheduler facts; update necessary current guides/architecture/status; obtain parent-coordinated independent high and dot agreement. S1 is not complete or approved.
- Preserved later-slice boundaries: reforge/load/recovery remain S3; factory refresh and full shared-step/retained-time handling remain S2; BalanceGame legacy research consumer remains a known later consumer issue. Do not interpret partial migration as proof these paths are correct.
- Next explicit reads: this task record, approved plan 76ed4b587b21af276b59ed37867c5a7271009b6d section 4, changed scripts command_result.gd/commit_effects.gd/game.gd/progress_runtime.gd/crew_system.gd/equipment_state.gd/balance_game.gd, test/test_commit_boundary.gd and affected existing tests. Inspect the Git diff against the base, then resume only in a continuation authorized to work after this stopped handoff.
- No new gameplay ambiguity has been resolved on the user's behalf. Report any discovered questionable legacy behavior as current behavior / impact / recommendation for user judgment.

## Authorized continuation — candidate, review still required

- Continuation starts from c903c062 in a separate local Git clone; the previous checkout, personal saves and uncommitted work were not changed. Branch: `work/architecture-s1-continuation-20261024`. Base remains 793f7c4c; no main merge. The complete candidate branch was normally pushed to `rlmclmc2-boop/space_idle`; remote readback confirmed `3140aeb2ebe921c0a8702ce18fbed3b45dd9b331` before this evidence-only follow-up.
- Closed additional gaps: Progress rechecks cross-domain contribution inputs after native handoff; externally supplied planet/research proposals are copied and frozen; research input/ratio commands use the same completion boundary; configuration handoff rejects writes during completion. Planet advancement now consumes a concrete step result for both partial progress and joint planet/crew completion. Partial progress marks save dirty without issuing completion rewards/notices. Planet scheduling facts derive from the plan, not the UI payload.
- Command results are not a global write lock or a time ledger. Public migrated commands are guarded; direct owner APIs, lifecycle and other S2 producers are not claimed migrated. No gameplay, balance, frozen data or save schema edits.

### Responsibility replacement / callers

| Old responsibility | Current owner / consumers / exit |
|---|---|
| Equipment refit/upgrade dirty flag and notifications | Game result methods install the concrete proposals, then `commit_effects.finish`; bool facades remain current UI API. `equipment_tab`, `ship_panel`, `main`, `balance_autoplayer`, `player_loadout_generator` and crew equipment purchasing reach the same implementation. No parallel equipment event scheduling remains. |
| Progress crew/planet/research notification completion | `progress_runtime` result methods and `commit_effects`; crew/planet panels and main research controls use bool facades. Internal planet/research advance checks concrete commit results; advance wrappers still do not report a shared-time remainder. |
| Crew scheduling inferred from equipment/crew/planet UI notices | `crew_system.on_committed` uses immutable facts. Removed migrated branches from `on_event`; resource/reactor/unlock bridges exist only for unmigrated S2 producers. Migrated notices carry `_committed_fact` to suppress those bridges. |
| Native numeric update followed by host install | Existing session/kernel retain responsibility. Kernel `update_configuration` validates before `apply_configuration`; apply has no business rejection or host notification. Host wallet validation precedes native commit; synchronous owner installs have no external callbacks. Existing real-native test plus boundary rejection/reentry fixture cover distinct sides of this contract. No native source/binary changed. |

### Review boundary requiring parent dot/high disposition

- Current behavior: shared time wrappers remain void; after earlier domains/planets commit, a later native rejection can return without a retained remainder. Factory refresh and BalanceGame's legacy research fields also remain later-slice consumers. Impact: this candidate proves individual commit completion, not lossless/replay-safe shared time or full Lab research support. Recommendation: retain the approved S2 time/consumer migration and S4 Lab scope, and explicitly accept this S1 pilot boundary before marking S1 closed. Do not infer acceptance from this record.
- Existing reforge/load/recovery stays S3; no compatibility promise for historical personal saves was added.
- Independent high and dot must review the final candidate SHA through the parent. No new review subagent was created. Full architecture acceptance and main merge are pending, not denied.

### Verification of continuation implementation 1501dccf37d5491e09cfceb156800383fba2cb92

Executed from repository root with `python test/run.py <name> --headless --godot C:\Users\Administrator\Documents\Codex\2026-10-23\task-4\godot\Godot_v4.7.2-stable_win64.exe`. Each runner isolated both project and user directories, imported successfully, returned 0 and produced its recognized completion summary. No personal save was used.

| Test | Checks / failures | Committed original test.log (repository-relative) |
|---|---|---|
| test_commit_boundary.gd | 25 / 0 | `test/evidence/architecture-s1/test_commit_boundary/test.log` |
| test_planet.gd | 688 / 0 | `test/evidence/architecture-s1/test_planet/test.log` |
| test_module_refit.gd | 63 / 0 | `test/evidence/architecture-s1/test_module_refit/test.log` |
| test_ai_tech_tree.gd | 134 / 0 | `test/evidence/architecture-s1/test_ai_tech_tree/test.log` |
| test_crew_dirty.gd | 59 / 0 | `test/evidence/architecture-s1/test_crew_dirty/test.log` |
| test_native_numeric_upgrade.gd | 146 / 0 | `test/evidence/architecture-s1/test_native_numeric_upgrade/test.log` |

The last three ran after all their affected implementation changes. The final subsequent code delta changed only planet-command allocation facts from `payload.has("activated")` to `plan.configuration`; boundary, planet and module-refit tests ran again on the final script tree. No runtime code changed after those final launches. Total selected assertions: 1115, zero failures. `git diff --check 793f7c4c HEAD` also passed.

Engine: Godot 4.7.2 stable official ed1daf0bf, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. Verified bundled native DLL used by the isolated runner: SHA256 `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f`. No rebuild was required because native source was unchanged.

All runs emitted the Windows root certificate store warning. Boundary/research/crew/planet runs also reported ObjectDB/resource leaks on exit (57/57/58/87 instances and 26 resources respectively). These were not repaired or represented as clean runtime teardown. No script-load/parse/runtime failure or missing completion summary was accepted. This is affected-correctness evidence, not performance, full UI, whole-step accounting, or release acceptance.

Git handoff: fetch [work/architecture-s1-continuation-20261024](https://github.com/rlmclmc2-boop/space_idle/tree/work/architecture-s1-continuation-20261024) from `https://github.com/rlmclmc2-boop/space_idle.git`. The complete S1 candidate includes inherited c903c062 plus continuation 1501dccf and this verification record; do not cherry-pick the continuation alone onto main. Original candidate checkout still reports c903c062 with a clean worktree. Only Git commits are delivery. The six original test.log files are now committed under `test/evidence/architecture-s1/`; they were copied byte-for-byte from the completed runs, with no rerun. Directory-local Git attributes disable text conversion for these logs. Import logs, saves and caches remain excluded. This follow-up changes only evidence and this handoff record; the implementation and test results are unchanged. The final pushed evidence commit SHA is supplied with the remote readback in the parent handoff.

## Review correction: external-time reentry and ordinary-progress cost

Parent review did not accept candidate `84bf68e1fd1e7c7387c536301123d56701de2b3c`: external-time consumption could perform side effects before tick refused reentry, and ordinary Progress steps added unnecessary copying/result construction/resource scans. Correction implementation: `4af9fa253b3612fc3e28fb7795779aba2749c227`. This section supersedes the earlier acceptance evidence for these two concerns; final parent dot/high acceptance remains pending.

- `consume_external_time` now refuses commit/logical-step reentry in its first guard, before timed-save checks, departure countdown, presentation, particles, resource-history pruning or budget/remainder changes. This is an entry guard, not S2 time retention or replay accounting.
- Ordinary incomplete planet and noncompleted/nonstopped research use `commit_effects.begin_progress/finish_progress`, the same exclusion and dirty-state owner with cached deeply immutable results. Result domains and changed resource IDs remain precise; contributions are empty because these steps do not alter them. No contribution-vector capture, coordinator proposal deep copy/freeze, or full result construction occurs on these paths. Existing domain snapshot preparation/install copies remain authoritative and unchanged.
- Research spending alone does not make a waiting purchase affordable. Resource scheduling and immutable UI notice now share the preexisting 250ms resource-notice cadence instead of rescanning all equipment cost rows each paid substep. Completion/stopping/configuration transitions retain full result publication. Due-notice tests verify one scheduler delivery before UI and blocked external-time reentry.
- No S2 ledger, gameplay/balance, native source/binary or save-schema change. Original six evidence logs remain historical and unchanged; new logs are in `test/evidence/architecture-s1-review/`.

### Affected correctness and regression reproduction

| Check | Outcome | Committed raw log under test/evidence/architecture-s1-review |
|---|---|---|
| Updated boundary fixture on rejected 84bf68e1 | 29 checks, 4 expected failures: external-time side effects, reused result, per-step scheduler scan, due-notice ordering/reentry | before-boundary-regression.log |
| Same boundary fixture on 4af9fa25 | 29 checks, 0 failures | after-boundary.log |
| Current research test on 4af9fa25 | 134 checks, 0 failures | after-research.log |
| Current planet test on 4af9fa25 | 688 checks, 0 failures | after-planet.log |
| Same hot-path harness, baseline and corrected source | 13 checks, 0 failures each; identical work and wallet outputs | before-hotpath.log / after-hotpath.log |
| Legacy test_time_steps.gd, both revisions | 206 checks, 1 failure and script errors on both; not accepted as passing | before-time-steps-known-failure.log / after-time-steps-known-failure.log |

The additional time-step probe fails identically on 84bf68e1 and 4af9fa25: `no later geometry preparation after departure`, missing `Runtime.detach_requested` at test line 208, and a nil geometry mount (`screen_mount_for_slot`). Both exit 1. This is an existing fixture/entry mismatch, not closed by this S1 correction; the test was neither changed nor counted as acceptance. Broader time-step acceptance remains limited by that probe, while the new targeted external-entry regression is red on the baseline and green on the correction. No attempt was made to expand into S2 or repair unrelated geometry/lifecycle behavior.

Runner: same `python test/run.py <test> --headless --godot <engine>` and engine/native hashes recorded above. The updated boundary and domain tests were imported in isolated projects and isolated user directories. Baseline regression reproduction reused the imported 84bf68e1 project with only the identical updated fixture copied in. Initial benchmark fixture parsing encountered a built-in type-name collision; it was corrected before both measured runs and is not counted as passing evidence. Certificate warnings remain; boundary/domain runs still report fixture exit resource leaks, preserved in the raw logs.

### Hot-path before/after measurement

Same Windows host, engine, source data and fixture; environment reports `Intel64 Family 6 Model 165 Stepping 5, GenuineIntel`, 16 logical processors. Hardware inventory through CIM was unavailable; no specific processor model is inferred. Both already-imported isolated projects were run serially after the other test processes finished. Before each run, game/progress_runtime/commit_effects/command_result script contents were checked against the stated Git revision (ignoring checkout CRLF only), and both fixture files were checked identical. Harness SHA256: `b3a5fe03b50b5f56491f740ede04bce9ee49525fd930ad3c5b61677c58f96bf1`.

Reproduce by putting `4af9fa25:test/test_progress_commit_hotpath.gd` into independent checkouts of 84bf68e1 and 4af9fa25, then running the same test/run.py command serially. The deterministic fixture extends planet/research completion thresholds to 1e9 only in memory; it uses one active planet or singularity research, with both resource inputs equal to 1 for the paid case. Each scenario warms 200 steps then measures seven batches of 1000 steps at dt=0.001. The notice timestamp is set each step to measure the interior of the 250ms window consistently; due delivery is separately tested above. No random draws or personal saves are involved.

| Scenario | Before median microseconds / 1000 steps | After | Reduction | Configuration-input reads before -> after | Full completion results before -> after | Resource scans before -> after |
|---|---:|---:|---:|---|---|---|
| Planet ordinary progress | 122065 | 46828 | 61.64% | 14000 -> 0 | 7000 -> 0 | 0 -> 0 |
| Research, unpaid | 188623 | 131669 | 30.19% | 28000 -> 0 | 7000 -> 0 | 0 -> 0 |
| Research, paid | 234567 | 154807 | 34.00% | 28000 -> 0 | 7000 -> 0 | 7000 -> 0 |

Counters cover the 7000 measured steps, excluding warmup. These are instrumented method-call counts, not a total heap-allocation measurement. Every pair produced exactly the same 7.20000000000074 units of work and wallet values; paid wallets were 99999992.7999854 for each resource, unpaid/planet 100000000.0. Raw per-batch samples and full outcomes are committed. This establishes a reduction in the selected ordinary hot paths only, not frame-rate, native-battle, F9, peak-memory or full-product performance acceptance. No performance threshold or S2 correctness claim is inferred.

## Filtered main delivery prepared; push approval blocked

Parent reported dot/high S1-limited agreement for 5a907736 and requested filtered delivery. In independent `s1-delivery`, created `c3cdf98e5e6fdd8b0e2dba507d840b796ead0bc7` on remote main baseline 793f7c4c. Exactly seven runtime files and the reusable boundary test match the approved candidate. ARCHITECTURE/equipment guide remove references to omitted task/benchmark; progression guide explicitly marks the legacy time test as unresolved. No task record, new evidence directory or one-off hotpath script enters the delivery commit (11 files total).

Actual delivery tree ran original main.tscn through `test/run.py test_ordinary_entry.gd` with rendering and isolated user directories. Eight phases passed, 128 checks / 0 failures: planet-loading 16, product-write 26, product-reopen 18, product-claimed-reopen 7, reactor-write 25, reactor-reopen 8, factory-write 20, factory-reopen 8. Stage logs are retained byte-for-byte only on this candidate branch under `test/evidence/architecture-s1-delivery/`; import logs, saves, screenshots and caches are not committed. Save-page and factory-reopen screenshots were inspected locally. Certificate-store warnings remain.

The exact attempted action was a normal Git push of c3cdf98e to `rlmclmc2-boop/space_idle:refs/heads/main`. Automatic approval rejected it before execution: it treated the earlier trusted “do not merge main” instruction as controlling and did not accept the later delegated approval as trusted authorization. No retry or alternate main mutation occurred. A user confirmation request is pending; main delivery is NOT complete. Publishing the same commit to `work/architecture-s1-main-delivery` is only a review handoff, not an indirect merge.

Independent work: restored the original approved plan entry `docs/GLOBAL_ARCHITECTURE_PLAN.md` from 76ed4b58 and added section 12 with current delivery state, actual S2 symbols/scope, implementation/acceptance boundaries and concrete gameplay ambiguities requiring existing user decisions to be verified. No S2 runtime implementation or semantic decision was made. The plan and delivery evidence remain outside main.

## Main delivery confirmed

After the parent supplied new trusted transcript evidence of the user's conditional main-merge authorization and confirmed dot/high agreement, retried the exact denied normal main push once. It succeeded: remote main advanced from 793f7c4c to `c3cdf98e5e6fdd8b0e2dba507d840b796ead0bc7`; `git ls-remote --heads` read back that full SHA. No force push, branch deletion or alternate merge route was used. The earlier blocker above is resolved. The filtered tree and its eight-phase / 128-check acceptance are unchanged. S2 scope and remaining gameplay decisions remain in the original plan entry, outside main; the legacy time-test failure remains unresolved.
