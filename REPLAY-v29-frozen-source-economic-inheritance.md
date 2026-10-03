# Frozen V29 source and independent replay (2026-10-03 13:25 UTC)

Frozen source b4855e35dae1fcaf476f9949b9280671c57ae67e. No further numeric edits during this comparison.
Prerequisite V28 source 7406f866a9b0886b73e412f5a132d9bb8b8b0ce4, delivered in progression-v28-short-battles.bundle.base64. Its prerequisite V27 be60884b5c7d481870d88be21a6411c7dd7802ab; existing V26/V25/1d8/V11/V23 bundle chain remains required. Decode bundles, git bundle verify, git fetch bundle refs, then checkout frozen source. Do not cherry-pick onto unrelated source.

V29 increment progression-v29-short-wave-budgets.bundle.base64:
decoded 447908 bytes, SHA256 69f8b48d9f637a5b980c90f3f9d60b9da080de129226c14ea4cf7cad185e2b3c.
Data SHA256 eb9dba486b24b3441b329062f598fa80915513d8c45595d5df6dfaaabbffbd6f.
QA package fingerprint 19c494391ea34a32c4c93b05d41b5f6df04af09c6a5374a2daa8e085657ecc3e.
Root clean detached checkout at exact source and build_qa --scene independently reproduced this package fingerprint.

Dependencies: Godot 4.6.3 official 7d41c59c4, Python 3, openpyxl for Excel export/validation. Package builder copies required project/runtime assets; no external credentials needed. run_qa performs its own Godot import before executing.

## Minimal numeric diff / inheritance

V27 changes retained:
- battle income stage21–60 and future formula coefficient 4 -> 6 (1.5x).
- first new dock exploration unlock resource60 ->30. Construction requirement180 unchanged, nominal 3h at60sec/trip.
- stage35 growth step126 ->128, all stage35-anchored later enemy life/attack 1.44x. This is enemy curve compensation for intended reforge progression, not proof of actual reforge benefit timing.
V28 changes retained:
- stage33 normal HP .15 of original normalized template, elite .06; boss33 HP .1 of existing later-boss HP; elite33 and boss33 damage .1.
- stage34 normal HP .02, elite HP .05, boss HP unchanged; life step98 unchanged, attack step overridden to102 (2.0736x stage34 attack).
V29 only further halves stage33 normal .15->.075 and elite .06->.03; all stage33 boss and stage34 parameters unchanged.
QA V13 earned-farm option retained; default0 keeps earlier policy. No core gameplay mechanism added. Original protected fields/headers checked with normal Excel export; 543 protected rows passed.

## Exact arrival34 replay

Input v29-actual-no-forge-arrival34-native.json is an actual native snapshot, not an upgraded/copied diagnostic profile. Time77692.8333367859, no reforge. Its earlier segment started from the genuine V23 fresh32 checkpoint, with explicit numeric-version transition to V29. It is not a V29 whole fresh-run claim.

Build:
python test/progression/build_qa.py --output /tmp/qa-v29 --scene

Strong previously-earned-point farming sensitivity:
python test/progression/run_qa.py --project /tmp/qa-v29 --label v29-real34-heldbeam-earned32-reserve300-noforge12h --duration 43200 --scene --stop-clear 34 --visit-seconds 300 --teaching-seconds 10 --seed 2026100304 --no-reforge --bulk --scientist-batch --fixed-farm-stage 32 --fixed-weapon-from-stage 34 --fixed-weapon longLaser --resume /tmp/v29-actual-no-forge-arrival34-native.json --ui-refresh-seconds 1 --timeout 30000

UI refresh0 may be used as a display-only sensitivity but record it; parent already independently matched V26 actual33 UI0 versus root UI1. No assumption that V29 already matched.

Policy assumptions: 300s real visits, scientist +10 within existing reserve cap, whole-stage beam held, only already cleared32 revisited after two losses. Returning to34 occurs at real visits on accumulated five module levels or15min. These are explicit test assumptions, not user-required visit cadence or per-second oracle. Log manual claims/queue/refits and visit/event counts. X1 simulation step1/60 sec. Seed restores native RNG state on resume; seed is a fallback only.

## Completed facts, failures, remaining work

V29 fresh32 -> actual34 diagnostic: start77499.1666701643, clear33=77689.8166701199, arrival34=77692.8333367859, 0 retreats, 1 visit, 6 domain operation events. Wholebeam deliberately selected at actual32 visit, not after reaching33.
Actual wave times normal1–5: 11.55,10.5167,12.7667,13.8667,15.1167s; elite6–8:23.5,28.0833,26.4167s; Boss9:30.7667s.
Cold saved positive-defence nativefresh32 probes seed1701, samelevel/RNG, no manual upgrades during wave:
normal5 laser8.266667/beam14.266667/mixed12.083333;
elite6 laser17.583333/beam25.1/mixed20.683333;
Boss9 laser43.7/beam24.8/mixed34.133333. All won. Forced selected wave is diagnostic, not elapsed journey acceptance.

V29 actual34 stronger farming 12h test running; do not infer its wall from V26.
V27 first preparation from real older fresh30 still running; input economy before30 is older source, immediate resumed visit differs continuous fresh schedule.
Old V23 continuous full fresh maintained unmodified for late-chain diagnosis; parent independently replayed its zero-armour-fixed counterpart through40. New V29 full fresh0->60->all30buildingsLv5 50–60h acceptance remains unproved.
