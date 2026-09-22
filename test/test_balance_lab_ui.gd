extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func activate(window: Window, control: Control) -> void:
	window.grab_focus()
	control.grab_focus()
	await process_frame
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.window_id = window.get_window_id()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	root.gui_embed_subwindows = false
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	var panel = scene.balance_lab
	check(is_instance_valid(panel) and panel.visible,"F8 opens Debug lab")
	if not is_instance_valid(panel):quit(1); return
	panel.set_process(false)
	check(panel.speed_select.get_selected_id() == 100 and panel.duration.value == 3600,"defaults are 100x / one hour")
	check(panel.mode_select.selected == 0,"EXACT remains default")
	check(panel.runner.frame_budget_usec() == 48000,"high speed uses responsive larger work slices")
	panel.runner.speed = 10
	check(panel.runner.frame_budget_usec() == 12000,"normal and low speeds retain original work budget")
	panel.runner.speed = 100
	var profile: Dictionary = scene.game.profile.duplicate(true)
	var player: Dictionary = scene.game.player.duplicate(true)
	var clock_before: float = scene.clock
	var old_ui_id: int = scene.ui.get_instance_id()
	scene._process(0.1)
	check(scene.clock == clock_before and scene.game.profile == profile and scene.game.player == player,"live scene frozen without modifying live state")
	panel.duration_select.select(3)
	panel.duration_select.item_selected.emit(3)
	panel.duration.value = 15
	panel.directory.text = ProjectSettings.globalize_path("res://.runtime/balance_ui")
	await activate(panel,panel.start_button)
	check(panel.runner.status == "running","keyboard Start activation runs simulation")
	check(panel.start_button.disabled and not panel.seed_input.editable,"run config locked")
	var field_id: int = panel.seed_input.get_instance_id()
	panel.runner.process(0.1)
	await activate(panel,panel.pause_button)
	check(panel.runner.status == "paused","keyboard Pause activation")
	var steps: int = panel.runner.steps
	panel._process(0.5)
	check(panel.runner.steps == steps,"paused window does not tick")
	await activate(panel,panel.pause_button)
	check(panel.runner.status == "running","keyboard Resume activation")
	while panel.runner.status == "running":panel.runner.process(0.1,100000)
	panel.refresh_status()
	check(panel.runner.status == "completed" and panel.exports.has("json"),"completion automatically exports")
	check(panel.seed_input.get_instance_id() == field_id and scene.ui.get_instance_id() == old_ui_id,"lab refresh preserves controls and live UI")
	check(scene.game.profile == profile and scene.game.player == player,"simulation leaves live game untouched")
	await process_frame
	await RenderingServer.frame_post_draw
	panel.get_texture().get_image().save_png("res://.runtime/balance-lab.png")
	check(panel.output.size.x > 600 and panel.output.size.y > 250,"report readable size")
	var text_before: String = panel.output.text
	panel.refresh_status()
	check(panel.output.text == text_before,"idle refresh does not repeat serialization/export")
	check(panel.tabs.get_tab_count() == 5,"five v2 tabs")
	var table_id: int = panel.views.tables.strategies.get_root().get_first_child().get_instance_id()
	var writes_before: int = panel.views.writes
	panel.refresh_status()
	check(panel.views.writes == writes_before,"unchanged completed tab writes no table cells")
	check(panel.views.tables.timeline.get_root().get_child_count() == 0,"hidden timeline not populated eagerly")
	panel.tabs.current_tab = 3
	await process_frame
	check(panel.views.tables.timeline.get_root().get_child_count() > 0,"timeline fills on first display")
	check(panel.views.tables.strategies.get_root().get_first_child().get_instance_id() == table_id,"unrelated table items preserved")
	for index in range(1,5):
		panel.tabs.current_tab = index
		await process_frame
		await RenderingServer.frame_post_draw
		panel.get_texture().get_image().save_png("res://.runtime/balance-v2-tab-%d.png" % index)
	panel.tabs.current_tab = 2
	await process_frame
	var buttons: Array = panel.find_children("*","Button",true,false)
	var save_button = buttons.filter(func(control):return control.text == UIText.t("lab.v2.save_baseline"))[0]
	await activate(panel,save_button)
	check(FileAccess.file_exists(panel.baseline_input.text) and panel.runner.completed.comparison.compatible,"keyboard baseline save and immediate comparison")
	panel.runner.baseline_report.clear()
	var load_button = buttons.filter(func(control):return control.text == UIText.t("lab.v2.load_baseline"))[0]
	await activate(panel,load_button)
	check(not panel.runner.baseline_report.is_empty(),"keyboard baseline reload")
	panel.tabs.current_tab = 1
	var mode_id: int = panel.mode_select.get_instance_id()
	panel.mode_select.select(1)
	panel.duration.value = 2
	panel.repeats.value = 2
	panel.scan_select.select(panel.paths.find(["levels",0,"lifeRatio"])+1)
	panel.scan_start.value = 1.08
	panel.scan_end.value = 1.10
	panel.scan_step.value = 0.02
	var add_button = buttons.filter(func(control):return control.text == UIText.t("lab.v2.add_sweep"))[0]
	await activate(panel,add_button)
	check(panel.sweep_queue.size() == 1,"queue actual parameter via keyboard")
	await activate(panel,panel.start_button)
	check(panel.runner.config.simulation_mode == "fast" and panel.mode_select.disabled,"FAST sweep selected and locked while running")
	while panel.runner.status == "running":panel.runner.process(0.1,100000)
	panel.refresh_status()
	check(panel.runner.reports.size() == 4 and panel.views.tables.sweep.get_root().get_child_count() == 2,"queued sweep displays sorted parameter rows")
	check(panel.runner.reports.all(func(row):return row.simulation_mode == "fast"),"every sweep result records FAST")
	check(panel.mode_select.get_instance_id() == mode_id and not panel.mode_select.disabled,"mode control preserved and unlocked on completion")
	check(not panel.runner.completed.comparison.compatible,"different experiment condition visibly flagged")
	panel.close_lab()
	check(not panel.visible,"close hides lab")
	scene._process(0.1)
	check(scene.clock > clock_before,"close restores live processing")
	print("Balance Lab UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
