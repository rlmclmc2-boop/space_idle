# Four-weapon role baseline under candidate A

**Decision state:** a comparable neutral-hull baseline for review, not a production parameter change, final role closure, or opening-stage approval. The subsequent [typed-defense review](TYPE-AXIS.md) gives physical/energy matchups priority over this sample's exact HP interval. The only test override is missile base damage 200 -> 120; the recovering target also uses the separate unmounted 1.0 s / 25% per second shield candidate. Laser 300/1.5 s, missile four per 2.4 s with its fast 0.4 s opener, cannon 1500/3.5 s, and beam 35/0.28 s plus charge remain otherwise fixed. The installed game continues to use 4 x 200 missiles and the draft enemy's original 1.8 s / 8% recovery.

## Comparable results

Each row uses one identical weapon slot at level 1, one level-1 weapon purchase with an authored cost of 50 of resource 1, the same 1.2 damage and cost growth factors, no enemy attacks, no high-tech or enhancement, fixed RNG seed 1729, and a 60 s observation limit. Weapon unlock stage still differs in the real game: missile after stage 1, cannon after stage 2, beam after stage 5. Values are legacy presented executor clear times in seconds. `>60` means the target remained alive at the observation limit, not permanent invulnerability.

| Target role and fixture | Pulse | 4 x 120 missile | Cannon | Beam | Supported interpretation |
|---|---:|---:|---:|---:|---|
| Low swarm: 10 x 100 HP | 15.17 | **6.23** | 35.17 | 15.67 | One missile per target and four concurrent tubes favor missile. |
| Medium pack: 6 x 280 HP | **9.10** | 11.07 | 21.10 | 14.40 | One pulse versus three missiles per target favors pulse. |
| Heavy pair: 2 x 5000 HP | 51.57 | 49.97 | **28.13** | 30.00 | Sustained heavy damage and fewer shots favor cannon; beam remains close. |
| Reactive heavy pair: same HP, up to three reduction stacks | >60 | >60 | **28.13** | >60 | Cannon's 3.5 s hits let the 2.2 s stack window reset; frequent hits stack to 40% damage. |
| Recovering shield: 1100 HP + 600 shield, 1.0 s / 25% per second | 12.13 | 28.22 | 10.55 | **6.05** | Beam suppresses regeneration; all weapons can clear. |

The first three rows and reactive variant combine `damage120-fixed-baseline.jsonl` with four missing comparisons in `role-gaps120.jsonl`; the medium 6 x 280 pulse/missile and low 10 x 100 rows are from the same fixed-baseline probe. Recovering shield rows are `shield120-focused.jsonl`. All have the same source weapon rows and slot/level setup. These comparisons define a **soft** role structure for these sampled targets, not exclusive weapon requirements or a globally optimal loadout. Stage 3 cannot require beam because it unlocks later. Level-6 pulse and level-6 candidate missile did clear the level-1 reactive fixture in 42.47 and 47.32 s respectively (`damage120-high-level.jsonl`), showing that investment can bypass the soft counter; those are not same-level comparisons with the level-1 cannon.

## Valid parameter intervals and level rounding

Let `P(L)` be ordinary pulse damage and `M(L)` one candidate missile's ordinary damage at the **same equipment level**. At level 1, `P=300`, `M=120`; both have 200 raw sustained damage per second (`P/1.5 = 4M/2.4`). A one-hit low target has `HP <= M`; the useful pulse-one-hit/missile-three-hit medium interval is `2M < HP <= P`, or `240 < HP <= 300` at level 1. This is a continuous 60-HP band, not a single tuned threshold. A heavy target with HP far above one cannon hit rewards its 1500/3.5 = 428.6 raw sustained damage per second; the 5000-HP fixture is 16.7 pulse hits or 3.33 cannon hits before combat modifiers. Group geometry, travel, overkill, type modifiers, and shielding still control actual clear times.

`ShipDatabase.equipment_growth()` geometrically grows both authored damages by 1.2 then rounds. At levels 1, 2, 4, 6, 10, and 20, `M/P` is 0.400, 0.389, 0.404, 0.400, 0.413, and 0.396. Across the explicitly checked ordinary levels 1–100 its minimum is 0.379 (level 26) and maximum 0.420 (level 71). Thus `2M < P < 3M` survives that finite range: the medium interval remains at least 16% of pulse damage and at most about 24%. This is a formula check under equal-level, equal-factor equipment projection, not a claim for all integer levels or arbitrary buffs. Enemy HP must be designed relative to these damage thresholds as progression changes.

For the recovering target, 25% of its 600 shield is **150 shield per second** once a full second passes without a hit. That wait is shorter than the pulse's 1.5 s repeat, allowing regeneration between pulses, whereas continuous beam's 0.28 s ticks prevent it. Measured regained shield was 542.5 pulse, 1732.5 missile, 755 cannon, and 0 beam. The missile was slow but made net progress. The 8% / 1.8 s original draft allowed no pulse regeneration in this fixture, so it could not prove the beam's suppression role.

The restored five-point stage-2 data has common 976-HP targets, making 120 damage a significant migration risk in that **old** layout. This does not decide whether to keep an all-purpose missile or reject candidate A in a redesigned opening. A future authoring pass should place early low and medium groups within the stated intervals, account for equal-slot purchase costs and unlock order, and verify actual income, enemy damage, and attainable upgrades before any authoritative Excel/JSON change. No 18-point integration or stage-18 replay occurred here.

## Source of native/legacy time offsets

`native-roles120.jsonl` now records every fire and hit clock and the `wave_clear` clock. The four native cases each admitted through the real compiler/session, fired, hit, killed, and handed off once. Their same-target hit counts and total hit amounts match legacy. Clear-time differences are **observations requiring design review**, not pass/fail tolerances:

| Fixture | Old clear | Native clear | Measured timing stage |
|---|---:|---:|---|
| Low swarm missile | 6.233 s | 6.183 s | First launch/hit both match at 0.400/1.133 s. Second four-tube launch ends 3.183 vs 3.167 s, third ends 5.600 vs 5.567 s. Last impact and `wave_clear` are 6.233 vs 6.183 s. |
| Medium pulse | 9.100 s | 9.017 s | First fire/hit both 1.500/1.517 s; sixth fire 9.083 vs 9.000 s and sixth hit/clear 9.100 vs 9.017 s. |
| Reactive cannon | 28.133 s | 28.000 s | First fire/hit both 3.500 s; eighth fire/hit 28.117 vs 28.000 s. Legacy `wave_clear` follows its final hit by one 1/60 s step. |
| Recovering beam | 6.050 s | 6.067 s | Legacy builds the beam at clock 0 and first hits at 1.000 s; native builds it at 0.017 s and first hits at 1.017 s. All later beam hits and clear carry the same one-step offset. |

The old presented loop in `presented_battle_game.gd:77–97` advances in 1/60 s steps and splits again at pending missile ejections. `game.gd:3060–3090` decrements a weapon's remaining cooldown each step, fires only when it becomes `<= 0`, and `weapon_cooldown_after_shot()` resets it to a fresh full interval. In these measurements, floating-step rounding leads to one extra 1/60 s step on each subsequent pulse/cannon/missile salvo. The native kernel's `combat_execution_kernel.h:1691–1700` schedules the next root at `clock + interval`, admitting events with a `1e-9` due comparison, and `:2499–2517` segments at ejection times. That accounts for the repeated salvo drift. Missile impacts also gain another step of delay in parts of the old projectile movement/impact path, as the matching first hit but later last-hit clocks show. The old beam lock is emitted at clock zero, while native's first segment starts its beam at the first 1/60 s advance. Wave completion is decided by `game.gd:4542–4563` after the old projectile step and by `native_execution_session.gd:159–170` after native feedback/handoff; the cannon trace localizes its final extra step between last hit and wave clear. No combat timing code was changed in this work.

The focused probe now asserts native admission, work, one handoff, death count, hit count, and total hit amount. It **does not assert any clear-time tolerance**; the final result is `NATIVE_ROLE_CONTRACT: 4 cases, 0 failures` for those structural checks. Raw native log SHA256 `534456ed0143fba8a3f284d421d8a8b4db0ec4937de5514024f186e8c3983146`; raw four-gap log `effb4047544f88ac3f8f309b180e624d2c3f0f3283661db9010524e8661ae83b`. The native DLL hash is in [BUILD.md](BUILD.md). These observations are at 1x; the documented `1e40` precision boundary remains unresolved.

## Next executable decisions and open risk

1. Decide whether the pulse/missile/cannon/beam soft roles and their visible cadence fit the intended opening. If yes, author the first three stages and purchase pacing **with** the candidate damage and shield changes in authoritative Excel, then regenerate JSON and perform a short, serial stage-2/3 pressure and resource check. The disconnected 18-point draft requires its frozen reward binding repaired before any integration.
2. If event-time parity is a release requirement, define an allowed time difference or a desired shared scheduling rule before changing either executor. Structural hit-count parity in four 1x cases does not decide that standard.
3. The user accepted approximate rather than exact boundary hit counts at `1e40`. Track the observed residual and stable role rankings; do not install a broad residual clamp or a second shadow HP ledger on this evidence.
4. Re-evaluate Memory recovery at higher enhancement levels under sustained incoming damage. The current nominal no-branch repair reaches 7.5% of maximum defence per second at effective level 30, versus 2.5% at level 10. The level-10 tests do not prove that high-level tanking is impossible. Stage-18 economy and pressure remain unverified.
