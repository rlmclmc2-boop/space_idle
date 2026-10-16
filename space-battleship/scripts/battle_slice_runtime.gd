extends RefCounted
## Direct battle slice: one gameplay Game; numeric geometry and typed effects.
## No Owner, mailbox, DisplayGame, object graph encoding or scene geometry providers.
const Geometry=preload("res://scripts/simulation_geometry_authority.gd")
const View=preload("res://scripts/simulation_geometry_view.gd")
const HOT=["fire","hit","beam_started","beam_hit","projectile_impact","explode","prototype_missile_retired","prototype_missile_reset","critical_impact"]
class Effect extends RefCounted:
	var kind:int
	var serial:int=0
	var uid:int=0
	var style:int=0 # 0 enemy,1 pulse,2 missile,3 rail,4 beam
	var position:=Vector2.ZERO
	var aim:=Vector2.ZERO
	var direction:=Vector2.UP
	var width:float=0.0
	var speed:float=0.0
	var critical:bool=false
	var damage_type:int=0
	var coast:bool=false
	var spread:float=0.0
var scene
var game:BattleGame
var geometry=Geometry.new()
var view=View.new()
var remainder:float=0.0
var logical_steps:int=0
var frame:Dictionary={}
var previous:Dictionary={}
var previous_spatial
var born:Dictionary={}
var muzzle_values:Dictionary={}
var started:=false
var advancing:=false
var detach_requested:=false
func install(root)->void:
	scene=root;game=root.game
	root.fixed_enemy_layout=true
	remainder=root.game_time_remainder
	root.time_step_game_id=game.get_instance_id()
	# A native owner may be selected inside an already-started legacy frame.
	# End that frame publication before display consumers use the new view.
	root.battle_read_model.end()
	geometry.prepare(root,game)
	previous_spatial=game.target_spatial_source
	for key in ["target_provider","launch_provider","drone_launch_provider","rail_geometry_provider","rail_target_point_provider"]:
		previous[key]=game.get(key)
	game.target_provider=geometry.target_point;game.launch_provider=geometry.launch_pose
	game.drone_launch_provider=geometry.drone_launch_pose;game.target_spatial_source=geometry.battle_read_model
	game.rail_geometry_provider=geometry.rail_geometry;game.rail_target_point_provider=geometry.entity_render_position
	scene.simulation_geometry_view=view
	snapshot()
	scene.ship_view.numeric_slice_only=true
	started=true
func sync_screen_scale(value:float)->bool:
	var scale_changed:bool=geometry.sync_screen_scale(value)
	var layout_changed:bool=geometry.sync_fixed_layout()
	if not scale_changed and not layout_changed:return false
	snapshot()
	scene.paused_presentation_signature=""
	# A zero-step/paused frame may keep the normal draw signature unchanged.
	scene.battle_layer.queue_redraw();scene.battle_hud_layer.queue_redraw()
	scene.pulse_layer.queue_redraw()
	return true
func advance(seconds:float)->void:
	if scene.battle_transition_blocked():return
	advancing=true
	if game.native_cancelled_step>0:
		remainder=maxf(0.0,remainder-game.native_cancelled_step);game.native_cancelled_step=0.0
	remainder+=seconds
	const STEP=1.0/60.0
	while remainder+0.0000000001>=STEP:
		# Return can begin inside the preceding substep. Keep unconsumed debt,
		# but do not prepare geometry or tick the restored mainline during departure.
		if scene.battle_transition_blocked():
			advancing=false;scene.game_time_remainder=remainder
			return
		if not game.prepare_logical_step(STEP):
			advancing=false;scene.game_time_remainder=remainder
			return
		geometry.before_tick(STEP)
		scene.fx_time=geometry.fx_time;scene.demo_time=geometry.demo_time
		scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
		if game.native_execution!=null:game.native_execution.prepare_geometry(geometry,game)
		scene.shield_before_hit=game.player.shield
		game.tick(STEP)
		if game.native_step_phase=="blocked":
			advancing=false;scene.game_time_remainder=remainder
			return
		geometry.after_tick()
		logical_steps+=1;remainder=maxf(0,remainder-STEP)
		if detach_requested:
			advancing=false
			if not close():return
			scene.battle_slice_runtime=null
			scene.game_time_remainder=remainder
			scene.advance_game_time(0.0)
			return
	snapshot()
	scene.game_time_remainder=remainder
	advancing=false
func snapshot()->void:
	geometry.sync_fixed_layout()
	var membership:Dictionary={}
	if game.native_execution!=null and game.native_execution.kernel.has_method("presentation_membership"):
		membership=game.native_execution.kernel.presentation_membership()
	var native_membership:bool=not membership.is_empty()
	if native_membership and membership.has("compact_laser_serials"):
		var live:Dictionary={}
		for serial in membership.compact_laser_serials:live[int(serial)]=true
		for serial in scene.native_laser_visuals.keys():
			if not live.has(serial):scene.native_laser_visuals.erase(serial)
	var retained:Dictionary={}
	for enemy in game.enemies:retained[int(enemy.uid)]=enemy
	# Labels and in-flight shots may still reference a departed target.
	for entry in scene.floats+scene.damage_pending:
		if entry.has("target_entity"):retained[int(entry.target_entity.uid)]=entry.target_entity
	# The native encounter retains every source/target actor in game.enemies.
	# Only the legacy handoff/old-extension path needs to discover extra owners.
	if not native_membership:
		for shot in game.projectiles:
			for entity in [shot.get("target",{}),shot.get("source",{})]:
				if not entity.is_empty() and entity.has("uid") and born.has(int(entity.uid)):retained[int(entity.uid)]=entity
	for uid in born.keys():
		if not retained.has(uid):
			born.erase(uid);view.retire(uid);geometry.retire_display_entity(uid)
	var active_serials:Dictionary={}
	if native_membership:
		for serial in membership.muzzle_serials:active_serials[int(serial)]=true
	elif not muzzle_values.is_empty():
		for shot in game.projectiles:active_serials[int(shot.serial)]=true
	for serial in muzzle_values.keys():
		if not active_serials.has(serial):muzzle_values.erase(serial)
	for enemy in retained.values():
		var uid=int(enemy.uid)
		if not born.has(uid):
			view.descriptor(uid,geometry.display_descriptor(enemy));born[uid]=true
		if not game.enemies.has(enemy):geometry.freeze_display_entity(enemy)
	# One final record, not an event-time world publication.
	geometry.finish_display_boundary()
	var values:Dictionary=geometry.display_frame(retained.values())
	view.apply(values);frame=values.fleet
	scene.fx_time=geometry.fx_time;scene.demo_time=geometry.demo_time
	scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
	var beam_shots:Array=membership.beams if native_membership else game.projectiles
	for shot in beam_shots:
		if str(shot.get("key","")) in ["longLaser","longLaser_mon","longLaser-mon"]:
			muzzle_values[int(shot.serial)]=geometry.visual_muzzle(shot)
func apply_nodes()->void:
	scene.ship_view.apply_geometry_frame(frame,scene.shield_enabled)
	scene.hyperspace_visual.apply_geometry_frame(scene.ship_view,frame,game.drone_combat.disabled)
func muzzle(shot:Dictionary)->Vector2:
	assert(muzzle_values.has(int(shot.serial)),"Display attempted an uncommitted muzzle query")
	return muzzle_values[int(shot.serial)]
func style(shot:Dictionary)->int:
	if bool(shot.get("hostile",false)):return 0
	var key:String=str(shot.get("chain_weapon","")) if bool(shot.get("chain_hop",false)) else geometry.weapon_key(shot)
	match key:
		"laser":return 1
		"missile":return 2
		"cannon":return 3
		"longLaser":return 4
	return 1
func on_event(kind:String,info:Dictionary)->bool:
	if info.has("native_laser"):
		var laser:Dictionary=info.native_laser
		if kind=="fire":
			if not bool(laser.drone) and bool(laser.owns_primary_aim) and int(laser.mount)>=0 and int(laser.mount)<game.weapon_entries().size():
				var pose=geometry.turret_pose(int(laser.mount))
				pose.target=laser.primary_target;pose.fired_at=geometry.fx_time
			# Reserve only the old decorative cap slot, not a shot/visual object.
			if scene.projectile_visuals.size()+scene.native_laser_visuals.size()<256:scene.native_laser_visuals[int(laser.serial)]=true
		var e=Effect.new();e.kind=0 if kind=="fire" else 4;e.style=1
		e.serial=int(laser.serial);e.position=Vector2(info.x,info.y);e.direction=info.direction;e.damage_type=int(info.type);e.critical=bool(info.critical)
		if kind!="fire":
			var distance:float=(e.position-Vector2(laser.launch)).dot(e.direction)
			e.position=geometry.battle_logical_point(Vector2(laser.ray_origin)+Vector2(laser.ray_step)*distance)
			e.direction=Vector2(laser.ray_step).normalized()
		consume(e)
		return true
	# These feedback events never mutate geometry. Preserve every damage record
	# without allocating an Effect and a second dictionary for the same hit.
	if kind=="hit":
		scene.queue_damage_number(info)
		if bool(info.player):
			if GrowthNumber.compare(scene.shield_before_hit,0)>0:scene.player_hit_at=geometry.fx_time
			scene.shield_before_hit=game.player.shield
		return true
	geometry.on_simulation_event(kind,info)
	if not kind in HOT:
		if kind=="encounter":snapshot()
		return false
	var e=Effect.new();e.kind=HOT.find(kind)
	match kind:
		"fire":
			var shot:Dictionary=info.shot
			e.serial=int(shot.serial);e.style=style(shot);e.damage_type=int(shot.get("type",0));e.spread=float(info.get("spread",0.0))
			if e.style!=4:
				e.position=Vector2(info.x,info.y);e.direction=Vector2(info.direction) if info.has("direction") else game.projectile_direction(shot)
				e.aim=Vector2(info.aim) if info.has("aim") else geometry.target_point(shot.target) if not shot.target.is_empty() else e.position+e.direction*100.0
				if e.style==3:
					e.direction=(geometry.battle_point(e.aim)-geometry.battle_point(e.position)).normalized()
					e.width=scene.rail_vfx.discharge_width(float(shot.get("rail_width_multiplier",1.0)))
				muzzle_values[e.serial]=e.position
				spawn_visual(shot,e)
				consume(e)
		"projectile_impact":
			var shot:Dictionary=info.shot
			e.serial=int(shot.serial);e.style=style(shot);e.damage_type=int(shot.get("type",0));e.position=Vector2(info.pos)
			e.direction=game.projectile_direction(shot);e.critical=bool(shot.get("critical",false))
			var visual:Dictionary=scene.projectile_visual(shot)
			if shot.has("fixed_screen_step"):
				# Feedback may arrive after this step moved the body. Use its committed birth ray.
				var distance:float=(e.position-Vector2(shot.launch_point)).dot(game.projectile_direction(shot))
				e.position=geometry.battle_logical_point(Vector2(shot.fixed_screen_origin)+Vector2(shot.fixed_screen_step)*distance)
				e.direction=Vector2(shot.fixed_screen_step).normalized()
			elif visual.has("fixed_step"):e.position=scene.straight_projectile_point(e.position,visual)
			consume(e)
		"explode":
			e.uid=int(info.get("uid",0));e.position=Vector2(info.x,info.y);e.width=34.0
			for enemy in game.enemies:
				if int(enemy.uid)==e.uid:
					e.position=geometry.battle_logical_point(geometry.enemy_render_position(enemy))
					e.width=geometry.enemy_render_width(enemy)
					scene.death_drop_positions[e.uid]=geometry.enemy_render_position(enemy)
					break
			consume(e)
			if e.uid==scene.encounter_presentation.leader_uid:scene.encounter_presentation.leader_fall=0.0
			if bool(info.get("boss",false)):scene.shake=maxf(scene.shake,float(scene.battle_visual.boss_destroy_shake))
			scene.beep(90)
		"prototype_missile_retired":
			e.serial=int(info.serial);e.style=2;e.position=info.position;e.direction=info.direction
			e.speed=float(info.speed);e.coast=bool(info.coast);consume(e)
		"prototype_missile_reset":scene.missile_events.clear()
		"beam_started","beam_hit":
			var shot:Dictionary=info.shot
			if bool(shot.get("hostile",false)):
				e.position=geometry.visual_muzzle(shot) if kind=="beam_started" else Vector2(info.pos) if info.has("pos") else geometry.target_point(shot.target)
				scene.weapon_flash(e.position,scene.ORANGE,7.0,0.08)
		"critical_impact":
			e.position=info.pos;e.direction=info.direction;consume(e)
	return true
func spawn_visual(shot:Dictionary,e:Effect)->void:
	if scene.projectile_visuals.size()+scene.native_laser_visuals.size()>=256:return
	var mount=geometry.shot_mount(shot)
	var angle=e.direction.angle()
	var visual:Dictionary
	if game.combat_presentation!=null:
		visual=game.combat_presentation.create_visual(shot,angle,mount,e.position,game.projectile_position(shot),e.spread)
	else:
		var trail=PackedVector2Array();trail.resize(14);trail.fill(e.position)
		var times=PackedFloat32Array();times.resize(14);times.fill(0.0)
		visual={"shot":shot,"angle":angle,"mount":mount,"origin":e.position,"logical_origin":game.projectile_position(shot),"spread":e.spread,"age":0.0,"head":0,"samples":1,"trail":trail,"trail_times":times}
	scene.projectile_visuals.append(visual)
	if game.combat_presentation!=null:game.combat_presentation.register_visual(shot,visual,scene.projectile_visuals.size()-1)
	if shot.has("fixed_screen_step"):
		visual.logical_origin=shot.launch_point
		visual.fixed_origin=shot.fixed_screen_origin;visual.fixed_step=shot.fixed_screen_step
		visual.fixed_direction=game.projectile_direction(shot);visual.angle=Vector2(visual.fixed_step).angle()
	elif geometry.weapon_key(shot) in ["laser","cannon"] and not shot.target.is_empty():
		var aim:Vector2=shot.get("ballistic_target_origin",Vector2(shot.target.x,shot.target.y))
		var target:Vector2=geometry.battle_point(aim) if shot.has("ballistic_target_origin") else geometry.entity_render_position(shot.target)
		visual.fixed_origin=geometry.battle_point(e.position)
		visual.fixed_step=(target-visual.fixed_origin)/maxf(game.projectile_position(shot).distance_to(aim),0.001)
		visual.fixed_direction=game.projectile_direction(shot);visual.angle=Vector2(visual.fixed_step).angle()
	if game.combat_presentation!=null:game.combat_presentation.bind_visual(visual)

func consume(e:Effect)->void:
	match e.kind:
		0: # all original launches retain a body and an emitter effect
			match e.style:
				0,1:record_contact(e,true,false)
				2:scene.missile_events.append({"kind":"fire","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":false})
				3:scene.rail_events.append({"kind":"fire","origin":e.position,"position":e.position,"direction":e.direction,"aim":e.aim,"full_width":e.width,"born":geometry.fx_time})
			if e.style==3:scene.railgun_sound("release")
			else:scene.beep(620 if e.damage_type==1 else 200)
		4:
			match e.style:
				0,1:record_contact(e,false,e.critical)
				2:scene.missile_events.append({"kind":"hit","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":e.critical,"serial":e.serial})
				3:scene.rail_events.append({"kind":"hit","origin":muzzle_values.get(e.serial,e.position),"position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":e.critical})
			if e.style==3:scene.railgun_sound("impact")
		5:
			if scene.destruction_events.size()>=24:scene.destruction_events.pop_front()
			scene.destruction_events.append({"position":e.position,"width":e.width,"born":geometry.fx_time,"seed":e.uid,"hyperspace":false})
		6:
			var coast=0.12 if e.coast else 0.0
			scene.missile_events.append({"kind":"retired","position":e.position,"direction":e.direction,"speed":e.speed,"serial":e.serial,"born":geometry.fx_time,"coast_time":coast,"duration":coast+0.18})
		8:
			scene.weapon_flash(e.position,Color.WHITE,14.0,0.08)
			scene.beam_ring(e.position,scene.ORANGE,0.12,11)
			scene.weapon_sparks(e.position,7,140,e.direction)
func request_legacy_display()->void:
	detach_requested=true
	if not advancing:
		if not close():return
		scene.battle_slice_runtime=null;scene.game_time_remainder=remainder
func close()->bool:
	if not started:return true
	if not scene.prepare_native_laser_display(true):return false
	started=false
	scene.ship_view.numeric_slice_only=false
	scene.simulation_geometry_view=null
	scene.enemy_poses=geometry.enemy_poses
	for record in geometry.boundary_dead_geometry.values():
		var slot:int=int(record.entity.slot)
		if not scene.enemy_poses.has(slot) or is_same(scene.enemy_poses[slot].entity,record.entity):scene.enemy_poses[slot]=record.pose
	scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
	# Move ownership: cleanup must not clear the containers now held by Main.
	geometry.enemy_poses={};geometry.turret_visuals={}
	# In-flight fixed rays need a live hull publisher after ownership returns.
	# Cold native admission may never have initialized Main's read model.
	scene.battle_read_model.setup(scene)
	scene.battle_read_model.invalidate_membership()
	if previous_spatial==null:previous_spatial=scene.battle_read_model
	geometry.close({"providers":previous,"spatial":previous_spatial})
	started=false
	return true

func record_contact(e:Effect,launch:bool,critical:bool)->void:
	if game.combat_presentation!=null:
		game.combat_presentation.record_contact(e.style,e.position,e.direction,geometry.fx_time,launch,critical,e.damage_type)
		return
	if e.style==0:
		var event={"position":e.position,"direction":e.direction,"born":geometry.fx_time,"damage_type":e.damage_type}
		if launch:event.kind="fire"
		scene._enemy_impacts.append(event)
	else:scene._pulse_events.append({"kind":"fire" if launch else "hit","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":critical})
