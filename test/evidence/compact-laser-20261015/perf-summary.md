# Compact laser full-frame validation, 2026-10-15

Candidate: `fea943bc8d944cf2247907139aa075ca0ccf510f`; DLL SHA256 `1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5`. The same source, DLL, workload, and GL Compatibility rendering were used with compact births forced off/on in the QA driver. Each isolated run had 240 warm logical steps and 480 sampled steps at game speed 1, 60 Hz logic, full presentation, uncapped rendering, VSync off, cache on, save off, and a focused window. Engine reported NVIDIA GeForce RTX 2060. Exact hashes, order, validity flags, counts, timing arrays, and screenshots are in `perf-receipt.json` and the nine `*.json.gz` files. The receipt's raw SHA256 values refer to the decompressed JSON.

GL smoke: 1,436 compact fires; 146 compact serials active before downgrade. Forcing the legacy display materialized 365 rows for 365 active flights, and the kernel handoff export was unchanged. `mixed-smoke.png` shows the rendered battle.

| Workload | Order | Off mean ms | On mean ms | Mean saving ms | Off P95 ms | On P95 ms | Busy frames >10ms, off/on | Off drift ms |
|---|---|---:|---:|---:|---|---|---|---:|
| Mixed | off/on/on/off | 9.159, 9.070 | 8.522, 8.494 | 0.606 | 15.356, 15.087 | 13.046, 13.251 | 289/864, 284/872 vs 254/927, 239/931 | 0.089 |
| Pulse laser | off/on/on/off | 8.705, 8.777 | 7.214, 7.245 | 1.511 | 19.704, 22.133 | 13.218, 13.024 | 311/907, 309/898 vs 209/1094, 205/1093 | 0.072 |

All eight sampled windows completed the same 480 logical steps and 8 game seconds in 7.88–7.92 wall seconds, passed the focus/1x/timing checks, and had no script errors. Within each workload, compact off/on had identical sampled fire, hit, projectile impact, purchase, and upgrade event counts; game and kernel RNG state, player, enemies, resources, loadout, stage, and drops matched before and after sampling. Mixed had 3,458 fires, 13,050 hits, 8,430 impacts, and 8 completed upgrade batches. Pulse laser had 7,906 fires, 18,436 hits/impacts, and 8 upgrade batches. Compact fires during whole runs (warm plus sample) were 4,436 mixed and 11,535 pulse laser; off runs had zero. The `legendary_counts.drone_fire` probe differs because the compact route bypasses that legacy instrumentation point; the authoritative event counts above match.

The measured mean saving exceeds the 0.5ms retention threshold and off-run drift in both affected scenes. P95 and many individual full frames still exceed 10ms. These fixtures do not establish natural death, consecutive waves, random drops, or quote behavior in a human play session. They also do not measure the three unaffected environments anew. No main merge or production config change was made.
