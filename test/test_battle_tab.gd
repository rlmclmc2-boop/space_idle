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
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()*Vector2(root.size)/Vector2(2048,1280)
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
	return var_to_str(state)

func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1,51)
	scene.game.profile.highestLevel = 51
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.build_ui()
	await process_frame
	var tabs: TabContainer = scene.equipment_tabs
	var battle: Node = scene.battle_layer
	var resources: Node = scene.resource_layer
	var card: Node = scene.equipment_panel.cards.weapons_0
	var unrelated: Array = [scene.loop_select,scene.loop_button,scene.guard_settings,scene.resource_mode_button,scene.hightech_inventory,scene.charge_cards.values()[0].title]
	check(not tabs.tabs_visible and scene.system_nav_buttons.size()==7,"System navigation is vertical")
	check(not scene.has_method("toggle_battle_focus"),"Main screen has no battle focus mode")
	var baseline := snapshot(scene)
	for index in range(5):
		scene.writes.clear()
		await click(scene.system_nav_buttons[index])
		check(tabs.current_tab==index,"Real navigation click: "+str(index))
		if index==4:check(scene.jewel_panel.visible,"Jewel navigation opens the center")
		check(snapshot(scene)==baseline,"Navigation does not change combat state: "+str(index))
		check(scene.battle_layer==battle and scene.resource_layer==resources and scene.equipment_panel.cards.weapons_0==card,"Controls survive navigation: "+str(index))
		check(unrelated.all(func(control):return not scene.writes.has(control)),"Navigation leaves unrelated controls untouched: "+str(index))
		check(battle.visible and resources.visible and scene.battle_clip.position==scene.BATTLE_ORIGIN,"Battle stays fixed beside workspace: "+str(index))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/workspace-navigation.png")
	scene.jewel_panel.close()
	check(not scene.jewel_panel.visible and tabs.current_tab==0,"Jewel close returns to first system")
	scene.help_open=true
	scene.refresh_navigation()
	check(not scene.system_nav.visible,"Help hides navigation")
	scene.help_open=false
	scene.refresh_navigation()
	check(scene.system_nav.visible,"Closing help restores navigation")
	print("Battle navigation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
