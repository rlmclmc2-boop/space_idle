# S12/P1 audit-only MAX-APPROX-v1 result

Authority: [the unique implementation plan](../../IMPLEMENTATION_PLAN.md) and [the frozen amendment](P0_P1_EXTREME_MAX_AMENDMENT.md) at `0ec96ce39c0fd2af3b45d7b5de23f3938a0dda27`. This is an executable prototype in `p1_proto/`, not a game-script change or a P1 PASS. It uses the frozen fixed experiment: laser base 50, growth `0.2` (binary64 factor `1.0 + 0.2`), start level 1, material interval 20. Other price factors, levels, zero and low-value branches, complete profile saves, UI and native handoff are outside this result.

## Method and invariant

`max_approx_probe.gd` quotes the first 257 levels with the original exact price function. If the 257th purchase is not affordable it returns an exact count in 0..256. Otherwise it searches the first unaffordable count using a conservative fee upper bound and exact material total; if 257 is not affordable under that bound, it returns 256 with its exact fee. It does not scan the extreme count level by level. The threshold chooses the rule, never a gameplay level limit.

For the remaining terms, `approx_bounds.gd` derives the exact decimal coefficient of the binary64 growth factor, then uses directed 32-digit interval arithmetic and binary power/series composition. The experiment encloses the original rounded high-price branch with 0.95 and 1.05 times the unrounded geometric sum. It produces sparse integer bounds `L <= C <= U` and verifies `25*U <= 28*L + 24`, equivalent to the amendment's `U <= ceil(1.12*L)`. The price printed in the quote and removed from the wallet is the same `U`; material `M` uses the exact tier sum. A failed bound, arithmetic, material, wallet, or host check returns an explicit failure without a live debit. The finite original-price inputs through target 3872 were checked individually; the fixed higher-level analytical enclosure and the directed-series implementation remain a fixed-configuration prototype, not a universal pricing proof.

The fee calculation runs in a Godot worker while the main thread awaits frames; 257-item setup also yields. The search uses exponential bracketing and binary search, then records the next rejected candidate. It does not stop at a clock deadline or substitute a truncated affordable count. The synthetic `HostState` keeps a Dictionary profile and binds the quote to owner identity, profile/config identity and generation, full snapshots, and exact quote text. Commit rechecks them, calculates both debits, then publishes one replacement Dictionary. A future product interface must still prove equivalent ownership and save admission.

## Raw evidence and independent checks

The `p1_proto/exploratory_approx_*_freeze.{stdout.log,stderr.log,meta.json}` triplets are the frozen Godot 4.7.2 Windows executions, generated through `run_probe.py` with isolated app data. Their JSON `success:true` and process exit 0 are prototype outcomes; the engine also printed shutdown RID-leak diagnostics, retained in the raw logs. `verify_approx_bounds.py` independently builds the exact binary64 factor with Python Decimal and checks six count intervals plus 3,617 original finite-price targets; see [raw result](p1_proto/exploratory_approx_bounds_independent_1.log). `verify_approx_quotes.py` reads the fixed compact Godot price export (`6b376b85a21a303481f1e64a88f44ec956777018edab1fbc636c540c40aa5f15`) and compares exact totals, material, displayed/debited fee, wallet remainder and the next boundary; see [raw result](p1_proto/exploratory_approx_quotes_independent_freeze.log).

| Fixture | Result | Full wall time | Main frame gap | Independent result |
| --- | --- | ---: | ---: | --- |
| exact256 | exact 256 | 1.048 s | 16.697 ms | exact count and fee |
| fallback256 | approximate mode, exact fee for 256 | 1.066 s | 16.686 ms | original exact maximum 257; upper fee rejects 257 |
| medium compact wallet | approximate 47,959 | 1.804 s | 16.691 ms | original exact maximum also 47,959; upper fee 4.9911% above exact; next upper fee rejects 47,960 |
| far compact wallet `10^1000000000` | approximate 848,867,438 | 2.387 s | 16.700 ms | direct Decimal tail enclosure; exact material consumed 9,007,198,921,435,060; next tier exceeds material |

The billion fixture uses a tiny sparse v4 wallet rather than constructing a billion-digit integer. Its material balance is the signed-int64 maximum; 333,305,931 remains after submission. The fee magnitude is about `10^67214383`; this is a mathematical result of this fixed experiment, not a claim that every such transaction meets whole-save or UI constraints. Medium and far cases both report the bound certificate and exact quoted/debited wallet difference in the raw logs.

The `stale`, `wallet_stale`, `config_stale`, `silent_replace`, and `tamper` frozen triplets all reject without an additional live debit after, respectively, host replacement, in-place wallet change, config replacement, equal-value Dictionary replacement, or changed quote text. The `cancel` triplet requests cancellation during worker activity, reports `cancelled` with no live change, and measures 31.024 ms from request to stop with a 16.694 ms maximum observed frame gap. These are single-process exploratory checks, not ten-run certification or proof that every front-end dependency has been captured.

## Gate

The fixed MAX-APPROX-v1 prototype has no observed fee-bound, overdraft, material, or same-quote debit counterexample in these fixtures. The historical exact-billion linear MAX and 10,000-block public ledger timing failures remain failures. The public ledger's full validation/commit/save costs, general price configurations, supported-domain handoff, native and full-game save/preview/collector consumers, and independently repeated timing still need review. **P1 is NOT PASSED; P2/product connection and main merge remain closed.**
