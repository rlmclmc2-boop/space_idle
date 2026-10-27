extends SceneTree
const Session = preload("res://src/game_session.gd")
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(1); return
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("APPROVED_WEAPON_BIRTH_FAILED " + reason)
	quit(1)
	return false
func _run() -> void:
	var session = Session.new()
	if not _check(session.initialize("res://generated/config.json", 811).ok, "initialize"): return
	if not _check(session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8).ok, "availability fixture"): return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	if not _check(session.equipment.equip_slot("weapon:0", "missile", session.equipment_inputs(), session.publish_equipment_refit).ok and session.start_campaign_sortie(1).ok, "real missile refit"): return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	setup.wave.weapons = []
	setup.wave.enemies[0].hp = "1e12"
	setup.wave.enemies[0].max_hp = "1e12"
	if not _check(session.battle.start_wave(setup).ok, "wave"): return
	var pose: Dictionary = session.battle._weapon_poses["weapon:0"]
	if not _check(pose.ports.size() == 2 and pose.ports[0].distance_to(pose.ports[1]) > 1.0, "two visible launcher mouths"): return
	var seen: Dictionary = {}
	for step in 10000:
		session.battle.begin_frame()
		if not _check(session.battle.advance(0.005).ok, "native advance"): return
		var native: Dictionary = session.battle._kernel.geometry_details()
		var ports: PackedVector2Array = native.muzzles["weapon:0"].numeric_ports
		if not _check(ports == pose.ports and native.muzzles["weapon:0"].screen_ports == pose.ports, "visible/numeric/screen array split"): return
		for flight in native.flights:
			if flight.hostile or flight.source_id != "weapon:0": continue
			var index: int = int(flight.port_index)
			if not _check(index in [0, 1] and flight.launch_point.distance_to(ports[index]) < 0.0001 and flight.launch_screen_point.distance_to(ports[index]) < 0.0001, "actual missile did not leave selected visible mouth"): return
			seen[index] = true
		if seen.size() == 2: break
	if not _check(seen.size() == 2, "both mouths never emitted"): return
	print("STAGE6_APPROVED_TWO_MISSILE_MOUTHS_REAL_NUMERIC_SCREEN_BIRTH_OK")
	quit(0)
