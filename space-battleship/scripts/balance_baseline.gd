extends RefCounted
const Analyzer := preload("res://scripts/balance_analyzer.gd")
const METRICS := ["final_stage","ttk","boss_ttk","upgrade_interval","dps","defence/deaths","decision_interval","longest_growth_gap","resource_surplus","weapon_damage_share/laser","weapon_damage_share/missile","weapon_damage_share/cannon","weapon_damage_share/longLaser"]

static func save_baseline(report: Dictionary, path: String) -> String:
	if report.get("status") != "completed" or report.get("runs",[]).is_empty():return "baseline_requires_completed_report"
	if report.runs.any(func(run):return run.get("partial",true)):return "baseline_requires_completed_report"
	if FileAccess.file_exists(path):return "baseline_path_exists"
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:return "baseline_directory_failed"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:return "baseline_open_failed"
	file.store_string(JSON.stringify({"kind":"balance_baseline","version":2,"report":report},"\t",true,true))
	file.flush()
	return "" if file.get_error() == OK else "baseline_write_failed"

static func load_baseline(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:return {"error":"baseline_open_failed"}
	if file.get_length() > 128*1024*1024:return {"error":"baseline_too_large"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("kind") != "balance_baseline" or not parsed.get("report") is Dictionary:return {"error":"invalid_baseline"}
	var report: Dictionary = parsed.report
	if report.get("status") != "completed" or not report.get("runs") is Array or not report.get("config") is Dictionary or not report.get("metrics_summary") is Dictionary or not report.get("summary") is Dictionary:return {"error":"invalid_baseline"}
	for run in report.runs:
		if not run is Dictionary or not run.has_all(["seed","game_seconds","parameter_value"]) or run.get("partial",true):return {"error":"invalid_baseline"}
		if not run.seed is float and not run.seed is int:return {"error":"invalid_baseline"}
		if not run.game_seconds is float and not run.game_seconds is int:return {"error":"invalid_baseline"}
	for section in ["summary","metrics_summary"]:
		for entry in report[section].values():
			if not entry is Dictionary or not entry.has("mean"):return {"error":"invalid_baseline"}
			var value: Variant = entry.mean
			if value != null and ((not value is float and not value is int) or not is_finite(float(value))):return {"error":"invalid_baseline"}
	return {"report":report}

static func signature(report: Dictionary) -> Array:
	var values := []
	for run in report.get("runs",[]):
		values.append(JSON.stringify([run.get("parameter_id",""),run.parameter_value,run.get("strategy","BALANCED"),int(run.seed),snappedf(float(run.game_seconds),0.0001),run.get("partial",false)]))
	values.sort()
	return values

static func mean(report: Dictionary, key: String) -> Variant:
	if report.get("summary",{}).has(key):return report.summary[key].get("mean")
	return report.get("metrics_summary",{}).get(key,{}).get("mean")

static func compare(baseline: Dictionary, current: Dictionary) -> Dictionary:
	if baseline.is_empty():return {"compatible":false,"reasons":["no_baseline"],"rows":[],"warnings":[]}
	var reasons := []
	if baseline.config.get("simulation_mode","exact") != current.config.get("simulation_mode","exact"):reasons.append("different_simulation_mode")
	if signature(baseline) != signature(current):reasons.append("different_samples_or_partial")
	for key in ["policy","initial_state","step_seconds","sample_interval","max_samples"]:
		var before: Variant = baseline.config.get(key)
		var after: Variant = current.config.get(key)
		var same: bool = is_equal_approx(float(before),float(after)) if (before is float or before is int) and (after is float or after is int) else before == after
		if not same:reasons.append("different_"+key)
	var rows := []
	for key in METRICS:
		var before: Variant = mean(baseline,key)
		var after: Variant = mean(current,key)
		var pp: bool = str(key).begins_with("weapon_damage_share/")
		var change: Variant = null
		var absolute: Variant = null
		if before != null and after != null:
			absolute = float(after)-float(before)
			if pp:change = absolute*100.0
			elif float(before) != 0:change = absolute/absf(float(before))*100.0
		rows.append({"metric":key,"baseline":before,"current":after,"absolute":absolute,"change":change,"unit":"pp" if pp else "%"})
	return {"compatible":reasons.is_empty(),"reasons":reasons,"baseline_hash":baseline.config.get("data_sha256",""),"current_hash":current.config.get("data_sha256",""),
		"rows":rows,"warnings":Analyzer.comparison_warnings(rows) if reasons.is_empty() else []}
