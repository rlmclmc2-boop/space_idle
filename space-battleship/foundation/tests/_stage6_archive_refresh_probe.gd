extends SceneTree
const Session = preload("res://src/game_session.gd")
const Archive = preload("res://src/ui/archive_panel.gd")
var added: int = 0
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(1); return
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("ARCHIVE_REFRESH_FAILED " + reason)
	quit(1)
	return false
func _added(_node: Node) -> void:
	added += 1
func _wave(session) -> bool:
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	setup.wave.weapons = []
	if not session.battle.start_wave(setup).ok: return false
	session.campaign_system.accept_wave(setup)
	return true
func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var session = Session.new()
	if not _check(session.initialize("res://generated/config.json", 761).ok and session.start_campaign_sortie(1).ok and _wave(session), "initialize"): return
	var panel = Archive.new(session)
	panel.custom_minimum_size.x = 524
	root.add_child(panel)
	panel.set_process(false)
	for frame in 3: await process_frame
	for box in [panel._tutorial, panel._intel, panel._damage]: box.child_entered_tree.connect(_added)
	var uid: int = int(session.battle.enemy_intelligence()[0].uid)
	var row_id: int = panel._intel_rows[uid].row.get_instance_id()
	var old_text: String = panel._intel_rows[uid].label.text
	var height: float = panel.size.y
	var native_before: Dictionary = session.battle.persistent_state().duplicate(true)
	var total: int = 0
	for sample in 120:
		var begin: int = Time.get_ticks_usec()
		panel._refresh()
		total += Time.get_ticks_usec() - begin
		await process_frame
		if not _check(panel._intel_rows[uid].row.get_instance_id() == row_id and panel.size.y == height, "unchanged content rebuilt or resized"): return
	if not _check(added == 0 and session.battle.persistent_state() == native_before, "unchanged refresh adds rows or mutates native"): return
	print("ARCHIVE_UNCHANGED_ROWS_ZERO_REBUILDS_OK mean_us=", float(total) / 120.0)
	for step in 200:
		session.battle.begin_frame()
		if not _check(session.battle.advance(0.05).ok, "native hit"): return
		panel._refresh()
		if panel._intel_rows[uid].label.text != old_text: break
	if not _check(panel._intel_rows[uid].row.get_instance_id() == row_id and panel._intel_rows[uid].label.text != old_text, "HP update did not reuse row"): return
	if not _check(session.start_campaign_sortie(1).ok and _wave(session), "new encounter"): return
	panel._refresh()
	if not _check(not panel._intel_rows.has(uid) and panel._intel_rows.size() == 1, "old UID row retained"): return
	print("STAGE6_ARCHIVE_UID_ROW_REUSE_HP_UPDATE_ENCOUNTER_CHANGE_OK")
	panel.queue_free()
	await process_frame
	panel = null
	session = null
	quit(0)
