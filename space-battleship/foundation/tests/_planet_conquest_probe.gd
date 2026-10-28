extends SceneTree

const Planet = preload("res://src/systems/planet.gd")
const RunState = preload("res://src/systems/run_state.gd")
class UnitApi extends RefCounted:
	func apply(_operation: String, _args: Array) -> Dictionary:
		return {"ok": true, "value": {"unit": 1}}

var checks: int = 0
var failures: int = 0
var events: Array = []
var baseline

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)

func make_planet(rows: Array):
	var planet = Planet.new([{"id": 1,"reforgeStartLevel":1}, {"id": 3,"reforgeStartLevel":1}, {"id": 8,"reforgeStartLevel":1}], [], rows, UnitApi.new(), RunState.new())
	planet.refresh_availability(func(_kind, _id): return true)
	planet.conquest_changed.connect(func(ids, cumulative): events.append({"ids": ids, "cumulative": cumulative}))
	return planet

func changed(planet, ids: Array) -> Dictionary:
	var state: Dictionary = planet.save_state()
	for id in state.planets: state.planets[id].conquered = id in ids
	return state

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	baseline = load(OS.get_environment("SPACE_IDLE_PLANET_BASELINE"))
	check(baseline != null, "original Git source loaded")
	if baseline == null:
		quit(1)
		return
	var rows: Array = []
	for spec in [[1,"level_bonus","equipment","add",2.8], [3,"level_bonus","equipment","mul",1.5],
		[8,"level_bonus","equipment","max",3.0], [3,"level_bonus","enhancement","add",4.8],
		[1,"free_charge","all","add",0.1], [3,"free_charge","all","add",0.2],
		[8,"luck","all","max",5.0], [1,"crew_exp_share","all","add",1.0],
		[1,"planet_unlock","planet","max",8.0]]:
		rows.append({"planet_id":spec[0],"buff_type":spec[1],"target":spec[2],"stack":spec[3],"value":spec[4]})
	var p = make_planet(rows)
	check(not p.conquest_facts("3").ok and not p.conquest_facts("missing").ok, "locked and unknown rejected")
	var zero: Dictionary = p.conquest_facts("1")
	check(zero.ok and not zero.conquered and not zero.shared_experience, "known zero and false")
	for reward in zero.rewards: check(reward.value == 0, "zero source")
	for ids in [["1"], ["1","3"], ["1","3","8"]]:
		check(p.restore_state(changed(p, ids)).ok, "restore accepted")
		p.refresh_availability(func(_kind, _id): return true)
		var before: Dictionary = p.save_state()
		var internal: Array = [p._factors.duplicate(true), p._claim_state.duplicate(true), p._claim_factors.duplicate(true), p._facility_fact_cache.duplicate(true), p._conquest_baseline.duplicate(true), p._conquest_queued]
		var facts: Dictionary = p.conquest_facts("8")
		check(facts.ok and facts.conquered == ("8" in ids) and not facts.shared_experience, "current marker with cumulative other sources")
		var original: Dictionary = baseline._contributions(before.planets, {}, rows, UnitApi.new())
		var current: Dictionary = p.contributions()
		for index in range(4):
			var field: String = ["equipment_levels","enhancement_levels","free_charge","luck"][index]
			check(facts.rewards[index].value == original[field] and current[field] == original[field], "original contribution parity " + field)
			check(typeof(facts.rewards[index].value) == typeof(original[field]), "original type " + field)
		check(facts.rewards[2].unit == "ratio" and facts.rewards[2].display_text.ends_with("%"), "free charge source unit")
		p._factors = internal[0]
		facts.rewards[0].value = -999
		facts.rewards.clear()
		check(p.conquest_facts("1").shared_experience, "per-planet shared experience")
		check(p.save_state() == before and [p._factors, p._claim_state, p._claim_factors, p._facility_fact_cache, p._conquest_baseline, p._conquest_queued] == internal, "read purity and detached rows")
	await process_frame
	check(events.size() == 1 and events[0].ids == PackedStringArray(["1","3","8"]) and events[0].cumulative, "first baseline and one batch")
	events.clear()
	p.restore_state(changed(p, ["1"]))
	p.restore_state(changed(p, ["1","3","8"]))
	await process_frame
	check(events.is_empty(), "A B A emits nothing")
	var same: Dictionary = p.save_state()
	same.planets["1"].exploration = 12
	p.restore_state(same)
	p.set_automatic("1", false)
	p.cancel("1")
	p.advance({}, {}, 1.0, func(): return {"enabled":false})
	check(not p.prepare_reforge("1").ok and not p.accept_reforge("1").ok, "rejected and preview")
	check(not p.restore_state({}).ok, "invalid restore")
	await process_frame
	check(events.is_empty(), "same conquest, ordinary activity and failures silent")
	p.conquest_changed.connect(func(_ids, _cumulative):
		if events.size() == 1: p.restore_state(changed(p, ["1","3"]))
	)
	p.restore_state(changed(p, ["1"]))
	await process_frame
	await process_frame
	check(events.size() == 2 and events[0].ids == PackedStringArray(["3","8"]) and events[1].ids == PackedStringArray(["3"]), "reentrant fresh baseline")
	var accepted_facts: Dictionary = p.conquest_facts("1")
	p._factors = {"sentinel": "stale contribution"}
	p._claim_state = changed(p, ["1","3","8"])
	p._claim_factors = {"sentinel": "pending claim"}
	p._claim_id = "8"
	var caches: Array = [p._factors.duplicate(true), p._claim_state.duplicate(true), p._claim_factors.duplicate(true), p._claim_id]
	check(p.conquest_facts("1") == accepted_facts, "ignores pending claim and stale factors")
	check([p._factors, p._claim_state, p._claim_factors, p._claim_id] == caches, "pending claim caches untouched")
	var mark_only = make_planet([])
	mark_only.restore_state(changed(mark_only, ["1"]))
	var mark_start: int = events.size()
	await process_frame
	check(events.size() == mark_start + 1 and not events[-1].cumulative and events[-1].ids == PackedStringArray(["1"]), "marker dirty independent of cumulative dirty")
	for bad in [NAN, INF, -INF]:
		for spec in [["level_bonus","equipment"], ["free_charge","all"], ["crew_exp_share","all"]]:
			var invalid: Array = rows.duplicate(true)
			invalid.append({"planet_id":1,"buff_type":spec[0],"target":spec[1],"stack":"max","value":bad})
			var q = make_planet(invalid)
			q.restore_state(changed(q, ["1"]))
			check(not q.conquest_facts("1").ok, "nonfinite before int/bool including max")
			q._flush_conquest_change()
	var accepted = make_planet(rows)
	accepted._buildings["yard"] = {"type":"shipyard"}
	accepted._state["1"].buildings["yard"] = {"state":"built","work":0}
	var accepted_before: Dictionary = accepted._conquest_snapshot()
	check(accepted.prepare_reforge("1").ok, "accepted reforge preview")
	check(accepted.accept_reforge("1").ok and accepted._conquest_baseline == accepted_before, "accept captures before real write")
	check(accepted.is_available("8"), "original availability still handles chain unlock")
	var start: int = events.size()
	await process_frame
	check(events.size() == start + 1 and events[-1].ids == PackedStringArray(["1"]), "successful accept emits")
	var old = make_planet(rows)
	old.restore_state(changed(old, ["1"]))
	var current = make_planet(rows)
	var current_events: Array = []
	current.conquest_changed.connect(func(ids, _cumulative): current_events.append(ids))
	await process_frame
	check(current_events.is_empty() and not current.conquest_facts("1").conquered, "old instance queue stays on old owner")
	print("PLANET_CONQUEST checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
