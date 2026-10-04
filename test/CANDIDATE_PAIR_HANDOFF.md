# Parent-run candidate comparison

This is a review branch, not a production release. Main4a2083f remains the
data/level/economy baseline. Imported dependencies: rail/first-armour360841a
and visual/header148fe38 (four visual commits, cherry-picked without conflict).
The candidate JSON is injected into a private database; no source levels,
player progress, global growth/economy, or production Excel/JSON are replaced.

## First commands

With this branch checked out in a repository containing base4a2083f assets:

```sh
python test/test_explicit_formation_import.py
python test/run_candidate_pair_scene.py --godot /absolute/path/to/Godot --phase preflight --wall-timeout 240
```

Preflight defaults to all80 groups, cannon/+0/seed1701. It performs no combat
ticks. Exit3 means geometry rejected; inspect the JSONL and logs in the printed
private directory. Candidate coordinates in `candidate_pair_options.json`
are explicitly authored logical positions, packed offline using real-scene
footprints and the existing inverse battle_point projection. N01/N02 retain
their original probe coordinates; all200 numeric/loadout rows are unchanged.
The old130+0.7Y proposal was rejected and is superseded. The final40 pass local
geometry checks; parentGodot4.6.3 must confirm. They are never silently repaired
at runtime. The PDF
design coordinates are not executable production positions. Input-invalid
groups and empty spawns are also rejected, not counted as successes.

First battle chunk, only after these two specific groups pass preflight:

```sh
python test/run_candidate_pair_scene.py --godot /absolute/path/to/Godot --phase battle --groups normal_neutral4 N01 --weapons laser missile cannon longLaser --upgrades 0 --seeds 1701 --wall-timeout 240
```

The script copies the real project and scene driver into a private directory,
imports with the parent's engine, and runs main.tscn/PresentedBattleGame with
production launch and target providers. It never uses BalanceGame. Use the
parent's actual graphical/offscreen environment for battle/provider evidence;
`--headless` is an optional geometry/import diagnostic, not visual acceptance.
Each row flushes immediately; interrupted chunks retain completed rows. Resume
by selecting unfinished groups/weapon/level/seed combinations. Logs record
actual engine and source/input fingerprints; do not merge mismatched runs.

## Comparison proposal — parent review before expansion

Fixed fixture: Destroyer, four identical weapons, first defence armour then
shield, all six modulesLv10+N, no crew/enhancement/hightech/reactor allocation,
real default critical rules, speed1, step1/60, private encounter ratios1.
Both new and old records use base_level10. Keep hostile weapon rows unchanged.
Normal/elite fixtures append an unspawned sentinel wave to retain ordinary-wave
completion; boss/ultimate remain final encounters. Timeout120 game seconds is
excluded from win/TTK acceptance, never counted as a loss or easy clear.

1. Geometry coverage: all40 candidates at entry/drift0,.1,.25,.5,1,5,8 seconds,
   all legal yaw endpoints, native and small-window screenshot confirmation.
   Inspect rendered hull/weapon/protection/meter rectangles, front line, and
   overlaps. The runtime guards the current viewport; repeat after resizing.
2. Initial320 matches: old40+new40 × four weapons × +0 × seed1701. Parent runs
   small explicit chunks. Any rejected geometry blocks that group's battle.
3. Expand only genuine progression boundaries to adjacent levels and seeds.
   The parent's completed old160 cells include78 wins and82 losses, no timeout;
   preserve every failed cell. For failed cells compare enemy HP/shield progress,
   kills and time-to-loss rather than inventing a clear TTK. Do not mechanically
   run a3840-match grid. Seed expansion is reproducibility evidence, not a claim
   of population win probability.
4. Match each new group to old groups of the SAME tier AND hostile attack type;
   show the full corresponding old-tier distribution as well as the nearest
   structural comparator. Do not select a convenient weaker comparator. The
   design matrix's nearest old group is explanatory, not automatically the
   balance comparator. Preserve all40 old observations even when comparators
   repeat; avoid weighting repeated old matches as independent samples.

Suggested review tolerances, not accepted balance claims: required minimum
module level differs by at most1; at a common winning level, median TTK ratio
0.8..1.2 and remaining-armour fraction difference<=0.15; actual incurred
armour+shield damage ratio<=1.25, with separately reported layer damage and
normalised absolute differences when the reference damage is near zero.
Inspect win/loss disagreements seed-by-seed and threshold cliffs. Three seeds
are reproducibility probes, not enough for a statistical10-point win-rate
equivalence claim. Maintain weapon response ordering where the new group's
layer/regen intent predicts it; mixed profiles may legitimately differ, and
require a written interpretation rather than forcing the old winner.

## Coordinate interface and remaining work

`monGroup.formation_positions` is an optional JSON array parallel to all10/15
source slots: `[x,y]` for each occupied slot, null for empty slots, logical
battle units. Blank/missing keeps the exact old default projection. Importer
retains it in DB; source identity/order never sorts to fake a different layout.
Explicit runtime members use formation_columns0, size_formation=true, and
explicit_formation=true. The explicit display path grants the SAME .52 depth
budget deliberately, consumes battle_point once, and avoids centre clamping.
The existing actual target/collision provider reads final rendered positions.
Invalid display layouts are rejected. Legacy XLSX export explicitly refuses an
explicit layout instead of silently deleting its coordinates. The generic
Excel editor retains optional headers/fields; adding that header to final
authoritative candidate workbooks remains pending approved coordinates.

Own touches: enemy_formation.gd, game.gd spawn metadata/rejection, main.gd
encounter/pose/frontline/render/validator branches, explicit_formation_geometry.gd,
battlefield.gd shared enemy_status_layout, mon_group_xlsx.gd export
guard, tools/import_workbook.py and explicit_formation.py; plus dedicated
fixture/launcher/input/import checks. battlefield.gd's shared helper extracts
the actual health/shield/above-bar caption rectangles without changing drawing
coordinates; the old validator wrongly assumed the base main.gd side caption.
main.gd intersects the visual thread's geometry helpers; preserve both sets.

Local checks: three import tests and seven geometry regression checks pass.
Godot4.7.2 actual main/Presented preflight has80 rows/0 rejections. All40
candidates also pass actual graphical entry/drift checks in ordinary and small
windows (40/0 each);160 original entry/steady PNGs inspected via16 contacts,
plus preserved-coordinate N01/N02 and N35/N39 final template captures.
The original crowded N35 still rejects (131 component collisions), proving
real overlaps are not being ignored. AABB overlap alone no longer rejects:
body/protection polygons, actual health/shield rectangles and above-bar font
bounds are distinct parts, padded by2 actual pixels each; mixed yaw and lost
shield status footprints are included. No local battle or long run started.
ParentGodot4.6.3 confirmation, final source Excel authoring, balance tuning and
refreshed atlas remain pending. Existing
review PDF/ZIP are design evidence only and should not be sent as calibrated
end-user output yet.
