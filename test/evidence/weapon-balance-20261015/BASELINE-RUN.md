# Restored baseline regression provenance

These five isolated Godot runs were made after commit `dd4bfe5a` restored the fixed pulse 1.5 s, four-missile salvo, and draft shield 8%/1.8 s in authoritative Excel and projected JSON. They used Godot 4.7.2, `test/run.py --headless --timeout 120`, D-drive isolated workspaces, and no personal save. No long play was started.

| Test | Result | Raw output SHA-256 |
|---|---:|---|
| `test_memory_recovery_pacing.gd` | 22/22 | `ee16f876cc43cc2cdf9ec06e2186696e1bef7133ed58795bc284153847ae4228` |
| `test_neutral_memory_protection.gd` | 33/33 | `9dd66a9bc48c09f8996bf617d15592b36a7a3c1a0adc1107aee7d47e308718bd` |
| `test_enemy_shield_timing.gd` | 27/27 | `07d479f47b1f063436a6ac5412f79975d6906082e97bac503f1dd4c7d10f617f` |
| `test_enemy_shields.gd` | 43/43 | `d80ddec8e6bace45e289df6b0944c15798aae1b3f40fce39292c0a18c0d79646` |
| `test_equipment_growth.gd` | 94/94 | `1f3863d4c1fe3b5e28a1bb1729c5b38bf2008045f516ae08585fb4a485b4818c` |

Authoritative input hashes: `config_excel/equipment.xlsx` `50b4835e8aa2bce0e6f4a981fe582fcac10281792c9284ecefe25f78f581dab5`; `config_excel/mon.xlsx` `6640c467f9cd7fda46da942621c5b5663cda6bc81cfb0a87e14b4ba6ca1f26c2`; `data/game_data.json` `f3f6a3a1797f0b95ebd72410ec01318a5d7663698be5fee51d6f647695b1543b`.

Command for each test, replacing `<name>` with the filename above:

```powershell
python test/run.py <name> --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --timeout 120
```

`raw/test_*.txt` holds the original `test.log` from each isolated run. This regression set checks established recovery, shield, and equipment boundaries. The `1e40` exact-hit requirement remains explicitly unresolved in the separate legacy/native direct tests; see `precision-boundary.md`.
