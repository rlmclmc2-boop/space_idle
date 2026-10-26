extends SceneTree

const Session = preload("res://src/game_session.gd")

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
	var session = Session.new()
	var result: Dictionary = session.initialize("res://generated/config.json", 29)
	if result.ok: result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		_fail("session fixture: " + str(result))
		return
	var defence: Dictionary = session.battle._values.defences["defence:0"].duplicate()
	defence.base = "1e1000"
	result = session.battle._kernel.set_player_values({}, {"defence:0": defence}, "growth", "")
	if not result.ok:
		_fail("survivability fixture: " + str(result))
		return
	session.battle.reset_for_sortie()
	session.campaign_system._set_stage(10, 0.0)
	var group: Dictionary = session.campaign_system._groups.get(33011, {})
	if group.is_empty() or str(group.mon).strip_edges().trim_prefix("{").trim_suffix("}").split(",").size() != 15:
		_fail("fifteen-slot fixture unavailable")
		return
	session.campaign_system._state.points[0].id = 33011
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		_fail("dense wave setup: " + str(setup))
		return
	result = session.battle.start_wave(setup)
	if not result.ok:
		_fail("dense native wave: " + str(result))
		return
	var frames: int = 3600
	var requested: String = OS.get_environment("SPACE_IDLE_STRESS_FRAMES")
	if requested.is_valid_int(): frames = clampi(requested.to_int(), 600, 7200)
	var total_ms: float = 0.0
	var peak_ms: float = 0.0
	var busy_17: int = 0
	var busy_33: int = 0
	var flight_sum: int = 0
	var peak_flights: int = 0
	var peak_queued: int = 0
	var peak_flight_slots: int = 0
	var peak_active_capacity: int = 0
	var peak_feedback_capacity: int = 0
	var peak_static_mb: float = 0.0
	var wave_restarts: int = 0
	for frame in frames:
		var started: int = Time.get_ticks_usec()
		session.battle.begin_frame()
		for step in 10:
			var advanced: Dictionary = session.battle.advance(1.0 / 60.0)
			if not advanced.ok:
				_fail("native 10x step " + str(frame) + ": " + str(advanced) + " player=" + str(session.battle._kernel.player_view()) + " results=" + str(session.battle._kernel.take_results()))
				return
			if advanced.wave_cleared:
				session.battle.finish_wave(false)
				result = session.battle.start_wave(setup)
				if not result.ok:
					_fail("dense wave restart: " + str(result))
					return
				wave_restarts += 1
		var frame_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		total_ms += frame_ms
		peak_ms = maxf(peak_ms, frame_ms)
		if frame_ms > 16.7: busy_17 += 1
		if frame_ms > 33.3: busy_33 += 1
		var metrics: Dictionary = session.battle._kernel.workload_metrics()
		var queued: int = int(metrics.root_queue) + int(metrics.ejection_queue) + int(metrics.repeat_queue) + int(metrics.strange_queue)
		flight_sum += int(metrics.active_flights)
		peak_flights = maxi(peak_flights, int(metrics.active_flights))
		peak_queued = maxi(peak_queued, queued)
		peak_flight_slots = maxi(peak_flight_slots, int(metrics.flight_slots))
		peak_active_capacity = maxi(peak_active_capacity, int(metrics.active_capacity))
		peak_feedback_capacity = maxi(peak_feedback_capacity, int(metrics.feedback_capacity))
		peak_static_mb = maxf(peak_static_mb, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	if peak_flights == 0 or not session.run_state.is_running():
		_fail("sustained native combat did not remain active")
		return
	print("STAGE6_NATIVE_STRESS_OK frames=", frames, " game_seconds=", float(frames) / 6.0,
		" avg_frame_ms=", total_ms / float(frames), " peak_frame_ms=", peak_ms,
		" busy_17=", busy_17, " busy_33=", busy_33,
		" avg_flights=", float(flight_sum) / float(frames), " peak_flights=", peak_flights,
		" peak_queued=", peak_queued, " peak_flight_slots=", peak_flight_slots,
		" peak_active_capacity=", peak_active_capacity, " peak_feedback_capacity=", peak_feedback_capacity,
		" peak_static_mb=", peak_static_mb, " wave_restarts=", wave_restarts)
	quit()
