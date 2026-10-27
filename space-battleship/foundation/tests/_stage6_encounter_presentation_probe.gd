extends SceneTree
const Session = preload("res://src/game_session.gd")
class ShipDraw extends Node2D:
	var battle
	var draws: int = 0
	func _draw() -> void:
		draws += 1
		battle.draw_player_hull(self)
		battle.draw_enemy_overlays(self, ThemeDB.fallback_font)
		battle.draw_weapon_art(self)
var session
var surface
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		quit(1)
		return
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("ENCOUNTER_PRESENTATION_FAILED " + reason)
	quit(1)
	return false
func _spawn(lethal: bool = false) -> bool:
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not _check(setup.ok and not setup.wave.weapons.is_empty(), "fixture wave"): return false
	if lethal:
		var cannon: Dictionary = setup.wave.weapons[0].duplicate(true)
		cannon.kind = 1
		cannon.speed = 10000.0
		cannon.damage = "1e12"
		cannon.remaining = 0.0
		cannon.interval = 1000.0
		setup.wave.weapons = [cannon]
	if not _check(session.battle.start_wave(setup).ok, "native start wave"): return false
	session.campaign_system.accept_wave(setup)
	return _check(not session.battle._enemy_visual_weapons.is_empty() and not session.battle._kernel.enemy_views().is_empty(), "fixture has no enemy presentation")
func _retired(label: String, actors_empty: bool = true) -> bool:
	var battle = session.battle
	if not _check(battle._enemy_visual_weapons.is_empty() and battle._enemy_muzzles.is_empty(), label + " retained enemy descriptors"): return false
	for id in battle._weapon_poses:
		if not _check(not str(id).begins_with("enemy:"), label + " retained enemy pose"): return false
	if actors_empty and not _check(battle._kernel.enemy_views().is_empty() and battle._enemy_hulls.is_empty(), label + " retained actor geometry"): return false
	return _check(battle._weapon_poses.has("weapon:0"), label + " lost player pose")
func _draw_frame() -> void:
	surface.queue_redraw()
	RenderingServer.force_draw(false)
	await process_frame
func _run() -> void:
	session = Session.new()
	if not _check(session.initialize("res://generated/config.json", 503).ok and session.start_campaign_sortie(1).ok, "session startup"): return
	surface = ShipDraw.new()
	surface.battle = session.battle
	root.add_child(surface)
	if not _spawn(): return
	await _draw_frame()
	var old_ids: Array = session.battle._enemy_muzzles.keys()
	if not _check(session.start_campaign_sortie(1).ok, "repeat sortie command"): return
	if not _retired("sortie"): return
	await _draw_frame()
	if not _spawn(true): return
	for id in session.battle._enemy_muzzles:
		if not _check(not old_ids.has(id), "new encounter reused old source identity"): return
	await _draw_frame()
	var retreated: bool = false
	for step in 1000:
		session._step(1.0 / 60.0)
		if not _check(session.run_state.is_running(), "session stopped during real retreat"): return
		var state: String = str(session.campaign_system.scenery_facts().state)
		if state == "retreat":
			retreated = true
			if not _retired("retreat begin", false): return
		if retreated and state != "retreat": break
	if not _check(retreated, "real lethal hit did not enter retreat"): return
	if not _retired("retreat recovery"): return
	await _draw_frame()
	session.campaign_system._state.highest_reached = 8
	session.campaign_system._cycle_reached = 8
	if not _check(session.start_hyperspace_manual("alpha").ok and not session.battle._enemy_visual_weapons.is_empty(), "manual challenge fixture"): return
	await _draw_frame()
	if not _check(session.exit_hyperspace_manual().ok, "manual return"): return
	if not _retired("hyperspace return"): return
	await _draw_frame()
	if not _check(surface.draws >= 6, "Node2D draw path was not exercised"): return
	print("STAGE6_ENCOUNTER_PRESENTATION_SORTIE_RETREAT_HYPERSPACE_DRAW_OK draws=", surface.draws)
	surface.queue_free()
	await process_frame
	surface = null
	session = null
	quit(0)
