extends SceneTree
const Session = preload("res://src/game_session.gd")
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		quit(1)
		return
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("GEOMETRY_CONTRACT_FAILED " + reason)
	quit(1)
	return false
func _session():
	var session = Session.new()
	if not session.initialize("res://generated/config.json", 317).ok: return null
	if not session.start_campaign_sortie(1).ok: return null
	return session
func _run() -> void:
	var session = _session()
	if not _check(session != null, "session initialization"): return
	var battle = session.battle
	if not _check(battle._kernel.has_method("geometry_details"), "rebuilt native query required"): return
	for key in ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]:
		var mount: Dictionary = battle.mount_inputs(key)
		var bounds: Rect2 = battle._hull_bounds(battle._models[key].hull)
		var authored: float = float(mount.art.static_height) * float(mount.geometry.player_display_multiplier) * float(battle._parameters["playerVisualScale" + key])
		if not _check(absf(bounds.size.y * mount.dimensions.y - authored) < 0.001, "authored shared dimensions " + key): return
	var inputs: Dictionary = battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	setup.wave.weapons = []
	setup.wave.enemies[0].hp = "1e9"
	setup.wave.enemies[0].max_hp = "1e9"
	if not _check(battle.start_wave(setup).ok, "pulse fixture"): return
	var details: Dictionary = battle._kernel.geometry_details()
	if not _check(details.player_collision_hull == battle._player_hull, "visible player differs from native hull"): return
	for index in battle._enemy_hulls.size():
		if not _check(details.actors[index].collision_hull == battle._enemy_hulls[index], "visible enemy differs from native hull"): return
	for id in battle._weapon_poses:
		var pose: Dictionary = battle._weapon_poses[id]
		if not _check(pose.ports.size() == details.muzzles[id].numeric_ports.size(), "all authored ports preserved " + id): return
		for port in pose.ports.size():
			var drawn_port: Vector2 = pose.pivot + Vector2(pose.local_ports[port]).rotated(pose.angle)
			if not _check(drawn_port.distance_to(details.muzzles[id].numeric_ports[port]) < 0.0001 and drawn_port.distance_to(details.muzzles[id].screen_ports[port]) < 0.0001, "render/numeric/screen port " + id): return
	var born: bool = false
	for step in 2000:
		if not _check(battle.advance(0.001).ok, "pulse advance"): return
		details = battle._kernel.geometry_details()
		for flight in details.flights:
			if flight.hostile: continue
			var source: Dictionary = details.muzzles[flight.source_id]
			if not _check(flight.launch_point.distance_to(source.numeric) < 0.0001 and flight.ray_origin.distance_to(source.screen) < 0.0001, "actual retained pulse birth"): return
			born = true
		if born: break
	if not _check(born, "no real pulse birth"): return
	print("GEOMETRY_SHARED_FIVE_HULL_SIZES_AND_REAL_PULSE_PORT_OK")
	# Independent ray/polygon intersection predicts a real hostile cannon contact.
	session = _session()
	battle = session.battle
	inputs = battle.wave_inputs()
	setup = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	var source: Dictionary = setup.wave.weapons[0].duplicate(true)
	source.kind = 1
	source.speed = 100.0
	source.remaining = 0.0
	source.interval = 1000.0
	source.damage = "1e2"
	setup.wave.weapons = [source]
	setup.wave.enemies[0].hp = "1e9"
	setup.wave.enemies[0].max_hp = "1e9"
	if not _check(battle.start_wave(setup).ok, "hostile cannon fixture"): return
	var zero: Dictionary = battle._values.weapons["weapon:0"].duplicate()
	zero.base = "0"
	if not _check(battle._kernel.set_player_values({"weapon:0": zero}, {}, "growth", "").ok, "zero player fixture damage"): return
	details = battle._kernel.geometry_details()
	var enemy_id: String = "enemy:" + str(setup.wave.enemies[0].uid) + ":" + str(int(source.slot))
	var launch: Vector2 = details.muzzles[enemy_id].numeric
	var target: Vector2 = details.player_point
	var distance: float = INF
	var polygon: PackedVector2Array = battle._player_hull
	for index in polygon.size():
		var intersection = Geometry2D.segment_intersects_segment(launch, target, polygon[index], polygon[(index + 1) % polygon.size()])
		if intersection != null: distance = minf(distance, launch.distance_to(intersection))
	if not _check(is_finite(distance), "visible silhouette intersection"): return
	var expected: float = distance / 100.0
	var armour_before: String = str(battle.hud_values().armour)
	if not _check(battle.advance(0.001).ok, "enemy cannon birth"): return
	details = battle._kernel.geometry_details()
	var enemy_birth: bool = false
	for flight in details.flights:
		if not flight.hostile: continue
		if not _check(flight.launch_point.distance_to(launch) < 0.0001, "enemy cannon visible muzzle birth"): return
		enemy_birth = true
	if not _check(enemy_birth, "no enemy cannon flight"): return
	var time: float = 0.001
	while time < expected - 0.0005:
		var step: float = minf(0.01, expected - 0.0005 - time)
		if not _check(battle.advance(step).ok, "before visible contact advance"): return
		time += step
		if not _check(str(battle.hud_values().armour) == armour_before, "damage before visible hull contact"): return
	if not _check(battle.advance(0.001).ok and str(battle.hud_values().armour) != armour_before, "no damage at visible hull contact"): return
	print("GEOMETRY_HOSTILE_CANNON_BIRTH_AND_VISIBLE_HULL_CONTACT_OK contact_seconds=", expected)
	quit(0)
