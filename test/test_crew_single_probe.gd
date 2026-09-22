extends SceneTree
var scene
func _initialize() -> void:call_deferred("run")
func measure(label: String, action: Callable) -> void:
	var samples: Array=[]
	for i in 32:
		var start:=Time.get_ticks_usec()
		action.call()
		if i>=2:samples.append(Time.get_ticks_usec()-start)
	samples.sort()
	print("SINGLE_PROBE ",label," median_us=",samples[15]," p95_us=",samples[28])
func run() -> void:
	scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.automation_args=[]
	var g=scene.game
	g.save_enabled=false
	g.profile.cleared=range(1,61)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.switch_ship("Heavy_Battleship")
	for category in ["weapons","defence"]:
		var keys: Array=BattleGame.WEAPON_KEYS if category=="weapons" else BattleGame.DEFENSE_KEYS
		for index in g.module_entries(category).size():g.profile.loadout[category][index]={"key":keys[index%keys.size()],"level":1}
	g.profile.resources={"1":1e6,"2":1e6}
	g.reset_player()
	g.assign_crew("navigator","equipment_upgrade","equipment")
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	await process_frame
	var panel=scene.equipment_panel
	measure("items_12",func():
		for category in ["weapons","defence"]:
			for index in g.module_entries(category).size():panel.equipment_item(category,index))
	measure("cards_12",func():
		for id in panel.items:panel.cards[id].refresh(panel.items[id],id==panel.selected))
	measure("badges_12",func():
		for id in panel.items:panel.cards[id].refresh_crew(id))
	measure("detail",panel.refresh_detail)
	measure("filters",panel.apply_filters)
	measure("cost_one",func():g.slot_upgrade_cost("weapons",0))
	measure("cost_ten",func():g.slot_upgrade_cost("weapons",0,10))
	measure("full_refresh",panel.refresh)
	g.save_enabled=true
	measure("save",g.save_progress)
	quit()
