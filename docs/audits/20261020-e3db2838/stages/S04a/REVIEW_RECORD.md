# S04a review record

State: **review pending**. Base main `abb68a7f7014dafee73c2f8c48a856aaddec0456`; runtime candidate `01ddfcaf678321fafae51162b3bb6665b34e4301`, tree `46975cef1cd058b859525873b85b35453b26e8e3`. Audit snapshot is the commit containing this record and [the hash manifest](../../PLAN_SHA256SUMS.json). Both reviewers must state PASS on the final exact runtime and audit commit objects. Earlier heads `4efef1c2`, `cde9d042`, `5f410762` and `8fcc99c1` are superseded.

## Findings closed in this candidate

- Parent P1: the tracked `tools/player_runtime/space_native.dll` and the launcher native acceptance inventory initially remained at the old version. Both are now runtime dependencies in the candidate. `verified_bundle()` passed, bundled and installed DLL SHA-256 matched, and a clean isolated main mirror completed actual `tools/play_main.py` start and 120-frame exit 0. See [player entry receipt](player_entry_validation.json).
- Original astra P1: string-only path comparison allowed an unowned export through a directory alias to the same progress file. Native path canonicalization now feeds the ordinary Writer guard and export guard; the Windows junction negative test returned 31 for export, 22 for Writer, and left all save artifacts identical. The cross-platform test constructs a POSIX directory symlink when run on POSIX. Windows execution passed; Linux execution remains for independent review.
- Build reproducibility: the repository godot-cpp SCons defaults to `-fno-exceptions`. Native canonicalization now uses the `std::error_code` overload; the bundled DLL was rebuilt with `-fno-exceptions` and passed the same gates.
- Parent gate finding: the dual process Python driver previously summarized each Godot subprocess without checking its complete output. It now saves every child output, including holders before kill, and rejects any script/parse diagnostic matched by the S01 gate pattern. See [worker logs](worker-logs) and [summary](dual_process_summary.json).
- Regression caught during this correction: the shared protected-path guard initially rejected the owning import transaction's marker and staging writes. Those writes now use `ProgressWriter.write_import_stage()` after verifying the OS owner and permitted suffix. Transfer regression was rerun after this repair.

## Implementation handoff

Windows `CreateFileW` exclusive handle and POSIX `flock(LOCK_EX|LOCK_NB)` hold a permanent sidecar; no PID file grants ownership or is removed. A second process continues read-only and reports ERR_ALREADY_IN_USE (22) at save, import, clear and recovery write entrances. `weakly_canonical` resolves file/directory aliases before protected-file comparison. The runtime diff is exactly the seven paths in [RUNTIME_BLOBS.json](RUNTIME_BLOBS.json), including the necessary DLL and launcher inventory. Audit test code and logs stay on the audit branch.

Windows validation: S01 dual process PASS, recovery 131/0, transfer 161/0, policy 59/0; isolated startup rejection 7/0 and save boundaries 22/0. Native DLL SHA-256 `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f`. Actual player entry on isolated candidate main mirror exited 0. The synthetic save directory and worker logs are in the audit test area; committed evidence contains summaries and worker logs only. No personal save or credentials were used.

## Parent independent review

Verdict: **PENDING**. Reviewed runtime SHA: pending. Reviewed audit SHA: pending. Check launcher delivery, native lock/path semantics, every write entrance, import/recovery ownership, read-only UI, test validity, and platform limits. Record an independent PASS or FAIL for the final pair.

## Original astra independent review

Verdict: **PENDING**. Reviewed runtime SHA: pending. Reviewed audit SHA: pending. Recheck the original directory-alias P1, canonical path coverage and negative evidence, along with the full S04a contract. Record an independent PASS or FAIL for the same final pair.

## Integration and closure

Main remains `abb68a7f7014dafee73c2f8c48a856aaddec0456`. No merge, closure or S05 start was performed. Parent owns main integration and final acceptance after two matching PASS verdicts. Any further change affecting review conclusions requires a new exact snapshot and fresh reviews.
