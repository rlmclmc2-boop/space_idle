extends SceneTree
var scene: Node
var directory := ""
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	scene.refresh_navigation()
	scene.refresh_draw_layers(0)
	scene.overlay_layer.queue_redraw()
	scene.resource_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	if error!=OK:printerr("Screenshot failed: ",name," ",error)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	directory = ProjectSettings.globalize_path("res://../test/evidence/opening-feedback-20261016")
	DirAccess.make_dir_recursive_absolute(directory)
	scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.assign([str(scene.db.data.unlock.keys()[0])])
	scene.beginner_guide.refresh()
	await capture("01-default-confirm")
	scene.game.acknowledge_unlocks()
	scene.help_open=true
	scene.set_tutorial_auto_skip(true)
	await capture("02-optional-auto-skip")
	scene.help_open=false
	scene.set_tutorial_auto_skip(false)
	for id in ["1","2"]:
		var drop := {"uid":9910+int(id),"x":220.0,"y":340.0,"age":1.0,"id":id,"amount":10.0}
		scene.game.drops.append(drop)
		scene.game.collect(drop,true)
	await capture("03-two-resources")
	scene.game.profile.cleared=range(1,9)
	scene.game.rebuild_unlocks()
	var fragment := {"uid":9920,"x":220.0,"y":340.0,"age":1.0,"jewel":true,"amount":5.0}
	scene.game.drops.append(fragment)
	scene.game.collect(fragment,true)
	await capture("04-three-resources")
	scene.game.stage=3
	scene.select_system(11)
	var page=scene.enemy_intel_page
	page.show_entry(page.entries.find_custom(func(entry):return str(entry.id)=="271024"))
	await capture("05-stage-three-reactive")
	print("Opening screenshots: ",directory)
	scene.queue_free()
	quit()
