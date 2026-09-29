extends VBoxContainer
signal result_ready(directory: String)
const Analyzer := preload("res://scripts/fleet_result_analyzer.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
const Retest := preload("res://scripts/fleet_batch_retest.gd")
const EnemyGenerator := preload("res://scripts/enemy_fleet_simulator.gd")
const PlayerGenerator := preload("res://scripts/player_loadout_generator.gd")
const DATASETS := ["level_candidates","enemy_analysis","player_analysis","weapon_analysis","pair_analysis","enemy_tags","player_tags"]
const COLUMNS := ["id","tests","win_rate","avg_battle_time","discrimination","confidence"]
var current_batch: Callable
var running_batch: Callable
var database: ShipDatabase
var display_names := {}
var analyzer: RefCounted
var path_input: LineEdit
var load_button: Button
var latest_button: Button
var pair_button: Button
var dataset: OptionButton
var tag_filter: OptionButton
var weapon_filter: OptionButton
var inputs := {}
var status: Label
var table: Tree
var details: TextEdit
var rows: Array=[]
var items: Array=[]
var allowed_pairs: Array=[]
var sort_column := 1
var descending := true
var cards: VBoxContainer
var technical: VBoxContainer
var view_button: Button
var retest_runner: RefCounted
var retest_source := ""
var retest_button: Button
var retest_stop: Button
var retest_status: Label
var retest_target: SpinBox
var retest_budget: SpinBox
var retest_seed: SpinBox
var retest_plan := {}

func _ready() -> void:
	analyzer=Analyzer.new()
	add_theme_constant_override("separation",8)
	var notice := Label.new()
	notice.text=UIText.t("analysis.notice")
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	var bar := HBoxContainer.new()
	add_child(bar)
	path_input=LineEdit.new()
	path_input.placeholder_text=UIText.t("analysis.path")
	path_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_child(path_input)
	load_button=button(bar,"load",load_results)
	var chooser := FileDialog.new()
	chooser.file_mode=FileDialog.FILE_MODE_OPEN_DIR
	chooser.access=FileDialog.ACCESS_FILESYSTEM
	chooser.title=UIText.t("analysis.choose")
	add_child(chooser)
	button(bar,"choose",func():chooser.popup_centered(Vector2i(900,600)))
	chooser.dir_selected.connect(func(path):path_input.text=path;load_results())
	latest_button=button(bar,"latest",func():
		path_input.text=current_batch.call()
		load_results())
	latest_button.visible=current_batch.is_valid()
	view_button=button(bar,"technical",func():set_technical(not technical.visible))
	var followup := HBoxContainer.new()
	add_child(followup)
	for key in ["target","budget","seed"]:
		var label := Label.new()
		label.text=UIText.t("analysis.retest_"+key)
		followup.add_child(label)
		var spin := SpinBox.new()
		spin.min_value=1
		spin.max_value=2147483647 if key=="seed" else 100000 if key=="budget" else 1000
		spin.value=analyzer.policy.retest.target_tests if key=="target" else analyzer.policy.retest.budget if key=="budget" else analyzer.policy.retest.seed
		spin.custom_minimum_size.x=95
		followup.add_child(spin)
		if key=="target":retest_target=spin
		elif key=="budget":retest_budget=spin
		else:retest_seed=spin
	retest_button=button(followup,"retest_insufficient",func():start_retest(-1))
	retest_stop=button(followup,"retest_stop",stop_retest)
	retest_stop.disabled=true
	retest_status=Label.new()
	retest_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(retest_status)
	cards=VBoxContainer.new()
	cards.set_script(load("res://scripts/fleet_design_cards.gd"))
	cards.display_names=display_names
	cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(cards)
	cards.detail_requested.connect(open_card_details)
	cards.retest_requested.connect(func(row):start_retest(int(row.enemy_index)))
	technical=VBoxContainer.new()
	technical.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(technical)
	var filters := HBoxContainer.new()
	technical.add_child(filters)
	dataset=OptionButton.new()
	for key in DATASETS:dataset.add_item(UIText.t("analysis.dataset."+key))
	filters.add_child(dataset)
	dataset.item_selected.connect(func(_i):allowed_pairs.clear();show_dataset())
	tag_filter=OptionButton.new()
	filters.add_child(tag_filter)
	weapon_filter=OptionButton.new()
	filters.add_child(weapon_filter)
	for option in [tag_filter,weapon_filter]:option.item_selected.connect(func(_i):apply_filters())
	pair_button=button(filters,"pairs",show_pairs)
	button(filters,"all_pairs",func():allowed_pairs.clear();dataset.select(4);show_dataset())
	var numeric := HBoxContainer.new()
	technical.add_child(numeric)
	for key in ["min_tests","min_win","max_win","min_time","max_time","min_discrimination"]:
		var box := VBoxContainer.new()
		numeric.add_child(box)
		var label := Label.new()
		label.text=UIText.t("analysis.filter."+key)
		box.add_child(label)
		var input := SpinBox.new()
		input.custom_minimum_size.x=110
		input.max_value=100 if key in ["min_win","max_win","min_discrimination"] else 1000000
		input.value=100 if key=="max_win" else 1000000 if key=="max_time" else 0
		box.add_child(input)
		inputs[key]=input
		input.value_changed.connect(func(_value):apply_filters())
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	technical.add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	technical.add_child(split)
	table=Tree.new()
	table.hide_root=true
	table.columns=COLUMNS.size()
	table.column_titles_visible=true
	table.select_mode=Tree.SELECT_ROW
	table.custom_minimum_size.x=580
	for i in range(COLUMNS.size()):
		table.set_column_title(i,UIText.t("analysis.column."+COLUMNS[i]))
		table.set_column_custom_minimum_width(i,150 if i==0 else 65)
	split.add_child(table)
	table.column_title_clicked.connect(func(index,_mouse):
		descending=not descending if sort_column==index else true
		sort_column=index
		sort_rows())
	table.item_selected.connect(show_details)
	details=TextEdit.new()
	details.editable=false
	details.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(details)
	set_process(false)
	show_dataset()
	set_technical(false)

func button(parent: Container,key: String,callback: Callable) -> Button:
	var control := Button.new()
	control.text=UIText.t("analysis."+key)
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func load_results() -> bool:
	if retest_runner!=null and retest_runner.busy():retest_status.text=UIText.t("analysis.retest_running");return false
	var directory := path_input.text.strip_edges().replace("\\","/").trim_suffix("/")
	if directory.is_empty():status.text=UIText.t("analysis.invalid_path");set_technical(true);return false
	var running_path: String=str(running_batch.call()) if running_batch.is_valid() else ""
	if not running_path.is_empty() and ProjectSettings.globalize_path(directory).simplify_path()==ProjectSettings.globalize_path(running_path).replace("\\","/").simplify_path():
		status.text=UIText.t("analysis.running")
		set_technical(true)
		return false
	var result: Dictionary=analyzer.analyze(directory)
	cards.set_report(analyzer.report)
	allowed_pairs.clear()
	show_dataset()
	if result.has("error"):
		status.text=UIText.t("analysis.failed",{"reason":result.error})
		set_technical(true)
		refresh_retest_controls()
		return false
	var failure: String=analyzer.export_files(directory)
	status.text=UIText.t("analysis.loaded",{"tests":result.tests,"pairs":result.pair_analysis.size(),"path":directory}) if failure.is_empty() else UIText.t("analysis.failed",{"reason":failure})
	set_technical(not failure.is_empty())
	var saved=Retest.read_json(directory.path_join("summary.json"))
	if saved is Dictionary:
		var first_seed: int=int(saved.get("config",{}).get("seed",analyzer.policy.retest.seed))
		retest_seed.value=maxi(1,(first_seed+int(saved.get("completed_count",0))+1)%2147483647)
	refresh_retest_controls()
	if not failure.is_empty():return false
	result_ready.emit(directory)
	return true

func start_retest(enemy_index: int) -> void:
	if retest_runner!=null and retest_runner.busy():return
	if analyzer.report.is_empty():retest_status.text=UIText.t("analysis.retest_load_first");return
	var directory := path_input.text.strip_edges().replace("\\","/").trim_suffix("/")
	if ProjectSettings.globalize_path(directory).simplify_path()!=ProjectSettings.globalize_path(str(analyzer.report.source)).replace("\\","/").simplify_path():
		retest_status.text=UIText.t("analysis.retest_load_first")
		return
	var running_path: String=str(running_batch.call()) if running_batch.is_valid() else ""
	if not running_path.is_empty():
		retest_status.text=UIText.t("analysis.running")
		return
	var source=Retest.read_json(directory.path_join("inputs.json"))
	if not source is Dictionary or not source.get("enemy_fleets") is Array or not source.get("player_loadouts") is Array:
		retest_status.text=UIText.t("analysis.failed",{"reason":"invalid_batch"})
		return
	if source.get("data_sha256","")!=JSON.stringify(database.data).sha256_text():
		retest_status.text=UIText.t("analysis.retest_stale")
		return
	var target := int(retest_target.value)
	var budget := int(retest_budget.value)
	var candidate_runner := Runner.new(database)
	var max_configurations: int=int(analyzer.policy.retest.max_configurations)
	var max_pairs: int=int(candidate_runner.policy.sampling.max_pairs)
	retest_plan=Retest.plan(analyzer.report,source,target,budget,max_configurations,max_pairs,enemy_index)
	if retest_plan.pairs.is_empty():
		retest_status.text=UIText.t("analysis.retest_none")
		return
	var enemy_validator := EnemyGenerator.new(database)
	var player_validator := PlayerGenerator.new(database)
	var checked_enemies := {}
	var checked_players := {}
	for pair in retest_plan.pairs:
		var ei: int=pair.enemy_index
		var pi: int=pair.player_index
		if not checked_enemies.has(ei):
			var enemy=source.enemy_fleets[ei]
			if not enemy is Dictionary:
				retest_status.text=UIText.t("analysis.retest_stale")
				return
			var replay: Dictionary=enemy_validator.replay(enemy)
			if (replay.has("error") or not PlayerGenerator.same_record(replay,enemy)) and not Runner.valid_enemy_snapshot(enemy,enemy_validator):
				retest_status.text=UIText.t("analysis.retest_stale")
				return
			checked_enemies[ei]=true
		if not checked_players.has(pi):
			if not player_validator.validate_record(source.player_loadouts[pi]):
				retest_status.text=UIText.t("analysis.retest_stale")
				return
			checked_players[pi]=true
	retest_runner=candidate_runner
	if ProjectSettings.has_setting("application/config/battle_frame_budget_usec"):
		retest_runner.policy.frame_budget_usec=clampi(int(ProjectSettings.get_setting("application/config/battle_frame_budget_usec")),1000,50000)
	var request := {"mode":"fast","runs":1,"max_total":int(retest_plan.battles),"max_per_pair":target,"seed":int(retest_seed.value),"explicit_pairs":retest_plan.pairs,"max_seconds":retest_runner.policy.defaults.max_seconds,"retest_saved_inputs":true,"data_sha256":source.data_sha256}
	if ProjectSettings.has_setting("application/config/battle_results_directory"):
		request.directory=ProjectSettings.globalize_path(str(ProjectSettings.get_setting("application/config/battle_results_directory")))
	var message: String=retest_runner.start(source.enemy_fleets,source.player_loadouts,request)
	if not message.is_empty():
		retest_status.text=UIText.t("analysis.failed",{"reason":message})
		retest_runner=null
		return
	retest_source=directory
	refresh_retest_controls()
	set_process(true)
	refresh_retest_status()

func _process(_delta: float) -> void:
	if retest_runner==null:return
	retest_runner.process()
	refresh_retest_status()
	if retest_runner.busy():return
	set_process(false)
	refresh_retest_controls()
	if retest_runner.status=="error" or retest_runner.completed==0:
		retest_status.text=UIText.t("analysis.failed",{"reason":retest_runner.error})
		return
	var combined: Dictionary=Retest.combine(retest_source,retest_runner.directory)
	if combined.has("error"):
		retest_status.text=UIText.t("analysis.failed",{"reason":combined.error})
		return
	path_input.text=combined.directory
	if load_results():
		retest_status.text=UIText.t("analysis.retest_done",{"battles":retest_runner.completed,"pairs":retest_plan.pairs.size(),"skipped":retest_plan.skipped})
	else:
		retest_status.text=status.text

func stop_retest() -> void:
	if retest_runner==null or not retest_runner.busy():return
	retest_runner.stop()
	refresh_retest_status()

func refresh_retest_status() -> void:
	if retest_runner==null:return
	var message := UIText.t("analysis.retest_progress",{"done":retest_runner.completed,"total":retest_runner.total,"pairs":retest_plan.pairs.size(),"skipped":retest_plan.skipped})
	if retest_status.text!=message:retest_status.text=message

func refresh_retest_controls() -> void:
	var busy: bool=retest_runner!=null and retest_runner.busy()
	retest_button.disabled=busy or analyzer.report.is_empty()
	retest_stop.disabled=not busy
	for spin in [retest_target,retest_budget,retest_seed]:spin.editable=not busy

func _exit_tree() -> void:
	if retest_runner!=null:retest_runner.stop()

func set_technical(enabled: bool) -> void:
	technical.visible=enabled
	cards.visible=not enabled
	view_button.text=UIText.t("analysis.design" if enabled else "analysis.technical")

func open_card_details(row: Dictionary) -> void:
	set_technical(true)
	allowed_pairs.clear()
	dataset.select(0)
	show_dataset()
	for item in items:
		if item.get_metadata(0).id==row.id:
			item.select(0)
			table.scroll_to_item(item)
			show_details()
			break

func show_dataset() -> void:
	rows=analyzer.report.get(DATASETS[dataset.selected],[])
	table.clear()
	items.clear()
	details.text=""
	var root := table.create_item()
	var tags: Array=[]
	var weapons: Array=[]
	for row in rows:
		var item := table.create_item(root)
		item.set_metadata(0,row)
		items.append(item)
		var label := str(row.get("weapon",row.id))
		if row.has("enemy_index"):label=UIText.t("analysis.enemy_number",{"number":int(row.enemy_index)+1})
		if DATASETS[dataset.selected]=="pair_analysis":label="%d × %d" % [row.enemy_index+1,row.player_index+1]
		if row.has("scope") and row.scope!="all":label+=" · "+str(row.target)
		item.set_text(0,label)
		item.set_tooltip_text(0,str(row.id))
		item.set_text(1,str(row.tests))
		item.set_text(2,percent(row.win_rate))
		item.set_text(3,"—" if row.avg_battle_time==null else "%.2f s" % row.avg_battle_time)
		item.set_text(4,percent(row.get("discrimination")))
		item.set_text(5,UIText.t("analysis.confidence."+row.confidence))
		for tag in row.tags:
			if not tags.has(tag):tags.append(tag)
		for weapon in row.weapons:
			if not weapons.has(weapon):weapons.append(weapon)
	fill_options(tag_filter,tags,"all_tags")
	fill_options(weapon_filter,weapons,"all_weapons")
	sort_rows()
	apply_filters()

func fill_options(control: OptionButton,values: Array,key: String) -> void:
	control.clear()
	control.add_item(UIText.t("analysis."+key))
	control.set_item_metadata(0,"")
	values.sort()
	for value in values:
		control.add_item(str(value))
		control.set_item_metadata(control.item_count-1,value)

func sort_rows() -> void:
	var key: String=COLUMNS[sort_column]
	items.sort_custom(func(a,b):
		var left: Dictionary=a.get_metadata(0)
		var right: Dictionary=b.get_metadata(0)
		var x=left.get(key)
		var y=right.get(key)
		if x==y:return str(left.id)<str(right.id)
		if x==null:return false
		if y==null:return true
		return x>y if descending else x<y)
	for i in range(items.size()-2,-1,-1):items[i].move_before(items[i+1])

func apply_filters() -> void:
	if not is_instance_valid(table):return
	for item in items:
		var row: Dictionary=item.get_metadata(0)
		var tag: String=str(tag_filter.get_selected_metadata())
		var weapon: String=str(weapon_filter.get_selected_metadata())
		var accepted: bool=row.tests>=inputs.min_tests.value and (tag.is_empty() or row.tags.has(tag)) and (weapon.is_empty() or row.weapons.has(weapon))
		accepted=accepted and (allowed_pairs.is_empty() or allowed_pairs.has(row.id))
		accepted=accepted and (row.win_rate!=null and row.win_rate*100>=inputs.min_win.value and row.win_rate*100<=inputs.max_win.value or row.win_rate==null and inputs.min_win.value==0 and inputs.max_win.value==100)
		accepted=accepted and (row.avg_battle_time!=null and row.avg_battle_time>=inputs.min_time.value and row.avg_battle_time<=inputs.max_time.value or row.avg_battle_time==null and inputs.min_time.value==0 and inputs.max_time.value==1000000)
		if inputs.min_discrimination.value>0:accepted=accepted and row.get("discrimination")!=null and float(row.get("discrimination",0))*100>=inputs.min_discrimination.value
		if item.visible!=accepted:item.visible=accepted
		if not accepted and item.is_selected(0):table.deselect_all();details.text=""

func percent(value: Variant) -> String:return "—" if value==null else "%.1f%%" % (float(value)*100)

func show_details() -> void:
	var item := table.get_selected()
	if item==null:return
	var row: Dictionary=item.get_metadata(0)
	var findings := PackedStringArray()
	for finding in row.findings:findings.append(UIText.t("analysis.finding."+finding))
	var text := UIText.t("analysis.details",{"tests":row.tests,"rate":percent(row.win_rate),"confidence":UIText.t("analysis.confidence."+row.confidence),"findings":" / ".join(findings)})
	if row.has("candidate"):
		text+="\n"+UIText.t("analysis.candidate_details",{"candidate":UIText.t("analysis.candidate_yes" if row.candidate else "analysis.candidate_no"),"difference":UIText.t("analysis.difference."+row.discrimination_label),"focus":", ".join(row.test_focus),"coverage":"%d/%d" % [row.tested_configurations,row.available_configurations]})
		for key in ["strengths","weaknesses"]:
			text+="\n"+UIText.t("analysis."+key)
			for comparison in row[key]:text+="\n%s · %s · n=%d" % [comparison.weapons,percent(comparison.win_rate),comparison.tests]
	details.text=text+"\n\n"+JSON.stringify(row,"  ")

func show_pairs() -> void:
	var item := table.get_selected()
	if item==null:return
	allowed_pairs=item.get_metadata(0).pair_ids.duplicate()
	dataset.select(4)
	show_dataset()
