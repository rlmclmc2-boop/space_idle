# S12 sparse runtime candidate: review object

Runtime branch `impl/s12-transaction-integration` at **`42cc37c6d3470ab2e195df9c302de617a7402fa6`**. Main remains `31e79337741bf9860d69fff21dae6be994dacd00`. Audit core `c7cac7d6c242b2abd8656f92ee64fe8fe623b706` received a *limited* dot/original-astra dual PASS as an implementation input; this new runtime and its evidence have **not** received full dual PASS. S12/A07 remain open.

## Runtime connection

`sparse_wallet.gd` accepts old `{m,e}`, v1 integer, valid v2, and canonical v3 blocks. Signed base-10000 positions are exact strings. `GrowthNumber` routes v2/v3 validation, exact add/subtract/compare and ceiling through the sparse core; ordinary multiplication, division and power retain their previous routes. `BattleGame.cashflow_multiply` applies the sparse product only to real pickup and furnace factors and returns an explicit `work_budget` or invalid status before effects. The bounded product count is 50,000 actual block pairs, independent of exponent distance.

Equipment affordability, debit, refund, x10, MAX cache and native batch use the same exact wallet result. Legacy wallets retain their old shape until transaction; material currency retains its existing signed-int64 policy. Pickup and galaxy income add into the exact wallet, with sample/peak and whole-document preflight. Furnace block generation plans all new blocks for the call before changing its elapsed counters, peaks, UID, RNG or drop list. `SaveTransfer` uses `GrowthNumber.valid` for wallet and sample/peak fields in ordinary, backup and portable paths. The UI displays v3 with exact exponent text; finite reporting projections cannot authorize debit. Generator and Balance Lab direct consumers identify unsupported reporting domains explicitly.

## Executed probes

Run each `probes/audit_s12_*.gd` after copying it to `res://test/`, using Windows Godot 4.7.2 console, `--headless --path space-battleship --script test/<probe>`. The real `SpaceCombatKernel` DLL was loaded for the native probe. Raw logs below are from the committed runtime SHA above. The known sandbox `user://logs` and Windows root certificate warnings occur before probes and are not test assertions. Intentional unsupported reporting and work-budget errors are recorded in their probes; no `SCRIPT ERROR` occurred in the final logs.

| Probe | Result | Log |
|---|---|---|
| `audit_s12_transactions.gd` | 56/56 | `logs/transactions-sparse-final.log` |
| `audit_s12_native.gd` | 35/35 | `logs/native-sparse-final.log` |
| `audit_s12_compact_probe.gd` | failures=0 | `logs/compact-sparse-final.log` |
| `audit_s12_consumer_probe.gd` | failures=0 | `logs/consumers-sparse-final.log` |
| `audit_s12_size_probe.gd` | upgrade and pickup rejection atomic | `logs/save-size-sparse-final.log` |
| `audit_s12_sparse_runtime.gd` | 23/23 | `logs/sparse-runtime-final.log` |
| existing `test_equipment_switch_cooldown.gd` | 24/24 | `logs/equipment-switch-sparse-final.log` |
| audit-only `audit_s12_sparse_core.gd` | 3290/3290 | `logs/sparse-core-audit.log` |

The runtime probe verifies both real income orders for `10^1000000000-1 + 10^1000000100`, subsequent sparse auto pickup, furnace factors and pickup, wallet/sample/peak portable and ordinary/backup validation and reload, strict duplicate-block rejection, and rollback at a real 16 MiB whole-save boundary. The transaction probe covers insufficient funds without effects, single/x10/ten singles, MAX versus cached quote, refund and material order, v1/old/v2/v3 preservation, and exact material storage after a debit. The native probe covers finite ownership, high-stat handoff, unaffordable refusal, batch, and MAX work-budget refusal before handoff.

## Explicit work boundary

Synchronous equipment MAX, and reactor MAX for sparse or legacy large wallets, return `-1` for incomplete quote work after 512 steps or 40 ms; the equipment quote cache records `status:work_budget`, and batch preflights the sequential projected wallet before any purchase. UI disables MAX and shows an unavailable message while single/x10 purchases remain available. No partial affordable count is presented as the answer, and neither level nor wallet changes on this result. Sparse cashflow factor preflights at 50,000 actual block products and refuses the pickup/furnace production before its corresponding effects. The large-index test intentionally proves these statuses and side-effect boundaries. These are reviewable operation budgets, not gameplay level, wallet exponent, or price caps. Their thresholds and user presentation still require the full reviewers' acceptance.

No damage growth or economy formulas, S20 scoring policy, main merge, or later stage was changed.
