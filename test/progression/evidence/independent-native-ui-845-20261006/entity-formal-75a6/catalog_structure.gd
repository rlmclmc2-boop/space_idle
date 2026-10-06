extends SceneTree
func _initialize():
 var g=BattleGame.new(ShipDatabase.new(),false)
 var cat=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_enemy_reward_catalog.json"))
 var blocks=cat.references.normal_neutral3.late_drop_blocks
 var block:Array=blocks[0]
 print("CATALOG_STRUCTURE startup_error=",g.startup_error," drops=",JSON.stringify(block))
 quit(0 if g.startup_error.is_empty() else 1)
