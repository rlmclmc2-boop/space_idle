# Focused weapon balance evidence (2026-10-15)

All numbers come from isolated Godot 4.7.2 runs, fixed RNG seed 1729, the production stat cache enabled, one level 1 weapon mount, no enemy attacks, and a 60 second ceiling. The opening level and group fixture is restored from frozen commit `b6ab391e28ca55eb39827f95821bf94d95c8c8bb` in memory for the probe. Enemy HP and shield are multiplied by `k` along with derived player damage. The JSONL files contain first fire, first hit, kill time, applied HP/shield damage, regeneration, overkill, and reactive stacks, not just aggregate DPS. These are controlled mechanics probes, not playtest results.

## Measured effect of the authored changes

| Target fixture | Laser | Missile before 200 | Missile after 160 | Cannon | Continuous beam |
|---|---:|---:|---:|---:|---:|
| Five medium, 300 HP each | 7.58 s | 6.23 s | 6.23 s | 17.58 s | 12.00 s |
| Ten swarm, 180 HP each | 15.17 s | 6.23 s | 11.30 s | 35.17 s | 18.50 s |
| Two heavy, 5000 HP each | 51.57 s | 30.40 s | 37.88 s | 28.13 s | 30.00 s |
| Two heavy with reactive reduction | no clear by 60 s | no clear by 60 s | no clear by 60 s | 28.13 s | no clear by 60 s |

The authored missile base damage changes from 200 to 160 (same volley size and cooldown). Its swarm clear remains the fastest, while cannon takes over on heavy HP. Against medium enemies the laser has zero overkill at 300 HP; the missile is about 1.35 seconds faster, so this fixture does not establish a laser speed niche.

The recovering enemy `270007` remains 1100 HP + 600 shield. Old delay 1.8 s and recovery 8%/s produced **zero regeneration against the 1.5 s laser**; laser and beam cleared in 9.10 s and 6.05 s. With delay 0.8 s and recovery 35%/s, the laser clears in 16.68 s with 1505 shield regenerated, cannon in 14.07 s with 1711.5 regenerated, missile 160 in 37.88 s with 3937.5 regenerated, and continuous beam in 6.05 s with no regeneration. Missile still makes progress, but this defender clearly rewards continuous pressure. Level 4 laser clears in 7.58 s, so upgrades provide another way through. A tested 120 missile could not clear this shield in 60 s; that is why the smaller 160 change was chosen.

## Scale and executor checks

The 67 role probe rows use only `legacy_presented`. They include paired specialist/rival checks at `k=1,100,1000,100000,1e40`; the reported fields matched the `k=1` result within 0.001 while a residual clamp was active. **That clamp has been rejected and removed** because it could erase real health. These rows are historical candidate evidence and must be rerun before claiming high-scale equivalence. The 56-item native test covers direct kernel hit/defence operations, not the complete native firing chain. Its former 56/56 result also used the rejected clamp. Without it, 25 hits of `200*k` against `5000*k` leave `8e-13` normalized HP at `k=1e40`, causing two extra shots. Do not treat the former 56/56 file as current verification.

Native tests use the locally built copy of pinned godot-cpp and the isolated extension under `test/native-build`; no build output is committed. Both direct tests disable saves. Test fixtures and probes are in `test/`; generated local logs are excluded from Git.

Focused follow-up runs before removal of the clamp: Memory recovery pacing 22/22, neutral temporary protection 33/33, enemy shield timing 27/27, enemy shields 43/43, equipment growth 94/94, legacy direct scale 65/65, and native direct scale 56/56. The shield timing test needed its synthetic launch clock/ledger aligned with the existing monotonic-time contract. The balance-only simulator also needed its `jewel_equipment_stat` override updated to the parent six-argument signature; no production shot timing was changed for that test. Boundary cases are being rerun after removing the clamp.

## Scope limits

The first 18 point opening design remains a draft. The initial draft replaced frozen level 1–3 reward references and prevented normal game startup; the branch restores those three levels' original Excel and JSON entries while retaining unused draft enemy/group rows for review. Do not interpret this probe as full stage 18, economy, equipment purchase, player damage, or long play validation. The probe intentionally removes enemy attacks to isolate offensive timing. Godot reported resource leaks at probe exit; all probe runs exited successfully, but that diagnostic remains to investigate in the harness.
