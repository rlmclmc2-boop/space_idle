extends SceneTree
func _initialize()->void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	game.profile.highestLevel=999
	game.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	game.resource_samples.append({"time":game.economy_time(),"production_time":game.production_time(),"id":"1","amount":1.0,"origin":"x".repeat(16*1024*1024)})
	var before=game.profile.duplicate(true)
	var dirty:bool=game.save_dirty
	var events:Array=[]
	game.event.connect(func(kind,payload):events.append(kind))
	var accepted:=game.upgrade_slot("weapons",0)
	var clean:bool=not accepted and game.profile.resources==before.resources and game.profile.loadout==before.loadout and game.save_dirty==dirty and events.is_empty()
	print("S12_SIZE rejection_atomic=",clean)
	quit(0 if clean else 1)
