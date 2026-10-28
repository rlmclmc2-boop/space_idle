extends SceneTree
const Session = preload("res://src/game_session.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	var result = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if result not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired ", result)
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var original = load(OS.get_environment("SPACE_IDLE_PLANET_BASELINE"))
	var host = Session.new()
	check(host.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"), 271828).ok, "real Session/native initialized")
	if failures:
		quit(1)
		return
	var owner = host.planet_system
	var source: Dictionary = owner.save_state()
	var ids: Array = source.planets.keys()
	for count in range(ids.size() + 1):
		var state: Dictionary = source.duplicate(true)
		for index in range(ids.size()): state.planets[ids[index]].conquered = index < count
		check(owner.restore_state(state).ok, "production restore")
		# Explicit gate fixture isolates source projection; original availability remains authoritative.
		owner.refresh_availability(func(_kind, _id): return true, false)
		var old: Dictionary = original._contributions(state.planets, owner._buildings, owner._buffs, host.amount_api)
		check(old.ok, "original production contribution")
		check(host.publish_world(owner.contributions(), {}, {}, false).ok, "real Session/native accepts unchanged source")
		for id in ids:
			if not owner.is_available(id):
				check(not owner.conquest_facts(id).ok, "actual locked projection")
				continue
			var before: Dictionary = owner.save_state()
			var cached: Dictionary = owner._factors.duplicate(true)
			var facts: Dictionary = owner.conquest_facts(id)
			check(facts.ok and facts.conquered == state.planets[id].conquered, "production current marker")
			check(facts.shared_experience == (original._buff(state.planets, owner._buffs, "crew_exp_share", "all", id) > 0.0), "production shared source")
			for index in range(4):
				var field: String = ["equipment_levels", "enhancement_levels", "free_charge", "luck"][index]
				check(facts.rewards[index].value == old[field] and host._planet_factors[field] == old[field], "production original and Session field " + field)
			check(owner.save_state() == before and owner._factors == cached, "production reads pure")
	await process_frame
	print("PLANET_CONQUEST_SESSION checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
