extends VBoxContainer
## Visual editor for cyclic placement of previously analyzed enemy fleets.

const Generator := preload("res://scripts/cycle_level_generator.gd")
const LevelXlsx := preload("res://scripts/cycle_level_xlsx.gd")
const DEFAULTS := "res://data/level_generation_config.json"
var database: ShipDatabase
var maker: RefCounted
var source_input: LineEdit
var numeric: Dictionary={}
var patterns: Dictionary={}
var result: Dictionary={}
var status_label: Label
var summary_label: Label
var table: Tree
var export_button: Button
var level_filter: SpinBox
var strength_filter: LineEdit
var weapon_filter: OptionButton
var fleet_filter: LineEdit
var fallback_filter: SpinBox

func _ready() -> void:
	maker=Generator.new(database)
	add_theme_constant_override("separation",6)
	var notice:=Label.new()
	notice.text=UIText.t("cycle_level.notice")
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x=700
	add_child(notice)
	var source_bar:=HBoxContainer.new()
	add_child(source_bar)
	source_input=LineEdit.new()
	source_input.placeholder_text=UIText.t("cycle_level.source")
	source_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	source_input.text=_latest_analysis()
	source_bar.add_child(source_input)
	var open_dialog:=FileDialog.new()
	open_dialog.access=FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.add_filter("*.json","已分析的 generated_levels.json")
	add_child(open_dialog)
	open_dialog.file_selected.connect(func(path):source_input.text=path)
	_button(source_bar,"browse",func():open_dialog.popup_centered(Vector2i(900,600)))
	var defaults=JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS))
	if not defaults is Dictionary:defaults={}
	var numbers:=HFlowContainer.new()
	add_child(numbers)
	for key in ["level_count","battle_points_per_level","small_cycle","large_cycle","strength_tolerance","fleet_reuse_limit","recent_fleet_window","similarity_window","seed"]:
		var group:=VBoxContainer.new()
		group.custom_minimum_size.x=122
		numbers.add_child(group)
		var label:=Label.new()
		label.text=UIText.t("cycle_level."+key)
		group.add_child(label)
		var input:=SpinBox.new()
		input.min_value=0
		input.max_value=2147483647 if key=="seed" else 10000
		input.rounded=true
		input.value=int(defaults.get(key,0))
		group.add_child(input)
		numeric[key]=input
	var pattern_bar:=HFlowContainer.new()
	add_child(pattern_bar)
	for key in ["strength_pattern","weapon_pattern","battle_point_offsets"]:
		var group:=VBoxContainer.new()
		group.custom_minimum_size.x=280 if key!="battle_point_offsets" else 180
		pattern_bar.add_child(group)
		var label:=Label.new()
		label.text=UIText.t("cycle_level."+key)
		group.add_child(label)
		var input:=LineEdit.new()
		input.text=_join_strings(defaults.get(key,[])) if key=="weapon_pattern" else _join_ints(defaults.get(key,[]))
		input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		group.add_child(input)
		patterns[key]=input
	var actions:=HBoxContainer.new()
	add_child(actions)
	_button(actions,"generate",generate_levels)
	export_button=_button(actions,"export",choose_export)
	export_button.disabled=true
	status_label=Label.new()
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x=600
	status_label.text=UIText.t("cycle_level.ready")
	actions.add_child(status_label)
	summary_label=Label.new()
	add_child(summary_label)
	var filters:=HFlowContainer.new()
	add_child(filters)
	var level_group:=_filter_group(filters,"filter_level",135)
	level_filter=SpinBox.new()
	level_filter.min_value=0
	level_filter.max_value=10000
	level_filter.custom_minimum_size.x=135
	level_filter.value_changed.connect(func(_value):refresh_preview())
	level_group.add_child(level_filter)
	var strength_group:=_filter_group(filters,"filter_strength",155)
	strength_filter=LineEdit.new()
	strength_filter.text_changed.connect(func(_value):refresh_preview())
	strength_group.add_child(strength_filter)
	var weapon_group:=_filter_group(filters,"column.weapon",140)
	weapon_filter=OptionButton.new()
	for key in ["all","physical","energy","mixed"]:weapon_filter.add_item(UIText.t("cycle_level."+key))
	weapon_filter.item_selected.connect(func(_index):refresh_preview())
	weapon_group.add_child(weapon_filter)
	var fleet_group:=_filter_group(filters,"filter_fleet",240)
	fleet_filter=LineEdit.new()
	fleet_filter.text_changed.connect(func(_value):refresh_preview())
	fleet_group.add_child(fleet_filter)
	var fallback_group:=_filter_group(filters,"filter_fallback",150)
	fallback_filter=SpinBox.new()
	fallback_filter.min_value=-1
	fallback_filter.max_value=4
	fallback_filter.value=-1
	fallback_filter.value_changed.connect(func(_value):refresh_preview())
	fallback_group.add_child(fallback_filter)
	table=Tree.new()
	table.columns=7
	table.hide_root=true
	table.column_titles_visible=true
	table.size_flags_vertical=Control.SIZE_EXPAND_FILL
	for index in range(7):
		table.set_column_title(index,UIText.t("cycle_level.column."+["level","weapon","strength","point","fleet","group","fallback"][index]))
		table.set_column_expand(index,index==4)
		table.set_column_custom_minimum_width(index,[55,95,75,55,280,90,75][index])
	add_child(table)
	var save_dialog:=FileDialog.new()
	save_dialog.access=FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.xlsx","Excel 工作簿")
	save_dialog.current_dir=_output_directory()
	save_dialog.current_file="level_monGroup_generated.xlsx"
	add_child(save_dialog)
	save_dialog.file_selected.connect(export_excel)
	set_meta("save_dialog",save_dialog)

func _button(parent: Container,key: String,callback: Callable) -> Button:
	var control:=Button.new()
	control.text=UIText.t("cycle_level."+key)
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func _filter_group(parent: Container,key: String,width: float) -> VBoxContainer:
	var group:=VBoxContainer.new()
	group.custom_minimum_size.x=width
	parent.add_child(group)
	var label:=Label.new()
	label.text=UIText.t("cycle_level."+key)
	group.add_child(label)
	return group

func _join_ints(values: Array) -> String:
	var parts:=PackedStringArray()
	for value in values:parts.append(str(int(value)))
	return ",".join(parts)

func _join_strings(values: Array) -> String:
	var parts:=PackedStringArray()
	for value in values:parts.append(str(value))
	return ",".join(parts)

func _latest_analysis() -> String:
	var base: String=ProjectSettings.globalize_path("res://../战斗模拟工具/results")
	var dirs:=DirAccess.get_directories_at(base)
	dirs.sort()
	for index in range(dirs.size()-1,-1,-1):
		var path: String=base.path_join(dirs[index]).path_join("generated_levels/generated_levels.json")
		if FileAccess.file_exists(path):return path
	return ""

func _output_directory() -> String:
	var project: String=ProjectSettings.globalize_path("res://../space-battleship/config_excel")
	if FileAccess.file_exists(project.path_join("level.xlsx")):return project
	return ProjectSettings.globalize_path("res://config_excel")

func _integers(raw: String) -> Dictionary:
	var source: String=raw.strip_edges().replace("，",",").replace(" ","")
	var tokens:=PackedStringArray()
	if not source.contains(",") and source.length()>1 and source.is_valid_int() and not source.begins_with("-"):
		for character in source:tokens.append(character)
	else:tokens=source.split(",")
	var values: Array=[]
	for token in tokens:
		if not token.is_valid_int():return {"error":"周期数值必须为逗号分隔的整数。"}
		values.append(int(token))
	return {"values":values}

func _read_config() -> Dictionary:
	var config: Dictionary={}
	for key in numeric:config[key]=int(numeric[key].value)
	for key in ["strength_pattern","battle_point_offsets"]:
		var parsed:=_integers(patterns[key].text)
		if parsed.has("error"):return parsed
		config[key]=parsed.values
	var weapons: Array=[]
	var aliases:={"P":"physical","E":"energy","M":"mixed"}
	for token in patterns.weapon_pattern.text.replace("，",",").split(","):
		var kind: String=token.strip_edges()
		weapons.append(aliases.get(kind.to_upper(),kind))
	config.weapon_pattern=weapons
	return config

func generate_levels() -> void:
	result={}
	export_button.disabled=true
	summary_label.text=""
	table.clear()
	var path: String=source_input.text.strip_edges()
	if not FileAccess.file_exists(path):
		status_label.text=UIText.t("cycle_level.error",{"reason":"请选择已有 generated_levels.json。"})
		return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		status_label.text=UIText.t("cycle_level.error",{"reason":"分析文件不是有效 JSON。"})
		return
	var config:=_read_config()
	if config.has("error"):
		status_label.text=UIText.t("cycle_level.error",{"reason":str(config.error)})
		return
	var generated: Dictionary=maker.generate(config,parsed)
	if generated.has("error"):
		status_label.text=UIText.t("cycle_level.error",{"reason":str(generated.error)})
		return
	result=generated
	export_button.disabled=false
	level_filter.max_value=int(config.level_count)
	status_label.text=UIText.t("cycle_level.generated")
	var stats: Dictionary=result.statistics
	summary_label.text=UIText.t("cycle_level.stats",{"levels":stats.levels,"points":stats.battle_points,"unique":stats.unique_fleets_used,"exact":"%.1f%%" % (100.0*float(stats.exact_match_rate)),"fallback":stats.fallback_count})
	refresh_preview()

func refresh_preview() -> void:
	if table==null:return
	table.clear()
	var root:=table.create_item()
	if result.is_empty():return
	var weapon_choices: Array=["","physical","energy","mixed"]
	var selected_weapon: String=str(weapon_choices[weapon_filter.selected])
	var selected_level: int=int(level_filter.value)
	var selected_strength: String=strength_filter.text.strip_edges()
	var selected_fleet: String=fleet_filter.text.strip_edges().to_lower()
	var selected_fallback: int=int(fallback_filter.value)
	for stage in result.levels:
		if selected_level>0 and int(stage.level_id)!=selected_level:continue
		if not selected_strength.is_empty() and str(stage.strength_offset)!=selected_strength:continue
		if not selected_weapon.is_empty() and str(stage.weapon_bias)!=selected_weapon:continue
		for point in stage.battle_points:
			if not selected_fleet.is_empty() and not str(point.enemy_fleet_id).to_lower().contains(selected_fleet) and not str(point.mon_group_id).contains(selected_fleet):continue
			if selected_fallback>=0 and int(point.fallback_level)!=selected_fallback:continue
			var item:=table.create_item(root)
			var values: Array=["L%03d" % int(stage.level_id),str(stage.weapon_bias),"+%d" % int(stage.strength_offset),"BP%d" % int(point.battle_point_index),str(point.enemy_fleet_id),str(point.mon_group_id),str(point.fallback_level)]
			for index in range(values.size()):item.set_text(index,values[index])
			item.set_tooltip_text(4,str(point.enemy_fleet_id))

func choose_export() -> void:
	if result.is_empty():return
	var dialog: FileDialog=get_meta("save_dialog")
	dialog.popup_centered(Vector2i(900,600))

func export_excel(path: String) -> void:
	var target: String=path if path.to_lower().ends_with(".xlsx") else path+".xlsx"
	var failure: String=LevelXlsx.export_levels(result.levels,target,database.groups)
	status_label.text=UIText.t("cycle_level.error",{"reason":failure}) if not failure.is_empty() else UIText.t("cycle_level.exported",{"path":target})
