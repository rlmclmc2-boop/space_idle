# Targeted DPS checks

- Source base: `e02501b38bff8069f2b15bd8947c54d1dc215a1a` (`origin/main` verified remotely on 2026-10-16).
- Native DLL SHA-256: `5f8f555c7083612e0a3673be5d47ae7b4171bf1404090610f050733a0f591ac6`.
- `test_battle_damage_stats.gd`: 24 checks, 0 failures. Covers disabled ledger, window expiry, GrowthNumber, shield loss, health overkill, derived drone source, duplicate dead hit, pause, wave reset, native source, native state and RNG parity.
- `test_battle_damage_stats_ui.gd`: 9 checks, 0 failures in graphical main scene. Covers settings entry, toggle, total and source labels, hidden internal ID, close, reopen, timer stop. The screenshot uses injected damage rows to make layout readable; the displayed values are not a gameplay measurement.
- UI catalog validation: 2372 rows, valid. Godot 4.7.2 editor import: exit 0, no script or compile errors after the display-format correction.
- `main-scene.png`: GL compatibility main scene in an active combat state, with the DPS dialog open. Window contents were injected by the UI test.

Full five-suite performance and native handoff evidence follow separately.
