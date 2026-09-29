extends VBoxContainer
signal batch_started(directory: String)
const Runner := preload("res://scripts/fleet_battle_runner.gd")
var fleet_panel: Window
var runner: RefCounted
var scopes := {}
var inputs := {}
var mode: OptionButton
var start_button: Button
var stop_button: Button
var clear_button: Button
var status: Label
var progress: ProgressBar
var table: Tree
var details: TextEdit
var refresh_time := 0.0
var shown_completed := -1
var sampling_status: Label
var focus_button: Button
var focus_label: Label
var focus_pairs: Array = []

func _ready() -> void:
	runner=Runner.new(fleet_panel.database)
	if ProjectSettings.has_setting("application/config/battle_frame_budget_usec"):
		runner.policy.frame_budget_usec=clampi(int(ProjectSettings.get_setting("application/config/battle_frame_budget_usec")),1000,50000)
	add_theme_constant_override("separation",10)
	var notice := Label.new()
	notice.text=UIText.t("batch.notice")
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	for side in ["enemy","player"]:
		var bar := HBoxContainer.new()
		add_child(bar)
		var label := Label.new()
		label.text=UIText.t("batch."+side)
		bar.add_child(label)
		var choice := OptionButton.new()
		for key in ["all","selected","range"]:choice.add_item(UIText.t("batch.scope."+key))
		bar.add_child(choice)
		var low := SpinBox.new()
		var high := SpinBox.new()
		for spin in [low,high]:
			spin.min_value=1
			spin.max_value=100000
			spin.value=1
			bar.add_child(spin)
			spin.editable=false
		choice.item_selected.connect(func(index):
			low.editable=index==2
			high.editable=index==2)
		scopes[side]={"choice":choice,"low":low,"high":high}
	var options := HBoxContainer.new()
	add_child(options)
	for key in ["runs","max_total","max_per_pair","samples_per_tag","seed","max_seconds"]:
		var box := VBoxContainer.new()
		options.add_child(box)
		var label := Label.new()
		label.text=UIText.t("batch."+key)
		box.add_child(label)
		var spin := SpinBox.new()
		spin.min_value=0 if key=="seed" else 1
		spin.max_value={"runs":runner.policy.max_repeats,"seed":2147483647,"max_seconds":runner.policy.max_seconds,"max_total":runner.policy.max_battles,"max_per_pair":runner.policy.max_repeats,"samples_per_tag":runner.policy.sampling.max_samples_per_tag}[key]
		spin.value=runner.policy.defaults[key]
		box.add_child(spin)
		inputs[key]=spin
	var actions := HBoxContainer.new()
	add_child(actions)
	mode=OptionButton.new()
	mode.add_item("FAST")
	mode.add_item("EXACT")
	actions.add_child(mode)
	start_button=button(actions,"start",start_batch)
	stop_button=button(actions,"stop",stop_batch)
	clear_button=button(actions,"clear",clear_batch)
	focus_button=button(actions,"mark_focus",mark_focus)
	button(actions,"clear_focus",func():focus_pairs.clear();update_focus_label())
	focus_label=Label.new()
	actions.add_child(focus_label)
	update_focus_label()
	sampling_status=Label.new()
	sampling_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(sampling_status)
	progress=ProgressBar.new()
	add_child(progress)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(split)
	table=Tree.new()
	table.hide_root=true
	table.columns=4
	table.column_titles_visible=true
	table.select_mode=Tree.SELECT_ROW
	table.custom_minimum_size.x=500
	for i in range(4):table.set_column_title(i,UIText.t("batch.column."+["pair","result","time","hp"][i]))
	split.add_child(table)
	details=TextEdit.new()
	details.editable=false
	details.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(details)
	table.item_selected.connect(func():
		var item := table.get_selected()
		if item!=null:details.text=JSON.stringify(item.get_metadata(0),"  "))
	visibility_changed.connect(func():
		if is_visible_in_tree():refresh())
	fleet_panel.visibility_changed.connect(func():
		if not fleet_panel.visible:stop_batch())
	set_process(false)
	refresh()

func button(parent: Container,key: String,callback: Callable) -> Button:
	var item := Button.new()
	item.text=UIText.t("batch."+key)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func selection(side: String) -> Array:
	var source = fleet_panel if side=="enemy" else fleet_panel.player_section
	var scope: Dictionary=scopes[side]
	if scope.choice.selected==0:return source.rows
	if scope.choice.selected==1:
		var item: TreeItem=source.table.get_selected()
		return [] if item==null else [source.rows[int(item.get_metadata(0))]]
	var low := int(scope.low.value)-1
	var high := int(scope.high.value)
	if low>=high or high>source.rows.size():return []
	return source.rows.slice(low,high)

func start_batch() -> void:
	var request := {"mode":"fast" if mode.selected==0 else "exact"}
	if ProjectSettings.has_setting("application/config/battle_results_directory"):
		request.directory=ProjectSettings.globalize_path(str(ProjectSettings.get_setting("application/config/battle_results_directory")))
	for key in inputs:request[key]=int(inputs[key].value)
	var enemy_rows := selection("enemy")
	var player_rows := selection("player")
	request.focus_pairs=[]
	for pair in focus_pairs:
		var e := enemy_rows.find(pair.enemy)
		var p := player_rows.find(pair.player)
		if e<0 or p<0:
			status.text=UIText.t("batch.focus_outside")
			return
		request.focus_pairs.append({"enemy_index":e,"player_index":p})
	var message: String=runner.start(enemy_rows,player_rows,request)
	if not message.is_empty():
		status.text=UIText.t("batch.error."+message)
		return
	batch_started.emit(runner.directory)
	table.clear()
	table.create_item()
	details.text=""
	shown_completed=-1
	set_process(true)
	refresh()

func _process(delta: float) -> void:
	runner.process()
	refresh_time+=delta
	if is_visible_in_tree() and (refresh_time>=float(runner.policy.ui_refresh_seconds) or not runner.busy()):
		refresh_time=0
		refresh()
	if not runner.busy():set_process(false)

func refresh() -> void:
	if start_button.disabled!=runner.busy():start_button.disabled=runner.busy()
	if stop_button.disabled==runner.busy():stop_button.disabled=not runner.busy()
	if progress.max_value!=maxi(1,runner.total):progress.max_value=maxi(1,runner.total)
	if progress.value!=runner.completed:progress.value=runner.completed
	var stats: Dictionary=runner.aggregate
	var message := UIText.t("batch.status",{"state":UIText.t("batch.state."+runner.status),"done":runner.completed,"total":runner.total,"valid":stats.battle_count,"rate":"—" if stats.win_rate==null else "%.1f%%" % (100*stats.win_rate),"errors":stats.errors,"timeouts":stats.timeouts,"path":runner.directory})
	if not runner.error.is_empty():message+="\n"+UIText.t("batch.error."+runner.error)
	if status.text!=message:status.text=message
	var sampling: Dictionary=runner.sampling.report() if runner.sampling!=null else {"theoretical_pairs":0,"sampled_pairs":0,"tested_pairs":0,"stable_stopped":0,"similar_skipped":0,"quota_skipped":0}
	sampling.erase("covered_tags")
	sampling.erase("representatives")
	sampling.remaining=maxi(0,runner.total-runner.completed)
	var sampling_text := UIText.t("batch.sampling_status",sampling)
	if sampling_status.text!=sampling_text:sampling_status.text=sampling_text
	if shown_completed==runner.completed:return
	shown_completed=runner.completed
	if table.get_root()==null:table.create_item()
	var last := -1
	var children := table.get_root().get_children()
	if not children.is_empty():last=int(children[-1].get_metadata(0).sequence)
	for row in runner.results:
		var sequence: int=row.sequence
		if sequence<=last:continue
		var item := table.create_item(table.get_root())
		var display: Dictionary=row.duplicate(true)
		display.sequence=sequence
		item.set_metadata(0,display)
		item.set_text(0,"%d × %d · %d" % [row.enemy_index+1,row.player_index+1,row.repeat_index+1])
		item.set_text(1,UIText.t("batch.state."+str(row.status)))
		item.set_text(2,"%.2f s" % row.battle_time)
		item.set_text(3,"—" if row.player_hp_ratio==null else "%.0f%% / %.0f%%" % [100*row.player_hp_ratio,100*row.enemy_hp_ratio])
	while table.get_root().get_child_count()>int(runner.policy.retained_results):table.get_root().get_first_child().free()

func stop_batch() -> void:
	runner.stop()
	set_process(false)
	if is_visible_in_tree():refresh()

func clear_batch() -> void:
	runner.reset()
	set_process(false)
	table.clear()
	details.text=""
	shown_completed=-1
	refresh()

func _exit_tree() -> void:
	if runner!=null:runner.stop()

func mark_focus() -> void:
	var e: TreeItem=fleet_panel.table.get_selected()
	var p: TreeItem=fleet_panel.player_section.table.get_selected()
	if e==null or p==null:
		status.text=UIText.t("player_loadout.select_pair")
		return
	var pair := {"enemy":fleet_panel.rows[int(e.get_metadata(0))].duplicate(true),"player":fleet_panel.player_section.rows[int(p.get_metadata(0))].duplicate(true)}
	if not focus_pairs.has(pair):focus_pairs.append(pair)
	update_focus_label()

func update_focus_label() -> void:
	focus_label.text=UIText.t("batch.focus_count",{"count":focus_pairs.size()})
