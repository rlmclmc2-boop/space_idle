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
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
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
	var notice_count: int = scene.game.pending_unlocks.size()
	check(notice_count>0,"Stage two queues notices from the current unlock table")
	check(scene.continue_button.visible and tabs.visible,"Queued notices keep the right workspace visible")
	check(not scene.equipment_tabs.is_tab_hidden(2),"Charge tab follows table-driven availability")
	var first: Dictionary = scene.db.data.unlock[scene.game.pending_unlocks[0]]
	first.title="Table title fixture"
	first.desc="我们的科学家研发了导弹，导弹可以同时打击多个敌人，并且能够追踪目标。".repeat(40)
	scene.refresh_navigation()
	scene.overlay_layer.queue_redraw()
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	check(scene.unlock_panel_rect().encloses(scene.unlock_scroll.get_global_rect()),"Scrollable text stays inside the unlock panel")
	check(scene.unlock_description.size.x<=scene.unlock_scroll.size.x,"Long description wraps within the content width")
	check(scene.unlock_scroll.get_v_scroll_bar().visible,"Long text exposes a vertical scrollbar")
	var scroll_point: Vector2 = scene.unlock_scroll.get_global_rect().get_center()*Vector2(root.size)/scene.get_viewport_rect().size
	for pressed in [true,false]:
		var wheel := InputEventMouseButton.new()
		wheel.position=scroll_point
		wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed=pressed
		Input.parse_input_event(wheel)
		await process_frame
	check(scene.unlock_scroll.scroll_vertical>0,"Real mouse wheel scrolls long unlock text")
	var scroll_position: int = scene.unlock_scroll.scroll_vertical
	scene.refresh_navigation()
	check(scene.unlock_scroll.scroll_vertical==scroll_position,"Unchanged navigation preserves reading position")
	root.get_texture().get_image().save_png("res://.runtime/unlock-table-text.png")
	for i in notice_count:
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
		check(scene.unlock_scroll.scroll_vertical==0,"Next notice starts at the top")
		check(scene.game.pending_unlocks.size()==previous-1,"Real key advances one notice")
		check(scene.equipment_tabs==tabs and scene.equipment_panel==equipment,"Each page retains unrelated controls")
		if i==1:
			scene.overlay_layer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/unlock-charge.png")
	check(tabs.visible and not scene.continue_button.visible,"Last acknowledgment restores navigation")
	check(not scene.unlock_scroll.visible,"Last acknowledgment hides unlock content")
	scene.queue_free()
	await process_frame
	print("Unlock UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
