extends SceneTree

class EnemyProjectionProbe extends "res://src/systems/battle.gd":
	func _init() -> void:
		pass

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS ", label)

func enemy(uid: int, hp: String, capacity: String, shield: String, maximum: String, y: float) -> Dictionary:
	return {"uid": uid, "hp": hp, "max_hp": capacity, "shield": shield, "max_shield": maximum,
		"x": 0.0, "y": y, "visual_key": "probe", "shieldDelay": 0.5, "shieldRecovery": 0.5}

func descriptor(enemies: Array, attack: bool) -> Dictionary:
	return {"player": {"x": 0.0, "y": 200.0}, "target_slot_center": 0.0,
		"enemies": enemies, "weapons": [{"kind": 1, "damage": "10", "interval": 100.0,
		"remaining": 0.0, "muzzle": Vector2(0, 200)}] if attack else [],
		"defences": [{"base": "100", "maximum": "100", "layer": 1}]}

func geometry(view, offset: Vector2 = Vector2.ZERO) -> void:
	var actors: Array = view._kernel.enemy_views()
	var packet: Dictionary = {"hulls": [], "poses": []}
	for actor in actors:
		var origin := Vector2(float(actor.x), float(actor.y)) + offset
		packet.hulls.append(PackedVector2Array([origin + Vector2(-2, -2), origin + Vector2(2, -2), origin + Vector2(0, 2)]))
		packet.poses.append({"origin": origin})
	view._cache_enemy_presentation_geometry(actors, packet)
	view._enemy_hulls = packet.hulls

func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	check(status == GDExtensionManager.LOAD_STATUS_OK or status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED, "load candidate native extension")
	if failures:
		quit(1)
		return
	var k = ClassDB.instantiate("SpaceCombatKernel")
	check(k.initialize(descriptor([enemy(1, "100", "100", "100", "100", 100), enemy(2, "100", "100", "100", "100", 0), enemy(3, "5e1000", "1e1001", "0", "0", -100)], true)), "initialize controlled accepted facts")
	k.set_damage_stats_enabled(true)
	var view = EnemyProjectionProbe.new()
	view._kernel = k
	geometry(view)
	var initial: Array = view.enemy_presentation()
	check(initial.is_read_only() and initial[0].is_read_only(), "public snapshots are read-only")
	check(initial[2].armour == "5e1000" and initial[2].max_armour == "1e1001" and is_equal_approx(initial[2].armour_fraction, 0.5) and initial[2].shield_fraction == 0.0, "huge Amount and zero shield capacity")
	var clock: float = k.presentation_clock()
	var history: Dictionary = k.read_history()
	var native_rows: Array = k.enemy_views()
	for repeat in 20:
		check(is_same(initial, view.enemy_presentation()) and is_same(native_rows, k.enemy_views()), "unchanged read reuses native and Battle arrays #" + str(repeat))
	check(k.presentation_clock() == clock and k.read_history() == history, "queries do not advance clocks or history")
	var body_cache: Array = view._enemy_presentation_geometry
	geometry(view)
	check(is_same(body_cache, view._enemy_presentation_geometry), "unchanged shared hull reuses geometry/bounds cache")
	check(k.advance(0.1), "advance first shot")
	var damaged: Array = view.enemy_presentation()
	check(damaged[0].armour == initial[0].armour and damaged[0].shield == "9e1" and is_equal_approx(damaged[0].shield_fraction, 0.9), "pure shield loss publishes text and fraction with hp unchanged")
	check(is_same(initial[1], damaged[1]) and is_same(initial[2], damaged[2]) and is_same(body_cache, view._enemy_presentation_geometry) and initial[0].shield == "1e2", "only changed row replaced; old snapshot and geometry retained")
	var events: Dictionary = k.take_results()
	var receipt: bool = false
	for event in events.events:
		if int(event.kind) == 8: receipt = true
	check(receipt, "presentation reads leave damage receipt for sole consumer")
	check(k.advance(0.2), "advance shield recovery wait")
	check(is_same(damaged, view.enemy_presentation()), "recovery wait creates no display invalidation")
	check(k.advance(0.4), "advance pure shield recovery")
	var recovered: Array = view.enemy_presentation()
	check(recovered[0].armour == initial[0].armour and recovered[0].shield == "1e2" and recovered[0].shield_fraction == 1.0 and is_same(body_cache, view._enemy_presentation_geometry), "pure shield recovery updates amount/fraction without geometry rebuild")
	geometry(view, Vector2(10, 20))
	var moved: Array = view.enemy_presentation()
	check(moved[0].id == recovered[0].id and moved[0].origin == recovered[0].origin + Vector2(10, 20) and moved[0].body_bounds.position == recovered[0].body_bounds.position + Vector2(10, 20), "actual shared geometry change invalidates positioning only")
	geometry(view)
	var birth: String = initial[0].id
	k.begin_retreat()
	var retired: Array = view.enemy_presentation()
	check(retired[0].dead and retired[0].id == birth, "retreat changes runtime generation but preserves display birth identity")
	k.finish_retreat()
	geometry(view)
	check(view.enemy_presentation().is_empty(), "cleared encounter exposes no old bindings")
	check(k.start_wave({"enemies": [enemy(1, "100", "100", "0", "100", 100)], "weapons": []}), "install next wave with reused uid")
	geometry(view)
	var rebound: Array = view.enemy_presentation()
	check(rebound[0].id != birth and rebound[0].shield == "0e0" and rebound[0].max_shield == "1e2", "new wave receives new identity; empty shield differs from absent capacity")
	var dead_kernel = ClassDB.instantiate("SpaceCombatKernel")
	check(dead_kernel.initialize(descriptor([enemy(1, "5", "5", "0", "0", 100)], true)), "initialize lethal hit probe")
	var dead_view = EnemyProjectionProbe.new()
	dead_view._kernel = dead_kernel
	geometry(dead_view)
	var alive: Array = dead_view.enemy_presentation()
	check(dead_kernel.advance(0.1), "advance lethal hit")
	var dead: Array = dead_view.enemy_presentation()
	check(dead[0].dead and dead[0].id == alive[0].id and dead[0].armour_fraction == 0.0, "death preserves birth identity and clamps drawing fraction")
	check(k.initialize(descriptor([enemy(1, "25", "100", "0", "0", 100)], false)), "reinitialize owner")
	geometry(view)
	var restored: Array = view.enemy_presentation()
	check(restored[0].id != rebound[0].id and restored[0].armour == "2.5e1" and restored[0].armour_fraction == 0.25, "owner reinstallation rebinds identity and initial cache")
	print("PROBE_FAILURES=", failures)
	quit(1 if failures else 0)
