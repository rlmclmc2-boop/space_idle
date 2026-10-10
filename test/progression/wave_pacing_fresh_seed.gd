extends SceneTree
## Native fresh-profile seed for authorized QA; private output only.
func _initialize():
 var game=preload("res://qa/presented_balance_game.gd").new(ShipDatabase.new())
 game.stat_cache_enabled=true
 game.rng.seed=20261010
 if not game.start(1,false):quit(2);return
 var output=OS.get_environment("QA_PACING_FRESH_OUTPUT")
 if output.is_empty():quit(2);return
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"save":game.portable_save_data(),"state":{"t":0},"rng_state":str(game.rng.state),"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"scope":"Native fresh_profile plus normal start(1,false). No resource, level or unlock injection."}))
 quit()
