extends SceneTree
# Layout-only full-page fixture. Availability is forced visibly; no progression is claimed.
var _main
var _prefix: String
func _initialize() -> void:
	call_deferred("_run")
func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)
func _capture(name: String) -> bool:
	for frame in 6: await process_frame
	return root.get_texture().get_image().save_png(_prefix + "-" + name + ".png") == OK
func _check_width(node: Node) -> String:
	if node is Control and node.is_visible_in_tree() and not node is Window:
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < -0.5 or rect.end.x > 572.5:
			return "%s x=%s width=%s" % [node.get_path(), rect.position.x, rect.size.x]
	for child in node.get_children():
		var problem: String = _check_width(child)
		if not problem.is_empty(): return problem
	return ""
func _run() -> void:
	_prefix = OS.get_environment("SPACE_IDLE_WINDOW_EVIDENCE")
	if _prefix.is_empty() or DisplayServer.get_name() == "headless":
		_fail("real renderer and output prefix required")
		return
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", _prefix + "-settings.json")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_main.set_process(false)
	if not _main.startup_error.is_empty():
		_fail(_main.startup_error)
		return
	_main._skip_tutorial = true
	_main._sync_guidance()
	var combat_seen: bool = false
	for frame in 240:
		_main._process(0.1)
		if not _main.session.run_state.is_running():
			_fail("production session stopped during normal play")
			return
		if not combat_seen and not _main.session.battle.enemy_intelligence().is_empty():
			combat_seen = true
			await _capture("combat")
		await process_frame
	if not combat_seen or _main.session.game_time < 20.0:
		_fail("normal play did not enter combat and preserve elapsed game time")
		return
	print("NORMAL_GAMEPLAY_COMBAT_OK game_time=", _main.session.game_time)
	_main.session.set_pause("user", true)
	if not await _capture("battle"):
		_fail("battle screenshot failed")
		return
	_main.growth_panel.show()
	for panel in _main._feature_panels.values(): panel.show()
	for page in _main._pages.values(): _main._tabs.set_tab_hidden(page.index, false)
	for key in _main._pages:
		_main._tabs.current_tab = _main._pages[key].index
		if not await _capture(key):
			_fail("page capture failed " + key)
			return
		var problem: String = _check_width(_main.growth_panel)
		if not problem.is_empty():
			_fail("horizontal overflow " + key + " " + problem)
			return
		if key == "hyperspace":
			var panel = _main._feature_panels.hyperspace
			for index in panel._section_tabs.get_tab_count():
				panel._section_tabs.current_tab = index
				await _capture("hyperspace-" + str(index))
				problem = _check_width(_main.growth_panel)
				if not problem.is_empty():
					_fail("hyperspace overflow " + str(index) + " " + problem)
					return
	_main._tabs.current_tab = _main._pages.ship.index
	_main._pages.ship.scroll.scroll_vertical = 100000
	await _capture("attributes")
	_main.session.save_files.close(2000)
	_main.queue_free()
	for frame in 3: await process_frame
	print("STAGE6_BRIDGE_PAGES_WIDTHS_RENDER_OK " + _prefix)
	quit(0)
