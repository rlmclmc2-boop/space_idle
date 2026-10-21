# S10 integration preflight, pending main publication

Same-object dual PASS is recorded in `REVIEW_RECORD.md`: runtime `31e79337741bf9860d69fff21dae6be994dacd00`, frozen review evidence `813c43126db07dc6d3c3b19917359b4f29e2fcf5`.

The fast-forward push to main was rejected by automatic approval review before execution. Remote readback confirmed main remains `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8`. The stated reason was that publishing main requires trusted user-authored confirmation that the dual-PASS prerequisite was met. The user has been asked for that confirmation; no alternative publish path was used.

Independent preflight on the reviewed runtime branch used Godot 4.7.2 Windows headless with isolated `APPDATA` and `LOCALAPPDATA` inside this task workspace. `integration-preflight/integration_exact_save_probe.gd` performed one upgrade at level 1500 after assigning exactly `9007199254740993` reactor units, then saved and reopened. `integration-preflight/integration_exact_save.log` reports zero failures; both the allocation and post-debit uranium balance `9007199254741003`, plus level 1501, survived disk JSON and reopen. The root-certificate-store warning in that log did not affect this offline probe.

Read-only D:\放置 preflight found its checkout still at main `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8`, with the previous installed DLL SHA-256 `04e7be92c92637a72dde5f71ccc57a865ad20842e00aca63fd628b86e321590f` and a local `space-battleship/project.godot` modification. Its player entry can use `SPACE_BATTLESHIP_VERIFY_WINDOW=1` and `SPACE_BATTLESHIP_PLAYER_SOURCE_ROOT` to route verification user data outside the real save directory. No D:\放置 files or saves were changed by this preflight.

The actual D:\放置 entry first launch and reopen on the approved S10 main commit remain pending. This preflight is not an integration PASS and does not close S10.
