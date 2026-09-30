# STATUS: current / open / blockers

CURRENT: Release needs clean Windows acceptance; deep-space BGM musicality/loop awaits human listening.

| ID | OPEN / BLOCKER |
|---|---|
| U-001 | Experiment cfg promotion and portable source-fingerprint protocol undecided. |
| U-005 | Pickup/retreat/level-change duration, projectile speed conversion, initial resources, loss retention and auto-advance not fully design-approved. |
| U-006 | Min/zero damage, shield-overflow rounding, level-1 resistance, equal-priority targeting, pickup radius scope undecided. |
| U-007 | Resource/equipment extension and import paths differ in reference/duplicate-ID validation; fixed ID/field maps remain. |
| U-008 | Nonsequential clears, bad saves, shared-save instances and save-failure recovery risky. |
| U-009 | Quality, independent construction/facilities, independent level AI, global ending lack design rules. Do not invent. |
| U-010 | Clean Windows acceptance, other-platform export, CI incomplete. |
| U-011 | Legacy State/leave still consumed; enemy missile unused by formations and lacks player salvo. Verify before removal. |
| U-012 | Legacy workbook multiplier example vs linear 1.9 unresolved; no inferred rounding change. |
| U-013 | In-memory fixture/max-level clear does not establish natural new-game balance. |
| U-017 | Historical test_game assumes old install/loop/cfg; not comprehensive rule baseline. |
| U-018 | Legacy fixtures drift: test_scientists uses incomplete profiles/removed UI, test_local_ui references removed hightech_management_button, and test_planet_buffs fixes editable reward values. Use current specialty tests and test_stat_cache for cached/direct comparisons; old fixture failures are not rule acceptance. Old workbook lacks current fields; no guessed defaults. |
| U-019 | Cfg rollback can fail and leave partial commit; backups may also be cleaned. |
| U-020 | Incremental import concurrent target/manifest not fully rechecked; may overwrite external edits. |
| U-026 | BOSS card auxiliary coordinates used only in specialty test; main UI has no render entry. Verify actual requirement. |
| U-028 | Occasional full-page flicker not reproducible; research brightness fix does not close it. |
| U-029 | player_loadout_generator.gd module_snapshot infers from Variant-valued equipment stats; Godot rejects its inferred types, blocking the full fleet battle regression. Explicit number handling must follow the growth-number contract. |
