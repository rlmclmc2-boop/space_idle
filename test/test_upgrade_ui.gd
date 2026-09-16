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

func run() -> void:
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	scene.game.profile.resources = {"1":1e6,"2":1e6}
	scene.build_ui()
	await process_frame
	await process_frame
	var tabs = scene.equipment_tabs
	var action: Button = scene.upgrade_buttons.laser
	var old_level := int(scene.game.first_equipment_entry("laser").level)
	var mouse := InputEventMouseMotion.new()
	mouse.position = action.get_global_rect().get_center()
	Input.parse_input_event(mouse)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = mouse.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await process_frame
	check(int(scene.game.first_equipment_entry("laser").level) == old_level+1, "Real mouse click upgrades once")
	check(scene.equipment_tabs == tabs and scene.upgrade_buttons.laser == action, "Upgrade preserves control instances")
	check(scene.equipment_card_controls.weapons_0.title.text.contains("Lv.2"), "Level label refreshes")
	check(scene.equipment_card_controls.weapons_0.cost.text.contains(scene.cost_text(scene.game.slot_upgrade_cost("weapons",0))), "Cost label refreshes")
	scene.game.profile.resources = {"1":0.0,"2":0.0}
	scene._process(0)
	check(scene.max_upgrade_buttons.laser.disabled, "MAX disables when unaffordable")
	scene.game.profile.resources = scene.game.slot_upgrade_cost("weapons",0,3)
	scene.game.profile.resources["2"] = 0.0
	scene._process(0)
	check(not scene.max_upgrade_buttons.laser.disabled, "MAX enables when resources arrive")
	scene.max_upgrade_buttons.laser.pressed.emit()
	check(int(scene.game.first_equipment_entry("laser").level) == old_level+4, "MAX uses current resources rather than construction snapshot")
	scene.equipment_tabs.current_tab = 1
	scene.on_event("state",{})
	scene.on_event("state",{})
	scene.on_event("hightech_complete",{"key":BattleGame.ENERGY_FOCUS})
	check(scene.equipment_tabs == tabs and not scene.ui_rebuild_pending, "State and research events do not request full rebuild")
	scene._process(0)
	var rebuilt = scene.equipment_tabs
	check(rebuilt == tabs and not scene.ui_rebuild_pending, "Events preserve the existing tab container")
	check(tabs.visible, "Existing tree remains visible")
	check(rebuilt.current_tab == 1, "Local refresh preserves selected tab")
	scene._process(0)
	check(scene.equipment_tabs == rebuilt, "No redundant next-frame rebuild")
	for frame in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/upgrade-ui-%d.png" % frame)
	print("Upgrade UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
