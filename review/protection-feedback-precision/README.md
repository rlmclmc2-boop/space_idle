# Protection feedback precision evidence

Tested candidate: `2d6e3d0ccefa8373801778047a05eb9ac725a224` (`fix/protection-feedback-precision`), based on `31933e2da98cf648f6aa1f89800813d1f7ffdf52`. Business baseline: `e16abb40f12ca25a547d381b4ac643b979124cb0`.

These are copies of the original verification artifacts, not rerun measurements. `fixed-feedback.log`, `neutral-memory.log` and `deferred-regression.log` show 166/166, 33/33 and 31/31. `exit-codes.txt` records the observed process outcomes. `verify.py` is the exact original orchestration script, including assertions for exit codes and before/after state equality.

`original-main-business.json` and `fixed-feedback.json` are the raw 24-case snapshots. `business-comparison.csv` expands all 24 × 11 unchanged business fields (264 equal rows). Cases include actual nonempty debt buckets, full/partial fractional scheduled absorption, floating values 0.04/0.01/0.001, and unit cover spent against 1e16 and GrowthNumber 1e400. Feedback text/absorption intentionally differ and are excluded from business equality.

`reviewed-candidate-boundaries.*` records the original candidate's 19 expected failures under the same final new checks. Baseline mode skips feedback-specific expectations while retaining business assertions. All runs used Godot 4.6.3, speed 1, headless, an isolated project/user directory and synthetic in-memory profiles. No user saves, credentials, personal account information or temporary-directory dump is included. SHA256SUMS covers the copied data and derived comparison.

This evidence branch changes no production files. The fix remains a candidate; it was not merged into main.
