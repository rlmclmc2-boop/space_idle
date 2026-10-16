extends SceneTree
const Geometry=preload("res://scripts/simulation_geometry_authority.gd")

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.hide()
	# A legacy display pose can outlive its contact until the next draw boundary.
	# Native admission must discard it instead of rebinding its entity to {}.
	scene.enemy_poses[0]={"entity":{"uid":900001,"slot":0,"hp":0.0}}
	var geometry=Geometry.new()
	geometry.prepare(scene,scene.game)
	if not geometry.enemy_poses.is_empty():
		printerr("FAIL stale enemy pose retained at native admission")
		quit(1)
		return
	geometry.finish_display_boundary()
	print("PASS stale enemy pose discarded before freeze_display_entity")
	geometry.close({"spatial":scene.game.target_spatial_source})
	quit()
