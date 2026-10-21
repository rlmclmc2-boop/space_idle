# P1 scenario correction 1 — review required before official timing

**HISTORICAL / SUPERSEDED INPUT OBJECT.** Retained to show the first correction, including its still-incomplete transaction definition. Use only [P1_SCENARIOS_V3_AUTHORITY.md](P1_SCENARIOS_V3_AUTHORITY.md) for current inputs; it awaits dual confirmation.

This addendum preserves the original preregistration commit `b9ce803d5a2c16617bef3a0f689b768e40c25d6c` as evidence. It corrects the test definitions, not the P0/P1 gate or its thresholds. Dot identified the R-HALF, three-slot, high-start, block-construction, and edge-input omissions before any official timed run. **No P1 scenario is yet frozen for official timing**; dot and original astra must confirm this revision. Audit-only exploratory correctness runs may be labeled as such.

## Research R-HALF: full main `ai_tech_tree.advance` order

Use a valid active research node with required progress > 10, initial progress 0, `research_speed=1.0`, `aiTechInput["1"]=1`, input `"2"=0`, no level completion or native transition, and `dt=1.0`. The input factor for amount 1 is 1.0. Snapshot marks resource 1 affordable whenever balance > 0. The advance loop starts `step=remaining`; if `balance < amount*remaining`, it shortens step to `balance/amount`; it multiplies speed by input factor, caps step at the remaining research requirement, then computes `expense=float(amount)*step`, debits, increases progress by `step*speed`, decreases remaining, and repeats while remaining > 1e-10. Once balance is zero the next iteration has no paid input and completes the remaining time. This is the preserved gameplay sequence, including the exact finite fractional debit requirement.

| Initial resource 1 | First iteration | Second iteration | End after `dt=1.0` |
|---:|---|---|---|
| 0.5 | paid step 0.5, expense 0.5 | unpaid step 0.5, expense 0 | wallet 0, progress 1.0, paid-input event once |
| 1.5 | paid step 1.0, expense 1.0 | none | wallet 0.5, progress 1.0, paid-input event once |

For the 1.5 scene, a second `dt=1.0` call starts with wallet 0.5, pays 0.5 seconds, then advances the other 0.5 seconds unpaid. Ten separate `dt=0.1` calls from wallet 1.0 must run in the same order and preserve the baseline finite binary64 arithmetic; record each expense/balance/progress rather than assuming a decimal 0.1 identity. Add a second scene `aiTechInput["1"]=10`, wallet 5, `dt=1`, expected paid step 0.5 with factor `1+log10(10)/4=1.25`, then unpaid step 0.5: final progress 1.125, wallet 0. This distinguishes paid from unpaid progress.

## Transaction T-BATCH: ordered three-slot result

Use the main authored rows and slot order `laser`, `missile`, then `armour` as the fixed weapons→defence sequence. Laser and armour start at level 1; missile starts at level 19. All three use resource 1. The level-2 laser and armour quotes are 65 each (50×1.2=60, then sub-100 snap to 65). Start resource-1 wallet at **130**, resource-2 at 0, `degenerate_matter` wallet at **0**. Laser succeeds and leaves 65. Missile's target level 20 needs **10 materials** and fails before debit regardless of its resource price. Armour succeeds and leaves resource 0. Expected observable order: laser commits, missile rejects with no effects/descriptors, armour is still attempted and commits; receipt names precisely the first and last slots. Record the missile's independently quoted resource price and rejection reason. Do not simulate a fabricated failure or skip the third slot. Separately test first/middle/last insufficient cases and `x10` vs ten sequential purchases. Refund preflights *all* resource and int64 material credits before any write/event; one overflow rejects all slots.

## MAX starts, wallets and answer

All original level-1 distant scenes and their exact wallet formulas remain unchanged. Add ordinary scene `MAX-20`: start level 1, wallet `sum(P(2)..P(20))+floor(P(21)/2)`, material wallet `10`; expected 19 upgrades. For each target `T` in `3873,4001,10000,50000,1000000000`, add `MAX-HIGH-T`: start level `T-10`, resource wallet `sum(P(T-9)..P(T))+floor(P(T+1)/2)`, material wallet `sum(M(T-9)..M(T))`, expected 10 upgrades and first unaffordable `P(T+1)`. Resource 2 is zero; one laser slot, no income/refund/other slot. These high-start scenes supplement, never replace, the five fixed distant level-1 scenes. Query construction, exact wallet oracle/setup, cold prefix preparation, official query, and resume/cancel timing remain separately recorded.

## L-BLOCKS deterministic construction

For each cardinality `n=1,100,1000,10000`, make **two** canonical v4 candidates. `CONSEC-n`: blocks at positions `0..n-1`, each digit `1`. `REMOTE-n`: for n=1 use the single block at position `250000000`; for n>1 use positions `0..n-2` and `250000000`, each digit `1`. All position strings use the canonical unsigned decimal spelling, d is exact integer 1, positions sorted ascending, highest digit positive. Compare candidate to itself (0), add a unit at position 0, subtract that unit to recover exactly the original, encode→JSON→decode equality. Separately subtract itself to canonical zero. Record input/encoded byte lengths and actual occupied block count. This does not test only the far exponent while omitting 10000 blocks.

## Q-EDGE reproducible binary64 inputs

For each centre 10, 95, 100 use the IEEE-754 binary64 payloads below as `base`; `multiplier=0.0`, `level=2` to exercise the growth branch with exact pow(1,1). Construct by decoding the unsigned 64-bit payload in little endian; do not use ambiguous decimal literals or a platform `nextafter` implementation. The three inputs are centre−1 ULP, centre, centre+1 ULP.

| Centre | Below / exact / above bits (hex) | S09 expected integer price |
|---:|---|---|
| 10 | `4023ffffffffffff` / `4024000000000000` / `4024000000000001` | 5 / 15 / 15 |
| 95 | `4057bfffffffffff` / `4057c00000000000` / `4057c00000000001` | 95 / 95 / 95 |
| 100 | `4058ffffffffffff` / `4059000000000000` / `4059000000000001` | 95 / 100 / 100 |

For each value also record the exact binary64 decimal expansion and the independent S09 branch decision. Keep Q-LOW-25, Q-LOW-5 and Q-ZERO unchanged.
