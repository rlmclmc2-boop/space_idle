---
name: token-opt
description: Reduce total tokens for a coding task through narrow retrieval, verification, and reporting; use when planning work or handling large outputs.
---

Optimize total task cost, including later rereads and rework; never trade correctness for a smaller immediate prompt.

- Start from the target symbol/path and task route in AGENTS.md. Search filenames or indexed matches first; read only matching ranges and direct dependencies. Do not scan all docs, the repo, or full game_data.json for orientation.
- Keep scope and edits narrow. Before another read or tool call, ask what decision it enables. Batch independent searches; bound output and logs to the decisive lines. Retrieve more only when an omission could affect the decision.
- Run the smallest relevant verification from docs/TEST.md. Stop when affected behavior and stated risks are covered; do not rerun unrelated suites to accumulate green results.
- Report changes, decisive evidence, and remaining risks once. Prefer file references and concise counts over pasted source or full logs. For durable notes, use doc-compact.
