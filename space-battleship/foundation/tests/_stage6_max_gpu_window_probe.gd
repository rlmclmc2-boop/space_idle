extends "res://foundation/tests/_stage6_gpu_window_probe.gd"
const HyperspacePanel = preload("res://src/ui/hyperspace_panel.gd")

func _find_panel(node: Node):
	if node.get_script() == HyperspacePanel: return node
	for child in node.get_children():
		var found = _find_panel(child)
		if found != null: return found
	return null

func _maximum(session) -> Dictionary:
	var result: Dictionary = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 51)
	if not result.ok: return result
	session.equipment.refresh_availability(session.campaign_system.available, 51, false)
	result = session.campaign_system.change_ship("Heavy_Battleship", session.commit_ship_refit)
	for index in 5:
		if result.ok: result = session.equipment.equip_slot("weapon:" + str(index), ["missile", "longLaser", "cannon", "missile", "longLaser"][index], session.equipment_inputs(), session.publish_equipment_refit)
		if result.get("reason") == "NoChange": result = {"ok": true}
	for index in 3:
		if result.ok: result = session.equipment.equip_slot("defence:" + str(index), "armour" if index == 0 else "shield", session.equipment_inputs(), session.publish_equipment_refit)
		if result.get("reason") == "NoChange": result = {"ok": true}
	var drones: Array = []
	for index in int(session.campaign_system.ship_facts().drone_capacity):
		var donor: Dictionary = session.equipment.drone_weapon_source("missile" if index % 2 == 0 else "longLaser", 0, 0, session._research_factors, session._reactor_factors, session.battle.wave_inputs().motion)
		if not donor.ok: return donor
		drones.append({"id": "gpu-maximum-" + str(index), "generation": 1, "quality": "white", "weapon": donor.weapon})
	if result.ok: result = session.set_equipped_drone_contributions(drones)
	if not result.ok: return result
	var defence: Dictionary = session.battle._values.defences["defence:0"].duplicate()
	defence.base = "1e1000"
	result = session.battle._kernel.set_player_values({}, {"defence:0": defence}, "growth", "")
	if not result.ok: return result
	session.battle.reset_for_sortie()
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.weapon_order = ["repeat", "proficiency", "critical"]
	state.branches = {"repeat": ["B", "", "B"]}
	result = session.enhancement.restore_state(state)
	if not result.ok: return result
	var effects: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	result = session.battle._kernel.set_player_values({}, {}, "growth", "", effects)
	if not result.ok: return result
	session.campaign_system._set_stage(10, 0.0)
	session.campaign_system._state.points[0].id = 33011
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	for enemy in setup.wave.enemies:
		enemy.hp = "1e12"
		enemy.max_hp = "1e12"
	result = session.battle.start_wave(setup)
	if not result.ok: return result
	var own = session.hyperspace_system
	var manual: Dictionary = own.prepare_manual("alpha", 8, {"stage": 8, "point": 0, "guard": false, "guard_point": 0})
	if not manual.ok: return manual
	own.accept_manual(manual.receipt)
	own.advance_manual(10.0)
	var completed: Dictionary = own.finish_manual(true)
	if not completed.ok: return completed
	var sample: Dictionary = completed.receipt.reward.drone
	if sample.is_empty(): return {"ok": false, "reason": "NoWarehouseSample"}
	for index in own._warehouse_capacity():
		var copy: Dictionary = sample.duplicate(true)
		copy.id = "gpu-main-" + str(index)
		own._warehouse.append(copy)
	for index in int(own._parameters.overflow_capacity):
		var copy: Dictionary = sample.duplicate(true)
		copy.id = "gpu-overflow-" + str(index)
		own._overflow.append(copy)
	return {"ok": true}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("real renderer required")
		return
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	Engine.max_fps = 60
	if not main.startup_error.is_empty():
		_fail(main.startup_error)
		return
	main._skip_tutorial = true
	main._sync_guidance()
	main.growth_panel.hide()
	var ready: Dictionary = _maximum(main.session)
	if not ready.ok:
		_fail("maximum renderer fixture: " + str(ready))
		return
	var view: Node = null
	for child in main.get_children():
		if child.get_script() == BattleView: view = child
	var warehouse = _find_panel(main)
	if view == null or warehouse == null or main.session.battle._presentation == null:
		_fail("production presentation or warehouse panel missing")
		return
	view.damage_mode = "all"
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("MAX_GPU_BEGIN renderer=", RenderingServer.get_current_rendering_method(), " adapter=", RenderingServer.get_video_adapter_name(), " vendor=", RenderingServer.get_video_adapter_vendor())
	var phase_frames: int = 1800
	var requested: String = OS.get_environment("SPACE_IDLE_MAX_GPU_PHASE_FRAMES")
	if requested.is_valid_int(): phase_frames = clampi(requested.to_int(), 600, 3600)
	var screenshot: String = OS.get_environment("SPACE_IDLE_GPU_SCREENSHOT")
	for phase in 2:
		if phase == 1:
			main.growth_panel.show()
			warehouse._refresh()
			for index in 2: await process_frame
			var scroll: ScrollContainer = main.growth_panel.get_child(0)
			scroll.ensure_control_visible(warehouse._warehouse)
			if warehouse._warehouse.item_count != 200:
				_fail("full warehouse ItemList must show 200 rows")
				return
		var samples: Array[float] = []
		var gpu_samples: Array[float] = []
		var cpu_peak: float = 0.0
		var static_peak: float = 0.0
		var video_peak: float = 0.0
		var draw_peak: int = 0
		var flight_peak: int = 0
		var label_peak: int = 0
		var busy17: int = 0
		var busy33: int = 0
		var busy100: int = 0
		var started: int = Time.get_ticks_usec()
		var previous: int = started
		for index in phase_frames:
			main.session.battle.begin_frame()
			for step in 10:
				var advanced: Dictionary = main.session.battle.advance(1.0 / 60.0)
				if not advanced.ok or advanced.player_dead or advanced.wave_cleared:
					_fail("maximum sustained wave stopped: " + str(advanced))
					return
			await process_frame
			var now: int = Time.get_ticks_usec()
			var wall: float = float(now - previous) / 1000.0
			previous = now
			samples.append(wall)
			if wall > 17.0: busy17 += 1
			if wall > 33.3: busy33 += 1
			if wall > 100.0: busy100 += 1
			var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			if gpu_ms > 0: gpu_samples.append(gpu_ms)
			cpu_peak = maxf(cpu_peak, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			static_peak = maxf(static_peak, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
			video_peak = maxf(video_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
			draw_peak = maxi(draw_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			flight_peak = maxi(flight_peak, main.session.battle._kernel.active_flight_count())
			label_peak = maxi(label_peak, view.damage_labels.size())
		samples.sort()
		gpu_samples.sort()
		var gpu_p95: float = gpu_samples[int((gpu_samples.size() - 1) * 0.95)] if not gpu_samples.is_empty() else -1.0
		if not screenshot.is_empty():
			if root.get_texture().get_image().save_png(screenshot + "-" + str(phase) + ".png") != OK:
				_fail("maximum screenshot failed")
				return
		if label_peak == 0 or flight_peak < 20:
			_fail("maximum visible battle did not exercise labels/flights: labels=" + str(label_peak) + " flights=" + str(flight_peak))
			return
		print("STAGE6_MAX_GPU_PHASE_OK phase=", phase, " frames=", phase_frames, " wall_ms=", float(Time.get_ticks_usec() - started) / 1000.0,
			" wall_p95_ms=", samples[int((samples.size() - 1) * 0.95)], " wall_p99_ms=", samples[int((samples.size() - 1) * 0.99)], " wall_max_ms=", samples[-1],
			" busy17=", busy17, " busy33=", busy33, " busy100=", busy100, " gpu_samples=", gpu_samples.size(), " gpu_p95_ms=", gpu_p95,
			" gpu_peak_ms=", gpu_samples[-1] if not gpu_samples.is_empty() else -1.0, " process_peak_ms=", cpu_peak, " static_mb=", static_peak, " video_mb=", video_peak,
			" draw_peak=", draw_peak, " flight_peak=", flight_peak, " label_peak=", label_peak, " warehouse=200+10 visible=", phase == 1)
	print("STAGE6_MAX_GPU_WINDOW_OK controlled native10x, production BattleView and full Warehouse ItemList")
	quit()
