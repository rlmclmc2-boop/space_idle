extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	var db := ShipDatabase.new()
	var resources := BattleGame.new(db,false)
	resources.profile.resources["1"] = 0
	var collected: Array[Dictionary] = []
	resources.event.connect(func(kind, info):
		if kind == "collect":
			collected.append(info))
	var resource_enemy := {"hp":1.0,"armourType":0,"x":500.0,"y":300.0,"res_ratio":1.1,"drops":[{"resourceId":1,"amount":3.0,"chance":1.0}]}
	resources.hit_enemy(resource_enemy,10,1)
	check(resources.drops[0].amount==4,"Drop rounds after multiplier: ceil(3 * 1.1)")
	var original_loss = db.config.autoCollectReduce
	db.config.autoCollectReduce = 0.4
	resources.collect(resources.drops[0],false)
	db.config.autoCollectReduce = original_loss
	check(resources.profile.resources["1"]==3 and resources.run_resources["1"]==3 and collected[0].amount==3,"Auto loss rounds independently and display matches credit: ceil(4 * 0.6)")
	resources.drops=[{"uid":99,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":4.0}]
	resources.collect(resources.drops[0],true)
	check(resources.profile.resources["1"]==7 and resources.run_resources["1"]==7 and collected[1].amount==4,"Manual collection credits the displayed integer drop")

	print('Resource checks: 3, failures: ', failures)
	quit(failures)
