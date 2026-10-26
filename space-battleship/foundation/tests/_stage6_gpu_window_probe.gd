extends SceneTree

const BattleView = preload("res://src/ui/battle_view.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("real renderer required")
		return
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 60
	if not main.startup_error.is_empty():
		_fail(main.startup_error)
		return
	var view: Node = null
	for child in main.get_children():
		if child.get_script() == BattleView: view = child
	if view == null or main.session.battle._presentation == null:
		_fail("native GPU presentation missing")
		return
	main._skip_tutorial = true
	main._sync_guidance()
	for index in 60: await process_frame
	var pause: Button = main._pause_button
	pause.pressed.emit()
	if not main.session.pause_reasons.has("user"):
		_fail("window pause action failed")
		return
	pause.pressed.emit()
	if main.session.pause_reasons.has("user"):
		_fail("window continue action failed")
		return
	var open: Button = main.growth_panel.get_parent().get_child(0)
	open.pressed.emit()
	if not main.growth_panel.visible:
		_fail("growth page action failed")
		return
	main.growth_panel.get_child(0).get_child(0).get_child(0).pressed.emit()
	if main.growth_panel.visible:
		_fail("return to battle failed")
		return
	var start: int = Time.get_ticks_usec()
	var frame_count: int = 600
	var requested: String = OS.get_environment("SPACE_IDLE_GPU_FRAMES")
	if requested.is_valid_int(): frame_count = clampi(requested.to_int(), 600, 36000)
	var maximum_frame_ms: float = 0.0
	var monitor_process_peak_ms: float = 0.0
	var busy_17: int = 0
	var busy_33: int = 0
	var busy_100: int = 0
	var draw_calls: float = 0.0
	var peak_damage_labels: int = 0
	var peak_flights: int = 0
	var peak_pending_seconds: float = 0.0
	var peak_static_mb: float = 0.0
	var peak_video_mb: float = 0.0
	var combat_frames: int = 0
	var frame_samples: Array[float] = []
	var previous_tick: int = Time.get_ticks_usec()
	for index in frame_count:
		await process_frame
		var now_tick: int = Time.get_ticks_usec()
		var frame_ms: float = float(now_tick - previous_tick) / 1000.0
		previous_tick = now_tick
		frame_samples.append(frame_ms)
		maximum_frame_ms = maxf(maximum_frame_ms, frame_ms)
		monitor_process_peak_ms = maxf(monitor_process_peak_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		if frame_ms > 17.0: busy_17 += 1
		if frame_ms > 33.3: busy_33 += 1
		if frame_ms > 100.0: busy_100 += 1
		draw_calls = maxf(draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_damage_labels = maxi(peak_damage_labels, view.damage_labels.size())
		peak_flights = maxi(peak_flights, main.session.battle._kernel.active_flight_count())
		peak_pending_seconds = maxf(peak_pending_seconds, main.session.pending_seconds)
		peak_static_mb = maxf(peak_static_mb, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		peak_video_mb = maxf(peak_video_mb, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		if main.session.campaign_system.restore_checkpoint() == "combat": combat_frames += 1
	if peak_damage_labels == 0:
		_fail("native hit receipts did not reach damage numbers")
		return
	var elapsed_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	frame_samples.sort()
	var p95_ms: float = frame_samples[int((frame_samples.size() - 1) * 0.95)]
	var p99_ms: float = frame_samples[int((frame_samples.size() - 1) * 0.99)]
	var screenshot_path: String = OS.get_environment("SPACE_IDLE_GPU_SCREENSHOT")
	if not screenshot_path.is_empty():
		var image: Image = root.get_viewport().get_texture().get_image()
		if image.save_png(screenshot_path) != OK:
			_fail("screenshot write failed")
			return
	main._damage_option.select(2)
	main._damage_option.item_selected.emit(2)
	for index in 60: await process_frame
	if view.damage_mode != "off" or not view.damage_labels.is_empty():
		_fail("damage number switch did not hide presentation")
		return
	print("STAGE6_GPU_WINDOW_PROBE_OK frames=", frame_count, " wall_ms=", elapsed_ms,
		" p95_frame_wall_ms=", p95_ms, " p99_frame_wall_ms=", p99_ms,
		" max_frame_wall_ms=", maximum_frame_ms,
		" monitor_process_peak_ms=", monitor_process_peak_ms,
		" busy_17=", busy_17, " busy_33=", busy_33, " busy_100=", busy_100,
		" peak_draw_calls=", draw_calls, " combat_frames=", combat_frames,
		" peak_damage_labels=", peak_damage_labels, " peak_flights=", peak_flights,
		" peak_pending_seconds=", peak_pending_seconds, " peak_static_mb=", peak_static_mb,
		" peak_video_mb=", peak_video_mb,
		" screenshot=", screenshot_path)
	quit()
