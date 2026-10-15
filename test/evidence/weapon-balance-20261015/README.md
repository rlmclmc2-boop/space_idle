# Focused weapon balance evidence (2026-10-15)

The current candidate is authored in `config_excel/equipment.xlsx` and `config_excel/mon.xlsx`, with synchronized `data/game_data.json`: pulse laser 300 damage / 1.4 s cooldown, missile 3 × 200 damage / 2.4 s cooldown, and draft enemy `270007` at 1100 HP + 600 shield with 1.0 s recovery delay and 25% max shield/s regeneration. Compared with the original 4 × 200 missile and 1.5 s pulse, this changes salvo count and pulse interval; the previous 160-damage missile is superseded. The recovering enemy is still an **unmounted draft** after the first three levels were restored to their frozen reward binding.

All role timings below are controlled `legacy_presented` engine probes at normal 1×, fixed seed 1729, production stat cache enabled, one level-1 weapon mount, no enemy attacks, saves disabled, and a 60 s ceiling. These isolate offensive mechanics; they are not a player-run verdict or a native firing-chain test. `role-probe-safe.jsonl` records the exact outputs and `raw/role-k1.txt` retains the original Godot output.

| Target | Pulse | Missile | Cannon | Continuous beam |
|---|---:|---:|---:|---:|
| Five medium, 300 HP each | **7.00 s** | 8.52 s | 17.58 s | 12.00 s |
| Ten low HP, 180 each | 14.00 s | **8.52 s** | 35.17 s | 18.50 s |
| Two heavy, 5000 HP each | 47.60 s | 40.18 s | **28.13 s** | 30.00 s |
| Two heavy with reactive reduction | no clear by 60 s | no clear by 60 s | **28.13 s** | no clear by 60 s |
| One recovering shield, 1100 HP + 600 shield | 9.80 s | 18.43 s | 10.55 s | **6.05 s** |

The low-HP target needs one 200-damage missile; a medium target in the open interval `200 < HP <= 300` needs two missiles but only one pulse. This is a continuous HP band, not one exact-divisibility point. The authored targeting and travel simulation was checked at HP 220, 260, and 300 with 5–8 targets (`pulse-interval-final.jsonl` and `raw/pulse-interval.txt`). Pulse/missile clear times were 7.00/8.52 s for five, 8.40/8.77 s for six, 9.80/11.07 s for seven, and 11.20/13.35 s for eight. Missile's first hit can still arrive sooner than pulse; the pulse advantage here is full-group completion after the discrete two-hit missile requirement. The 1.4 s pulse change resolves the previously observed six-target exception at 1.5 s.

The recovering enemy is a soft counter: all four weapons can clear it, beam prevents shield regeneration and wins by 3.75 s over the next weapon, while more pulse levels remain another route. The earlier 35%/0.8 s candidate made the three-missile launcher unable to clear in 60 s; this is why it was reduced. The current 25%/1.0 s data are a draft role fixture, not established stage pacing.

## Scale and executor limits

`role-probe-safe.jsonl` has 20 normal-scale roles plus seven selected roles each at `k=100`, `100000`, and `1e40`. At 100 and 100000, selected first fire/hit, kill time, hit count, effective HP/shield loss, and shield regeneration matched 1× within 0.001. Reported overkill did **not**: recovering pulse differs by about 3 normalized damage and beam by 0.6 because `GrowthNumber.ceiling()` rounds fractional per-hit damage at 1× and the rounding quantum vanishes relative to large `k`. That is a real damage-amount difference, though it did not change the measured settled HP or kill time in these fixtures. A target near the integer boundary could behave differently.

At `k=1e40`, the heavy missile case needed **two extra hits** and 2.17 additional seconds. Exact-25-hit native direct damage similarly left `8e-13` normalized HP. No arbitrary residual clamp remains in the branch: the former `max_hp × 1e-12` clamp could delete representable health, as quantified in [the precision note](precision-boundary.md). The conservative result is that exact hit-count invariance at 1e40 is **contradicted here**. The `test_native_weapon_scale.gd` 59/59 test now explicitly bounds and reports this known residual; it does not call the 1e40 boundary exactly invariant. The 66/66 legacy direct test and 59/59 native direct test both preserve a representable 50-million-HP remainder. These tests cover hit, shield, defence, and repair equations, **not** a native four-weapon firing chain. See [build and DLL provenance](BUILD.md) and original outputs in `raw/`.

Against the final authored data and code, focused regressions also passed: Memory repair pacing 22/22, neutral temporary protection 33/33, enemy shield timing 27/27, enemy shields 43/43, and equipment growth 94/94. The corresponding `raw/test_*.txt` files are the original isolated Godot outputs, not reconstructed summaries.

The earlier `role-probe-160-rejected-clamp.jsonl`, `legacy-scale-rejected-clamp.txt`, and `native-scale-rejected-clamp.txt` are preserved only to audit why that candidate was rejected. `role-probe-before.jsonl` and `candidate-probe.jsonl` also describe earlier authored candidates. Do not combine their parameters with the final tables above.

## Remaining scope

The first 18-point opening design is a disconnected draft. Initial draft levels 1–3 broke a frozen hyperspace reward binding; their original Excel/JSON rows were restored, leaving draft enemy/group rows unmounted. Stage 18 continuous elites, Boss entry health, player incoming damage, energy/uranium economics, purchase timing, and long-session feel remain unverified here. No new long play was run. Godot emitted resource-leak diagnostics at the end of role probes; the probe processes exited successfully. Parent acceptance still needs the project constraints and targeted experience review.
