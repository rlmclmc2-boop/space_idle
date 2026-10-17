# Final integrated candidate acceptance (2026-10-17)

- Candidate: `feat/stage1-7-experience-20261017@da95e636c1ad2a5c6b8ce5d5c081fca2bc1fd5b2`; no main merge. Scope: five existing high-load weapon cases, verified player entry, matching native module, and repeat launch.
- Godot console: `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`; graphical entry: the same 4.7.2 build copied read-only from `D:/放置/space-battleship/engine` into an isolated checkout. OpenGL Compatibility, RTX 2060, 1373x883, VSync off, FPS uncapped.
- Native DLL SHA256: `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`. All four `addons/native_battle/src` files match the established build candidate byte-for-byte. The one allowed extension descriptor points to the local `res://bin/space_native.dll` for both Windows variants.
- Final data SHA256: `game_data.json` `6E824478461D81F4E5679899D18AED892B5B2BF91E332C6B4522A902CAA7BD0F`; `ai_tech_tree.json` `4B3D0FF83F327DBC6546DF08B598C5F90329A627E5731E82FBC14AC087903F53`.

## Five-weapon graphical replay

`ai-tech-final-da95-five-weapon/` holds 25 compressed original JSON traces and system-load samples, original engine logs, seven PNGs, runner/fixture source, and `summary.json` (SHA256 `44ACCF6AC186B8AE2430A1735A7A03C5108B078161B1836E63952D699386ED95`). Cases: `mixed`, `laser`, `cannon`, `missile`, `longLaser`; each ran A absent, B integrated closed, C integrated open, D closed, E absent, with 240 warmup + 480 sampled logical steps and 15 held-health enemies.

All 25 samples passed native admission, 1x, frame phase, and sampling checks. B/C/D have identical event and fixture stress counts within **all five** weapon cases. The historical no-tree A/E baseline is from `52a87c0e8db7e0fd5a9e4c01882a60515411bdca`; the final candidate changes level/monster/game data. A/E differ from B/C/D, so the original suite's five-state identity gate **failed** and exited 1. The old baseline comparison cannot be used to attribute frame time changes to the AI page. The five investment-input modes from the earlier branch remain a separate UI diagnostic.

| Case | B/D mean frame ms | C mean / p95 frame ms |
| --- | ---: | ---: |
| mixed | 7.670 | 7.009 / 10.126 |
| laser | 5.746 | 4.933 / 7.816 |
| cannon | 7.742 | 6.974 / 10.671 |
| missile | 7.076 | 6.400 / 8.947 |
| longLaser | 8.953 | 9.149 / 13.777 |

These wall frame measurements are from one sequential uncapped run, not a hardware-independent FPS guarantee or pure `BattleGame.tick` CPU benchmark. Open and closed pages draw different content.

## Player entry

`tools/play_main.py` now accepts the complete candidate as `BASE`. In a copied checkout under `test/work/entry portable 验收/`, the actual entry ran its validation and import then launched the graphical main scene twice using the same isolated test user data. Both short auto-quit launches exited 0; receipt, import/game logs, and the exact acceptance wrapper are in `ai-tech-final-da95-entry/`. The wrapper only substitutes `main` for the branch-name query because this is a task branch, and adds Godot `--quit-after 2`; all other Git source checks, DLL/version/descriptor checks, import, and main-scene launch use the entry itself. Production main-branch behavior still depends on merging without further runtime edits.

The first launch generated four `.translation` files solely under `space-battleship/docs/tasks/playtest-ui-art/evidence/`; the entry now excludes only those generated evidence files from its untracked-runtime rejection. It continues to reject a `.translation` file elsewhere. `test/test_player_entry.py` passed 12/12. After editor import, the final AI tree headless check passed 49/49 with no script errors; the pre-import parse error was caused by the new SVG lacking its Godot import cache.
