extends SceneTree
const Analyzer := preload("res://scripts/fleet_result_analyzer.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func save(path: String,data: Variant) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
func run() -> void:
	var directory := ProjectSettings.globalize_path("res://.runtime/analysis-fixture")
	DirAccess.make_dir_recursive_absolute(directory)
	var enemies := [{"signature":"a","primary_tags":["heavy"],"secondary_tags":["durable"],"composition":{"1":2}},{"signature":"b","primary_tags":["light"],"secondary_tags":[]}]
	var players := [{"loadout_id":"p1","ship":"Frigate","tags":["burst"],"weapons":[{"key":"cannon","level":1},{"key":"longLaser","level":1}],"equipment":{},"stats":{}},{"loadout_id":"p2","ship":"Frigate","tags":["sustained"],"weapons":[{"key":"laser","level":1}],"equipment":{},"stats":{}}]
	save(directory.path_join("inputs.json"),{"enemy_fleets":enemies,"player_loadouts":players})
	save(directory.path_join("summary.json"),{"status":"completed","completed_count":102,"aggregate":{"battle_count":102}})
	var file := FileAccess.open(directory.path_join("pairs.jsonl"),FileAccess.WRITE)
	for spec in [[0,0,50,40,20.0],[0,1,50,10,40.0],[1,0,2,2,0.2]]:
		file.store_line(JSON.stringify({"enemy_index":spec[0],"player_index":spec[1],"battle_count":spec[2],"wins":spec[3],"attempted_count":spec[2],"avg_battle_time":spec[4],"avg_player_hp_ratio":0.5,"avg_enemy_hp_ratio":0.3,"time_m2":0.0}))
	file.close()
	var before := FileAccess.get_file_as_string(directory.path_join("pairs.jsonl"))
	var analyzer := Analyzer.new()
	var result := analyzer.analyze(directory)
	check(not result.has("error"),"fixture parsed")
	if result.has("error"):printerr(result);quit(1);return
	var candidate: Dictionary=result.level_candidates[0]
	check(candidate.candidate and candidate.tests==100 and is_equal_approx(candidate.win_rate,0.5) and is_equal_approx(candidate.avg_battle_time,30.0),"weighted enemy aggregation and candidate")
	check(is_equal_approx(candidate.discrimination,0.6) and candidate.strengths.size()==1 and candidate.weaknesses.size()==1,"configuration discrimination and supported contrast")
	check(candidate.design_category=="ordinary" and candidate.design_best.size()==1 and candidate.design_worst.size()==1,"all fleets remain candidates with descriptive rankings")
	check(result.level_candidates[1].design_category=="insufficient" and result.level_candidates[1].design_best.is_empty(),"sparse perfect wins never get confident readable recommendations")
	for scenario in [{"rate":0.1,"expected":"ordinary"},{"rate":0.9,"expected":"ordinary"},{"rate":0.5,"expected":"ordinary"}]:
		var design: Dictionary=candidate.duplicate(true)
		design.candidate=false
		design.discrimination=0.0
		design.discrimination_label="general"
		var comparisons: Array=result.pair_analysis.slice(0,2).duplicate(true)
		for pair in comparisons:pair.win_rate=scenario.rate
		analyzer.add_design_fields(design,comparisons)
		check(design.design_category==scenario.expected,"current win rate does not classify level viability "+str(scenario.rate))
		check(design.design_best.is_empty() and design.design_worst.is_empty(),"equal configurations not given false best/worst ranks")
	var anomaly: Dictionary=candidate.duplicate(true)
	anomaly.findings=["long"]
	analyzer.add_design_fields(anomaly,result.pair_analysis.slice(0,2))
	check(anomaly.design_category=="anomaly","abnormal time category overrides recommendation")
	check(result.enemy_analysis[1].confidence=="low" and not result.enemy_analysis[1].findings.has("dominant"),"tiny perfect result not promoted")
	check(result.enemy_tags.size()==3 and result.player_tags.size()==2,"both tag dimensions")
	var laser: Dictionary=result.weapon_analysis.filter(func(row):return row.kind=="combination" and row.weapon=="laser" and row.scope=="enemy")[0]
	check(laser.tests==50 and laser.findings.has("bad"),"weapon comparison conditioned on enemy")
	check(result.player_analysis[0].tests==52 and is_equal_approx(result.player_analysis[0].win_rate,42.0/52),"unequal samples weighted correctly")
	check(analyzer.export_files(directory)=="","all exports")
	var csv := FileAccess.open(directory.path_join("level_candidates.csv"),FileAccess.READ)
	var header := csv.get_csv_line()
	var first_csv := csv.get_csv_line()
	check(first_csv.size()==header.size() and first_csv[header.find("composition")].contains("1"),"CSV quoting preserves nested candidate composition")
	for name in ["analysis_summary.json","enemy_analysis.csv","player_analysis.csv","weapon_analysis.csv","pair_analysis.csv","level_candidates.csv"]:check(FileAccess.file_exists(directory.path_join(name)),"export "+name)
	check(FileAccess.get_file_as_string(directory.path_join("pairs.jsonl"))==before,"source aggregates unchanged")
	var repeat: Dictionary=analyzer.analyze(directory)
	check(result==repeat,"analysis deterministic")
	var with_untested: Array=enemies.duplicate(true)
	with_untested.append({"signature":"c","primary_tags":["fast"],"secondary_tags":[],"composition":{"2":1}})
	save(directory.path_join("inputs.json"),{"enemy_fleets":with_untested,"player_loadouts":players})
	var inclusive: Dictionary=analyzer.analyze(directory)
	check(inclusive.level_candidates.size()==3 and inclusive.level_candidates[2].candidate and inclusive.level_candidates[2].tests==0,"untested generated fleet remains candidate")
	# Legacy aggregate without time M2 is still readable, with explicit limitation.
	var legacy=JSON.parse_string(before.split("\n")[0])
	legacy.erase("time_m2")
	var row: Dictionary=analyzer.normalize(legacy,{"enemy_fleets":enemies,"player_loadouts":players})
	check(row.time_cv==null and analyzer.warnings.has("legacy_time_variance_unknown"),"old batches do not invent time variance")
	row=analyzer.normalize({"enemy_index":1,"player_index":1,"battle_count":0,"wins":0,"attempted_count":3,"timeouts":3},{"enemy_fleets":enemies,"player_loadouts":players})
	check(row.win_rate==null and row.tests==0 and row.excluded==3 and row.confidence=="low","timeouts excluded, not losses")
	var fluctuating: Dictionary=legacy.duplicate(true)
	fluctuating.time_m2=1000000.0
	row=analyzer.normalize(fluctuating,{"enemy_fleets":enemies,"player_loadouts":players})
	check(row.confidence=="low" and row.findings.has("time_variation") and not row.findings.has("good"),"time instability downgrades confident conclusions")
	var boundary: Dictionary=legacy.duplicate(true)
	boundary.wins=25
	row=analyzer.normalize(boundary,{"enemy_fleets":enemies,"player_loadouts":players})
	check(row.findings.has("boundary") and row.findings.has("outcome_variation"),"valuable 50-percent matchup and mixed outcomes identified")
	file=FileAccess.open(directory.path_join("pairs.jsonl"),FileAccess.WRITE)
	file.store_string(before+before.split("\n")[0]+"\n")
	file.close()
	check(analyzer.analyze(directory).get("error","").begins_with("duplicate_pair"),"duplicate aggregates rejected, no double counting")
	file=FileAccess.open(directory.path_join("pairs.jsonl"),FileAccess.WRITE)
	file.store_string(before)
	file.close()
	print("FLEET ANALYSIS failures=",failures)
	quit(1 if failures else 0)
