extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(label,": ","PASS" if value else "FAIL")
	if not value:
		failures += 1

func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if predicate.call():
			return true
		await process_frame
	return false

func run() -> void:
	var original := FileAccess.get_file_as_string("res://data/game_data.json")
	var current_tables := {}
	for name in DirAccess.get_files_at("res://config_excel"):
		if name.ends_with(".xlsx") or name == ".split_manifest.json":
			current_tables[name] = FileAccess.get_file_as_bytes("res://config_excel/"+name)
	if FileAccess.file_exists("res://data/.import_state.json"):
		DirAccess.remove_absolute("res://data/.import_state.json")
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await wait_for(func():return root.has_node("QATools"))
	var panel = root.get_node("QATools")
	var panel_id: int = panel.get_instance_id()
	var process_id := OS.get_process_id()
	check(panel.get_tree()==current_scene.get_tree(),"Shared game instance")
	var selected := ProjectSettings.globalize_path("res://.runtime/测试 Excel.xlsx")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://../太空战舰.xlsx"),selected)
	panel.select_source(selected)
	panel.split_button.pressed.emit()
	await wait_for(func():return panel.worker==null)
	check(panel.status_label.text.begins_with("拆分同步成功"),"Split/sync button creates separate workbooks")
	check(FileAccess.file_exists("res://config_excel/equipment.xlsx") and not FileAccess.file_exists("res://config_excel/总览.xlsx"),"Split excludes overview")
	# The historical aggregate lacks current scientist fields. Test importing
	# the current source tables without weakening the production validator.
	for name in current_tables:
		var file := FileAccess.open("res://config_excel/"+name,FileAccess.WRITE)
		file.store_buffer(current_tables[name])
		file.close()
	panel.import_button.pressed.emit()
	await wait_for(func():return panel.worker==null)
	check(panel.status_label.text.begins_with("导入成功"),"Selected Excel import")
	var imported_json := FileAccess.get_file_as_string("res://data/game_data.json")
	panel.import_button.pressed.emit()
	await wait_for(func():return panel.worker==null)
	check(panel.status_label.text.begins_with("没有配置变化") and FileAccess.get_file_as_string("res://data/game_data.json")==imported_json,"QA unchanged import is a no-op")
	panel.send_control({"paused":true})
	var distance: float = current_scene.game.distance
	await create_timer(0.4).timeout
	check(current_scene.game.paused and current_scene.game.distance==distance,"Direct pause")
	panel.speed_select.select(panel.speed_select.get_item_index(5))
	panel.speed_select.item_selected.emit(panel.speed_select.get_item_index(5))
	check(current_scene.game.speed==5,"Direct x5")
	panel.send_control({"paused":false})
	check(not current_scene.game.paused,"Direct resume")
	# Freeze and settle pre-existing drops before assigning the persistence fixture.
	# Otherwise legitimate pickups during asynchronous reload change the balance.
	panel.send_control({"paused":true})
	current_scene.game.settle_drops()
	current_scene.game.profile.resources["1"]=4321
	var previous_scene := current_scene.get_instance_id()
	panel.restart_button.pressed.emit()
	var done := await wait_for(func():return not panel.restarting)
	check(done and current_scene.get_instance_id()!=previous_scene and OS.get_process_id()==process_id,"Reload scene without new process")
	check(root.get_node("QATools").get_instance_id()==panel_id and panel.visible,"QA survives scene reload")
	check(current_scene.game.profile.resources["1"]==4321 and current_scene.game.speed==5,"Progress and speed preserved")
	panel.close_panel()
	check(not panel.visible and is_instance_valid(current_scene),"Close QA only hides panel")
	current_scene.show_qa_tools()
	check(panel.visible and root.get_node("QATools").get_instance_id()==panel_id,"Reopen same QA panel")
	var restored := ConfigFile.new()
	restored.load("user://qa_settings.cfg")
	check(restored.get_value("excel","path")==selected and str(restored.get_value("excel","last_status")).contains("成功"),"Excel selection and status persisted")
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		panel.get_texture().get_image().save_png("res://preview-config.png")
	panel.select_source(ProjectSettings.globalize_path("res://../太空战舰.xlsx").simplify_path())
	DirAccess.remove_absolute(selected)
	var restore := FileAccess.open("res://data/game_data.json",FileAccess.WRITE)
	restore.store_string(original)
	restore.close()
	print("INTEGRATED QA: ",failures," failures")
	quit(0 if failures==0 else 1)
