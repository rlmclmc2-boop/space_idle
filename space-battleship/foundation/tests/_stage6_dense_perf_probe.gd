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
	var result: Dictionary = session.initialize("res://generated/config.json", 17)
	if not result.ok:
		_fail("session initialization: " + str(result))
		return
	result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		_fail("sortie: " + str(result))
		return
	# Existing production group 33011 has all fifteen logical enemy slots.
	var group: Dictionary = session.campaign_system._groups.get(33011, {})
	if group.is_empty() or str(group.mon).strip_edges().trim_prefix("{").trim_suffix("}").split(",").size() != 15:
		_fail("fifteen-slot fixture unavailable")
		return
	session.campaign_system._set_stage(10, 0.0)
	for point in session.campaign_system._state.points: point.id = 33011
	session._start_wave()
	if not session.run_state.is_running():
		_fail("dense native wave rejected: " + session.run_state.reason())
		return
	var chrono: Dictionary = session.amount_api.apply("from_decimal", ["1000000"])
	if not chrono.ok:
		_fail("chrono fixture failed")
		return
	var wallet: Dictionary = session.economy.budget().duplicate()
	wallet.chrono = chrono.value
	session.economy.accept_budget(wallet)
	result = session.set_chrono_speed(10)
	if not result.ok:
		_fail("10x speed unavailable")
		return
	var peak_flights: int = 0
	var peak_pending: float = 0.0
	var peak_step_ms: float = 0.0
	var total_step_ms: float = 0.0
	var busy_17: int = 0
	var busy_33: int = 0
	var combat_frames: int = 0
	var sum_flights: int = 0
	var peak_static_mb: float = 0.0
	var frames: int = 600
	var requested: String = OS.get_environment("SPACE_IDLE_PERF_FRAMES")
	if requested.is_valid_int(): frames = clampi(requested.to_int(), 600, 12000)
	for index in frames:
		var started: int = Time.get_ticks_usec()
		session.frame(1.0 / 60.0, true)
		var step_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		peak_step_ms = maxf(peak_step_ms, step_ms)
		total_step_ms += step_ms
		if step_ms > 16.7: busy_17 += 1
		if step_ms > 33.3: busy_33 += 1
		peak_flights = maxi(peak_flights, session.battle._kernel.active_flight_count())
		sum_flights += session.battle._kernel.active_flight_count()
		peak_pending = maxf(peak_pending, session.pending_seconds)
		peak_static_mb = maxf(peak_static_mb, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		if session.campaign_system.restore_checkpoint() == "combat": combat_frames += 1
		if not session.run_state.is_running():
			_fail("dense run stopped at frame " + str(index) + " game=" + str(session.game_time)
				+ " campaign=" + str(session.campaign_system._state.state) + ": " + session.run_state.reason())
			return
	if session.game_time < float(frames) * 0.13 or peak_flights < 1:
		_fail("dense 10x simulation did not advance: " + str(session.game_time)
			+ " pending=" + str(peak_pending) + " flights=" + str(peak_flights))
		return
	print("STAGE6_DENSE_PERF_PROBE_OK frames=", frames, " game_seconds=", session.game_time,
		" avg_frame_ms=", total_step_ms / float(frames), " peak_frame_ms=", peak_step_ms,
		" busy_17=", busy_17, " busy_33=", busy_33, " combat_frames=", combat_frames,
		" avg_flights=", float(sum_flights) / float(frames), " peak_flights=", peak_flights,
		" peak_pending_seconds=", peak_pending, " peak_static_mb=", peak_static_mb,
		" campaign=", session.campaign_system.restore_checkpoint())
	quit()
