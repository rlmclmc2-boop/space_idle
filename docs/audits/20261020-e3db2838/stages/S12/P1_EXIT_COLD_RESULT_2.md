# P1 repaired cold-process audit gate: 40/40 finite measurements pass

[Freeze 2](P1_EXIT_COLD_FREEZE_2.json) pinned audit query source `f6a54af3f440854e46ba2c16c9d57472f23fc8ba` and 19 Git-byte dependencies before measurement. It retained the original exact-256, middle compact, far compact and cancellation inputs and 4/50/100 ms thresholds. The runner verified source and its own hash; every child used a new process and isolated APPDATA/LOCALAPPDATA. The [raw aggregate](p1_proto/exploratory_p1_exit_cold_2.json) and all 40 `p1_proto/exploratory_exit_cold_2_{class}_{01..10}.{stdout.log,stderr.log,meta.json}` triplets are the primary evidence. [Independent readback](p1_proto/exploratory_p1_exit_cold_2_independent.json) rehashed all 80 streams, checked the 40 metadata records, terminal state, complete gate keys, amount/material/level receipt for commits and no live write for cancellation. It reported zero failures.

| Class (10 new processes each) | Max single-frame query work | Max main heartbeat gap | Full query wall range | Commit wall range | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Exact 256 | 2.586 ms | 16.709 ms | 1.036–1.038 s | 116–137 us | 10/10 |
| Approximate middle | 1.788 ms | 16.995 ms | 2.187–2.220 s | 147–158 us | 10/10 |
| Compact far exponent | 2.992 ms | 16.707 ms | 3.153–3.219 s | 165–181 us | 10/10 |
| Cancellation | 3.742 ms | 16.761 ms | 1.385–1.419 s | no commit | 10/10; request-to-stop 32.036–32.467 ms |

The highest synchronous phase times were prefix 3.742 ms, fee-thread start 2.990 ms and fee join/decode 1.753 ms. Work is charged to observed frame numbers, including setup, source validation, exact prefix, material, bounds result, host dependency checks and commit; heartbeat is measured by a main-frame callback. Full query time is reported, with no P1 total-time threshold. New processes do not clear the OS file cache. `run_exit_cold.py` requires all forty unique rows, complete gate keys and expected terminal states; execution failures and timeouts cannot vacuously pass.

This limited audit gate does **not** erase [the first frozen FAIL](P1_EXIT_COLD_RESULT.md) or the historical 10,000-block full-public 4 ms failure. The [legacy bridge checks](P1_EXIT_REPAIR.md) and [finite protocol](P1_HOST_PROTOCOL.md) address the other specified P1 interface/host gaps within their documented support domain. This is a candidate for dot and replacement astra to review on one complete evidence SHA. It is not a dual-review P1 PASS, product connection, native DLL/save/UI validation, or main-merge authorization.
