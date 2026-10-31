# Enemy presentation evidence for 7f77acf6

This directory archives the existing targeted run for code commit
`7f77acf6cffd5b1a11b147a8d38dafea3424ccb8`, based on
`b29e442ef8ce5bf3d93e3c4346dd898f2d694308`. Packaging did not rerun any check.
The evidence commit changes only this directory; production code is unchanged.

## Contents and result

- [probe.gd](probe.gd): byte-for-byte source used in the recorded run.
- [probe.log](probe.log): original Godot log, 44 `PASS` entries and `PROBE_FAILURES=0`; process exit was 0.
- [manifest.json](manifest.json): exact code revision, source/log and DLL hashes, pinned tools, original invocation, and limits.
- [.gitattributes](.gitattributes): preserves probe/log bytes across Git checkout.

The run covers pure shield loss with unchanged hp, shield recovery waiting and
recovery, zero capacity versus empty shield, huge Amount values, birth identity
through death/retreat, cleared bindings and reinstallation, read-only snapshots,
unchanged native/Battle row reuse, shared-geometry cache reuse and invalidation,
and queries leaving clocks/history and damage receipts untouched.

The script uses the real candidate DLL and real Battle query/cache methods. Its
subclass skips Battle's resource-loading initializer and supplies controlled
accepted descriptors and synthetic shared hull packets. It does not verify the
complete GameSession, UI appearance, drawing, formation, saves/restoration, or G9.
Reinitialization coverage must not be described as persisted-save restoration.

Native compilation, full main-script check-only compilation, and the repository's
existing standalone Amount C++ test also exited 0 before packaging. Their complete
raw logs were not saved; this archive does not manufacture replacements for them.
The only attached runtime log is `probe.log`.

## Independent reproduction (instructions only; not executed during packaging)

Use this evidence commit in a review checkout: its production files are exactly
the code revision above. Alternatively, extract this evidence directory alongside
a checkout of that exact code revision. Configure the pinned dependencies as
described in [foundation/README.md](../../../../foundation/README.md):
`SPACE_IDLE_GODOT`, `SPACE_IDLE_GODOT_CPP`, `SPACE_IDLE_LLVM_MINGW`,
`SPACE_IDLE_GODOT_API`, and `SPACE_IDLE_PYTHON` (Python with SCons).
The tested versions and API hash are in `manifest.json`.

From the repository root in PowerShell:

```powershell
$project = (Resolve-Path .\space-battleship).Path
$archive = Join-Path $project 'docs\verification\enemy-presentation\7f77acf6'
$reviewBuild = Join-Path $env:TEMP 'space-idle-enemy-presentation-review'
& (Join-Path $project 'addons\native_battle\build_native.ps1') -BuildRoot $reviewBuild -Jobs 4
if ($LASTEXITCODE -ne 0) { throw 'Native build failed' }
$env:SPACE_IDLE_NATIVE_EXTENSION = Join-Path $reviewBuild 'native-stable\space_native.gdextension'
& $env:SPACE_IDLE_GODOT --headless --path $project --log-file (Join-Path $reviewBuild 'review-probe.log') --script (Join-Path $archive 'probe.gd')
if ($LASTEXITCODE -ne 0) { throw 'Targeted probe failed' }
```

Expect 44 `PASS` lines, `PROBE_FAILURES=0`, and exit 0. Keep the review run's
new log separate from this archived original. The manifest's original invocation
records the actual executable, cwd, DLL manifest and temporary probe/log paths
used before archival; those historical paths are not needed for reproduction.

For the earlier compilation/Amount checks, from `space-battleship/`:

```powershell
& $env:SPACE_IDLE_GODOT --headless --path . --script res://src/main.gd --check-only
& (Join-Path $env:SPACE_IDLE_LLVM_MINGW 'bin\clang++.exe') -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o (Join-Path $reviewBuild 'amount-tests.exe')
if ($LASTEXITCODE -eq 0) { & (Join-Path $reviewBuild 'amount-tests.exe') }
```

The original working directory needed the normal editor asset import before its
main-script check, because its font import cache was absent. That import generated
142 untracked `.uid` files and 120 untracked `.import` files. Cleanup was rejected
by automatic approval review; they remain uncommitted and are outside this archive.
No new test runner or CI facility is introduced by this archival exception.
