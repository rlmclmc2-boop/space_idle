extends SceneTree

const KEYS := ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]
const WEAPONS := ["longLaser", "laser", "missile", "cannon", "cannon"]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var key:String = OS.get_environment("HARDPOINT_ONLY")
	var output:String = OS.get_environment("HARDPOINT_CAPTURE_DIR")
	assert(KEYS.has(key) and not output.is_empty(),"Set HARDPOINT_ONLY and HARDPOINT_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var scene:Node=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.size=Vector2i(1440,900)
	root.add_child(scene)
	scene.automation_args=[]
	var game=scene.game
	game.save_enabled=false
	game.profile.onboarding.completed=true
	game.profile.onboarding.dismissed=true
	game.profile.selectedShip=key
	var count:int=game.active_slot_count("weapons")
	assert(count==KEYS.find(key)+1,key)
	var entries:Array=game.profile.loadout.weapons
	while entries.size()<count:entries.append({"key":"","level":1})
	for slot in count:entries[slot]={"key":WEAPONS[slot],"level":1}
	game.invalidate_stat_cache()
	assert(scene.ship_view.set_hull(key),key)
	scene.current_hull=key
	scene._set_reference_dimensions()
	assert(scene.ship_view.set_loadout(game.weapon_entries(),count),key)
	assert(game.start(1,false),key)
	game.group_index=1
	game.spawn_group()
	var native_rows:=[]
	if game.native_execution!=null:
		for row in game.native_execution.weapons:native_rows.append({"key":row.get("key",""),"hostile":row.get("hostile",false),"kind":row.get("kind",-1),"cd":row.get("cd",-1)})
	print("BATTLE_SETUP ",key," player=",Vector2(game.player.x,game.player.y)," enemies=",game.enemies.map(func(e):return Vector2(e.x,e.y))," native=",game.native_execution!=null," weapons=",native_rows)
	var metrics:Dictionary={"fires":0,"hits":0,"beams":0,"native_fires":0,"max_origin_error":0.0,"max_logical_error":0.0,"min_direct_aim_dot":1.0,"turn":0.0,"hull_bottom":0.0}
	var events:Dictionary={}
	var pending:Array=[]
	game.event.connect(func(kind:String,info:Dictionary)->void:
		events[kind]=int(events.get(kind,0))+1
		if kind=="hit" and not bool(info.get("player",false)):metrics.hits+=1
		if kind=="beam_started" and info.has("shot") and not bool(info.shot.get("hostile",false)):metrics.beams+=1
		if kind!="fire":return
		var shot:Dictionary=info.get("shot",{})
		var laser:Dictionary=info.get("native_laser",{})
		if shot.is_empty() and laser.is_empty():return
		if bool(shot.get("hostile",laser.get("hostile",false))) or bool(laser.get("drone",false)):return
		var slot:int=int(shot.get("mount",laser.get("mount",-1)))
		if slot<0 or slot>=count:return
		metrics.fires+=1
		if not laser.is_empty():metrics.native_fires+=1
		var ordinal:int=int(shot.get("salvo_ordinal",0))
		var launch:Vector2=scene.battle_point(Vector2(info.x,info.y))
		var logical:Vector2=scene.battle_slice_runtime.geometry.fleet_pose.screen_muzzle_for_slot(slot,ordinal)
		metrics.max_logical_error=maxf(float(metrics.max_logical_error),logical.distance_to(launch))
		pending.append({"slot":slot,"ordinal":ordinal,"launch":launch,"direction":Vector2(info.get("direction",Vector2.ZERO))})
	)
	for frame in 180:
		await process_frame
		for record in pending:
			var slot:int=record.slot
			var module:Dictionary=scene.ship_view.modules[slot]
			var muzzle:Vector2=scene.ship_view.screen_muzzle_for_slot(slot,int(record.ordinal))
			metrics.max_origin_error=maxf(float(metrics.max_origin_error),muzzle.distance_to(record.launch))
			if Vector2(record.direction).length_squared()>0.0:
				var ahead:Vector2=scene.ship_view.camera.unproject_position(module.muzzle.to_global(Vector3(0,0,-0.5)))
				var aim_dot:float=(ahead-muzzle).normalized().dot(Vector2(record.direction).normalized())
				if WEAPONS[slot]!="missile":metrics.min_direct_aim_dot=minf(float(metrics.min_direct_aim_dot),aim_dot)
		pending.clear()
		for module in scene.ship_view.modules:
			metrics.turn=maxf(float(metrics.turn),absf(module.pivot.rotation.y))
			var muzzle:Vector2=scene.ship_view.screen_muzzle_for_slot(int(module.slot))
			assert(muzzle.x>0 and muzzle.x<scene.ship_view.size.x and muzzle.y>0 and muzzle.y<scene.ship_view.size.y,key+" muzzle clipped")
	var plane:MeshInstance3D=scene.ship_view.approved_body_plane
	var opaque:Rect2=scene.ship_view.approved_body_bounds
	var texture_size:Vector2=((plane.material_override as StandardMaterial3D).albedo_texture as Texture2D).get_size()
	var mesh_size:Vector2=(plane.mesh as PlaneMesh).size
	for corner in [opaque.position,Vector2(opaque.end.x,opaque.position.y),Vector2(opaque.position.x,opaque.end.y),opaque.end]:
		var local:=Vector3((corner.x/texture_size.x-0.5)*mesh_size.x,0,(corner.y/texture_size.y-0.5)*mesh_size.y)
		var screen:Vector2=scene.ship_view.camera.unproject_position(plane.to_global(local))
		assert(screen.x>=0 and screen.x<=scene.ship_view.size.x and screen.y>=0 and screen.y<=scene.ship_view.size.y,key+" hull clipped")
		metrics.hull_bottom=maxf(float(metrics.hull_bottom),screen.y)
	assert(game.native_execution!=null and int(metrics.fires)>0 and int(metrics.hits)>0,key+" native combat not exercised")
	assert(float(metrics.max_origin_error)<0.1 and float(metrics.max_logical_error)<0.1,key+" muzzle/launch mismatch")
	assert(float(metrics.min_direct_aim_dot)>0.95 and float(metrics.turn)>0.05,key+" direct aim or turn mismatch")
	RenderingServer.force_draw()
	var path:String=output.path_join("battle-"+key.to_lower()+"-full.png")
	assert(root.get_texture().get_image().save_png(path)==OK,path)
	var result_path:String=output.path_join("battle-"+key.to_lower()+"-result.json")
	var result:=FileAccess.open(result_path,FileAccess.WRITE)
	assert(result!=null,result_path)
	result.store_string(JSON.stringify({"hull":key,"slots":count,"weapons":WEAPONS.slice(0,count),"metrics":metrics,"events":events,"native":game.native_execution!=null},"  "))
	result.close()
	print("BATTLE_CAPTURE ",key," slots=",count," metrics=",metrics," pulse=",scene.pulse_fire_count," rail=",scene.rail_fire_count," missile=",scene.missile_fire_count," events=",events," native=",game.native_execution!=null," image=",path)
	quit()
