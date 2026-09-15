extends Control
## Standalone authoring scene: never instantiates BattleGame or reads player saves.

const TABLES := ["mon", "monGroup", "level"]
const TITLES := ["敌方飞行器", "敌方飞行器组", "关卡配置"]
const LABELS := {"id":"ID", "des":"描述", "equipment":"武器 name|数量，逗号分隔", "dmgMultiple":"伤害倍率", "health":"基础生命", "armourType":"抗性 0=无 / 1=能量 / 2=物理", "res":"掉落 资源ID,数量,概率", "size":"外观尺寸等级（每舰固定占1格）", "length":"关卡长度", "atkRatio":"攻击倍率", "lifeRatio":"生命倍率", "resRatio":"资源倍率"}
const NUMBERS := ["id", "dmgMultiple", "health", "armourType", "size", "length", "atkRatio", "lifeRatio", "resRatio"]
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
	get_window().title = "太空战舰 · 关卡编辑器"
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
	heading.text = "关卡编辑器    /    太空战舰"
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	var help := Label.new()
	help.text = "编辑分表 → 校验 → 保存并导入 → QA 重启游戏。切换记录自动保留草稿，保存前不改文件。"
	column.add_child(help)
	toolbar = HBoxContainer.new()
	column.add_child(toolbar)
	button(toolbar, "重新加载", reload_document)
	button(toolbar, "校验草稿", func(): run_action("validate"))
	button(toolbar, "保存并导入", func(): run_action("save"))
	button(toolbar, "打开分表目录", func(): OS.shell_open(ProjectSettings.globalize_path("res://config_excel")))
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
	search.placeholder_text = "搜索 ID、描述或配置内容"
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
	button(actions, "新增", func(): add_record(false))
	button(actions, "复制", func(): add_record(true))
	button(actions, "删除", delete_record)
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
	confirmation.title = "确认操作"
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
		var text := "%s  ·  %s" % [display_value(row.id), str(row.get("des", "关卡 " + display_value(row.id)))]
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
		preview.text = "暂无记录。点击新增开始配置。"
		return
	var record: Dictionary = rows()[index]
	for key in document.tables[table].headers:
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
		hint.text = "十格编队（从上到下）；每艘敌舰只占一格，size仅决定外观。"
		form.add_child(hint)
		var values := clean(str(record.mon)).split(",")
		var grid := GridContainer.new()
		grid.columns = 2
		form.add_child(grid)
		for i in range(10):
			var label := Label.new()
			label.text = "第 %02d 格   " % (i + 1)
			grid.add_child(label)
			var option := choices("mon", values[i] if i < values.size() else "null", true)
			grid.add_child(option)
			slots.append(option)
	elif table == "level":
		var hint := Label.new()
		hint.text = "遭遇位置 0–1（0.1 = 10%），按位置升序；最后一场为 BOSS 战。"
		form.add_child(hint)
		var formula_hint := Label.new()
		formula_hint.text = "倍率可填数字或 Excel 公式；本条记录对应第 %d 行。增删后请核对公式地址。" % (index + 4)
		form.add_child(formula_hint)
		encounter_box = VBoxContainer.new()
		form.add_child(encounter_box)
		for value in clean(str(record.monGroup)).split(","):
			var parts := value.split("|")
			if parts.size() == 2: add_encounter(parts[0], parts[1])
		button(form, "＋ 添加遭遇", func():
			add_encounter("", "0.5")
			dirty = true)
	button(form, "更新预览 / 保留本条草稿", func():
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
		choice.add_item("空格")
		choice.set_item_metadata(0, "null")
	for row in document.tables[kind].rows:
		choice.add_item("%s · %s" % [display_value(row.id), str(row.get("des", ""))])
		choice.set_item_metadata(choice.item_count - 1, display_value(row.id))
	var found := false
	for i in range(choice.item_count):
		if str(choice.get_item_metadata(i)) == value.strip_edges():
			choice.select(i)
			found = true
	if not found and not value.is_empty():
		choice.add_item("无效引用：" + value)
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
	button(line, "移除", func():
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
		row = {"des":"新飞行器", "equipment":"{laser_mon|1}", "dmgMultiple":1, "health":100, "armourType":0, "res":"{1,10,1}", "size":1}
	elif table == "monGroup":
		row = {"des":"新编队", "mon":"{null,null,null,null,null,null,null,null,null,null}"}
	else:
		row = {"length":1000, "monGroup":"", "atkRatio":1, "lifeRatio":1, "resRatio":1}
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
					used.append("编队 " + display_value(row.id))
					break
	elif table == "monGroup":
		for row in document.tables.level.rows:
			for token in clean(str(row.monGroup)).split(","):
				if token.split("|")[0].strip_edges() == id:
					used.append("关卡 " + display_value(row.id))
					break
	return "、".join(used)

func delete_record() -> void:
	stash()
	if selected < 0: return
	var used := references()
	if not used.is_empty():
		status.text = "无法删除：被 " + used + " 引用。请先修改这些记录。"
		return
	confirm_action("删除当前记录？删除保存在草稿中。删关卡后需手动保证 ID 连续并核对公式及解锁引用。", func():
		rows().remove_at(selected)
		dirty = true
		show_record(mini(selected, rows().size()-1))
		refresh_list())

func update_preview() -> void:
	if selected < 0: return
	var row: Dictionary = rows()[selected]
	var used := references()
	preview.text = "引用：" + (used if not used.is_empty() else "无上游引用") + "\n"
	if table == "monGroup":
		var values := clean(str(row.mon)).split(",")
		preview.text += "从上到下：  " + "  →  ".join(values)
	elif table == "level":
		preview.text += "起点 0%  →  " + clean(str(row.monGroup)).replace(",", "  →  ") + "  →  终点100%\n遭遇格式：编队ID | 长度比例；最后一场全灭后通关"
	else:
		preview.text += "武器：" + str(row.get("equipment", "")) + "    掉落：" + str(row.get("res", ""))

func confirm_action(message: String, action: Callable) -> void:
	for connection in confirmation.confirmed.get_connections(): confirmation.confirmed.disconnect(connection.callable)
	confirmation.dialog_text = message
	confirmation.confirmed.connect(action, CONNECT_ONE_SHOT)
	confirmation.popup_centered(Vector2i(720, 180))

func reload_document() -> void:
	if dirty: confirm_action("放弃所有未保存草稿，重新读取分表？", func(): run_action("load"))
	else: run_action("load")

func close_editor() -> void:
	if worker != null: return
	if dirty: confirm_action("仍有未保存草稿，确定关闭编辑器？", func(): get_tree().quit())
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
			status.text = "无法写入编辑器草稿请求：" + str(FileAccess.get_open_error())
			return
		file.store_string(JSON.stringify(document))
		file.close()
		args.append_array(["--request", request_path])
	var resolver = load("res://scripts/config_panel.gd").new()
	var python: String = resolver.find_python()
	resolver.free()
	# Resolve through existing QA convention without adding its window to the tree.
	worker = Thread.new()
	worker.start(func(): return OS.execute(python, args, output, true, false))
	set_busy(true)
	status.text = "正在" + {"load":"读取分表", "save":"校验、备份并保存", "validate":"校验草稿"}[action] + "…"

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
		status.text = "工具启动失败。请确认 Python 已安装 openpyxl / lxml。\n" + "".join(output)
		return
	if not parsed.get("ok", false):
		status.text = "未保存：" + str(parsed.get("message", "未知错误"))
		return
	if parsed.has("tables"):
		document = parsed
		dirty = false
		show_record(clampi(selected, 0, rows().size()-1) if rows().size() else -1)
		refresh_list()
	status.text = str(parsed.get("message", "已读取分表。支持新增、复制、搜索、编辑、删除；数字字段也可填写本表公式。"))
	for warning in parsed.get("warnings", []): status.text += "\n提示：" + str(warning)
	if parsed.has("backup"): status.text += "\n备份：" + str(parsed.backup)
