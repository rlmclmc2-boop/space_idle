extends VBoxContainer
const Generator := preload("res://scripts/player_loadout_generator.gd")
var database: ShipDatabase
var fleet_panel: Window
var generator: RefCounted
var inputs := {}
var ship_checks := {}
var rows: Array = []
var items: Array[TreeItem] = []
var table: Tree
var details: TextEdit
var status: Label
var weapon_filter: OptionButton
var tag_filter: OptionButton
var generate_button: Button
var clear_button: Button
var pair_button: Button
var selected_pair := {}
var batch := {}

func _ready() -> void:
	generator = Generator.new(database)
	add_theme_constant_override("separation",10)
	var notice := Label.new()
	notice.text = UIText.t("player_loadout.notice")
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	var top := HBoxContainer.new()
	add_child(top)
	var defaults: Dictionary = generator.default_options()
	for key in ["count","seed","cleared_through","module_level"]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(box)
		var label := Label.new()
		label.text = UIText.t("player_loadout.input."+key)
		box.add_child(label)
		var input := SpinBox.new()
		input.min_value = 1 if key in ["count","module_level"] else 0
		input.max_value = {"count":generator.policy.max_results,"seed":generator.policy.max_seed,"cleared_through":database.levels.size(),"module_level":generator.policy.max_module_level}[key]
		input.value = defaults[key]
		box.add_child(input)
		inputs[key] = input
	var ship_label := Label.new()
	ship_label.text = UIText.t("player_loadout.available_ships")
	add_child(ship_label)
	var ship_choices := HFlowContainer.new()
	add_child(ship_choices)
	for key in database.ships:
		var check := CheckBox.new()
		check.text = UIText.data_text("ship",key,"des")
		check.button_pressed = defaults.available_ships.has(key)
		ship_choices.add_child(check)
		ship_checks[key] = check
		check.toggled.connect(func(pressed):
			if not pressed and not ship_checks.values().any(func(item):return item.button_pressed):
				check.set_pressed_no_signal(true)
				status.text = UIText.t("player_loadout.require_ship"))
	var actions := HBoxContainer.new()
	add_child(actions)
	generate_button = fleet_panel.action(actions,"generate",generate)
	clear_button = fleet_panel.action(actions,"clear",clear_results)
	pair_button = Button.new()
	pair_button.text = UIText.t("player_loadout.pair")
	pair_button.pressed.connect(show_pair)
	actions.add_child(pair_button)
	weapon_filter = OptionButton.new()
	weapon_filter.add_item(UIText.t("player_loadout.all_weapons"))
	weapon_filter.set_item_metadata(0,"")
	for key in BattleGame.WEAPON_KEYS:
		if not database.equip(key,1).is_empty():
			weapon_filter.add_item(UIText.data_text("equipment",key,"name"))
			weapon_filter.set_item_metadata(weapon_filter.item_count-1,key)
	actions.add_child(weapon_filter)
	weapon_filter.item_selected.connect(func(_index):apply_filters())
	tag_filter = OptionButton.new()
	tag_filter.add_item(UIText.t("fleet.all_tags"))
	tag_filter.set_item_metadata(0,"")
	for rule in generator.policy.tags:
		tag_filter.add_item(UIText.t("player_loadout.tag."+str(rule.id)))
		tag_filter.set_item_metadata(tag_filter.item_count-1,rule.id)
	actions.add_child(tag_filter)
	tag_filter.item_selected.connect(func(_index):apply_filters())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	table = Tree.new()
	table.columns = 5
	table.hide_root = true
	table.column_titles_visible = true
	table.select_mode = Tree.SELECT_ROW
	table.custom_minimum_size.x = 700
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(5):
		table.set_column_title(index,UIText.t("player_loadout.column."+["ship","type","weapons","defence","tags"][index]))
		table.set_column_custom_minimum_width(index,[90,75,175,175,150][index])
		table.set_column_expand(index,index>=2)
	split.add_child(table)
	table.item_selected.connect(show_selected)
	details = TextEdit.new()
	details.editable = false
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(details)
	clear_results()

func generate() -> void:
	var options := {"available_ships":[]}
	for key in inputs:options[key] = int(inputs[key].value)
	for key in ship_checks:
		if ship_checks[key].button_pressed:options.available_ships.append(key)
	var started := Time.get_ticks_usec()
	batch = generator.generate(options)
	batch.elapsed_ms = float(Time.get_ticks_usec()-started)/1000.0
	rows = batch.results
	table.clear()
	items.clear()
	clear_pair()
	var root := table.create_item()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var item := table.create_item(root)
		item.set_metadata(0,index)
		item.set_text(0,UIText.data_text("ship",row.ship,"des"))
		item.set_text(1,UIText.t("player_loadout.type."+str(row.generation_type)))
		item.set_text(2,equipment_names(row.equipment.weapons))
		item.set_text(3,equipment_names(row.equipment.defence))
		item.set_text(4,tag_names(row.tags))
		for column in [2,3,4]:item.set_tooltip_text(column,item.get_text(column))
		items.append(item)
	details.text = ""
	apply_filters()

func equipment_names(entries: Array) -> String:
	var counts := {}
	for entry in entries:
		var name := "%s Lv.%d" % [UIText.data_text("equipment",entry.key,"name"),int(entry.level)]
		counts[name]=int(counts.get(name,0))+1
	var names := PackedStringArray()
	for name in counts:names.append("%s ×%d" % [name,counts[name]])
	return ", ".join(names)

func tag_names(tags: Array) -> String:
	var names := PackedStringArray()
	for tag in tags:names.append(UIText.t("player_loadout.tag."+str(tag)))
	return " / ".join(names)

func apply_filters() -> void:
	var visible_count := 0
	for index in range(rows.size()):
		var accepted := Generator.matches_filter(rows[index],str(weapon_filter.get_selected_metadata()),str(tag_filter.get_selected_metadata()))
		if items[index].visible!=accepted:items[index].visible=accepted
		if accepted:visible_count+=1
		elif items[index].is_selected(0):
			table.deselect_all()
			details.text=""
			clear_pair()
	var state := str(batch.get("status","empty"))
	status.text = UIText.t("fleet.status",{"visible":visible_count,"total":rows.size(),"attempts":batch.get("attempts",0),"ms":"%.1f" % batch.get("elapsed_ms",0),"state":UIText.t("player_loadout.no_legal_loadouts") if state=="no_legal_loadouts" else UIText.t("fleet.state."+state)})
	if not batch.get("unavailable_types",[]).is_empty():
		var types := PackedStringArray()
		for mode in batch.unavailable_types:types.append(UIText.t("player_loadout.type."+str(mode)))
		status.text += UIText.t("player_loadout.unavailable",{"types":", ".join(types)})

func show_selected() -> void:
	clear_pair()
	var item := table.get_selected()
	if item==null:return
	var row: Dictionary = rows[int(item.get_metadata(0))]
	var display := row.duplicate(true)
	display["ship_name"] = UIText.data_text("ship",row.ship,"des")
	display["weapon_names"] = equipment_names(row.equipment.weapons)
	display["defence_names"] = equipment_names(row.equipment.defence)
	display["tag_names"] = tag_names(row.tags)
	display["note_text"] = row.notes.map(func(key):return UIText.t("player_loadout.note."+str(key)))
	details.text = JSON.stringify(display,"  ")

func show_pair() -> void:
	var player_item := table.get_selected()
	var enemy_item: TreeItem = fleet_panel.table.get_selected()
	if player_item==null or enemy_item==null:
		status.text=UIText.t("player_loadout.select_pair")
		return
	selected_pair = generator.pair(fleet_panel.rows[int(enemy_item.get_metadata(0))],rows[int(player_item.get_metadata(0))],int(inputs.seed.value))
	details.text = JSON.stringify(selected_pair,"  ")

func clear_pair() -> void:
	if not selected_pair.is_empty() and is_instance_valid(details):details.text=""
	selected_pair.clear()

func clear_results() -> void:
	clear_pair()
	rows.clear()
	items.clear()
	batch.clear()
	table.clear()
	details.text=""
	apply_filters()
