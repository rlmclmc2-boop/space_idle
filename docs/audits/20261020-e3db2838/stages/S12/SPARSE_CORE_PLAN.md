# S12 sparse exact wallet proposal (audit prototype)

Status: audit-side implementation and verification, not runtime acceptance. It supersedes the one-base v2 extension proposed in `OPEN_ISSUES.md` if both reviewers accept the evidence.

## Canonical contract

Transport shape: `{v:3, blocks:[{p:"<signed decimal integer>", d:<signed int>}, ...]}`. Each block contributes `d * 10000^p` exactly. Positions use canonical signed decimal strings, so a finite legacy float exponent beyond int64 can be converted without `int(e)` or `float(e)-offset`. Blocks are strictly ordered by numeric position, positions are unique, digits are in `[-5000,4999]` and nonzero, and the highest block is positive. Zero is the ordinary `0`. Additional fields, negative balances, malformed positions, unnormalized blocks, nested wallet values, and nonfinite inputs are invalid.

Addition combines matching positions. Normalize from low positions with `carry=floor((digit+5000)/10000)`, storing `digit-10000*carry` and inserting carry only at the immediately next position. There is no walk across empty positions. Subtraction uses signed addition and rejects a negative highest nonzero block. Comparison subtracts into a transient normalized sparse difference and reads its highest sign. `10^E-1` therefore stays two blocks for arbitrarily distant E.

Legacy `{m,e}` represents the decimal value of `String.num_scientific(m)*10^e`, consistent with S11. Convert its finite integral binary64 `e` to an exact signed integer string first, then apply the short mantissa's decimal scale using exact signed-position arithmetic. A v1 amount and ordinary `int` use their canonical decimal digits. Finite floats use their IEEE-754 payload to obtain exact decimal digits; fractional income is never silently discarded. A legacy value is not rewritten until its first transaction. `parts()` and display are projections, not authority for cost or debit.

Limits are applied to actual block count, work, and whole serialized document size. No rejection depends on the numeric gap between two positions. No general sparse multiplication, division, power, or S20 simulator policy is included. Any real cash-flow factor still requiring such a product must be identified and given a local exact contract before runtime integration.

## Direct impact and audit gate

| Area | Required boundary |
|---|---|
| `GrowthNumber`, `equipment_quote`, `game` wallet operations | Exact old/v1/v2/v3 comparisons and nonnegative add/subtract for payment, refund, batch and MAX; failure before wallet/event/level/dirty mutation. |
| Pickup, galaxy income, AI income | Exact addition into sparse wallet; sample/peak and actual save preflight must complete before effects. Locally inspect income factors and document any multiplication. |
| SaveTransfer, ordinary/backup/portable | Same strict schema; old untouched saves stay old; actual 16 MiB whole-document boundary. |
| UI, quote cache, native | Text and parts approximate only; quote and affordability exact; native receives only its supported domain or hands off before effects. |
| Generator and Balance Lab direct consumers | Ordinary-domain behavior unchanged; finite projections cannot flow back into authoritative wallet. |

Audit-side probe must cover swapped `10^1000000000-1+10^1000000100`, carry/borrow/cancellation/zero, fractional exactness, malformed and duplicate blocks, random small oracle comparison, and algebraic large-gap identities. Runtime integration follows only after this core and its evidence can be reviewed.
