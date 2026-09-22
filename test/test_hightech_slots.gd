extends SceneTree
## Configuration and legacy order compatibility; drag UI was removed by request.
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
	var scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=[]
	scene.game.profile.hightechOrder=[]
	scene.build_ui()
	await process_frame
	check(scene.hightech_buttons.is_empty() and scene.hightech_container.get_child_count()==0,"Locked technologies and reserved save slots create no visible bays")
	check(scene.equipment_tabs.is_tab_hidden(1) and scene.equipment_tabs.current_tab==0,"Research hidden before unlock and first tab remains selected")
	var first := BattleGame.FURNACE
	scene.game.profile.cleared=[int(scene.db.unlock_row("hightech",first).level)]
	scene.sync_hightech_slots()
	scene.refresh_tab_visibility()
	check(scene.hightech_buttons.keys()==[first] and scene.hightech_container.get_child_count()==1,"First unlock creates exactly one bay")
	check(not scene.equipment_tabs.is_tab_hidden(1) and scene.equipment_tabs.current_tab==0,"Unlock does not change selected page")
	var first_card: Node=scene.hightech_titles[first].get_parent()
	scene.game.profile.cleared=scene.db.data.hightech.keys().map(func(key):return int(scene.db.unlock_row("hightech",key).level))
	scene.sync_hightech_slots()
	scene.equipment_tabs.current_tab=1
	await process_frame
	check(scene.hightech_buttons.size()==4 and scene.hightech_container.get_child_count()==4,"Four configured technologies have no extra empty drag bays")
	check(scene.hightech_titles[first].get_parent()==first_card,"Unlock keeps existing card")
	scene.game.profile.hightechOrder=["",BattleGame.JEWEL_FURNACE,"",first,BattleGame.DENSE_ARMOUR,BattleGame.ENERGY_FOCUS]
	var profile_before: Dictionary=scene.game.profile.duplicate(true)
	scene.sync_hightech_slots()
	check(scene.game.profile==profile_before,"List projection never rewrites legacy order or research state")
	check(scene.hightech_container.get_child(0).get_meta("tech_key")==BattleGame.JEWEL_FURNACE and scene.hightech_container.get_child_count()==4,"Legacy holes are compacted visually while relative order survives")
	check(scene.hightech_titles[first].get_parent()==first_card,"Legacy order moves original controls")
	scene.game.profile.scientists=17
	scene.game.profile.scientistAssignments[first]=17
	scene.game.profile.techPoints[first]=12.0
	scene.game.save_enabled=true
	scene.game.save_progress()
	# Check serialized state before the separate wall-clock offline research step.
	var reloaded := BattleGame.new(scene.db,false)
	reloaded.save_enabled=true
	reloaded.load_progress()
	check(reloaded.profile.hightechOrder==scene.game.profile.hightechOrder,"Actual save/load preserves legacy order")
	check(reloaded.assigned_scientists(first)==17 and reloaded.profile.techPoints[first]==12.0,"AI assignments and points survive save/load")
	scene.game.save_enabled=false
	for i in 7:
		var key := "future_technology_%d" % i
		scene.db.data.hightech[key]=scene.db.data.hightech[first].duplicate(true)
		scene.db.data.hightech[key].name=key
		scene.db.data.unlock[key]={"type":"hightech","target":key,"level":0,"mode":"cleared"}
	scene.sync_hightech_slots()
	await process_frame
	check(scene.hightech_buttons.size()==11 and scene.hightech_container.get_child_count()==11,"Configuration growth adds all projects without manual UI changes")
	check(scene.hightech_titles[first].get_parent()==first_card,"Growth preserves original bay")
	scene.hightech_scroll.scroll_horizontal=100000
	await process_frame
	var scroll: int=scene.hightech_scroll.scroll_horizontal
	scene.sync_hightech_slots()
	check(scroll>0 and scene.hightech_scroll.scroll_horizontal==scroll,"Unchanged list synchronization retains scrolling")
	for i in 7:scene.db.data.hightech.erase("future_technology_%d" % i)
	scene.sync_hightech_slots()
	check(scene.hightech_progress.size()==4 and scene.hightech_container.get_child_count()==4,"Removed config releases only retired bay references")
	check(scene.hightech_titles[first].get_parent()==first_card,"Shrinking preserves remaining controls")
	scene.game.profile.cleared=[]
	scene.sync_hightech_slots()
	scene.refresh_tab_visibility()
	check(scene.hightech_buttons.is_empty() and scene.hightech_progress.is_empty(),"Relock releases all unavailable research controls")
	check(scene.equipment_tabs.is_tab_hidden(1),"Relock hides research page")
	print("Hightech slots: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
