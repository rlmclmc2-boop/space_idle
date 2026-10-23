extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var workbook=load("res://scripts/mon_group_xlsx.gd")
	check(workbook.parse_resource_drops("｛1，128，1；2，4，0,5｝").drops==JSON.parse_string('[{"resourceId":1,"amount":128,"chance":1},{"resourceId":2,"amount":4,"chance":0.5}]'),"drop blocks match runtime JSON representation, order and supported punctuation")
	check(workbook.parse_resource_drops("{1,0,0}").drops==JSON.parse_string('[{"resourceId":1,"amount":0,"chance":0}]'),"zero amount/probability remains valid")
	for invalid in ["", "{1,2}", "{x,2,1}", "{1,no,1}", "{1,2,no}", "{1,2,1;}", "{1,2,1;;2,3,1}", "{1,2,1;2,3}", "{1,-1,1}", "{1,2,1.1}", "{0,2,1}", "{1,1e999,1}"]:
		check(workbook.parse_resource_drops(invalid).has("error"),"reject malformed complete drop list: "+invalid)
	check(not FileAccess.file_exists("res://scripts/main.gd") and not FileAccess.file_exists("res://main_game.tscn"),"portable project has no game UI")
	var entry=load("res://main.tscn").instantiate()
	root.add_child(entry)
	await process_frame
	var panel=entry.panel
	check(panel.tabs.get_tab_count()==3 and panel.visible and panel.tabs.get_tab_title(0)==UIText.t("fleet.enemy_tab") and panel.tabs.get_tab_title(1)==UIText.t("auto_level.title") and panel.tabs.get_tab_title(2)==UIText.t("cycle_level.title"),"current three tool pages remain available")
	check(not panel.database.data.is_empty(),"source database loaded")
	check(panel.database.mon_source_error.is_empty(),"packaged enemy workbook accepted: "+panel.database.mon_source_error)
	if not panel.database.mon_source_error.is_empty():
		entry.queue_free()
		await process_frame
		print("BATTLE LAB STANDALONE failures=",failures)
		quit(1)
		return
	print("STANDALONE workbook accepted enemies=",panel.database.enemies.size())
	var expected_path:=OS.get_environment("SPACE_MON_PROJECTION")
	if not expected_path.is_empty():
		var expected=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		check(expected is Dictionary and panel.database.enemies==expected,"packaged workbook projection equals official importer for every row and field")
		print("STANDALONE projection comparison failures=",failures)
	var large_id: String=""
	var small_id: String=""
	for id in panel.database.enemies:
		if float(panel.database.enemies[id].size)>=4 and large_id.is_empty():large_id=str(id)
		if float(panel.database.enemies[id].size)<4 and small_id.is_empty():small_id=str(id)
	# Exercise the real selection controls with a bounded smoke-test pool. The
	# full workbook was parsed above; catalog-wide combinatorics is a perf test.
	for id in panel.enemy_checks:panel.enemy_checks[id].button_pressed=id in [large_id,small_id]
	panel.inputs.count.value=2
	panel.inputs.min_count.value=1
	panel.inputs.max_count.value=2
	panel.generate()
	check(panel.rows.size()==2,"enemy fleets generated")
	if panel.rows.size()!=2:
		entry.queue_free()
		await process_frame
		print("BATTLE LAB STANDALONE failures=",failures)
		quit(1)
		return
	var large: Dictionary=panel.simulator.generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[large_id],"seed":81,"min_strength":0,"max_strength":1000000}).results[0]
	var small: Dictionary=panel.simulator.generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[small_id],"seed":82,"min_strength":0,"max_strength":1000000}).results[0]
	panel.rows=[small,large]
	var runtime_group: Dictionary=preload("res://scripts/enemy_fleet_simulator.gd").runtime_group(small)
	check(runtime_group.slots==small.slots and not runtime_group.has("formation_positions") and small.has("formation_positions"),"runtime group keeps source slots without consuming preview coordinates")
	runtime_group.slots[0]=999999
	check(runtime_group.slots!=small.slots,"runtime group owns its slots copy")
	var first_enemy: TreeItem=panel.table.get_root().get_first_child()
	first_enemy.select(0)
	panel.show_selected()
	check(panel.details.text.contains("结构评分"),"formation preview retained")
	var levels=panel.level_section
	for checkbox in levels.ship_checks.values():checkbox.button_pressed=false
	levels.start_generation()
	check(levels.generator.status=="idle" and levels.status_label.text==UIText.t("auto_level.select_ship"),"at least one player ship required")
	levels.ship_checks.values()[0].button_pressed=true
	levels.limits.max_loadouts.value=1
	levels.limits.max_level.value=0
	levels.limits.max_total_battles.value=6
	levels.limits.seed.value=42
	levels.start_generation()
	var deadline:=Time.get_ticks_msec()+30000
	while levels.generator.busy() and Time.get_ticks_msec()<deadline:levels.generator.process(20000)
	levels.refresh()
	print("STANDALONE_GENERATION ",JSON.stringify({"status":levels.generator.status,"error":levels.generator.error,"evaluated":levels.generator.evaluated.size(),"levels":levels.generator.levels.size()}))
	check(levels.generator.status=="completed" and levels.generator.evaluated.size()==panel.rows.size() and levels.generator.levels.size()==1,"current fleets become one multi-wave level")
	if levels.generator.levels.size()==1:
		var stage: Dictionary=levels.generator.levels[0]
		check(stage.encounters.size()==2 and levels.generator.final_wave_eligible(stage.encounters.back()),"last encounter uses only a few large ships")
	check(levels.generator.source_directory.begins_with(ProjectSettings.globalize_path("res://results")),"run contained in portable results")
	check(FileAccess.file_exists(levels.generator.source_directory.path_join("inputs.json")),"source fleets saved for replay")
	check(FileAccess.file_exists(levels.generator.output_directory.path_join("generated_levels.json")),"level evidence saved")
	check(FileAccess.file_exists(levels.generator.output_directory.path_join("monGroup.xlsx")),"Excel output saved")
	for row in levels.generator.group_rows:
		check(not row.group_data.has("formation_positions"),"export uses runtime groups, not preview coordinates")
	for row in levels.generator.evaluated:
		check(row.enemy_group.has("formation_positions"),"analysis evidence retains preview metadata")
	check(levels.list.item_count==levels.generator.levels.size(),"generated level visible in level page")
	var selected_ship_count:=0
	for check_box in levels.ship_checks.values():
		if check_box.button_pressed:selected_ship_count+=1
	check(selected_ship_count>=1,"ship selection retained on level page")
	# Existing capture remains authoritative if package files change afterwards.
	var template_path:="res://config_excel/published/level.xlsx"
	var template_bytes:=FileAccess.get_file_as_bytes(template_path)
	FileAccess.open(template_path,FileAccess.WRITE).store_string("injected later replacement")
	var cycle_output:=ProjectSettings.globalize_path("res://results/cycle-snapshot.xlsx")
	var cycle_error:String=preload("res://scripts/cycle_level_xlsx.gd").export_levels([{"level_id":1,"battle_points":[{"mon_group_id":int(panel.database.groups.keys()[0])}]}],cycle_output,panel.database.groups)
	FileAccess.open(template_path,FileAccess.WRITE).store_buffer(template_bytes)
	check(cycle_error.is_empty() and FileAccess.file_exists(cycle_output),"Cycle export uses the captured template after source replacement")
	check(not FileAccess.file_exists("res://config_excel/mon.xlsx"),"Portable runtime needs no mutable source workbook")
	verify_startup_rejection(panel.database,small)
	print("BATTLE LAB STANDALONE failures=",failures)
	entry.queue_free()
	await process_frame
	quit(1 if failures else 0)

func verify_startup_rejection(source: ShipDatabase, enemy: Dictionary) -> void:
	var generator_script=preload("res://scripts/player_loadout_generator.gd")
	var generator=generator_script.new(source)
	var options: Dictionary=generator.default_options()
	options.count=1
	var valid: Dictionary=generator.generate(options)
	var canonical: Dictionary=generator.generate_canonical(options,1)
	check(valid.status=="complete" and valid.results.size()==1,"startup fixture begins with a valid player record")
	check(canonical.status=="complete" and canonical.results.size()==1,"startup fixture begins with a valid canonical record")
	if valid.results.is_empty() or canonical.results.is_empty():return
	# A private database with missing frozen source groups must be rejected before
	# progress/equipment installation. Never touch the source or any player save.
	var invalid:=ShipDatabase.new()
	invalid.data=source.data.duplicate(true)
	for field in ["equipment","enemies","groups","levels","config","defaults"]:invalid.set(field,invalid.data[field])
	invalid.ships=invalid.data.ship
	invalid.groups.clear()
	var rejected=generator_script.new(invalid)
	var reason:="invalid_hyperspace_config_pack"
	check(rejected.generate(options).status==reason,"generate propagates startup rejection")
	check(rejected.generate_canonical(options,1).status==reason,"canonical generation propagates startup rejection")
	var record: Dictionary=valid.results[0].duplicate(true)
	record.config_fingerprint=rejected.fingerprint
	check(rejected.replay(record).get("error")==reason,"replay propagates startup rejection")
	var canonical_record: Dictionary=canonical.results[0].duplicate(true)
	canonical_record.config_fingerprint=rejected.fingerprint
	check(rejected.replay(canonical_record).get("error")==reason,"canonical replay propagates startup rejection")
	var game=generator_script.start_validated_battle(invalid,enemy,record,42)
	check(game.startup_error==reason and game.profile.is_empty() and game.enemies.is_empty() and not game.save_enabled,"battle startup stops before progress and spawn on rejection")
	check(generator_script.upgraded_profile(invalid,record,{},1).get("error")==reason,"upgrade adapter propagates startup rejection")
	var pair: Dictionary=rejected.create_battle({"player_loadout":record,"enemy_fleet":enemy,"seed":42})
	check(pair.get("error")=="invalid_player_loadout" and not pair.has("game"),"pair validation rejects a player whose rules cannot start")
	var runner=preload("res://scripts/fleet_battle_runner.gd").new(source)
	check(runner.start([enemy],valid.results,{"runs":1,"max_total":1,"max_per_pair":1,"samples_per_tag":1,"max_seconds":1,"directory":ProjectSettings.globalize_path("res://results/startup-rejection")}).is_empty(),"runner accepts valid immutable input records")
	while runner.status=="validating":runner.validate_next()
	runner.database.groups.clear()
	runner.process(20000)
	check(not runner.busy() and runner.results.size()==1 and runner.results[0].status=="error" and runner.results[0].error==reason and runner.game==null,"runner records startup rejection without ticking or metrics access")
	print("STANDALONE startup rejection cases complete")

