extends SceneTree
var failures:=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	var event:=InputEventKey.new()
	event.keycode=KEY_F9
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	var panel=scene.enemy_fleet_lab
	check(is_instance_valid(panel) and panel.visible,"F9 opens fleet tool")
	if not is_instance_valid(panel):quit(1);return
	var original_profile: Dictionary=scene.game.profile.duplicate(true)
	var original_data:=JSON.stringify(scene.game.db.data)
	var seed_control: int=panel.inputs.seed.get_instance_id()
	check(panel.tabs.get_tab_count()==2,"only enemy fleets and automatic levels visible")
	panel.inputs.count.value=100
	panel.generate()
	check(panel.rows.size()==100 and panel.table.get_root().get_child_count()==100,"enemy fleet generation and table")
	var row_item: TreeItem=panel.table.get_root().get_first_child()
	var first_id: String=str(panel.rows[0].composition.keys()[0])
	check(row_item.get_text(0).contains(str(panel.database.enemies[first_id].des)) and row_item.get_text(0).contains("×"),"fleet list uses mon des and counts")
	row_item.select(0)
	panel.show_selected()
	check(panel.details.text.contains("结构评分") and panel.details.text.contains("composition"),"formation and composition details")
	var row_id: int=panel.items[0].get_instance_id()
	var signatures: Array=panel.rows.map(func(row):return row.signature)
	panel.filters.min_count.value=8
	panel.filters.max_count.value=9
	panel.apply_filters()
	var valid:=true
	for index in range(panel.items.size()):
		if panel.items[index].visible:valid=valid and panel.rows[index].count>=8 and panel.rows[index].count<=9
	check(valid,"fleet count filter")
	panel.filters.min_count.value=0
	panel.filters.max_count.value=10
	panel.apply_filters()
	check(panel.items[0].get_instance_id()==row_id and panel.inputs.seed.get_instance_id()==seed_control,"filter preserves controls and rows")
	check(panel.rows.map(func(row):return row.signature)==signatures,"filter leaves data unchanged")
	panel.tabs.current_tab=1
	await process_frame
	check(panel.level_section.current_fleets.call().size()==100,"automatic level tab reads current fleets")
	var selected_ships:=0
	for checkbox in panel.level_section.ship_checks.values():
		if checkbox.button_pressed:selected_ships+=1
	check(selected_ships>=1,"level page keeps ship choice")
	check(JSON.stringify(scene.game.profile)==JSON.stringify(original_profile) and JSON.stringify(scene.game.db.data)==original_data,"tool does not mutate game data or save")
	print("ENEMY FLEET UI failures=",failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

