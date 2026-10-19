extends SceneTree

const KEYS := ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]
const WEAPONS := ["longLaser", "laser", "missile", "cannon", "cannon"]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var key:String = OS.get_environment("HARDPOINT_ONLY")
	var output:String = OS.get_environment("HARDPOINT_CAPTURE_DIR")
	var extended:bool = OS.get_environment("HARDPOINT_EXTENDED") == "1"
	assert(KEYS.has(key) and not output.is_empty(),"Set HARDPOINT_ONLY and HARDPOINT_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var scene:Node=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.size=Vector2i(1440,900)
	root.add_child(scene)
	scene.automation_args=[]
	var game=scene.game
	game.save_enabled=false
	if extended:game.damage_stats.set_enabled(true)
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
	var native_started:bool=game.native_execution!=null
	var native_rows:=[]
	if game.native_execution!=null:
		for row in game.native_execution.weapons:native_rows.append({"key":row.get("key",""),"hostile":row.get("hostile",false),"kind":row.get("kind",-1),"cd":row.get("cd",-1)})
	print("BATTLE_SETUP ",key," player=",Vector2(game.player.x,game.player.y)," enemies=",game.enemies.map(func(e):return Vector2(e.x,e.y))," native=",game.native_execution!=null," weapons=",native_rows)
	var metrics:Dictionary={"fires":0,"hits":0,"beams":0,"native_fires":0,"max_origin_error":0.0,"max_logical_error":0.0,"min_direct_aim_dot":1.0,"turn":0.0,"hull_bottom":0.0}
	var events:Dictionary={}
	var pending:Array=[]
	var slot_rows:Array=[]
	for slot in count:slot_rows.append({"slot":slot,"weapon":WEAPONS[slot],"fires":0,"impact_events":0,"beam_hit_events":0,"native_laser_fires":0,"damage":0.0,"max_origin_error":0.0,"max_logical_error":0.0,"min_direct_aim_dot":1.0,"min_trajectory_target_dot":1.0})
	game.event.connect(func(kind:String,info:Dictionary)->void:
		events[kind]=int(events.get(kind,0))+1
		if kind=="hit" and not bool(info.get("player",false)):metrics.hits+=1
		if kind=="beam_started" and info.has("shot") and not bool(info.shot.get("hostile",false)):metrics.beams+=1
		if kind=="projectile_impact" or kind=="beam_hit":
			var impact_shot:Dictionary=info.get("shot",{})
			var impact_laser:Dictionary=info.get("native_laser",{})
			if not bool(impact_shot.get("hostile",impact_laser.get("hostile",false))):
				var impact_slot:int=int(impact_shot.get("mount",impact_laser.get("mount",-1)))
				if impact_slot>=0 and impact_slot<count:
					if kind=="projectile_impact":slot_rows[impact_slot].impact_events+=1
					else:slot_rows[impact_slot].beam_hit_events+=1
		if kind!="fire":return
		var shot:Dictionary=info.get("shot",{})
		var laser:Dictionary=info.get("native_laser",{})
		if shot.is_empty() and laser.is_empty():return
		if bool(shot.get("hostile",laser.get("hostile",false))) or bool(laser.get("drone",false)):return
		var slot:int=int(shot.get("mount",laser.get("mount",-1)))
		if slot<0 or slot>=count:return
		metrics.fires+=1
		if not laser.is_empty():metrics.native_fires+=1
		slot_rows[slot].fires+=1
		if not laser.is_empty():slot_rows[slot].native_laser_fires+=1
		var ordinal:int=int(shot.get("salvo_ordinal",0))
		var launch:Vector2=scene.battle_point(Vector2(info.x,info.y))
		var logical:Vector2=scene.battle_slice_runtime.geometry.fleet_pose.screen_muzzle_for_slot(slot,ordinal)
		metrics.max_logical_error=maxf(float(metrics.max_logical_error),logical.distance_to(launch))
		slot_rows[slot].max_logical_error=maxf(float(slot_rows[slot].max_logical_error),logical.distance_to(launch))
		pending.append({"slot":slot,"ordinal":ordinal,"launch":launch,"direction":Vector2(info.get("direction",Vector2.ZERO)),"aim":scene.battle_point(Vector2(info.get("aim",Vector2(info.x,info.y))))})
	)
	var frames_run:int=0
	var all_fired_at:int=-1
	var heavy_fire_captured:bool=false
	for frame in (900 if extended else 180):
		await process_frame
		await RenderingServer.frame_post_draw
		frames_run=frame+1
		for record in pending:
			var slot:int=record.slot
			var module:Dictionary=scene.ship_view.modules[slot]
			var muzzle:Vector2=scene.ship_view.screen_muzzle_for_slot(slot,int(record.ordinal))
			metrics.max_origin_error=maxf(float(metrics.max_origin_error),muzzle.distance_to(record.launch))
			slot_rows[slot].max_origin_error=maxf(float(slot_rows[slot].max_origin_error),muzzle.distance_to(record.launch))
			if Vector2(record.direction).length_squared()>0.0:
				var trajectory_to_target:Vector2=Vector2(record.aim)-muzzle
				if trajectory_to_target.length_squared()>0.0:
					slot_rows[slot].min_trajectory_target_dot=minf(float(slot_rows[slot].min_trajectory_target_dot),trajectory_to_target.normalized().dot(Vector2(record.direction).normalized()))
				var ahead:Vector2=scene.ship_view.camera.unproject_position(module.muzzle.to_global(Vector3(0,0,-0.5)))
				var aim_dot:float=(ahead-muzzle).normalized().dot(trajectory_to_target.normalized()) if trajectory_to_target.length_squared()>0.0 else 1.0
				if WEAPONS[slot]!="missile":
					metrics.min_direct_aim_dot=minf(float(metrics.min_direct_aim_dot),aim_dot)
					slot_rows[slot].min_direct_aim_dot=minf(float(slot_rows[slot].min_direct_aim_dot),aim_dot)
		pending.clear()
		if extended and key=="Heavy_Battleship" and not heavy_fire_captured and int(slot_rows[4].fires)>0:
			var fire_image:String=output.path_join("battle-heavy-slot4-fire.png")
			assert(root.get_texture().get_image().save_png(fire_image)==OK,fire_image)
			heavy_fire_captured=true
		for module in scene.ship_view.modules:
			metrics.turn=maxf(float(metrics.turn),absf(module.pivot.rotation.y))
			var muzzle:Vector2=scene.ship_view.screen_muzzle_for_slot(int(module.slot))
			assert(muzzle.x>0 and muzzle.x<scene.ship_view.size.x and muzzle.y>0 and muzzle.y<scene.ship_view.size.y,key+" muzzle clipped")
		if extended:
			var complete:bool=true
			for row in slot_rows:
				if int(row.fires)==0:complete=false
			if complete and all_fired_at<0:all_fired_at=frames_run
			if all_fired_at>=0 and frames_run>=all_fired_at+120:break
	var plane:MeshInstance3D=scene.ship_view.approved_body_plane
	var opaque:Rect2=scene.ship_view.approved_body_bounds
	var texture_size:Vector2=((plane.material_override as StandardMaterial3D).albedo_texture as Texture2D).get_size()
	var mesh_size:Vector2=(plane.mesh as PlaneMesh).size
	for corner in [opaque.position,Vector2(opaque.end.x,opaque.position.y),Vector2(opaque.position.x,opaque.end.y),opaque.end]:
		var local:=Vector3((corner.x/texture_size.x-0.5)*mesh_size.x,0,(corner.y/texture_size.y-0.5)*mesh_size.y)
		var screen:Vector2=scene.ship_view.camera.unproject_position(plane.to_global(local))
		assert(screen.x>=0 and screen.x<=scene.ship_view.size.x and screen.y>=0 and screen.y<=scene.ship_view.size.y,key+" hull clipped")
		metrics.hull_bottom=maxf(float(metrics.hull_bottom),screen.y)
	if extended:
		for damage_row in game.damage_stats.snapshot().rows:
			var source:String=str(damage_row.source)
			if source.begins_with("module:"):
				var damage_slot:int=int(source.trim_prefix("module:"))
				if damage_slot>=0 and damage_slot<count:slot_rows[damage_slot].damage=float(damage_row.damage)
	print("BATTLE_DIAG ",key," frames=",frames_run," state=",game.state," native=",game.native_execution!=null," metrics=",metrics," slots=",slot_rows)
	assert(native_started and int(metrics.fires)>0 and int(metrics.hits)>0,key+" native combat not exercised")
	assert(float(metrics.max_origin_error)<0.1 and float(metrics.max_logical_error)<0.1,key+" muzzle/launch mismatch")
	assert(float(metrics.turn)>0.05,key+" turret never turned")
	if extended:
		for row in slot_rows:
			assert(int(row.fires)>0,key+" slot "+str(row.slot)+" never fired")
			assert(float(row.max_origin_error)<0.1,key+" slot "+str(row.slot)+" launch mismatch")
			if str(row.weapon)!="missile":assert(float(row.min_trajectory_target_dot)>0.95,key+" slot "+str(row.slot)+" target mismatch")
			if str(row.weapon)!="missile":assert(float(row.min_direct_aim_dot)>0.95,key+" slot "+str(row.slot)+" barrel/ray mismatch")
			if key=="Heavy_Battleship" and int(row.slot)==4:assert(float(row.min_direct_aim_dot)>0.985,"Heavy cannon slot 4 retarget regression")
	else:
		assert(float(metrics.min_direct_aim_dot)>0.95,key+" direct aim mismatch")
		RenderingServer.force_draw()
		var path:String=output.path_join("battle-"+key.to_lower()+"-full.png")
		assert(root.get_texture().get_image().save_png(path)==OK,path)
	var layer_path:String=output.path_join("battle-"+key.to_lower()+"-ship.png")
	assert(scene.ship_view.viewport.get_texture().get_image().save_png(layer_path)==OK,layer_path)
	metrics["reference_height"]=scene.reference_height
	metrics["hull_width"]=opaque.size.x/opaque.size.y*scene.reference_height
	var result_path:String=output.path_join("battle-"+key.to_lower()+("-all-slots-result.json" if extended else "-result.json"))
	var result:=FileAccess.open(result_path,FileAccess.WRITE)
	assert(result!=null,result_path)
	result.store_string(JSON.stringify({"hull":key,"slots":count,"weapons":WEAPONS.slice(0,count),"frames":frames_run,"all_fired_at":all_fired_at,"slot_results":slot_rows,"metrics":metrics,"events":events,"native":native_started},"  "))
	result.close()
	print("BATTLE_CAPTURE ",key," slots=",count," frames=",frames_run," slot_results=",slot_rows," metrics=",metrics," events=",events," native=",game.native_execution!=null," result=",result_path)
	quit()
