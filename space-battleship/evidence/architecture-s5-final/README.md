# S5 final candidate evidence (exclude from main)

Evidence for candidate `6e3ce8dffc002c30249a195b498ee11d20e5d7b3`, runtime cleanup `2e0fc2b4`. This directory was selected from existing isolated results after measurement. No game, test or benchmark was rerun to create it. It is candidate-review material only, not a player/build/main deliverable.

Start with [review-index.json](review-index.json), whose paths are relative to this directory. [manifest.json](manifest.json) records original repository-relative source paths, exact byte lengths and SHA256 for every selected payload and the portable index. Original indexes are unchanged under `indexes/`; their absolute Windows paths identify historical execution locations, not additional required downloads. `.gitattributes` preserves copied bytes in Git.

## Included evidence

- `raw/s0`, `raw/s4`, `raw/s5`: all 21 successful rendered whole-game reports and matching logs (111 page rows), the final 300-second growth logs, and the final complete-cost F9 logs. References: S0 `793f7c4cda5e480434f14663597ffbeee72163ff`, S4 `1795d5c5cef6a20060303e5f1c914542edc882a4`, S5 runtime `2e0fc2b4` (unchanged in `6e3ce8df`).
- `raw/<version>/f9-8000` and `f9-24000`: final generated synthetic inputs, six original battle records, pair aggregates and summary/execution identity. Each copied `battles.jsonl` was checked against its corresponding `BATTLE_WORK` log array, including execution metadata. These are generated Lab inputs/results, not a personal save.
- `source-hashes`: original full source/configuration file-hash inventories used to guard reuse. Each top-level `sha256` is SHA256 of Python `json.dumps(files, sort_keys=True).encode()` as used by the existing runner, not a Git tree hash. Engine/native/probe hashes and actual work states are retained in each rendered JSON report. All final rendered reports use one engine, one native binary and one probe hash; each version uses one source inventory.
- `verification`: the four final selected regression logs (131, 1230, 21 and 157 checks, all zero failures), plus all eight actual main-entry phase logs (151 checks, zero failures, restored-domain mismatches empty). Certificate-store diagnostics and the deliberate invalid-configuration rejection remain in the raw logs. The material fixture's exit resource warnings are not hidden.
- `indexes/s5-reuse-rejection.json`: recorded CLI rejection outcomes for an existing unknown cache, a nonexistent directory and an empty fingerprint record. Each rejected before target mutation. No unknown-source reused measurement contributes to the passing matrix.
- `excluded`: the failed headless DummyMesh report/log, superseded opening/material fixture logs and the two incomplete larger-pool F9 logs. These are not passing or comparable samples. The 120-second timeout determination came from the executor's subprocess timeout, not a completion line in the incomplete F9 logs. No missing completion is reconstructed as success.

No project copy, import cache, engine/DLL, user save, credentials, temporary workbook, screenshot or Library upload is included. The prior accepted S2/S3/S4 evidence reused for unchanged boundaries remains referenced by its existing commit in the task/closure table; this directory does not relabel historical evidence as newly run.

## Interpretation limits

Read the [task entry](../../docs/knowledge/tasks/architecture-s2-boundaries.md) for the full scoped result and [ownership closure](../../docs/ARCHITECTURE.md#supported-entry-closure). Normal/rich shared pages 0/4/1/2 have matching observed work across all repeats. Pages 6/8 and the S0-to-current 300-second growth pair are explicitly not same-work comparisons. Dense native observations are a single case; these are CPU/manual-step measurements, not FPS or a long-run leak guarantee.

**F9's additional preparation and execution cost relative to S0 is observed, but causal attribution has not been established.** Separate timing phases locate cost in broad stages; they do not prove which new boundary or algorithm caused it. No savings or performance optimization has been demonstrated. S4/S5 physics records agree, while execution identities differ; this does not authorize cross-identity report merge/retest. The larger generation-pool timeouts are not certified by the different small-batch workload.

Final dot/high agreement remains the acceptance gate. These files must be excluded from any later main delivery.
