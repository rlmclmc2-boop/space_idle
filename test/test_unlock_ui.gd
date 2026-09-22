extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile=scene.game.fresh_profile()
	scene.game.profile.cleared=[1]
	scene.game.rebuild_unlocks()
	scene.game.start(2,false)
	var tabs: Node = scene.equipment_tabs
	var equipment: Node = scene.equipment_panel
	scene.game.clear_level()
	scene.refresh_navigation()
	scene.refresh_draw_layers(0)
	check(scene.game.pending_unlocks.size()==4,"Stage two queues two equipment and two systems")
	check(scene.continue_button.visible and not tabs.visible,"Queued notices use existing modal navigation")
	check(not scene.equipment_tabs.is_tab_hidden(2),"Charge tab follows table-driven availability")
	var first: Dictionary = scene.db.data.unlock[scene.game.pending_unlocks[0]]
	first.title="Table title fixture"
	first.desc="Table description fixture"
	scene.overlay_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/unlock-table-text.png")
	for i in 4:
		var previous: int = scene.game.pending_unlocks.size()
		var event := InputEventKey.new()
		event.keycode=KEY_SPACE
		event.pressed=true
		Input.parse_input_event(event)
		await process_frame
		event=InputEventKey.new()
		event.keycode=KEY_SPACE
		event.pressed=false
		Input.parse_input_event(event)
		await process_frame
		scene.refresh_navigation()
		scene.refresh_draw_layers(0)
		check(scene.game.pending_unlocks.size()==previous-1,"Real key advances one notice")
		check(scene.equipment_tabs==tabs and scene.equipment_panel==equipment,"Each page retains unrelated controls")
		if i==1:
			scene.overlay_layer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/unlock-charge.png")
	check(tabs.visible and not scene.continue_button.visible,"Last acknowledgment restores navigation")
	scene.queue_free()
	await process_frame
	print("Unlock UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
