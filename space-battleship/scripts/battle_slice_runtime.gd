extends RefCounted
## Direct battle slice: one gameplay Game; numeric geometry and typed effects.
## No Owner, mailbox, DisplayGame, object graph encoding or scene geometry providers.
const Geometry=preload("res://scripts/simulation_geometry_authority.gd")
const View=preload("res://scripts/simulation_geometry_view.gd")
const HOT=["fire","hit","beam_started","beam_hit","projectile_impact","explode","prototype_missile_retired","prototype_missile_reset"]
class Effect extends RefCounted:
	var kind:int
	var serial:int=0
	var uid:int=0
	var style:int=0 # 0 enemy,1 pulse,2 missile,3 rail,4 beam
	var position:=Vector2.ZERO
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
var node_applies:int=0
var typed_events:int=0
var fire_events:int=0
var hit_events:int=0
var geometry_us:int=0
var effects_us:int=0
var frame:Dictionary={}
var previous:Dictionary={}
var previous_spatial
var born:Dictionary={}
var muzzle_values:Dictionary={}
var started:=false
func install(root)->void:
	assert(root.simulation_presenter==null,"Direct slice cannot enable the rejected bridge")
	scene=root;game=root.game
	geometry.prepare(root,game)
	previous_spatial=game.target_spatial_source
	for key in ["target_provider","launch_provider","drone_launch_provider","rail_geometry_provider","rail_target_point_provider"]:
		previous[key]=game.get(key);game.native_forget_observer(previous[key])
	game.target_provider=geometry.target_point;game.launch_provider=geometry.launch_pose
	game.drone_launch_provider=geometry.drone_launch_pose;game.target_spatial_source=geometry.battle_read_model
	game.rail_geometry_provider=geometry.rail_geometry;game.rail_target_point_provider=geometry.entity_render_position
	for cb in [geometry.target_point,geometry.launch_pose,geometry.drone_launch_pose,geometry.rail_geometry,geometry.entity_render_position]:
		game.native_transaction_observer(cb)
	scene.simulation_geometry_view=view
	snapshot()
	scene.ship_view.numeric_slice_only=true
	started=true
func advance(seconds:float)->void:
	remainder+=seconds
	const STEP=1.0/60.0
	while remainder+0.0000000001>=STEP:
		var began=Time.get_ticks_usec()
		geometry.before_tick(STEP)
		scene.fx_time=geometry.fx_time;scene.demo_time=geometry.demo_time
		scene.turret_visuals=geometry.turret_visuals;scene.turret_ship=geometry.turret_ship
		geometry_us+=Time.get_ticks_usec()-began
		game.tick(STEP);geometry.after_tick()
		logical_steps+=1;remainder=maxf(0,remainder-STEP)
	var began=Time.get_ticks_usec()
	snapshot();geometry_us+=Time.get_ticks_usec()-began
	scene.game_time_remainder=remainder
func snapshot()->void:
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
	var began=Time.get_ticks_usec()
	scene.ship_view.apply_geometry_frame(frame,scene.shield_enabled)
	scene.hyperspace_visual.apply_geometry_frame(scene.ship_view,frame,game.drone_combat.disabled)
	node_applies+=1;geometry_us+=Time.get_ticks_usec()-began
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
	var began=Time.get_ticks_usec()
	geometry.on_simulation_event(kind,info)
	if not kind in HOT:
		if kind=="encounter":snapshot()
		return false
	var e=Effect.new();e.kind=HOT.find(kind);typed_events+=1
	match kind:
		"fire":
			var shot:Dictionary=info.shot
			e.serial=int(shot.serial);e.style=style(shot);e.damage_type=int(shot.get("type",0));e.spread=float(info.get("spread",0.0));fire_events+=1
			if e.style!=4:
				e.position=geometry.visual_muzzle(shot);e.direction=game.projectile_direction(shot)
				muzzle_values[e.serial]=e.position
				spawn_visual(shot,e)
				consume(e)
		"hit":
			e.uid=int(info.get("uid",0));e.player=bool(info.player);e.damage_type=int(info.type)
			e.amount=info.amount;e.absorbed=info.get("absorbed",0.0);e.critical=bool(info.get("critical",false))
			hit_events+=1;consume(e)
		"projectile_impact":
			var shot:Dictionary=info.shot
			e.serial=int(shot.serial);e.style=style(shot);e.damage_type=int(shot.get("type",0));e.position=Vector2(info.pos)
			e.direction=game.projectile_direction(shot);e.critical=bool(shot.get("critical",false))
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
		"prototype_missile_retired":
			e.serial=int(info.serial);e.style=2;e.position=info.position;e.direction=info.direction
			e.speed=float(info.speed);e.coast=bool(info.coast);consume(e)
		"prototype_missile_reset":scene.missile_events.clear()
		"beam_started","beam_hit":pass # continuous beam renderer consumes the live beam record
	effects_us+=Time.get_ticks_usec()-began
	return true
func spawn_visual(shot:Dictionary,e:Effect)->void:
	if scene.projectile_visuals.size()>=256:return
	var mount=geometry.shot_mount(shot)
	var angle=e.direction.angle()
	var visual:Dictionary=game.native_pipeline.create_visual(shot,angle,mount,e.position,game.projectile_position(shot),e.spread)
	scene.projectile_visuals.append(visual)
	game.native_pipeline.register_visual(shot,visual,scene.projectile_visuals.size()-1)
	if geometry.weapon_key(shot) in ["laser","cannon"] and not shot.target.is_empty():
		var aim:Vector2=shot.get("ballistic_target_origin",Vector2(shot.target.x,shot.target.y))
		var target:Vector2=geometry.battle_point(aim) if shot.has("ballistic_target_origin") else geometry.entity_render_position(shot.target)
		visual.fixed_origin=geometry.battle_point(e.position)
		visual.fixed_step=(target-visual.fixed_origin)/maxf(game.projectile_position(shot).distance_to(aim),0.001)
		visual.fixed_direction=game.projectile_direction(shot);visual.angle=Vector2(visual.fixed_step).angle()
	game.native_pipeline.bind_visual(visual)
func consume(e:Effect)->void:
	match e.kind:
		0: # all original launches retain a body and an emitter effect
			match e.style:
				0,1:game.native_pipeline.record_contact(e.style,e.position,e.direction,geometry.fx_time,true,false,e.damage_type)
				2:scene.missile_events.append({"kind":"fire","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":false})
				3:scene.rail_events.append({"kind":"fire","origin":e.position,"position":e.position,"direction":e.direction,"aim":e.position+e.direction*800,"full_width":scene.rail_vfx.discharge_width(),"born":geometry.fx_time})
		1:
			scene.queue_damage_number({"player":e.player,"uid":e.uid,"type":e.damage_type,"amount":e.amount,"absorbed":e.absorbed,"critical":e.critical})
			if e.player:scene.player_hit_at=geometry.fx_time
		4:
			match e.style:
				0,1:game.native_pipeline.record_contact(e.style,e.position,e.direction,geometry.fx_time,false,e.critical,e.damage_type)
				2:scene.missile_events.append({"kind":"hit","position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":e.critical,"serial":e.serial})
				3:scene.rail_events.append({"kind":"hit","origin":muzzle_values.get(e.serial,e.position),"position":e.position,"direction":e.direction,"born":geometry.fx_time,"critical":e.critical})
		5:
			if scene.destruction_events.size()>=24:scene.destruction_events.pop_front()
			scene.destruction_events.append({"position":e.position,"width":e.width,"born":geometry.fx_time,"seed":e.uid,"hyperspace":false})
		6:
			var coast=0.12 if e.coast else 0.0
			scene.missile_events.append({"kind":"retired","position":e.position,"direction":e.direction,"speed":e.speed,"serial":e.serial,"born":geometry.fx_time,"coast_time":coast,"duration":coast+0.18})
func metrics()->Dictionary:
	return {"logical_steps":logical_steps,"node_applies":node_applies,"typed_events":typed_events,"fire_events":fire_events,"hit_events":hit_events,"geometry_us":geometry_us,"effects_us":effects_us,"one_game":scene.game==game,"bridge_enabled":scene.simulation_presenter!=null}
func close()->void:
	scene.ship_view.numeric_slice_only=false
	for key in previous:game.set(key,previous[key])
	game.target_spatial_source=previous_spatial
	scene.simulation_geometry_view=null
	geometry.close({"providers":previous,"spatial":previous_spatial})
	previous.clear();previous_spatial=null
	geometry=null;scene=null;game=null
