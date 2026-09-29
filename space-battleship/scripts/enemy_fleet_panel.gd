extends Window

const Simulator := preload("res://scripts/enemy_fleet_simulator.gd")
const MonGroupXlsx := preload("res://scripts/mon_group_xlsx.gd")
var database: ShipDatabase
var simulator: RefCounted
var inputs := {}
var filters := {}
var enemy_checks := {}
var rows: Array = []
var items: Array[TreeItem] = []
var table: Tree
var details: TextEdit
var status: Label
var tag_filter: OptionButton
var generate_button: Button
var clear_button: Button
var batch := {}
var mon_names: Dictionary={}
var tabs: TabContainer
var level_section: VBoxContainer

func _ready() -> void:
	if database == null:database = ShipDatabase.new()
	simulator = Simulator.new(database)
	var mon_table: Dictionary=MonGroupXlsx.read_mon_names()
	if mon_table.has("names"):mon_names=mon_table.names
	title = UIText.t("fleet.title")
	size = Vector2i(1180, 800)
	min_size = Vector2i(960, 680)
	var page_theme := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	readable_font.variation_embolden = 0.45
	page_theme.default_font = readable_font
	page_theme.default_font_size = 18
	var text_color := Color("f1f6fc")
	var secondary_color := Color("d5e3f1")
	var muted_color := Color("aebed0")
	for type in ["Label", "Button", "OptionButton", "CheckBox", "LineEdit", "TextEdit", "Tree", "ItemList", "PopupMenu", "ProgressBar"]:
		page_theme.set_color("font_color",type,text_color)
	for type in ["Button", "OptionButton", "CheckBox"]:
		for key in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:page_theme.set_color(key,type,Color.WHITE)
		page_theme.set_color("font_disabled_color",type,muted_color)
	for key in ["font_selected_color", "font_hovered_color", "font_hovered_selected_color"]:
		page_theme.set_color(key,"Tree",Color.WHITE)
		page_theme.set_color(key,"ItemList",Color.WHITE)
	page_theme.set_color("title_button_color","Tree",secondary_color)
	page_theme.set_color("font_readonly_color","TextEdit",text_color)
	page_theme.set_color("font_uneditable_color","LineEdit",secondary_color)
	page_theme.set_color("font_placeholder_color","LineEdit",muted_color)
	for key in ["font_selected_color", "font_hovered_color"]:page_theme.set_color(key,"TabBar",Color.WHITE)
	page_theme.set_color("font_unselected_color","TabBar",secondary_color)
	page_theme.set_color("font_disabled_color","TabBar",muted_color)
	theme = page_theme
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:margin.add_theme_constant_override("margin_"+side, 12)
	add_child(margin)
	tabs = TabContainer.new()
	margin.add_child(tabs)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	tabs.add_child(body)
	tabs.set_tab_title(0, UIText.t("fleet.enemy_tab"))
	var heading := Label.new()
	heading.text = UIText.t("fleet.notice")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	var top := HBoxContainer.new()
	body.add_child(top)
	for key in ["count", "min_count", "max_count", "seed"]:
		inputs[key] = number_field(top, key, 0, float(simulator.policy.limits.max_seed) if key == "seed" else float(simulator.policy.limits.max_results) if key == "count" else simulator.slot_count, float(simulator.policy.defaults[key]))
	var limits := HBoxContainer.new()
	body.add_child(limits)
	for key in ["min_strength", "max_strength"]:
		inputs[key] = number_field(limits, key, 0, 1e12, float(simulator.policy.defaults[key]), 0.1)
	generate_button = action(limits, "generate", generate)
	clear_button = action(limits, "clear", clear_results)
	var available_label := Label.new()
	available_label.text = UIText.t("fleet.available")
	body.add_child(available_label)
	var available_scroll := ScrollContainer.new()
	available_scroll.custom_minimum_size.y = 90
	body.add_child(available_scroll)
	var available := HFlowContainer.new()
	available.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_scroll.add_child(available)
	var ids := database.enemies.keys()
	ids.sort()
	for id in ids:
		var check := CheckBox.new()
		check.text = "%s · %s" % [id, str(mon_names.get(str(id),id))]
		check.button_pressed = true
		available.add_child(check)
		enemy_checks[str(id)] = check
	var filter_bar := HBoxContainer.new()
	body.add_child(filter_bar)
	tag_filter = OptionButton.new()
	tag_filter.add_item(UIText.t("fleet.all_tags"))
	tag_filter.set_item_metadata(0, "")
	for rule in simulator.policy.tags:
		tag_filter.add_item(UIText.t("fleet.tag." + str(rule.id)))
		tag_filter.set_item_metadata(tag_filter.item_count-1, rule.id)
	var added_structures := {}
	for rule in simulator.policy.formation.templates:
		if added_structures.has(rule.tag):continue
		added_structures[rule.tag]=true
		tag_filter.add_item(UIText.t("fleet.tag."+str(rule.tag)))
		tag_filter.set_item_metadata(tag_filter.item_count-1,rule.tag)
	filter_bar.add_child(tag_filter)
	tag_filter.item_selected.connect(func(_index):apply_filters())
	for key in ["min_strength", "max_strength", "min_count", "max_count"]:
		filters[key] = number_field(filter_bar, key, 0, 1e12 if key.ends_with("strength") else simulator.slot_count, 0 if key.begins_with("min") else 1e12 if key.ends_with("strength") else simulator.slot_count, 0.1 if key.ends_with("strength") else 1.0)
		filters[key].value_changed.connect(func(_value):apply_filters())
	status = Label.new()
	body.add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	table = Tree.new()
	table.custom_minimum_size.x = 570
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.columns = 4
	table.hide_root = true
	table.column_titles_visible = true
	table.select_mode = Tree.SELECT_ROW
	for index in range(4):
		table.set_column_title(index, UIText.t("fleet.column." + ["number", "count", "strength", "tags"][index]))
		table.set_column_expand(index, index == 3)
		table.set_column_custom_minimum_width(index, [260,55,85,330][index])
	split.add_child(table)
	table.item_selected.connect(show_selected)
	details = TextEdit.new()
	details.editable = false
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical=Control.SIZE_EXPAND_FILL
	split.add_child(details)
	clear_results()
	if mon_names.is_empty():status.text=UIText.t("auto_level.failed",{"reason":UIText.t("auto_level.error."+str(mon_table.get("error","invalid_mon_table")))})
	level_section=VBoxContainer.new()
	level_section.set_script(load("res://scripts/fleet_level_panel.gd"))
	level_section.database=database
	level_section.current_fleets=func():return rows
	tabs.add_child(level_section)
	tabs.set_tab_title(1,UIText.t("auto_level.title"))
	var cycle_section:=VBoxContainer.new()
	cycle_section.set_script(load("res://scripts/cycle_level_panel.gd"))
	cycle_section.database=database
	tabs.add_child(cycle_section)
	tabs.set_tab_title(2,UIText.t("cycle_level.title"))

func number_field(parent: Container, key: String, minimum: float, maximum: float, value: float, step := 1.0) -> SpinBox:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = UIText.t("fleet.input." + key)
	box.add_child(label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = value
	box.add_child(input)
	return input

func action(parent: Container, key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = UIText.t("fleet." + key)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func generate() -> void:
	var mon_table: Dictionary=MonGroupXlsx.read_mon_names()
	if mon_table.has("error"):
		status.text=UIText.t("auto_level.failed",{"reason":UIText.t("auto_level.error."+str(mon_table.error))})
		return
	mon_names=mon_table.names
	for id in enemy_checks:enemy_checks[id].text="%s · %s" % [id,str(mon_names.get(str(id),id))]
	var options := {"available_enemies":[]}
	for key in inputs:options[key] = inputs[key].value
	for id in enemy_checks:
		if enemy_checks[id].button_pressed:options.available_enemies.append(id)
	var started := Time.get_ticks_usec()
	batch = simulator.generate(options)
	batch.elapsed_ms = float(Time.get_ticks_usec() - started) / 1000.0
	rows = batch.results
	# Replacing a batch is an explicit dataset reset; filters never rebuild controls/rows.
	table.clear()
	items.clear()
	var root := table.create_item()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var item := table.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, MonGroupXlsx.group_name(row.composition,mon_names))
		item.set_text(1, str(row.count))
		item.set_text(2, "%.2f" % row.strength)
		item.set_text(3, tag_names(row.primary_tags) + " / " + tag_names(row.secondary_tags) + " / " + tag_names(row.formation_tags))
		items.append(item)
	details.text = ""
	apply_filters()

func tag_names(tags: Array) -> String:
	var names := PackedStringArray()
	for tag in tags:names.append(UIText.t("fleet.tag." + str(tag)))
	return "、".join(names)

func apply_filters() -> void:
	if table == null:return
	var visible_count := 0
	var tag := str(tag_filter.get_selected_metadata())
	for index in range(rows.size()):
		var accepted := Simulator.matches_filter(rows[index], tag, filters.min_strength.value, filters.max_strength.value, int(filters.min_count.value), int(filters.max_count.value))
		if items[index].visible != accepted:items[index].visible = accepted
		if accepted:visible_count += 1
		elif items[index].is_selected(0):
			table.deselect_all()
			details.text = ""
	status.text = UIText.t("fleet.status", {"visible":visible_count, "total":rows.size(), "attempts":batch.get("attempts",0), "ms":"%.1f" % batch.get("elapsed_ms",0), "state":UIText.t("fleet.state." + str(batch.get("status","empty")))})

func show_selected() -> void:
	var selected := table.get_selected()
	if selected == null:return
	var row: Dictionary = rows[int(selected.get_metadata(0))]
	var display := row.duplicate(true)
	display.primary_tags = tag_names(row.primary_tags)
	display.secondary_tags = tag_names(row.secondary_tags)
	display.formation_tags=tag_names(row.formation_tags)
	for key in display.feature_notes:display.feature_notes[key] = UIText.t("fleet.note." + str(display.feature_notes[key]))
	var names := {}
	for id in row.composition:names[id] = {"name":str(mon_names.get(str(id),id)), "count":row.composition[id]}
	display.composition = names
	details.text = formation_preview(row)+"\n\n"+JSON.stringify(display, "  ")

func formation_preview(row: Dictionary) -> String:
	var cells: Array=[]
	for _row in range(3):
		var line:=PackedStringArray()
		for _column in range(11):line.append(" · ")
		cells.append(line)
	for unit in row.formation_positions:
		var y:=clampi(int(round(float(unit.y))),0,2)
		var x:=clampi(int(round(float(unit.x)))+5,0,10)
		var line: PackedStringArray=cells[y]
		line[x]="%3s" % str(unit.id)
		cells[y]=line
	var lines:=PackedStringArray()
	lines.append(UIText.t("formation.summary",{"type":UIText.t("fleet.tag."+str(row.formation_type)),"score":"%.2f" % row.formation_score}))
	for y in range(3):lines.append(UIText.t("formation.row."+["back","middle","front"][y])+"  "+" ".join(cells[y]))
	return "\n".join(lines)

func clear_results() -> void:
	rows.clear()
	items.clear()
	batch.clear()
	table.clear()
	details.text = ""
	apply_filters()
