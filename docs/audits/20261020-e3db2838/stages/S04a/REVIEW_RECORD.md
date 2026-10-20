# S04a review record

Stage state: `review`. Runtime candidate `4efef1c2a2dad438dd515ee3dca0cbf77a8b14d6`; tree `21fe58a96e3d4a3bd9430aa95adb34fdca6b68bd`; base main `abb68a7f7014dafee73c2f8c48a856aaddec0456`. Evidence snapshot is the audit commit containing this file and the updated hash manifest. It must be read back before either independent verdict. Earlier handoff `4ef3659e` was superseded by this PID-reuse recovery correction; no verdict can be inherited.

## Implementation handoff

- **Contract:** one OS-held writer per archive, second instance runs without writing; no merge. OS lock is held in the native `SpaceSaveLock` object for the game's lifetime. Windows exclusive `CreateFileW` and POSIX nonblocking `flock` close automatically on process death; sidecar existence or PID does not confer ownership.
- **Runtime scope:** exactly five files listed in [README.md](README.md). `space_native.cpp` provides the necessary OS primitive; `progress_writer.gd`, `game.gd`, `save_transfer.gd` cover ordinary save, import, recovery finalization and deletion; `main.gd` shows the read-only warning while the game continues. No audit test, runner, generated DLL, logs or screenshot belongs in main.
- **Evidence scope:** audit-only `test_single_writer_s04a.py` and three Godot workers, adjusted recovery/transfer/policy/startup/boundary fixtures, runner and S01 gate options, [synthetic summary](dual_process_summary.json), this record, and manifest. The new test compares the entire save artifact set before and after denied writes.
- **Verification:** Windows Godot 4.7.2 native DLL SHA-256 `21a6a85131796759bf220e4d7913e0ac2a1cf9d6c589d4176fa1b2b61ffe69d1`; dual process gate PASS; recovery 131/0, transfer 158/0, policy 59/0 under S01 gate; startup 7/0 and boundaries 22/0 direct isolated run; `git diff --check` clean. Exact commands and limitations are in README.
- **Authorization:** D03 explicitly approved. No data migration, forced exit, automatic merge, gameplay or numeric policy change.

## Parent independent review

Verdict: **PENDING**. Reviewed runtime SHA: pending. Reviewed evidence SHA: pending. Unresolved review items: inspect native OS lock and lifetime, every write entrance, UI behavior, synthetic snapshots, runtime file whitelist, platform limits, and rebuild obligation. Parent must independently state PASS/FAIL on the final exact two SHAs; this handoff does not claim approval.

## Original astra independent review

Verdict: **PENDING**. Reviewed runtime SHA: pending. Reviewed evidence SHA: pending. Unresolved review items: same contract and evidence, including whether `flock`/Windows `CreateFileW` semantics and import/recovery ownership are complete. The original astra must independently state PASS/FAIL on the same final two SHAs.

## Integration and closure

State: **not integrated**. Current main remains `abb68a7f7014dafee73c2f8c48a856aaddec0456`. Local actual entry result: **not run for this runtime SHA**; parent owns integration and entry validation after dual PASS. S04a closure: **pending**; S05 remains blocked by S04a. A code or evidence change affecting conclusions requires a new snapshot and fresh reviews.
