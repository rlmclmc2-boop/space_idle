# Battlefield integration boundary

Production: `main.tscn` → `scripts/battlefield.gd` → `scripts/main.gd`.
`presented_battle_game.gd` retains BattleGame save, inventory, unlock, damage and hit paths. Its player database projects the previously approved missile values; hostile lookup delegates to the original database, including missing-field fallbacks. No workbook, serialized schema or migration changes.

The developer harness subclasses the production renderer. Fixture construction, screenshot controls, synthetic enemy durability and diagnostic inputs stay in `dev/toon_ship`; production does not invoke them. GLB resources and the existing ship-view contract remain at their stable paths during the fleet art handoff.

| Coverage | Owner / consumer | State before integration |
|---|---|---|
| Five friendly hulls, drone geometry | friendly fleet asset task; `dev/toon_ship/hulls`, manifest, `ship_view.gd` | Only dev scene used new rendering |
| Six hostile hulls | enemy fleet asset task; existing `enemy_1` … `enemy_6` IDs | Legacy PNGs in main |
| Shared hull draw and status hook | `main.gd`, `battlefield.gd` | Hardcoded enemy drawing; transverse-size HP offset |
| Normal save/load and loadout | BattleGame; `presented_battle_game.gd` | Dev forced no-save startup |
| Background | `starfield.gdshader`, `battlefield.gd` | Legacy cool fog and foreground debris |
| Stage, wave, travel, pause, clear/retreat, armour/shield | `battlefield.gd` | Thin cyan HUD; square generic panels |
| In-battle notices / existing beginner guide | overlay skin; `beginner_guide.gd` style only | Legacy bright outlines; guide behavior unchanged |
| Shield / impact / destruction | real hit/explode events, foreground feedback layer | Periodic demonstration shield flash; textured debris |
| Missile, beam, pulse, rail | extracted renderer, existing VFX scripts | Approved dev-only presentation |
| Resources / quantity formatting | existing top chrome and NumberFormat | Retain integrated compact-card number notation |

Contract: preserve hull IDs, module slot indices, named mounts and muzzle nodes. Weapon capacity comes from active real equipment, with overflow represented by independent carriers. Enemy health bars track alpha bounds; no fixture HP is installed by production. Background and HUD remain separate draw owners; paused unchanged state does not repaint them.

Focused verification: `test/battlefield_live_check.gd` (isolated project/user directory, normal new-player save and combat), existing enemy-isolation/missile-retirement/mapping checks and `test_battle_transition_ui.gd`. Full-loadout/size coverage is explicit test input, never a shipped player profile.
