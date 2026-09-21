extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func click_tab(tabs: TabContainer, index: int) -> void:
	var bar := tabs.get_tab_bar()
	var point := bar.global_position + bar.get_tab_rect(index).get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func snapshot(scene: Node) -> String:
	var state := {}
	for property in scene.game.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name not in ["db","rng"]:
			state[property.name] = scene.game.get(property.name)
	state.rng_state = scene.game.rng.state
	for key in ["stars","particles","projectile_visuals","turret_visuals","clock","star_travel","star_streak","shake"]:
		state[key] = scene.get(key)
	return var_to_str(state)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1,51)
	scene.game.profile.highestLevel = int(scene.db.config.jewelDropLevel)
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.build_ui()
	await process_frame
	var tabs: TabContainer = scene.equipment_tabs
	check(tabs.current_tab == scene.BATTLE_TAB,"Initial battlefield is selected")
	var battle: Node = scene.battle_layer
	var resources: Node = scene.resource_layer
	var card: Node = scene.equipment_panel.cards.weapons_0
	var draws := {"resources":0,"background":0,"battle":0}
	resources.draw.connect(func():draws.resources+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	battle.draw.connect(func():draws.battle+=1)
	await process_frame
	for index in range(5):
		await click_tab(tabs,index)
		check(tabs.current_tab == index,"Real feature tab click: "+str(index))
		if index == 4:
			scene.jewel_panel.open()
			await process_frame
		check(tabs.is_visible_in_tree() and not tabs.is_tab_hidden(scene.BATTLE_TAB),"Battle entry remains visible: "+str(index))
		var before := snapshot(scene)
		for key in draws: draws[key]=0
		await click_tab(tabs,scene.BATTLE_TAB)
		check(tabs.current_tab == scene.BATTLE_TAB and tabs.get_tab_bar().current_tab == scene.BATTLE_TAB,"Battle selection: "+str(index))
		check(not scene.jewel_panel.visible and not scene.charge_nav_backdrop.visible and tabs.position.y == 620,"Feature overlays dismissed: "+str(index))
		check(snapshot(scene) == before,"Battle and camera state unchanged: "+str(index))
		check(scene.battle_layer == battle and scene.resource_layer == resources and scene.equipment_panel.cards.weapons_0 == card,"Unrelated controls preserved: "+str(index))
		check(resources.visible and battle.visible and tabs.visible and draws.values().all(func(count):return count==0),"Global UI remains visible without unrelated redraw: "+str(index))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://battle-tab.png")
	print("Battle tab: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
