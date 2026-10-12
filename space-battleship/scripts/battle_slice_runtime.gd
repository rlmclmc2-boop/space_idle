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
	var player:bool=false
	var damage_type:int=0
	var amount:Variant=0.0
	var absorbed:Variant=0.0
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
func advance(seconds:float)->void:
	advancing=true
	remainder+=seconds
	const STEP=1.0/60.0
	while remainder+0.0000000001>=STEP:
		geometry.before_tick(STEP)
		scene.fx_time=geometry.fx_time;scene.demo_time=geometry.demo_time
		scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
		if game.native_execution!=null:game.native_execution.prepare_geometry(geometry,game)
		game.tick(STEP);geometry.after_tick()
		logical_steps+=1;remainder=maxf(0,remainder-STEP)
		if detach_requested:
			advancing=false
			close()
			scene.battle_slice_runtime=null
			scene.game_time_remainder=remainder
			scene.advance_game_time(0.0)
			return
	snapshot()
	scene.game_time_remainder=remainder
	advancing=false
func snapshot()->void:
	var retained:Dictionary={}
	for enemy in game.enemies:retained[int(enemy.uid)]=true
	# Labels and in-flight shots may still reference a departed target.
	for entry in scene.floats+scene.damage_pending:
		if entry.has("target_entity"):retained[int(entry.target_entity.uid)]=true
	for shot in game.projectiles:
		if not shot.target.is_empty() and shot.target.has("uid"):retained[int(shot.target.uid)]=true
	for uid in born.keys():
		if not retained.has(uid):
			born.erase(uid);view.retire(uid);geometry.retire_display_entity(uid)
	var active_serials:Dictionary={}
	for shot in game.projectiles:active_serials[int(shot.serial)]=true
	for serial in muzzle_values.keys():
		if not active_serials.has(serial):muzzle_values.erase(serial)
	for enemy in game.enemies:
		var uid=int(enemy.uid)
		if not born.has(uid):
			view.descriptor(uid,geometry.display_descriptor(enemy));born[uid]=true
	# One final record, not an event-time world publication.
	var values:Dictionary=geometry.display_frame(game.enemies)
	view.apply(values);frame=values.fleet
	scene.fx_time=geometry.fx_time;scene.demo_time=geometry.demo_time
	scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
	for shot in game.projectiles:
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
	match geometry.weapon_key(shot):
		"laser":return 1
		"missile":return 2
		"cannon":return 3
		"longLaser":return 4
	return 1
func on_event(kind:String,info:Dictionary)->bool:
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
				e.position=geometry.visual_muzzle(shot);e.direction=game.projectile_direction(shot)
				e.aim=geometry.target_point(shot.target) if not shot.target.is_empty() else e.position+e.direction*100.0
				if e.style==3:
					e.direction=(geometry.battle_point(e.aim)-geometry.battle_point(e.position)).normalized()
					e.width=scene.rail_vfx.discharge_width(float(shot.get("rail_width_multiplier",1.0)))
				muzzle_values[e.serial]=e.position
				spawn_visual(shot,e)
				consume(e)
		"hit":
			e.uid=int(info.get("uid",0));e.player=bool(info.player);e.damage_type=int(info.type)
			e.amount=info.amount;e.absorbed=info.get("absorbed",0.0);e.critical=bool(info.get("critical",false))
			consume(e)
		"projectile_impact":
			var shot:Dictionary=info.shot
			e.serial=int(shot.serial);e.style=style(shot);e.damage_type=int(shot.get("type",0));e.position=Vector2(info.pos)
			e.direction=game.projectile_direction(shot);e.critical=bool(shot.get("critical",false))
			var visual:Dictionary=scene.projectile_visual(shot)
			if visual.has("fixed_step"):e.position=scene.straight_projectile_point(e.position,visual)
			if not bool(shot.get("chain_hop",false)):consume(e)
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
				e.position=geometry.visual_muzzle(shot) if kind=="beam_started" else geometry.target_point(shot.target)
				scene.weapon_flash(e.position,scene.ORANGE,7.0,0.08)
		"critical_impact":
			e.position=info.pos;e.direction=info.direction;consume(e)
	return true
func spawn_visual(shot:Dictionary,e:Effect)->void:
	if scene.projectile_visuals.size()>=256:return
	var mount=geometry.shot_mount(shot)
	var angle=e.direction.angle()
	var trail=PackedVector2Array();trail.resize(14);trail.fill(e.position)
	var times=PackedFloat32Array();times.resize(14);times.fill(0.0)
	var visual:Dictionary={"shot":shot,"angle":angle,"mount":mount,"origin":e.position,"logical_origin":game.projectile_position(shot),"spread":e.spread,"age":0.0,"head":0,"samples":1,"trail":trail,"trail_times":times}
	scene.projectile_visuals.append(visual)
	if geometry.weapon_key(shot) in ["laser","cannon"] and not shot.target.is_empty():
		var aim:Vector2=shot.get("ballistic_target_origin",Vector2(shot.target.x,shot.target.y))
		var target:Vector2=geometry.battle_point(aim) if shot.has("ballistic_target_origin") else geometry.entity_render_position(shot.target)
		visual.fixed_origin=geometry.battle_point(e.position)
		visual.fixed_step=(target-visual.fixed_origin)/maxf(game.projectile_position(shot).distance_to(aim),0.001)
		visual.fixed_direction=game.projectile_direction(shot);visual.angle=Vector2(visual.fixed_step).angle()
func consume(e:Effect)->void:
	match e.kind:
		0: # all original launches retain a body and an emitter effect
			match e.style:
				0,1:record_contact(e,true,false)
				2:scene.missile_events.append({"kind":"fire","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":false})
				3:scene.rail_events.append({"kind":"fire","origin":e.position,"position":e.position,"direction":e.direction,"aim":e.aim,"full_width":e.width,"born":geometry.fx_time})
			if e.style==3:scene.railgun_sound("release")
			else:scene.beep(620 if e.damage_type==1 else 200)
		1:
			scene.queue_damage_number({"player":e.player,"uid":e.uid,"type":e.damage_type,"amount":e.amount,"absorbed":e.absorbed,"critical":e.critical})
			if e.player:scene.player_hit_at=geometry.fx_time
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
		close();scene.battle_slice_runtime=null;scene.game_time_remainder=remainder
func close()->void:
	scene.ship_view.numeric_slice_only=false
	scene.simulation_geometry_view=null
	scene.enemy_poses=geometry.enemy_poses
	geometry.close({"providers":previous,"spatial":previous_spatial})
	started=false

func record_contact(e:Effect,launch:bool,critical:bool)->void:
	if e.style==0:
		var event={"position":e.position,"direction":e.direction,"born":geometry.fx_time,"damage_type":e.damage_type}
		if launch:event.kind="fire"
		scene.enemy_impacts.append(event)
	else:scene.pulse_events.append({"kind":"fire" if launch else "hit","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":critical})
