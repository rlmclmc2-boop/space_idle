extends Window

var import_button: Button
var status_label: Label
var worker: Thread
var output: Array = []
var python_path := ""
var restart_button: Button
var full_restart_button: Button
var delete_save_button: Button
var deleting_save := false
var restarting := false
var source_path := ""
var import_source := ""
var source_field: LineEdit
var browse_button: Button
var picker: FileDialog
var history_label: Label
var pause_button: Button
var speed_select: OptionButton
var speed_options: Array[Dictionary] = []
var settings := ConfigFile.new()
var control_poll := 0.0
var observed_paused := false
var split_button: Button
var operation := "import"
var config_directory := ""

func _ready() -> void:
	title = UIText.t("debug._ready.text_01")
	size = Vector2i(660,600)
	min_size = size
	transient = true
	unresizable = true
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","sans-serif"])
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 16
	theme = theme_data
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = UIText.t("debug._ready.text_02")
	heading.add_theme_font_size_override("font_size",24)
	column.add_child(heading)
	settings.load("user://qa_settings.cfg")
	source_path = str(settings.get_value("excel","path",ProjectSettings.globalize_path("res://../太空战舰.xlsx").simplify_path()))
	var source := Label.new()
	source.text = UIText.t("debug._ready.text_03")
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(source)
	var source_row := HBoxContainer.new()
	column.add_child(source_row)
	source_field = LineEdit.new()
	source_field.text = source_path
	source_field.tooltip_text = source_path
	source_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_field.text_submitted.connect(func(value): select_source(value))
	source_field.focus_exited.connect(func(): select_source(source_field.text))
	source_row.add_child(source_field)
	browse_button = Button.new()
	browse_button.text = UIText.t("debug._ready.text_04")
	browse_button.pressed.connect(open_picker)
	source_row.add_child(browse_button)
	picker = FileDialog.new()
	picker.ok_button_text = UIText.t("system.open")
	picker.cancel_button_text = UIText.t("system.cancel")
	picker.title = UIText.t("debug._ready.text_05")
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.xlsx ; " + UIText.t("debug.excel_filter")])
	picker.file_selected.connect(select_source)
	add_child(picker)
	config_directory = ProjectSettings.globalize_path("res://config_excel")
	var split_row := HBoxContainer.new()
	split_row.add_theme_constant_override("separation",12)
	column.add_child(split_row)
	split_button = Button.new()
	split_button.text = UIText.t("debug._ready.text_06")
	split_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_button.custom_minimum_size.y = 42
	split_button.pressed.connect(func(): start_operation("split"))
	split_row.add_child(split_button)
	var open_directory := Button.new()
	open_directory.text = UIText.t("debug._ready.text_07")
	open_directory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_directory.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(config_directory)
		OS.shell_open(config_directory))
	split_row.add_child(open_directory)
	var level_editor_button := Button.new()
	level_editor_button.text = UIText.t("debug._ready.text_08")
	level_editor_button.pressed.connect(func():
		var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "res://level_editor.tscn"]))
		if pid == -1: status_label.text = UIText.t("debug._ready.text_09"))
	split_row.add_child(level_editor_button)
	var directory_label := Label.new()
	directory_label.text = UIText.t("debug._ready.text_10")
	directory_label.tooltip_text = config_directory
	column.add_child(directory_label)
	history_label = Label.new()
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.text = str(settings.get_value("excel","last_status",UIText.t("debug._ready.text_11")))
	column.add_child(history_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	column.add_child(buttons)
	import_button = Button.new()
	import_button.text = UIText.t("debug._ready.text_12")
	import_button.custom_minimum_size.y = 46
	import_button.pressed.connect(import_config)
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(import_button)
	restart_button = Button.new()
	restart_button.text = UIText.t("debug._ready.text_13")
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.custom_minimum_size.y = 46
	restart_button.pressed.connect(restart_game)
	buttons.add_child(restart_button)
	full_restart_button = Button.new()
	full_restart_button.text = UIText.t("debug._ready.text_14")
	full_restart_button.tooltip_text = UIText.t("debug._ready.text_15")
	full_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_restart_button.pressed.connect(full_restart)
	buttons.add_child(full_restart_button)
	delete_save_button = Button.new()
	delete_save_button.text = UIText.t("debug._ready.text_16")
	delete_save_button.tooltip_text = UIText.t("debug._ready.text_17")
	delete_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_save_button.pressed.connect(delete_save)
	buttons.add_child(delete_save_button)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	column.add_child(controls)
	pause_button = Button.new()
	pause_button.text = UIText.t("debug._ready.text_18")
	pause_button.custom_minimum_size.y = 42
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(func(): send_control({"paused":not observed_paused}))
	controls.add_child(pause_button)
	speed_select = OptionButton.new()
	speed_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var live_scene := game_scene()
	if live_scene != null:
		sync_speed_options(live_scene)
	speed_select.item_selected.connect(func(index):
		if index >= 0 and index < speed_options.size():
			send_control({"speed":float(speed_options[index].multiplier)}))
	controls.add_child(speed_select)
	status_label = Label.new()
	status_label.text = UIText.t("debug._ready.text_20")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	close_requested.connect(close_panel)
	visibility_changed.connect(update_processing)
	update_processing()
	# Keep native test tooling outside the game viewport.
	var parent_window := get_parent().get_window()
	var screen_rect := DisplayServer.screen_get_usable_rect(parent_window.current_screen)
	position = Vector2i(clampi(parent_window.position.x+parent_window.size.x+12,screen_rect.position.x,screen_rect.end.x-size.x),clampi(parent_window.position.y,screen_rect.position.y,screen_rect.end.y-size.y))

static func find_python() -> String:
	var configured := OS.get_environment("SPACE_BATTLESHIP_PYTHON")
	if not configured.is_empty() and FileAccess.file_exists(configured):
		return configured
	var bundled := OS.get_environment("USERPROFILE").path_join(".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe")
	if FileAccess.file_exists(bundled):
		return bundled
	return "python"

func import_config() -> void:
	start_operation("import")

func start_operation(action: String) -> void:
	if worker != null or restarting:
		return
	operation = action
	python_path = find_python()
	select_source(source_field.text)
	import_source = source_path
	browse_button.disabled = true
	source_field.editable = false
	output.clear()
	status_label.text = UIText.t("debug.start_operation.text_01") if operation == "split" else UIText.t("debug.start_operation.text_02")
	import_button.disabled = true
	split_button.disabled = true
	restart_button.disabled = true
	worker = Thread.new()
	set_process(true)
	var error := worker.start(execute_import)
	if error != OK:
		worker = null
		browse_button.disabled = false
		source_field.editable = true
		import_button.disabled = false
		split_button.disabled = false
		restart_button.disabled = false
		status_label.text = UIText.t("debug.start_operation.text_03") + error_string(error)
		update_processing()

func execute_import() -> int:
	return OS.execute(python_path,PackedStringArray([ProjectSettings.globalize_path("res://tools/config_workbooks.py"),operation,"--source",import_source,"--directory",config_directory]),output,true,false)

func update_processing() -> void:
	control_poll = 0.2
	set_process(visible or worker!=null)

func refresh_controls(_delta: float) -> void:
	full_restart_button.disabled = worker != null or restarting or game_scene() == null
	delete_save_button.disabled = worker != null or restarting or game_scene() == null
	control_poll += _delta
	if control_poll >= 0.2:
		control_poll = 0
		var scene := game_scene()
		var connected := scene != null
		var live: Dictionary = {"paused":scene.game.paused,"speed":scene.game.speed} if connected else {}
		pause_button.disabled = not connected or restarting
		speed_select.disabled = not connected or restarting
		if connected:
			sync_speed_options(scene)
			observed_paused = bool(live.get("paused",false))
			pause_button.text = UIText.t("debug._process.text_01") if observed_paused else UIText.t("debug._ready.text_18")
			for index in speed_options.size():
				if is_equal_approx(float(speed_options[index].multiplier),float(live.speed)):
					speed_select.select(index)
					break

func sync_speed_options(scene: Node) -> void:
	var configured: Array[Dictionary] = scene.game.chrono_options()
	if configured == speed_options:
		return
	speed_options = configured
	speed_select.clear()
	for option in speed_options:
		speed_select.add_item(UIText.t("debug._ready.text_19", {"value":str(option.multiplier)}))

func _process(_delta: float) -> void:
	if visible:refresh_controls(_delta)
	if worker != null and not worker.is_alive():
		var result = worker.wait_to_finish()
		worker = null
		browse_button.disabled = false
		source_field.editable = true
		import_button.disabled = false
		split_button.disabled = false
		restart_button.disabled = false
		var detail := str(output.back()).strip_edges() if not output.is_empty() else UIText.t("debug._process.text_02")
		var lines := detail.split("\n",false)
		var report := JSON.new()
		var parsed := not lines.is_empty() and report.parse(str(lines[-1])) == OK and report.data is Dictionary
		var summary := str(report.data.get("message",detail)) if parsed else (str(lines[-1]) if not lines.is_empty() else detail)
		status_label.text = summary
		if result == 0:
			status_label.text += UIText.t("debug._process.text_03") if operation == "split" else UIText.t("debug._process.text_04")
		else:
			status_label.text = UIText.t("debug._process.text_05") + summary
		status_label.tooltip_text = detail
		history_label.text = UIText.t("debug._process.text_06", {"else":"%s" % (UIText.t("debug._process.text_07") if operation == "split" else UIText.t("debug._process.text_08")), "T":"%s" % (Time.get_datetime_string_from_system().replace("T"," ")), "else_3":"%s" % (UIText.t("debug._process.text_09") if result == 0 else UIText.t("debug._process.text_10")), "config_directory":"%s" % (import_source if operation == "split" else config_directory)})
		settings.set_value("excel","last_status",history_label.text)
		settings.save("user://qa_settings.cfg")
		update_processing()

func open_picker() -> void:
	picker.current_dir = source_path.get_base_dir()
	picker.current_file = source_path.get_file()
	picker.popup_centered(Vector2i(850,550))

func select_source(value: String) -> void:
	source_path = value.strip_edges()
	source_field.text = source_path
	source_field.tooltip_text = source_path
	settings.set_value("excel","path",source_path)
	settings.save("user://qa_settings.cfg")

func game_scene() -> Node:
	var scene := get_tree().current_scene
	return scene if is_instance_valid(scene) and scene.get("game") is BattleGame else null

func send_control(values: Dictionary) -> void:
	var scene := game_scene()
	if scene == null or restarting:
		return
	if values.has("paused"):
		scene.game.paused = bool(values.paused)
		observed_paused = scene.game.paused
	if values.has("speed"):
		scene.game.set_speed(float(values.speed))

func delete_save() -> void:
	restart_game(true)

func full_restart() -> void:
	if worker != null or restarting:
		return
	var scene := game_scene()
	if scene == null:
		status_label.text = UIText.t("debug.full_restart.text_01")
		return
	var failed := [false]
	var on_event := func(kind, _info):
		if kind == "save_error": failed[0] = true
	scene.game.event.connect(on_event)
	scene.game.settle_drops()
	scene.game.save_progress()
	scene.game.event.disconnect(on_event)
	if failed[0]:
		status_label.text = UIText.t("debug.full_restart.text_02")
		return
	if settings.save("user://qa_settings.cfg") != OK:
		status_label.text = UIText.t("debug.full_restart.text_03")
		return
	var project := ProjectSettings.globalize_path("res://")
	if DirAccess.make_dir_recursive_absolute(project.path_join(".runtime")) != OK:
		status_label.text = UIText.t("debug.full_restart.text_04")
		return
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--path", project, "--log-file", project.path_join(".runtime/full-restart.log"), "--script", "res://scripts/restart_host.gd", "--", str(OS.get_process_id())]))
	if pid == -1:
		status_label.text = UIText.t("debug.full_restart.text_05")
		return
	restarting = true
	full_restart_button.disabled = true
	scene.set_process(false)
	scene.game.save_enabled = false
	get_tree().quit()

func restart_game(clear_save: bool = false) -> void:
	if worker != null or restarting:
		return
	var scene := game_scene()
	if scene == null:
		status_label.text = UIText.t("debug.full_restart.text_01")
		return
	if clear_save:
		if FileAccess.file_exists(BattleGame.SAVE_PATH):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(BattleGame.SAVE_PATH))
			if error != OK:
				status_label.text = UIText.t("debug.restart_game.text_01") + error_string(error)
				return
		# Prevent the outgoing scene from writing its old progress back.
		scene.game.save_enabled = false
		scene.set_process(false)
	else:
		var failed := [false]
		var on_event := func(kind, _info):
			if kind == "save_error": failed[0] = true
		scene.game.event.connect(on_event)
		scene.game.settle_drops()
		scene.game.save_progress()
		scene.game.event.disconnect(on_event)
		if failed[0]:
			status_label.text = UIText.t("debug.restart_game.text_02")
			return
	deleting_save = clear_save
	restarting = true
	import_button.disabled = true
	split_button.disabled = true
	restart_button.disabled = true
	delete_save_button.disabled = true
	pause_button.disabled = true
	speed_select.disabled = true
	status_label.text = UIText.t("debug.restart_game.text_03") if clear_save else UIText.t("debug.restart_game.text_04")
	call_deferred("reload_game")

func reload_game() -> void:
	var result := get_tree().reload_current_scene()
	if result == OK:
		await get_tree().scene_changed
	restarting = false
	import_button.disabled = false
	split_button.disabled = false
	restart_button.disabled = false
	status_label.text = UIText.t("debug.reload_game.text_01") if result == OK else UIText.t("debug.reload_game.text_02") + error_string(result)
	if deleting_save and result == OK:
		status_label.text = UIText.t("debug.reload_game.text_03")
	deleting_save = false

func close_panel() -> void:
	hide()

func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()
