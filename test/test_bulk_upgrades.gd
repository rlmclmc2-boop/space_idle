extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func sum_cost(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := left.duplicate()
	for id in right:
		result[id] = int(result.get(id,0)) + int(right[id])
	return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	var game := BattleGame.new(db,false)
	game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	game.profile.resources = {"1":1e25,"2":1e25}
	var ten_cost := game.upgrade_costs("laser",10)
	check(game.upgrade("laser",10) and game.profile.levels.laser==11,"10-upgrade advances exactly ten levels")
	check(game.profile.resources["1"]==1e25-ten_cost.get("1",0) and game.profile.resources["2"]==1e25-ten_cost.get("2",0),"10-upgrade charges summed cost once")
	var blocked := BattleGame.new(db,false)
	blocked.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	blocked.profile.levels.laser = 1
	blocked.profile.resources = {"1":ten_cost.get("1",0)-1,"2":ten_cost.get("2",0)}
	check(not blocked.can_upgrade_amount("laser",10) and not blocked.upgrade("laser",10) and blocked.profile.levels.laser==1,"10-upgrade is all-or-nothing")
	var max_game := BattleGame.new(db,false)
	max_game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	max_game.profile.levels.laser = 1
	var first := max_game.upgrade_cost_for_level("laser",2)
	var second := max_game.upgrade_cost_for_level("laser",3)
	var first_two := sum_cost(first,second)
	max_game.profile.resources = {"1":first_two.get("1",0),"2":first_two.get("2",0)}
	check(max_game.max_upgrade_amount("laser")==2,"MAX finds highest affordable level")
	check(max_game.upgrade_max("laser") and max_game.profile.levels.laser==3,"MAX upgrades to affordable level")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.game.save_enabled = false
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources = {"1":1e25,"2":1e25}
	scene.build_ui()
	check(scene.ten_upgrade_buttons.has("laser") and scene.ten_upgrade_buttons.has("shield"),"Weapons and shield expose 10-upgrade")
	check(scene.max_upgrade_buttons.has("laser") and scene.max_upgrade_buttons.has("shield"),"Weapons and shield expose MAX")
	check(scene.ten_upgrade_buttons.has("armour") and scene.max_upgrade_buttons.has("armour"),"All equipment expose bulk upgrades")
	check(scene.ten_upgrade_buttons.laser.text=="10连" and scene.max_upgrade_buttons.laser.text=="MAX","Bulk button labels")
	scene.queue_free()
	await process_frame
	print("Bulk upgrades: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
