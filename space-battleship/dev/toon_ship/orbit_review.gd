extends SceneTree
## Consecutive 30 Hz presentation frames; combat remains paused throughout.
const DT := 1.0/30.0
var scene
var output := ""
var errors: Array[String]=[]
var check_only := false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and not errors.has(message):errors.append(message);printerr("FAIL: ",message)
func positions()->Array:
	var p:Array=[scene.ship_view.ship.global_transform,scene.ship_view.orbit_elapsed]
	for c in scene.ship_view.carriers:p.append(c.global_transform)
	return p
func radius(node:Node3D,center:Vector3,exclude_weapons:=false)->float:
	var r:=0.0
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.name in ["PrototypeShield","BlueExhaust"]:continue
		if exclude_weapons:
			var skip:=false
			for m in scene.ship_view.modules:
				if m.node.is_ancestor_of(mesh):skip=true
			if skip:continue
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			for v in arrays[Mesh.ARRAY_VERTEX]:
				var point:Vector3=mesh.global_transform*v-center
				r=maxf(r,Vector2(point.x,point.z).length())
	return r
func frame(path:String)->void:
	await process_frame
	if check_only:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--orbit-check-only":check_only=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	scene=load("res://dev/toon_ship_test.tscn").instantiate();root.add_child(scene)
	root.size=Vector2i(1335,859)
	for i in 15:await process_frame
	scene.game.paused=true;scene.set_process(false);scene.set_effects(false)
	var label:=Label.new();label.text="CONTINUOUS ORBIT TEST | 18 s/orbit | 30 Hz presentation | COMBAT PAUSED"
	label.position=Vector2(10,10);label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",Color.WHITE);root.add_child(label)
	var view=scene.ship_view
	var center:Vector2=scene.player_render_position()
	var before:=JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	var rng_before:int=scene.game.rng.state
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-500),0,false,false,0)
	var anchor:Vector3=view.orbit_center
	var hull_radius:float=radius(view.ship,anchor,true)+0.10
	for mount in view.hull_config.weapon_mounts:
		hull_radius=maxf(hull_radius,(Vector2(float(mount.position[0]),float(mount.position[2])).length()+1.24)*view.ship.scale.x+0.10)
	var drone_radii:Array=[]
	for carrier in view.carriers:drone_radii.append(radius(carrier,carrier.global_position)+0.02)
	var minimum_hull_gap:=INF
	var minimum_drone_gap:=INF
	var max_bob:=0.0
	var max_yaw:=0.0
	var start:Array=[]
	var paths:Array=[[],[],[]]
	for c in view.carriers:start.append(c.global_position)
	var orbit_return_error:=0.0
	await frame(output.path_join("full-window-orbit.png"))
	for index in 600:
		view.set_pose(center,scene.reference_height,0,center+Vector2(0,-500),float(index+1)*DT,false,false,DT)
		check(view.orbit_center.is_equal_approx(anchor),"Orbit center must not inherit hull bob")
		max_bob=maxf(max_bob,view.ship.global_position.distance_to(anchor)/view.WORLD_PER_PIXEL)
		max_yaw=maxf(max_yaw,absf(rad_to_deg(view.ship.rotation.y)))
		for i in view.carriers.size():
			var c:Node3D=view.carriers[i]
			check(c.get_parent()==view.world,"Carrier must remain a world sibling")
			var gap:float=Vector2(c.global_position.x-anchor.x,c.global_position.z-anchor.z).length()-hull_radius-float(drone_radii[i])
			minimum_hull_gap=minf(minimum_hull_gap,gap);check(gap>0,"Carrier geometry envelope overlaps hull")
			var screen:Vector2=view.camera.unproject_position(c.global_position)
			var r:float=float(drone_radii[i])/view.WORLD_PER_PIXEL
			check(Rect2(Vector2.ONE*r,scene.BATTLE_VIEW_SIZE-Vector2.ONE*2*r).has_point(screen),"Carrier geometry envelope leaves viewport")
			paths[i].append([screen.x,screen.y])
			for j in range(i):
				var d:Vector3=c.global_position-view.carriers[j].global_position
				var other_gap:float=Vector2(d.x,d.z).length()-float(drone_radii[i])-float(drone_radii[j])
				minimum_drone_gap=minf(minimum_drone_gap,other_gap);check(other_gap>0,"Drone geometry envelopes overlap")
			if index==539:orbit_return_error=maxf(orbit_return_error,c.global_position.distance_to(start[i]))
		for module in view.modules:
			check(Rect2(Vector2.ZERO,scene.BATTLE_VIEW_SIZE).has_point(view.screen_muzzle_for_slot(module.slot)),"Muzzle outside battlefield")
		await frame(output.path_join("frames/frame-%04d.png"%index))
	var frozen:=positions()
	for i in 10:view.set_pose(center,scene.reference_height,0,center+Vector2(0,-500),100,false,false,0)
	check(frozen==positions(),"Zero delta must freeze bob and orbits")
	check(max_bob<=1.201 and max_yaw<=0.651,"Hull bob exceeds small anchored bounds")
	check(orbit_return_error<0.005,"18-second orbit did not return to start")
	check(before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles]) and rng_before==scene.game.rng.state,"Presentation modified gameplay or RNG")
	var facts:Dictionary={"passed":errors.is_empty(),"errors":errors,"frames":600,"visual_dt":DT,"duration":20,"orbit_period":18,"mother_height_logical":scene.reference_height,"mother_max_bob_logical_pixels":max_bob,"mother_max_yaw_degrees":max_yaw,"carrier_scale":view.CARRIER_SCALE,"weapon_scale_within_carrier":view.CARRIER_WEAPON_SCALE,"minimum_hull_gap_world":minimum_hull_gap,"minimum_drone_gap_world":minimum_drone_gap,"full_orbit_return_error_world":orbit_return_error,"state_rng_unchanged":before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles]) and rng_before==scene.game.rng.state,"zero_delta_freezes":frozen==positions(),"weapons":view.modules.size(),"carriers":view.carriers.size(),"save_enabled":scene.game.save_enabled,"fixture":"synthetic full loadout; combat paused","continuous_frames":true}
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	FileAccess.open(output.path_join("paths.json"),FileAccess.WRITE).store_string(JSON.stringify(paths))
	var entries:Array=scene.game.weapon_entries().duplicate(true)
	check(view.set_hull("Frigate") and view.set_loadout(entries,3),"Frigate switch failed")
	check(view.carriers.is_empty(),"Frigate must remove orbital carriers")
	check(view.set_hull("Heavy_Battleship") and view.set_loadout(entries,8),"Heavy return switch failed")
	check(view.carriers.size()==3 and view.carriers.all(func(c):return not c.visible),"Fresh carriers must stay hidden until initialized")
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-500),0,false,false,0)
	check(view.carriers.all(func(c):return c.visible and c.global_position.distance_to(view.orbit_center)>1.0),"Restored orbit carrier pop at origin")
	var restored:=positions()
	view.set_rendering(false,true)
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-500),100,false,false,0)
	view.set_rendering(true,true)
	check(restored==positions(),"Hidden/revealed zero-delta pose must not jump")
	facts.hull_switch_no_origin_pop=true
	facts.hidden_zero_delta_preserves_pose=restored==positions()
	facts.passed=errors.is_empty();facts.errors=errors
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	print("ORBIT_REVIEW ",JSON.stringify(facts));quit(0 if errors.is_empty() else 1)
