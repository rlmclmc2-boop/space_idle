extends SceneTree
## Full GameSession state at equal elapsed time with different display frame widths.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _sample(group: int) -> Dictionary:
	var session = Session.new()
	var result: Dictionary = session.initialize("res://generated/config.json", 17)
	if result.ok: result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok: return result
	# Use the production campaign path; a direct Battle.start_wave leaves the
	# campaign's departure transition armed and causes a duplicate wave start.
	session.campaign_system._set_stage(10, 0.0)
	for point in session.campaign_system._state.points: point.id = 33011
	session._start_wave()
	if not session.run_state.is_running(): return {"ok": false, "reason": session.run_state.reason()}
	for index in 600 / group:
		session.frame(float(group) / 60.0, true)
		if not session.run_state.is_running(): return {"ok": false, "reason": session.run_state.reason()}
	return {"ok": true, "game_time": session.game_time, "pending": session.pending_seconds,
		"campaign": session.campaign_system.save_state(), "economy": session.economy.save_state(),
		"research": session.research.save_state(), "crew": session.crew_system.save_state(),
		"battle": session.battle._kernel.persistent_state(),
		"history": session.battle._kernel.read_history(),
		"notifications": session.notifications.save_state()}

func _run() -> void:
	var one: Dictionary = _sample(1)
	var four: Dictionary = _sample(4)
	if not one.ok or not four.ok:
		printerr("session frame fixture: ", one if not one.ok else four)
		quit(1)
		return
	for key in ["campaign", "economy", "research", "crew", "battle", "history", "notifications"]:
		if one[key] != four[key]:
			printerr("session frame mismatch in ", key, " clocks=", one.game_time, "/", four.game_time,
				" pending=", one.pending, "/", four.pending)
			if key == "campaign":
				for field in one.campaign:
					if one.campaign[field] != four.campaign.get(field):
						printerr("campaign field ", field, ": ", one.campaign[field], " / ", four.campaign.get(field))
			quit(1)
			return
	if absf(one.game_time - four.game_time) > 0.000001 or absf(one.pending - four.pending) > 0.000001:
		printerr("session clock mismatch: ", one.game_time, " ", four.game_time, " pending ", one.pending, " ", four.pending)
		quit(1)
		return
	print("STAGE6_SESSION_FRAME_EQUIVALENCE_OK 600 steps grouped 1/4; game_time=", one.game_time,
		" history=", one.history.size())
	quit()
