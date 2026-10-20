extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	root.add_child(scene)
	await process_frame
	var warned := false
	for child in scene.get_children():
		if child is AcceptDialog and child.title == "存档已被占用":warned = true
	print("S04A_UI:", JSON.stringify({"warned":warned,"processing":scene.is_processing(),"save_enabled":scene.game.save_enabled,"startup":scene.game.startup_error}))
	quit(0)
