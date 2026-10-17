# Tutorial and unlock notice correction

- Goal: concise factual unlock notices and short location-based opening guidance; correct misleading gated cards and research completion behavior.
- Base: verified remote `main@3a0f40283ae653d004f738277606b2a57bf7739c`; candidate `feat/unlock-notice-copy-20261017`.
- Scope: unlock and onboarding copy, AI factory prerequisite visibility, reactor module visibility, enemy intelligence time display, opening tutorial pause, single-level research stop, and completion badge. Keep balance values and unlock gates unchanged.
- Stop: targeted source, headless text rendering, gate and pause behavior checked; retain original output and commit for parent review. No main merge.
- Locate: `docs/UI_TEXT.md`, matching `data/ui_text.json`/contract keys, `config_excel/unlock.xlsx` exception rows, and unlock rendering entry.
- Risk: the opening screenshot includes situational strategy inside a notice. Remove it without erasing the unlock identity or adjacent system instructions.
- Next: parent review and GUI check in its assigned serial window.

## Coverage

| Entry | Source / render path | Result |
|---|---|---|
| Opening, equipment, defense, upgrade, resource wait, combat, clear, retreat, pickup, enhancement | `data/ui_text.json` `onboarding.*` → `beginner_guide.gd` | Short capabilities and location; opening phase holds simulation until Next or Dismiss. |
| Unlock popup and guide archive | `unlock.xlsx` → `game_data.json` → `main.gd`, `unlock_tutorial.gd` | All 46 descriptions state only unlocked content; title and gate unchanged. |
| Synthetic hyperspace archive entry | `tutorial.hyperspace.description` | Short unlock summary. |
| AI research choices | `ai_tech_tree.gd` eligibility → `ai_tech_view_model.gd` → art page | Unmet first-level choices hidden; earned levels remain visible even if next level is gated. |
| Reactor module bays | `reactor_available_modules()` → `reactor_panel.gd` | Locked bays absent in both synced lists; stage 15 reveals condensation. |
| Research completion | `ai_tech_tree.gd` → profile → system navigation | Stops after one level, marks persisted unread badge, clears on tech page entry. |
| Enemy shield timing | `enemy_intel_page.gd` `duration_text` | 1800 ms is shown as 1.8 seconds; authored timing is unchanged. |
| Stage-clear drops | `game.gd` clear → `collect` → `main.gd` resource feedback | All remaining ordinary/core drops settle once before an unlock pause; the existing top resource icons receive increments and flight effects. |

## Mechanic checks

- Upgrade cost is a resource dictionary. `host.cost_text` already includes resource units, so the onboarding `{cost}` sentence adds no fixed “iron” suffix.
- Active weapon and defense slot counts come from the selected hull; copy asserts no fixed slot count. `equip_slot` changes a slot without charging resources; upgrade cost remains on the card.
- Fragment technology checks `enhancement_unlocked()` through research eligibility. The reactor condensation bay uses its own `reactor_module_unlocked()` gate, a cleared-stage 15 condition. These are distinct gates.
- Completion writes only the finished technology's level and resets its own progress; remaining `dt` stops at that boundary. Stored progress and multipliers for other technologies remain intact.
- Intro and unlock pause requests share one baseline paused state. Auto-skip still applies only to unlock notices.

## Before / after samples

| Surface | Before | After |
|---|---|---|
| Reactor unlock | “去【反应炉】点【均分】先看加成，再拖能源偏向武器或防御……” | “反应炉已解锁。” |
| Beam unlock | “先把一门武器换成光束……若打不动……再试另一类伤害。” | “高能激光已解锁。” |
| Shield unlock | Defense-slot, recovery, and comparison instructions | “偏转护盾已解锁。” |
| AI prerequisite | “强化碎片已解锁” even when prerequisites were unmet | Hidden until eligible; condition label is “解锁条件：强化系统”. |
| Enemy shield delay | “1800 毫秒” | “1.8 秒” |

The complete source-string before/after table is in `unlock-notice-copy-before-after-20261017.md`.

## Verification (Godot 4.7.2, `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`)

- `python tools/ui_text_editor.py --check` → `UI catalog: 2387 rows, valid`.
- Workbook audit → `XLSX_CELL_AUDIT_OK 46 desc cells; all other values and styles identical`.
- `test/test_unlock_copy.gd` → `COPY_CHECK_OK` with actual rendered waiting, reactor, shield, and auto-skip strings; all 46 projected unlock descriptions concise; 1.8/0.25 second conversions.
- `test/test_unlock_gates.gd` → `GATE_CHECK_OK` for initial, enhancement, core, earned, and final choices; reactor condensation absent before cleared stage 15 and present after; both bay lists compact.
- `test/test_ai_tech_stop_badge.gd` → `TECH_STOP_BADGE_OK level=1 active=none balance=9520.0 saved_unread=true restored_clear=true`.
- `test/test_tutorial_pause.gd` → `TUTORIAL_PAUSE_OK repeated intro, overlapping unlock, preexisting pause, auto-skip separation, resources stable`.
- `test/test_clear_drop_settlement.gd` → `CLEAR_DROPS_OK receipts={ "1": 1, "2": 1 } top_icons=2 effects=2 repeat=no_change`.
- Headless main scene for two frames (`--headless --path . --quit-after 2`) → exit code 0, with no script errors.

Godot emitted local log and certificate-store warnings because this sandbox cannot write the global Godot settings directory. The tests above returned exit code 0 and their checks passed. GUI review remains for the parent's serial window.

## AI investment performance check

The existing rich whole-game fixture (heavy battleship, eight level-150 weapons, four level-150 defenses, three durable enemies, completed galaxy state) was copied into one isolated project with Godot 4.7.2. Both runs used seed 1701, 480 measured realtime frames per page, the same imported assets, and the same fixture. Mode `zero` invested 0/0; mode `both` invested 100 iron and 100 uranium per game second. Page 0 is the hidden-factory case; page 1 opens the factory with its selection drawer. The page provider counted snapshot calls, while row instance IDs counted list rebuilds; no per-frame logging was added. Raw measurements: `ai-tech-investment-perf-20261017.json`.

| Factory | Inputs | Resource events | Snapshots | List rebuilds | Node delta | Main p95 (µs) | Frame p95 (µs) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Hidden | 0/0 | 0 | 0 | 0 | +3 | 4318 | 6930 |
| Hidden | 100/100 | 13 | 0 | 0 | +3 | 3949 | 6916 |
| Visible | 0/0 | 0 | 13 | 0 | 0 | 3445 | 6921 |
| Visible | 100/100 | 13 | 13 | 0 | 0 | 3158 | 6920 |

The resource event path is `AITech.advance` (250 ms limit) → `resources_changed` → existing UI refresh. The visible page's separate 250 ms provider refresh ran 13 times in either mode. `_sync_rows` kept its ID/tier fingerprint and rebuilt no rows. The headless high-load CPU sample showed no investment-related rise in snapshot count, node growth, or measured p95 cost. Headless rendering reported zero draw calls, so this does not establish graphical FPS; GUI review remains in the parent's serial window.

## Player entry handoff

`玩游戏.cmd` now changes to its own directory and calls `tools/play_main.py` there. The Python entry resolves its checkout from `__file__`; the isolated window check stays under that checkout's `test/work`, without a fixed D: path. Source baseline, main-branch, 4.7.2 engine, GDExtension descriptor, and native DLL SHA-256 checks remain. The entry also rejects uncommitted or untracked runtime files other than generated `.uid`/`.import` metadata and the exact checked native descriptor that the entry creates on first run. Current `BASE` is provisional at `2fec0f04f19d85b11fe21a5931b63c5d4bb713e8`; the integration owner must replace it with the final reviewed main commit after all art and logic merges, then recheck with the packaged engine and matching DLL. No native source or DLL was changed in this task. Local path/guard smoke test: `PLAYER_ENTRY_PATH_OK`; actual packaged engine and DLL are absent from this isolated checkout, and GUI launch awaits the parent's serial window.

Test cleanup: removed two reproducible high-load project copies (`test/work/ai-tech-perf-2o8p1qvj`, `test/work/ai-tech-perf-rfrpd15z`, 1,289,900,440 bytes total) and 467 Godot-generated untracked `.uid`/`.import` metadata files. Retained the committed raw performance JSON/logs and the preexisting `test/work/ai-tech-perf-20261017` directory, which was not created by this run.

## Continued gate, refit, and GUI verification

The source unlock table still has four original hightech gates: iron furnace after cleared stage 3, weapon focus and dense armour after cleared stage 4, and fragment furnace after cleared stage 12. `ShipDatabase` now retains these rows for authority while BattleGame filters their obsolete scientist notices from the popup and tutorial archive. The replacement factory tab is hidden until the stage-3 furnace gate; `AITech.eligibility`, `select`, and investment input enforce the gate in the model. Current explicit mapping in `data/ai_tech_tree.json`: singularity and resource refining use the furnace gate; weapon accuracy uses weapon focus; equipment reinforcement uses dense armour; fragment condensation requires its old furnace gate plus the enhancement system. Core/final research keeps its authored technology prerequisites. This mapping is awaiting the integration owner's review because the new nodes have no one-to-one original equivalents.

Equipment switch cooldown is `config_excel/config.xlsx`/`data/game_data.json` `equipmentSwitchCooldownSeconds=10`. `equipment_switch_remaining(category,index)` returns game seconds for the UI; `slot_equipment_locked` is the boolean form. The authoritative `equip_slot` and `unequip_slot` paths reject another switch on that slot, while upgrades and combat continue. Deadline state is saved against `productionElapsed`; pause freezes it, and stage clear or death clears all slots. Headless test: `EQUIPMENT_SWITCH_COOLDOWN checks=18 failures=0`; workbook/JSON projection: `CONFIG_PROJECTION_OK 38 38 10`.

The previously unrun `test/test_ai_tech_tree.gd` now passes `AI_TECH_TREE_CHECKS=49 FAILURES=0`, covering fresh-save lock and stages 3, 4, and 12. The old projectile lifecycle test originally produced an array out-of-bounds script error while returning process code 0; raw failure is in `docs/knowledge/tasks/projectile-lifecycle-before-20261017.log`. Its stage-one fixture had no armour and was cleared by refit death; its second `resize()` entry was empty; and its missile-retarget expectation contradicted the current no-retarget rule. After correcting only those fixture assumptions, it reports `Projectile lifecycle: 32 checks, 0 failures`.

Graphical main-scene smoke used Godot 4.7.2 with OpenGL on an RTX 2060, 90 rendered frames, exit 0, and a captured AVI in ignored `.runtime/gui-validation/main.avi`. The native DLL came from `D:/CodexBuild/space_idle/stage4-7-main-perf-20261017/candidate/space-battleship/bin/space_native.dll`; SHA256 `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`. Four native source files match this checkout by SHA256. The current `D:/放置` DLL has a different SHA and was not used. Five graphical high-load comparisons and enemy-bullet visual inspection remain for the next serial GUI window.

Direct task-branch push to `https://github.com/rlmclmc2-boop/space_idle` succeeded after the parent supplied the user's explicit Git authorization. Remote `feat/unlock-notice-copy-20261017` was `a6bb93256e1f7a89552be7b9994010958df358f3` at this checkpoint; no main merge or PR was made.

Affected headless checks after these changes: `AI_TECH_TREE_CHECKS=49 FAILURES=0`; `AI_TECH_TUTORIAL_CHECKS=6 FAILURES=0`; `GATE_CHECK_OK`; `TECH_STOP_BADGE_OK`; `EQUIPMENT_SWITCH_COOLDOWN checks=18 failures=0`; `Projectile lifecycle: 32 checks, 0 failures`; and `Unlock table: 707 checks, 0 failures` with isolated user data. `res://main.tscn --headless --quit-after 2` also exited 0. The five-mode graphical performance runner has a two-frame headless compile/smoke pass; its full graphical measurements are pending the next shared GUI window. The legacy jewel-furnace test remains an outdated scientist-flow fixture and currently raises an array bounds script error; it is not counted as passed.

A specification comparison found the singularity row's first-level time still at 20 seconds, while `docs/tasks/AI_TECH_TREE_20261017.md` specifies 60. It is corrected to 60 in `data/ai_tech_tree.json`; the newly added assertion yields `AI_TECH_TREE_CHECKS=49 FAILURES=0`. No other technology time or factor was changed. The unified `0<R<1` income factor still uses `max(1,1+log10(R)/5)` and therefore remains exactly 1 for that interval.

Workbook cell audit against pre-change `97007e78`: `CONFIG_XLSX_AUDIT_OK 47 existing rows unchanged; appended row 48`. The projected game config equals the workbook across all 38 config entries.

Five-mode rich headless comparison (same fixture/seed, 480 realtime frames on each of hidden page 0 and open factory page 1; raw JSON and per-mode logs named `ai-tech-investment-five-headless-*`):

| Iron / uranium per game second | Hidden events / snapshots / rebuilds | Visible events / snapshots / rebuilds | Hidden main p95 µs | Visible main p95 µs | Hidden / visible frame p95 µs |
|---|---|---|---:|---:|---:|
| 0 / 0 | 0 / 0 / 0 | 0 / 13 / 0 | 4408 | 3161 | 6927 / 6923 |
| 100 / 0 | 13 / 0 / 0 | 13 / 13 / 0 | 4409 | 3301 | 6920 / 6924 |
| 0 / 100 | 13 / 0 / 0 | 13 / 13 / 0 | 4028 | 3264 | 6919 / 6926 |
| 100 / 100 | 13 / 0 / 0 | 13 / 13 / 0 | 4286 | 3300 | 6924 / 6930 |
| 1000 / 1000 | 13 / 0 / 0 | 13 / 13 / 0 | 4342 | 3339 | 6927 / 6928 |

All hidden runs had node delta +3 from ordinary combat; all visible runs had node delta 0. These are CPU and headless frame timings, not graphical FPS. The graphical run and screenshots remain pending the serial window.

The GUI smoke AVI contains 90 MJPEG frames. `docs/knowledge/tasks/ai-tech-gui-smoke-frame-0.jpg` is the original first frame extracted byte-for-byte from its `00db` video chunk. Visual inspection confirms the new opening copy, equipment cards, and intact main scene at 1373x883. This short fresh-save capture has no enemy attack and cannot verify projectile occlusion.

Battle-point cooldown review: the shared `finish_combat_step()` now clears all per-slot switch deadlines as soon as an encounter has no surviving enemies, including normal travel transition, guarded repeats, final clear, and the native completion handoff that calls this method. `clear_level()` still covers direct and immediate stage completion, and death still clears deadlines in `begin_retreat()`. The load path restores the saved `productionElapsed` before filtering deadlines; `load_hightech()` subsequently reads the same value. `test/test_equipment_switch_cooldown.gd` includes a portable import into an already-running clock, nonfinal completion, and native waiting branch; raw run: `docs/knowledge/tasks/equipment-switch-cooldown-20261017.log.txt`, `checks=24 failures=0`.

## Prepared serial GUI runs

After the art owner releases the graphical window, from this worktree root:

```powershell
python space-battleship/test/perf_ai_tech_investment.py
& 'D:/放置/space-battleship/engine/Godot_v4.7.2-stable_win64.exe' --path space-battleship --audio-driver Dummy --disable-vsync --script res://test/capture_enemy_projectile_hull.gd
```

The first command runs five identical 480-frame rich-combat scenarios (`zero`, `iron`, `uranium`, `both`, `both_1000`) on hidden and visible factory pages, captures PNGs and raw JSON/logs in its printed `test/work/ai-tech-perf-*` directory, and checks the native DLL SHA before launching. The second command captures 12 frames and a position/damage trace under ignored `.runtime/enemy-projectile-hull`; it fires the authored `laser_mon` projectile from 90 logical pixels above the player. Its headless compile/logic smoke passed with 12 trace frames and 10 armour damage at frame 8; graphical pixels remain pending. Both commands use this isolated checkout; `D:/放置` is read only for the engine executable.

## Graphical five-input UI diagnostic and hostile projectile trace

GUI window was serially assigned by the integration owner, used for these two runs, then released for the level owner. Functional candidate: `feat/unlock-notice-copy-20261017@ff146621193cb9d9dd8f4401f00f3ae62de5bff0`; historical local main ref: `d2f5db1aa4b8b10e563456bde03eaf337635ccf3` (stale); parent-confirmed current remote main: `3a0f40283ae653d004f738277606b2a57bf7739c`, a descendant of the stale ref and ancestor of this candidate; original AI task base: `feat/ai-tech-tree-20261017@81968778c275798529770fcb0fec1eaa23866b66`. This candidate contains the first art wiring inherited from the base, not the concurrent art owner's later changes. No main merge was performed.

Graphical engine read-only from `D:/放置/space-battleship/engine/Godot_v4.7.2-stable_win64.exe` (SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`), Godot 4.7.2 OpenGL compatibility renderer, RTX 2060, 1373x883, vsync disabled and FPS uncapped. Native DLL in this isolated checkout came from `D:/CodexBuild/space_idle/stage4-7-main-perf-20261017/candidate/space-battleship/bin/space_native.dll`, SHA256 `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`. Native ownership remains with `addons/native_battle/src` (execution kernel, combat presentation, retained presentation, space_native.cpp); all four source byte hashes match that build candidate and this task changed no native source or DLL. The rich whole-game data fixture is `test/fixtures/galaxy_1_complete.json`, SHA256 `72148C9DE7E70D783D45ADDC2B16CB9D601180371F361D9747DF6321232FDBAF`; AI technology data SHA256 `75BF5D5A90A7232B77CFA2D3DAB115B13BE2EB2BC5E5CC24FD0751C923C92029`; config workbook SHA256 `B7EF041DB8912C64F9C52A7FB0698DD63AC0E5DBC89AB31F0D552FAFD6E9B192`.

These five investment modes are a focused AI UI diagnostic, not the required five-weapon high-load acceptance suite. All five used the same seed 1701, 480 measured frames after 15 warmup frames per page, rich combat fixture, and both hidden (`page=0`) and visible (`page=1`) factory views. Frame p95 is end-to-end measured microseconds, main p95 is script microseconds; draw calls are rendered p95 counts.

| Investment (iron/uranium) | Hidden frame p95 µs | Visible frame p95 µs | Hidden main p95 µs | Visible main p95 µs | Hidden/visible draw calls p95 | Hidden/visible row rebuilds |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| zero (0/0) | 6470 | 5681 | 3583 | 2791 | 371/393 | 0/0 |
| iron (100/0) | 6731 | 5266 | 3732 | 2732 | 370/385 | 0/0 |
| uranium (0/100) | 6549 | 5581 | 3768 | 2943 | 370/385 | 0/0 |
| both (100/100) | 6894 | 5981 | 4010 | 3074 | 371/385 | 0/0 |
| both_1000 (1000/1000) | 6990 | 5797 | 3989 | 2850 | 371/385 | 0/0 |

Raw per-mode JSON, engine logs, `summary.json`, and ten original full-screen PNGs are in `docs/knowledge/tasks/ai-tech-gui-five-20261017/`. The 1000/1000 mode's p95 frame time changed from zero by +520 µs on the hidden page and +116 µs on the visible page; this single uncapped sequential run is evidence for the tested fixture, not a hardware-independent FPS guarantee. Resource events were 0 in zero mode and 6–8 in invested modes; visible snapshots were 6–7, hidden snapshots 0; all modes had five retained rows and zero row rebuilds.

The hostile projectile capture used authored `laser_mon` speed/damage against a live player model, then rendered each 12-logical-pixel step on the actual main scene. `docs/knowledge/tasks/enemy-projectile-hull-20261017/` contains original PNG frames 04–08 and `trace.json`. Frames 05–07 visibly place the hostile bolt over the front/player hull while `armour_loss=0`; at frame 08 the bolt is removed and armour loss becomes 10. This reproduces the visual penetration/late-hit complaint; it does not yet change native or legacy presentation. The issue is a rendering/collision alignment question for review before a native source change.

The original five-weapon high-load suite is already archived under `test/evidence/ai-tech-tree-20261017/performance-final-art/`: `mixed_fixture.gd`, `combat_stress_fixture.gd`, `perf_driver.gd`, `run.py`, `suite.py`, `prepare.py`, and the original 25-run `summary.json`/traces/screenshots. Its cases are `mixed`, `laser`, `cannon`, `missile`, and `longLaser`. For a current-candidate replay, point the existing driver at isolated baseline and candidate checkouts (the retained `run.py` has stale paths to deleted `test/work` copies), use the existing `A absent / B closed / C open / D closed / E absent` sequence, 240 warmup + 480 sampled logical steps, and keep the same 15-enemy held-health fixture, seed, native DLL, 1x speed, GPU settings and page states. The suite must reject a run unless all five states within each weapon case have identical event counters, fixture stress counters, logical-step counts, and complete measured frame phases, with native admission and 1x checks true. Its archived `SUMMARY.md` is prior art baseline evidence, not proof for this newer candidate. GUI replay awaits a new serial window.

## Hostile projectile visual alignment on the current candidate

The original graphical capture in `docs/knowledge/tasks/enemy-projectile-hull-20261017/` showed an authored hostile laser visually inside the player hull on frames 05–07 while armour remained unchanged. The rendered ship occupies a different screen Y than its logical combat point, and the old fixed visual segment divided the screen distance to the ship center by the short logical projectile distance. This made the sprite outrun its collision.

The final repair scans the center column of the selected ship texture for its first visible alpha pixel, caches that hull-front offset, and uses the screen contact point for hostile laser/cannon visual segments, missile convergence, beam endpoints, and impact FX. It does not alter `BattleGame` or native projectile aim, flight, collision, damage, or timing. A provisional change to logical/native aim was rejected because it delayed this shot's damage from frame 08 to frame 17 and broke the high-load suite's event/stress identity. The final code restores the original frame-08 damage timing.

The repaired graphical 20-frame source capture is `docs/knowledge/tasks/enemy-projectile-contact-after-20261017/`: original frames 06–08, `trace.json`, and GUI engine log. Frame 07 has projectile screen Y 836.058 while visible hull contact Y is 849.348; frame 08 removes the projectile and reduces armour by 10. No pre-impact frame crosses the visible contact line. The dedicated headless test checks legacy/native target projection remains at the original rendered player center, the rendered bolt endpoint equals the hull front, and the authored shot still applies exactly one logical impact and one damage. It passed 7/7. This fixture uses the Frigate texture and the authored `laser_mon`; other ship silhouettes and projectile families still require separate visual review if they are reported to penetrate.

## Final five-weapon graphical replay

The original suite was replayed against the above final visual-only candidate in its own copied project. The absent side is the prior no-tree baseline `52a87c0e8db7e0fd5a9e4c01882a60515411bdca`; the candidate side is this isolated branch with the projectile visual fix. The original fixture/driver files, seed and 15 held-health enemies were reused. Every weapon case ran `A absent / B closed / C open / D closed / E absent`, 240 warmup and 480 sampled logical steps, native DLL SHA256 `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`, 1x, OpenGL Compatibility at 1373x883 on RTX 2060, uncapped FPS and VSync off. The five technology-investment input modes reported earlier remain a separate UI diagnostic.

All 25 runs exited successfully. For every run the 1x, native admission, sample-validity, 15-enemy, step-count and frame-phase checks passed. Within each weapon case, all five states had identical complete event counts and fixture stress counts. The runner's final `SUITE_OK five cases` had exit code 0; packaged raw JSON and system-load samples, engine logs, representative original PNGs, suite/driver/fixture scripts and summary are in `docs/knowledge/tasks/ai-tech-five-weapon-replay-20261017/`. The package summary SHA256 is `78945422E327B74E99B628FD79E193750B6295D99494CD5A44186C5D5E8F6268`.

| Weapon case | Absent A/E frame mean ms | Closed B/D frame mean ms | Open C frame mean / p95 ms |
| --- | ---: | ---: | ---: |
| mixed | 7.679 | 7.471 | 7.035 / 10.061 |
| laser | 5.869 | 5.556 | 5.198 / 8.330 |
| cannon | 8.169 | 7.827 | 6.870 / 10.322 |
| missile | 7.364 | 7.229 | 6.927 / 9.793 |
| longLaser | 9.054 | 8.908 | 8.287 / 12.778 |

These are measured wall frame times for this GPU/fixture, not hardware-independent FPS estimates. The open page changes the display, so its lower frame mean alone is not evidence that opening the tree accelerates combat. The bracketed A/E and B/D runs control sequential drift. A provisional physics-aim fix was run and failed event/stress equivalence; its superseded samples were discarded before this final replay, and no gameplay timing change is included in the candidate.

Final isolated headless reruns are preserved with the projectile evidence: contact 7/7, AI technology tree 49/49, equipment switch cooldown 24/24, projectile lifecycle 32/32, enemy attack pairs 230/230. Each process exited 0.
