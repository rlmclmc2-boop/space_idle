# S04a single writer handoff

State: **review**. The sole implementation plan and PLAN_VALIDATION now mark S04a as the one open review stage; prior astra FAIL on the older audit snapshot was for their stale not_started entry. Parent and original astra must independently pass the same final runtime and audit commits before any main integration. S04a remains open; S05 has not begun.

| Item | Exact object |
| --- | --- |
| Base main | `abb68a7f7014dafee73c2f8c48a856aaddec0456` |
| Runtime candidate | `01ddfcaf678321fafae51162b3bb6665b34e4301` |
| Runtime tree | `46975cef1cd058b859525873b85b35453b26e8e3` |
| Audit base | `f451b5eaae9c57196a7a627ee452b83e85df27da` |
| Native DLL SHA-256 | `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f` |

## Runtime delivery

The native path method uses `std::error_code` and was rebuilt with `-fno-exceptions`, matching the default godot-cpp SCons option. The runtime diff contains seven paths, all in [RUNTIME_BLOBS.json](RUNTIME_BLOBS.json): five implementation sources, the tracked player DLL `tools/player_runtime/space_native.dll`, and the player acceptance inventory `space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json`. The DLL and inventory are required by `tools/play_main.py`: it verifies the native source Git blobs and DLL SHA-256, then installs that exact DLL into `space-battleship/bin`. A source-only merge would fail player verification or leave the new lock class unavailable. The normal launcher continues to require a clean, accepted `main`; the candidate was tested in an isolated `main` mirror without changing the actual main branch.

`SpaceSaveLock` holds an exclusive Windows `CreateFileW` handle or POSIX nonblocking `flock` on a permanent `.writer-lock` sidecar. Only the OS handle grants ownership. Closing or killing the process releases it. No valid lock is removed. The second game loads its snapshot and displays a read-only warning while the UI continues running. Ordinary saves, clear, import staging/commit, and recovery finalization require ownership. Native `weakly_canonical` resolves existing file links, directory links/junctions and the parent of new files; progress and export share protected path identity checks. Import's internal marker and staging writes flow through the owning `ProgressWriter`.

## Windows verification

Godot `4.7.2.stable.official.ed1daf0bf`, fixed godot-cpp binding and LLVM MinGW, synthetic user directories. Run the four S01 commands from the audit branch with `--source-root <candidate root>` and `--native-dll <candidate root>/tools/player_runtime/space_native.dll`:

```text
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_single_writer_s04a.py --headless --godot <Godot console> --source-root <candidate root> --native-dll <candidate DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_recovery_s04.gd --headless --godot <Godot console> --source-root <candidate root> --native-dll <candidate DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_transfer.gd --headless --godot <Godot console> --source-root <candidate root> --native-dll <candidate DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_policy.gd --headless --godot <Godot console> --source-root <candidate root> --native-dll <candidate DLL>
```

The dual process gate asserts same-save rejection, different-save independence, normal exit and forced kill reacquisition, denial at save/import/clear/recovery, a running read-only UI, identical save artifact hashes, a real confirmed import followed by `reload_current_scene()` and a new Game that acquires the lock, saves and retains resource 4321 on disk, and rejection of an alias directory (Windows junction here; POSIX symbolic link in the same cross-platform test). Alias export returns 31; direct Writer returns 22. [The summary](dual_process_summary.json) contains exact results and hashes; [worker-logs](worker-logs) retains complete UTF-8 output from all eleven Godot subprocesses with LF newlines, including both holders before forced termination. Each summary log SHA-256 matches its Git blob. The Python driver rejects any child script or parse diagnostic using the S01 gate pattern. The isolated runner accepts a Linux `.so` and writes matching Linux GDExtension entries, so the same test executes its POSIX symlink case on a Linux host with a matching native build. Linux execution and filesystem race attacks were not validated on this Windows host.

Recovery: 131 checks / 0 failures. Transfer: 161 / 0. Save policy: 59 / 0. Startup rejection: 7 / 0 and save boundaries: 22 / 0 in isolated direct runs. The tracked DLL and acceptance inventory also passed `tools.play_main.verified_bundle()`. A clean, isolated main mirror ran `tools/play_main.py` using the bundled DLL, imported resources, opened the game and quit after 120 frames with exit 0. [Player entry receipt](player_entry_validation.json) identifies the head, DLL and game log hashes. The game log had no script errors. Final gate results refer to the exact candidate above.

## Review scope

Reviewers should inspect OS lock lifetime, all write entrances, canonical path behavior on both platforms, import/recovery ownership, read-only UI, test output validation, DLL provenance and launcher inventory. Windows OS certificate-store warnings in Godot output did not cause script or save failures. The audit branch holds test scripts, fixtures, logs, summaries and review records; none of those are part of the runtime diff. See [REVIEW_RECORD.md](REVIEW_RECORD.md) for independent verdict slots. No main merge or stage closure was performed.
