extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)

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

func click_return(scene: Node) -> void:
	var point: Vector2 = scene.battle_return_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func run() -> void:
	var scene = TrackedUI.new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1,51)
	scene.game.profile.highestLevel = (int(scene.db.unlock_row("feature","jewels").level)+1)
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.build_ui()
	await process_frame
	var tabs: TabContainer = scene.equipment_tabs
	check(tabs.current_tab == 0 and scene.equipment_panel.visible,"First feature tab is selected by default")
	check(tabs.get_tab_count()>=5 and tabs.get_children().all(func(page):return page.name!="Battle"),"Battlefield is no longer a bottom tab; additional feature tabs are allowed")
	check(scene.battle_return_button.position.y<76,"Return is in the top header")
	var battle: Node = scene.battle_layer
	var resources: Node = scene.resource_layer
	var card: Node = scene.equipment_panel.cards.weapons_0
	var unrelated: Array = [scene.loop_select,scene.loop_button,scene.guard_settings,scene.resource_mode_button,scene.hightech_inventory,scene.charge_cards.values()[0].title]
	var draws := {"resources":0,"background":0,"battle":0}
	resources.draw.connect(func():draws.resources+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	battle.draw.connect(func():draws.battle+=1)
	await process_frame
	for index in range(5):
		await click_tab(tabs,index)
		await process_frame
		await process_frame
		check(tabs.current_tab == index,"Real feature tab click: "+str(index))
		if index==0:
			scene.equipment_panel.set_view_mode("expanded")
			await create_timer(0.25).timeout
		if index == 4:
			check(scene.jewel_panel.visible,"Jewel tab opens center directly without a second click")
		check(scene.battle_return_button.is_visible_in_tree() and scene.battle_return_button.position.y<76,"Top return remains visible: "+str(index))
		if index==4:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/battle-return-jewels.png")
		var before := snapshot(scene)
		scene.writes.clear()
		for key in draws: draws[key]=0
		await click_return(scene)
		check(tabs.current_tab == 0 and tabs.get_tab_bar().current_tab == 0 and scene.equipment_panel.equipment_view_mode=="compact","Return selects compact first tab: "+str(index))
		check(not scene.jewel_panel.visible and not scene.charge_nav_backdrop.visible and tabs.position.y == 620,"Feature overlays dismissed: "+str(index))
		check(snapshot(scene) == before,"Battle and camera state unchanged: "+str(index))
		check(scene.battle_layer == battle and scene.resource_layer == resources and scene.equipment_panel.cards.weapons_0 == card,"Unrelated controls preserved: "+str(index))
		check(unrelated.all(func(control):return not scene.writes.has(control)),"Return does not write unrelated controls: "+str(index))
		check(resources.visible and battle.visible and tabs.visible and draws.resources==0 and draws.background==0 and draws.battle==(1 if index==1 else 0),"Only the occluded research battlefield redraws once on return: "+str(index))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/battle-return.png")
	# Repeated return remains safe and does not rebuild or reset combat.
	var before := snapshot(scene)
	await click_return(scene)
	check(snapshot(scene)==before and scene.equipment_panel.cards.weapons_0==card,"Repeated return preserves battle and cards")
	scene.jewel_panel.open("weapons",0)
	await process_frame
	check(scene.battle_return_button.get_global_rect().end.y<=scene.jewel_panel.position.y,"Equipment socket entry cannot cover top return")
	await click_return(scene)
	check(not scene.jewel_panel.visible and tabs.current_tab==0,"Return also closes equipment socket entry")
	await click_tab(tabs,4)
	await process_frame
	scene.jewel_panel.close()
	await process_frame
	check(not scene.jewel_panel.visible and tabs.current_tab==0 and tabs.position.y==620,"Jewel close uses same first-tab return")
	scene.help_open=true
	scene.refresh_navigation()
	check(not scene.battle_return_button.visible,"Help hides return with navigation")
	scene.help_open=false
	scene.refresh_navigation()
	check(scene.battle_return_button.visible,"Closing help restores return")
	print("Battle tab: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
