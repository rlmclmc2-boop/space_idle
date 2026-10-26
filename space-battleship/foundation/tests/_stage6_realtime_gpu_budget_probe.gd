extends "res://foundation/tests/_stage6_max_gpu_window_probe.gd"

func _percentile(values: Array[float], ratio: float) -> float:
	values.sort()
	return values[int((values.size() - 1) * ratio)] if not values.is_empty() else -1.0

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("real renderer required")
		return
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main._skip_tutorial = true
	main._sync_guidance()
	var session = main.session
	var ready: Dictionary = _maximum(session)
	if not ready.ok:
		_fail(str(ready))
		return
	# Use actual owner state/loadout and the production Session.frame time bank.
	var equipment: Dictionary = session.equipment.save_state()
	for slot in equipment.slots:
		if slot.id == "defence:0": slot.paid_level = 1000
	ready = session.equipment.restore_state(equipment, session.campaign_system.ship_facts().mounts)
	var own = session.hyperspace_system
	var ids: Array = []
	for index in 4:
		var drone: Dictionary = own._warehouse[index]
		drone.weapon = "missile" if index % 2 == 0 else "longLaser"
		drone.origin_quality = "white"
		drone.legendary = false
		drone.ultimate = false
		drone.affixes = []
		drone.hangings = []
		ids.append(str(drone.id))
	if ready.ok: ready = session.equip_hyperspace_drones(ids)
	if not ready.ok:
		_fail("realtime loadout: " + str(ready))
		return
	var budget: Dictionary = session.economy.budget().duplicate()
	budget.chrono = session.amount_api.apply("from_decimal", ["1e9"]).value
	session.economy.accept_budget(budget)
	ready = session.set_chrono_speed(10)
	session.campaign_system.consume_departure(100.0)
	session.campaign_system._state.state = "combat"
	session.pause_reasons.clear()
	var warehouse = _find_panel(main)
	main.growth_panel.show()
	warehouse._refresh()
	for index in 2: await process_frame
	main.growth_panel.get_child(0).ensure_control_visible(warehouse._warehouse)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var previous: int = Time.get_ticks_usec()
	for index in 150:
		await process_frame
		var now: int = Time.get_ticks_usec()
		session.frame(float(now - previous) / 1000000.0, true)
		main._sync_guidance()
		previous = now
		if not session.run_state.is_running():
			_fail("realtime warmup: " + session.run_state.reason())
			return
	print("REALTIME_GPU_WARMUP_DONE game=", session.game_time, " pending=", session.pending_seconds, " loadout=", session.battle._equipped_drones.size())
	for phase in 2:
		Engine.max_fps = 60 if phase == 0 else 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if phase == 0 else DisplayServer.VSYNC_DISABLED)
		var wall: Array[float] = []
		var work: Array[float] = []
		var wait_tail: Array[float] = []
		var gpu: Array[float] = []
		var render_cpu: Array[float] = []
		var busy_wall: Array = [0, 0, 0]
		var busy_work: Array = [0, 0, 0]
		var pending_peak: float = session.pending_seconds
		var step_peak: int = 0
		var game_start: float = session.game_time
		var session_wall_start: float = session.wall_time
		var pending_start: float = session.pending_seconds
		var started: int = Time.get_ticks_usec()
		previous = started
		var last_work_end: int = started
		while float(Time.get_ticks_usec() - started) < 10000000.0:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var delta: float = float(now - previous) / 1000000.0
			wall.append(delta * 1000.0)
			wait_tail.append(float(now - last_work_end) / 1000.0)
			previous = now
			var before: float = session.game_time
			session.frame(delta, true)
			main._sync_guidance()
			last_work_end = Time.get_ticks_usec()
			work.append(float(last_work_end - now) / 1000.0)
			step_peak = maxi(step_peak, int(round((session.game_time - before) * 60.0)))
			pending_peak = maxf(pending_peak, session.pending_seconds)
			var measured_gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			if measured_gpu > 0.0: gpu.append(measured_gpu)
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			for index in 3:
				if wall[-1] > [17.0, 33.3, 100.0][index]: busy_wall[index] += 1
				if work[-1] > [17.0, 33.3, 100.0][index]: busy_work[index] += 1
			if not session.run_state.is_running() or session.campaign_system.restore_checkpoint() != "combat":
				_fail("realtime run stopped: " + session.run_state.reason())
				return
		var elapsed: float = float(previous - started) / 1000000.0
		var game_delta: float = session.game_time - game_start
		var requested: float = (session.wall_time - session_wall_start) * 10.0
		var bank_error: float = game_delta + session.pending_seconds - pending_start - requested
		if absf(bank_error) > 0.00001:
			_fail("realtime accepted time lost: " + str(bank_error))
			return
		print("STAGE6_REALTIME_GPU_PHASE_OK phase=", phase, " fps_cap=", Engine.max_fps, " vsync=", DisplayServer.window_get_vsync_mode(),
			" frames=", wall.size(), " wall_seconds=", elapsed, " requested_game_seconds=", requested, " game_seconds=", game_delta, " actual_speed=", game_delta / elapsed,
			" logical_steps=", int(round(game_delta * 60.0)), " step_peak=", step_peak, " pending_peak=", pending_peak, " pending_end=", session.pending_seconds, " bank_error=", bank_error,
			" wall_p95=", _percentile(wall, 0.95), " wall_p99=", _percentile(wall, 0.99), " wall_peak=", wall[-1], " busy_wall_17_33_100=", busy_wall,
			" session_work_p95=", _percentile(work, 0.95), " session_work_p99=", _percentile(work, 0.99), " session_work_peak=", work[-1], " busy_work_17_33_100=", busy_work,
			" non_session_tail_p95=", _percentile(wait_tail, 0.95), " render_cpu_p95=", _percentile(render_cpu, 0.95), " gpu_p95=", _percentile(gpu, 0.95), " gpu_peak=", gpu[-1] if not gpu.is_empty() else -1.0)
	print("STAGE6_REALTIME_GPU_BUDGET_OK production Session.frame at real10x, maximum loadout/full warehouse, capped and uncapped after warmup")
	quit()
