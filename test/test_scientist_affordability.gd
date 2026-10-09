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
	scene.refresh_tab_visibility()
	scene.equipment_tabs.current_tab=scene.equipment_tabs.get_tab_idx_from_control(scene.hightech_page)
	await process_frame
	var page=scene.hightech_page
	for paused in [false,true]:
		scene.game.paused=paused
		for balance in [0.0,1e100,0.0]:
			scene.game.profile.resources={"1":balance,"2":balance}
			page.refresh()
			check(page.generate_actions[-1].disabled==(int(scene.game.scientist_purchase(-1).count)==0),"MAX button reflects resources immediately, also while paused")
	for amount in [10,-1]:
		scene.game.profile.scientists=13
		scene.game.profile.resources={"1":1.0e7,"2":1.0e6}
		var original: Dictionary=scene.game.profile.duplicate(true)
		var quote: Dictionary=page.generation_quote(amount)
		check(scene.game.profile==original and quote.count>0,"Batch purchase quote is read-only")
		var tooltip: String=page.generation_quote_text(amount)
		check(tooltip.contains(str(quote.count)),"Tooltip states the actual batch quantity")
		for id in quote.costs:check(tooltip.contains(NumberFormat.precise(quote.costs[id])),"Tooltip includes the exact resource total")
		var popup: Control=page.generate_actions[amount]._make_custom_tooltip("preview")
		check(popup.get_node("TooltipLabel").text==tooltip,"Actual custom tooltip uses the purchase-specific quote")
		popup.free()
		check(scene.game.generate_scientist(amount) and scene.game.profile.scientists==13+int(quote.count),"Real batch purchase agrees with quoted count")
		for id in quote.costs:check(GrowthNumber.compare(scene.game.profile.resources[id],GrowthNumber.subtract(original.resources[id],quote.costs[id]))==0,"Real resource debit agrees with quoted total")
	scene.game.profile.resources={"1":0.0,"2":0.0}
	check(page.generation_quote(10).count==10 and page.generation_quote_text(10).contains(UIText.t("research.ai_purchase_insufficient")),"Unaffordable x10 still quotes the complete requested cost, not an affordable prefix")
	scene.queue_free()
	await process_frame
	print("Scientist affordability: ",checks," checks; failures: ",failures)
	quit(failures)
