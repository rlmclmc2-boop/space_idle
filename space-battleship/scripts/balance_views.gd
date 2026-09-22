extends RefCounted
## Tables retain their items/cells. Owners invalidate only tabs whose data changed.
const LIMIT := 2000
var writes := 0
var tables := {}
const ISSUE_TEXT := {
	"weapon_monopoly":"lab.v2.issue.weapon_monopoly","weapon_ineffective":"lab.v2.issue.weapon_ineffective","weapon_untried":"lab.v2.issue.weapon_untried",
	"enemy_trivial":"lab.v2.issue.enemy_trivial","ttk_wall":"lab.v2.issue.ttk_wall","defence_low_value":"lab.v2.issue.defence_low_value",
	"growth_stalled":"lab.v2.issue.growth_stalled","upgrades_too_fast":"lab.v2.issue.upgrades_too_fast","growth_vacuum":"lab.v2.issue.growth_vacuum",
	"resource_zero":"lab.v2.issue.resource_zero","resource_hoarding":"lab.v2.issue.resource_hoarding","death_burst":"lab.v2.issue.death_burst",
	"dps_breakthrough":"lab.v2.issue.dps_breakthrough","dps_stagnation":"lab.v2.issue.dps_stagnation","few_new_choices":"lab.v2.issue.few_new_choices",
	"system_inactive":"lab.v2.issue.system_inactive","spending_concentration":"lab.v2.issue.spending_concentration","events_truncated":"lab.v2.issue.events_truncated",
	"comparison_dps":"lab.v2.issue.comparison_dps","comparison_upgrade":"lab.v2.issue.comparison_upgrade","comparison_weapon":"lab.v2.issue.comparison_weapon"}

func table(parent: Node, name: String, columns: Array) -> Tree:
	var tree := Tree.new()
	tree.columns = columns.size()
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 140
	for index in columns.size():
		tree.set_column_title(index,UIText.t(columns[index]))
		tree.set_column_custom_minimum_width(index,95 if index > 0 else 130)
	parent.add_child(tree)
	tree.create_item()
	tables[name] = tree
	return tree

func fill(name: String, rows: Array) -> void:
	var tree: Tree = tables[name]
	var root := tree.get_root()
	var item := root.get_first_child()
	for row in rows.slice(0,LIMIT):
		if item == null:item = tree.create_item(root)
		for column in tree.columns:
			var text := value(row[column]) if column < row.size() else ""
			if item.get_text(column) != text:
				item.set_text(column,text)
				item.set_tooltip_text(column,text)
				writes += 1
		item = item.get_next()
	while item != null:
		var next := item.get_next()
		item.free()
		item = next

static func value(data: Variant) -> String:
	if data == null:return "—"
	if data is float:return "%.3f" % data
	if data is Dictionary or data is Array:return JSON.stringify(data)
	return str(data)

static func clock_text(seconds: float) -> String:
	return "%02d:%02d:%02d" % [int(seconds)/3600,(int(seconds)/60)%60,int(seconds)%60]

func quick(report: Dictionary) -> void:
	var rows := []
	for point in report.scan:
		var summary: Dictionary = point.summary
		rows.append([point.strategy,point.parameter_id,point.parameter,summary.final_stage.mean,summary.dps.mean,summary.deaths.mean,summary.resource_surplus.mean,summary.ttk.mean,summary.decision_interval.mean])
	fill("strategies",rows)

func sweep(report: Dictionary) -> void:
	var rows := []
	for point in report.scan:
		var summary: Dictionary = point.summary
		rows.append([point.parameter_id,point.parameter,point.strategy,summary.final_stage.mean,summary.ttk.mean,summary.boss_ttk.mean,summary.first_death_seconds.mean,summary.upgrade_interval.mean,summary.resource_surplus.mean,summary.deaths.mean,summary.dps_growth.mean])
	fill("sweep",rows)
	rows = []
	for entry in report.get("sensitivity",[]):rows.append([entry.metric,entry.parameter_id,entry.strategy,entry.from,entry.to,entry.before,entry.after,entry.elasticity,entry.slope])
	fill("sensitivity",rows)

func comparison(report: Dictionary) -> void:
	var rows := []
	for row in report.get("comparison",{}).get("rows",[]):rows.append([row.metric,row.baseline,row.current,(value(row.change)+row.unit) if row.change != null else "—",row.absolute])
	fill("comparison",rows)

func timeline(report: Dictionary, index: int) -> void:
	var rows := []
	var events := []
	if index >= 0 and index < report.runs.size():
		var run: Dictionary = report.runs[index]
		for point in run.timeline.samples:
			rows.append([clock_text(point.game_time),point.stage,point.dps,point.enemy_hp,point.normal_ttk,point.resource_income,point.resource_balance,point.upgrade_interval,point.player_survivability,point.weapon_damage_share,point.growth_idle,point.marks])
		for event in run.timeline.events:events.append([clock_text(event.time),event.stage,event.kind,event.count,event.data])
	fill("timeline",rows)
	fill("events",events)

func diagnosis(report: Dictionary, index: int) -> void:
	var rows := []
	if index >= 0 and index < report.runs.size():
		for warning in report.runs[index].get("analysis",{}).get("warnings",[]):
			rows.append([warning.severity,clock_text(warning.start_time),clock_text(warning.time),warning.stage,UIText.t(ISSUE_TEXT[warning.code]),warning.evidence])
	for warning in report.get("comparison",{}).get("warnings",[]):rows.append([warning.severity,"—","—","—",UIText.t(ISSUE_TEXT[warning.code]),warning.evidence])
	for warning in report.get("strategy_warnings",[]):rows.append([warning.severity,"—","—","—",UIText.t("lab.v2.strategy_dominance"),warning])
	fill("diagnosis",rows)
