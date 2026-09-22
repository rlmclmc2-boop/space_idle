extends SceneTree
# Boolean affordability must match the existing complete purchase calculation.
# Costs below are explicit isolated rule-boundary fixtures, never source edits.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.profile.cleared=db.data.hightech.keys().map(func(key):return int(db.unlock_row("hightech",key).level))
	for config in ["1.3,1|100,2|10","1.3,1|0,2|0","0.5,1|2,2|1","1.3,1|0,2|10","1.3,1|0.1,2|0.1"]:
		db.config.scientistCost=config
		for scientists in [0,1,20,1000000]:
			g.profile.scientists=scientists
			for resources in [{"1":0.0,"2":0.0},{"1":99.0,"2":10.0},{"1":100.0,"2":10.0},{"1":10000.0,"2":1000.0},{"1":1e100,"2":1e100}]:
				g.profile.resources=resources.duplicate(true)
				for amount in [0,1,10,-1,-7]:
					var before := g.profile.duplicate(true)
					var expected := int(g.scientist_purchase(amount).count)>0
					check(g.can_generate_scientist(amount)==expected,"Affordability differs from complete purchase: %s/%s/%s/%s"%[config,scientists,resources,amount])
					check(g.profile==before,"Affordability must not mutate profile")
	g.profile.cleared=[]
	for amount in [1,10,-1]:
		check(not g.can_generate_scientist(amount),"Locked generation stays unavailable")
	var scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=scene.db.data.hightech.keys().map(func(key):return int(scene.db.unlock_row("hightech",key).level))
	scene.build_ui()
	scene.equipment_tabs.current_tab=scene.equipment_tabs.get_tab_idx_from_control(scene.hightech_page)
	for paused in [false,true]:
		scene.game.paused=paused
		for balance in [0.0,1e100,0.0]:
			scene.game.profile.resources={"1":balance,"2":balance}
			scene._process(0.0)
			check(scene.scientist_bulk_buttons[-1].disabled==(int(scene.game.scientist_purchase(-1).count)==0),"MAX button reflects resources immediately, also while paused")
	scene.queue_free()
	await process_frame
	print("Scientist affordability: ",checks," checks; failures: ",failures)
	quit(failures)
