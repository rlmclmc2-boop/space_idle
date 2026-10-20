# Player entry

Launch the game from the repository root with `玩游戏.cmd` on Windows 10/11 x64. The entry uses built-in Windows PowerShell and Git; no preinstalled Python or Godot is required. On first launch it downloads pinned official Python and Godot archives, verifies SHA-256, and caches them under the ignored `space-battleship/.runtime/` and `space-battleship/engine/` directories. The first launch requires internet access; later launches reuse the verified local files. It does not fetch Git changes or change player saves.

If Godot's first resource import exits with Windows access violation `3221225477`, the entry keeps its first log as `player-import-first-attempt.log` and retries that import once. Other import failures stop with the import log available for inspection.

The player entry requires the local `main` commit to equal the locally fetched `origin/main` ref from `rlmclmc2-boop/space_idle` on GitHub. A normal `git pull` advances both refs, so new accepted game commits require no launcher edit. If the refs differ, inspect local changes and update or review the branch manually; the launcher does not pull, reset, or overwrite the user's checkout. If that checkout contains uncommitted runtime edits, the entry keeps them untouched and plays committed main from a managed clean mirror under `.runtime/player-main/checkout/`. This mirror is reused on updates; only generated tracked import files inside the managed mirror may be reset. The original checkout's `.userdata` still supplies the player's saves. Generated Godot `.import`, `.uid`, and evidence CSV translations are allowed.

The native runtime inventory is [`native-validation-hashes.json`](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json). The launcher verifies that the accepted main commit still contains the inventoried native source blobs and that the bundled and installed DLL hashes match the inventory. A native source or DLL change therefore requires an updated, reviewed inventory in the same accepted main history. The matching DLL is installed automatically on launch; manual repair remains available:

```powershell
python tools/play_main.py --install-native
```

DLL replacement keeps a hash-named backup of an older installed DLL in `space-battleship/.runtime/native-backup/`. It does not alter player progress. The Godot executable must match the pinned 4.7.2 Windows build and the inventory's engine version, and have no adjacent `.pck`. The native extension descriptor must resolve to the installed DLL. Existing nonmatching executables and cached archives stop startup with an error; they are not overwritten.

For an isolated launch check, set `SPACE_BATTLESHIP_VERIFY_WINDOW=1`. This puts saves, logs, and the launch receipt under `test/work/player-window-check/`. Set `SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES=120` in that mode to exit after 120 frames. Ordinary launches use this checkout's `.userdata` and `.runtime` directories.

Historical native validation: [`native-validation-hashes.json`](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json). The previous one-time main startup check is in [`main-startup-20261020`](../test/evidence/main-startup-20261020/README.md).
