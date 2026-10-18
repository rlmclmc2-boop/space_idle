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

## Main-scene native battle

The following full 1440×900 `main.tscn` captures show the complete battle and equipment panels with every available weapon slot equipped. `test/capture_battle_hardpoints.gd` starts stage 1, group 2 with the local native battle extension, runs 180 frames, and writes an image and raw result for each hull. It disables saving while constructing the capture loadout.

| Hull | Slots | Full scene | Raw result |
| --- | ---: | --- | --- |
| Frigate | 1 | [battle-frigate-full.png](battle-frigate-full.png) | [JSON](battle-frigate-result.json) |
| Destroyer | 2 | [battle-destroyer-full.png](battle-destroyer-full.png) | [JSON](battle-destroyer-result.json) |
| Cruiser | 3 | [battle-cruiser-full.png](battle-cruiser-full.png) | [JSON](battle-cruiser-result.json) |
| Battleship | 4 | [battle-battleship-full.png](battle-battleship-full.png) | [JSON](battle-battleship-result.json) |
| Heavy Battleship | 5 | [battle-heavy_battleship-full.png](battle-heavy_battleship-full.png) | [JSON](battle-heavy_battleship-result.json) |

All five native runs passed: 2–12 player shots and 6–10 enemy hits per hull. Across the observed shots, the visible barrel muzzle, logical fleet muzzle, and actual launch origin differed by at most `0.000184` screen pixels. Direct-fire aim alignment stayed above `0.967` dot product, and turrets turned `0.109`–`0.187` radians. Missile launch fans intentionally spread away from the barrel axis and are excluded from the direct-fire dot threshold. All muzzle positions remained inside the battle view throughout the run. Final opaque hull bounds stayed inside the battle view; the lowest hull point was at most `908.1` of `960` view pixels, leaving at least `51.9` pixels at the bottom.

The native DLL used for these runs was a local validation build whose four native source files matched this checkout by SHA-256. The DLL and generated Godot import files are not part of this evidence commit. To regenerate, provide a matching native extension and set `HARDPOINT_CAPTURE_DIR` and `HARDPOINT_ONLY` as above, then run Godot with `--path space-battleship --script res://test/capture_battle_hardpoints.gd`.
