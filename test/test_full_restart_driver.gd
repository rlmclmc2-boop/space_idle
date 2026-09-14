extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	for i in range(300):
		if root.has_node("QATools"): break
		await process_frame
	var panel = root.get_node("QATools")
	await process_frame
	await RenderingServer.frame_post_draw
	panel.get_texture().get_image().save_png("res://../qa-full-restart.png")
	current_scene.set_process(false)
	current_scene.game.profile.resources["1"] = 432123
	current_scene.game.drops.clear()
	panel.settings.set_value("control", "speed", 5)
	panel.restarting = true
	panel.full_restart()
	assert(not FileAccess.file_exists("res://.runtime/full-restart.log"))
	panel.restarting = false
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	# This code is written AFTER the current scene has loaded. Only a fresh
	# process can execute it; its evidence includes the inherited save path.
	var probe := '\n\tvar evidence := FileAccess.open("res://../restart-result.json", FileAccess.WRITE)\n\tevidence.store_string(JSON.stringify({"pid":OS.get_process_id(), "save":JSON.parse_string(FileAccess.get_file_as_string("user://progress.json")), "user":OS.get_user_data_dir(), "code":"fresh"}))\n\tevidence.close()\n\tget_tree().call_deferred("quit")\n'
	source = source.replace("func _ready() -> void:", "func _ready() -> void:" + probe)
	var file := FileAccess.open("res://scripts/main.gd", FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var before := FileAccess.open("res://../restart-before.json", FileAccess.WRITE)
	before.store_string(JSON.stringify({"pid":OS.get_process_id(), "user":OS.get_user_data_dir()}))
	before.close()
	panel.full_restart_button.pressed.emit()
