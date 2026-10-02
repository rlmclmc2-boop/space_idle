extends Control
## Standalone authoring scene: never instantiates BattleGame or reads player saves.

const TABLES := ["mon", "monGroup", "level"]
static var TITLES := [UIText.t("debug.global.text_01"), UIText.t("debug.global.text_02"), UIText.t("debug.global.text_03")]
static var LABELS := {"id":UIText.t("debug.global.text_04"), "des":UIText.t("debug.global.text_05"), "equipment":UIText.t("debug.global.text_06"), "dmgMultiple":UIText.t("debug.global.text_07"), "health":UIText.t("debug.global.text_08"), "armourType":UIText.t("debug.global.text_09"), "res":UIText.t("debug.global.text_10"), "size":UIText.t("debug.global.text_11"), "length":UIText.t("debug.global.text_12"), "atkRatio":UIText.t("debug.global.text_13"), "lifeRatio":UIText.t("debug.global.text_14"), "resRatio":UIText.t("debug.global.text_15"), "jewelRatio":UIText.t("debug.global.text_16")}
const NUMBERS := ["id", "dmgMultiple", "health", "armourType", "size", "length", "atkRatio", "lifeRatio", "resRatio", "jewelRatio"]
var document: Dictionary = {}
var table := "mon"
var selected := -1
var dirty := false
var fields: Dictionary = {}
var slots: Array[OptionButton] = []
var encounters: Array = []
var encounter_box: VBoxContainer
var listing: ItemList
var search: LineEdit
var form: VBoxContainer
var status: RichTextLabel
var preview: RichTextLabel
var toolbar: HBoxContainer
var tabs: TabBar
var worker: Thread
var output: Array = []
var pending_action := ""
var request_path := ""
var confirmation: ConfirmationDialog

func _ready() -> void:
	get_window().title = UIText.t("debug._ready.text_21")
	get_window().min_size = Vector2i(1100, 760)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(close_editor)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "sans-serif"])
	var style := Theme.new()
	style.default_font = font
	style.default_font_size = 17
	theme = style
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = UIText.t("debug._ready.text_22")
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	var help := Label.new()
	help.text = UIText.t("debug._ready.text_23")
	column.add_child(help)
	toolbar = HBoxContainer.new()
	column.add_child(toolbar)
	button(toolbar, UIText.t("debug._ready.text_24"), reload_document)
	button(toolbar, UIText.t("debug._ready.text_25"), func(): run_action("validate"))
	button(toolbar, UIText.t("debug._ready.text_26"), func(): run_action("save"))
	button(toolbar, UIText.t("debug._ready.text_07"), func(): OS.shell_open(ProjectSettings.globalize_path("res://config_excel")))
	tabs = TabBar.new()
	for title in TITLES: tabs.add_tab(title)
	column.add_child(tabs)
	tabs.tab_changed.connect(func(index):
		stash()
		table = TABLES[index]
		selected = -1
		search.text = ""
		refresh_list()
		show_record(0 if rows().size() else -1))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	split.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = UIText.t("debug._ready.text_27")
	search.text_changed.connect(func(_text): refresh_list())
	left.add_child(search)
	listing = ItemList.new()
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(func(index):
		stash()
		show_record(int(listing.get_item_metadata(index))))
	left.add_child(listing)
	var actions := HBoxContainer.new()
	left.add_child(actions)
	button(actions, UIText.t("debug._ready.text_28"), func(): add_record(false))
	button(actions, UIText.t("debug._ready.text_29"), func(): add_record(true))
	button(actions, UIText.t("debug._ready.text_30"), delete_record)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	form = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)
	preview = RichTextLabel.new()
	preview.custom_minimum_size.y = 92
	preview.bbcode_enabled = true
	right.add_child(preview)
	status = RichTextLabel.new()
	status.custom_minimum_size.y = 105
	column.add_child(status)
	confirmation = ConfirmationDialog.new()
	confirmation.ok_button_text = UIText.t("system.confirm")
	confirmation.cancel_button_text = UIText.t("system.cancel")
	confirmation.title = UIText.t("debug._ready.text_31")
	add_child(confirmation)
	run_action("load")

func button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func rows() -> Array:
	return document.get("tables", {}).get(table, {}).get("rows", [])

func display_value(value: Variant) -> String:
	if (value is float or value is int) and is_finite(float(value)) and value == int(value):
		return str(int(value))
	return str(value)

func refresh_list() -> void:
	listing.clear()
	for index in range(rows().size()):
		var row: Dictionary = rows()[index]
		if not search.text.is_empty() and not JSON.stringify(row).to_lower().contains(search.text.to_lower()): continue
		var text := UIText.t("debug.refresh_list.text_01", {"id":"%s" % (display_value(row.id)), "id_2":"%s" % (str(row.get("des", UIText.t("debug.refresh_list.text_02") + display_value(row.id))))})
		listing.add_item(text)
		listing.set_item_metadata(listing.item_count - 1, index)
		if index == selected: listing.select(listing.item_count - 1)

func clear_form() -> void:
	for child in form.get_children():
		form.remove_child(child)
		child.queue_free()
	fields.clear()
	slots.clear()
	encounters.clear()

func show_record(index: int) -> void:
	selected = index
	clear_form()
	if index < 0 or index >= rows().size():
		preview.text = UIText.t("debug.show_record.text_01")
		return
	var record: Dictionary = rows()[index]
	for key in document.tables[table].headers:
		if table == "level" and key in ["atkRatio", "lifeRatio", "resRatio"]: continue
		if key == "mon" or key == "monGroup": continue
		var line := HBoxContainer.new()
		form.add_child(line)
		var label := Label.new()
		label.text = LABELS.get(key, key)
		label.custom_minimum_size.x = 315
		line.add_child(label)
		var entry := LineEdit.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.text = "" if record.get(key) == null else display_value(record[key])
		entry.text_changed.connect(func(_text): dirty = true)
		line.add_child(entry)
		fields[key] = entry
	if table == "monGroup":
		var hint := Label.new()
		hint.text = UIText.t("debug.show_record.text_02")
		form.add_child(hint)
		var values := clean(str(record.mon)).split(",")
		var grid := GridContainer.new()
		grid.columns = 2
		form.add_child(grid)
		for i in range(10 if values.size()==10 else 15):
			var label := Label.new()
			label.text = UIText.t("debug.show_record.text_03", {"i":"%02d" % ((i + 1))})
			grid.add_child(label)
			var option := choices("mon", values[i] if i < values.size() else "null", true)
			grid.add_child(option)
			slots.append(option)
	elif table == "level":
		var hint := Label.new()
		hint.text = UIText.t("debug.show_record.text_04")
		form.add_child(hint)
		var formula_hint := Label.new()
		formula_hint.text = UIText.t("debug.show_record.text_05")
		form.add_child(formula_hint)
		encounter_box = VBoxContainer.new()
		form.add_child(encounter_box)
		for value in clean(str(record.monGroup)).split(","):
			var parts := value.split("|")
			if parts.size() == 2: add_encounter(parts[0], parts[1])
		button(form, UIText.t("debug.show_record.text_06"), func():
			add_encounter("", "0.5")
			dirty = true)
	button(form, UIText.t("debug.show_record.text_07"), func():
		stash()
		refresh_list()
		update_preview())
	update_preview()
	refresh_list()

func clean(value: String) -> String:
	return value.replace("｛", "{").replace("｝", "}").replace("，", ",").strip_edges().trim_prefix("{").trim_suffix("}")

func choices(kind: String, value: String, empty: bool = false) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.x = 300
	if empty:
		choice.add_item(UIText.t("debug.choices.text_01"))
		choice.set_item_metadata(0, "null")
	for row in document.tables[kind].rows:
		choice.add_item(UIText.t("debug.choices.text_02", {"id":"%s" % (display_value(row.id)), "des":"%s" % (str(row.get("des", "")))}))
		choice.set_item_metadata(choice.item_count - 1, display_value(row.id))
	var found := false
	for i in range(choice.item_count):
		if str(choice.get_item_metadata(i)) == value.strip_edges():
			choice.select(i)
			found = true
	if not found and not value.is_empty():
		choice.add_item(UIText.t("debug.choices.text_03") + value)
		choice.set_item_metadata(choice.item_count - 1, value)
		choice.select(choice.item_count - 1)
	choice.item_selected.connect(func(_i): dirty = true)
	return choice

func add_encounter(id: String, position: String) -> void:
	var line := HBoxContainer.new()
	encounter_box.add_child(line)
	var choice := choices("monGroup", id)
	line.add_child(choice)
	var entry := LineEdit.new()
	entry.text = position
	entry.custom_minimum_size.x = 110
	entry.text_changed.connect(func(_t): dirty = true)
	line.add_child(entry)
	var item := {"node": line, "choice": choice, "position": entry}
	encounters.append(item)
	button(line, UIText.t("debug.add_encounter.text_01"), func():
		encounters.erase(item)
		line.queue_free()
		dirty = true)

func choice_value(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""

func stash() -> void:
	if selected < 0 or selected >= rows().size(): return
	var record: Dictionary = rows()[selected]
	var before := JSON.stringify(record)
	for key in fields:
		var value: String = fields[key].text.strip_edges()
		record[key] = float(value) if key in NUMBERS and value.is_valid_float() else value
	if table == "monGroup":
		var values: Array[String] = []
		for slot in slots: values.append(choice_value(slot))
		record.mon = "{" + ",".join(values) + "}"
	if table == "level":
		var values: Array[String] = []
		for item in encounters: values.append(choice_value(item.choice) + "|" + item.position.text.strip_edges())
		record.monGroup = "{" + ",".join(values) + "}"
	if before != JSON.stringify(record): dirty = true

func add_record(duplicate: bool) -> void:
	stash()
	var row: Dictionary
	if duplicate and selected >= 0:
		row = rows()[selected].duplicate(true)
	elif table == "mon":
		row = {"des":UIText.t("debug.add_record.text_01"), "equipment":"{laser_mon|1}", "dmgMultiple":1, "health":100, "armourType":0, "res":"{1,10,1}", "size":1}
	elif table == "monGroup":
		row = {"des":UIText.t("debug.add_record.text_02"), "mon":"{null,null,null,null,null,null,null,null,null,null,null,null,null,null,null}"}
	else:
		row = {"length":1000, "monGroup":"", "atkRatio":1, "lifeRatio":1, "resRatio":1, "jewelRatio":1}
	var next_id := 1
	for existing in rows(): next_id = maxi(next_id, int(existing.id) + 1)
	row.id = next_id
	rows().append(row)
	dirty = true
	search.text = ""
	show_record(rows().size()-1)

func references() -> String:
	if selected < 0: return ""
	var id := display_value(rows()[selected].id)
	var used: Array[String] = []
	if table == "mon":
		for row in document.tables.monGroup.rows:
			for token in clean(str(row.mon)).split(","):
				if token.strip_edges() == id:
					used.append(UIText.t("debug.references.text_01") + display_value(row.id))
					break
	elif table == "monGroup":
		for row in document.tables.level.rows:
			for token in clean(str(row.monGroup)).split(","):
				if token.split("|")[0].strip_edges() == id:
					used.append(UIText.t("debug.refresh_list.text_02") + display_value(row.id))
					break
	return "、".join(used)

func delete_record() -> void:
	stash()
	if selected < 0: return
	var used := references()
	if not used.is_empty():
		status.text = UIText.t("debug.delete_record.text_01") + used + UIText.t("debug.delete_record.text_02")
		return
	confirm_action(UIText.t("debug.delete_record.text_03"), func():
		rows().remove_at(selected)
		dirty = true
		show_record(mini(selected, rows().size()-1))
		refresh_list())

func update_preview() -> void:
	if selected < 0: return
	var row: Dictionary = rows()[selected]
	var used := references()
	preview.text = UIText.t("debug.update_preview.text_01") + (used if not used.is_empty() else UIText.t("debug.update_preview.text_02")) + "\n"
	if table == "monGroup":
		var values := clean(str(row.mon)).split(",")
		preview.text += UIText.t("debug.update_preview.text_03") + "  →  ".join(values)
	elif table == "level":
		preview.text += UIText.t("debug.update_preview.text_04") + clean(str(row.monGroup)).replace(",", "  →  ") + UIText.t("debug.update_preview.text_05")
	else:
		preview.text += UIText.t("debug.update_preview.text_06") + str(row.get("equipment", "")) + UIText.t("debug.update_preview.text_07") + str(row.get("res", ""))

func confirm_action(message: String, action: Callable) -> void:
	for connection in confirmation.confirmed.get_connections(): confirmation.confirmed.disconnect(connection.callable)
	confirmation.dialog_text = message
	confirmation.confirmed.connect(action, CONNECT_ONE_SHOT)
	confirmation.popup_centered(Vector2i(720, 180))

func reload_document() -> void:
	if dirty: confirm_action(UIText.t("debug.reload_document.text_01"), func(): run_action("load"))
	else: run_action("load")

func close_editor() -> void:
	if worker != null: return
	if dirty: confirm_action(UIText.t("debug.close_editor.text_01"), func(): get_tree().quit())
	else: get_tree().quit()

func run_action(action: String) -> void:
	if worker != null: return
	if action != "load": stash()
	pending_action = action
	output.clear()
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tools/level_editor_store.py"), action])
	if action != "load":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime"))
		request_path = ProjectSettings.globalize_path("res://.runtime/level-editor-%d.json" % OS.get_process_id())
		var file := FileAccess.open(request_path, FileAccess.WRITE)
		if file == null:
			status.text = UIText.t("debug.run_action.text_01") + str(FileAccess.get_open_error())
			return
		file.store_string(JSON.stringify(document))
		file.close()
		args.append_array(["--request", request_path])
	var python: String = preload("res://scripts/config_panel.gd").find_python()
	worker = Thread.new()
	worker.start(func(): return OS.execute(python, args, output, true, false))
	set_busy(true)
	status.text = UIText.t("debug.run_action.text_02") + {"load":UIText.t("debug.run_action.text_03"), "save":UIText.t("debug.run_action.text_04"), "validate":UIText.t("debug._ready.text_25")}[action] + "…"

func set_busy(busy: bool) -> void:
	for b in toolbar.get_children(): b.disabled = busy
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	# Disable the entire form while the worker snapshot is in flight.
	set_controls(self, busy)

func set_controls(node: Node, busy: bool) -> void:
	for child in node.get_children():
		if child is BaseButton: child.disabled = busy
		if child is LineEdit: child.editable = not busy
		if child is ItemList: child.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
		set_controls(child, busy)

func _process(_delta: float) -> void:
	if worker == null or worker.is_alive(): return
	worker.wait_to_finish()
	worker = null
	if not request_path.is_empty():
		DirAccess.remove_absolute(request_path)
		request_path = ""
	set_busy(false)
	var parsed = JSON.parse_string("".join(output).strip_edges())
	if not parsed is Dictionary:
		status.text = UIText.t("debug._process.text_11") + "".join(output)
		return
	if not parsed.get("ok", false):
		status.text = UIText.t("debug._process.text_12") + str(parsed.get("message", UIText.t("debug._process.text_13")))
		return
	if parsed.has("tables"):
		document = parsed
		dirty = false
		show_record(clampi(selected, 0, rows().size()-1) if rows().size() else -1)
		refresh_list()
	status.text = str(parsed.get("message", UIText.t("debug._process.text_14")))
	for warning in parsed.get("warnings", []): status.text += UIText.t("debug._process.text_15") + str(warning)
	if parsed.has("backup"): status.text += UIText.t("debug._process.text_16") + str(parsed.backup)
