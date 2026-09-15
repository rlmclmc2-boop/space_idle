extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(label, ": ", "PASS" if value else "FAIL")
	if not value:
		failed += 1

func run() -> void:
	var db := ShipDatabase.new()
	var game := BattleGame.new(db,false)
	game.profile.resources = {"1":1e25,"2":1e25}
	game.profile.cleared=BattleGame.EQUIPMENT.map(func(key):return db.unlock_level(key))
	game.rebuild_unlocks()
	# Cap assertions require installed equipment, not just unlocked options.
	check(game.equip_slot("weapons",1,"cannon"),"Install cannon for cap checks")
	check(game.equip_slot("weapons",2,"missile"),"Install missile for cap checks")
	check(game.equip_slot("defence",1,"shield"),"Install shield for cap checks")
	for key in BattleGame.EQUIPMENT:
		var cap := db.max_equipment_level(key)
		check(cap==100,"Excel 100 levels / "+key)
		game.first_equipment_entry(key).level=20
		check(game.upgrade(key) and game.first_equipment_entry(key).level==21,"Upgrade beyond old cap / "+key)
		game.first_equipment_entry(key).level=cap-1
		check(game.upgrade(key) and game.first_equipment_entry(key).level==cap,"Upgrade to actual cap / "+key)
		check(not game.can_upgrade(key) and not game.upgrade(key),"Reject upgrade above configured cap / "+key)
	game.save_enabled=true
	game.save_progress()
	var restored := BattleGame.new(db,true)
	check(restored.first_equipment_entry("armour").level==100 and restored.first_equipment_entry("laser").level==100,"Save restores levels above 20")
	# Different equipment may use different configured caps.
	db.equipment.shield=db.equipment.shield.slice(0,3)
	check(db.max_equipment_level("shield")==3 and db.max_equipment_level("laser")==100,"Independent per-equipment caps")
	var shorter := BattleGame.new(db,true)
	check(shorter.first_equipment_entry("shield").level==3 and shorter.first_equipment_entry("laser").level==100,"Clamp save to each new cap")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.upgrade_buttons.armour.disabled and scene.upgrade_buttons.laser.disabled,"UI shows actual max-level state")
	scene.game.profile.resources={"1":1e25,"2":1e25}
	scene.game.first_equipment_entry("laser").level=20
	scene.build_ui()
	check(not scene.upgrade_buttons.laser.disabled,"UI allows level 20 to 21")
	scene.queue_free()
	await process_frame
	print("EQUIPMENT LIMITS: ",failed," failures")
	quit(0 if failed==0 else 1)
