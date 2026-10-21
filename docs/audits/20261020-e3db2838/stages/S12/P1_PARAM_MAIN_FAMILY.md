# S12/P1 parameterized main equipment family: audit-only readback

Entry: [unique implementation plan](../../IMPLEMENTATION_PLAN.md), [frozen MAX-APPROX-v1 rule](P0_P1_EXTREME_MAX_AMENDMENT.md), and [prior fixed-config result](P1_APPROX_MAX_PROTOTYPE.md). This follow-up keeps the algorithm in the audit directory. It does not connect to game scripts, native code, save handling or main.

## Input and support decision

`p1_proto/max_approx_probe.gd` now receives `requested_equipment`, `requested_start_level`, the equipment cost row, material evolution row, wallet mode and material balance before the same quote/commit path. `max_approx_parameter_probe.gd` exposes these inputs through six `S12_*` scenario variables logged by `run_probe.py`; the checked-in [main snapshot](p1_proto/actual_equipment_main31e793.json) supplies the six cost rows and evolution data. `verify_param_matrix.py` compares that snapshot byte for byte by SHA-256 and field for field with Git object `31e79337741bf9860d69fff21dae6be994dacd00`: `game_data.json` SHA `fd9507a476d6164fd5f1dac9250923d9b0450f2450c22004b52be2def9bd2609`, `equipment_evolution.json` SHA `6f494f85b50d4e6d3a993ce03a7f5420cbdd04deb979a2cde1734253b4d9c99c`.

The approximate path accepts only player `armour`, `shield`, `laser`, `missile`, `cannon`, `longLaser` with exactly one row, `cost_1=50`, binary64 `costMulti_1=0.2`, `res_1=1`, absent second resource/cost, material interval 20, material `degenerate_matter`, and cost per tier 10. The supplied start level must be positive and the material balance nonnegative. Current main has those six matching rows. The exact 257-item prefix uses the **supplied row and start level**; the interval suffix starts at exponent `start_level+256`, correcting the initial exploratory hard-coded exponent found before the frozen run. Material tiers also start at the supplied level. The quote carries slot/resource identity and a full profile/config snapshot, and commit rejects a changed owner, profile, row or evolution config.

This is a **support-domain gate**, not a rule that generic `cost_1`, growth, or secondary resources can use the fixed geometric bound. Zero, low-cost, missing multiplier, second-resource and changed-growth inputs are explicitly `unsupported` before any quote/debit. The audit prototype has no general exact-MAX fallback for those configs; a product dispatcher would need to retain the existing exact path or report unsupported without a debit. Ordinary x1/x10 are outside this MAX-only entry and keep their original exact quote rules. Within the supported family, the 256/257 switch retains the frozen exact prefix and 256 exact-fee fallback. A first unaffordable purchase returns `not_affordable` without publishing even an equal-value profile.

## Frozen comparison

[Matrix runner](p1_proto/run_param_matrix.py) produced 14 isolated Godot 4.7.2 Windows triplets named `p1_proto/exploratory_param_*_freeze.{stdout.log,stderr.log,meta.json}`; see its [raw summary](p1_proto/exploratory_param_matrix_3.log). Each meta file records the concrete input values and raw hashes. The independent [readback](p1_proto/exploratory_param_independent_3.log) uses the main Git objects and prior fixed 50,000 original-price export to compare the six supported quotes, exact wallet and material differences, and bound/next-candidate conditions. It does not infer success from the candidate's `remaining_matches` flag.

| Input | Result |
| --- | --- |
| armour level 20, exact 256-price wallet | 256 exact purchases; fee equals original prices |
| shield level 257, exact 257-price wallet | upper bound rejects 257; 256 exact-fee fallback |
| laser 1, missile 100, cannon 1000, longLaser 10000; compact `10^3800` wallet | approximate counts 47,959 / 47,860 / 46,960 / 37,960; independent original-price sum lies within each reported fee interval, displayed fee equals wallet debit |
| laser level 19, materials 9 then 10 | 9: `not_affordable`, no profile publication; 10: 20 exact purchases, material reaches zero before level 40 |
| armour level 20, config changed after quote | `stale_rejected`, no debit |
| laser zero/low cost, no multiplier, second resource, changed growth | each `unsupported`, no quote or debit |

The old fixed start-1 billion fixture was also rerun after parameterization: count 848,867,438 and material remainder 333,305,931, with no new algorithmic claim; raw triplet `p1_proto/exploratory_param_billion_regression_freeze.*`. Cancellation still responds after the current worker fee completes. This is a bounded main-family audit result only. Full production config changes, all numeric representations, native, save, UI, ordinary purchase consumers and the public-ledger performance gate remain unproven. **P1 is NOT PASSED; no P2 or main integration follows from this record.**
