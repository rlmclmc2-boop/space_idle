extends SceneTree
func _initialize():
 var db=ShipDatabase.new()
 print("RELEASE_AI_TREE=",db.data.get("ai_tech_tree")," EVOLUTION=",db.data.get("equipment_evolution"))
 var g=BattleGame.new(db,false)
 print("RELEASE_STARTUP_ERROR=",g.startup_error)
 quit()
