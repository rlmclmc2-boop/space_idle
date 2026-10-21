# S12 candidate 82492c5: verification and open boundary

Runtime branch: `impl/s12-transaction-integration` at `82492c5ed267044e66840ed3fd99e9aad707b814`. Evidence branch: `audit/code-review-e3db2838-20261020`. Main remains `31e79337741bf9860d69fff21dae6be994dacd00`. This is an implementation handoff, not A07 closure or a dual PASS.

## Fixes since the prior candidate

- `compact_wallet.gd`: strict integer coefficient validation rejects a v2 value with `delta:1.5, places:0` before `change` can normalize it. A legacy income at the same or adjacent exponent can merge with a compact wallet base only when the resulting legacy mantissa round trips as the exact same printed decimal; the signed exact debit remains attached. This covers `9e1e9 - 1 + 2e1e9 = 1.1e(1e9+1) - 1` and both adjacent-exponent directions.
- `game.gd` and `save_transfer.gd`: an actual adjacent-exponent iron pickup keeps a large `furnaceIncomePeak` in the numeric wallet domain, preflights the projected whole portable document before changing the drop, wallet, sample, or save dirty flag, and saves/reloads the peak through the ordinary `g` numeric schema. Furnace output uses the existing factors in their original order via `GrowthNumber` operations.
- The earlier candidate fixes material wallet integer precision, exact `+1` after a debit, old/v1/v2 round trips, batch/MAX/cache, native handoff, and the scoped generator and Balance Lab direct consumers. These are exercised again below.

## Reproducible evidence

Run from `space-battleship` using the Windows Godot 4.7.2 console and the real `SpaceCombatKernel` DLL (not committed). The scripts are in `probes/`; copy them to `res://test/` and run `--headless --path . --script test/<name>`. Raw logs are in `logs/*-final.log`.

| Probe | Result | Log |
|---|---|
| `audit_s12_transactions.gd` | 56/56 | `transactions-final.log` |
| `audit_s12_native.gd` | 31/31 | `native-final.log` |
| `audit_s12_consumer_probe.gd` | failures=0 | `consumers-final.log` |
| `audit_s12_size_probe.gd` | rejection_atomic=true | `save-size-final.log` |
| `audit_s12_compact_probe.gd` | failures=0 | `compact-wallet-final.log` |
| existing `test_equipment_switch_cooldown.gd` | 24/24 | `equipment-switch-final.log` |

The logs contain sandbox failures to open `user://logs` and the Windows root certificate store. The compact probe deliberately triggers the unsupported remote-income error after checking that drop, wallet, events, and dirty state were unchanged. There are no script parse/runtime errors in these final runs.

## Remaining review point

A compact wallet `1e1e9 - small_debit` can accept same and adjacent-exponent legacy income, but an income term with an independently distant large exponent (probe: `{m:1,e:1000000100}`) cannot fit the current one-base-plus-adjustment representation without materializing roughly a billion digits. `Game.collect` explicitly rejects that input before mutating the drop or wallet. This is a representation limitation for a legal growth-number income, not a finite resource allocation failure. It must not be described as full support for all legal wallets or made into a gameplay exponent cap. Parent dot and original astra must decide whether S12 needs a sparse multi-base form to remove this blocker before PASS. No S20 scoring or economy formula was changed.

The implementation thread remains open pending both reviewers' decision on this same runtime and evidence object. No main merge or next stage was performed.
