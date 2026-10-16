extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.hide()
	var view=scene.ship_view
	view.set_loadout([{"key":"cannon","level":1}],1)
	view.set_pose(scene.player_render_position(),scene.reference_height,0.0,scene.player_render_position()+Vector2(0,-450),scene.demo_time,false,false)
	var muzzle:Vector2=view.screen_muzzle_for_slot(0)
	var mount:Vector2=view.camera.unproject_position(view.modules[0].mount.global_position)
	var center:Vector2=view.rendered_position
	var front:Vector2=view.camera.unproject_position(view.ship.to_global(Vector3(0,0,float(view.hull_config.godot_aabb_min[2]))))
	var rear:Vector2=view.camera.unproject_position(view.ship.to_global(Vector3(0,0,float(view.hull_config.godot_aabb_max[2]))))
	var socket:Node3D=view.modules[0].muzzle
	var forward:Vector2=view.camera.unproject_position(socket.to_global(Vector3(0,0,-1)))
	print("RAIL_GEOMETRY ",JSON.stringify({"muzzle_x":muzzle.x,"muzzle_y":muzzle.y,"mount_x":mount.x,"mount_y":mount.y,"ship_x":center.x,"ship_y":center.y,"height":view.rendered_height,"hull_z_min_y":front.y,"hull_z_max_y":rear.y,"socket_z":socket.position.z,"forward_one_y":forward.y,"pulse_z":scene.pulse_layer.z_index,"overlay_z":scene.overlay_layer.z_index,"hud_z":scene.battle_hud_layer.z_index}))
	var logical=preload("res://scripts/logical_fleet_pose.gd").new()
	logical.prepare(view)
	logical.configure("Frigate",[{"key":"cannon"}],1,{})
	logical.pose_base(scene.player_render_position(),scene.reference_height,0.0,scene.demo_time,false,0.0)
	var logical_muzzle:Vector2=logical.screen_muzzle_for_slot(0)
	if muzzle.distance_to(logical_muzzle)>0.5 or muzzle.y>front.y:
		printerr("FAIL real and logical cannon muzzles diverge or fire inside the bow: ",muzzle," vs ",logical_muzzle," bow=",front)
		quit(1)
		return
	print("PASS cannon real/logical muzzle ahead of Frigate bow ",muzzle," vs ",logical_muzzle)
	if scene.pulse_layer.z_index>=scene.overlay_layer.z_index:
		printerr("FAIL rail feedback above tutorial")
		quit(1)
		return
	print("PASS rail feedback below tutorial and damage HUD")
	quit()
