# Player entry

Launch the game from the repository root with `玩游戏.cmd`. The script resolves its own checkout; it does not select a test copy, fetch Git changes, or change player saves.

The player entry requires the local `main` commit to equal the locally fetched `origin/main` ref from `rlmclmc2-boop/space_idle` on GitHub. A normal `git pull` advances both refs, so new accepted game commits require no launcher edit. If the refs differ, inspect local changes and update or review the branch manually; the launcher does not pull, reset, or overwrite it. Tracked runtime and launcher edits, plus unexpected untracked runtime files, remain blocked. Generated Godot `.import` and `.uid` files are allowed.

The native runtime inventory is [`native-validation-hashes.json`](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json). The launcher verifies that the accepted main commit still contains the inventoried native source blobs and that the bundled and installed DLL hashes match the inventory. A native source or DLL change therefore requires an updated, reviewed inventory in the same accepted main history. Install the matching DLL explicitly when needed:

```powershell
python tools/play_main.py --install-native
```

This command keeps a hash-named backup of an older installed DLL in `space-battleship/.runtime/native-backup/` before replacing it. It does not alter player progress. The Godot executable must be at `space-battleship/engine/Godot_v4.7.2-stable_win64.exe`, match the inventory's engine version, and have no adjacent `.pck`. The native extension descriptor must resolve to the installed DLL.

For an isolated launch check, set `SPACE_BATTLESHIP_VERIFY_WINDOW=1`. This puts saves, logs, and the launch receipt under `test/work/player-window-check/`. Set `SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES=120` in that mode to exit after 120 frames. Ordinary launches use this checkout's `.userdata` and `.runtime` directories.

Historical native validation: [`native-validation-hashes.json`](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json). The previous one-time main startup check is in [`main-startup-20261020`](../test/evidence/main-startup-20261020/README.md).
