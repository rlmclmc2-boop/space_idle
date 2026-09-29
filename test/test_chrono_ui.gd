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
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	var equipment := scene.equipment_panel
	var reactor := scene.reactor_panel
	var tab := scene.chrono_panel
	check(scene.equipment_tabs.get_tab_count()==8 and scene.equipment_tabs.get_tab_idx_from_control(tab)==7,"Chrono is the final independent page")
	check(tab.speed_buttons.size()==scene.game.chrono_options().size() and tab.speed_slider.tick_count==tab.speed_buttons.size(),"Slider stops and markers follow configured options")
	await process_frame
	scene.game.profile.chronoParticles=10
	scene.select_system(7)
	await process_frame
	tab.refresh()
	check(tab.balance_label.text.contains("10") and tab.reserve_bar.value==10 and tab.reserve_bar.max_value==scene.game.chrono_capacity() and not tab.speed_buttons[4].disabled,"Visible balance, reserve bar and paid speed agree")
	await activate(scene.get_window(),tab.speed_buttons[4])
	check(scene.game.speed==5 and tab.current_label.text=="x5  -4/s" and tab.multiplier_label.text=="x5" and tab.selected_speed==5 and tab.speed_slider.value==4,"Marker activation selects and highlights x5")
	check(tab.endurance_label.text.contains("00:00:02"),"Estimated duration uses balance and configured real-time cost")
	var selected_style: StyleBox = tab.speed_buttons[4].get_theme_stylebox("normal")
	tab.refresh()
	check(tab.speed_buttons[4].has_focus() and tab.speed_buttons[4].get_theme_stylebox("normal")==selected_style,"Unchanged refresh retains button focus and style instance")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/chrono-x5.png")
	tab.speed_slider.grab_focus()
	tab.speed_slider.value=9
	check(scene.game.speed==10 and tab.selected_index==9 and tab.flow.intensity>0 and tab.flow.is_processing(),"Highest configured slider stop adds local energy flow")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/chrono-x10.png")
	var left := InputEventKey.new()
	left.window_id = scene.get_window().get_window_id()
	left.keycode = KEY_LEFT
	left.pressed = true
	Input.parse_input_event(left)
	await process_frame
	check(scene.game.speed==9 and tab.speed_slider.value==8,"Keyboard moves slider by one configured stop")
	tab.speed_slider.value=4
	scene.game.start(1,false)
	scene.game.group_index=scene.db.levels[0].groups.size()
	scene.game.distance=0
	scene._process(0.1)
	check(is_equal_approx(scene.game.distance,scene.game.ship_movement()*0.5),"Travel receives one accelerated game interval")
	check(is_equal_approx(float(scene.game.profile.chronoParticles),9.6),"x5 consumes four particles per real second once")
	check(scene.equipment_panel==equipment and scene.reactor_panel==reactor and scene.chrono_panel==tab,"Speed change retains unrelated page controls")
	scene.game.profile.chronoParticles=0.2
	scene._process(0.1)
	check(scene.game.speed==scene.game.default_speed() and scene.game.profile.chronoParticles==0,"Insufficient particles automatically restore configured default")
	check(tab.current_label.text=="x1  -0/s" and tab.speed_slider.value==0 and tab.speed_buttons[4].disabled and tab.endurance_label.text==UIText.t("chrono.endurance_free"),"Exhaustion restores slider, rate and free duration locally")
	scene.game.profile.chronoParticles=3
	scene.game.set_speed(10)
	tab.refresh()
	check(tab.flow.is_processing(),"High multiplier animates only its slider layer")
	scene.game.paused=true
	tab.refresh()
	check(not tab.flow.is_processing(),"Paused page stops energy flow")
	scene.game.paused=false
	tab.refresh()
	scene.select_system(0)
	check(not tab.flow.is_processing(),"Hidden page stops energy flow")
	var hidden_text: String = tab.balance_label.text
	scene.game.profile.chronoParticles=4
	tab.refresh()
	check(tab.balance_label.text==hidden_text,"Hidden page skips ordinary refresh")
	scene.select_system(7)
	check(tab.balance_label.text.contains("4") and tab.flow.is_processing(),"Returning to page catches up and resumes local flow")
	scene.game.set_speed(2)
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var before := float(scene.game.profile.chronoParticles)
	var distance_before := float(scene.game.distance)
	scene._process(0.5)
	check(scene.background_unfocused and scene.game.speed==scene.game.default_speed() and scene.game.profile.chronoParticles==before,"Background resets multiplier and stops particle consumption")
	check(is_equal_approx(scene.game.distance-distance_before,scene.game.ship_movement()*0.5),"Background continues ordinary online travel at x1 without the foreground frame clamp")
	scene.game.profile.chronoSavedAt=Time.get_unix_time_from_system()-10.5
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not scene.background_unfocused and scene.game.speed==scene.game.default_speed() and scene.game.profile.chronoParticles==before,"Returning from running background does not award offline particles")
	var preview := SubViewport.new()
	preview.size=Vector2i(420,540)
	preview.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(preview)
	var narrow := preload("res://scripts/chrono_panel.gd").new()
	narrow.size=Vector2(420,540)
	preview.add_child(narrow)
	narrow.setup(scene)
	await process_frame
	await process_frame
	check(narrow.status_grid.columns==1 and narrow.scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and narrow.content.size.x<=narrow.scroll.size.x+1,"Narrow layout stacks status without horizontal scrolling")
	check(narrow.content.size.y>narrow.scroll.size.y and narrow.marker_strip.size.x>0,"Short layout scrolls vertically and keeps slider width")
	var markers_fit := narrow.speed_buttons.all(func(button):return button.position.x>=0 and button.position.x+button.size.x<=narrow.marker_strip.size.x+1)
	check(markers_fit,"All configured stops stay inside the narrow horizontal rail")
	await RenderingServer.frame_post_draw
	preview.get_texture().get_image().save_png("res://.runtime/chrono-narrow.png")
	narrow.scroll.scroll_vertical=int(narrow.content.size.y)
	await process_frame
	await RenderingServer.frame_post_draw
	preview.get_texture().get_image().save_png("res://.runtime/chrono-narrow-slider.png")
	preview.size=Vector2i(320,480)
	narrow.size=Vector2(320,480)
	await process_frame
	await process_frame
	check(narrow.status_grid.columns==1 and narrow.content.size.x<=narrow.scroll.size.x+1 and narrow.speed_buttons.all(func(button):return button.position.x>=0 and button.position.x+button.size.x<=narrow.marker_strip.size.x+1),"Very narrow rail and status stay within the panel")
	await RenderingServer.frame_post_draw
	preview.get_texture().get_image().save_png("res://.runtime/chrono-compact.png")
	scene.db.config.chronoSpeeds="1|0,3|2,6|5"
	scene.build_ui()
	check(scene.chrono_panel.speed_buttons.size()==3 and scene.chrono_panel.speed_slider.max_value==2 and scene.chrono_panel.speed_buttons[1].text=="x3" and scene.chrono_panel.speed_buttons[1].tooltip_text=="x3  -2/s","Explicit config reload rebuilds slider stops and prices")
	print("Chrono UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
