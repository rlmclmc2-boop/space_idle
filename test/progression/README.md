# Progression calibration evidence

Experimental branch only. Source baseline: main b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f plus enemy-pair candidate 04a5a307bcef9325efa9026e1ca94affa577e10d. The inherited 6/32 loss-to-win changes remain unresolved baseline evidence; paired copies are not equivalent difficulty.

## Independent reproduction

Requires Python 3 and Godot 4.6.3 (official 7d41c59c4); package builder uses standard library only. Build copies only the reachable game-rule scripts and JSON, never assets, engine, credentials or player saves. Configuration edits require openpyxl 3.1.5 and the formal import command below.

```sh
python test/progression/build_qa.py --output /tmp/progression-qa
export XDG_DATA_HOME=/tmp/progression-qa/userdata
export XDG_CONFIG_HOME=/tmp/progression-qa/config
export XDG_CACHE_HOME=/tmp/progression-qa/cache
godot --headless --editor --path /tmp/progression-qa --import --quit
export PROGRESSION_OPTIONS='{"label":"baseline120","duration":10800,"stop_clear":10,"seed":20261002,"visit_seconds":120,"teaching_seconds":10,"strategy":"BALANCED"}'
godot --headless --path /tmp/progression-qa --script qa/progression_probe.gd
```

Runs are EXACT original-rule fixed 1/60 X1 steps. QA acceleration saves wall time only. Results include fingerprints, settings, engine, action JSONL, wave/state durations, clear times, resource/growth state, RNG and checkpoints. Each label must be unique; preserve failed results. A save checkpoint resumes according to formal journey rules, not arbitrary enemy/projectile state.

Current pilot policy is a documented diagnostic proxy: 10s teaching visits; post-teaching 120/300/900s sensitivity assumptions, never a user-required cadence. Each visit uses the existing BALANCED transaction policy (bounded 12 module purchases, mixed unlocked weapons, danger-sensitive defense). This policy still chooses purchases algorithmically and is NOT a validated human playthrough. Manual drops are collected only at visits; unlock acknowledgment delays and automatic collection loss remain. Planet, crew and galaxy handling must be added before later-stage claims. Per-second legacy autoplayer is only an optimistic diagnostic comparison.

## Ordered work and acceptance gates

1. Freeze baseline; run 0–10 budget and sparse-policy sensitivity; record actual blockers. Generate level source Excel: 1–5 four normal+elite, 6–19 five normal+three elite+Boss, themed by level. Levels 4/5 defense pairing/resource upgrades are suggestions.
2. Tune early growth and wave difficulty together. Targets: teaching 2–4 minutes each (first about 2), stage 10 cumulative 2–3h; waves 10/20/30/60s for advantaged weapons, normal +3 worst-case reserve. Keep 32% neutral disparity as starting point, not proof.
3. Expand to stage 20 (5 elite/3 Boss/region Boss, cumulative 12–18h); repeat special structure every fifth level 25–70 and every tenth from 80. Preserve stage/node distinction.
4. Planet stage 30: approximately 4h preparation, shipyard construction 75% (3h), smoothly advance two levels; numeric stall at 34 lasts at least 12h without reforge, no hard lock/immunity. Reforge return 34 <=2h, clear35 at 4–6h. Record fragments of upgrades across all systems.
5. Expand fifth-stage cycles to 60 galaxy unlock, then every building in first galaxy maximum at fresh cumulative 50–60h. Later planets repeating exactly 4h preparation remains undecided.
6. After segmented tuning, fresh-profile end-to-end run on ONE frozen code/config/policy version. Never splice mixed-version sections into a full pass.

Offline audit: formal game grants only chrono, capacity 12h. With configured speed M consuming M−1 particles per real second and earning 1 per offline second, retained chrono adds exactly the offline X1 budget when spent, once. Verify actual main conversion and formal reload tests before equivalence claims; no offline resources or second catch-up simulation.

All changes go through config_excel fields without deleting existing columns, then:

```sh
python space-battleship/tools/config_workbooks.py import
```

Evidence categories: diagnosis, checkpoint regression, full fresh run; facts versus hypotheses; numeric fixes versus experience recommendations. Every candidate records reason, affected stages/systems, prior failure and retest. The parent independently runs this package; this branch does not claim that happened.
