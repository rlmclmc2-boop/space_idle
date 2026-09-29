extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(not FileAccess.file_exists("res://scripts/main.gd") and not FileAccess.file_exists("res://main_game.tscn"),"portable project has no game UI")
	var entry=load("res://main.tscn").instantiate()
	root.add_child(entry)
	await process_frame
	var panel=entry.panel
	check(panel.tabs.get_tab_count()>=2 and panel.visible and panel.tabs.get_tab_title(0)==UIText.t("fleet.enemy_tab") and panel.tabs.get_tab_title(1)==UIText.t("auto_level.title"),"enemy fleets and automatic levels remain available")
	check(not panel.database.data.is_empty(),"source database loaded")
	panel.inputs.count.value=2
	panel.inputs.min_count.value=1
	panel.inputs.max_count.value=2
	panel.generate()
	check(panel.rows.size()==2,"enemy fleets generated")
	var large_id: String=""
	var small_id: String=""
	for id in panel.database.enemies:
		if float(panel.database.enemies[id].size)>=4 and large_id.is_empty():large_id=str(id)
		if float(panel.database.enemies[id].size)<4 and small_id.is_empty():small_id=str(id)
	var large: Dictionary=panel.simulator.generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[large_id],"seed":81,"min_strength":0,"max_strength":1000000}).results[0]
	var small: Dictionary=panel.simulator.generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[small_id],"seed":82,"min_strength":0,"max_strength":1000000}).results[0]
	panel.rows=[small,large]
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
	check(levels.generator.status=="completed" and levels.generator.evaluated.size()==panel.rows.size() and levels.generator.levels.size()==1,"current fleets become one multi-wave level")
	if levels.generator.levels.size()==1:
		var stage: Dictionary=levels.generator.levels[0]
		check(stage.encounters.size()==2 and levels.generator.final_wave_eligible(stage.encounters.back()),"last encounter uses only a few large ships")
	check(levels.generator.source_directory.begins_with(ProjectSettings.globalize_path("res://results")),"run contained in portable results")
	check(FileAccess.file_exists(levels.generator.source_directory.path_join("inputs.json")),"source fleets saved for replay")
	check(FileAccess.file_exists(levels.generator.output_directory.path_join("generated_levels.json")),"level evidence saved")
	check(FileAccess.file_exists(levels.generator.output_directory.path_join("monGroup.xlsx")),"Excel output saved")
	check(levels.list.item_count==levels.generator.levels.size(),"generated level visible in level page")
	var selected_ship_count:=0
	for check_box in levels.ship_checks.values():
		if check_box.button_pressed:selected_ship_count+=1
	check(selected_ship_count>=1,"ship selection retained on level page")
	print("BATTLE LAB STANDALONE failures=",failures)
	entry.queue_free()
	await process_frame
	quit(1 if failures else 0)

