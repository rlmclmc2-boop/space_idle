# S03 local integration verification

Runtime approved by both reviewers: `0d01530bdce168a55d0ce7c835f17072d66d6bc7`. Previous main: `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`. Review record: `stages/S03/FINAL_REVIEW.md` at audit commit `2fb843dc0f95fc9426735d90e10dd97a7772a1b9`.

## Local update and preservation

On Windows `BJNLPC-0459`, the actual checkout `D:\放置` was on `main` at the previous SHA and `origin/main` was the approved SHA. Before updating, 164 tracked changes were present: 163 `.import` files and `space-battleship/project.godot`; there were 806 untracked generated/local files. `space-battleship/scripts/save_transfer.gd`, the only file changed by the approved commit, had no local modification.

Command: `git -c safe.directory='D:/放置' -C 'D:\放置' merge --ff-only 0d01530bdce168a55d0ce7c835f17072d66d6bc7`.

Result: exit 0; fast-forward changed only `space-battleship/scripts/save_transfer.gd` (13 insertions, 2 deletions). Read-back of `D:\放置` HEAD and `origin/main` was the approved SHA. After the player run, the original checkout still had 164 tracked changes, with `project.godot` the only non-`.import` modification. No local edits or personal saves were deleted or reset.

## Actual player entry, isolated user directory

The real `D:\放置\玩游戏.cmd` calls `tools/bootstrap_player.ps1` and `tools/play_main.py`. The source checkout contains a pre-existing local `project.godot` edit, so this entry correctly selected its pre-existing managed clean mirror rather than using unreviewed local runtime edits. The mirror read-back HEAD was the approved SHA.

PowerShell invocation:

```powershell
$env:SPACE_BATTLESHIP_VERIFY_WINDOW='1'
$env:SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES='120'
$env:SPACE_BATTLESHIP_ENGINE_PATH='D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
& 'D:\放置\玩游戏.cmd'
```

The verification mode selected `D:\放置\test\work\player-window-check\userdata\roaming` for APPDATA and the adjacent `local` directory for LOCALAPPDATA. These are separate from the player's ordinary `.userdata`. No `progress.json*` existed under that isolated user directory before or after this run. The entry imported the project, launched `res://main.tscn`, and quit after 120 frames. Exit code: **0**. `player-launch.json` reported HEAD `0d01530bdce168a55d0ce7c835f17072d66d6bc7`, Godot `4.7.2.stable.official.ed1daf0bf`, native DLL SHA256 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`, and `game_data.json` SHA256 `e25cec9db813b1122dae681c37cd990067efab439caec97f1cc4ef889bcf4c4a`.

The captured entry output and `player-import.log` and `player-game.log` were checked for `SCRIPT ERROR:`, `Parse Error:`, Python traceback, `FATAL`, and lines beginning `ERROR:`. Each had **0 matching lines**. Full generated logs and user data remain local and are not committed.

## Branch cleanup assessment

Remote `main` and `s03/durable-portable` both resolve to `0d01530bdce168a55d0ce7c835f17072d66d6bc7`: the candidate branch has no unique unmerged runtime commit. The necessary test and review evidence is retained on `audit/code-review-e3db2838-20261020`. The candidate branch is eligible for later cleanup after the parent completes stage closure; **no branch was deleted**. S04 was not started.
