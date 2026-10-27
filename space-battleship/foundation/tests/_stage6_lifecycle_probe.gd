extends SceneTree
const Session = preload("res://src/game_session.gd")
const Main = preload("res://src/main.tscn")
const BattleView = preload("res://src/ui/battle_view.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		quit(1)
		return
	call_deferred("_run")

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _retired_session(seed_value: int) -> WeakRef:
	var session = Session.new()
	var initialized: Dictionary = session.initialize("res://generated/config.json", seed_value)
	if not initialized.ok:
		_fail("standalone initialization " + str(initialized))
		return weakref(session)
	# The ownership fix must retain all original tutorial callbacks.
	session.equipment.loadout_changed.emit()
	session.equipment.slots_changed.emit([])
	session.economy.drop_collected.emit()
	session.campaign_system.retreat_started.emit()
	for event in ["equip", "upgrade", "pickup", "retreat"]:
		if not session.tutorial.completed(event): _fail("tutorial callback lost " + event)
	return weakref(session)

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		_fail("disposable lifecycle directory required")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", directory.path_join("settings.json"))
	var retired: Array = []
	for index in 6:
		retired.append(_retired_session(101 + index))
		await process_frame
		for reference in retired:
			if reference.get_ref() != null:
				_fail("retired standalone Session retained by owned signal lambda")
				return
	print("LIFECYCLE_STANDALONE_SESSIONS_RELEASED count=6")
	# Exercise retained presentation's real ownership with a headless CanvasItem.
	# No window or alternative combat implementation is created.
	var presented = Session.new()
	if not presented.initialize("res://generated/config.json", 202).ok:
		_fail("presentation session initialization")
		return
	var presented_ref: WeakRef = weakref(presented)
	var view = BattleView.new(presented.battle)
	# Initialize the same native retained ownership without MultiMesh drawing:
	# DummyRenderer cannot introspect instance shader parameters headlessly.
	var retained := ShaderMaterial.new()
	retained.shader = preload("res://shaders/retained_flights.gdshader")
	var contacts := ShaderMaterial.new()
	contacts.shader = preload("res://shaders/gpu_contacts.gdshader")
	var contact_canvas := Node2D.new()
	var topology = preload("res://scripts/gpu_contact_mesh.gd")
	presented.battle.configure_presentation(retained, [topology.build(0), topology.build(1)],
		contact_canvas.get_canvas_item(), contacts, view.get_canvas_item(), view._collect_beams)
	presented = null
	for frame in 3: await process_frame
	if presented_ref.get_ref() != null:
		_fail("view retained Session instead of its Battle owner")
		return
	var battle_ref: WeakRef = weakref(view._battle)
	view._exit_tree()
	view.free()
	view = null
	contact_canvas.free()
	for frame in 3: await process_frame
	if battle_ref.get_ref() != null:
		_fail("presentation or view retained retired Battle")
		return
	print("LIFECYCLE_BATTLE_VIEW_PRESENTATION_RELEASED")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_process(false)
	if not main.startup_error.is_empty():
		_fail(main.startup_error)
		return
	var store: String = main.session.save_files._directory
	main._skip_tutorial = true
	main._sync_guidance()
	var resource_counts: Array = []
	var owner_object_counts: Array = []
	var node_counts: Array = []
	for index in 8:
		retired.append(weakref(main.session))
		var changed: Dictionary
		if index % 2 == 0:
			if not main._preview_new_game(store, false).ok:
				_fail("new-game preview")
				return
			var abandoned: WeakRef = weakref(main._pending_new_game.session)
			if not main._preview_new_game(store, false).ok or abandoned.get_ref() != null:
				_fail("abandoned preview candidate retained")
				return
			changed = main._confirm_new_game(store, false)
		else:
			changed = main._load_saved(store)
		if not changed.ok:
			_fail("replace session failed " + str(changed))
			return
		for frame in 4: await process_frame
		for reference in retired:
			if reference.get_ref() != null:
				_fail("retired Session retained after load/new-game replacement")
				return
		resource_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
		# Each retained WeakRef is itself one ObjectDB object, not a session leak.
		owner_object_counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - retired.size())
		node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		print("LIFECYCLE_REPLACEMENT index=", index, " resources=", resource_counts.back(), " owner_objects=", owner_object_counts.back(), " nodes=", node_counts.back())
	for index in range(2, resource_counts.size()):
		if resource_counts[index] > resource_counts[1] or owner_object_counts[index] > owner_object_counts[1] or node_counts[index] > node_counts[1]:
			_fail("resources accumulated across replacements " + str(resource_counts))
			return
	if not main.session.save_files.close(2000).ok:
		_fail("final save writer did not close")
		return
	print("STAGE6_LIFECYCLE_RELEASE_REPLACE_AND_NORMAL_CLOSE_OK resources=", resource_counts)
	# The actual production close path saves then ends the tree; a clean process
	# log confirms teardown without relying on a catch-all disposal framework.
	main._close_game()
