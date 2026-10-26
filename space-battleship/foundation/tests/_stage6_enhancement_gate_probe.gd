extends SceneTree
## C09: every authored effect and node across all three order positions.
const Session = preload("res://src/game_session.gd")
const EFFECTS := ["proficiency", "repeat", "critical", "adaptation", "memory", "deferred"]

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr(message)
	quit(1)

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 37)
	if not ready.ok:
		_fail("C09 init: " + str(ready))
		return
	var rules: Dictionary = session.enhancement._rules
	var checks: int = 0
	for effect in EFFECTS:
		var group: String = "weapon" if effect in ["proficiency", "repeat", "critical"] else "defence"
		for position in 3:
			for node in 3:
				var order: Array = ["proficiency", "repeat", "critical"] if group == "weapon" else ["adaptation", "memory", "deferred"]
				order.erase(effect)
				order.insert(position, effect)
				var gate: int = int(rules["branch_threshold_" + str(node + 1)]) + int(rules["branch_position_offset_" + str(position + 1)])
				for choice in ["A", "B"]:
					for level in [gate - 1, gate]:
						var state: Dictionary = session.enhancement.save_state()
						state.level = level
						state[group + "_order"] = order
						var choices: Array = ["", "", ""]
						choices[node] = choice
						state.branches = {effect: choices}
						ready = session.enhancement.restore_state(state)
						if not ready.ok:
							_fail("C09 restore " + effect + ": " + str(ready))
							return
						var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
						if not output.ok:
							_fail("C09 evaluation " + effect + ": " + str(output))
							return
						var flags: Dictionary = output.effects[effect]
						var active: bool = level == gate
						var selected_b: bool = active and choice == "B" and not (effect == "repeat" and node == 1)
						if bool(flags["b" + str(node + 1)]) != selected_b:
							_fail("C09 branch gate " + effect + " position=" + str(position) + " node=" + str(node) + " level=" + str(level) + " choice=" + choice)
							return
						var baseline: Dictionary = state.duplicate(true)
						baseline.branches = {}
						ready = session.enhancement.restore_state(baseline)
						if not ready.ok:
							_fail("C09 baseline restore")
							return
						var reference: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
						if not reference.ok:
							_fail("C09 baseline evaluation")
							return
						if not active and (output.weapon != reference.weapon or output.defence != reference.defence or output.globals != reference.globals):
							_fail("C09 early branch changed values: " + effect)
							return
						checks += 1
	print("STAGE6_ENHANCEMENT_GATE_OK C09 checks=", checks, " six effects, three nodes, three positions, A/B and gate boundaries")
	quit()
