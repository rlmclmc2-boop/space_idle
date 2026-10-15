# Fixed-weapon candidate A: focused shield and native evidence

**Status:** test-only proposal. The authoritative Excel/JSON remain laser 300 damage / 1.5 s, missile 4 x 200 damage / 2.4 s with a 0.4 s opener, and unmounted enemy `270007` shield recovery 8%/s after 1.8 s. The scenarios here override missile base damage to **120** and compare an independent recovering-shield candidate at **25%/s after 1.0 s**. Neither override is a production edit. Seed 1729, one level-1 weapon slot, no enemy attacks, 60 s ceiling; the native comparison is at ordinary 1x scale.

## Recovery shield: actual regeneration and progress

The target starts with 1100 HP and 600 shield. `effective_shield_loss` includes repeated damage to regenerated shield. Every row killed the target; final net depletion is the initial 1700 pool. This shield is a soft counter: continuous beam prevents regeneration while pulse, missiles, and cannon still make progress.

| Recovery delay/rate | Weapon | Actual shield regenerated | Effective shield damage | HP damage | Kill time |
|---|---|---:|---:|---:|---:|
| Original 1.8 s / 8%/s | Pulse | 0 | 600 | 1100 | 9.10 s |
| Original | Missile 4 x 120 | 48 | 648 | 1100 | 11.30 s |
| Original | Cannon | 82.4 | 682.4 | 1100 | 7.03 s |
| Original | Beam | 0 | 600 | 1100 | 6.05 s |
| Candidate 1.0 s / 25%/s | Pulse | 542.5 | 1142.5 | 1100 | 12.13 s |
| Candidate | Missile 4 x 120 | 1732.5 | 2332.5 | 1100 | 28.22 s |
| Candidate | Cannon | 755 | 1355 | 1100 | 10.55 s |
| Candidate | Beam | 0 | 600 | 1100 | 6.05 s |

The original 1.8-second delay lets the 1.5-second pulse continually reset recovery, leaving beam with little distinct shield suppression benefit. The 1.0-second candidate allows shield to regenerate between pulses. The missile's 1732.5 regained shield exceeds the entire original shield pool and its clear becomes slow, yet the target is not invulnerable. Cannon's 1500-damage hits also overcome recovery. These observations isolate this no-attack fixture; they do not establish a stage-3 beam requirement, especially because beam unlocks only after stage 5.

## Native admission through kill and handoff

The probe compiles the actual `BattleGame` configuration, calls `admit_native_compiled_execution`, advances its `SpaceCombatKernel`, consumes fire/hit feedback, kills the targets, and records its automatic handoff. Ten and six targets use `native_rich15_layer2`; one and two targets use `native_low_contract`. Every native case admitted, killed all targets, and made **one** wave-complete handoff. `old_game_callbacks` remained 0 while native owned combat. The native DLL SHA256 is `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b`; source/build provenance is in [BUILD.md](BUILD.md).

| Fixture / weapon | Legacy clear | Native clear | Hits both | Native root attacks / deaths / physics visits |
|---|---:|---:|---:|---:|
| 10 x 100 HP, 4 x 120 missile | 6.233 s | 6.183 s | 10 | 3 / 10 / 563 |
| 6 x 280 HP, 300/1.5 pulse | 9.100 s | 9.017 s | 6 | 6 / 6 / 6 |
| 2 x 5000 HP reactive, cannon | 28.133 s | 28.000 s | 8 | 8 / 2 / 0 |
| 1100 HP + 600 candidate shield, beam | 6.050 s | 6.067 s | 19 | 1 / 1 / 0 |

Both executors reported the same total hit amounts (1200, 1800, 12000, and 1710 respectively), first missile/pulse/cannon fire and first hits. Beam native fire and first hit occurred one 1/60-second tick after legacy. Clear time differences of 0.017–0.133 s are observable and are explained by event-stage measurements in [ROLE-CLOSURE.md](ROLE-CLOSURE.md). The focused script fails on denied admission, missing native work/handoff, or different hit count or amount; its final line was `NATIVE_ROLE_CONTRACT: 4 cases, 0 failures`. No clear-time acceptance threshold was authorized or asserted. This is selected outcome evidence, not exact event-time identity or a general native equivalence proof. The existing `1e40` exact-hit discrepancy remains recorded by direct tests as a diagnostic under the user-approved relation-stability criterion; the tests now exit zero when their other checks pass.

## First three stages and purchase consequence

The live first-three-stage level rows are currently the **restored frozen five-point rows**, not the disconnected 18-point proposal. The missile unlock follows stage 1, cannon follows stage 2, and beam follows stage 5. Therefore a missile damage cut cannot change stage-1 purchases, but it can change stage-2 entry and stage-3 shield fights. In the frozen rows, `ceil(enemy.health * lifeRatio)` gives stage-2 HP groups of 976 (60 enemies), 2327 (13), and 6980 (2), with no starting shield. At unmodified raw damage, 976 HP takes 5 missiles at 200 but 9 at 120; 2327 HP takes 12 versus 20; 6980 HP takes 35 versus 59. These counts deliberately omit type resistance, bonuses, travel, targeting, and concurrent slots, so they are **threshold warnings**, not clear-time predictions. Stage 3's seven high-HP enemies are 14540–46528 HP; cannon is already unlocked there.

The missile's level-1 purchase row still costs 50 of resource 1 under candidate A. `equipment_growth()` uses a geometric 1.2 factor with rounding for both damage and costs. A candidate missile needs level 4 to regain current level-1's 200 damage (`120 -> 140 -> 170 -> 210` by the database rounding rule); levels 2–4 add 65 + 75 + 85 = 225 resource 1 on the same slot. This is a migration risk in the restored old stage-2 layout, while the target-role probe's 100-HP low group is far below its authored HP. It does not veto a redesigned opening built around the new roles. Candidate A has **not** earned a production adoption from these fixtures; a new progression and purchase-cost design must accompany it before changing the authoritative missile row or shield enemy.

## Reproduction and inputs

`shield120-focused.jsonl` and `native-roles120.jsonl` are the exact extracted rows. `raw/shield120-focused.txt` and `raw/native-roles120.txt` are the isolated Godot logs, including import output and exit warnings. Execute one probe at a time with `SPACE_BALANCE_SHIELD120=1` or `SPACE_BALANCE_NATIVE_ROLES=1` and `python test/run.py probe_weapon_roles.gd --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --headless --timeout 120`. The runner copies the existing DLL only for native mode. Both isolated process exits were 0; the Godot logs report leaked instances/resources at process exit, as prior probes did. No production data or native source was changed in this focused pass.

Input SHA256: `game_data.json` `f3f6a3a1797f0b95ebd72410ec01318a5d7663698be5fee51d6f647695b1543b`; equipment Excel `50b4835e8aa2bce0e6f4a981fe582fcac10281792c9284ecefe25f78f581dab5`; monster Excel `6640c467f9cd7fda46da942621c5b5663cda6bc81cfb0a87e14b4ba6ca1f26c2`. Raw shield log SHA256 `78795c741e8e0fac96e6a4608ffc3e459d0b51726717ae86dfe6f5d725904195`; final native event trace `534456ed0143fba8a3f284d421d8a8b4db0ec4937de5514024f186e8c3983146`.
