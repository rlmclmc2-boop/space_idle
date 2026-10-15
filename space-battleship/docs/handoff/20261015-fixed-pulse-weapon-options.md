# Weapon roles with the fixed 1.5-second pulse

**Decision state:** options for parent review only. Current authoritative Excel/JSON retain pulse `300 / 1.5 s`, missile `4 × 200 / 2.4 s`, and the existing `0.4 s` quick opening salvo. No option below was written to production data. The unmounted draft shield was restored to 8%/s after 1.8 s.

The pulse budget is `300/1.5 = 200` raw damage/s. Four 200-damage missiles every 2.4 s provide `800/2.4 ≈ 333` raw damage/s plus a faster opening. Against a medium target killed by one pulse and two missiles, the ideal sustained kill budget is `1.5 s` versus `2×2.4/4 = 1.2 s`; the missile has a structural advantage. The earlier four-missile/160-damage scan found no pulse win among 5–8 targets across sampled 180–620 HP points. Zero pulse overkill at exactly 300 HP has no resource value and does not fix this.

## Option A: one authored missile damage change

Keep four missiles, 2.4 s cooldown, and the 0.4 s opener; change single-missile damage **200→120**. This makes the ideal raw budget `4×120/2.4 = 200`/s, equal to pulse. A low-HP target with `HP≤120` takes one missile. A medium target in the continuous band `240 < HP ≤ 300` takes three missiles but one pulse. Fixed-seed `legacy_presented` measurements at 250, 280, and 300 HP gave identical timings within that band:

| Medium target count | Pulse 300/1.5 | Missile 4×120/2.4 |
|---:|---:|---:|
| 5 | 7.58 s | 8.77 s |
| 6 | 9.10 s | 11.07 s |
| 7 | 10.62 s | 13.48 s |
| 8 | 12.13 s | 13.72 s |

Ten low targets at 100 HP cleared in 6.23 s with missiles versus 15.17 s with pulse. Two 5000-HP targets cleared in 49.97 s with missiles versus 28.13 s with cannon. The reactive version did not clear with level-1 missiles inside 60 s, while cannon cleared in 28.13 s. This remains a soft counter: level-6 pulse cleared reactive targets in 42.47 s and level-6 missiles in 47.32 s. The original 8%/1.8 s draft shield admitted 120-damage missiles in 11.30 s; continuous beam cleared in 6.05 s and cannon in 7.03 s, so the draft shield does not yet make beam uniquely necessary.

**Cost:** 40% lower damage per missile than current. The `240–300 HP` pulse interval has width 60 HP; outside it, target distribution may change the winner. This option needs targeted progression and purchase-cost checks before adoption because a lower missile can slow single targets and the currently reported stage-18 bottleneck. It should not be chosen solely to make this fixture work.

## Option B: change missile damage and its own interval

Keep four missiles and the 0.4 s opener; test **160 damage / 4.0 s repeat interval**. The 300-HP medium requires two missiles. The longer interval yields a 160 raw damage/s sustained budget, 20% below pulse, while a 100-HP low target still takes one missile. The measured 5–8 medium-target pulse/missile times were 7.58/9.43, 9.10/9.67, 10.62/13.45, and 12.13/13.68 s. Ten low targets cleared in 9.43 s with missiles versus 15.17 s with pulse.

**Cost:** repeating salvos arrive 67% less often than the current 2.4 s rhythm, despite the quick first salvo. The longer visible gap may undermine the intended missile feel and could be worse for high-HP progression. This option changes two authored fields and was not checked against heavy or shield cases; it is a less economical candidate than Option A.

## Evidence and limits

`test/evidence/weapon-balance-20261015/damage120-fixed-baseline.jsonl`, `damage120-high-level.jsonl`, and `cadence160-4s-candidate.jsonl` retain each actual first fire/hit, kill time, hit count, applied HP/shield loss, regeneration, and overkill. Their raw Godot logs are in `raw/`. Each probe used one weapon slot, level 1 except the stated high-level bypasses, fixed RNG seed 1729, no enemy attacks, a 60 s ceiling, and the legacy presented executor. They do not demonstrate full player economy, stage pressure, or native weapon-chain equivalence. The candidate-only override lives in `test/probe_weapon_roles.gd`; authoritative game values are unchanged.
