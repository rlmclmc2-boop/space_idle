# 2026-10-16 branch integration record

- Goal: merge `docs/token-reading-main@688937d7` into the reviewed single-slot candidate `879fea78`.
- Scope: resolve only `tools/play_main.py`. Keep runtime BASE `60af4b09`, DLL SHA `dccd40b5...`, and 12 exact documentation/read-tool exceptions. No main merge, deployment, or balance changes.
- Locate: `tools/play_main.py`, `test/test_player_entry.py`, `space-battleship/tools/read_budget.py` and its tests.
- Risk and check: the entry must admit precisely the 12 paths and still reject gameplay changes. Run entry and read-tool tests only.
- Result: `tools/play_main.py` kept BASE `60af4b0989c1e239788f35a38cf4877720bdccdc`, DLL SHA `dccd40b52e086444edd7291d2bead736b96f7876a53f989df5549a1d4f99b30a`, and the exact 12 paths from the docs branch. No other conflict.
- [Entry checks](player-entry-merged.log): 11 passed, including admitting only listed reading files and rejecting a runtime source mixed with a listed file. [Read-tool checks](read-budget-merged.log): 7 passed. No game test rerun.
- Archived here outside `space-battleship/` so the runtime whitelist remains exactly 12 paths.
