class_name BalanceAnalyzer
extends RefCounted
## Diagnostic evidence, not a global balance score. All thresholds live here.
const THRESHOLDS := {"weapon_share":0.70,"weak_share":0.03,"minimum_usage":0.10,"ttk_low":0.5,"ttk_wall":8.0,
	"sustained_seconds":120.0,"idle_seconds":300.0,"upgrade_fast":2.0,"surplus_minutes":30.0,"resource_share":0.80,
	"damage_low":0.01,"death_burst":3,"death_window":60.0,"dps_spike":2.0,"dps_flat_gain":0.10,"choice_stages":3,
	"comparison_change":0.30,"share_change_pp":20.0,"strategy_advantage":0.20}
const PRIORITY := {"HIGH":0,"MEDIUM":1,"LOW":2}

static func issue(code: String, severity: String, time: float, stage: int, evidence: Dictionary, start := -1.0) -> Dictionary:
	return {"code":code,"severity":severity,"time":time,"start_time":time if start < 0 else start,"stage":stage,"evidence":evidence}

static func analyze_run(report: Dictionary) -> Dictionary:
	var warnings := []
	var time := float(report.game_seconds)
	for key in report.weapon_damage_share:
		var share := float(report.weapon_damage_share[key])
		var used := float(report.equipment_utilization.get(key,0))
		if share > THRESHOLDS.weapon_share:warnings.append(issue("weapon_monopoly","MEDIUM",time,report.final_stage,{"weapon":key,"share":share,"threshold":THRESHOLDS.weapon_share}))
		if time >= THRESHOLDS.idle_seconds and key in report.get("unlocked",[]):
			if used >= THRESHOLDS.minimum_usage and share < THRESHOLDS.weak_share:warnings.append(issue("weapon_ineffective","MEDIUM",time,report.final_stage,{"weapon":key,"share":share,"utilization":used}))
			elif used < THRESHOLDS.minimum_usage:warnings.append(issue("weapon_untried","LOW",time,report.final_stage,{"weapon":key,"utilization":used}))
	if report.get("normal_ttk") != null and float(report.normal_ttk) < THRESHOLDS.ttk_low:
		warnings.append(issue("enemy_trivial","LOW",time,report.final_stage,{"normal_ttk":report.normal_ttk,"threshold":THRESHOLDS.ttk_low}))
	for system in report.resources.system_share:
		for id in report.resources.system_share[system]:
			var share := float(report.resources.system_share[system][id])
			if share > THRESHOLDS.resource_share and float(report.resources.spending.get(id,0)) > 0:
				warnings.append(issue("spending_concentration","MEDIUM",time,report.final_stage,{"system":system,"resource":id,"share":share,"paid":report.resources.spending[id]}))
	var timeline: Dictionary = report.get("timeline",{})
	var points: Array = timeline.get("samples",[])
	var issues := analyze_timeline(points)
	warnings.append_array(issues)
	if int(timeline.get("dropped_events",0)) > 0:warnings.append(issue("events_truncated","LOW",time,report.final_stage,{"dropped_events":timeline.dropped_events}))
	warnings.sort_custom(func(a,b):return PRIORITY[a.severity] < PRIORITY[b.severity] if a.severity != b.severity else float(a.time) < float(b.time))
	return {"warnings":warnings,"timeline_issues":issues,"thresholds":THRESHOLDS.duplicate()}

static func sustained(tracker: Dictionary, output: Array, code: String, active: bool, point: Dictionary, evidence: Dictionary, severity := "MEDIUM", seconds := 120.0, suffix := "") -> void:
	var key := code+suffix
	if not active:
		tracker.erase(key)
		return
	if not tracker.has(key):tracker[key] = {"start":float(point.game_time)-float(point.window_seconds),"seconds":0.0,"reported":false}
	var state: Dictionary = tracker[key]
	state.seconds += float(point.window_seconds)
	if state.seconds >= seconds and not state.reported:
		var data := evidence.duplicate()
		data.duration = state.seconds
		output.append(issue(code,severity,float(point.game_time),int(point.stage),data,float(state.start)))
		state.reported = true

static func analyze_timeline(points: Array) -> Array:
	var result := []
	var tracker := {}
	var previous := {}
	var growth_anchor := {}
	var choice_anchor := {}
	var flat_reported := false
	for point in points:
		if float(point.window_seconds) <= 0:continue
		var time := float(point.game_time)
		var combat := float(point.combat_seconds)
		var normal_ttk: Variant = point.normal_ttk
		sustained(tracker,result,"ttk_wall",normal_ttk != null and float(normal_ttk) > THRESHOLDS.ttk_wall,point,{"normal_ttk":normal_ttk,"threshold":THRESHOLDS.ttk_wall},"HIGH",THRESHOLDS.sustained_seconds)
		sustained(tracker,result,"defence_low_value",combat > 0 and float(point.player_survivability.received_per_combat_second) < THRESHOLDS.damage_low,point,{"received_per_combat_second":point.player_survivability.received_per_combat_second},"LOW",THRESHOLDS.idle_seconds)
		sustained(tracker,result,"growth_stalled",float(point.upgrade_idle) >= THRESHOLDS.sustained_seconds,point,{"upgrade_idle":point.upgrade_idle},"HIGH",THRESHOLDS.sustained_seconds)
		sustained(tracker,result,"upgrades_too_fast",point.upgrade_interval != null and float(point.upgrade_interval) < THRESHOLDS.upgrade_fast and int(point.upgrades) > 1,point,{"upgrade_interval":point.upgrade_interval},"LOW",THRESHOLDS.sustained_seconds)
		sustained(tracker,result,"growth_vacuum",float(point.growth_idle) >= THRESHOLDS.idle_seconds,point,{"growth_idle":point.growth_idle},"HIGH",float(point.window_seconds))
		for id in point.resource_balance:
			var balance := float(point.resource_balance[id])
			var income := float(point.resource_income.get(id,0))
			# A zero locked resource is not enough evidence of an economic bottleneck.
			var resource_active := income > 0 or float(previous.get("resource_income",{}).get(id,0)) > 0
			if resource_active:tracker["observed/"+id] = true
			sustained(tracker,result,"resource_zero",balance <= 0 and tracker.has("observed/"+id),point,{"resource":id,"balance":balance},"HIGH",THRESHOLDS.sustained_seconds,id)
			sustained(tracker,result,"resource_hoarding",income > 0 and balance > income*THRESHOLDS.surplus_minutes,point,{"resource":id,"balance":balance,"per_minute":income},"MEDIUM",THRESHOLDS.idle_seconds,id)
		if int(point.deaths) >= THRESHOLDS.death_burst and float(point.deaths)/float(point.window_seconds) >= float(THRESHOLDS.death_burst)/THRESHOLDS.death_window:
			result.append(issue("death_burst","HIGH",time,point.stage,{"deaths":point.deaths,"seconds":point.window_seconds},time-float(point.window_seconds)))
		if not previous.is_empty() and float(previous.dps) > 0 and int(point.kills) >= 3 and int(previous.kills) >= 3:
			var ratio := float(point.dps)/float(previous.dps)
			if ratio >= THRESHOLDS.dps_spike:result.append(issue("dps_breakthrough","HIGH",time,point.stage,{"before":previous.dps,"current":point.dps,"ratio":ratio},previous.game_time))
		if float(point.dps) > 0 and combat > 0:
			if growth_anchor.is_empty() or float(point.dps) > float(growth_anchor.dps)*(1.0+THRESHOLDS.dps_flat_gain):
				growth_anchor = point
				flat_reported = false
			elif time-float(growth_anchor.game_time) >= THRESHOLDS.idle_seconds and not flat_reported:
				result.append(issue("dps_stagnation","MEDIUM",time,point.stage,{"before":growth_anchor.dps,"current":point.dps},growth_anchor.game_time))
				flat_reported = true
		if choice_anchor.is_empty() or int(point.choice_count) > int(choice_anchor.choice_count):choice_anchor = point
		elif int(point.highest_stage)-int(choice_anchor.highest_stage) >= THRESHOLDS.choice_stages:
			result.append(issue("few_new_choices","MEDIUM",time,point.stage,{"stages":int(point.highest_stage)-int(choice_anchor.highest_stage),"choice_count":point.choice_count},choice_anchor.game_time))
			choice_anchor = point
		# A participating system that subsequently goes idle gets an onset interval.
		for system in ["upgrade","research","reactor_levels","jewel_combine","jewel_equip"]:
			var count := int(point.system_uses.get(system,0))
			var prior := int(previous.get("system_uses",{}).get(system,0))
			sustained(tracker,result,"system_inactive",count > 0 and count == prior,point,{"system":system,"count":count},"LOW",THRESHOLDS.idle_seconds,system)
		previous = point
	return result

static func comparison_warnings(rows: Array) -> Array:
	var result := []
	for row in rows:
		if row.change == null:continue
		var code := ""
		if row.metric == "dps" and float(row.change) > THRESHOLDS.comparison_change*100:code = "comparison_dps"
		elif row.metric == "upgrade_interval" and float(row.change) > THRESHOLDS.comparison_change*100:code = "comparison_upgrade"
		elif str(row.metric).begins_with("weapon_damage_share/") and float(row.change) > THRESHOLDS.share_change_pp:code = "comparison_weapon"
		if not code.is_empty():result.append(issue(code,"MEDIUM",0,0,row))
	return result
