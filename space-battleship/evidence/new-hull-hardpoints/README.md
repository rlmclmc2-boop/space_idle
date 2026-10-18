# New player hull weapon mounts

Base: `506c2217`. The five PNGs in this folder are actual Godot 4.7.2 viewport captures of the approved player hull art with every physical weapon slot populated. Each hull was captured in a fresh engine process to avoid stale GLES texture state after repeated hull swaps in the capture harness. Weapon sequence: cannon, laser, missile, long laser, cannon.

| Hull | Slots | Capture |
| --- | ---: | --- |
| Frigate | 1 | [frigate-full.png](frigate-full.png) |
| Destroyer | 2 | [destroyer-full.png](destroyer-full.png) |
| Cruiser | 3 | [cruiser-full.png](cruiser-full.png) |
| Battleship | 4 | [battleship-full.png](battleship-full.png) |
| Heavy Battleship | 5 | [heavy_battleship-full.png](heavy_battleship-full.png) |

`test/capture_player_hardpoints.gd` checks each module's base against nontransparent hull pixels, checks that the rendered muzzle and launch muzzle projection coincide, and checks that all muzzles remain inside the viewport. The heavy hull also passed a low-anchor visible-bounds check. Five isolated captures exited 0 with no script errors. The existing `docs/tasks/fleet-13-20261018/verify_visual_fit.gd` also passed for all five hulls after this change.

`test/verify_player_hardpoint_geometry.gd` compares the live 3D bases and both muzzle ordinals with the independent logical battle pose across all 15 slots at center and low screen anchors. All 30 base and 60 muzzle comparisons passed; maximum drift was `0.000061` screen pixels. This verifies that the battle launch path and visible barrel now share the fitted art anchors.

To regenerate a capture, set `HARDPOINT_CAPTURE_DIR` to this folder and `HARDPOINT_ONLY` to one hull key, then run Godot with `--path space-battleship --script res://test/capture_player_hardpoints.gd` from the repository root.
