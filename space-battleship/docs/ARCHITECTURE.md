# ARCHITECTURE: locator
Paths relative to project root. Operations: [README](../README.md).

| Feature | Path / owner |
|---|---|
| boot, scene, event->UI | project.godot -> main.tscn -> scripts/main.gd |
| gameplay/state/combat/save | scripts/game.gd: BattleGame |
| ship hulls / weapon presentation | assets/ships/*, data/ship_weapon_visuals.json -> scripts/weapon_visual.gd -> scripts/main.gd draw/muzzle; logic remains in scripts/game.gd |
| cfg/stat projection | scripts/database.gd: ShipDatabase |
| equipment/ships/gems | scripts/equipment_tab.gd, equipment_card.gd, ship_panel.gd, jewel_panel.gd |
| crew/planet/reactor/chrono | scripts/crew_system.gd, crew_panel.gd, planet_buildings.gd, planet_buffs.gd, planet_panel.gd, reactor_panel.gd, chrono_panel.gd; growth_number.gd extends quantities beyond float range |
| hightech | scripts/main.gd, hightech_scroll.gd, hightech_inspector.gd, hightech_hall.gd, hightech_dock_bay.gd, hightech_construction.gd |
| galaxy | scripts/galaxy_system.gd owns profile.galaxies and online scheduling; galaxy_region.gd work/compact frontier/macro slots; galaxy_effect_aggregator.gd sole effect cache; galaxy_panel.gd Control cards + galaxy_map.gd independent 3D viewport; config_excel/galaxy*.xlsx; [rules](GALAXY.md), [GLB pipeline](../assets/galaxy/v3/README.md) |
| UI text | data/ui_text.json, ui_text_contract.json; scripts/ui_text.gd |
| cfg split/import/editor | tools/config_workbooks.py, import_workbook.py, level_editor_store.py; level_editor.tscn, scripts/level_editor.gd |
| QA / tests | scripts/config_panel.gd; ../test/README.md; outputs ../test/work/ |
| F8 sim | scripts/balance_panel.gd -> balance_runner.gd -> balance_game.gd |
| F9 fleet / loadout | scripts/enemy_fleet_panel.gd -> enemy_fleet_simulator.gd; player_loadout_panel.gd -> player_loadout_generator.gd |
| F9 batch / analysis / level | scripts/fleet_battle_panel.gd -> fleet_battle_runner.gd, fleet_battle_sampling.gd; fleet_analysis_panel.gd -> fleet_result_analyzer.gd, fleet_design_cards.gd; fleet_level_panel.gd -> fleet_level_generator.gd |
| portable sim | tools/build_result_analyzer.py; tools/result_analyzer/ |

DATA: config_excel/*.xlsx -> tools/import_workbook.py -> data/game_data.json -> ShipDatabase -> BattleGame/UI. Legacy workbook -> tools/config_workbooks.py by explicit split. Import uses cached Excel formula values. Edited/new tables use field names, concise per-column descriptions, types, then data; importer skips both metadata rows. New columns require descriptions.

OWNER: game.profile=durable resources/modules/unlocks/tech/crew/planets/reactor/gems/journey; game.player/enemies/projectiles/drops=runtime. main/pages own selection/controls/UI snapshots only. Reads must not mutate profile.

LOCATE: attack=game.fire/tick_projectiles/hit_enemy/hit_player; beam=lock_long_laser/tick_long_laser; equipment=module_entry/equip_slot/unequip_slot/switch_ship/upgrade_slot; gems=settle_jewel_fragments/combine_all_jewels/socket_jewel/unsocket_jewel/upgrade_socket_jewel; save=load_progress/load_journey/resume_progress. Save user://progress.json v3 migrates v2 planet identities; music preference separate user://music_settings.cfg. Import vs editor transaction risks: [STATUS](STATUS.md) U-019/U-020.
