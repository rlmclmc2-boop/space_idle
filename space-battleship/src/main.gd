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
const PlayerSettings = preload("res://foundation/host/player_settings.gd")
const Session = preload("res://src/game_session.gd")
var session
var startup_error: String = ""
var _overlay: Node2D
var _pause_button: Button
var _guidance_panel: PanelContainer
var _guidance_label: Label
var _guidance_button: Button
var _skip_tutorial: bool = false
var growth_panel: PanelContainer
var growth_status: Label
var save_state_label: Label
var _pending_import: Dictionary = {}
var _pending_reforge: Dictionary = {}
var _pending_new_game: Dictionary = {}
var _autosave_interval: float = 0.0
var _music_enabled: bool = true
var _effects_enabled: bool = true
var _damage_mode: String = "all"
var _preferred_page: String = "battle"
var _music_player: AudioStreamPlayer
var _effects_player: AudioStreamPlayer
var _next_effect_ms: int = 0
var _music_toggle: CheckBox
var _effects_toggle: CheckBox
var _damage_option: OptionButton
var _skip_toggle: CheckBox
var _autosave_spin: SpinBox
var _settings_error: String = ""
var _next_autosave_wall: float = 0.0
var _save_status_elapsed: float = 1.0
var _seen_save_failure_generation: String = ""

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
	var settings: Dictionary = PlayerSettings.load_interval()
	if settings.ok:
		_apply_settings(settings)
	else:
		_settings_error = str(settings.reason)
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
		_next_autosave_wall = session.wall_time + _autosave_interval
		_show_session()
		_sync_guidance()

func _show_session() -> void:
	get_window().content_scale_size = session.battle.view_size()
	if DisplayServer.get_name() != "headless":
		var battle_view = BattleView.new(session.battle)
		battle_view.damage_mode = _damage_mode
		battle_view.damage_received.connect(_play_effect)
		add_child(battle_view)
	add_child(BattleStatisticsView.new(session.battle.statistics()))
	_setup_shell_overlay()
	add_child(CampaignView.new(session.campaign_system))
	add_child(EconomyView.new(session.economy, session.economy_display_context, session.refresh_growth))
	_setup_growth_panel()
	_setup_guidance_panel()
	_setup_audio()

func _apply_settings(settings: Dictionary) -> void:
	_autosave_interval = float(settings.interval)
	_skip_tutorial = bool(settings.auto_skip_tutorial)
	_music_enabled = bool(settings.music_enabled)
	_effects_enabled = bool(settings.effects_enabled)
	_damage_mode = str(settings.damage_mode)
	_preferred_page = str(settings.page)
	_next_autosave_wall = session.wall_time + _autosave_interval if session != null else 0.0
	if _music_player != null: _music_player.stream_paused = not _music_enabled
	if _music_toggle != null: _music_toggle.set_pressed_no_signal(_music_enabled)
	if _effects_toggle != null: _effects_toggle.set_pressed_no_signal(_effects_enabled)
	if _skip_toggle != null: _skip_toggle.set_pressed_no_signal(_skip_tutorial)
	if _autosave_spin != null: _autosave_spin.set_value_no_signal(_autosave_interval)
	if _damage_option != null: _damage_option.select(PlayerSettings.DAMAGE_MODES.find(_damage_mode))
	for child in get_children():
		if child.get_script() == BattleView: child.damage_mode = _damage_mode
	if growth_panel != null: growth_panel.visible = _preferred_page == "growth"

func _setup_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load("res://assets/audio/bgm/deep_space_idle_01.ogg")
	if _music_player.stream is AudioStreamOggVorbis: _music_player.stream.loop = true
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.play()
	_music_player.stream_paused = not _music_enabled
	_effects_player = AudioStreamPlayer.new()
	_effects_player.volume_db = -13.0
	var tone := AudioStreamWAV.new()
	tone.mix_rate = 22050
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	for i in 2205:
		var envelope: float = 1.0 - float(i) / 2205.0
		var amplitude: int = int(sin(float(i) * TAU * 660.0 / 22050.0) * envelope * 4500.0)
		samples.append(amplitude & 255)
		samples.append((amplitude >> 8) & 255)
	tone.data = samples
	_effects_player.stream = tone
	add_child(_effects_player)

func _play_effect() -> void:
	if not _effects_enabled or _effects_player == null: return
	var now: int = Time.get_ticks_msec()
	if now < _next_effect_ms: return
	_next_effect_ms = now + 120
	_effects_player.play()

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
	# Publish a recoverable snapshot of the live session before replacing it.
	# This also captures changes made since the preview was opened.
	var configured: Dictionary = session.configure_save_directory(directory)
	if not configured.ok: return configured
	var backup: Dictionary = session.request_save()
	if not backup.ok: return backup
	var completed: Dictionary = session.save_files.close()
	if not completed.ok: return completed
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
	_pending_new_game = {}
	_seen_save_failure_generation = ""
	_next_autosave_wall = session.wall_time + _autosave_interval
	_overlay = null
	_pause_button = null
	_guidance_panel = null
	_guidance_label = null
	_guidance_button = null
	growth_panel = null
	_music_player = null
	_effects_player = null
	_next_effect_ms = 0
	_music_toggle = null
	_effects_toggle = null
	_damage_option = null
	_skip_toggle = null
	_autosave_spin = null
	_show_session()
	_sync_guidance()
	var persisted: Dictionary = session.request_save()
	return {"ok": true, "persistence_pending": persisted.ok,
		"persistence_failed": not persisted.ok,
		"persistence_error": str(persisted.get("error", persisted.get("reason", "SaveFailed")))}

func _preview_new_game(directory: String, clear_settings: bool) -> Dictionary:
	_pending_new_game = {}
	if not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "reason": "SaveDirectoryRequired"}
	var candidate = Session.new()
	var created: Dictionary = candidate.initialize("res://generated/config.json", Time.get_ticks_usec())
	if not created.ok: return created
	created = candidate.campaign_system.start_sortie(1, candidate.equipment.clear_switch_locks)
	if not created.ok: return created
	created = candidate.configure_save_directory(directory)
	if not created.ok: return created
	_pending_new_game = {"session": candidate, "directory": directory, "clear_settings": clear_settings}
	return {"ok": true, "message": "New game ready. Confirm to replace the current save; settings %s." % ["reset" if clear_settings else "kept"]}

func _confirm_new_game(directory: String, clear_settings: bool) -> Dictionary:
	if _pending_new_game.is_empty() or _pending_new_game.directory != directory or _pending_new_game.clear_settings != clear_settings:
		return {"ok": false, "reason": "NewGamePreviewRequired"}
	var switched: Dictionary = _replace_session(_pending_new_game.session)
	if not switched.ok: return switched
	if clear_settings:
		var cleared: Dictionary = PlayerSettings.reset()
		if not cleared.ok:
			switched.settings_failed = true
			switched.settings_error = str(cleared.reason)
		else:
			_apply_settings(PlayerSettings.defaults())
	return switched

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
		_sync_guidance()
		if _pause_button != null:
			_pause_button.text = "Continue" if session.pause_reasons.has("user") else "Pause"
		if session.save_files != null: session.save_files.poll()
		if session.save_files != null and not session.save_files.last_failure.is_empty():
			var failure_generation: String = str(session.save_files.last_failure.get("generation", ""))
			if failure_generation != _seen_save_failure_generation:
				_seen_save_failure_generation = failure_generation
				if growth_status != null:
					growth_status.text = "保存失败：" + str(session.save_files.last_failure.get("error", "Unknown"))
		_save_status_elapsed += maxf(dt, 0.0)
		if save_state_label != null and growth_panel != null and growth_panel.visible and _save_status_elapsed >= 1.0:
			_save_status_elapsed = 0.0
			if session.save_files == null:
				save_state_label.text = "No save directory"
			elif not session.save_files.last_failure.is_empty():
				save_state_label.text = "Save failed: " + str(session.save_files.last_failure.get("error", "Unknown"))
			elif session.save_files.busy():
				save_state_label.text = "Saving…"
			else:
				var status: Dictionary = session.dirty_since_save()
				save_state_label.text = "Save status unavailable" if not status.ok else "Unsaved changes" if status.dirty else "Last save written"
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
	_overlay.draw.connect(_draw_shell.bind(_overlay))
	_pause_button = Button.new()
	_pause_button.text = "Continue" if session.pause_reasons.has("user") else "Pause"
	_pause_button.position = Vector2(420, 18)
	_pause_button.pressed.connect(func():
		if session.run_state.is_running():
			session.set_pause("user", not session.pause_reasons.has("user"))
			_pause_button.text = "Continue" if session.pause_reasons.has("user") else "Pause")
	layer.add_child(_pause_button)

func _setup_guidance_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_guidance_panel = PanelContainer.new()
	_guidance_panel.position = Vector2(80, 265)
	_guidance_panel.custom_minimum_size = Vector2(410, 110)
	_guidance_panel.visible = false
	layer.add_child(_guidance_panel)
	var box := VBoxContainer.new()
	_guidance_panel.add_child(box)
	_guidance_label = Label.new()
	_guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance_label.custom_minimum_size.x = 390
	box.add_child(_guidance_label)
	_guidance_button = Button.new()
	_guidance_button.text = "继续游戏"
	box.add_child(_guidance_button)
	_guidance_button.pressed.connect(func():
		var pending: Dictionary = session.pending_guidance()
		if not pending.is_empty(): session.dismiss_guidance(str(pending.kind), str(pending.id))
		_sync_guidance())

func _sync_guidance() -> void:
	if _guidance_panel == null: return
	if not session.run_state.is_running():
		_guidance_panel.visible = false
		return
	var pending: Dictionary = session.pending_guidance()
	if pending.is_empty():
		session.set_pause("tutorial", false)
		session.set_pause("unlock", false)
		_guidance_panel.visible = false
		return
	if _skip_tutorial:
		while not pending.is_empty():
			var dismissed: Dictionary = session.dismiss_guidance(str(pending.kind), str(pending.id))
			if not dismissed.ok: break
			pending = session.pending_guidance()
		session.set_pause("tutorial", false)
		session.set_pause("unlock", false)
		_guidance_panel.visible = false
		return
	var kind: String = str(pending.kind)
	session.set_pause("tutorial", kind == "tutorial")
	session.set_pause("unlock", kind == "unlock")
	var captions := {"equip": "首次换装已完成", "upgrade": "首次升级已完成",
		"pickup": "首次拾取已完成", "retreat": "首次撤退已发生",
		"clear": "通关奖励已入账"}
	_guidance_label.text = str(captions.get(str(pending.id), "已解锁：" + str(pending.id)))
	_guidance_panel.visible = true

func _draw_shell(canvas: Node2D) -> void:
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(18, 920), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))
	if not session.run_state.is_running():
		canvas.draw_string(font, Vector2(18, 850), session.run_state.reason(), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))

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
		if result.get("settings_failed", false):
			growth_status.text = "Settings reset failed: " + str(result.get("settings_error", "Unknown"))
			return
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"NoChange": "没有变更", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "会话已切换，保存失败：" + str(result.get("persistence_error", "Unknown")) if result.get("persistence_failed", false) else "保存请求已排队" if result.get("persistence_pending", false) or result.has("generation") else str(result.get("message", "完成")) if result.get("ok", false) else str(result.get("message", labels.get(reason, reason)))
		)
	return button

func _set_page(page: String) -> void:
	var saved: Dictionary = PlayerSettings.save_change("page", page)
	if saved.ok:
		_preferred_page = page
		growth_panel.visible = page == "growth"
	elif growth_status != null:
		growth_status.text = str(saved.reason)

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
	growth_panel.visible = _preferred_page == "growth"
	layer.add_child(growth_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 600)
	growth_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	scroll.add_child(box)
	var back := Button.new()
	back.text = "返回战斗"
	back.pressed.connect(func(): _set_page("battle"))
	box.add_child(back)
	growth_status = Label.new()
	if not _settings_error.is_empty(): growth_status.text = _settings_error
	box.add_child(growth_status)
	save_state_label = Label.new()
	box.add_child(save_state_label)
	_save_status_elapsed = 1.0
	open.pressed.connect(func(): _set_page("battle" if growth_panel.visible else "growth"))
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
	_autosave_spin = autosave
	box.add_child(autosave)
	autosave.value_changed.connect(func(value: float):
		var saved: Dictionary = PlayerSettings.save_interval(int(value))
		if saved.ok:
			_autosave_interval = value
			_next_autosave_wall = session.wall_time + value
		else:
			autosave.set_value_no_signal(_autosave_interval)
			growth_status.text = str(saved.reason))
	var skip_tutorial := CheckBox.new()
	skip_tutorial.text = "自动跳过引导提示"
	skip_tutorial.button_pressed = _skip_tutorial
	_skip_toggle = skip_tutorial
	box.add_child(skip_tutorial)
	skip_tutorial.toggled.connect(func(enabled: bool):
		var saved: Dictionary = PlayerSettings.save_auto_skip_tutorial(enabled)
		if saved.ok:
			_skip_tutorial = enabled
			_sync_guidance()
		else:
			skip_tutorial.set_pressed_no_signal(_skip_tutorial)
			growth_status.text = str(saved.reason))
	var music := CheckBox.new()
	music.text = "Music"
	music.button_pressed = _music_enabled
	_music_toggle = music
	box.add_child(music)
	music.toggled.connect(func(enabled: bool):
		var saved: Dictionary = PlayerSettings.save_change("music_enabled", enabled)
		if saved.ok:
			_music_enabled = enabled
			if _music_player != null: _music_player.stream_paused = not enabled
		else:
			music.set_pressed_no_signal(_music_enabled)
			growth_status.text = str(saved.reason))
	var effects := CheckBox.new()
	effects.text = "Sound effects"
	effects.button_pressed = _effects_enabled
	_effects_toggle = effects
	box.add_child(effects)
	effects.toggled.connect(func(enabled: bool):
		var saved: Dictionary = PlayerSettings.save_change("effects_enabled", enabled)
		if saved.ok: _effects_enabled = enabled
		else:
			effects.set_pressed_no_signal(_effects_enabled)
			growth_status.text = str(saved.reason))
	var damage_mode := OptionButton.new()
	for mode in PlayerSettings.DAMAGE_MODES: damage_mode.add_item("Damage numbers: " + mode)
	damage_mode.select(PlayerSettings.DAMAGE_MODES.find(_damage_mode))
	_damage_option = damage_mode
	box.add_child(damage_mode)
	damage_mode.item_selected.connect(func(index: int):
		var chosen: String = PlayerSettings.DAMAGE_MODES[index]
		var saved: Dictionary = PlayerSettings.save_change("damage_mode", chosen)
		if saved.ok:
			_damage_mode = chosen
			for child in get_children():
				if child.get_script() == BattleView: child.damage_mode = chosen
		else:
			damage_mode.select(PlayerSettings.DAMAGE_MODES.find(_damage_mode))
			growth_status.text = str(saved.reason))
	var clear_settings := CheckBox.new()
	clear_settings.text = "Clear player settings with new game"
	box.add_child(clear_settings)
	_command_button(box, "Preview new game", func() -> Dictionary:
		return _preview_new_game(save_path.text, clear_settings.button_pressed))
	_command_button(box, "Confirm new game", func() -> Dictionary:
		return _confirm_new_game(save_path.text, clear_settings.button_pressed))
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
