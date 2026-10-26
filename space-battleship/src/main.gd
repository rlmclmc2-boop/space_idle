extends Node2D
const BattleView = preload("res://src/ui/battle_view.gd")
const BattleStatisticsView = preload("res://src/ui/battle_statistics_view.gd")
const FleetPanel = preload("res://src/ui/fleet_panel.gd")
const CampaignView = preload("res://src/ui/campaign_view.gd")
const CrewPanel = preload("res://src/ui/crew_panel.gd")
const GalaxyPanel = preload("res://src/ui/galaxy_panel.gd")
const PlanetPanel = preload("res://src/ui/planet_panel.gd")
const HyperspacePanel = preload("res://src/ui/hyperspace_panel.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const EquipmentPanel = preload("res://src/ui/equipment_panel.gd")
const ReactorPanel = preload("res://src/ui/reactor_panel.gd")
const EnhancementPanel = preload("res://src/ui/enhancement_panel.gd")
const ResearchPanel = preload("res://src/ui/research_panel.gd")
const NotificationsPanel = preload("res://src/ui/notifications_panel.gd")
const Session = preload("res://src/game_session.gd")
var session
var startup_error: String = ""
var _overlay: Node2D
var growth_panel: PanelContainer
var growth_status: Label
var save_state_label: Label
var _pending_import: Dictionary = {}
var _pending_reforge: Dictionary = {}
var _autosave_interval: float = 0.0
var _next_autosave_wall: float = 0.0

func _ready() -> void:
	if not ClassDB.class_exists("SpaceCombatKernel"):
		var extension: String = OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION")
		if extension.is_empty():
			startup_error = "请先编译原生模块，再通过 run_game.ps1 启动。"
			return
		var loaded = GDExtensionManager.load_extension(extension)
		if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			startup_error = "原生模块加载失败：" + extension
			return
	session = Session.new()
	var result = session.initialize("res://generated/config.json", Time.get_ticks_usec())
	if not result.ok:
		startup_error = str(result.reason)
		return
	get_window().content_scale_size = session.battle.view_size()
	result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		startup_error = str(result.reason)
	else:
		_show_session()

func _show_session() -> void:
	get_window().content_scale_size = session.battle.view_size()
	if DisplayServer.get_name() != "headless": add_child(BattleView.new(session.battle))
	add_child(BattleStatisticsView.new(session.battle.statistics()))
	_setup_shell_overlay()
	add_child(CampaignView.new(session.campaign_system))
	add_child(EconomyView.new(session.economy, session.economy_display_context, session.refresh_growth))
	_setup_growth_panel()

func _load_saved(directory: String, backup: bool = false) -> Dictionary:
	var loaded: Dictionary = Session.load_candidate("res://generated/config.json", directory, backup)
	if not loaded.ok: return loaded
	return _replace_session(loaded.session)

func _preview_import(directory: String, source_file: String) -> Dictionary:
	_pending_import = {}
	if not DirAccess.dir_exists_absolute(directory): return {"ok": false, "reason": "SaveDirectoryRequired"}
	var preview: Dictionary = Session.import_candidate("res://generated/config.json", directory, source_file)
	if not preview.ok: return preview
	_pending_import = {"directory": directory, "source": source_file, "session": preview.session}
	return {"ok": true, "message": "关卡 %s，舰船 %s，代次 %s；确认后导入" % [
		preview.summary.stage, preview.summary.ship, preview.summary.generation]}

func _apply_import(directory: String, source_file: String) -> Dictionary:
	if _pending_import.is_empty() or _pending_import.directory != directory or _pending_import.source != source_file:
		return {"ok": false, "reason": "ImportPreviewRequired"}
	var replacement = _pending_import.session
	_pending_import = {}
	return _replace_session(replacement)

func _replace_session(replacement) -> Dictionary:
	if session.save_files != null:
		var closed: Dictionary = session.save_files.close()
		if not closed.ok: return closed
	for child in get_children(): child.queue_free()
	session = replacement
	_pending_import = {}
	_pending_reforge = {}
	_next_autosave_wall = session.wall_time + _autosave_interval
	_overlay = null
	growth_panel = null
	_show_session()
	var persisted: Dictionary = session.request_save()
	return {"ok": true, "persistence_pending": persisted.ok,
		"persistence_failed": not persisted.ok,
		"persistence_error": str(persisted.get("error", persisted.get("reason", "SaveFailed")))}

func _preview_reforge(directory: String, planet_id: String, ids_text: String) -> Dictionary:
	_pending_reforge = {}
	var ids: Array = []
	for id in ids_text.split(",", false):
		ids.append(id.strip_edges())
	var preview: Dictionary = session.prepare_reforge(planet_id, ids, directory)
	if not preview.ok: return preview
	_pending_reforge = {"session": preview.session, "directory": directory,
		"planet": planet_id, "ids": ids_text}
	session.set_pause("reforge", true)
	return {"ok": true, "message": preview.summary.message}

func _confirm_reforge(directory: String, planet_id: String, ids_text: String) -> Dictionary:
	if _pending_reforge.is_empty() or _pending_reforge.directory != directory or _pending_reforge.planet != planet_id or _pending_reforge.ids != ids_text:
		return {"ok": false, "reason": "ReforgePreviewRequired"}
	return _replace_session(_pending_reforge.session)

func _cancel_reforge() -> Dictionary:
	_pending_reforge = {}
	session.set_pause("reforge", false)
	return {"ok": true}

func _process(dt: float) -> void:
	if session != null and startup_error.is_empty():
		session.frame(dt, DisplayServer.window_is_focused())
		if session.save_files != null: session.save_files.poll()
		if save_state_label != null:
			if session.save_files == null:
				save_state_label.text = "No save directory"
			elif session.save_files.busy():
				save_state_label.text = "Saving…"
			elif not session.save_files.last_result.is_empty() and not session.save_files.last_result.ok:
				save_state_label.text = "Save failed: " + str(session.save_files.last_result.get("error", "Unknown"))
			elif session.save_files.dirty(str(session._change_number)):
				save_state_label.text = "Snapshot not written"
			else:
				save_state_label.text = "Last save written"
		if _autosave_interval > 0.0 and session.save_files != null and session.wall_time >= _next_autosave_wall:
			_next_autosave_wall = session.wall_time + _autosave_interval
			var saved: Dictionary = session.request_save()
			if not saved.ok and growth_status != null: growth_status.text = str(saved.get("error", saved.get("reason", "SaveFailed")))
	if _overlay != null: _overlay.queue_redraw()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty() or not session.run_state.is_running():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("071423"))
	var font: Font = ThemeDB.fallback_font
	if not startup_error.is_empty():
		draw_string(font, Vector2(18, 45), startup_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))
		return

func _setup_shell_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_overlay = Node2D.new()
	layer.add_child(_overlay)
	_overlay.draw.connect(_draw_shell)

func _draw_shell() -> void:
	var font: Font = ThemeDB.fallback_font
	_overlay.draw_string(font, Vector2(18, 920), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))
	if not session.run_state.is_running():
		_overlay.draw_string(font, Vector2(18, 850), session.run_state.reason(), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))

func _command_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(func():
		if not session.run_state.is_running():
			growth_status.text = session.run_state.reason()
			return
		if not _pending_reforge.is_empty() and text not in ["Confirm reforge", "Cancel reforge"]:
			growth_status.text = "请先确认或取消重铸"
			return
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"NoChange": "没有变更", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "会话已切换，保存失败：" + str(result.get("persistence_error", "Unknown")) if result.get("persistence_failed", false) else "保存请求已排队" if result.get("persistence_pending", false) or result.has("generation") else str(result.get("message", "完成")) if result.get("ok", false) else str(result.get("message", labels.get(reason, reason)))
		)
	return button

func _setup_growth_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var open := Button.new()
	open.text = "成长与配装"
	open.position = Vector2(18, 80)
	layer.add_child(open)
	growth_panel = PanelContainer.new()
	growth_panel.position = Vector2(12, 122)
	growth_panel.size = Vector2(410, 615)
	growth_panel.visible = false
	layer.add_child(growth_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 600)
	growth_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	scroll.add_child(box)
	growth_status = Label.new()
	box.add_child(growth_status)
	save_state_label = Label.new()
	box.add_child(save_state_label)
	open.pressed.connect(func(): growth_panel.visible = not growth_panel.visible)
	box.add_child(EquipmentPanel.new(session.equipment, session.equipment_inputs, session.economy.affordable,
		session.economy.payment, session.publish_equipment_levels, session.publish_equipment_refit, _command_button))
	box.add_child(FleetPanel.new(session.campaign_system, session.commit_ship_refit, _command_button))
	var reactor_panel = ReactorPanel.new(session.reactor_system, session.reactor_inputs, session.economy.payment, session.publish_reactor, _command_button)
	box.add_child(reactor_panel)
	var research_panel = ResearchPanel.new(session.research, _command_button)
	box.add_child(research_panel)
	box.add_child(EnhancementPanel.new(session.enhancement, session.enhancement_inputs,
		session.economy.affordable, session.publish_enhancement, _command_button))
	box.add_child(CrewPanel.new(session.crew_system, session.planet_system, session.galaxy_system, session.coordinate_assignment, _command_button))
	box.add_child(GalaxyPanel.new(session.galaxy_system))
	box.add_child(PlanetPanel.new(session.planet_system, session.coordinate_planet_cancel, session.publish_planet_claim, _command_button))
	box.add_child(HyperspacePanel.new(session, _command_button))
	box.add_child(NotificationsPanel.new(session.notifications))
	var save_path := LineEdit.new()
	save_path.placeholder_text = "Existing absolute save directory"
	if session.save_files != null: save_path.text = session.save_files._directory
	box.add_child(save_path)
	var save_picker := FileDialog.new()
	save_picker.access = FileDialog.ACCESS_FILESYSTEM
	save_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_picker.dir_selected.connect(func(path: String): save_path.text = path)
	box.add_child(save_picker)
	_command_button(box, "Choose save directory", func() -> Dictionary:
		save_picker.popup_centered_ratio()
		return {"ok": true, "message": "Choose an existing save directory"})
	var speed_options := OptionButton.new()
	for option in session.chrono_speed_options():
		speed_options.add_item("%sx · %s chrono/s" % [option.speed, option.cost], int(option.speed))
		if int(option.speed) == session.current_chrono_speed(): speed_options.select(speed_options.item_count - 1)
	speed_options.item_selected.connect(func(index: int):
		session.set_chrono_speed(speed_options.get_item_id(index)))
	box.add_child(speed_options)
	_command_button(box, "Save", func() -> Dictionary:
		var configured: Dictionary = session.configure_save_directory(save_path.text)
		return session.request_save() if configured.ok else configured)
	var autosave := SpinBox.new()
	autosave.min_value = 0.0
	autosave.max_value = 86400.0
	autosave.step = 1.0
	autosave.suffix = " seconds between saves (0 = off)"
	autosave.value = _autosave_interval
	box.add_child(autosave)
	autosave.value_changed.connect(func(value: float):
		_autosave_interval = value
		_next_autosave_wall = session.wall_time + value)
	_command_button(box, "Load primary", func() -> Dictionary:
		return _load_saved(save_path.text))
	_command_button(box, "Load backup", func() -> Dictionary:
		return _load_saved(save_path.text, true))
	var import_path := LineEdit.new()
	import_path.placeholder_text = "Envelope JSON file to import"
	box.add_child(import_path)
	var import_picker := FileDialog.new()
	import_picker.access = FileDialog.ACCESS_FILESYSTEM
	import_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_picker.add_filter("*.json", "JSON save envelope")
	import_picker.file_selected.connect(func(path: String): import_path.text = path)
	box.add_child(import_picker)
	_command_button(box, "Choose import file", func() -> Dictionary:
		import_picker.popup_centered_ratio()
		return {"ok": true, "message": "Choose an Envelope JSON file"})
	_command_button(box, "Preview import", func() -> Dictionary:
		return _preview_import(save_path.text, import_path.text))
	_command_button(box, "Confirm import", func() -> Dictionary:
		return _apply_import(save_path.text, import_path.text))
	var planet_id := LineEdit.new()
	planet_id.placeholder_text = "Planet ID for reforge"
	box.add_child(planet_id)
	var retained_ids := LineEdit.new()
	retained_ids.placeholder_text = "Drone IDs to retain, comma separated"
	box.add_child(retained_ids)
	_command_button(box, "Preview reforge", func() -> Dictionary:
		return _preview_reforge(save_path.text, planet_id.text, retained_ids.text))
	_command_button(box, "Confirm reforge", func() -> Dictionary:
		return _confirm_reforge(save_path.text, planet_id.text, retained_ids.text))
	_command_button(box, "Cancel reforge", _cancel_reforge)
