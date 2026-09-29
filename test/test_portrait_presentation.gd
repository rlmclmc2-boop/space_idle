extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func capture(scene: Node, name: String) -> void:
	scene.refresh_draw_layers(0)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/portrait-"+name+".png")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.paused=true
	var original: Dictionary=scene.game.enemies[0].duplicate(true)
	var ordinary_group: int=scene.game.group_index
	var card=scene.equipment_panel.cards.weapons_0
	for boss in [false,true]:
		scene.game.group_index=scene.db.levels[0].groups.size() if boss else ordinary_group
		check(scene.game.is_boss_encounter()==boss,"fixture selects actual boss encounter")
		scene.game.enemies.clear()
		scene.enemy_poses.clear()
		for i in 10:
			var enemy: Dictionary=original.duplicate(true)
			enemy.slot=i
			enemy.uid=1000+i
			var slot_position := BattleGame.enemy_slot_position(i)
			enemy.x=slot_position.x
			enemy.y=slot_position.y
			enemy.size=6 if boss else 1
			scene.game.enemies.append(enemy)
			scene.enemy_pose(enemy)
		var simulation: Array=scene.game.enemies.duplicate(true)
		var rng_state: int=scene.game.rng.state
		var poses: Dictionary=scene.enemy_poses.duplicate(true)
		var safe := true
		var ordered := true
		var rear_line := true
		# Include approach, hover extrema and settled positions of all ten slots.
		for frame in 240:
			scene.fx_time+=1.0/30.0
			for i in 10:
				var enemy: Dictionary=scene.game.enemies[i]
				var point: Vector2=scene.enemy_render_position(enemy)
				var width: float=scene.enemy_render_width(enemy)
				var bounds := Rect2(point-Vector2(width*0.6,width*1.06),Vector2(width*1.2,width*2.12))
				safe = safe and bounds.position.x>=0 and bounds.end.x<=572 and bounds.position.y>=0 and bounds.end.y<650
				rear_line = rear_line and point.y<185.0 and enemy.y==BattleGame.ENEMY_LINE_Y
				if i>0:ordered = ordered and point.x>scene.enemy_render_position(scene.game.enemies[i-1]).x
		check(safe,"full formation stays within battle and above player: "+str(boss))
		check(ordered and rear_line,"ten slots stay left-to-right on one rear line: "+str(boss))
		check(scene.game.enemies==simulation and scene.game.rng.state==rng_state,"poses preserve ten slots, entities and combat RNG")
		check(scene.enemy_poses==poses,"entry and hover never regenerate random seeds")
		await capture(scene,"boss-ten" if boss else "normal-ten")
	scene.game.group_index=ordinary_group
	scene.enemy_poses.clear()
	for enemy in scene.game.enemies:
		enemy.size=1
		scene.enemy_pose(enemy)
	var hovering_enemy: Dictionary=scene.game.enemies[0]
	var logical_anchor := Vector2(hovering_enemy.x,hovering_enemy.y)
	scene.fx_time=float(scene.enemy_pose(hovering_enemy).born)+2.0
	var hover_min := Vector2.INF
	var hover_max := -Vector2.INF
	for frame in 240:
		scene.fx_time+=1.0/30.0
		var point: Vector2=scene.enemy_render_position(hovering_enemy)
		hover_min=hover_min.min(point)
		hover_max=hover_max.max(point)
	check(hover_max.x-hover_min.x>=14.0 and hover_max.y-hover_min.y>=11.0,"settled enemy visibly hovers within original formation")
	check(Vector2(hovering_enemy.x,hovering_enemy.y)==logical_anchor,"tactical hover leaves logical enemy position unchanged")
	# Ship proportions, HUD margin and actual module muzzle placement.
	for key in scene.SHIP_VISUALS.SOCKETS:
		scene.game.profile.selectedShip=key
		scene.game.profile.loadout=scene.game.empty_loadout(key)
		for i in scene.game.weapon_entries().size():scene.game.profile.loadout.weapons[i]={"key":["laser","cannon","missile"][i%3],"level":1}
		scene.refresh_structure()
		var position: Vector2=scene.player_render_position()
		var scale_value: float=scene.player_art_scale()
		check(position.y/960.0>=0.82 and position.y/960.0<=0.92,"player sits at lower battle line "+key)
		var hull_tail: float=position.y+scene.SHIP_VISUALS.CANVAS.x*float(scene.battle_visual.player_core_scale)*scale_value/2
		var hud_gap: float=1132.0-scene.BATTLE_ORIGIN.y-hull_tail
		check(hud_gap>=float(scene.battle_visual.player_hud_gap) and hud_gap<=70.0,"compact engine-to-HUD gap "+key)
		var gap_safe := true
		var player_front: float=position.y-(scene.SHIP_VISUALS.CANVAS.x*0.65/2.0+535.0*absf(sin(scene.player_idle_angle())))*scale_value
		for enemy in scene.game.enemies:
			var point: Vector2=scene.enemy_render_position(enemy)
			gap_safe=gap_safe and point.y<=scene.BATTLE_VIEW_SIZE.y*scene.battle_visual.enemy_max_y and player_front-point.y-scene.enemy_render_width(enemy)*1.06>=scene.BATTLE_VIEW_SIZE.y*scene.battle_visual.enemy_player_min_gap
		check(gap_safe,"hull-to-hull firing corridor retained on ship change "+key)
		var front_enemy: Dictionary=scene.game.enemies[8]
		var pose_for_clamp: Dictionary=scene.enemy_pose(front_enemy)
		var old_target: Vector2=pose_for_clamp.target
		pose_for_clamp.target.y=900.0
		check(scene.enemy_render_position(front_enemy).y<=scene.enemy_frontline_y_limit(front_enemy),"final animated Y cannot cross front-line limit "+key)
		pose_for_clamp.target=old_target
		for i in scene.game.weapon_entries().size():
			var original_muzzle: Vector2=scene.game.player_weapon_offset(i)
			var expected: Vector2=position+(scene.player_mount_center(key,i)+Vector2(scene.SHIP_VISUALS.module_width(key)/2,0)).rotated(-PI/2+scene.player_idle_angle())*scale_value
			check(scene.battle_point(scene.turret_muzzle(i)).distance_to(expected)<0.001,"repacked barrel matches visible muzzle "+key+str(i))
			check(scene.game.player_weapon_offset(i)==original_muzzle,"logical muzzle preserved")
		await capture(scene,key)
	# Non-homing paths snapshot the rendered endpoint once, including the expanded corridor.
	for key in ["laser","cannon"]:
		scene.game.projectiles.clear()
		scene.projectile_visuals.clear()
		var target: Dictionary=scene.game.enemies[8]
		scene.game.fire(scene.game.player,target,scene.db.equip(key,1),1,false,key,scene.game.player_weapon_offset(0))
		var shot: Dictionary=scene.game.projectiles.back()
		var visual: Dictionary=scene.projectile_visuals.back()
		var start: Vector2=scene.battle_point(visual.origin)
		var end: Vector2=scene.entity_render_position(target)
		check(start.y-end.y>=192,key+" visible flight spans the firing corridor")
		scene.game.tick_projectiles(0.01)
		var before: Vector2=scene.missile_visual_position(shot,0,visual.origin,visual)
		scene.fx_time+=0.4
		check(scene.missile_visual_position(shot,0,visual.origin,visual).is_equal_approx(before),key+" flight does not follow target hover")
		var on_ray: Vector2=scene.battle_point(before)-start
		check(absf(on_ray.cross((end-start).normalized()))<0.001,key+" display stays on its launch line")
	scene.game.projectiles.clear()
	scene.projectile_visuals.clear()
	# Animation lifetime: 10 simulated hours, constant mesh and pose identities.
	var node_count: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mesh=scene.stars_mesh
	var pose: Dictionary=scene.enemy_poses[0]
	var particle_count: int=scene.particles.size()
	for i in 36000:
		scene.fx_time+=1.0
		for enemy in scene.game.enemies:
			scene.enemy_render_position(enemy)
			scene.enemy_render_width(enemy)
	check(scene.enemy_poses.size()==10 and is_same(pose,scene.enemy_poses[0]),"ten-hour pose reuse remains bounded")
	check(scene.stars_mesh==mesh and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==node_count and scene.particles.size()==particle_count,"idle creates no nodes, meshes or particles")
	check(scene.stars_mesh.get_surface_count()==1 and scene.stars.size()==200,"three background layers share one fixed mesh and 200 seeds")
	check(scene.stars.filter(func(star):return star.z>0.965).size()==8 and scene.stars.filter(func(star):return star.z>0.87 and star.z<0.965).size()==18,"fixed sparse mid and near layer populations")
	check(scene.battle_visual.background_far_speed<scene.battle_visual.background_mid_speed and scene.battle_visual.background_mid_speed<scene.battle_visual.background_near_speed,"parallax speeds ordered by distance")
	var particle_before_event: int=scene.particles.size()
	scene.fx_time=float(scene.battle_visual.environment_event_interval)+0.6
	await capture(scene,"environment-event")
	check(scene.particles.size()==particle_before_event,"low-frequency event reuses draw layer without particles")
	scene.fx_time+=2.0
	check(scene.particles.size()==particle_before_event,"expired environment event retains no objects")
	var static_draws := [0]
	var star_draws := [0]
	scene.background_layer.draw.connect(func():static_draws[0]+=1)
	scene.stars_layer.draw.connect(func():star_draws[0]+=1)
	scene.refresh_draw_layers(0)
	await process_frame
	await RenderingServer.frame_post_draw
	static_draws[0]=0
	star_draws[0]=0
	var frozen: float=scene.fx_time
	for i in 5:
		scene._process(0.1)
		await process_frame
	check(scene.fx_time==frozen and star_draws[0]==0 and static_draws[0]==0,"paused animation freezes without background redraw")
	check(scene.equipment_panel.cards.weapons_0==card,"battle animation retains unrelated equipment card")
	scene.game.enemies.clear()
	scene.refresh_draw_layers(0)
	check(scene.enemy_poses.is_empty(),"departed encounter releases all poses")
	var fixture_slots: Array = []
	for i in 10:fixture_slots.append(int(original.id))
	scene.db.groups["999998"]={"slots":fixture_slots}
	scene.db.levels[0].groups=[{"id":999998,"position":0.0}]
	scene.game.group_index=0
	scene.game.spawn_group()
	var spawned_in_line: bool = scene.game.enemies.size()==10
	for enemy in scene.game.enemies:
		spawned_in_line = spawned_in_line and Vector2(enemy.x,enemy.y).is_equal_approx(BattleGame.enemy_slot_position(int(enemy.slot)))
	check(spawned_in_line,"actual group spawn places ten configured slots on one rear line")
	fixture_slots[4]=null
	scene.game.group_index=0
	scene.game.spawn_group()
	check(scene.game.enemies.size()==9 and scene.game.enemies[4].slot==5 and Vector2(scene.game.enemies[4].x,scene.game.enemies[4].y).is_equal_approx(BattleGame.enemy_slot_position(5)),"empty slot does not shift later positions")
	print("Portrait presentation: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	quit(1 if failures else 0)
