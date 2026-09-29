extends SceneTree
const Generator := preload("res://scripts/fleet_level_generator.gd")
const Enemy := preload("res://scripts/enemy_fleet_simulator.gd")
const Player := preload("res://scripts/player_loadout_generator.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
const MonGroupXlsx := preload("res://scripts/mon_group_xlsx.gd")
var failures:=0

func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func save(path: String,value: Variant) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
func fixture(path: String,db: ShipDatabase,enemy: Dictionary,player: Dictionary,wins: int) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	save(path.path_join("inputs.json"),{"enemy_fleets":[enemy],"player_loadouts":[player],"data_sha256":JSON.stringify(db.data).sha256_text(),"config":{"power_multiplier":1.0,"module_delta":0}})
	save(path.path_join("summary.json"),{"status":"completed","completed_count":3,"aggregate":{"battle_count":3}})
	var file:=FileAccess.open(path.path_join("pairs.jsonl"),FileAccess.WRITE)
	file.store_line(JSON.stringify({"enemy_index":0,"player_index":0,"battle_count":3,"wins":wins,"avg_battle_time":12.0,"avg_player_hp_ratio":0.5,"errors":0,"timeouts":0}))
	file.close()
func run() -> void:
	check(UIText.reload_catalog().is_empty(),"UI text contract")
	var db:=ShipDatabase.new()
	var mon_names: Dictionary=MonGroupXlsx.read_mon_names().names
	check(MonGroupXlsx.group_name({"2":3,"1":2},mon_names)=="%s×2、%s×3" % [mon_names["1"],mon_names["2"]],"mixed group name sorts and counts mon descriptions")
	var large_id: String=""
	var small_id: String=""
	for id in db.enemies:
		if float(db.enemies[id].size)>=4 and large_id.is_empty():large_id=str(id)
		if float(db.enemies[id].size)<4 and small_id.is_empty():small_id=str(id)
	var enemy: Dictionary=Enemy.new(db).generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[large_id],"seed":71,"min_strength":0,"max_strength":1000000}).results[0]
	var maker:=Player.new(db)
	var options:=maker.default_options()
	options.seed=42
	options.count=1
	var canonical: Dictionary=maker.generate_canonical(options,1)
	check(canonical.results.size()==1,"one canonical loadout")
	var two_ships: Array=db.ships.keys().slice(0,2)
	if two_ships.size()==2:
		var multi_options: Dictionary=options.duplicate(true)
		multi_options.available_ships=two_ships
		var multi: Dictionary=maker.generate_canonical(multi_options,8)
		check(multi.results.any(func(row):return row.ship==two_ships[0]) and multi.results.any(func(row):return row.ship==two_ships[1]),"selected ships represented in canonical set")
	var player: Dictionary=canonical.results[0]
	check(maker.validate_record(player),"canonical loadout replays")
	var base: Dictionary=maker.rules.profile.duplicate(true)
	var upgraded: Dictionary=Player.upgraded_profile(db,player,base,1)
	check(not upgraded.has("error"),"normal module upgrades succeed in private profile")
	if not upgraded.has("error"):
		for category in ["weapons","defence"]:
			for index in range(player.equipment[category].size()):
				check(int(upgraded.loadout[category][index].level)==int(player.equipment[category][index].level)+1,"all equipped modules upgraded")
	var runner:=Runner.new(db)
	check(runner.start([enemy],[player],{"runs":1,"max_total":1,"max_per_pair":1,"samples_per_tag":1,"module_delta":1})=="","runner accepts module upgrade delta")
	while runner.status=="validating":runner.validate_next()
	check(str(runner.player_errors[0]).is_empty() and int(runner.profiles[0].loadout.weapons[0].level)==int(player.weapons[0].level)+1,"runner uses upgraded profile")
	runner.stop()
	var path:=ProjectSettings.globalize_path("res://results/level-fixture")
	fixture(path,db,enemy,player,3)
	var generator:=Generator.new(db)
	check(generator.start(path,{"max_loadouts":1,"max_level":1,"max_total_battles":3,"coarse_runs":3,"max_per_level":3,"seed":42})=="","all-fleet level analysis starts")
	check(generator.status=="completed" and generator.spent==0,"compatible +0 result reused")
	check(generator.candidates.size()==1 and generator.levels.size()==1,"every enemy retained as level")
	if not generator.levels.is_empty():
		var stage: Dictionary=generator.levels[0]
		var enemy_id: String=str(enemy.composition.keys()[0])
		var expected_name: String="%s×%d" % [str(mon_names[enemy_id]),int(enemy.composition[enemy_id])]
		check(stage.name.ends_with(expected_name) and stage.group_data.description==stage.name,"group name uses weapon style, mon des and ship count")
		check(stage.encounters.size()==1 and stage.encounters.back().enemy_group==stage.enemy_group,"single large fleet is a valid final wave")
		check(stage.recommended_level==0 and stage.loadout_results[0].required_level==0,"minimum module delta is zero")
		check(stage.loadout_results[0].tests[0].source=="existing_batch","existing pair evidence recorded")
		var reader:=ZIPReader.new()
		check(reader.open(path.path_join("generated_levels/monGroup.xlsx"))==OK,"monGroup workbook produced")
		var exported_sheet: String=""
		for member in reader.get_files():
			if member.begins_with("xl/worksheets/") and member.ends_with(".xml") and not member.contains("/_rels/"):exported_sheet=member;break
		check(not exported_sheet.is_empty() and reader.read_file(exported_sheet).get_string_from_utf8().contains(str(stage.name).xml_escape()),"Excel description uses the same group name")
		reader.close()
	var small: Dictionary=Enemy.new(db).generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[small_id],"seed":72,"min_strength":0,"max_strength":1000000}).results[0]
	var small_result: Dictionary=generator.evaluated[0].duplicate(true)
	small_result.enemy_index=1
	small_result.enemy_group=small
	small_result.composition=small.composition
	small_result.enemy_id="enemy_"+str(small.signature).sha256_text()
	generator.evaluated.append(small_result)
	generator.build_levels()
	check(generator.levels.size()==1 and generator.group_rows.size()==2,"small fleet becomes a preliminary wave without dropping either fleet")
	if generator.levels.size()==1:
		var combined: Dictionary=generator.levels[0]
		check(combined.groups.size()==2 and not generator.final_wave_eligible(combined.encounters[0]) and generator.final_wave_eligible(combined.encounters.back()),"few large ships remain the last wave")
		check(absf(float(combined.groups.back().position)-float(generator.policy.group_position))<0.0001,"last wave keeps final encounter position")
		var crowded: Dictionary=enemy.duplicate(true)
		crowded.composition={large_id:4}
		check(not generator.final_wave_eligible(crowded),"large-ship fleet above final count cap is rejected")
	var weak_path:=ProjectSettings.globalize_path("res://results/level-weak-fixture")
	fixture(weak_path,db,enemy,player,0)
	var capped:=Generator.new(db)
	check(capped.start(weak_path,{"max_loadouts":1,"max_level":0,"max_total_battles":3,"coarse_runs":3,"max_per_level":3,"seed":42})=="","capped search starts")
	check(capped.status=="completed" and capped.levels.size()==1 and capped.levels[0].loadout_results[0].status=="unbeatable","unbeatable fleet still retained")
	var searched:=Generator.new(db)
	check(searched.start(weak_path,{"max_loadouts":1,"max_level":1,"max_total_battles":3,"coarse_runs":3,"max_per_level":3,"max_seconds":30,"seed":42})=="","next module level starts")
	var deadline:=Time.get_ticks_msec()+30000
	while searched.busy() and Time.get_ticks_msec()<deadline:searched.process(20000)
	check(searched.status=="completed" and searched.spent==3,"next module level executes bounded battles")
	if not searched.levels.is_empty():
		var search_row: Dictionary=searched.levels[0].loadout_results[0]
		check(search_row.tests.size()==2 and search_row.tests[1].module_delta==1 and search_row.tests[1].tests==3,"sequential +0 then +1 evidence")
	var panel:=VBoxContainer.new()
	panel.set_script(load("res://scripts/fleet_level_panel.gd"))
	panel.database=db
	root.add_child(panel)
	panel.path_input.text=path
	panel.limits.max_loadouts.value=1
	panel.limits.max_level.value=1
	panel.limits.max_total_battles.value=3
	panel.limits.seed.value=42
	for checkbox in panel.ship_checks.values():checkbox.button_pressed=false
	panel.ship_checks[player.ship].button_pressed=true
	panel.start_generation()
	check(panel.list.item_count==1 and panel.details.text.contains("典型配装所需模块升级") and panel.list.get_item_text(0).begins_with(generator.levels[0].name) and not panel.details.text.contains("关卡 #"),"designer page shows named group")
	panel.queue_free()
	print("FLEET LEVEL failures=",failures)
	quit(1 if failures else 0)

