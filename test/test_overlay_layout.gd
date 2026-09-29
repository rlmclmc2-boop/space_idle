extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.encloses(inner)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	var initial_size := root.size
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="keep","Window scaling preserves the logical layout aspect ratio")
	var viewport: Rect2 = scene.get_viewport_rect()
	var workspace: Rect2 = scene.workspace_frame.get_global_rect()
	await process_frame
	await RenderingServer.frame_post_draw
	var before_toast := root.get_texture().get_image()
	var notice: Rect2 = scene.battle_notice_rect(0)
	var battle_hud := Rect2(30,100,552,98)
	check(inside(notice,battle_hud) and inside(scene.battle_notice_rect(1),battle_hud) and not notice.intersects(workspace),"Both event rows fit inside the battle status panel")
	check(scene.battle_notice_rect(1).end.y<=battle_hud.end.y,"Notifications do not enter the battle picture")
	check(scene.overlay_layer.z_index>scene.ui.z_index and scene.continue_button.z_index>scene.overlay_layer.z_index and scene.help_close_button.z_index>scene.overlay_layer.z_index,"Modal drawing sits above pages and below its buttons")
	scene.toast("Layout audit notice")
	scene.refresh_draw_layers(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var after_toast := root.get_texture().get_image()
	after_toast.save_png("res://.runtime/overlay-toast.png")
	var image_scale := Vector2(after_toast.get_size())/viewport.size
	var old_edge := Rect2i(Vector2i(Vector2(1078,91)*image_scale),Vector2i(Vector2(465,5)*image_scale))
	check(before_toast.get_region(old_edge).get_data()==after_toast.get_region(old_edge).get_data(),"Old exposed edge remains unchanged when an event appears")
	var jewel_drop := {"uid":99007,"x":200.0,"y":340.0,"id":"jewel","amount":5.4}
	scene.on_event("jewel_pickup",jewel_drop)
	var jewel_flight: TextureRect = scene.jewel_panel.flights[(scene.jewel_panel.flight_cursor-1)%scene.jewel_panel.flights.size()]
	var jewel_origin: Vector2 = scene.battle_layer.to_global(scene.drop_render_position(jewel_drop))
	check(jewel_flight.visible and jewel_flight.global_position.is_equal_approx(jewel_origin-Vector2(16,16)),"Gem flight starts at the visible portrait battle drop")
	check(scene.battle_notices().size()==1 and scene.battle_notice_rect(0)==notice,"Gem pickup feedback uses the battlefield notice")
	scene.help_open=true
	scene.refresh_navigation()
	scene.refresh_draw_layers(0)
	check(inside(scene.overlay_panel_rect(Vector2(820,551)),viewport) and inside(scene.help_close_button.get_global_rect(),viewport),"Help panel and close button stay on screen")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/overlay-help.png")
	scene.help_open=false
	scene.game.pending_unlocks.assign(["shield"])
	scene.refresh_navigation()
	scene.refresh_draw_layers(0)
	var battle := Rect2(scene.BATTLE_ORIGIN,scene.BATTLE_VIEW_SIZE)
	check(inside(scene.unlock_panel_rect(),battle) and inside(scene.continue_button.get_global_rect(),scene.unlock_panel_rect()),"Unlock panel and continue button fit the left battlefield")
	check(scene.unlock_panel_rect().get_center().is_equal_approx(battle.get_center()),"Unlock is centered in the battlefield")
	check(scene.workspace_frame.visible and scene.system_nav.visible and scene.equipment_tabs.visible,"Unlock keeps the right workspace visible")
	check(not scene.unlock_panel_rect().intersects(workspace),"Unlock does not cover the workspace")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/overlay-unlock.png")
	var tabs = scene.equipment_tabs
	var selected_tab: int = tabs.current_tab
	var point: Vector2 = scene.continue_button.get_global_rect().get_center()*Vector2(root.size)/viewport.size
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	check(scene.game.pending_unlocks.is_empty(),"Real mouse click confirms the relocated unlock notice")
	check(scene.equipment_tabs==tabs and tabs.current_tab==selected_tab,"Confirming an unlock preserves the workspace and selected tab")
	scene.game.pending_unlocks.clear()
	for dimensions in [Vector2i(1600,900),Vector2i(900,1440)]:
		root.size=dimensions
		await process_frame
		await RenderingServer.frame_post_draw
		print("Requested window: ",dimensions,"; actual window: ",root.size,"; layout viewport: ",scene.get_viewport_rect().size)
		viewport=scene.get_viewport_rect()
		scene.help_open=true
		scene.refresh_navigation()
		scene.refresh_draw_layers(0)
		check(inside(scene.overlay_panel_rect(Vector2(820,551)),viewport) and inside(scene.help_close_button.get_global_rect(),viewport),"Help stays within resized viewport: "+str(dimensions))
		scene.help_open=false
		scene.game.pending_unlocks.assign(["shield"])
		scene.refresh_navigation()
		scene.refresh_draw_layers(0)
		check(inside(scene.unlock_panel_rect(),battle) and inside(scene.continue_button.get_global_rect(),scene.unlock_panel_rect()),"Unlock stays in battlefield after resize: "+str(dimensions))
		scene.game.pending_unlocks.clear()
		scene.refresh_navigation()
	root.size=initial_size
	print("Overlay layout: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
