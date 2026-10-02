# Enemy formation candidate — review only

Base: `8b631374a4c8f217af0ce3c68bd1a233ad289b6c`. No main publication or existing level replacement. Twenty append-only groups (1001–1020), sixty referenced enemy archetypes, optional `battle_design.xlsx`. Existing ten-slot groups keep their original coordinates; new fifteen-slot groups use three rows of five. Editor/import/export supports both lengths and rejects sixteen.

## Conditions and working criteria

- Destroyer, four identical weapon modules, one shield and one armour. All modules use Lv10+N for +N. Fixed 1/60 steps, speed 1. No purchased enhancement, crew, technology, planet, reactor or gem bonuses; no player save imported.
- Godot 4.6.3 Linux. Formal battlefield missile target/launch providers, hull pose and turret progression used; ordinary/elite samples end on ordinary wave clear rather than being treated as a final encounter. Boss/ultimate samples use final encounter clear.
- The old base has a pre-unlock base-critical leak; every sample explicitly suppresses it. This matches the intended zero pre-unlock contribution. Later main `a22fd7d` contains the independent `31cd75e` gate fix; these are not measurements on that later runtime.
- Normal: advantageous weapon +0 wins in 8–12s; all weapons +3 win. Elite: advantageous +0 loses, +1 wins in 16–24s. Boss: optimal weapon within physical/energy category +1 loses, +2 wins in 24–36s. Ultimate: optimal category weapon +2 loses, +3 wins in 48–72s. Other same-category weapons' results remain visible; no claim that both share the optimal time.
- Neutral working criterion: all four weapons win at the required upgrade, each meets the tier duration window, and each time differs by at most 20% from that group's four-weapon mean. Elite neutral also requires all four +0 to fail. This quantitative neutrality criterion is a proposed review criterion, not an established game rule.
- Symmetry is exact by mirrored enemy ID. Normal size ≤3; elite exactly two size4 at left/right, remaining size1–2; boss ≤one size5 and ≤two size4, remaining size1–2; ultimate exactly one size6.

## Numerical changes and findings

Only existing equipment source cells changed: cannon base damage **350→1500**, CD **2→3.5** (3.5 is the separately confirmed rail cadence). Cannon speed remains 40 and motion multiplier remains 1. All damage/cost/defence growth coefficients and all other existing equipment cells are unchanged. Existing enemy/group data rows unchanged; level and motion workbooks byte-identical. See `source-audit.json` and `test_enemy_design_contract.py`.

Four-slot nominal Lv10 DPS before flight, charge, target change and overkill:

| Weapon | Damage per projectile/tick | Nominal DPS |
|---|---:|---:|
| laser | 520 | 4160 |
| missile | 1000; four per batch per mount | 6666.7 |
| cannon, old / candidate | 1800 / 7700 | 2057.1 / 8800 at CD3.5 |
| longLaser | 180 | 3600, rising to 10800 while sustained |

The initial 320-case diagnosis failed the design goals: cannon was weak against durable single targets, neutral pairs were repeated, elite/boss +0 generally won, ultimate cannon timed out. Those archived results used the earlier one-encounter/fallback-aim fixture and must not be presented as a matched final-runtime benchmark. Targeted `trial3.csv` established ordinary role separation through existing HP/type resistance alone. No new flat absorption or regenerating enemy shield was needed or implemented.

## Final fixture results

`acceptance.json` records **20/20 working criteria passed**. Full four-weapon × +0/+1/+2/+3 coverage at seed1701; seeds2701/3701 repeat required/preceding boundaries (neutral: all four weapons; categorical groups: optimal weapon).

| Group | Required upgrade | Required successful time, seconds |
|---|---:|---|
| normal_laser | +0 | laser 9.80 |
| normal_missile | +0 | missile 10.93–10.97 |
| normal_cannon | +0 | cannon 10.80 |
| normal_longLaser | +0 | longLaser 9.60 |
| normal_neutral1 | +0 | 8.43–11.20 |
| normal_neutral2 | +0 | 8.47–11.20 |
| normal_neutral3 | +0 | 8.40–10.82 |
| normal_neutral4 | +0 | 8.40–11.20 |
| elite_laser | +1 | laser 21.75 |
| elite_missile | +1 | missile 22.85–22.87 |
| elite_cannon | +1 | cannon 17.90 |
| elite_longLaser | +1 | longLaser 18.20 |
| elite_neutral1 | +1 | 16.00–21.42 |
| elite_neutral2 | +1 | 17.20–22.92 |
| elite_neutral3 | +1 | 16.00–21.42 |
| elite_neutral4 | +1 | 16.00–21.42 |
| boss_physical | +2 | cannon 28.37 |
| boss_energy | +2 | longLaser 29.80 |
| ultimate_physical | +3 | cannon 60.02 |
| ultimate_energy | +3 | longLaser 68.80 |

Provenance: 320+88+88 cases preceded the last normal-neutral2 HP correction (7500→7000 for mirrored archetype1025); only that group was then replayed (16+8+8). **528 raw final cases, 496 selected cases**. Original global configuration SHAs are preserved in CSV. `config-before-neutral2-fix.json` plus the final source verifies the single semantic change; the other nineteen complete fixture projection hashes are identical. This is not one mixed global-configuration batch. Earlier gate failures and the subsequent corrections remain in `before-final-corrections.csv` with its snapshot.

## Validation and review limits

- Source/schema contract passes: twenty unique compositions, size limits, symmetry, legacy rows, unchanged growth and unchanged level/motion bytes; invalid lengths and boolean/fractional upgrade baselines rejected.
- Headless and visible Compatibility tests each pass **172 grid checks**; four scene screenshots cover ordinary, elite, boss and ultimate layouts. Linux llvmpipe screenshots are layout evidence, not Windows performance evidence.
- No combat damage, RNG, hit/chain/deferred payment or save code was changed. New group positions affect the new formations by design. Old formations remain unchanged.
- Base-critical suppression and the Lv10 Destroyer fixture are explicit design assumptions. This is a candidate for review, not verified Windows frame performance or a published balance release. Some neutral +1 survivors have only a few hundred armour; the two additional seeds validate sampled boundaries, not broad save/build/frame-rate robustness.
- Do not overwrite a newer main's consumer JSON with this old-base artifact. Reconcile authored source/formation changes, retain newer fields, then run the official exporter and relevant compatibility checks.

Raw rows: `selected-results.csv`, per-seed matrix/fix CSVs, `group-summary.csv`. Reproduce with `test_enemy_design_probe.gd` and saved input JSON in an isolated copy. `test_enemy_grid.gd` covers grid/export/rendering semantics. No raw user save, frame sample or log is included.
