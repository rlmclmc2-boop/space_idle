# ARCHITECTURE: locator
Paths relative to project root. Operations: [README](../README.md).
Supported roots: [entrypoint map](../tools/supported_entrypoints.json). This page describes current code; [redesign plan](GLOBAL_ARCHITECTURE_PLAN.md) describes the reviewed migration, not completed runtime work.

| Feature | Path / owner |
|---|---|
| boot, scene, event->UI | project.godot -> main.tscn -> scripts/battlefield.gd (extends main.gd), creates PresentedBattleGame |
| gameplay/state/combat/save | scripts/game.gd: BattleGame |
| real-time/manual save / safe storage / settings | scripts/game.gd: check_timed_save/save_progress; scripts/progress_writer.gd; scripts/main.gd: show_save_settings |
| ship hulls / weapon presentation | assets/ships/*, data/ship_weapon_visuals.json -> scripts/weapon_visual.gd -> scripts/main.gd draw/muzzle; logic remains in scripts/game.gd |
| cfg/stat projection | scripts/database.gd: ShipDatabase |
| equipment/ships/enhancement | scripts/equipment_tab.gd, equipment_card.gd, ship_panel.gd, enhancement_panel.gd |
| tutorial / unlock notices | scripts/main.gd owns notice UI clock; scripts/unlock_tutorial.gd projects system archive; scripts/game.gd owns earned IDs/readUnlocks; save_transfer.gd includes read flags |
| crew/planet/reactor/chrono | scripts/crew_system.gd, crew_panel.gd, planet_buildings.gd, planet_buffs.gd, planet_panel.gd, reactor_panel.gd, chrono_panel.gd; growth_number.gd extends quantities beyond float range |
| research | scripts/ai_tech_tree.gd owns research; ai_tech_factory_page.gd + ai_tech_view_model.gd present it; main.gd dispatches tabs |
| galaxy | scripts/galaxy_system.gd owns galaxy state; galaxy_runtime.gd coordinates work/commits; galaxy_region.gd work/frontier; galaxy_effect_aggregator.gd effect cache; galaxy_panel.gd + galaxy_map.gd display; [rules](GALAXY.md) |
| UI text | data/ui_text.json, ui_text_contract.json; scripts/ui_text.gd |
| cfg split/import/editor | tools/config_workbooks.py, import_workbook.py, level_editor_store.py; level_editor.tscn, scripts/level_editor.gd |
| QA / tests | scripts/config_panel.gd; ../test/README.md; outputs ../test/work/ |
| F8 sim | scripts/balance_panel.gd -> balance_runner.gd -> balance_game.gd |
| F9 current UI | scripts/enemy_fleet_panel.gd exposes enemy fleets, automatic levels and cycle levels; enemy_fleet_simulator.gd, fleet_level_generator.gd, cycle_level_generator.gd |
| batch / analysis components | fleet_battle_runner.gd, fleet_result_analyzer.gd and associated tests; component existence does not imply a current F9 analysis tab |
| portable sim | tools/build_result_analyzer.py; tools/result_analyzer/ wraps current F9; static scripts derived from scene/class_name closure, dynamic resources explicit in analyzer_required_data.json |

DATA: config_excel/*.xlsx -> tools/import_workbook.py -> data/game_data.json -> ShipDatabase -> BattleGame/UI. Legacy workbook -> tools/config_workbooks.py by explicit split. Import uses cached Excel formula values. Edited/new tables use field names, concise per-column descriptions, types, then data; importer skips both metadata rows. New columns require descriptions.

OWNER: profile retains progression/unlocks/journey metadata. Economy owns spendable balances; equipment_state owns hull/modules; ai_tech_tree, crew_system, planet_state, reactor_state, enhancement_growth, galaxy_system and hyperspace_system own their domain state. Game composes their save_data exports. progress_runtime, galaxy_runtime and hyperspace_runtime coordinate concrete cross-domain commands. attribute_projection and compiled_combat_rules derive values from contribution revisions. Equipment read views are immutable; exported snapshots are detached. player/enemies/projectiles/drops remain session state; main/pages own selection/controls/UI snapshots only. Reads may cache derived values but must not mutate authoritative state.

LOCATE: attack=game.fire/tick_projectiles/hit_enemy/hit_player; beam=lock_long_laser/tick_long_laser; equipment=commit_loadout_change/commit_equipment_upgrades; enhancement=settle_jewel_fragments/upgrade_enhancement/set_enhancement_order/set_enhancement_branch; neutral protection/debt=advance_jewel_repair; branch hooks/timers=scripts/enhancement_branches.gd; save=load_progress/load_progress_data/portable_save_data. Save version is defined by BattleGame.SAVE_VERSION and validation by save_transfer.gd; this locator makes no historical-save continuity promise. Music preference remains separate user://music_settings.cfg.

BOUNDARIES: native_execution_compiler admits its supported subset; native_execution_session/handoff own execution transfer. PresentedBattleGame motion is distinct from Lab exact/fast. Portable analysis may read external mon.xlsx in addition to packaged JSON; S0 dependency closure is not configuration snapshot isolation, model equivalence or proof of all tool behavior.
