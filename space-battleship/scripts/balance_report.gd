extends RefCounted
const Analyzer := preload("res://scripts/balance_analyzer.gd")
const FIELDS := ["final_stage","dps","ttk","boss_ttk","first_death_seconds","upgrade_interval","resource_surplus","deaths","dps_growth","decision_interval","longest_growth_gap","longest_decision_gap"]

static func row(report: Dictionary) -> Dictionary:
	var result := {}
	for key in ["final_stage","dps","ttk","boss_ttk","upgrade_interval"]:result[key] = report[key]
	result.first_death_seconds = report.defence.first_death.time if report.defence.first_death != null else null
	# This total is a convenient scan indicator, not an exchange-rate valuation.
	result.resource_surplus = 0.0
	for value in report.resources.balance.values():result.resource_surplus += float(value)
	result.deaths = report.defence.deaths
	var density: Dictionary = report.get("timeline",{}).get("decision_density",{})
	result.decision_interval = density.get("average_interval")
	result.longest_growth_gap = density.get("longest_growth_gap")
	result.longest_decision_gap = density.get("longest_gap")
	var first_dps := 0.0
	var last_dps := 0.0
	var count := 0
	for point in report.get("timeline",{}).get("samples",[]):
		if not (float(point.dps) > 0 and int(point.kills) >= 3):continue
		if count == 0:first_dps = float(point.dps)
		last_dps = float(point.dps)
		count += 1
	result.dps_growth = (last_dps/first_dps-1.0)*100.0 if count > 1 else null
	return result

static func summarize(reports: Array) -> Dictionary:
	var result := {}
	for key in FIELDS:result[key] = accumulator()
	for report in reports:
		var values := row(report)
		for key in FIELDS:
			if values[key] != null:accumulate(result[key],float(values[key]))
	for key in result:result[key] = statistics(result[key])
	return result

static func accumulator() -> Dictionary:
	return {"count":0,"mean":0.0,"min":INF,"max":-INF,"m2":0.0}

static func accumulate(state: Dictionary, value: float) -> void:
	state.count += 1
	var delta := value-float(state.mean)
	state.mean += delta/int(state.count)
	state.m2 += delta*(value-float(state.mean))
	state.min = minf(float(state.min),value)
	state.max = maxf(float(state.max),value)

static func statistics(state: Dictionary) -> Dictionary:
	if int(state.count) == 0:return {"count":0,"mean":null,"min":null,"max":null,"stddev":null}
	return {"count":state.count,"mean":state.mean,"min":state.min,"max":state.max,"stddev":sqrt(maxf(0,float(state.m2)/int(state.count)))}

static func build(config: Dictionary, reports: Array, status: String, deep_copy_runs := true) -> Dictionary:
	var groups := {}
	for report in reports:
		var key := JSON.stringify([report.get("parameter_id",""),report.parameter_value,report.get("strategy","BALANCED")])
		if not groups.has(key):groups[key] = []
		groups[key].append(report)
	var scan := []
	for key in groups:
		var first: Dictionary = groups[key][0]
		scan.append({"parameter_id":first.get("parameter_id",""),"parameter":first.parameter_value,"strategy":first.get("strategy","BALANCED"),"summary":summarize(groups[key]),"partial":groups[key].any(func(run):return run.get("partial",false))})
	scan.sort_custom(func(a,b):
		if a.parameter_id != b.parameter_id:return str(a.parameter_id) < str(b.parameter_id)
		if a.parameter != b.parameter:return float(a.parameter) < float(b.parameter)
		return str(a.strategy) < str(b.strategy))
	var metrics := summarize_metrics(reports)
	var distribution := {}
	for key in metrics:
		if str(key).begins_with("weapon_damage_share/") or str(key).begins_with("resources/system_share/") or key in ["defence/shield_absorbed","defence/health_lost"]:distribution[key] = metrics[key]
	var warning_groups := {}
	for run in reports:
		for warning in run.get("analysis",{}).get("warnings",[]):
			var key: String = warning.code
			if not warning_groups.has(key):warning_groups[key] = {"code":key,"severity":warning.severity,"occurrences":0,"first_time":warning.start_time,"example":warning.evidence}
			warning_groups[key].occurrences += 1
			warning_groups[key].first_time = minf(float(warning_groups[key].first_time),float(warning.start_time))
	return {"simulation_mode":config.get("simulation_mode","exact"),"schema_version":2,"config":config.duplicate(true),"status":status,"runs":reports.duplicate(deep_copy_runs),"summary":summarize(reports),"metrics_summary":metrics,"build_distribution":distribution,"balance_warnings":warning_groups.values(),"scan":scan,"sensitivity":sensitivity(scan),"strategy_warnings":strategy_warnings(scan)}

static func sensitivity(scan: Array) -> Array:
	var groups := {}
	for point in scan:
		if point.parameter == null or point.partial:continue
		var key := str(point.parameter_id)+"|"+str(point.strategy)
		if not groups.has(key):groups[key] = []
		groups[key].append(point)
	var result := []
	for key in groups:
		var points: Array = groups[key]
		if points.size() < 2:continue
		var first: Dictionary = points.front()
		var last: Dictionary = points.back()
		var dx := float(last.parameter)-float(first.parameter)
		for metric in ["final_stage","ttk","deaths","upgrade_interval","dps","resource_surplus"]:
			var low: Variant = first.summary[metric].mean
			var high: Variant = last.summary[metric].mean
			if low == null or high == null or dx == 0:continue
			var elasticity: Variant = null
			if float(low) != 0 and float(first.parameter) != 0:elasticity = ((float(high)-float(low))/absf(float(low)))/(dx/absf(float(first.parameter)))
			result.append({"parameter_id":first.parameter_id,"strategy":first.strategy,"metric":metric,"from":first.parameter,"to":last.parameter,"before":low,"after":high,"slope":(float(high)-float(low))/dx,"elasticity":elasticity})
	# Rank within each metric; there is deliberately no score combining unlike metrics.
	result.sort_custom(func(a,b):return str(a.metric) < str(b.metric) if a.metric != b.metric else absf(float(a.elasticity) if a.elasticity != null else 0.0) > absf(float(b.elasticity) if b.elasticity != null else 0.0))
	return result

static func strategy_warnings(scan: Array) -> Array:
	var result := []
	var groups := {}
	for point in scan:
		if point.partial:continue
		var key := str(point.parameter_id)+"|"+str(point.parameter)
		if not groups.has(key):groups[key] = []
		groups[key].append(point)
	for key in groups:
		var points: Array = groups[key]
		if points.size() < 2:continue
		points.sort_custom(func(a,b):return float(a.summary.final_stage.mean) > float(b.summary.final_stage.mean))
		var best: Dictionary = points[0]
		var second: Dictionary = points[1]
		if float(best.summary.final_stage.mean) > float(second.summary.final_stage.mean)*(1.0+Analyzer.THRESHOLDS.strategy_advantage) and float(best.summary.deaths.mean) <= float(second.summary.deaths.mean):
			result.append({"code":"strategy_dominance","severity":"MEDIUM","parameter_id":best.parameter_id,"parameter":best.parameter,"strategy":best.strategy,"final_stage":best.summary.final_stage,"runner_up":second.strategy,"runner_up_stage":second.summary.final_stage,"note":"descriptive_not_significance_test"})
	return result

static func summarize_metrics(reports: Array) -> Dictionary:
	var samples := {}
	for report in reports:
		for key in ["game_seconds","final_stage","highest_stage","dps","combat_dps","ttk","boss_ttk","kills","boss_kills","defence","resources","upgrades","upgrade_interval","system_uses","damage","weapon_damage_share","equipment_utilization"]:
			collect_numeric(samples,report[key],key)
	var result := {}
	for key in samples:
		result[key] = statistics(samples[key])
	return result

static func collect_numeric(samples: Dictionary, value: Variant, path: String) -> void:
	if value is Dictionary:
		for key in value:collect_numeric(samples,value[key],path+"/"+str(key))
	elif (value is float or value is int) and is_finite(float(value)):
		if not samples.has(path):samples[path] = accumulator()
		accumulate(samples[path],float(value))

static func save(report: Dictionary, directory: String) -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:return {"error":error}
	var name := "balance_%s_%d" % [Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_usec()]
	var base := directory.path_join(name)
	var json := FileAccess.open(base+".json",FileAccess.WRITE)
	if json == null:return {"error":FileAccess.get_open_error()}
	json.store_string(JSON.stringify(report,"\t",true,true))
	json.flush()
	if json.get_error() != OK:return {"error":json.get_error()}
	json.close()
	var csv := FileAccess.open(base+".csv",FileAccess.WRITE)
	if csv == null:return {"error":FileAccess.get_open_error()}
	# Long-form CSV includes every nested metric, anomaly, configuration and summary.
	csv.store_csv_line(PackedStringArray(["path","value"]))
	write_csv(csv,report,"")
	csv.flush()
	if csv.get_error() != OK:return {"error":csv.get_error()}
	csv.close()
	var scan_file := FileAccess.open(base+"_scan.csv",FileAccess.WRITE)
	if scan_file == null:return {"error":FileAccess.get_open_error()}
	scan_file.store_csv_line(PackedStringArray(["simulation_mode","parameter_id","parameter","strategy","final_stage","ttk","boss_ttk","first_death_seconds","upgrade_interval","resource_surplus","deaths","dps_growth","decision_interval","longest_growth_gap"]))
	for point in report.scan:
		var columns := PackedStringArray([str(report.get("simulation_mode","exact")),str(point.parameter_id),str(point.parameter),str(point.strategy)])
		for key in ["final_stage","ttk","boss_ttk","first_death_seconds","upgrade_interval","resource_surplus","deaths","dps_growth","decision_interval","longest_growth_gap"]:columns.append(str(point.summary[key].mean))
		scan_file.store_csv_line(columns)
	scan_file.flush()
	if scan_file.get_error() != OK:return {"error":scan_file.get_error()}
	scan_file.close()
	return {"json":base+".json","csv":base+".csv","scan_csv":base+"_scan.csv"}

static func write_csv(file: FileAccess, value: Variant, path: String) -> void:
	if (value is Dictionary or value is Array) and value.is_empty():
		file.store_csv_line(PackedStringArray([path,JSON.stringify(value)]))
		return
	if value is Dictionary:
		for key in value:write_csv(file,value[key],path+"/"+str(key))
	elif value is Array:
		for index in value.size():write_csv(file,value[index],path+"/"+str(index))
	else:file.store_csv_line(PackedStringArray([path,JSON.stringify(value)]))
