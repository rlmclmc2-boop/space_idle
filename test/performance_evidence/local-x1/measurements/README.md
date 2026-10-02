# Local X1 measurement provenance

These are the six original, unmodified 3600-frame samples from the isolated Windows run, stored as lossless `.gz` files to preserve exact source bytes and keep the Git diff readable. JSON rows contain elapsed time, frame interval, main-loop duration, event counts, stage/state, and enemy/projectile counts. They contain no save data. The stage 82 input save is intentionally excluded; its SHA-256 is `8b882f2774ee02c3ce63e2bc02edf51ad48e9a7c35a8d49d89103577f0280c1d`.

Run `python test/performance_evidence/local-x1/measurements/verify_measurements.py` at the repository root. It verifies the archived measurement sources against Git commits after CRLF normalization, checks exact raw source hashes stored by the probe, and recomputes each frame distribution and event count. `before-to-original.diff` and `original-to-final.diff` show the committed changes. No production script contains sampling instrumentation; the isolated probe is `x1_light_probe.gd`.

The baseline sample used `e16abb40f12ca25a547d381b4ac643b979124cb0`; `after`, `after2`, and later `control` used `5b7542db115783c51dbd7ce89587f53e28f97a71`; `final` and `final2` used `cfc9ef9402d49f4c9832bf1c878790d4b442b990`. `game.gd` and `equipment_tab.gd` did not change between the baseline and original implementation. The original `after` source contains mixed line endings: raw SHA-256 `35e167ec55ca2d8b85c7f3cbc292b1fb0eb184c24983d4cb3e46fffcac415665`; normalized content exactly matches Git `5b7542d`. The baseline CRLF source hash is `7dcf24b19445ee90d9096741e31e13592fcf6337b2db744fc0d447677324a6b8`. The final raw `main.gd` hash is `9e63e8660400e8f5c96caeeea65a7239756156c87de2bb732b102d3cd28fac81`.

Each run copied the same stage 82 save into the isolated APPDATA directory, then launched Godot 4.7.2 with `--path <isolated-project> --resolution 1373x883 --script res://.runtime/x1_light_probe.gd -- --x1-label=<label>`. The probe loads real `main.tscn`, selects equipment page +1, seeds battle RNG with 1701, uses X1, keeps rendering and timed saves active, warms 120 frames, then records 3600 frames. VSync was on, FPS cap 60, GL Compatibility on RTX 3090. The probe records frame intervals around the actual `_process` call without per-function diagnostics. `after` and `final` have matching event counts; `after2`, `control`, and `final2` cover repeat variability. Save snapshot is not included, so a third party can recalculate these samples but cannot replay the exact stage 82 input from this archive alone.

The actual PowerShell invocation from the worktree root was:

```powershell
$area = (Resolve-Path -LiteralPath 'test/work/test_orbital_blender_assets-8rkphcat').Path
$env:APPDATA = Join-Path $area 'userdata/roaming'
$env:LOCALAPPDATA = Join-Path $area 'userdata/local'
$target = Join-Path $env:APPDATA 'Godot/app_userdata/太空战舰 · 深空远征/progress.json'
Copy-Item -LiteralPath (Join-Path $area 'stage82-save.json') -Destination $target -Force
& 'G:/放置/space-battleship/engine/Godot_v4.7.2-stable_win64.exe' --path (Join-Path $area 'space-battleship') --resolution 1373x883 --script 'res://.runtime/x1_light_probe.gd' --log-file (Join-Path $area 'stage82-light-before.log') -- --x1-label=before
```

For each subsequent label, the same save was copied again. The command changed only the log file and `--x1-label` value. The isolated `scripts/main.gd` and `scripts/equipment_tab.gd` were first set to the archived version named above; the original implementation and final repair were copied from their respective worktree commits. This local path is provenance, not a bundled replay environment.
