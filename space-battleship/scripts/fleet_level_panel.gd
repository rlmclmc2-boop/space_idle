extends VBoxContainer
const Generator := preload("res://scripts/fleet_level_generator.gd")
const PlayerGenerator := preload("res://scripts/player_loadout_generator.gd")
var database: ShipDatabase
var current_batch: Callable
var current_fleets: Callable
var running_batch: Callable
var generator: RefCounted
var path_input: LineEdit
var limits := {}
var ship_checks := {}
var status_label: Label
var list: ItemList
var details: TextEdit

func _ready() -> void:
	generator=Generator.new(database)
	add_theme_constant_override("separation",8)
	var notice:=Label.new()
	notice.text=UIText.t("auto_level.notice")
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	var bar:=HBoxContainer.new()
	add_child(bar)
	path_input=LineEdit.new()
	path_input.placeholder_text=UIText.t("auto_level.path")
	path_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_child(path_input)
	button(bar,"current",func():path_input.text="";start_generation()).disabled=not current_fleets.is_valid()
	var chooser:=FileDialog.new()
	chooser.file_mode=FileDialog.FILE_MODE_OPEN_DIR
	chooser.access=FileDialog.ACCESS_FILESYSTEM
	add_child(chooser)
	button(bar,"choose",func():chooser.popup_centered(Vector2i(900,600)))
	chooser.dir_selected.connect(func(path):path_input.text=path)
	var ship_bar:=HFlowContainer.new()
	add_child(ship_bar)
	var ships_label:=Label.new()
	ships_label.text=UIText.t("auto_level.ships")
	ship_bar.add_child(ships_label)
	var ship_ids: Array=database.ships.keys()
	ship_ids.sort()
	for ship in ship_ids:
		var check:=CheckBox.new()
		check.text=UIText.data_text("ship",str(ship),"des")
		check.button_pressed=ship==ship_ids[0]
		ship_bar.add_child(check)
		ship_checks[str(ship)]=check
	var controls:=HFlowContainer.new()
	add_child(controls)
	for key in ["max_loadouts","max_level","max_total_battles","base_module_level","cleared_through","seed"]:
		var group:=VBoxContainer.new()
		controls.add_child(group)
		var label:=Label.new()
		label.text=UIText.t("auto_level."+key)
		group.add_child(label)
		var input:=SpinBox.new()
		input.min_value=0 if key in ["seed","max_level","cleared_through"] else 1
		input.max_value=2147483647 if key=="seed" else 100000 if key=="max_total_battles" else database.levels.size() if key=="cleared_through" else int(PlayerGenerator.new(database).policy.max_module_level) if key=="base_module_level" else 1000
		input.value=database.levels.size() if key=="cleared_through" else 1 if key=="base_module_level" else generator.policy[key]
		input.custom_minimum_size.x=160
		group.add_child(input)
		limits[key]=input
	button(controls,"start",start_generation)
	button(controls,"stop",stop_generation)
	button(controls,"clear",clear_results)
	status_label=Label.new()
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	var split:=HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(split)
	list=ItemList.new()
	list.custom_minimum_size.x=420
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(list)
	list.item_selected.connect(show_selected)
	details=TextEdit.new()
	details.editable=false
	details.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(details)
	clear_results()

func button(parent: Container,key: String,callback: Callable) -> Button:
	var control:=Button.new()
	control.text=UIText.t("auto_level."+key)
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func start_generation() -> void:
	if generator.busy():return
	var directory:=path_input.text.strip_edges().replace("\\","/").trim_suffix("/")
	if directory.is_empty() and (not current_fleets.is_valid() or current_fleets.call().is_empty()):status_label.text=UIText.t("auto_level.invalid_path");return
	if not directory.is_empty() and running_batch.is_valid() and running_batch.call()==directory:status_label.text=UIText.t("auto_level.running_batch");return
	var options:={}
	for key in limits:options[key]=int(limits[key].value)
	options.available_ships=[]
	for key in ship_checks:
		if ship_checks[key].button_pressed:options.available_ships.append(key)
	if directory.is_empty() and options.available_ships.is_empty():status_label.text=UIText.t("auto_level.select_ship");return
	if not directory.is_empty():
		options.erase("available_ships")
		options.erase("base_module_level")
		options.erase("cleared_through")
	var failure: String=generator.start(directory,options) if not directory.is_empty() else generator.start_fleets(current_fleets.call(),options)
	if not failure.is_empty():
		var key: String="auto_level.error."+failure
		status_label.text=UIText.t("auto_level.failed",{"reason":UIText.t(key) if UIText.entries.has(key) else failure})
		return
	refresh()
	set_process(generator.busy())

func _process(_delta: float) -> void:
	if not generator.busy():set_process(false);return
	generator.process(int(ProjectSettings.get_setting("application/config/battle_frame_budget_usec",8000)))
	if not generator.busy():set_process(false)
	refresh()

func stop_generation() -> void:
	if generator.busy():generator.stop()
	set_process(false)
	refresh()

func clear_results() -> void:
	if generator!=null and generator.busy():generator.stop()
	set_process(false)
	if list!=null:list.clear()
	if details!=null:details.text=""
	if status_label!=null:status_label.text=UIText.t("auto_level.ready")

func refresh() -> void:
	var result_path: String=generator.output_directory.path_join("monGroup.xlsx") if generator.status=="completed" else generator.output_directory
	var failure_key: String="auto_level.error."+str(generator.error)
	var failure_text: String=UIText.t(failure_key) if UIText.entries.has(failure_key) else str(generator.error)
	status_label.text=UIText.t("auto_level.progress",{"screened":generator.candidates.size(),"done":generator.evaluated.size(),"battles":generator.spent,"budget":generator.policy.max_total_battles,"levels":generator.levels.size(),"path":result_path}) if not generator.status=="error" else UIText.t("auto_level.failed",{"reason":failure_text})
	if generator.busy():return
	list.clear()
	for stage in generator.levels:
		var level_text:="+"+str(stage.recommended_level) if stage.recommended_level!=null else "未达标"
		var spread_text:=str(stage.required_level_spread) if stage.required_level_spread!=null else "—"
		if stage.spread_is_lower_bound:spread_text="至少 "+spread_text
		list.add_item(UIText.t("auto_level.item",{"name":stage.name,"type":level_text,"rate":spread_text}))
	if not generator.levels.is_empty():list.select(0);show_selected(0)

func show_selected(index: int) -> void:
	if index<0 or index>=generator.levels.size():return
	var stage: Dictionary=generator.levels[index]
	var waves:=PackedStringArray()
	for wave_index in range(stage.encounters.size()):
		var wave: Dictionary=stage.encounters[wave_index]
		waves.append(UIText.t("auto_level.wave_final",{"name":wave.name}) if wave_index==stage.encounters.size()-1 else UIText.t("auto_level.wave",{"number":wave_index+1,"name":wave.name}))
	var composition:=PackedStringArray()
	for id in stage.composition:composition.append(UIText.t("design.enemy_count",{"name":str(generator.mon_names.get(str(id),id)),"count":stage.composition[id]}))
	var tags:=PackedStringArray()
	for tag in stage.enemy_tags:
		var key: String="fleet.tag."+str(tag)
		tags.append(UIText.t(key) if UIText.entries.has(key) else str(tag))
	var lines:=PackedStringArray()
	for row in stage.loadout_results:
		var keys:=PackedStringArray()
		for key in row.weapons:keys.append(str(generator.inputs.get("display_names",{}).get("equipment",{}).get(str(key),key)))
		var level_text:=str(row.required_level) if row.required_level!=null else "未达标"
		lines.append(UIText.t("auto_level.loadout_result",{"weapons":" + ".join(keys),"level":level_text,"rate":"%.0f%%" % (100*float(row.winrate_at_level)) if row.winrate_at_level!=null else "—","tests":row.sample_count,"time":"%.1f" % float(row.battle_time) if row.battle_time!=null else "—"}))
	var spread_text:=str(stage.required_level_spread) if stage.required_level_spread!=null else "—"
	if stage.spread_is_lower_bound:spread_text="至少 "+spread_text
	var difference_text:=UIText.t("auto_level.unknown_difference") if stage.required_level_spread==null else UIText.t("auto_level.no_difference") if stage.no_difference else UIText.t("auto_level.difference",{"spread":spread_text})
	details.text=UIText.t("auto_level.card",{"name":stage.name,"waves":"\n".join(waves),"composition":"\n".join(composition),"tags":" / ".join(tags),"powers":"\n".join(lines),"recommended_power":"+"+str(stage.recommended_level) if stage.recommended_level!=null else "未达标","recommended":configurations(stage.best_loadouts),"weak":configurations(stage.worst_loadouts),"reason":difference_text})

func configurations(rows: Array) -> String:
	var names: Dictionary=generator.inputs.get("display_names",{}).get("equipment",{})
	var lines:=PackedStringArray()
	for row in rows:
		var weapons:=PackedStringArray()
		for key in row.weapons:weapons.append(str(names.get(str(key),key)))
		lines.append("%s · %s · +%s" % [UIText.data_text("ship",str(row.ship),"des")," + ".join(weapons),str(row.required_level) if row.required_level!=null else "未达标"])
	return "\n".join(lines) if not lines.is_empty() else UIText.t("design.no_ranking")
