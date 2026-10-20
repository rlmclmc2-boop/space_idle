# S04 local integration verification

Approved runtime: `abb68a7f7014dafee73c2f8c48a856aaddec0456`. Frozen evidence: `c345de52867a38a2cc0db6baadb2a53b2daa37aa`. Both parent and original astra PASS verdicts are recorded in [FINAL_REVIEW.md](FINAL_REVIEW.md) at audit commit `1bcbd69c509147d6936a7835a8b0b15dbfaa5462`.

## Actual local checkout

The real checkout is `D:\放置` on `main`. Before the update, local HEAD was `0d01530bdce168a55d0ce7c835f17072d66d6bc7`; remote `main` was the approved runtime. Existing work comprised 164 tracked modifications (163 `.import` files and `space-battleship/project.godot`) and 856 untracked files. The three approved runtime scripts had no local edits.

Commands:

```powershell
git -c safe.directory='D:/放置' -C 'D:\放置' fetch origin main
git -c safe.directory='D:/放置' -C 'D:\放置' merge --ff-only abb68a7f7014dafee73c2f8c48a856aaddec0456
```

Both exited 0. Fast-forward updated only `space-battleship/scripts/game.gd`, `progress_writer.gd` and `save_transfer.gd`. Read-back after verification: local `HEAD`, `origin/main`, fresh `ls-remote origin refs/heads/main`, and the launcher's managed clean mirror `HEAD` all equal `abb68a7f7014dafee73c2f8c48a856aaddec0456`. The local checkout still has the same 164 tracked modifications (163 `.import` and `project.godot`) and 856 untracked files; the three runtime scripts remain unmodified locally. No personal save or existing work was reset or deleted.

## Isolated full-save startup and reopen

The real `D:\放置\玩游戏.cmd` invokes `tools/bootstrap_player.ps1` and `tools/play_main.py`. Because `project.godot` has an existing local edit, the launcher selected its managed clean mirror at the approved runtime SHA. Verification mode redirected APPDATA and LOCALAPPDATA to `D:\放置\test\work\player-window-check\userdata\roaming` and `...\local`. The actual isolated `user://progress.json` resolved to `D:\放置\test\work\player-window-check\userdata\roaming\Godot\app_userdata\太空战舰 · 深空远征\progress.json`. The player's ordinary `.userdata` directory was never used.

The audit-only [isolated_save_probe.gd](isolated_save_probe.gd) generated a save from the approved `BattleGame.portable_save_data()` writer with persistence disabled and set `resources.1=4321`. It required the current complete quality before writing and refused to replace an existing progress file. The resulting v5 JSON had all 47 current top-level writer fields and was 42,650 bytes. No `progress.json*` existed in the isolated app user directory before seeding.

PowerShell seed and read-back commands (the `check` command was run after each real launch):

```powershell
$env:APPDATA='D:\放置\test\work\player-window-check\userdata\roaming'
$env:LOCALAPPDATA='D:\放置\test\work\player-window-check\userdata\local'
$probe='C:\Users\Administrator\Documents\Codex\2026-10-21\task-5\audit\docs\audits\20261020-e3db2838\stages\S04\isolated_save_probe.gd'
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\放置\space-battleship' --script $probe -- seed
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\放置\space-battleship' --script $probe -- check
```

Seed and both read-back invocations exited 0. Each read-back printed `ISOLATED_LOAD_OK resources.1=4321 startup_error=empty save_enabled=true`.

The following real entry command was run **twice** against the same isolated save:

```powershell
$env:SPACE_BATTLESHIP_VERIFY_WINDOW='1'
$env:SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES='120'
$env:SPACE_BATTLESHIP_ENGINE_PATH='D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
& 'D:\放置\玩游戏.cmd'
```

Both launches imported the project, opened `res://main.tscn`, and exited **0** after 120 frames. The final `player-launch.json` reported approved HEAD, Godot `4.7.2.stable.official.ed1daf0bf`, native DLL SHA256 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`, and `game_data.json` SHA256 `e25cec9db813b1122dae681c37cd990067efab439caec97f1cc4ef889bcf4c4a`. The isolated progress file remained the only `progress.json*` file and its final SHA256 was `113e106e8d217de9e39595a554b2ef00acad5e5fd53feadfecb0a941eb679baf`.

Both captured entry outputs, seed and both read-back outputs, and final `player-import.log` / `player-game.log` had **zero** matches for `SCRIPT ERROR:`, `Parse Error:`, `Traceback`, `FATAL` or a line beginning `ERROR:`. Generated logs and synthetic save remain local and are not committed.

## Candidate branch assessment

Fresh remote `main` and `s04/durable-recovery` both resolved to `abb68a7f7014dafee73c2f8c48a856aaddec0456`. `git rev-list --count main..origin/s04/durable-recovery` returned `0`, and `merge-base --is-ancestor origin/s04/durable-recovery main` exited `0`. The audit branch retained the complete evidence at `5522fdded558d4831a447fbef593dcee766437e2`.

The parent and original astra independently reviewed that same integration evidence commit and both returned **PASS**, unresolved 0. Their acceptance covers the isolated full-save load and actual entry startup/reopen; it does not extend to real power loss, multi-instance behavior, or long-running play.

After those approvals, the only temporary S04 remote branch was deleted with an exact-SHA lease:

```powershell
git -c safe.directory='D:/放置' -C 'D:\放置' push --force-with-lease=refs/heads/s04/durable-recovery:abb68a7f7014dafee73c2f8c48a856aaddec0456 origin --delete s04/durable-recovery
git -c safe.directory='D:/放置' -C 'D:\放置' ls-remote origin refs/heads/main refs/heads/s04/durable-recovery refs/heads/audit/code-review-e3db2838-20261020
```

The delete exited 0. The read-back returned only `main` at `abb68a7f7014dafee73c2f8c48a856aaddec0456` and the audit branch at `5522fdded558d4831a447fbef593dcee766437e2`; the deleted branch was absent. No other branch or local uncommitted content was deleted. Stage closure and thread archive belong to the parent; S04a remains blocked.
