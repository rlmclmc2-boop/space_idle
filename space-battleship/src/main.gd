extends Node2D
const PlayerText = preload("res://src/ui/player_text.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")
const BattleView = preload("res://src/ui/battle_view.gd")
const FleetPanel = preload("res://src/ui/fleet_panel.gd")
const CampaignView = preload("res://src/ui/campaign_view.gd")
const CrewPanel = preload("res://src/ui/crew_panel.gd")
const GalaxyPanel = preload("res://src/ui/galaxy_panel.gd")
const PlanetPanel = preload("res://src/ui/planet_panel.gd")
const HyperspacePanel = preload("res://src/ui/hyperspace_panel.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const EquipmentPanel = preload("res://src/ui/equipment_panel.gd")
const ReactorScene = preload("res://src/ui/reactor_scene.gd")
const EnhancementPanel = preload("res://src/ui/enhancement_panel.gd")
const ResearchPanel = preload("res://src/ui/research_panel.gd")
const NotificationsPanel = preload("res://src/ui/notifications_panel.gd")
const PlayerSettings = preload("res://foundation/host/player_settings.gd")
const Session = preload("res://src/game_session.gd")
var session
var startup_error: String = ""
var _player_text
var _startup_save_error: String = ""
var _startup_directory: String = ""
var _feature_panels: Dictionary = {}
var _pages: Dictionary = {}
var _tabs: TabContainer
var equipment_scene: Control
var reactor_scene: Control
var _left_module: String = "equipment"
var _left_buttons: Dictionary = {}
var _left_modules: Dictionary = {}
var _battle_viewport: SubViewport
var _reforge_picker: OptionButton
var _reforge_drones: ItemList
var _reforge_planet_value: LineEdit
var _reforge_drone_value: LineEdit
var _visibility_pending: bool = true
var _save_warning: Label
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
var _autosave_interval: float = 60.0
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
	var readable_font := FontVariation.new()
	readable_font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	readable_font.variation_opentype = {"wght": 450}
	readable_font.variation_embolden = 0.8
	ThemeDB.fallback_font = readable_font
	ThemeDB.get_default_theme().default_font = ThemeDB.fallback_font
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
		_settings_error = PlayerText.error(str(settings.reason))
	session = Session.new()
	var result = session.initialize("res://generated/config.json", Time.get_ticks_usec())
	if not result.ok:
		startup_error = str(result.reason)
		return
	get_window().content_scale_size = Vector2i(1440, 900)
	result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		startup_error = str(result.reason)
		return
	_startup_directory = PlayerSettings.save_directory(settings if settings.ok else PlayerSettings.defaults())
	if DirAccess.make_dir_recursive_absolute(_startup_directory) != OK:
		_startup_save_error = "无法创建存档目录，请在成长页选择可写目录后保存。"
		session.set_pause("recovery", true)
	elif _has_save_files(_startup_directory):
		var loaded: Dictionary = Session.load_candidate("res://generated/config.json", _startup_directory)
		if loaded.ok:
			session = loaded.session
		else:
			_startup_save_error = "主存档读取失败，已暂停。请在成长页加载备份、导入有效存档或明确确认新游戏。原文件未覆盖。"
			session.set_pause("recovery", true)
	else:
		if _startup_save_error.is_empty():
			result = session.configure_save_directory(_startup_directory)
			if result.ok: result = session.request_save()
			if not result.ok:
				_startup_save_error = "初始存档未能写入，请检查成长页保存状态。"
				session.set_pause("recovery", true)
	_next_autosave_wall = session.wall_time + _autosave_interval
	_show_session()
	_sync_guidance()
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close_game)

func _save_before_exit() -> Dictionary:
	if session == null or session.save_files == null: return {"ok": true}
	var saved: Dictionary = session.request_save()
	return session.save_files.close(2000) if saved.ok else saved

func _close_game() -> void:
	var saved: Dictionary = _save_before_exit()
	if not saved.ok:
		_startup_save_error = "退出保存失败，游戏仍在运行。请检查目录、重试保存后退出。"
		session.set_pause("recovery", true)
		return
	_stop_audio()
	get_tree().quit()

func _has_save_files(directory: String) -> bool:
	for file in ["active.json", "previous.json", "slot-0.json", "slot-1.json"]:
		if FileAccess.file_exists(directory.path_join(file)): return true
	return false

func _configure_save(directory: String) -> Dictionary:
	if session.pause_reasons.has("recovery") and session.save_files == null and _has_save_files(directory):
		return {"ok": false, "message": "请先恢复存档或确认新游戏，以免覆盖待恢复文件。"}
	var configured: Dictionary = session.configure_save_directory(directory)
	if not configured.ok: return configured
	var saved: Dictionary = PlayerSettings.save_change("save_directory", directory)
	if not saved.ok: return saved
	_startup_save_error = ""
	_startup_directory = directory
	session.set_pause("recovery", false)
	return configured

func _show_session() -> void:
	_player_text = PlayerText.new(JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json")))
	_feature_panels.clear()
	_visibility_pending = true
	session.campaign_system.progress_changed.connect(_queue_feature_visibility)
	get_window().content_scale_size = Vector2i(1440, 900)
	# Preserve the battle's authored logical coordinates inside the fixed right surface.
	# The viewport container transforms input together with its existing presentation.
	var battle_surface := SubViewportContainer.new()
	var logical_size := Vector2(session.battle.view_size())
	var surface_size := Vector2(632, 900)
	var projection_scale: float = minf(surface_size.x / logical_size.x, surface_size.y / logical_size.y)
	battle_surface.position = Vector2(808, 0) + (surface_size - logical_size * projection_scale) * 0.5
	battle_surface.size = logical_size
	battle_surface.scale = Vector2.ONE * projection_scale
	add_child(battle_surface)
	_battle_viewport = SubViewport.new()
	_battle_viewport.size = session.battle.view_size()
	_battle_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	battle_surface.add_child(_battle_viewport)
	if DisplayServer.get_name() != "headless":
		_battle_viewport.add_child(load("res://src/ui/battle_scenery.gd").new(session))
		var battle_view = BattleView.new(session.battle)
		battle_view.damage_mode = _damage_mode
		battle_view.damage_received.connect(_play_effect)
		_battle_viewport.add_child(battle_view)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 8
	_battle_viewport.add_child(hud_layer)
	hud_layer.add_child(load("res://src/ui/battle_hud.gd").new(session.battle, session.economy))
	_setup_shell_overlay()
	_battle_viewport.add_child(CampaignView.new(session.campaign_system))
	_battle_viewport.add_child(EconomyView.new(session.economy, session.economy_display_context, session.refresh_growth))
	var equipment_layer := CanvasLayer.new()
	equipment_layer.layer = 9
	add_child(equipment_layer)
	equipment_scene = EquipmentPanel.new(session)
	equipment_layer.add_child(equipment_scene)
	_setup_reactor_scene(equipment_layer)
	_setup_growth_panel()
	_refresh_feature_visibility()
	_setup_guidance_panel()
	_setup_audio()

func _setup_reactor_scene(layer: CanvasLayer) -> void:
	reactor_scene = ReactorScene.new(session.reactor_system, session.reactor_inputs, session.economy.payment, session.publish_reactor)
	layer.add_child(reactor_scene)
	reactor_scene.bind_presentation(_reactor_scene_presentation, func():
		return {"game_time": session.game_time, "paused": not session.pause_reasons.is_empty() or not session.run_state.is_running(),
			"running": session.run_state.is_running()})
	reactor_scene.bind_purchase_quote(_reactor_scene_quote)
	reactor_scene.command_finished.connect(func(result: Dictionary):
		if growth_status != null:
			growth_status.text = str(result.get("message", "完成")) if result.get("ok", false) else PlayerText.error(str(result.get("reason", "Unknown"))))
	if session.reactor_system.has_signal("presentation_changed"):
		session.reactor_system.connect("presentation_changed", reactor_scene.invalidate_presentation)
	if session.economy.has_signal("budget_changed"):
		session.economy.connect("budget_changed", reactor_scene.invalidate_budget)
	_left_modules.clear()
	_left_buttons.clear()
	_register_left_module(layer, "equipment", "装备", equipment_scene)
	_register_left_module(layer, "reactor", "反应炉", reactor_scene, "feature", "reactor")
	_refresh_left_module()

## Add a full-size left Control and its one navigation entry. The optional
## campaign grant is a kind/target pair; scene data binding stays local.
func _register_left_module(layer: CanvasLayer, id: String, title: String, scene: Control, unlock_kind: String = "", unlock_target: String = "") -> void:
	if id in _left_modules: return
	_left_modules[id] = {"scene": scene, "unlock_kind": unlock_kind, "unlock_target": unlock_target}
	var button := Button.new()
	button.text = title
	button.position = Vector2(442 + 96 * _left_buttons.size(), 52)
	button.size = Vector2(88, 30)
	button.theme = load("res://src/ui/bridge_theme.gd").create()
	button.toggle_mode = true
	button.pressed.connect(_select_left_module.bind(id))
	layer.add_child(button)
	_left_buttons[id] = button
	_refresh_left_module()

func _reactor_scene_presentation() -> Dictionary:
	# The fixed interface owner supplies the read-only outlet; never substitute
	# private Reactor caches or frontend Amount calculations for a missing port.
	if not session.reactor_system.has_method("presentation_model"):
		return {"ok": false, "reason": "ReactorSnapshotUnavailable", "message": "供能状态暂不可用"}
	return session.reactor_system.presentation_model()

func _reactor_scene_quote() -> Dictionary:
	if not session.reactor_system.has_method("purchase_preview"):
		return {"ok": false, "reason": "ReactorQuoteUnavailable"}
	return session.reactor_system.purchase_preview(session.economy.can_pay)

func _select_left_module(module: String) -> void:
	_left_module = module
	if growth_panel != null: growth_panel.hide()
	_refresh_left_module()

func _refresh_left_module() -> void:
	if session == null or _left_modules.is_empty(): return
	var active_available: bool = _left_module in _left_modules and _left_module_available(_left_module)
	if not active_available: _left_module = "equipment"
	for id in _left_modules:
		var available: bool = _left_module_available(id)
		_left_modules[id].scene.visible = available and _left_module == id
		_left_buttons[id].visible = available
		_left_buttons[id].set_pressed_no_signal(_left_module == id)

func _left_module_available(id: String) -> bool:
	var kind: String = str(_left_modules[id].unlock_kind)
	return kind.is_empty() or session.campaign_system.available(kind, str(_left_modules[id].unlock_target))

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
	for child in (_battle_viewport.get_children() if _battle_viewport != null else get_children()):
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

func _stop_audio() -> void:
	# Release this interface's active playback before replacement or shutdown.
	for player in [_music_player, _effects_player]:
		if player != null:
			player.stop()
			player.stream = null

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
	_stop_audio()
	for child in get_children(): child.queue_free()
	session = replacement
	_startup_save_error = ""
	_startup_directory = session.save_files._directory if session.save_files != null else _startup_directory
	var directory_setting: Dictionary = PlayerSettings.save_change("save_directory", _startup_directory)
	if not directory_setting.ok: _settings_error = "存档目录偏好保存失败，下次启动请手动选择此目录。"
	_pending_import = {}
	_pending_reforge = {}
	_pending_new_game = {}
	_seen_save_failure_generation = ""
	_next_autosave_wall = session.wall_time + _autosave_interval
	_feature_panels.clear()
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
	var stored: Dictionary = SaveFiles.read_store(directory)
	var target: String = directory
	if not stored.ok and stored.error == "InvalidSaveStore":
		# Do not unlock or overwrite an invalid store. A separately named new
		# store keeps every original pointer/slot available for later recovery.
		target = directory.path_join("new-game-" + candidate._session_id.sha256_text().substr(0, 16))
	_pending_new_game = {"session": candidate, "directory": directory, "target_directory": target, "clear_settings": clear_settings}
	var recovery: String = "原目录中的损坏文件将原样保留，新存档将保存到 %s。" % target if target != directory else "确认后替换当前存档。"
	return {"ok": true, "message": "新游戏已准备好。%s个人设置将%s。" % [recovery, "重置" if clear_settings else "保留"]}

func _confirm_new_game(directory: String, clear_settings: bool) -> Dictionary:
	if _pending_new_game.is_empty() or _pending_new_game.directory != directory or _pending_new_game.clear_settings != clear_settings:
		return {"ok": false, "reason": "NewGamePreviewRequired"}
	# Finish the old writer before any new candidate can publish in its store.
	if session.save_files != null:
		var closed: Dictionary = session.save_files.close(2000)
		if not closed.ok: return closed
	var candidate = _pending_new_game.session
	var target: String = _pending_new_game.target_directory
	if DirAccess.make_dir_recursive_absolute(target) != OK: return {"ok": false, "reason": "SaveDirectoryRequired"}
	var prepared: Dictionary = candidate.configure_save_directory(target)
	if prepared.ok: prepared = candidate.request_save()
	if not prepared.ok: return prepared
	prepared = candidate.save_files.close(2000)
	if not prepared.ok: return prepared
	var verified: Dictionary = SaveFiles.read_pointer(target, "active.json")
	if not verified.ok or verified.envelope.sessionId != candidate._session_id:
		return {"ok": false, "reason": "NewGameSaveVerificationFailed"}
	# Only a candidate already durably published may replace the live game.
	var switched: Dictionary = _replace_session(candidate)
	if not switched.ok: return switched
	if clear_settings:
		var cleared: Dictionary = PlayerSettings.reset()
		if not cleared.ok:
			switched.settings_failed = true
			switched.settings_error = str(cleared.reason)
		else:
			var directory_saved: Dictionary = PlayerSettings.save_change("save_directory", _startup_directory)
			if not directory_saved.ok:
				switched.settings_failed = true
				switched.settings_error = str(directory_saved.reason)
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
		if _visibility_pending: _refresh_feature_visibility()
		_refresh_save_warning()
		if _pause_button != null:
			_pause_button.text = "继续" if session.pause_reasons.has("user") else "暂停"
		if session.save_files != null: session.save_files.poll()
		if session.save_files != null and not session.save_files.last_failure.is_empty():
			var failure_generation: String = str(session.save_files.last_failure.get("generation", ""))
			if failure_generation != _seen_save_failure_generation:
				_seen_save_failure_generation = failure_generation
				if growth_status != null:
					growth_status.text = "保存失败：" + PlayerText.error(str(session.save_files.last_failure.get("error", "Unknown")))
		_save_status_elapsed += maxf(dt, 0.0)
		if save_state_label != null and growth_panel != null and growth_panel.visible and _save_status_elapsed >= 1.0:
			_save_status_elapsed = 0.0
			if session.save_files == null:
				save_state_label.text = "尚未设置存档目录"
			elif not session.save_files.last_failure.is_empty():
				save_state_label.text = "保存失败：" + PlayerText.error(str(session.save_files.last_failure.get("error", "Unknown")))
			elif session.save_files.busy():
				save_state_label.text = "正在保存…"
			else:
				var status: Dictionary = session.dirty_since_save()
				save_state_label.text = "暂时无法读取保存状态" if not status.ok else "有未保存进度" if status.dirty else "最近进度已写入文件"
		if _autosave_interval > 0.0 and session.save_files != null and session.wall_time >= _next_autosave_wall:
			_next_autosave_wall = session.wall_time + _autosave_interval
			var saved: Dictionary = session.request_save()
			if not saved.ok and growth_status != null: growth_status.text = PlayerText.error(str(saved.get("error", saved.get("reason", "SaveFailed"))))
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
	_battle_viewport.add_child(layer)
	_overlay = Node2D.new()
	layer.add_child(_overlay)
	_overlay.draw.connect(_draw_shell.bind(_overlay))
	_pause_button = Button.new()
	_pause_button.text = "继续" if session.pause_reasons.has("user") else "暂停"
	_pause_button.position = Vector2(420, 18)
	_pause_button.pressed.connect(func():
		if session.run_state.is_running():
			session.set_pause("user", not session.pause_reasons.has("user"))
			_pause_button.text = "继续" if session.pause_reasons.has("user") else "暂停")
	layer.add_child(_pause_button)
	_save_warning = Label.new()
	_save_warning.position = Vector2(18, 54)
	_save_warning.size = Vector2(530, 24)
	_save_warning.clip_text = true
	_save_warning.max_lines_visible = 1
	_save_warning.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_save_warning.add_theme_font_size_override("font_size", 14)
	_save_warning.modulate = Color("ffb4a6")
	layer.add_child(_save_warning)

func _refresh_save_warning() -> void:
	if _save_warning == null: return
	var failed_save: bool = session.save_files != null and not session.save_files.last_failure.is_empty()
	if not session.run_state.is_running():
		_save_warning.text = "会话已停止；保存未完成。请在舰桥设置中恢复有效存档。" if failed_save or not _startup_save_error.is_empty() else "会话已停止，请在舰桥查看提示并恢复有效存档。"
	else:
		_save_warning.text = "保存失败，请在舰桥设置中重试，当前进度尚未写入文件。" if failed_save else _startup_save_error
	_save_warning.tooltip_text = _save_warning.text
	_save_warning.visible = not _save_warning.text.is_empty()

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
	_guidance_label.text = str(captions.get(str(pending.id), _player_text.notification_text("unlock", str(pending.id))))
	_guidance_panel.visible = true

func _draw_shell(canvas: Node2D) -> void:
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(18, 942), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))

func _command_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(func():
		if not session.run_state.is_running():
			growth_status.text = "当前会话已停止，请恢复有效存档。"
			return
		if not _pending_reforge.is_empty() and text not in ["确认重铸", "取消重铸"]:
			growth_status.text = "请先确认或取消重铸"
			return
		var result: Dictionary = action.call()
		if result.get("settings_failed", false):
			growth_status.text = "个人设置重置失败：" + PlayerText.error(str(result.get("settings_error", "Unknown")))
			return
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"NoChange": "没有变更", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "会话已切换，保存失败：" + PlayerText.error(str(result.get("persistence_error", "Unknown"))) if result.get("persistence_failed", false) else "保存请求已排队" if result.get("persistence_pending", false) or result.has("generation") else str(result.get("message", "完成")) if result.get("ok", false) else str(result.get("message", labels.get(reason, PlayerText.error(reason))))
		)
	return button

func _set_page(page: String) -> void:
	var saved: Dictionary = PlayerSettings.save_change("page", page)
	if saved.ok:
		_preferred_page = page
		growth_panel.visible = page == "growth"
	elif growth_status != null:
		growth_status.text = PlayerText.error(str(saved.reason))

func _setup_growth_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var open := Button.new()
	open.text = "舰桥面板"
	open.position = Vector2(678, 48)
	layer.add_child(open)
	growth_panel = PanelContainer.new()
	growth_panel.position = Vector2(12, 130)
	growth_panel.size = Vector2(548, 760)
	growth_panel.visible = _preferred_page == "growth"
	layer.add_child(growth_panel)
	growth_panel.theme = load("res://src/ui/bridge_theme.gd").create()
	var shell := VBoxContainer.new()
	growth_panel.add_child(shell)
	var box: VBoxContainer = shell
	var back := Button.new()
	back.text = "关闭面板"
	back.pressed.connect(func(): _set_page("battle"))
	box.add_child(back)
	growth_status = Label.new()
	if not _settings_error.is_empty(): growth_status.text = _settings_error
	PlayerText.wrap(growth_status)
	box.add_child(growth_status)
	save_state_label = Label.new()
	PlayerText.wrap(save_state_label)
	box.add_child(save_state_label)
	_save_status_elapsed = 1.0
	open.pressed.connect(func(): _set_page("battle" if growth_panel.visible else "growth"))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_tabs)
	_pages.clear()
	for page in [["ship", "舰船"], ["growth", "成长"], ["universe", "星图"], ["hyperspace", "超空间"], ["archive", "档案"], ["settings", "设置"]]:
		_create_bridge_page(str(page[0]), str(page[1]))
	box = _pages.ship.box
	box.add_child(load("res://src/ui/campaign_panel.gd").new(session, _command_button))
	# Equipment has one scene and one command surface in the hangar at left.
	box.add_child(FleetPanel.new(session.campaign_system, session.commit_ship_refit, _command_button))
	box.add_child(load("res://src/ui/attributes_panel.gd").new(session))
	box = _pages.growth.box
	var research_panel = ResearchPanel.new(session.research, _command_button)
	box.add_child(research_panel)
	_feature_panels["research"] = research_panel
	_add_feature_panel(box, "enhancement", EnhancementPanel.new(session.enhancement, session.enhancement_inputs,
		session.economy.affordable, session.publish_enhancement, _command_button))
	box = _pages.universe.box
	_add_feature_panel(box, "crew", CrewPanel.new(session.crew_system, session.planet_system, session.galaxy_system, session.coordinate_assignment, _command_button))
	_add_feature_panel(box, "galaxy", GalaxyPanel.new(session.galaxy_system, _world_visual_context))
	_add_feature_panel(box, "planet", PlanetPanel.new(session.planet_system, session.coordinate_planet_cancel, session.publish_planet_claim, _command_button, _world_visual_context))
	box = _pages.hyperspace.box
	_add_feature_panel(box, "hyperspace", HyperspacePanel.new(session, _command_button))
	box = _pages.archive.box
	box.add_child(load("res://src/ui/archive_panel.gd").new(session))
	box.add_child(NotificationsPanel.new(session.notifications, _player_text))
	box = _pages.settings.box
	var save_path := LineEdit.new()
	save_path.placeholder_text = "存档目录（完整路径）"
	save_path.text = session.save_files._directory if session.save_files != null else _startup_directory
	box.add_child(save_path)
	var save_picker := FileDialog.new()
	save_picker.access = FileDialog.ACCESS_FILESYSTEM
	save_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_picker.dir_selected.connect(func(path: String): save_path.text = path)
	box.add_child(save_picker)
	_command_button(box, "选择存档目录", func() -> Dictionary:
		save_picker.popup_centered_ratio()
		return {"ok": true, "message": "请选择已有的存档目录"})
	var speed_options := OptionButton.new()
	for option in session.chrono_speed_options():
		speed_options.add_item("%s倍速 · 每秒消耗%s时空微粒" % [option.speed, option.cost], int(option.speed))
		if int(option.speed) == session.current_chrono_speed(): speed_options.select(speed_options.item_count - 1)
	speed_options.item_selected.connect(func(index: int):
		session.set_chrono_speed(speed_options.get_item_id(index)))
	box.add_child(speed_options)
	_command_button(box, "保存", func() -> Dictionary:
		var configured: Dictionary = _configure_save(save_path.text)
		return session.request_save() if configured.ok else configured)
	var autosave := SpinBox.new()
	autosave.min_value = 0.0
	autosave.max_value = 86400.0
	autosave.step = 1.0
	var autosave_caption := Label.new()
	autosave_caption.text = "自动保存间隔（现实时间，0为关闭）"
	PlayerText.wrap(autosave_caption)
	box.add_child(autosave_caption)
	autosave.suffix = " 秒"
	autosave.set_meta("autosave_interval", true)
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
			growth_status.text = PlayerText.error(str(saved.reason)))
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
			growth_status.text = PlayerText.error(str(saved.reason)))
	var music := CheckBox.new()
	music.text = "音乐"
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
			growth_status.text = PlayerText.error(str(saved.reason)))
	var effects := CheckBox.new()
	effects.text = "音效"
	effects.button_pressed = _effects_enabled
	_effects_toggle = effects
	box.add_child(effects)
	effects.toggled.connect(func(enabled: bool):
		var saved: Dictionary = PlayerSettings.save_change("effects_enabled", enabled)
		if saved.ok: _effects_enabled = enabled
		else:
			effects.set_pressed_no_signal(_effects_enabled)
			growth_status.text = PlayerText.error(str(saved.reason)))
	var damage_mode := OptionButton.new()
	for mode in PlayerSettings.DAMAGE_MODES: damage_mode.add_item("伤害数字：" + str({"all": "全部", "critical": "仅暴击", "off": "关闭"}[mode]))
	damage_mode.select(PlayerSettings.DAMAGE_MODES.find(_damage_mode))
	_damage_option = damage_mode
	box.add_child(damage_mode)
	damage_mode.item_selected.connect(func(index: int):
		var chosen: String = PlayerSettings.DAMAGE_MODES[index]
		var saved: Dictionary = PlayerSettings.save_change("damage_mode", chosen)
		if saved.ok:
			_damage_mode = chosen
			for child in (_battle_viewport.get_children() if _battle_viewport != null else get_children()):
				if child.get_script() == BattleView: child.damage_mode = chosen
		else:
			damage_mode.select(PlayerSettings.DAMAGE_MODES.find(_damage_mode))
			growth_status.text = PlayerText.error(str(saved.reason)))
	var clear_settings := CheckBox.new()
	clear_settings.text = "新游戏同时重置个人设置"
	box.add_child(clear_settings)
	_command_button(box, "预览新游戏", func() -> Dictionary:
		return _preview_new_game(save_path.text, clear_settings.button_pressed))
	_command_button(box, "确认新游戏", func() -> Dictionary:
		return _confirm_new_game(save_path.text, clear_settings.button_pressed))
	_command_button(box, "加载主存档", func() -> Dictionary:
		return _load_saved(save_path.text))
	_command_button(box, "加载备份", func() -> Dictionary:
		return _load_saved(save_path.text, true))
	var import_path := LineEdit.new()
	import_path.placeholder_text = "要导入的存档文件"
	box.add_child(import_path)
	var import_picker := FileDialog.new()
	import_picker.access = FileDialog.ACCESS_FILESYSTEM
	import_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_picker.add_filter("*.json", "游戏存档")
	import_picker.file_selected.connect(func(path: String): import_path.text = path)
	box.add_child(import_picker)
	_command_button(box, "选择导入文件", func() -> Dictionary:
		import_picker.popup_centered_ratio()
		return {"ok": true, "message": "请选择游戏存档文件"})
	_command_button(box, "预览导入", func() -> Dictionary:
		return _preview_import(save_path.text, import_path.text))
	_command_button(box, "确认导入", func() -> Dictionary:
		return _apply_import(save_path.text, import_path.text))
	box = _pages.universe.box
	var planet_id := LineEdit.new()
	planet_id.placeholder_text = "重铸星球编号"
	var reforge_box := VBoxContainer.new()
	_add_feature_panel(box, "reforge", reforge_box)
	reforge_box.add_child(planet_id)
	var retained_ids := LineEdit.new()
	retained_ids.placeholder_text = "保留无人机编号（逗号分隔）"
	reforge_box.add_child(retained_ids)
	planet_id.hide()
	retained_ids.hide()
	_setup_reforge_selection(reforge_box, planet_id, retained_ids)
	_command_button(reforge_box, "预览重铸", func() -> Dictionary:
		return _preview_reforge(save_path.text, planet_id.text, retained_ids.text))
	_command_button(reforge_box, "确认重铸", func() -> Dictionary:
		return _confirm_reforge(save_path.text, planet_id.text, retained_ids.text))
	_command_button(reforge_box, "取消重铸", _cancel_reforge)
	_tabs.tab_changed.connect(_bridge_tab_changed)
	_bridge_tab_changed(_tabs.current_tab)

func _add_feature_panel(parent: Control, key: String, panel: Control) -> void:
	_feature_panels[key] = panel
	parent.add_child(panel)

func _queue_feature_visibility() -> void:
	_visibility_pending = true

func _refresh_feature_visibility() -> void:
	_visibility_pending = false
	var research_available: bool = false
	for enabled in session.research.choices().values():
		if enabled: research_available = true
	var highest: int = int(session.campaign_system.progress_facts().highest_reached)
	var visible_features := {"reactor": session.campaign_system.available("feature", "reactor"),
		"research": research_available, "enhancement": session.campaign_system.available("feature", "jewels"),
		"crew": not session.crew_system.member_options().is_empty(), "planet": not session.planet_system.planet_options().is_empty(),
		"galaxy": not session.galaxy_system.status_rows().is_empty(), "hyperspace": session.hyperspace_system.unlocked(highest),
		"reforge": not session.planet_system.planet_options().is_empty()}
	for key in _feature_panels: _feature_panels[key].visible = bool(visible_features[key])
	_refresh_left_module()
	if _tabs != null:
		_tabs.set_tab_hidden(_pages.growth.index, not (visible_features.research or visible_features.enhancement))
		_tabs.set_tab_hidden(_pages.universe.index, not (visible_features.crew or visible_features.planet or visible_features.galaxy))
		_tabs.set_tab_hidden(_pages.hyperspace.index, not visible_features.hyperspace)
		if _tabs.is_tab_hidden(_tabs.current_tab): _tabs.current_tab = int(_pages.ship.index)

func _create_bridge_page(key: String, title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_pages[key] = {"scroll": scroll, "box": box, "index": _tabs.get_tab_count() - 1}

func _bridge_tab_changed(index: int) -> void:
	if _reforge_picker != null and index == int(_pages.universe.index): _refresh_reforge_selection()

func _world_visual_context() -> Dictionary:
	return {"paused": not session.pause_reasons.is_empty(), "speed": session.current_chrono_speed(),
		"galaxy_crew": session.crew_system.galaxy_assignments()}

func _setup_reforge_selection(parent: Control, planet_value: LineEdit, drone_value: LineEdit) -> void:
	_reforge_planet_value = planet_value
	_reforge_drone_value = drone_value
	var heading := Label.new()
	heading.text = "重铸远征"
	heading.add_theme_font_size_override("font_size", 20)
	parent.add_child(heading)
	var help := Label.new()
	help.text = "选择尚未征服且已建成造船厂的星球，并选择本次保留的无人机。先预览损失与收益，确认后才征服并重铸。"
	PlayerText.wrap(help)
	parent.add_child(help)
	_reforge_picker = OptionButton.new()
	parent.add_child(_reforge_picker)
	_reforge_picker.item_selected.connect(func(index): _reforge_planet_value.text = str(_reforge_picker.get_item_metadata(index)))
	_reforge_drones = ItemList.new()
	_reforge_drones.select_mode = ItemList.SELECT_MULTI
	_reforge_drones.custom_minimum_size.y = 120
	parent.add_child(_reforge_drones)
	_reforge_drones.multi_selected.connect(func(_index, _selected):
		var selected := PackedStringArray()
		for index in _reforge_drones.get_selected_items(): selected.append(str(_reforge_drones.get_item_metadata(index)))
		_reforge_drone_value.text = ",".join(selected))
	_refresh_reforge_selection()

func _refresh_reforge_selection() -> void:
	var previous: String = _reforge_planet_value.text
	_reforge_picker.clear()
	for option in session.planet_system.planet_options():
		_reforge_picker.add_item(str(option.name))
		var index: int = _reforge_picker.item_count - 1
		_reforge_picker.set_item_metadata(index, option.id)
		if str(option.id) == previous: _reforge_picker.select(index)
	if _reforge_picker.selected >= 0: _reforge_planet_value.text = str(_reforge_picker.get_item_metadata(_reforge_picker.selected))
	var selected: PackedStringArray = _reforge_drone_value.text.split(",", false)
	_reforge_drones.clear()
	var number: int = 0
	for drone in session.hyperspace_system.warehouse().main:
		number += 1
		var names := {"laser": "脉冲激光", "cannon": "磁轨炮", "missile": "导弹", "longLaser": "长激光"}
		_reforge_drones.add_item("无人机 %d · %s · Lv%d" % [number, names.get(str(drone.weapon), "武装"), int(drone.level)])
		_reforge_drones.set_item_metadata(number - 1, drone.id)
		if str(drone.id) in selected: _reforge_drones.select(number - 1, false)
