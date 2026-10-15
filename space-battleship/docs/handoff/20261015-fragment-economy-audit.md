# Fragment economy: static audit before tuning

The October 15 normal 1× new-save review observed about 0.6K fragments/min in stage 18 with roughly half of energy assigned to fragments, versus about 1.68K/min in a short stage 14 normal-point sample. These are not controlled A/B measurements. The authored reward structure nevertheless contains a clear reason for the direction: `jewel_kill_drop()` performs one fragment chance roll per killed enemy by default. The global chance is 0.2, and the stage's `jewelRatio` multiplies a successful fragment. Other bonuses, auto collection, combat time, and survival affect realized income.

The table sums visible enemy slots across every authored group at each stage. `base expected/clear` is `0.2 × enemy slots × jewelRatio`, assuming every enemy is killed and one roll per enemy. It is a relative opportunity count, not a per-minute forecast or a promise of actual income.

| Stage | Enemy slots | Jewel ratio | Base expected fragments/clear |
|---:|---:|---:|---:|
| 10 | 31 | 2.8 | 17.36 |
| 11 | 31 | 3.0 | 18.60 |
| 12 | 121 | 3.2 | 77.44 |
| 13 | 31 | 3.4 | 21.08 |
| 14 | 91 | 3.6 | 65.52 |
| 15 | 15 | 3.8 | 11.40 |
| 16 | 31 | 4.0 | 24.80 |
| 17 | 25 | 4.2 | 21.00 |
| 18 | 31 | 4.4 | 27.28 |
| 19 | 121 | 4.6 | 111.32 |
| 20 | 79 | 4.8 | 75.84 |

Stages 14 and 18 both have nine encounter groups across a 1000-unit route. Stage 14 has nine enemies in each of its first five groups and 15 in each of its next three; stage 18 has three and five respectively. Stage 14 therefore offers **2.40×** the base expected fragments per full clear (65.52/27.28), before any possible difference in clear time. This structural gap is consistent with the old-stage farming observation. It does not prove stage 14 is globally best. Stage 15 is a sharper low-reward valley; stage 19 is a high-reward peak. A single stage-18 multiplier patch would merely move the best farming point.

The enhancement purchase cost is `ceil(100 × 2^(target_level−1))`; the target level 10 purchase costs 51,200 fragments. Such exponential demand magnifies a low kill-frequency stage. Iron/titanium drops use enemy-authored amounts and `resRatio` through a separate path; uranium and energy allocation must be checked separately rather than inferred from fragment counts.

## Decision boundary

Do not add a stage-18-only payout or block jumping back. A durable adjustment needs an authored per-encounter fragment budget or clear reward floor that accounts for enemy count and expected clear time, then targeted checks around stages 12, 14, 15, 18, and 19. `candidate_rewards.gd` already validates custom per-enemy roll budgets against a bound reference group for candidate encounters; it should not be bypassed for the unused opening draft. Any economic change must preserve existing reward bindings and demonstrate that a player can fund the next meaningful growth step by advancing or retreating a few points inside the current stage. No economy values were changed in this batch because the available new-save rates are short samples and the current opening design is still a draft.
