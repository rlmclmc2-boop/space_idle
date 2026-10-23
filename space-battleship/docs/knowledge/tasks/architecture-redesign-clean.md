# architecture-redesign-clean

- Goal: independently verify the global audit and commit a reviewable architecture proposal before implementation.
- Base: d1fff7b4e74023f2e41ff2c14b2b2c37ca3dc34b. Audit input: fc4ca37b004b3a4c2402ae988e13d3c86dfbcd3f.
- Scope: architectural boundaries and migration/verification plan; no gameplay, balance, configuration or save changes. Independent clone; preserve other workspaces.
- Stop: submit plan for dot + independent high review; no implementation before review, no main merge without both; hand off and stop on compaction.
- Read gap: no architecture route. Use decision route plus explicit audit targets. Inspect scripts/game.gd function index; progress_runtime.gd commit/tick functions; attribute_projection.gd dependencies; crew_system.gd event dispatch; balance_game.gd numeric/executor methods; native_execution_compiler.gd capability gate; main.gd import/reload recovery; tools/config_workbooks.py batch; analyzer manifest/build dependency checks; test_state_ownership.gd and equipment guide. Inspect project.godot, main.tscn, battlefield.gd entry and owner indexes to verify full supported surfaces. Read only relevant symbols and direct callers.
- Risks: stale consumer inventories, hidden model differences, failure ordering; audit claims are hypotheses until checked.
- Next: record source evidence and alternatives in proposal; Git-only handoff.

- Additional read gap: verify actual income authority, retained work, and delivery identity before specifying boundaries. Exact targets: economy_state.gd function index and income queries; ai_tech_state.gd income peak; galaxy_runtime.gd:1-85; hyperspace_runtime.gd:1-84; presented_battle_game.gd:45-99; fleet_battle_runner.gd:53-100; balance_runner.gd:37-63; tools/build_release.ps1 identity/native lines; guides/running.md commands. No prior task records read.

- Outcome: proposal at docs/GLOBAL_ARCHITECTURE_PLAN.md; evidence paths exist; analyzer manifest missing scripts independently confirmed by filesystem check; git diff --check clean. No game test/build/performance run (docs-only). Implementation blocked on dot + independent high review of the proposal Git commit. No main merge, no player state accessed.
