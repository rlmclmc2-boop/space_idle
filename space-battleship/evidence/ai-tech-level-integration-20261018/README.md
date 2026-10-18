# AI tech + third review level integration

Parents: `2150e041e34966bcdb2c228ff8caac777a5c1194` and `6d52620dfbf122af3f87201d8282e39918ebfa27`. Common base: `main@51a7e1b9bc5784927e7d5b232a112194d990a41c`. The merge had no conflicts. Only the four reviewed level commits were merged; no main update or art candidate was included.

Projection check: `import_workbook.read_rows` + `convert_sheet` compared `mon.xlsx` (10461 rows), `monGroup.xlsx` (2330), `level.xlsx` (220) and `hightech.xlsx` (4) to their complete `game_data.json` sections; zero mismatches. `validate_projection` passed. Thus `mon.xlsx` remains authoritative for the neutral enemy intel text.

Headless Godot 4.7.2, isolated app data; every listed script exited 0:

- `followup.log`: 12 native point cases, `THIRD_FOLLOWUP_PROBE 0`.
- `compare.log`: armour/shield and weapon comparisons, `THIRD_FOLLOWUP_COMPARE 0`.
- `pulse.log`: pulse counterexamples, `THIRD_FOLLOWUP_PULSE_CHECK 0`.
- `ai-tree.log`: 49 checks, zero failures.
- `ai-tutorial.log`: six checks, zero failures.
- `intro.log`: five confirmations, passive hint hidden, affordable hint and manual review retained, `upgraded=false`.
- `ai-ui.log`: first/second unread milestones and visible-page read behavior.

The native extension was built from the integration source using `addons/native_battle/build_native.ps1`, imported into this isolated worktree, and excluded from Git. A first probe before import failed native admission; the final logs above are after the correct build/import. No GUI or image review was performed. These fixed full-state point probes do not establish continuous new-save balance or visible shield recovery; those limits remain for the parent's serial acceptance.
