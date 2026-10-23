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

- Continuation starts from c903c062 in a separate local Git clone; the previous checkout, personal saves and uncommitted work were not changed. Branch: `work/architecture-s1-continuation-20261024`. Base remains 793f7c4c; no main merge or remote push.
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

| Test | Checks / failures | Ignored local evidence under test/work |
|---|---|---|
| test_commit_boundary.gd | 25 / 0 | test_commit_boundary-qfyrdqua/{import,test}.log |
| test_planet.gd | 688 / 0 | test_planet-z1d6h0dc/{import,test}.log |
| test_module_refit.gd | 63 / 0 | test_module_refit-ezn85vxc/{import,test}.log |
| test_ai_tech_tree.gd | 134 / 0 | test_ai_tech_tree-5ydwe442/{import,test}.log |
| test_crew_dirty.gd | 59 / 0 | test_crew_dirty-kfk4oomy/{import,test}.log |
| test_native_numeric_upgrade.gd | 146 / 0 | test_native_numeric_upgrade-3e4igs4i/{import,test}.log |

The last three ran after all their affected implementation changes. The final subsequent code delta changed only planet-command allocation facts from `payload.has("activated")` to `plan.configuration`; boundary, planet and module-refit tests ran again on the final script tree. No runtime code changed after those final launches. Total selected assertions: 1115, zero failures. `git diff --check 793f7c4c HEAD` also passed.

Engine: Godot 4.7.2 stable official ed1daf0bf, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. Verified bundled native DLL used by the isolated runner: SHA256 `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f`. No rebuild was required because native source was unchanged.

All runs emitted the Windows root certificate store warning. Boundary/research/crew/planet runs also reported ObjectDB/resource leaks on exit (57/57/58/87 instances and 26 resources respectively). These were not repaired or represented as clean runtime teardown. No script-load/parse/runtime failure or missing completion summary was accepted. This is affected-correctness evidence, not performance, full UI, whole-step accounting, or release acceptance.

Git handoff: fetch `work/architecture-s1-continuation-20261024` from `C:\Users\Administrator\Documents\Codex\2026-10-24\task-2\s1`. The complete S1 candidate includes inherited c903c062 plus continuation 1501dccf and this verification record; do not cherry-pick the continuation alone onto main. Original candidate checkout still reports c903c062 with a clean worktree. Only Git commits are delivery; ignored test artifacts are not part of the candidate.
