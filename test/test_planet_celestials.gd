extends SceneTree
## Configuration-driven acceptance for added bodies, existing saves and rendering.
var failures := 0
var checks := 0
const IDS := ["2", "3", "4", "5", "6"]

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func click_control(viewport: SubViewport, control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func grant_crew(g) -> Array:
	if not g.profile.has("grantedUnlocks"):g.profile.grantedUnlocks = []
	for gate in g.db.data.unlock.values():
		if gate.type == "crew" or (gate.type == "feature" and gate.target == "crew_level"):
			if not g.profile.get("grantedUnlocks", []).has(gate.name):g.profile.grantedUnlocks.append(gate.name)
	var ids: Array = []
	for member in g.profile.crew:
		if g.idle_planet_crew(str(member.crewId)):ids.append(str(member.crewId))
	return ids

func run() -> void:
	var db := ShipDatabase.new()
	var before := db.data.duplicate(true)
	var g := BattleGame.new(db, false)
	var members := grant_crew(g)
	check(members.size() >= IDS.size(), "Five independent crew available in fixture")
	if members.size() < IDS.size():quit(1);return
	for id in IDS:
		var gate: Dictionary = db.data.unlock[g.planet_row(id).unlockId]
		check(not g.planet_unlocked(id), id + " initially locked")
		check(not g.start_planet_exploration(id, members[0]), id + " locked dispatch rejected")
		g.profile.cleared.append(int(gate.level))
		g.profile.highestLevel = maxi(g.profile.highestLevel, int(gate.level) + 1)
		check(g.planet_unlocked(id), id + " unlock uses configured gate")
		check(is_equal_approx(g.planet_duration(id), float(g.planet_row(id).baseTime)), id + " existing duration retained")
		check(g.start_planet_exploration(id, members[0]), id + " dispatch")
		var duration := g.planet_duration(id)
		g.advance_planets(duration - 0.25)
		check(g.planet_progress(id).degree == 0, id + " progress does not finish early")
		g.paused = true
		g.tick(1.0)
		check(is_equal_approx(g.planet_progress(id).elapsed, duration - 0.25), id + " paused logic")
		g.paused = false
		var reward := [-1.0]
		var handler := func(kind, payload):
			if kind == "planet_changed" and payload.get("id") == id and payload.has("reward"):reward[0] = float(payload.reward)
		g.event.connect(handler)
		g.advance_planets(0.25)
		g.event.disconnect(handler)
		check(g.planet_progress(id).degree == 1 and g.planet_progress(id).crewId == "", id + " completion releases crew")
		check(is_equal_approx(reward[0], g.planet_exp_reward(id)), id + " configured XP effect")
		check(g.planet_buildings.rows(g, id).size() == db.data.planet_build.size(), id + " inherits all applicable buildings")
	# Different values and simultaneous workers must survive the actual save path.
	for i in IDS.size():
		var id: String = IDS[i]
		g.profile.planets[id].degree = i + 2
		check(g.start_planet_exploration(id, members[i]), id + " independent simultaneous dispatch")
		g.profile.planets[id].elapsed = float(i + 1)
		check(not g.start_planet_exploration("1", members[i]), "Occupied crew cannot be reused")
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(db, false)
	restored.load_progress()
	for i in IDS.size():
		var p: Dictionary = restored.planet_progress(IDS[i])
		check(p.degree == i + 2 and p.crewId == members[i] and is_equal_approx(p.elapsed, float(i + 1)), IDS[i] + " independent save/load and no offline progress")
	# Old saves get missing body/building fields from existing load normalization.
	var legacy := BattleGame.new(db, false)
	legacy.load_planets({"1":{"degree":7}})
	check(legacy.planet_progress("1").degree == 7, "Old first-body progress preserved")
	for id in IDS:
		var p: Dictionary = legacy.planet_progress(id)
		check(p.degree == 0 and p.crewId == "" and p.elapsed == 0 and not p.conquered, id + " old-save defaults")
		check(not is_same(p.buildings, legacy.planet_progress("1").buildings), id + " independent mutable state")
	# Existing building effects apply and persist per body without new reward rows.
	for id in IDS:
		restored.cancel_planet_exploration(id)
		var refinery: Dictionary = db.data.planet_build.refinery
		restored.profile.planets[id].degree = refinery.unlock_explore
		restored.planet_buildings.sync(restored, id)
		for trip in int(refinery.build_explore):
			if restored.planet_progress(id).crewId.is_empty():
				check(restored.start_planet_exploration(id, members[0]), id + " building dispatch")
			else:check(restored.planet_progress(id).crewId == members[0], id + " automatic building dispatch retains its crew")
			restored.advance_planets(restored.planet_duration(id))
		check(restored.planet_buildings.built(restored, id, "refinery"), id + " building completes")
		restored.cancel_planet_exploration(id)
	check(GrowthNumber.compare(restored.planet_resource_multiplier(), 1) > 0, "Existing completed-building effects apply")
	restored.save_enabled = true
	restored.save_progress()
	var finished := BattleGame.new(db, false)
	finished.load_progress()
	check(GrowthNumber.compare(finished.planet_resource_multiplier(), restored.planet_resource_multiplier()) == 0, "Completed effects survive reload")
	check(db.data == before, "Runtime never overwrites source configuration")
	await verify_ui()
	print("CELESTIALS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048, 1280)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = []
	scene.game.profile.grantedUnlocks = []
	scene.game.load_planets({})
	grant_crew(scene.game)
	for row in scene.game.db.data.unlock.values():
		if row.type == "planet":scene.game.profile.cleared.append(int(row.level))
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	scene.planet_panel.refresh()
	check(scene.planet_panel.cards.size() == scene.game.db.data.planet.size(), "All configured bodies displayed")
	await process_frame
	await process_frame
	var nodes := get_node_count()
	var visual_nodes := {}
	for id in IDS:visual_nodes[id] = scene.planet_panel.cards[id].visual.find_children("*", "", true, false).size()
	var sample_times: Array[float] = []
	for id in IDS:
		await click_control(viewport, scene.planet_panel.cards[id].list_button)
		var card: Dictionary = scene.planet_panel.cards[id]
		check(card.stage.visible and scene.planet_panel.selected_planet_id == id, id + " list selection")
		check(card.stage_title.text == scene.game.planet_row(id).name, id + " configured display name preserved")
		await click_control(viewport, card.start)
		check(not scene.game.planet_progress(id).crewId.is_empty(), id + " UI dispatch")
		var visual = card.visual
		check(visual.globe.surface_map != visual.PlanetSphere.SURFACE, id + " generated map resolved")
		var start: Vector2 = visual.globe.phases
		var animation_nodes := get_node_count()
		for frame in 36:
			var t := Time.get_ticks_usec()
			visual.advance(1.0 / 60.0, false)
			sample_times.append(float(Time.get_ticks_usec() - t))
			await process_frame
		check(visual.globe.phases != start and is_zero_approx(visual.globe.rotation), id + " spherical UV motion")
		check(get_node_count() == animation_nodes, id + " animation allocates no nodes")
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://.runtime/celestial-%s.png" % id)
		var frozen: Vector2 = visual.globe.phases
		var clock: float = visual.globe.visual_clock
		var writes: int = visual.globe.parameter_writes
		scene.equipment_tabs.current_tab = 5
		visual.advance(2.0, false)
		visual.globe.advance(2.0, false)
		check(visual.globe.phases == frozen and visual.globe.visual_clock == clock and visual.globe.parameter_writes == writes, id + " hidden animation has zero writes")
		scene.equipment_tabs.current_tab = 6
		visual.advance(2.0, true)
		check(visual.globe.phases == frozen and visual.globe.visual_clock == clock, id + " paused VFX")
		scene.game.cancel_planet_exploration(id)
	for id in IDS:
		check(scene.planet_panel.cards[id].visual.find_children("*", "", true, false).size() == visual_nodes[id], id + " visual subtree preserved through selection")
	# Missing optional maps safely inherit the existing sphere defaults.
	var fallback = load("res://scripts/planet_visual.gd").new()
	viewport.add_child(fallback)
	fallback.configure("future_body", {"visual":{"surfaceTexture":"res://missing.png", "emission":1.0}})
	check(fallback.globe.surface_map == fallback.PlanetSphere.SURFACE, "Missing map uses safe fallback")
	check(fallback.globe.globe_material.get_shader_parameter("beam_length") == 0.0, "Missing VFX uses neutral defaults")
	fallback.configure("future_body", {"visual":"", "visualFacilities":""})
	check(fallback.appearance.is_empty() and fallback.facilities.is_empty(), "Empty optional workbook cells inherit defaults")
	fallback.configure("future_body", {"visual":"invalid json"})
	check(fallback.appearance.is_empty(), "Malformed optional appearance safely falls back")
	check(UIText.data_text("planet", "future_body", "name", "Future body") == "Future body", "Future configured name requires no catalog duplication")
	sample_times.sort()
	print("Celestial visual CPU: median %.1f us, p95 %.1f us; nodes %d" % [sample_times[sample_times.size()/2], sample_times[int(sample_times.size()*0.95)], nodes])
	viewport.queue_free()
