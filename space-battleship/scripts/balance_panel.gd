extends Window
const Runner := preload("res://scripts/balance_runner.gd")
const Scan := preload("res://scripts/balance_scan.gd")
const Report := preload("res://scripts/balance_report.gd")
const Views := preload("res://scripts/balance_views.gd")
const STATUS_TEXT := {"idle":"lab.status.idle","running":"lab.status.running","paused":"lab.status.paused","completed":"lab.status.completed","stopped":"lab.status.stopped"}
const WARNING_TEXT := {"weapon_dominance":"lab.warning.weapon_dominance","equipment_unused":"lab.warning.equipment_unused","system_unused":"lab.warning.system_unused","ttk_outside_range":"lab.warning.ttk_outside_range","upgrade_gap":"lab.warning.upgrade_gap","unaffordable":"lab.warning.unaffordable","resource_surplus":"lab.warning.resource_surplus"}
var runner = Runner.new()
var speed_select: OptionButton
var mode_select: OptionButton
var duration_select: OptionButton
var duration: SpinBox
var repeats: SpinBox
var seed_input: LineEdit
var scan_select: OptionButton
var scan_start: SpinBox
var scan_end: SpinBox
var scan_step: SpinBox
var directory: LineEdit
var progress: Label
var output: TextEdit
var pause_button: Button
var start_button: Button
var export_button: Button
var fields: Array[Control] = []
var paths := []
var baseline := {}
var refresh_elapsed := 0.0
var rendered_status := ""
var exports := {}
var tabs: TabContainer
var pages: Array[VBoxContainer] = []
var strategy_select: OptionButton
var sample_interval: SpinBox
var run_select: SpinBox
var baseline_input: LineEdit
var comparison_status: Label
var timeline_status: Label
var queue_status: Label
var sweep_queue := []
var views = Views.new()
var dirty_tabs := [true,true,true,true,true]

func _ready() -> void:
	title = UIText.t("lab.title")
	size = Vector2i(1200,900)
	min_size = Vector2i(1000,780)
	close_requested.connect(close_lab)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var hint := Label.new()
	hint.text = UIText.t("lab.hint")
	root.add_child(hint)
	var row := HBoxContainer.new()
	root.add_child(row)
	label(row,"lab.speed")
	speed_select = OptionButton.new()
	for speed in [1,10,100,1000]:speed_select.add_item(str(speed)+"x",speed)
	speed_select.select(2)
	row.add_child(speed_select)
	fields.append(speed_select)
	label(row,"lab.duration")
	duration_select = OptionButton.new()
	for key in ["lab.ten_minutes","lab.one_hour","lab.ten_hours","lab.custom"]:duration_select.add_item(UIText.t(key))
	duration_select.select(1)
	row.add_child(duration_select)
	fields.append(duration_select)
	duration = number(row,3600,0.1,31536000,0.1)
	duration.editable = false
	duration_select.item_selected.connect(func(index):
		duration.editable = index == 3
		if index < 3:duration.value = [600,3600,36000][index])
	label(row,"lab.runs")
	repeats = number(row,1,1,100,1)
	label(row,"lab.seed")
	seed_input = LineEdit.new()
	seed_input.text = "12345"
	seed_input.custom_minimum_size.x = 110
	row.add_child(seed_input)
	fields.append(seed_input)
	var strategies := HBoxContainer.new()
	root.add_child(strategies)
	label(strategies,"lab.v2.strategy")
	strategy_select = OptionButton.new()
	for name in Scan.STRATEGIES:strategy_select.add_item(name)
	strategy_select.add_item(UIText.t("lab.v2.all_strategies"))
	strategies.add_child(strategy_select)
	fields.append(strategy_select)
	mode_select = OptionButton.new()
	for key in ["lab.mode.exact","lab.mode.fast"]:mode_select.add_item(UIText.t(key))
	strategies.add_child(mode_select)
	fields.append(mode_select)
	label(strategies,"lab.v2.sample_interval")
	sample_interval = number(strategies,30,1,3600,1)
	label(strategies,"lab.v2.result_run")
	run_select = number(strategies,1,1,1,1)
	run_select.value_changed.connect(func(_value):dirty_tabs[3] = true; dirty_tabs[4] = true; refresh_active_tab())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	for key in ["lab.v2.quick","lab.v2.sweep","lab.v2.compare","lab.v2.timeline","lab.v2.diagnosis"]:
		var page := VBoxContainer.new()
		page.name = UIText.t(key)
		tabs.add_child(page)
		pages.append(page)
	tabs.tab_changed.connect(func(_index):refresh_active_tab())
	var scan_row := HBoxContainer.new()
	pages[1].add_child(scan_row)
	label(scan_row,"lab.parameter")
	scan_select = OptionButton.new()
	scan_select.custom_minimum_size.x = 410
	scan_select.add_item(UIText.t("lab.no_scan"))
	baseline = ShipDatabase.new().data
	paths = Scan.parameters(baseline)
	for path in paths:
		var parts := PackedStringArray()
		for part in path:parts.append(str(part))
		scan_select.add_item("/".join(parts))
	scan_row.add_child(scan_select)
	fields.append(scan_select)
	var bounds := HBoxContainer.new()
	pages[1].add_child(bounds)
	label(bounds,"lab.from")
	scan_start = number(bounds,1,0,1e20,0.000001)
	label(bounds,"lab.to")
	scan_end = number(bounds,1,0,1e20,0.000001)
	label(bounds,"lab.step")
	scan_step = number(bounds,0.02,0.000001,1e20,0.000001)
	fields.append(button(bounds,"lab.v2.add_sweep",add_sweep))
	fields.append(button(bounds,"lab.v2.clear_sweeps",func():sweep_queue.clear(); update_queue()))
	queue_status = Label.new()
	queue_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages[1].add_child(queue_status)
	update_queue()
	scan_select.item_selected.connect(func(index):
		if index > 0:
			var value := Scan.read(baseline,paths[index-1])
			scan_start.value = maxf(value,0.000001)
			scan_end.value = maxf(value,0.000001))
	var directory_row := HBoxContainer.new()
	root.add_child(directory_row)
	label(directory_row,"lab.directory")
	directory = LineEdit.new()
	directory.text = ProjectSettings.globalize_path("res://../test/work/balance_lab")
	directory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory_row.add_child(directory)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	start_button = button(buttons,"lab.start",start_simulation)
	pause_button = button(buttons,"lab.pause",func():runner.pause(); refresh_status())
	button(buttons,"lab.stop",func():runner.stop(); refresh_status())
	button(buttons,"lab.reset",func():runner.reset(); exports.clear(); output.text = ""; dirty_tabs.fill(true); refresh_status(); refresh_active_tab())
	export_button = button(buttons,"lab.export",save_report)
	progress = Label.new()
	root.add_child(progress)
	root.move_child(tabs,root.get_child_count()-1)
	views.table(pages[0],"strategies",["lab.v2.strategy","lab.parameter","lab.v2.value","lab.v2.stage","lab.v2.dps","lab.v2.deaths","lab.v2.balance","lab.v2.ttk","lab.v2.decision_interval"])
	output = TextEdit.new()
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.add_theme_color_override("font_readonly_color",Color(0.88,0.92,0.98))
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size.y = 270
	pages[0].add_child(output)
	build_result_tabs()
	refresh_status()
	refresh_active_tab()

func label(parent: Node, key: String) -> void:
	var control := Label.new()
	control.text = UIText.t(key)
	parent.add_child(control)

func number(parent: Node, value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = value
	control.custom_minimum_size.x = 125
	parent.add_child(control)
	fields.append(control)
	return control

func button(parent: Node, key: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = UIText.t(key)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func start_simulation() -> void:
	if not seed_input.text.is_valid_int():
		output.text = UIText.t("lab.error",{"error":"invalid_seed"})
		return
	var selected_strategies: Array = Scan.STRATEGIES.duplicate() if strategy_select.selected == Scan.STRATEGIES.size() else [Scan.STRATEGIES[strategy_select.selected]]
	var request := {"speed":speed_select.get_selected_id(),"duration":duration.value,"runs":int(repeats.value),"seed":int(seed_input.text),"strategies":selected_strategies,"sample_interval":sample_interval.value}
	request.simulation_mode = "fast" if mode_select.selected == 1 else "exact"
	if tabs.current_tab == 1:
		if not sweep_queue.is_empty():request.sweeps = sweep_queue.duplicate(true)
		elif scan_select.selected > 0:request.scan = selected_sweep()
		else:
			output.text = UIText.t("lab.error",{"error":"invalid_parameter"})
			tabs.current_tab = 0
			return
	request.performance_directory = directory.text
	var error: String = runner.start(request)
	if not error.is_empty():output.text = UIText.t("lab.error",{"error":error})
	else:
		exports.clear()
		output.text = ""
		dirty_tabs.fill(true)
	refresh_status()
	refresh_active_tab()

func _process(delta: float) -> void:
	if not visible:return
	runner.process(delta)
	refresh_elapsed += delta
	if refresh_elapsed >= 0.25 or rendered_status != runner.status:
		refresh_elapsed = 0
		refresh_status()

func close_lab() -> void:
	if runner.status == "running":runner.pause()
	set_process(false)
	hide()

func refresh_status() -> void:
	var busy: bool = runner.status in ["running","paused"]
	if rendered_status != runner.status:
		for field in fields:
			if field is OptionButton:field.disabled = busy
			elif field is SpinBox:field.editable = not busy
			elif field is LineEdit:field.editable = not busy
			elif field is Button:field.disabled = busy
		duration.editable = not busy and duration_select.selected == 3
		start_button.disabled = busy
		pause_button.disabled = not busy
		pause_button.text = UIText.t("lab.resume" if runner.status == "paused" else "lab.pause")
		export_button.disabled = runner.completed.is_empty()
		if runner.status in ["completed","stopped"]:
			run_select.max_value = maxi(1,runner.reports.size())
			dirty_tabs.fill(true)
			output.text = concise_report()
			save_report()
		rendered_status = runner.status
		refresh_active_tab()
	var elapsed: float = runner.metrics.time if runner.metrics != null else 0.0
	var stage: int = runner.game.stage if runner.game != null else 0
	var text := UIText.t("lab.progress",{"status":UIText.t(STATUS_TEXT[runner.status]),"run":str(mini(runner.job_index+1,runner.jobs.size())),"total":str(runner.jobs.size()),"seconds":"%.1f" % elapsed,"stage":str(stage)})
	text += UIText.t("lab.effective_speed",{"speed":"%.1f" % (runner.total_game_seconds/maxf(runner.wall_seconds,0.000001))})
	if progress.text != text:progress.text = text

func concise_report() -> String:
	var summary: Dictionary = runner.completed.summary
	var lines := PackedStringArray([UIText.t("lab.v2.summary",{"stage":Views.value(summary.final_stage.mean),"ttk":Views.value(summary.ttk.mean),"boss":Views.value(summary.boss_ttk.mean),"upgrade":Views.value(summary.upgrade_interval.mean),"decision":Views.value(summary.decision_interval.mean),"gap":Views.value(summary.longest_growth_gap.mean),"deaths":Views.value(summary.deaths.mean),"balance":Views.value(summary.resource_surplus.mean)})])
	if not runner.reports.is_empty():
		var run: Dictionary = runner.reports[0]
		lines.append(UIText.t("lab.v2.build",{"weapons":JSON.stringify(run.weapon_damage_share),"defence":JSON.stringify({"shield":run.defence.shield_absorbed,"health":run.defence.health_lost}),"resources":JSON.stringify(run.resources.system_share)}))
	lines.append(UIText.t("lab.report_header"))
	for point in runner.completed.scan:
		var point_summary: Dictionary = point.summary
		var values := PackedStringArray([UIText.t("lab.no_scan") if point.parameter == null else str(point.parameter)])
		for key in ["final_stage","ttk","first_death_seconds","upgrade_interval","resource_surplus"]:
			var value: Variant = point_summary[key].mean
			values.append("—" if value == null else "%.3f" % float(value))
		lines.append(" | ".join(values))
	for index in mini(runner.reports.size(),20):
		var report: Dictionary = runner.reports[index]
		lines.append(UIText.t("lab.run_summary",{"run":str(index+1),"seed":str(report.seed),"dps":"%.3f" % report.dps,"deaths":str(report.defence.deaths),"upgrades":str(report.upgrades),"warnings":str(report.anomalies.size())}))
		for anomaly in report.anomalies:
			var values := {}
			if anomaly.has("key"):values.key = str(anomaly.key)
			if anomaly.has("value"):values.value = "%.3f" % float(anomaly.value)
			lines.append("  "+UIText.t(WARNING_TEXT[anomaly.code],values))
	if runner.reports.size() > 20:lines.append(UIText.t("lab.more_runs"))
	return "\n".join(lines)

func save_report() -> void:
	if runner.completed.is_empty():return
	exports = Report.save(runner.completed,directory.text)
	if exports.has("error"):output.text += "\n"+UIText.t("lab.error",{"error":str(exports.error)})
	else:output.text += "\n"+UIText.t("lab.saved",{"path":str(exports.json)})

func selected_sweep() -> Dictionary:
	return {"path":paths[scan_select.selected-1],"start":scan_start.value,"end":scan_end.value,"step":scan_step.value}

func add_sweep() -> void:
	if scan_select.selected <= 0:return
	var sweep := selected_sweep()
	for index in sweep_queue.size():
		if sweep_queue[index].path == sweep.path:
			sweep_queue[index] = sweep
			update_queue()
			return
	sweep_queue.append(sweep)
	update_queue()

func update_queue() -> void:
	var descriptions := PackedStringArray()
	for sweep in sweep_queue:descriptions.append("%s [%s, %s, %s]" % [Scan.identifier(sweep.path),sweep.start,sweep.end,sweep.step])
	queue_status.text = UIText.t("lab.v2.queue",{"count":str(sweep_queue.size()),"parameters":"; ".join(descriptions)})

func build_result_tabs() -> void:
	views.table(pages[1],"sweep",["lab.parameter","lab.v2.value","lab.v2.strategy","lab.v2.stage","lab.v2.ttk","lab.v2.boss_ttk","lab.v2.first_death","lab.v2.upgrade_interval","lab.v2.balance","lab.v2.deaths","lab.v2.dps_growth"])
	label(pages[1],"lab.v2.sensitivity_hint")
	views.table(pages[1],"sensitivity",["lab.v2.metric","lab.parameter","lab.v2.strategy","lab.from","lab.to","lab.v2.before","lab.v2.after","lab.v2.elasticity","lab.v2.slope"])
	var baseline_row := HBoxContainer.new()
	pages[2].add_child(baseline_row)
	baseline_input = LineEdit.new()
	baseline_input.placeholder_text = UIText.t("lab.v2.baseline_path")
	baseline_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baseline_row.add_child(baseline_input)
	button(baseline_row,"lab.v2.load_baseline",load_selected_baseline)
	button(baseline_row,"lab.v2.save_baseline",save_current_baseline)
	comparison_status = Label.new()
	comparison_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages[2].add_child(comparison_status)
	views.table(pages[2],"comparison",["lab.v2.metric","lab.v2.baseline","lab.v2.current","lab.v2.change","lab.v2.absolute"])
	label(pages[2],"lab.v2.comparison_hint")
	timeline_status = Label.new()
	timeline_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages[3].add_child(timeline_status)
	views.table(pages[3],"timeline",["lab.v2.time","lab.v2.stage","lab.v2.dps","lab.v2.enemy_hp","lab.v2.normal_ttk","lab.v2.income","lab.v2.balance","lab.v2.upgrade_interval","lab.v2.survivability","lab.v2.weapon_share","lab.v2.growth_gap","lab.v2.events"])
	views.table(pages[3],"events",["lab.v2.time","lab.v2.stage","lab.v2.events","lab.runs","lab.v2.evidence"])
	label(pages[4],"lab.v2.diagnosis_hint")
	views.table(pages[4],"diagnosis",["lab.v2.severity","lab.v2.onset","lab.v2.detected","lab.v2.stage","lab.v2.issue","lab.v2.evidence"])
	for page in pages:label(page,"lab.v2.table_limit")

func refresh_active_tab() -> void:
	if tabs == null or comparison_status == null:return
	var index := tabs.current_tab
	if not dirty_tabs[index]:return
	dirty_tabs[index] = false
	var report: Dictionary = runner.completed
	if report.is_empty():
		var names: Array = [["strategies"],["sweep","sensitivity"],["comparison"],["timeline","events"],["diagnosis"]][index]
		for name in names:views.fill(name,[])
		if index == 2:comparison_status.text = UIText.t("lab.v2.no_comparison")
		if index == 3:timeline_status.text = UIText.t("lab.v2.no_results")
		return
	match index:
		0:views.quick(report)
		1:views.sweep(report)
		2:
			views.comparison(report)
			var comparison: Dictionary = report.get("comparison",{})
			comparison_status.text = UIText.t("lab.v2.comparable") if comparison.get("compatible",false) else UIText.t("lab.v2.incomparable",{"reasons":str(comparison.get("reasons",[]))})
		3:
			views.timeline(report,int(run_select.value)-1)
			var run: Dictionary = report.runs[int(run_select.value)-1]
			timeline_status.text = UIText.t("lab.v2.timeline_context",{"strategy":str(run.strategy),"seed":str(run.seed),"interval":Views.value(run.timeline.interval_seconds),"samples":str(run.timeline.samples.size()),"dropped":str(run.timeline.dropped_events)})
		4:views.diagnosis(report,int(run_select.value)-1)

func load_selected_baseline() -> void:
	var error: String = runner.load_baseline(baseline_input.text)
	if not error.is_empty():comparison_status.text = UIText.t("lab.error",{"error":error}); return
	dirty_tabs[2] = true
	dirty_tabs[4] = true
	refresh_active_tab()
	if runner.completed.is_empty():comparison_status.text = UIText.t("lab.v2.baseline_loaded")

func save_current_baseline() -> void:
	var path := directory.text.path_join("baseline_%s_%d.json" % [Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_usec()])
	var error: String = runner.save_baseline(path)
	if not error.is_empty():comparison_status.text = UIText.t("lab.error",{"error":error}); return
	baseline_input.text = path
	dirty_tabs[2] = true
	dirty_tabs[4] = true
	refresh_active_tab()
