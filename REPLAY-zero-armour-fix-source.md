# Zero-armour consistency fix, exact V23 numeric data

Source SHA1d8dc45b6346f0d18dfa5ed993fa046a64525fd0. Requires V11 source30de7ce62aae3f390184729b0c79dfbe6aa419a0 (first obtain the small progression-v11-strategy-increment.bundle.base64 if needed; its base is frozenV23d9a). Decode progression-zero-armour-fix.bundle.base64: binary5942 bytes SHA256b4a4f5db943f2cc21e9f880d4e3a1b8617ecb7764c2b3b9be9703242275ae328. git bundle verify; git fetch bundle refs/heads/evidence/zero-armour-consistency-source; create an isolated worktree at1d8dc45. No running frozen project is changed.

Exact source package built from isolated1d8dc45: fullscene fingerprint918af5124bfcfb2588f7a0297bed168f48d7482aae23100f516316baf3ea9acd,763files. Game numeric data remains V23 SHA2564588c250929677a8199219117fcf6789381f151d7467c719ccc2878d73e07e1d; no V24/V25 numeric candidate included. Godot4.6.3 official7d41c59c4/Python/openpyxl.

```bash
python test/progression/build_qa.py --output /tmp/zero-armour-qa --scene
PROGRESSION_WAVE_CHECKPOINT=/ABS/legal-save32.json python test/progression/run_entry.py --project /tmp/zero-armour-qa --entry res://qa/zero_armour_lifecycle.gd --label pure-shield-five-weapons-and-live-death --timeout 600
```

Use a real legal32 (highest33, shield/fourweapons unlocked), either parent's own or supplied old legal32 evidence. Five weapon configurations retain public selectable allshield layout and slotlevels, but zero life cannot start. Actual UI message says装甲生命为0，无法战斗。请装备装甲后重试。 During combat removing final armour uses one existing native retreat, stops at level selection while stillzero, normal public armour refit/restart works. No baseline life/HP/resources/immunity injected. Start rejection does not spend resources. Existing2s crew production during retreat remains.

Probe respects start return and positive armour before explicit selected-wave spawn. Invalid/rejected rows are labeled start_rejected/invalid_loadout/invalid_encounter; zero enemy array cannot falselywin. Fullshield selection is not silently removed. Negative old anomaly retained: parent independently observed cannon/laser irrational wins373.667/385.967s whilezeroHP; root old fullshield beam60s zerohits timeout. Those are quarantined Bug evidence, not balance passes.

Root package64/66 control results:5startrefusals+live lastarmour retreat/recovery PASS; full-scene UI toast verified. Saved2armour1shield node33:6 remainsloss0.983333333534 with sameRNG/initialstats as old unobserved V23;1armour2shield samefailure; node9loss1.316667. New native60 offline-vsX1 completecombat/economy/research/crew/planet/galaxy signature PASS, zero offline duplication. Exact isolated source package repeat is running and will be separately recorded. UI catalog1762rows valid. Running root/parent V23 fullfresh remains unpatched.

Cold source validator now exports into a temporary directory, compares all gameplay fields, reports source_files provenance separately, never rewrites source JSON/cache. python test/progression/test_source_validation_portability.py checks metadata-only relocation PASS and genuine level mismatch rejection. Parent original cold/warm failure remains evidence.