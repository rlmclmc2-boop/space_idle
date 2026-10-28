extends SceneTree
const Session = preload("res://src/game_session.gd")
const RunState = preload("res://src/systems/run_state.gd")
var failures: Array = []
var notices := {"crew": 0, "planet": 0}
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func reason(result: Dictionary, expected: String, label: String) -> void:
	check(not result.ok and result.get("reason") == expected, label + ": " + str(result))
func share(value) -> String:
	return "SPACE-FILTER-v2:" + Marshalls.utf8_to_base64(JSON.stringify(value))
func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired: ", status); quit(1); return
	call_deferred("run")
func run() -> void:
	var host = Session.new()
	var initialized: Dictionary = host.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"), 314159)
	check(initialized.ok, "real Session initialization")
	if not initialized.ok: quit(1); return
	var h = host.hyperspace_system
	var crew = host.crew_system
	var planet = host.planet_system
	crew.members_changed.connect(func(_ids): notices.crew += 1)
	planet.status_changed.connect(func(_ids): notices.planet += 1)
	# Explicit task fixture; no production workbook, save or gameplay progression is changed.
	var saved: Dictionary = h.save_state()
	saved.history["alpha"] = {"cleared": 3, "best": {1: 8.4, 2: 12.0, 3: 20.0}}
	saved.history["gamma"] = {"cleared": 1, "best": {1: 8.4}}
	var restored: Dictionary = h.restore_state(saved)
	if not restored.ok:
		printerr("Route fixture restore: ", restored); quit(1); return
	var before_h: Dictionary = h.save_state()
	var before_crew: Dictionary = crew.save_state()
	var rows: Array = h.routes()
	for row in rows:
		if row.route == "alpha": check(row.cleared == 3 and row.best_time == 20.0, "best belongs to highest cleared layer")
		elif row.route == "gamma": check(row.best_time == 8.4, "manual record below idle minimum retained")
		else: check(row.best_time == null, "missing record is unknown")
	rows[0].best_time = 999.0
	check(h.save_state() == before_h, "routes detached and pure")
	reason(host.hyperspace_idle_preview("missing", false), "HyperspaceLocked", "single unlock before route")
	reason(host.start_hyperspace_single("missing"), "HyperspaceLocked", "single command same guard")
	reason(host.hyperspace_idle_preview("missing", true, "missing"), "HyperspaceLocked", "auto unlock before crew")
	h._auto.enabled = true
	reason(host.hyperspace_idle_preview("missing", true, "missing"), "AutoRunning", "auto running before unlock")
	reason(host.start_hyperspace_auto("missing", "missing"), "AutoRunning", "auto command same guard")
	reason(host.hyperspace_idle_preview("missing", false), "HyperspaceLocked", "single unlock still precedes prepare auto guard")
	h._auto.enabled = false
	host.campaign_system._cycle_reached = 8
	crew.refresh_availability(func(_kind, _id): return true, false)
	var id: String = str(crew._members.keys()[0])
	crew._members[id].level = 3
	host._planet_factors = host._planet_factors.duplicate()
	host._planet_factors.luck = 7.0
	reason(host.hyperspace_idle_preview("missing", true, "missing"), "CrewLocked", "auto crew before route")
	reason(host.start_hyperspace_auto("missing", "missing"), "CrewLocked", "auto command crew before route")
	crew._members[id].kind = "system_job"; crew._members[id].target = "equipment_upgrade"
	reason(host.hyperspace_idle_preview("missing", true, id), "CrewOccupied", "occupied crew before route")
	crew._members[id].kind = ""; crew._members[id].target = ""
	reason(host.hyperspace_idle_preview("missing", false), "UnknownRoute", "single original prepare reason")
	reason(host.hyperspace_idle_preview("beta", false), "NoBestTime", "no invented best time")
	before_h = h.save_state(); before_crew = crew.save_state()
	var count_before: Dictionary = notices.duplicate()
	var single: Dictionary = host.hyperspace_idle_preview("gamma", false, "ignored")
	check(single.ok and single.duration == 10.0 and single.crew == null, "single minimum and no crew snapshot")
	var automatic: Dictionary = host.hyperspace_idle_preview("alpha", true, id)
	if not automatic.ok:
		printerr("Fixture diagnostic: ", automatic, " prior failures: ", failures); quit(1); return
	check(automatic.ok and is_equal_approx(automatic.duration, 400.0 / 23.0) and automatic.level == 3, "auto original full game duration")
	check(automatic.crew == {"id": id, "level": 3, "luck": 10.0}, "crew snapshot comes from Session owners")
	check(not automatic.has("receipt") and not automatic.has("run_id") and not automatic.has("luck_state"), "no receipt or RNG leak")
	automatic.crew.level = 999
	host.hyperspace_idle_preview("alpha", true, id)
	check(h.save_state() == before_h and crew.save_state() == before_crew and notices == count_before, "repeated preview changes no task receipt sequence RNG reservation or notice")
	# A successful preview is not a reservation: confirmation reads current crew and history.
	crew._members[id].kind = "system_job"; crew._members[id].target = "equipment_upgrade"
	reason(host.start_hyperspace_auto("alpha", id), "CrewOccupied", "confirmation rejects newly occupied crew")
	check(h.save_state() == before_h, "rejected start keeps full task owner")
	crew._members[id].kind = ""; crew._members[id].target = ""; crew._members[id].level = 10
	h._history.alpha.best[3] = 40.0
	host._planet_factors.luck = 9.0
	var started: Dictionary = host.start_hyperspace_auto("alpha", id)
	check(started.ok and is_equal_approx(started.receipt.duration, 800.0 / 30.0) and started.receipt.crew_level == 10 and started.receipt.luck == 19.0, "confirmation uses latest level best and luck")
	check(crew._members[id].kind == "hyperspace" and notices.crew == count_before.crew + 1, "only start reserves and publishes once")
	reason(host.hyperspace_idle_preview("missing", true, "missing"), "AutoRunning", "active auto precedes crew and route")
	reason(host.hyperspace_idle_preview("alpha", false), "AutoRunning", "single prepare original auto guard")
	check(host.stop_hyperspace_auto().ok, "real stop releases automatic fixture")
	check(h.restore_state(before_h).ok, "restore clean task owner")
	var pending: Dictionary = host.start_hyperspace_single("alpha")
	check(pending.ok and pending.receipt.crew_id == "", "real single start has no reservation")
	reason(host.hyperspace_idle_preview("alpha", false), "OnlineChallengePending", "pending task refusal")
	reason(host.hyperspace_idle_preview("alpha", true, id), "OnlineChallengePending", "auto prepare pending after crew")
	check(h.restore_state(before_h).ok, "restore before filter cases")
	var config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	var baseline_script = load(OS.get_environment("SPACE_IDLE_READONLY_BASELINE"))
	check(baseline_script != null, "fixed prechange Hyperspace baseline loaded")
	if baseline_script == null: quit(1); return
	var old = baseline_script.new(config, host.amount_api, RunState.new(), 314159)
	var catalog: Dictionary = h.player_catalog()
	var valid := {"version": 2, "enabled": true, "mode": "all", "action": "keep_matches", "conditions": [
		{"field": "weapon", "value": catalog.weapons[0]}, {"field": "quality", "value": "blue"},
		{"field": "minimum_level", "value": 3}, {"field": "affix", "key": catalog.affixes[0], "tier": 2},
		{"field": "legendary_effect", "value": catalog.legends[0]}]}
	var cases: Array = ["", "SPACE-FILTER-v1:abcd", "SPACE-FILTER-v2:", "SPACE-FILTER-v2:***=", "SPACE-FILTER-v2:abc", "SPACE-FILTER-v2:e31=", share(null), share([]), share({}), share(valid)]
	var alternate: Dictionary = valid.duplicate(true); alternate.mode = "any"; alternate.action = "clear_matches"; cases.append(share(alternate))
	var disabled: Dictionary = valid.duplicate(true); disabled.enabled = false; disabled.conditions = []; cases.append(share(disabled))
	for field in ["version", "enabled", "mode", "action", "conditions"]:
		var invalid: Dictionary = valid.duplicate(true); invalid.erase(field); cases.append(share(invalid))
	for change in [{"version": 3}, {"enabled": 1}, {"mode": "ALL"}, {"action": "destroy"}, {"conditions": []}, {"conditions": "bad"}, {"extra": true}]:
		var invalid: Dictionary = valid.duplicate(true); invalid.merge(change, true); cases.append(share(invalid))
	for condition in [null, {}, {"field": "unknown"}, {"field": "weapon", "value": "bad"}, {"field": "quality", "value": "bad"}, {"field": "minimum_level", "value": -1}, {"field": "minimum_level", "value": 1.5}, {"field": "minimum_level", "value": true}, {"field": "affix", "key": "bad", "tier": 1}, {"field": "affix", "key": catalog.affixes[0], "tier": 0}, {"field": "legendary_effect", "value": "bad"}, {"field": "weapon", "value": "laser", "extra": true}]:
		var invalid: Dictionary = valid.duplicate(true); invalid.conditions = [condition]; cases.append(share(invalid))
	var too_many: Dictionary = valid.duplicate(true); too_many.conditions.append({"field": "minimum_level", "value": 1}); cases.append(share(too_many))
	cases.append("SPACE-FILTER-v2:" + "A".repeat(int(h._parameters.maximum_filter_string_length)))
	var normalized: Dictionary = valid.duplicate(true); normalized.version = 2.0; normalized.conditions[2].value = 3.0; normalized.conditions[3].tier = 2.0; cases.append(share(normalized))
	var filter_before: Dictionary = h.save_state()
	for index in cases.size():
		var text: String = cases[index]
		var preview: Dictionary = h.preview_filter_import(text)
		check(h.save_state() == filter_before, "filter preview whole-owner purity " + str(index))
		var expected: Dictionary = old.import_filter(text)
		check(preview.ok == expected.ok and preview.get("reason") == expected.get("reason"), "baseline parser/error equivalence " + str(index))
		if preview.ok:
			check(preview.candidate == old.filter_configuration(), "canonical candidate baseline " + str(index))
			check(preview.candidate.version is int, "version integer normalization")
			preview.candidate.conditions.append({"field": "minimum_level", "value": 999})
			check(h.save_state() == filter_before, "deep candidate detached " + str(index))
		var imported: Dictionary = h.import_filter(text)
		check(imported == expected and h.filter_configuration() == old.filter_configuration(), "confirm original-string equivalence " + str(index))
		filter_before = h.save_state()
	check(h.preview_filter_import(share(valid)).ok, "valid preconfirmation filter preview")
	var unchanged: Dictionary = h.filter_configuration()
	reason(h.import_filter(share({})), "InvalidFilter", "confirmation rechecks edited schema")
	check(h.filter_configuration() == unchanged, "invalid confirmation preserves current rule")
	reason(h.preview_filter_import("bad"), "InvalidFilterShare", "share error distinct")
	var set_before: Dictionary = h.filter_configuration()
	var setter_invalid: Dictionary = valid.duplicate(true); setter_invalid.version = 2.0
	reason(h.set_filter(setter_invalid), "InvalidFilter", "direct setter keeps original strict int admission")
	check(h.filter_configuration() == set_before, "invalid direct setter preserves rule")
	planet.refresh_availability(func(_kind, _id): return true, false)
	check(planet.visual_snapshot("missing").is_empty() and planet.visual_snapshot("6").is_empty(), "unknown/locked Planet unchanged")
	var p: Dictionary = planet._state["1"]
	check(planet.visual_snapshot("1").automatic == false, "actual default automatic setting")
	reason(planet.set_automatic("1", true), "PlanetStationRequired", "enable still requires built station")
	check(notices.planet == 0 and not planet.visual_snapshot("1").automatic, "failed enable no notice or setting mutation")
	p.buildings.station.state = "built"; p.running = true; p.elapsed = 5.0; p.duration = 60.0
	check(planet.set_automatic("1", true).ok and notices.planet == 1 and planet.visual_snapshot("1").automatic, "enable reflects accepted fact and one notice")
	check(planet.set_automatic("1", true).ok and notices.planet == 1, "unchanged setter has no extra notice")
	var planet_before: Dictionary = planet.save_state()
	var visual: Dictionary = planet.visual_snapshot("1"); visual.automatic = false; visual.row.name = "changed"
	check(planet.save_state() == planet_before and notices.planet == 1, "Planet snapshot detached and pure")
	check(planet.set_automatic("1", false).ok and notices.planet == 2, "disable existing notification")
	visual = planet.visual_snapshot("1")
	check(not visual.automatic and visual.running and visual.elapsed == 5.0 and visual.duration == 60.0, "disable continuation does not cancel current exploration")
	host.run_state.fail("FixtureStopped")
	reason(host.hyperspace_idle_preview("missing", false), "SessionUnavailable", "single RunState first")
	reason(host.hyperspace_idle_preview("missing", true, "missing"), "SessionUnavailable", "auto RunState first")
	check(host.run_state.reason() == "FixtureStopped", "query does not replace failure")
	if failures.is_empty(): print("PASS: route best/latest idle preview purity and unchanged admission order; actual start revalidation/reservation; ", cases.size(), " baseline filter parse/error/normalization/confirm cases; detached candidates; Planet automatic and existing notices without cancellation")
	else: printerr("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)
