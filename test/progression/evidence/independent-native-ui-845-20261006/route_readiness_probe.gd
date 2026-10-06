extends SceneTree
func _initialize():
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 var raw=JSON.parse_string(FileAccess.get_file_as_string("/workspace/longrun_packages/clear35-to40-independent/diagnostics/actual-clear35-to40-natural-same0a4/save_reach_15_round_3.json"));var s=raw.save.duplicate(true);s.chronoSavedAt=Time.get_unix_time_from_system();s.hightechSavedAt=s.chronoSavedAt;g.load_progress_data(s);g.resume_progress()
 print("ROUTE_PROBE ",g.load_hyperspace_routes()," ERROR ",g.manual_hyperspace.last_error," config ",g.hyperspace.last_error," snapshot ",g.hyperspace.snapshot(g));quit()
