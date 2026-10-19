extends SceneTree
const KEYS:=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
var fires:=0
var hits:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var key:=OS.get_environment("FULL_HULL");var weapon:=OS.get_environment("FULL_WEAPON");var output:=OS.get_environment("FULL_OUTPUT")
	assert(KEYS.has(key) and not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1373,883)
	var scene:Node=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene)
	scene.automation_args=[];scene.game.save_enabled=false;scene.game.profile.onboarding.completed=true;scene.game.profile.onboarding.dismissed=true
	scene.game.profile.selectedShip=key
	var count:int=scene.game.active_slot_count("weapons")
	while scene.game.profile.loadout.weapons.size()<count:scene.game.profile.loadout.weapons.append({"key":"","level":1})
	for slot in count:scene.game.profile.loadout.weapons[slot]={"key":weapon,"level":1}
	scene.game.invalidate_stat_cache();scene.ship_view.set_hull(key);scene.current_hull=key;scene._set_reference_dimensions();scene.ship_view.set_loadout(scene.game.weapon_entries(),count)
	scene.game.event.connect(func(kind:String,info:Dictionary):
		if kind=="fire" and not bool(info.get("shot",{}).get("hostile",true)):fires+=1
		if kind=="hit" and not bool(info.get("player",false)):hits+=1)
	assert(scene.game.start(1,false));scene.game.group_index=1;scene.game.spawn_group()
	var frames_run:=0
	for frame in 150:
		await process_frame;frames_run=frame+1
		if frames_run>=90 and fires>0 and hits>0:break
	print("FULL_BATTLE hull=",key," weapon=",weapon," fires=",fires," hits=",hits," native=",scene.game.native_execution!=null," state=",scene.game.state)
	assert(fires>0 and hits>0,"Full battle did not advance combat")
	var dimensions:Array=[]
	var view=scene.ship_view
	var to_pixels:Transform2D=root.get_final_transform()*view.get_global_transform_with_canvas()
	var raster_size:=Vector2(root.get_texture().get_image().get_size())
	var texture_size:=Vector2(root.get_texture().get_size())
	var raster_factor:=raster_size/texture_size
	for module in view.modules:
		var plane:MeshInstance3D=module.node.find_child("StaticWeaponArt",true,false)
		var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
		var opaque:Rect2=Rect2(texture.get_image().get_used_rect());var mesh_size:Vector2=(plane.mesh as PlaneMesh).size
		var bounds:=Rect2();var initial:=true
		for pixel in [opaque.position,Vector2(opaque.end.x,opaque.position.y),opaque.end,Vector2(opaque.position.x,opaque.end.y)]:
			var uv:Vector2=pixel/Vector2(texture.get_size())
			var local:=Vector3((uv.x-.5)*mesh_size.x,0,(uv.y-.5)*mesh_size.y)
			var point:Vector2=(to_pixels*view.camera.unproject_position(plane.to_global(local)))*raster_factor
			if initial:bounds=Rect2(point,Vector2.ZERO);initial=false
			else:bounds=bounds.expand(point)
		dimensions.append({"slot":int(module.slot)+1,"opaque_aabb_width_px":bounds.size.x,"opaque_aabb_height_px":bounds.size.y})
	scene.game.paused=true;scene.set_process(false)
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(key+"-"+weapon+"-battle.png"))==OK)
	# Pause-only inspection: remove in-memory flights and visual feedback so a
	# frozen old ray is not mistaken for the newly turned turret's firing ray.
	scene.game.projectiles.clear();scene.projectile_visuals.clear();scene.rail_events.clear();scene.missile_events.clear();scene._pulse_events.clear()
	scene.pulse_layer.visible=false
	if is_instance_valid(scene.retained_contacts):scene.retained_contacts.foreground.hide()
	scene.battle_layer.queue_redraw()
	for angle in [-60,60]:
		for module in scene.ship_view.modules:module.pivot.rotation.y=deg_to_rad(angle)
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(key+"-"+weapon+"-turn"+str(angle)+".png"))==OK)
	var file:=FileAccess.open(output.path_join(key+"-"+weapon+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"hull":key,"weapon":weapon,"slots":count,"frames":frames_run,"fires":fires,"hits":hits,"native":scene.game.native_execution!=null,"window":[int(raster_size.x),int(raster_size.y)],"texture_reported_size":[int(texture_size.x),int(texture_size.y)],"projection_raster_factor":[raster_factor.x,raster_factor.y],"weapon_bounds":dimensions,"turn_inspection":"paused +/-60 degrees; flights cleared only in isolated fixture"},"  "))
	quit()
