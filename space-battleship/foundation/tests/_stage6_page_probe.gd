extends SceneTree

const NotificationsPanel = preload("res://src/ui/notifications_panel.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")
const PlayerSettings = preload("res://foundation/host/player_settings.gd")
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run")

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found: Button = _find_button(child, label)
		if found != null: return found
	return null

func _find_line(node: Node, placeholder: String) -> LineEdit:
	if node is LineEdit and node.placeholder_text == placeholder: return node
	for child in node.get_children():
		var found: LineEdit = _find_line(child, placeholder)
		if found != null: return found
	return null

func _find_autosave(node: Node) -> SpinBox:
	if node is SpinBox and node.suffix.begins_with(" seconds between saves"): return node
	for child in node.get_children():
		var found: SpinBox = _find_autosave(child)
		if found != null: return found
	return null

func _find_guidance_skip(node: Node) -> CheckBox:
	if node is CheckBox and node.text == "自动跳过引导提示": return node
	for child in node.get_children():
		var found: CheckBox = _find_guidance_skip(child)
		if found != null: return found
	return null

func _find_notifications(node: Node):
	if node.get_script() == NotificationsPanel: return node
	for child in node.get_children():
		var found = _find_notifications(child)
		if found != null: return found
	return null

func _find_dialog(node: Node, mode: int) -> FileDialog:
	if node is FileDialog and node.file_mode == mode: return node
	for child in node.get_children():
		var found: FileDialog = _find_dialog(child, mode)
		if found != null: return found
	return null

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", directory.path_join("player-settings.json"))
	var invalid_settings: FileAccess = FileAccess.open(PlayerSettings._path(), FileAccess.WRITE)
	invalid_settings.store_string('{"formatVersion":1,"autosaveInterval":-1}')
	invalid_settings.close()
	if PlayerSettings.load_interval().ok:
		printerr("invalid autosave setting admitted")
		quit(1)
		return
	if not PlayerSettings.save_interval(15).ok:
		printerr("could not prepare separate player settings")
		quit(1)
		return
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	if main.session == null or not main.startup_error.is_empty() or main._autosave_interval != 15.0:
		printerr("main startup: ", main.startup_error, " interval=", main._autosave_interval,
			" settings=", PlayerSettings.load_interval())
		quit(1)
		return
	var autosave_control: SpinBox = _find_autosave(main)
	if autosave_control == null or autosave_control.value != 15.0:
		printerr("saved autosave setting was not shown")
		quit(1)
		return
	var guidance_button: Button = _find_button(main, "继续游戏")
	var guidance_skip: CheckBox = _find_guidance_skip(main)
	if guidance_button == null or guidance_skip == null:
		printerr("guidance controls missing")
		quit(1)
		return
	main._sync_guidance()
	if not main.session.pause_reasons.has("unlock") or not main._guidance_panel.visible:
		printerr("unlock guidance did not hold its pause reason")
		quit(1)
		return
	main.session.set_pause("user", true)
	guidance_button.pressed.emit()
	if not main.session.pause_reasons.has("user"):
		printerr("guidance release cleared user pause")
		quit(1)
		return
	main.session.set_pause("user", false)
	guidance_skip.button_pressed = true
	for index in 10: main._sync_guidance()
	if not PlayerSettings.load_interval().auto_skip_tutorial or main.session.pause_reasons.has("unlock") or main.session.notifications.unread("unlock") == 0:
		printerr("guidance skip did not persist or release")
		quit(1)
		return
	autosave_control.value = 25.0
	if main._autosave_interval != 25.0 or PlayerSettings.load_interval().get("interval") != 25:
		printerr("autosave setting did not persist outside gameplay save")
		quit(1)
		return
	var pause_button: Button = _find_button(main, "Pause")
	if pause_button == null:
		printerr("visible pause control missing")
		quit(1)
		return
	pause_button.pressed.emit()
	if not main.session.pause_reasons.has("user") or pause_button.text != "Continue":
		printerr("pause button did not hold user pause")
		quit(1)
		return
	main.session.set_pause("unlock", true)
	pause_button.pressed.emit()
	if main.session.pause_reasons.has("user") or not main.session.pause_reasons.has("unlock"):
		printerr("continue button cleared another pause reason")
		quit(1)
		return
	main.session.set_pause("unlock", false)
	main.growth_panel.visible = true
	var back_button: Button = _find_button(main, "返回战斗")
	if back_button == null:
		printerr("growth panel return control missing")
		quit(1)
		return
	back_button.pressed.emit()
	if main.growth_panel.visible:
		printerr("return control did not close growth panel")
		quit(1)
		return
	main.growth_panel.visible = true
	var save_path: LineEdit = _find_line(main, "Existing absolute save directory")
	if save_path == null:
		printerr("save path control missing")
		quit(1)
		return
	var save_picker: FileDialog = _find_dialog(main, FileDialog.FILE_MODE_OPEN_DIR)
	if save_picker == null or _find_button(main, "Choose save directory") == null:
		printerr("save directory picker missing")
		quit(1)
		return
	save_picker.dir_selected.emit(directory)
	if save_path.text != directory:
		printerr("save directory picker did not fill path")
		quit(1)
		return
	_find_button(main, "Save").pressed.emit()
	if main.growth_status.text != "保存请求已排队":
		printerr("save button claimed completion before writer: ", main.growth_status.text)
		quit(1)
		return
	var result: Dictionary = main.session.save_files.close(2000)
	if not result.ok or not SaveFiles.read_pointer(directory, "active.json").ok:
		printerr("save button: ", result)
		quit(1)
		return
	main._process(0.0)
	if main.save_state_label.text != "Last save written":
		printerr("save status failed to show committed state: ", main.save_state_label.text)
		quit(1)
		return
	main.session.set_chrono_speed(10)
	main._save_status_elapsed = 1.0
	main._process(0.0)
	if main.save_state_label.text != "Unsaved changes":
		printerr("business change missing from save status: ", main.save_state_label.text)
		quit(1)
		return
	_find_button(main, "Save").pressed.emit()
	result = main.session.save_files.close(2000)
	if not result.ok or not SaveFiles.read_pointer(directory, "previous.json").ok:
		printerr("second save button: ", result)
		quit(1)
		return
	_find_button(main, "Load backup").pressed.emit()
	if main.session.current_chrono_speed() != 1:
		printerr("backup button did not restore prior session")
		quit(1)
		return
	result = main.session.save_files.close(2000)
	if not result.ok:
		printerr("backup replacement save: ", result)
		quit(1)
		return
	await process_frame
	var pointer: Dictionary = SaveFiles.read_pointer(directory, "active.json")
	var import_path: LineEdit = _find_line(main, "Envelope JSON file to import")
	var import_picker: FileDialog = _find_dialog(main, FileDialog.FILE_MODE_OPEN_FILE)
	if import_path == null or import_picker == null or _find_button(main, "Choose import file") == null or not pointer.ok:
		printerr("import controls missing")
		quit(1)
		return
	var broken_path: String = directory.path_join("broken-import.json")
	var broken: FileAccess = FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string("{bad json")
	broken.close()
	var before_rejection = main.session
	import_picker.file_selected.emit(broken_path)
	_find_button(main, "Preview import").pressed.emit()
	if main.session != before_rejection or not main._pending_import.is_empty():
		printerr("bad import changed current session")
		quit(1)
		return
	var wrong_config: Dictionary = pointer.envelope.duplicate(true)
	wrong_config.configHash = "0".repeat(64)
	var wrong_config_path: String = directory.path_join("wrong-config-import.json")
	var wrong_file: FileAccess = FileAccess.open(wrong_config_path, FileAccess.WRITE)
	wrong_file.store_string(JSON.stringify(wrong_config))
	wrong_file.close()
	import_picker.file_selected.emit(wrong_config_path)
	_find_button(main, "Preview import").pressed.emit()
	if main.session != before_rejection or not main._pending_import.is_empty() or main.growth_status.text != "ConfigurationMismatch":
		printerr("wrong config import changed current session: ", main.growth_status.text)
		quit(1)
		return
	import_picker.file_selected.emit(directory.path_join(pointer.pointer.file))
	if import_path.text != directory.path_join(pointer.pointer.file):
		printerr("import picker did not fill path")
		quit(1)
		return
	_find_button(main, "Preview import").pressed.emit()
	if main._pending_import.is_empty():
		printerr("import preview button failed: ", main.growth_status.text)
		quit(1)
		return
	_find_button(main, "Confirm import").pressed.emit()
	if not main._pending_import.is_empty():
		printerr("import confirmation button failed")
		quit(1)
		return
	result = main.session.save_files.close(2000)
	if not result.ok:
		printerr("import replacement save: ", result)
		quit(1)
		return
	await process_frame
	main.session.notifications.record("research", "page-probe")
	var panel = _find_notifications(main)
	if panel == null:
		printerr("notifications panel missing")
		quit(1)
		return
	var unread: int = main.session.notifications.unread()
	panel._open.pressed.emit()
	if main.session.notifications.unread() != unread:
		printerr("opening archive cleared unread")
		quit(1)
		return
	var notice = panel._archive.get_child(panel._archive.get_child_count() - 1)
	notice.get_child(2).pressed.emit()
	if main.session.notifications.unread() != unread - 1:
		printerr("read button did not clear one unread")
		quit(1)
		return
	result = main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(), 5)
	main.session.planet_system.refresh_availability(main.session.campaign_system.available, false)
	main.session.crew_system.refresh_availability(main.session.campaign_system.available, false)
	var crew_ids: Array = main.session.crew_system.save_state().members.keys()
	if not result.ok or crew_ids.size() < 2:
		printerr("reforge page fixture unavailable")
		quit(1)
		return
	var explorer: String = str(crew_ids[0])
	var builder: String = str(crew_ids[1])
	var building_assigned: bool = false
	for cycle in 220:
		var planet: Dictionary = main.session.planet_system.save_state().planets["1"]
		if planet.buildings.shipyard.state == "ready": break
		if planet.buildings.shipyard.state == "building" and not building_assigned:
			result = main.session.coordinate_assignment(builder, "planet_build", "1:shipyard")
			if not result.ok: break
			building_assigned = true
		result = main.session.coordinate_assignment(explorer, "planet_explore", "1")
		if not result.ok: break
		var builders: Dictionary = {"1:shipyard": [builder]} if building_assigned else {}
		if not main.session._advance_planets(1000000.0, {"1": [explorer]}, builders):
			result = main.session.run_state.rejection()
			break
	if not result.ok or main.session.planet_system.save_state().planets["1"].buildings.shipyard.state != "ready":
		printerr("reforge page shipyard work failed: ", result)
		quit(1)
		return
	result = main.session.planet_system.claim_build("1", "shipyard", main.session.publish_planet_claim)
	if not result.ok:
		printerr("reforge page shipyard claim failed: ", result)
		quit(1)
		return
	var planet_id: LineEdit = _find_line(main, "Planet ID for reforge")
	if planet_id == null:
		printerr("reforge page controls missing")
		quit(1)
		return
	planet_id.text = "1"
	_find_button(main, "Preview reforge").pressed.emit()
	if main._pending_reforge.is_empty() or not main.session.pause_reasons.has("reforge"):
		printerr("reforge preview button failed: ", main.growth_status.text)
		quit(1)
		return
	_find_button(main, "Cancel reforge").pressed.emit()
	if not main._pending_reforge.is_empty() or main.session.pause_reasons.has("reforge"):
		printerr("reforge cancel button failed")
		quit(1)
		return
	_find_button(main, "Preview reforge").pressed.emit()
	_find_button(main, "Confirm reforge").pressed.emit()
	if not main._pending_reforge.is_empty() or main.session.hyperspace_system.warehouse().reforge_count != 1 or not main.session.planet_system.save_state().planets["1"].conquered:
		printerr("reforge confirm button failed: ", main.growth_status.text)
		quit(1)
		return
	result = main.session.save_files.close(2000)
	if not result.ok:
		printerr("reforge replacement save: ", result)
		quit(1)
		return
	# Fail an actual background publication after a candidate has replaced the
	# visible session. The last committed file stays readable and the page must
	# make the failed persistence explicit until a successful retry.
	var committed: Dictionary = SaveFiles.read_pointer(directory, "active.json")
	var old_session = main.session
	import_path = _find_line(main, "Envelope JSON file to import")
	import_path.text = directory.path_join(committed.pointer.file)
	_find_button(main, "Preview import").pressed.emit()
	if main._pending_import.is_empty():
		printerr("replacement failure fixture preview: ", main.growth_status.text)
		quit(1)
		return
	var blocked_temp: String = directory.path_join("previous.json.tmp")
	DirAccess.make_dir_absolute(blocked_temp)
	_find_button(main, "Confirm import").pressed.emit()
	if main.session == old_session or not main.session.run_state.is_running():
		printerr("replacement did not yield a usable candidate")
		quit(1)
		return
	result = main.session.save_files.close(2000)
	main._save_status_elapsed = 1.0
	main.growth_panel.visible = true
	main._process(0.0)
	if result.ok or not main.save_state_label.text.begins_with("Save failed:") or not main.growth_status.text.begins_with("保存失败：") or not SaveFiles.read_pointer(directory, "active.json").ok:
		printerr("asynchronous replacement failure was hidden: ", result, " ", main.save_state_label.text, " ", main.growth_status.text)
		quit(1)
		return
	DirAccess.remove_absolute(blocked_temp)
	_find_button(main, "Save").pressed.emit()
	result = main.session.save_files.close(2000)
	main._save_status_elapsed = 1.0
	main._process(0.0)
	if not result.ok or not main.session.save_files.last_failure.is_empty() or main.save_state_label.text != "Last save written":
		printerr("failed replacement save retry: ", result, " ", main.save_state_label.text)
		quit(1)
		return
	var gameplay = main.session
	var weapon_slot: String = ""
	for slot in gameplay.equipment.save_state().slots:
		if slot.category == "weapon" and not str(slot.equipment_id).is_empty():
			weapon_slot = str(slot.id)
			break
	if weapon_slot.is_empty():
		printerr("no equipped weapon for tutorial probe")
		quit(1)
		return
	var rejected_equip: Dictionary = gameplay.equipment.equip_slot(weapon_slot, "laser", gameplay.equipment_inputs(), gameplay.publish_equipment_refit)
	if rejected_equip.ok or gameplay.tutorial.completed("equip"):
		printerr("rejected equipment action advanced tutorial: ", rejected_equip)
		quit(1)
		return
	var equipped: Dictionary = gameplay.equipment.equip_slot(weapon_slot, "", gameplay.equipment_inputs(), gameplay.publish_equipment_refit)
	if not equipped.ok or not gameplay.tutorial.completed("equip"):
		printerr("accepted equipment action missing from tutorial: ", equipped)
		quit(1)
		return
	var quoted: Dictionary = gameplay.equipment.quote_slot(weapon_slot, 1)
	if not quoted.ok:
		printerr("tutorial upgrade quote failed: ", quoted)
		quit(1)
		return
	var funded: Dictionary = gameplay.economy.budget().duplicate()
	for resource in quoted.costs: funded[resource] = gameplay.amount_api.apply("from_decimal", ["1e40"]).value
	gameplay.economy.accept_budget(funded)
	var upgraded: Dictionary = gameplay.equipment.buy_levels(weapon_slot, 1, gameplay.equipment_inputs(),
		func(costs, balances): return gameplay.economy.payment(costs, balances), gameplay.publish_equipment_levels)
	if not upgraded.ok or not gameplay.tutorial.completed("upgrade"):
		printerr("paid upgrade missing from tutorial: ", upgraded)
		quit(1)
		return
	if gameplay.tutorial.completed("pickup"):
		printerr("pickup tutorial advanced without income")
		quit(1)
		return
	var timed: Dictionary = gameplay.economy.advance_timed(30.0, true,
		func(): return gameplay.amount_api.apply("from_decimal", ["1"]),
		Vector2(280, 10), 800.0, gameplay.wall_time, gameplay.game_time, gameplay._income_factors)
	if not timed.ok:
		printerr("timed pickup fixture failed: ", timed)
		quit(1)
		return
	for marker in gameplay.economy.drop_markers():
		var collected: Dictionary = gameplay.economy.collect_at(Vector2(float(marker.x), float(marker.y)),
			gameplay.wall_time, gameplay.game_time, gameplay._income_factors)
		if not collected.ok:
			printerr("manual pickup failed: ", collected)
			quit(1)
			return
		break
	if not gameplay.tutorial.completed("pickup"):
		printerr("credited pickup missing from tutorial")
		quit(1)
		return
	main._skip_tutorial = false
	main._sync_guidance()
	if not gameplay.pause_reasons.has("tutorial") or not main._guidance_panel.visible:
		printerr("completed tutorial event did not hold pause")
		quit(1)
		return
	gameplay.set_pause("user", true)
	guidance_button = _find_button(main, "继续游戏")
	guidance_button.pressed.emit()
	if not gameplay.pause_reasons.has("user"):
		printerr("tutorial dismissal cleared user pause")
		quit(1)
		return
	gameplay.set_pause("user", false)
	main._skip_tutorial = true
	main._sync_guidance()
	result = gameplay.request_save()
	if result.ok: result = gameplay.save_files.close(2000)
	var tutorial_loaded: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not result.ok or not tutorial_loaded.ok or not tutorial_loaded.session.tutorial.completed("equip") or not tutorial_loaded.session.tutorial.completed("upgrade") or not tutorial_loaded.session.tutorial.completed("pickup"):
		printerr("tutorial progress did not persist: ", result, " ", tutorial_loaded)
		quit(1)
		return
	tutorial_loaded.session.save_files.close(2000)
	print("STAGE6_PAGE_PROBE_OK")
	quit(0)
