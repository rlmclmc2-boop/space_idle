# Candidate-A role stability at five proportional scales

**Exploratory neutral-hull question:** Does the *winning weapon and advantage* stay recognizable when enemy HP/shield and player weapon damage are multiplied by the same factor? The user does not require identical last-hit counts at numerical boundaries. This is finite evidence at `1`, `100`, `1000`, `100000`, and nominal `1e40`, not a proof for every scale or effect combination. Physical/energy matchups are the primary design axis; see [the typed-defense review](TYPE-AXIS.md). These neutral fixtures alone do not close weapon-role design.

The test-only combination is laser `300/1.5 s`, missile **4 x 120/2.4 s** with first salvo at 0.4 s, cannon `1500/3.5 s`, and beam `35/0.28 s` plus its existing ramp. The shield candidate is 1100 HP + 600 shield, 1.0 s delay, 25% of maximum shield per second. The authoritative equipment and enemy Excel/JSON remain at 4 x 200 missiles and the draft enemy's 1.8 s / 8% shield recovery. One level-1 slot, identical purchase cost, fixed seed 1729, no enemy attacks, and the same geometry apply in each comparison. `test/probe_weapon_roles.gd` scales enemy HP/shield and the relevant equipment damage together; timers and percentages are unchanged.

## Measured outcome

The four role comparisons below produced the **same entries at all five scales** within each executor; each line lists winner versus nearest measured rival at every scale. The reactive variant is included because its cadence mechanic is a separate soft counter. Times are seconds; the percentage is `(rival time / winner time - 1) x 100`, the extra time the rival needs relative to the winner. `>60` means no clear within the observation limit.

| Role | Old presented: winner / rival | Advantage | Native compiled: winner / rival | Advantage |
|---|---|---:|---|---:|
| 10 x 100 HP low swarm | Missile 6.23 / pulse 15.17 | 143% | Missile 6.18 / pulse 15.02 | 143% |
| 6 x 280 HP medium pack | Pulse 9.10 / missile 11.07 | 21.6% | Pulse 9.02 / missile 10.98 | 21.8% |
| 2 x 5000 HP heavy pair | Cannon 28.13 / beam 30.00 | 6.6% | Cannon 28.00 / beam 30.03 | 7.3% |
| 2 x 5000 HP reactive pair | Cannon 28.13 / pulse >60 | At least 113% | Cannon 28.00 / pulse >60 | At least 114% |
| 1100 HP + 600 recovering shield | Beam 6.05 / cannon 10.55 | 74.4% | Beam 6.07 / cannon 10.50 | 73.1% |

The heavy cannon edge is the narrowest, about 1.87–2.03 s in these fixtures, so later content or bonuses could reverse it. The reactive pulse killed one of two targets but did not finish by 60 s at every tested scale; level-6 bypass was separately shown at 1x in `damage120-high-level.jsonl`. All **66 native configurations admitted** through the real compiler and performed native work. The 1x native winner/rival pairs here extend the earlier four end-to-end cases; all four original native cases also observed one wave-complete handoff. Each run's admission, work metrics, hit count, clear state, and time are in the JSONL, not inferred from direct `hit_handle` calls.

## Middle interval boundaries

At level 1, two candidate missiles deliver 240 damage and one pulse delivers 300, so `240 < HP <= 300` is the one-pulse/three-missile target interval before type modifiers. For six neutral-armour targets, the inside points 241 and 300 were checked at **all five scales**. The immediate outside points 240 and 301 were additionally checked at 1x and `1e40`:

| HP per target | Old pulse / missile | Native pulse / missile | Winner and reason |
|---:|---:|---:|---|
| 240 | 9.10 / 6.47 | 9.02 / 6.42 | Missile; two hits suffice. |
| 241 | 9.10 / 11.07 | 9.02 / 10.98 | Pulse; missile needs three. |
| 280 | 9.10 / 11.07 | 9.02 / 10.98 | Pulse; interior point, all five scales. |
| 300 | 9.10 / 11.07 | 9.02 / 10.98 | Pulse; upper inclusive edge. |
| 301 | 18.20 / 11.07 | 18.02 / 10.98 | Missile; pulse needs two. |

At both tested outside-edge scales, all hit counts and winners followed this interval. This does **not** make all near-boundary floating calculations exact: the separate 25-hit `1e40` diagnostic still has a positive normalized residual around `9.28e-13`. The test only shows no reversal for these selected candidate-role targets. Input rounding, per-hit ceiling, added buffs, enemy type resistance, and long attack sequences remain possible sources of a different near-boundary result.

## Mathematical scale audit and gate

The probe multiplies both sides' authored damage/pools by `k`; absent absolute rounding, a fixed percentage of damage, shield regeneration and each HP threshold is unchanged in normalized units. Timers, volley grouping, beam charge, and reactive stack windows are independent of `k`. This predicts stable roles but does **not** certify numerical implementation: source HP and damage are separately rounded to binary64, `GrowthNumber.ceiling()` has an absolute quantum, and repeated subtraction can accumulate error. Those are why the actual `1e40` runs above were needed and why they do not prove stability at every magnitude.

Under the user's relation-stability criterion, the five selected neutral-hull scales support further review of candidate A; they do not justify production adoption on their own. The direct old/native formula contracts still verify ordinary damage and true small-residual preservation; their exact 25-hit `1e40` mismatch is now an **observed diagnostic**, not a failing acceptance gate. The new isolated runs report legacy **66 checks, 0 failures** and native **54 checks, 0 failures**; both record one nonzero extreme-boundary observation. No shadow health state, residual clamp, or combat timing framework change was made.

## Reproduction and provenance

`candidate120-scales-legacy.jsonl` holds 60 new old-executor rows; `candidate120-scales-native.jsonl` holds 66 native rows. `candidate120-interior-legacy.jsonl` adds the eight old-executor 280-HP interior rows at the four larger scales. The 1x old low/heavy/reactive/shield and 280-HP medium comparisons reused the earlier same-condition `damage120-fixed-baseline.jsonl`, `shield120-focused.jsonl`, and `role-gaps120.jsonl` instead of repeating them. The raw isolated logs are `raw/candidate120-scales-legacy.txt`, `raw/candidate120-scales-native.txt`, `raw/candidate120-interior-legacy.txt`, `raw/test_weapon_scale_contract.txt`, and `raw/test_native_weapon_scale.txt`.

Run one mode at a time through `python test/run.py probe_weapon_roles.gd --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --headless --timeout 360`, with `SPACE_BALANCE_SCALE_CANDIDATE=1`, `SPACE_BALANCE_NATIVE_SCALE_CANDIDATE=1`, or `SPACE_BALANCE_SCALE_INTERIOR=1`. The native mode uses the same isolated DLL SHA256 `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b` documented in [BUILD.md](BUILD.md). The `game_data.json` input SHA256 is `f3f6a3a1797f0b95ebd72410ec01318a5d7663698be5fee51d6f647695b1543b`. Raw log SHA256 values are legacy `4763913125e978db1dba7462f272fc2a40dc146dc5c29e2ed80bb3102008919d`, native `8ff42ede56a69d22e40e070d6322716ad4da27ca304ee15217c2eb7dcd8fd53d`, interior legacy `cf040d7fc71e8b44a4e2d3889938fa858359b67a38451f2ebe35acce7d76dd6c`, direct legacy `d215873088be712f13cd39c9340308a6e07b79a90c265cc0b9a9762683cfe35d`, and direct native `1f5eacf2b56cc3bc911d10f45b3638775caf24a29e16428a3c8a50a4dc623198`.
