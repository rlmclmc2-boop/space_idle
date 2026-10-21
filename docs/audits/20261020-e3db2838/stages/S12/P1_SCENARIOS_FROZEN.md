# S12 P1 fixed scenarios and full configuration

**HISTORICAL / SUPERSEDED INPUT OBJECT.** This preregistration was rejected during input review before official timing. Its errors and omissions remain visible for audit. The single current test table is [P1_SCENARIOS_V3_AUTHORITY.md](P1_SCENARIOS_V3_AUTHORITY.md), pending dot and original-astra confirmation; P0/P1 thresholds are unchanged.

Status: preregistered **before** any P1 implementation or measurement. Authority is `IMPLEMENTATION_PLAN.md` at `e806d458c9c836e636321aaa6c5759707e7dc5fc` and its linked `P0_CONTRACT_P1_GATE.md` / `P1_PERFORMANCE_PREREGISTRATION.md`. This addendum specifies concrete inputs; it does not alter their gates. Main baseline is `31e79337741bf9860d69fff21dae6be994dacd00`. Old runtime `2a6119564e1cffc07bf0b833c3118b97faf6d728` is reference only. Every source or generated benchmark input and log belongs under this audit directory. No player save, production script, native DLL, or main merge is used.

## Immutable input sources

| Source | Git blob at main | Use |
|---|---|---|
| `space-battleship/data/game_data.json` | `582d36199cb394127288e53eac16fb7eee57b4a6` | Authored laser level-one cost row: `res_1=1`, `cost_1=50`, `costMulti_1=0.2`; no second resource. Reactor data is out of this prototype. |
| `space-battleship/data/equipment_evolution.json` | `fbbc9b50d00dc889cc709c65fcd87db122b60f82` | `interval=20`, `material_id=degenerate_matter`, `material_cost_per_tier=10`. |
| `space-battleship/scripts/database.gd` | `0f2064fd4964ab26e39c12738f2f03392f8b5f79` | Existing per-level cost order and branch selection. |
| `space-battleship/scripts/reactor_integer.gd` | `45b806e2d9fa914a906fd5bbebd3847114e73a5e` | S11 decimal-factor reference; independent oracle must also prove each expected result. |

All money is nonnegative. Material wallet is a separate signed-int64 domain, with no automatic conversion to the money representation. Every ordinary MAX benchmark uses one laser slot; defence slot is absent. The first-price formula is the main row's **per-level** rule: level 1 costs `ceil(50)`; level `k>1` starts from binary64 `50 * pow(1.0 + 0.2, k-1)` when finite; for overflowing intermediate values use the same decimal-factor interpretation frozen in S11. For a positive value below 100, the price is `ceil(floor(value/10)*10+5)`, otherwise the established two-leading-digit rounded value is ceiled. Each level divisible by 20 also costs `10 * (k/20)` materials. No combat growth or income multiplier enters a price.

## Correctness scenes, exact wallets and stopping points

`P(k)` denotes the exact resource-one price just defined; `M(k)` is the material cost (zero except each 20th level). `Σ(a..b) P(k)` and `Σ(a..b) M(k)` denote exact integer sums, **not** float projections or results of the proposed MAX implementation. These expressions uniquely specify the complete wallet bytes; an independent oracle must materialize or rigorously bound them before a benchmark may claim an answer. A setup that cannot construct the specified wallet remains FAIL/PENDING, never a smaller substituted scene.

| ID | Initial level | Starting wallet (`resources["1"]`, `hyperspace.materials["degenerate_matter"]`) | Expected affordable upgrades | First unaffordable quote |
|---|---:|---|---:|---|
| `MAX-3873` | 1 | `(Σ(2..3873) P(k) + floor(P(3874)/2), Σ(2..3873) M(k))` | 3872; stop at level 3873 | `P(3874)` resource-one; remaining resource is `floor(P(3874)/2)` |
| `MAX-4001` | 1 | `(Σ(2..4001) P(k) + floor(P(4002)/2), Σ(2..4001) M(k))` | 4000; stop at level 4001 | `P(4002)` resource-one |
| `MAX-10000` | 1 | `(Σ(2..10000) P(k) + floor(P(10001)/2), Σ(2..10000) M(k))` | 9999; stop at level 10000 | `P(10001)` resource-one |
| `MAX-50000` | 1 | `(Σ(2..50000) P(k) + floor(P(50001)/2), Σ(2..50000) M(k))` | 49999; stop at level 50000 | `P(50001)` resource-one |
| `MAX-1000000000` | 1 | `(Σ(2..1000000000) P(k) + floor(P(1000000001)/2), Σ(2..1000000000) M(k))` | 999999999; stop at level 1000000000 | `P(1000000001)` resource-one |

For all five, resource-two wallet is zero; the material wallet is the exact triangular sum `10*n*(n+1)/2` where `n=floor(target/20)`, within signed int64 for these targets. The slot is `laser`, there are no discounts, unlock restrictions, upgrades in other slots, income, or refunds during the query. No level shortcut or candidate result supplies the oracle. The billion scene is deliberately distant from level 1; substituting a near-end starting level cannot pass its gate. Query construction, cold and warmed prefix preparation, and any independent oracle setup are timed separately and disclosed.

Additional fixed scenes:

| ID | Exact input and expected observation |
|---|---|
| `Q-LOW-25` | `base=1e-300*1e-8`, multiplier `0.195`, level `4001`; expected price 25. |
| `Q-LOW-5` | Same base, multiplier `exp(710/4000)-1` evaluated as binary64, level `4001`; expected price 5. |
| `Q-ZERO` | Base zero, multiplier 0.2, levels 1, 20, 4001; resource price zero and material rule still applies. |
| `Q-EDGE` | Decimal values immediately below/equal/above 10, 95, and 100 after multiplication; independent decimal interval oracle decides the branch and ceiling. |
| `L-REMOTE` | Legacy `{m:1.0,e:1000000000.0}` minus 1, then plus 1; separately add `{m:1.0,e:1000000100.0}` in both orders. Exact comparisons and compact storage must preserve each low unit. |
| `L-ENCODE` | `9007199254741003 - 10 = 9007199254740993`, then +1 and -1; primary/backup/portable JSON all preserve exact balances. Malformed v1, invalid old m/e, negative, NaN/INF and noncanonical candidate encodings reject with error before mutation. |
| `L-BLOCKS` | Canonical sparse inputs with 1, 100, 1000 and 10000 occupied decimal blocks, consecutive positions from 0 upward and separately positions `0,250000000`; compare, add, subtract, encode and JSON round trip. Report encoded bytes and actual constructed memory. |
| `R-HALF` | Research wallet 0.5, charge 1: cannot pay and wallet remains 0.5. Research wallet 1.5, charge 1: debit to 0.5; next tick requiring 1 cannot pay. Ten fractional charges of 0.1 from 1.0 retain the agreed finite binary64 branch behavior without a projection deciding affordability. |
| `T-BATCH` | One slot x10 cost equals ten sequential prices; insufficient wallet at last level produces zero change for this purchase. Two slots in weapons-then-defence order: first can buy, second fails, first remains bought, receipt lists only first. Refund of both preflights all credits and int64 material limit; overflow yields no credit/event. |
| `A-STALE` | Plan against one profile, replace profile with an equal-value copy, then commit: stale. Mutate a nested resource, material, level, or evolution field after plan: stale. Plan-only and encode-only leave original nested dictionaries, events and save-dirty bit unchanged. |
| `I-SOURCE` | Incoming source amount, production base, income sample, peak, run resource, event payload and source removal are checked independently. Failure preserves source and all outputs; success credits exact wallet while the other representations retain their original meaning. Projection failure is explicit and cannot veto a valid debit or mint income. |
| `M-CANCEL` | Start each MAX scene, cancel after the first incomplete slice; the result must report cancelled within 100 ms, with no wallet/event mutation. Resume only under the same value/revision dependencies; changing wallet, materials, slot level, evolution, a nested field, or profile object must report stale and discard the old answer. |
| `N-NATIVE` | Audit-only mock: compiler/preflight sees the same ordered successful slot receipts as legacy commit. A later rejected slot cannot install a numeric descriptor for it. A mismatch yields explicit reject/handoff state and preserves the already successful slot; no real DLL result is claimed. |

## Fixed platform and measurement protocol

- Windows host `BJNLPC-0459`; Godot 4.7.2. At execution record executable SHA-256, `--version`, CPU model, logical cores, physical/available memory, OS build, command, working path, engine import status, process exit code, raw stdout/stderr and isolated `APPDATA`/`LOCALAPPDATA` locations. Never use a personal save or default user directory. Native DLL: N/A for this audit-only project.
- Performance thresholds are frozen: full ledger compare/add/subtract and encode operation ≤4 ms each; each MAX work slice ≤4 ms including decode/validation/price/wallet work; cancellation observation ≤100 ms; complete MAX ≤2 s for the four ordinary scenes, ≤10 s for the billion scene. Ten independent processes per fixed case, with prewarm and official run shown separately. Record each run's full time, maximum slice, cancellation latency where applicable, encoded bytes, block count, peak resident memory, and whether setup was excluded or included. A single over-limit run fails its gate. Missing exact oracle, missing required cases, timeout or omitted memory data is PENDING/FAIL as specified in the frozen contract, never PASS.
- Currency compare/add/subtract are synchronous typed success/error. Only a MAX query may return pending/complete/stale/cancelled. Price and plan failures are errors; a pending query is never represented as zero. The full price/wallet/material work cannot be shifted to an unmeasured helper or warmup. Use independent integer/Decimal or algebraic bounds for expected results, never the prototype's own return as oracle.
