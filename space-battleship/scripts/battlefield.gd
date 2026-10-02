extends "res://scripts/main.gd"
## Live battle presentation. Save, inventory and unlock authority remains BattleGame.

const PROTOTYPE_GAME := preload("res://scripts/presented_battle_game.gd")
const ENEMY_VFX := preload("res://dev/toon_ship/enemy_weapon_vfx.gd")
var enemy_vfx_enabled:=true
var enemy_launch_context:=false
var enemy_impacts:Array[Dictionary]=[]
const CHAIN_VFX := preload("res://dev/toon_ship/chain_vfx.gd")
const MISSILE_VFX := preload("res://dev/toon_ship/missile_vfx.gd")
const CONTINUOUS_BEAM_VFX := preload("res://dev/toon_ship/continuous_beam_vfx.gd")
const RAIL_VFX := preload("res://dev/toon_ship/rail_vfx.gd")
var rail_vfx = RAIL_VFX.new()
const PULSE_VFX := preload("res://dev/toon_ship/pulse_vfx.gd")
const SHIP_VIEW := preload("res://scripts/presented_ship_view.gd")

@export_group("Toon ship prototype")
@export_range(0.0,1.0,0.01) var toon_shadow_threshold := 0.60
@export_range(2,5,1) var toon_steps := 3
@export_range(0.0,1.0,0.01) var rim_strength := 0.22
@export_range(1.0,12.0,0.1) var rim_power := 4.5
@export_range(0.0,0.3,0.01) var specular_strength := 0.04
# Reserved because precision outlines are deliberately excluded from this prototype.
@export_range(0.0,2.0,0.1) var outline_strength := 0.0
@export_range(0.0,3.0,0.1) var emission_strength := 1.0
@export_range(0.0,4.0,0.1) var engine_emission := 1.4
@export_range(0.0,0.6,0.01) var shield_opacity := 0.12
@export var toon_enabled := true
@export var rim_enabled := true
@export var shield_enabled := true

var effects_enabled := true
var ship_view
var prototype_enabled := true
var close_up := false
var demo_time := 0.0
var pulse_layer: Node2D
var reference_height := 0.0
var reference_offset := Vector2.ZERO
var requested_exit := false
var prototype_frames := 0
var capture_directory := ""
var parameters_signature := ""
var paused_presentation_signature := ""
var fixture_name := ""
var current_hull := ""
var protect_silhouette := false
var missile_vfx_enabled := true
var continuous_beam_enabled := true
var missile_events: Array[Dictionary] = []
var missile_launch_context := false
var missile_density := 0
var missile_fire_count := 0
var missile_hit_count := 0
var missile_origin_max_error := 0.0
var missile_fire_slots: Dictionary = {}
var missile_loss_count := 0
var missile_loss_max_jump := 0.0
var rail_vfx_enabled := true
var rail_events: Array[Dictionary] = []
var rail_launch_context := false
var rail_fire_count := 0
var rail_hit_count := 0
var rail_origin_max_error := 0.0
var rail_fire_slots: Dictionary = {}
var pulse_vfx_enabled := true
var pulse_events: Array[Dictionary] = []
var pulse_launch_context := false
var pulse_fire_count := 0
var pulse_hit_count := 0
var pulse_origin_max_error := 0.0
var pulse_fire_slots: Dictionary = {}
var beam_full_started:Dictionary={}
var beam_full_cue_count:=0
var hull_opaque_bounds: Dictionary = {}
var player_hit_at := -100.0
var shield_before_hit: Variant = 0.0
var destruction_events: Array[Dictionary] = []
var stable_center := Vector2.ZERO
var stable_center_ready := false


func _ready() -> void:
	super._ready()
	rail_vfx.configure(db)
	# Resolve the six fixed enemy silhouettes before gameplay starts, so a new
	# encounter never loads a hull or reads its pixels inside the draw callback.
	prepare_enemy_hulls()
	ship_view = SHIP_VIEW.new()
	ship_view.name = "BattleShipView"
	ship_view.size = BATTLE_VIEW_SIZE
	battle_clip.add_child(ship_view)
	battle_clip.move_child(ship_view,battle_layer.get_index())
	ship_view.set_hull(str(game.profile.selectedShip))
	current_hull = str(game.profile.selectedShip)
	ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
	pulse_layer = Node2D.new()
	pulse_layer.name = "BattleFeedback"
	pulse_layer.z_index = 2
	battle_clip.add_child(pulse_layer)
	pulse_layer.draw.connect(_draw_muzzle_cues)
	_set_reference_dimensions()
	_sync_parameters()
	ship_view.set_pose(player_render_position(),reference_height,0.0,player_render_position()+Vector2(0,-450),demo_time,false,false)


func create_battle_game(persist:bool)->BattleGame:
	var prototype=PROTOTYPE_GAME.new(db,persist)
	db=prototype.db
	prototype.launch_provider=_prototype_launch_pose
	prototype.target_provider=_prototype_target_point
	return prototype


func _prototype_target_point(target:Dictionary)->Vector2:
	return battle_logical_point(entity_render_position(target))


func _prototype_launch_pose(slot:int,aim:Vector2,ordinal:int)->Dictionary:
	if not is_instance_valid(ship_view):
		var fallback:=Vector2(game.player.x,game.player.y)+game.player_weapon_offset(slot)
		return {"position":fallback,"direction":(aim-fallback).normalized()}
	var angles:Array=[]
	for index in game.weapon_entries().size():angles.append(turret_angle(index))
	ship_view.set_slot_angles(angles)
	var point:Vector2=ship_view.screen_muzzle_for_slot(slot,ordinal)
	# Canonical battlefield coordinates are independent of viewport pixels and
	# paused close-up inspection magnification.
	if close_up:point=player_render_position()+reference_offset+(point-ship_view.rendered_position)/2.8
	var logical:=battle_logical_point(point)
	return {"position":logical,"direction":(aim-logical).normalized()}


func visual_muzzle(shot:Dictionary)->Vector2:
	if bool(shot.get("prototype_missile",false)):return Vector2(shot.launch_point)
	return super.visual_muzzle(shot)


func _set_reference_dimensions() -> void:
	# Match the existing hull's opaque footprint, not its transparent source canvas.
	var image := ship_hull_texture(str(game.profile.selectedShip)).get_image()
	var rect := image.get_used_rect()
	var factor: float = float(battle_visual.player_core_scale)*player_art_scale()
	reference_height = float(rect.size.y)*factor
	# Frame the combined formation at battle scale, never enlarge the original hull footprint.
	# Reserve 10% side margin for ordinary idle yaw; diagnostic rear angles do not widen gameplay aim.
	reference_height = minf(reference_height,BATTLE_VIEW_SIZE.x*0.90*ship_view.model_span/ship_view.formation_width)
	# Reduce only the large own-ship classes; tiny frigates keep their legibility.
	reference_height *= 0.74 if str(game.profile.selectedShip)=="Heavy_Battleship" else 0.85 if str(game.profile.selectedShip)=="Battleship" else 1.0
	stable_center_ready=false
	reference_offset = Vector2.ZERO # The modular hull origin is its own center, not the PNG canvas center.


func _sync_parameters() -> void:
	var settings := {"toon_shadow_threshold":toon_shadow_threshold,"toon_steps":toon_steps,
		"rim_strength":rim_strength,"rim_power":rim_power,"specular_strength":specular_strength,
		"outline_strength":outline_strength,"emission_strength":emission_strength,
		"engine_emission":engine_emission,"shield_opacity":shield_opacity}
	var signature := str(settings)+str(toon_enabled)+str(rim_enabled)
	if signature != parameters_signature:
		parameters_signature = signature
		ship_view.apply_parameters(settings,toon_enabled,rim_enabled)


func _process(delta: float) -> void:
	if is_instance_valid(ship_view):
		ship_view.set_accelerated_quality(game.speed >= 10.0)
		if current_hull != str(game.profile.selectedShip):
			current_hull = str(game.profile.selectedShip)
			if not ship_view.set_hull(current_hull):
				prototype_enabled = false
				ship_view.set_rendering(false)
				return
			_set_reference_dimensions()
		ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
	# Update the canonical carrier pose before simulation asks for release points.
	if is_instance_valid(ship_view) and not game.paused:
		demo_time+=delta
		var aim:Vector2=player_render_position()+Vector2(0,-450)
		if not game.enemies.is_empty():aim=enemy_render_position(game.enemies[0])
		ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,aim,demo_time,shield_enabled,close_up,delta)
	shield_before_hit = game.player.shield
	super._process(delta)
	destruction_events = destruction_events.filter(func(e):return fx_time-float(e.born)<0.65)
	var valid_beams:Dictionary={}
	for shot in game.projectiles:
		if not bool(shot.get("beam",false)) or bool(shot.hostile) or not game.long_laser_valid(shot):continue
		var serial:=int(shot.serial)
		valid_beams[serial]=true
		if int(shot.ticks)>0 and float(beam_style(shot).power)>=0.999999 and not beam_full_started.has(serial):
			beam_full_started[serial]=fx_time;beam_full_cue_count+=1
	for serial in beam_full_started.keys():
		if not valid_beams.has(serial):beam_full_started.erase(serial)
	if not is_instance_valid(ship_view): return
	missile_events = missile_events.filter(func(e):return fx_time-float(e.born)<float(e.get("duration",0.25)))
	if accelerated_visual_mode:missile_events.clear()
	rail_events = rail_events.filter(func(e):return fx_time-float(e.born)<maxf(rail_vfx.flash_seconds,rail_vfx.impact_seconds))
	if accelerated_visual_mode:rail_events.clear()
	enemy_impacts=enemy_impacts.filter(func(e):return fx_time-float(e.born)<0.12)
	if accelerated_visual_mode:enemy_impacts.clear()
	pulse_events = pulse_events.filter(func(e):return fx_time-float(e.born)<0.14)
	prototype_frames += 1
	_sync_parameters()
	var anchor := _stable_player_anchor()
	if not stable_center_ready:
		stable_center=anchor
		stable_center_ready=true
	elif not game.paused and battle_layer.visible:
		stable_center=stable_center.lerp(anchor,1.0-exp(-3.0*minf(delta,0.1)))
	var target := player_render_position()+Vector2(0,-450)
	if not game.enemies.is_empty(): target = enemy_render_position(game.enemies[0])
	var pose_signature := str([current_hull,ship_view.loadout_signature,game.player.shield,parameters_signature,prototype_enabled,close_up,shield_enabled,battle_layer.visible,game.paused,player_render_position(),target,fx_time])
	if game.paused and pose_signature==paused_presentation_signature: return
	paused_presentation_signature = pose_signature
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,target,demo_time,shield_enabled,close_up,0.0)
	ship_view.shield.visible = shield_enabled and GrowthNumber.compare(game.player.shield,0)>0
	ship_view.shield_material.set_shader_parameter("impact_strength",maxf(0.0,1.0-(fx_time-player_hit_at)/0.38))
	var angles: Array = []
	for index in game.weapon_entries().size(): angles.append(turret_angle(index))
	ship_view.set_slot_angles(angles)
	for plume in ship_view.exhaust_nodes: plume.visible = effects_enabled
	var alive: bool = GrowthNumber.compare(game.player.armour,0)>0 or game.state==BattleGame.State.RETREAT
	ship_view.set_rendering(prototype_enabled and alive and battle_layer.visible,game.paused)
	pulse_layer.visible = ship_view.visible and effects_enabled
	pulse_layer.queue_redraw()


func _draw_muzzle_cues() -> void:
	# Read existing presentation fire timestamps only. No synthetic shots, recoil,
	# RNG, hit timing or combat events are generated by this small foreground cue.
	if not effects_enabled or not prototype_enabled: return
	for module in ship_view.modules:
		if missile_vfx_enabled and str(module.key)=="missile":continue
		if rail_vfx_enabled and str(module.key)=="cannon":
			_draw_rail_charge(module)
			continue
		if pulse_vfx_enabled and str(module.key)=="laser":continue
		var pose: Dictionary = turret_visuals.get(int(module.slot),{})
		var age := fx_time-float(pose.get("fired_at",-100.0))
		if age<0.0 or age>0.12: continue
		var fade := 1.0-age/0.12
		var point: Vector2 = ship_view.screen_muzzle_for_slot(int(module.slot))
		var ahead: Vector2 = ship_view.camera.unproject_position(module.muzzle.to_global(Vector3(0,0,-0.5)))
		var direction := (ahead-point).normalized()
		var across := Vector2(-direction.y,direction.x)
		var color := Color("ffbf75") if str(module.key) in ["missile","cannon"] else Color("96f6ff")
		color.a = fade
		# Short directional stroke keeps the precise exit visible without covering
		# the turret with a broad bloom disk. It is intentionally a 2D overlay.
		pulse_layer.draw_line(point,point+direction*(9.0+6.0*fade),color,2.0,true)
		pulse_layer.draw_line(point+direction*3.0-across*3.0*fade,point+direction*3.0+across*3.0*fade,Color(1,1,1,fade),1.5,true)

	for event in destruction_events:
		var age:=fx_time-float(event.born)
		var progress:=clampf(age/0.65,0.0,1.0)
		var point:=battle_point(event.position)
		var radius:=clampf(float(event.width)*0.45,12.0,40.0)
		for piece in 7:
			var angle:=float(piece)*TAU/7.0+float(event.seed)*0.7
			var center:=point+Vector2.from_angle(angle)*radius*(0.25+progress*1.8)
			var extent:=Vector2(4.0,7.0)*(1.0-progress)
			pulse_layer.draw_set_transform(center,angle+progress)
			pulse_layer.draw_rect(Rect2(-extent,extent*2),Color(Color("bc8060") if piece%2==0 else Color("384c59"),1.0-progress))
		pulse_layer.draw_set_transform(Vector2.ZERO)
		pulse_layer.draw_circle(point,radius*(0.3+progress),Color(Color("d9a477"),maxf(0.0,0.28-age*1.5)))
		if age<0.22:pulse_layer.draw_circle(point,radius*(0.5-age*1.5),Color(Color("f5e4bd"),1.0-age/0.22))
	for event in enemy_impacts:
		if event.get("kind","")=="fire":
			var age:=fx_time-float(event.born)
			var point:=battle_point(event.position)
			pulse_layer.draw_line(point,point+Vector2(event.direction)*4.0,Color(Color("e2a36b"),maxf(0.0,1.0-age/0.12)),2.0,true)
			continue
		ENEMY_VFX.impact(pulse_layer,battle_point(event.position),event.direction,fx_time-float(event.born),event.key)
	if pulse_vfx_enabled:
		for event in pulse_events:
			var age:=fx_time-float(event.born)
			var point:=battle_point(Vector2(event.position))
			if event.kind=="fire":PULSE_VFX.flash(pulse_layer,point,event.direction,age)
			else:PULSE_VFX.impact(pulse_layer,point,event.direction,age,bool(event.critical))

	if rail_vfx_enabled:
		# Only brightness budgets overlap. Every shot still has a core and event.
		var budget:=clampf(1.5/sqrt(maxf(1.0,float(rail_events.size()))),0.42,1.0)
		for event in rail_events:
			var age:=fx_time-float(event.born)
			var point:=battle_point(Vector2(event.position))
			if event.kind=="fire":rail_vfx.flash(pulse_layer,point,event.direction,age,budget)
			else:
				rail_vfx.penetration(pulse_layer,battle_point(Vector2(event.origin)),point,event.direction,age,budget,BATTLE_VIEW_SIZE)
				rail_vfx.impact(pulse_layer,point,event.direction,age,bool(event.critical),budget)

	if missile_vfx_enabled:
		var budget:=clampf(2.0/sqrt(maxf(1.0,float(missile_events.size()))),0.45,1.0)
		for event in missile_events:
			var age:=fx_time-float(event.born)
			var point:=battle_point(Vector2(event.position))
			if event.kind=="retired":
				var coast_time:float=minf(age,float(event.coast_time))
				point=battle_point(Vector2(event.position)+Vector2(event.direction)*float(event.speed)*coast_time)
				if age<float(event.coast_time):MISSILE_VFX.flight(pulse_layer,point,event.direction,1.0,int(event.serial),1.0,true,false)
				else:MISSILE_VFX.retire(pulse_layer,point,event.direction,age-float(event.coast_time))
			elif event.kind=="fire":MISSILE_VFX.flash(pulse_layer,point,event.direction,age,budget)
			else:MISSILE_VFX.impact(pulse_layer,point,event.direction,age,bool(event.critical),budget,int(event.serial))


func on_event(kind:String,info:Dictionary)->void:
	if kind=="projectile_impact" and info.shot.get("chain_hop",false):return
	if kind=="hit" and bool(info.get("player",false)):
		if GrowthNumber.compare(shield_before_hit,0)>0:player_hit_at=fx_time
	if kind=="explode":
		if info.has("slot"):death_drop_positions[int(info.uid)]=enemy_drop_anchor(info)
		if fast_mode_enabled():return
		var point:=visual_effect_point(Vector2(info.x,info.y))
		var width:=34.0
		for enemy in game.enemies:
			if int(enemy.uid)==int(info.get("uid",-1)):
				point=battle_logical_point(enemy_render_position(enemy));width=enemy_render_width(enemy)
		if destruction_events.size()>=24:destruction_events.pop_front()
		destruction_events.append({"position":point,"width":width,"born":fx_time,"seed":int(info.get("uid",0))})
		if bool(info.get("boss",false)):shake=maxf(shake,float(battle_visual.boss_destroy_shake))
		beep(90)
		return
	if kind=="prototype_missile_reset":
		missile_events.clear();return
	if kind=="prototype_missile_retired":
		if not missile_vfx_enabled:return
		var coast_time:=0.12 if bool(info.coast) else 0.0
		missile_events.append({"kind":"retired","position":info.position,"direction":info.direction,"speed":info.speed,"serial":info.serial,"born":fx_time,"coast_time":coast_time,"duration":coast_time+0.18})
		return
	if kind=="projectile_impact" and bool(info.shot.get("prototype_missile",false)):
		weapon_impact(info.shot,Vector2(info.pos));return
	if prototype_enabled and continuous_beam_enabled and kind in ["beam_started","beam_hit"] and info.has("shot") and not bool(info.shot.hostile):
		# The active beam draws its own emitter/contact. Do not enqueue legacy
		# endpoint flashes or a cache that creates a shrinking tail on shutdown.
		if kind=="beam_started" and not fast_mode_enabled() and int(info.shot.mount)>=0:
			turret_pose(int(info.shot.mount)).fired_at=fx_time
		return
	super.on_event(kind,info)


func sync_beam_visuals()->void:
	if prototype_enabled and continuous_beam_enabled:
		beam_visuals=beam_visuals.filter(func(v):return bool(v.shot.hostile))
	super.sync_beam_visuals()


func draw_projectile_body_override(shot:Dictionary,pos:Vector2,angle:float)->bool:
	if shot.get("chain_hop",false):
		var logical:=Vector2(shot.x,shot.y)
		CHAIN_VFX.flight(draw_surface,pos,battle_point(logical+Vector2(shot.direction))-battle_point(logical))
		return true
	if not _is_own_missile(shot):return false
	var visual:=projectile_visual(shot)
	# Every real missile, including an orphan, retains one physical body.
	MISSILE_VFX.flight(draw_surface,pos,Vector2.from_angle(angle),float(shot.get("motion_age",visual.get("age",0.0))),int(shot.get("serial",0)),0.4 if missile_density>6 else 1.0,true,not shot.target.is_empty())
	return true


func draw_beam_override(shot:Dictionary,offset:Vector2,core:bool=true)->bool:
	if not prototype_enabled or not continuous_beam_enabled or bool(shot.hostile):return false
	if not core:return true # Suppress the legacy behind-hull envelope.
	var muzzle:=battle_point(visual_muzzle(shot))+offset
	var target:=entity_render_position(shot.target)+offset
	if float(shot.charge)>0 and float(shot.elapsed)<float(shot.charge):
		CONTINUOUS_BEAM_VFX.charge(draw_surface,muzzle,target,float(shot.elapsed)/float(shot.charge),fx_time)
	elif int(shot.ticks)>0:
		var style:=beam_style(shot)
		CONTINUOUS_BEAM_VFX.active(draw_surface,muzzle,target,fx_time,float(style.width),float(style.power),float(style.pulse))
		if beam_full_started.has(int(shot.serial)):
			CONTINUOUS_BEAM_VFX.full_cue(draw_surface,target,fx_time-float(beam_full_started[int(shot.serial)]))
		for linked in game.beam_chain_targets(shot):
			CHAIN_VFX.link(draw_surface,target,entity_render_position(linked)+offset,fx_time)
	return true


func _is_own_missile(shot:Dictionary)->bool:
	return prototype_enabled and missile_vfx_enabled and not bool(shot.get("hostile",false)) and weapon_key(shot)=="missile"


func missile_visual_position(shot:Dictionary,spread:float,origin:Vector2,visual:Dictionary={})->Vector2:
	if bool(shot.get("prototype_missile",false)):return Vector2(shot.x,shot.y)
	if not _is_own_missile(shot):return super.missile_visual_position(shot,spread,origin,visual)
	if visual.is_empty():visual=projectile_visual(shot)
	var logical:=Vector2(shot.x,shot.y)
	if visual.has("orphan_offset"):return logical+Vector2(visual.orphan_offset)
	if shot.target.is_empty():return super.missile_visual_position(shot,spread,origin,visual)
	var start:Vector2=visual.get("logical_origin",origin)
	var target:=Vector2(shot.target.x,shot.target.y)
	var distance:=logical.distance_to(start)
	var flight_length:=maxf(1.0,float(visual.get("missile_range",start.distance_to(target))))
	var progress:=smoothstep(0.0,flight_length,distance)
	var muzzle_shift:Vector2=(origin-start)*(1.0-progress)
	var target_shift:Vector2=(battle_logical_point(entity_render_position(shot.target))-target)*progress
	# Keep each real muzzle's departure lane through the flight instead of
	# collapsing every carrier into the logical center after the first 160 units.
	var fan:=spread*0.4*smoothstep(0.0,100.0,distance)*(1.0-progress)
	return logical+muzzle_shift+target_shift+Vector2(fan,0)


func advance_projectile_visuals(dt:float)->void:
	missile_density=game.projectiles.filter(func(p):return not bool(p.hostile) and str(p.key)=="missile").size()
	# Preserve the final rendered offset when the authoritative target disappears.
	# The orphan continues its existing logical velocity, never retargets visually.
	for visual in projectile_visuals:
		if not _is_own_missile(visual.shot) or bool(visual.shot.get("prototype_missile",false)):continue
		if bool(visual.get("had_target",false)) and visual.shot.target.is_empty() and not visual.has("orphan_offset"):
			visual.orphan_offset=Vector2(visual.get("last_render_point",visual.origin))-Vector2(visual.get("last_logical_point",visual.logical_origin))
			missile_loss_count+=1
			var expected:=Vector2(visual.last_render_point)+Vector2(visual.shot.x,visual.shot.y)-Vector2(visual.last_logical_point)
			var actual:=missile_visual_position(visual.shot,float(visual.spread),visual.origin,visual)
			missile_loss_max_jump=maxf(missile_loss_max_jump,battle_point(actual).distance_to(battle_point(expected)))
	super.advance_projectile_visuals(dt)
	for visual in projectile_visuals:
		if not _is_own_missile(visual.shot):continue
		var head:=int(visual.head)
		if int(visual.samples)>1:
			var movement:=battle_point(visual.trail[head])-battle_point(visual.trail[(head+13)%14])
			if movement.length_squared()>0.001:visual.angle=movement.angle()
		visual.last_render_point=visual.trail[head]
		visual.last_logical_point=Vector2(visual.shot.x,visual.shot.y)
		visual.had_target=not visual.shot.target.is_empty()


func _draw_rail_charge(module:Dictionary)->void:
	if accelerated_visual_mode or game.state!=BattleGame.State.COMBAT or not game.has_alive_enemy():return
	var slot:=int(module.slot)
	var amount:float=player_railgun_charge(slot)
	if amount<=0.0:return
	var point:Vector2=ship_view.screen_muzzle_for_slot(slot)
	var ahead:Vector2=ship_view.camera.unproject_position(module.muzzle.to_global(Vector3(0,0,-0.5)))
	rail_vfx.charge(pulse_layer,point,(ahead-point).normalized(),amount,fx_time)


func _is_own_rail(shot:Dictionary)->bool:
	return prototype_enabled and rail_vfx_enabled and not bool(shot.get("hostile",false)) and weapon_key(shot)=="cannon" and not bool(shot.get("beam",false))


func _is_own_pulse(shot:Dictionary)->bool:
	return prototype_enabled and pulse_vfx_enabled and not bool(shot.get("hostile",false)) and weapon_key(shot)=="laser" and not bool(shot.get("beam",false))


func _is_simple_enemy(shot:Dictionary)->bool:
	return prototype_enabled and enemy_vfx_enabled and bool(shot.get("hostile",false)) and weapon_key(shot) in ["laser","cannon"] and not bool(shot.get("beam",false))


func weapon_launch(shot:Dictionary,spread:=0.0)->void:
	enemy_launch_context=_is_simple_enemy(shot)
	missile_launch_context=_is_own_missile(shot)
	rail_launch_context=_is_own_rail(shot)
	pulse_launch_context=_is_own_pulse(shot)
	# Preserve the original launch projection/target/age/trail bookkeeping.
	# Only the legacy flash/smoke calls are suppressed inside this visual context.
	super.weapon_launch(shot,spread)
	if enemy_launch_context and not fast_mode_enabled():
		var visual:=projectile_visual(shot)
		enemy_impacts.append({"kind":"fire","position":visual.get("origin",visual_muzzle(shot)),"direction":Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle()))),"key":weapon_key(shot),"born":fx_time})
	if pulse_launch_context and not fast_mode_enabled():
		var visual:=projectile_visual(shot)
		var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
		pulse_events.append({"kind":"fire","position":visual.get("origin",visual_muzzle(shot)),"direction":direction,"born":fx_time,"critical":false})
		pulse_fire_count+=1
		pulse_fire_slots[int(visual.get("mount",-1))]=true
		pulse_origin_max_error=maxf(pulse_origin_max_error,Vector2(visual.get("origin",Vector2.ZERO)).distance_to(visual_muzzle(shot)))
	if rail_launch_context and not fast_mode_enabled():
		var visual:=projectile_visual(shot)
		var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
		rail_events.append({"kind":"fire","position":visual.get("origin",visual_muzzle(shot)),"direction":direction,"born":fx_time,"critical":false})
		rail_fire_count+=1
		rail_fire_slots[int(visual.get("mount",-1))]=true
		rail_origin_max_error=maxf(rail_origin_max_error,Vector2(visual.get("origin",Vector2.ZERO)).distance_to(visual_muzzle(shot)))
	if missile_launch_context and not fast_mode_enabled():
		var visual:=projectile_visual(shot)
		var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
		missile_events.append({"kind":"fire","position":visual.get("origin",visual_muzzle(shot)),"direction":direction,"born":fx_time,"critical":false,"serial":int(shot.get("serial",0))})
		missile_fire_count+=1
		missile_fire_slots[int(visual.get("mount",-1))]=true
		missile_origin_max_error=maxf(missile_origin_max_error,Vector2(visual.get("origin",Vector2.ZERO)).distance_to(visual_muzzle(shot)))
		visual.had_target=not shot.target.is_empty()
		visual.missile_range=Vector2(shot.x,shot.y).distance_to(Vector2(shot.target.x,shot.target.y)) if not shot.target.is_empty() else 160.0
		visual.last_render_point=visual.get("origin",visual_muzzle(shot))
		visual.last_logical_point=Vector2(shot.x,shot.y)
	enemy_launch_context=false
	pulse_launch_context=false
	rail_launch_context=false
	missile_launch_context=false


func weapon_flash(pos:Vector2,color:Color,radius:float,duration:float)->void:
	if not enemy_launch_context and not pulse_launch_context and not rail_launch_context and not missile_launch_context:super.weapon_flash(pos,color,radius,duration)


func weapon_smoke(pos:Vector2,color:Color,count:int,duration:float,size_value:float)->void:
	if not enemy_launch_context and not pulse_launch_context and not rail_launch_context and not missile_launch_context:super.weapon_smoke(pos,color,count,duration,size_value)


func weapon_impact(shot:Dictionary,pos:Vector2)->void:
	if _is_simple_enemy(shot):
		if not fast_mode_enabled():enemy_impacts.append({"position":pos,"direction":shot.direction,"key":weapon_key(shot),"born":fx_time})
		return
	if _is_own_missile(shot):
		if fast_mode_enabled():return
		var visual:=projectile_visual(shot)
		var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
		missile_events.append({"kind":"hit","position":pos,"direction":direction,"born":fx_time,"critical":bool(shot.get("critical",false)),"serial":int(shot.get("serial",0))})
		missile_hit_count+=1
		return
	if _is_own_rail(shot):
		if fast_mode_enabled():return
		var visual:=projectile_visual(shot)
		var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
		rail_events.append({"kind":"hit","origin":visual.get("origin",pos),"position":pos,"direction":direction,"born":fx_time,"critical":bool(shot.get("critical",false))})
		rail_hit_count+=1
		railgun_sound("impact")
		return
	if not _is_own_pulse(shot):
		super.weapon_impact(shot,pos)
		return
	if fast_mode_enabled():return
	var visual:=projectile_visual(shot)
	var direction:=Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle())))
	pulse_events.append({"kind":"hit","position":pos,"direction":direction,"born":fx_time,"critical":bool(shot.get("critical",false))})
	pulse_hit_count+=1


func draw_projectile_fx(shot:Dictionary,pos:Vector2,offset:Vector2,core:=true,visual:Dictionary={},trail_budget:=-1)->float:
	if shot.get("chain_hop",false):return Vector2(shot.direction).angle()
	if _is_simple_enemy(shot):
		var angle:float=visual.get("angle",Vector2(shot.direction).angle())
		if core:ENEMY_VFX.flight(draw_surface,pos,Vector2.from_angle(angle),weapon_key(shot))
		return angle
	if _is_own_missile(shot):
		var angle:=float(visual.get("angle",Vector2(shot.direction).angle()))
		var budget:=0.5 if trail_budget==0 else 1.0
		if not shot.target.is_empty() and float(shot.get("motion_age",1.0))>=0.22:MISSILE_VFX.trail(draw_surface,visual,battle_point,offset,core,int(shot.get("serial",0)),budget)
		return angle
	if _is_own_rail(shot):
		var angle:=float(visual.get("angle",Vector2(shot.direction).angle()))
		if core:rail_vfx.flight(draw_surface,pos,Vector2.from_angle(angle),fx_time,battle_point(Vector2(visual.get("origin",Vector2(shot.x,shot.y)))))
		return angle
	if not _is_own_pulse(shot):return super.draw_projectile_fx(shot,pos,offset,core,visual,trail_budget)
	var angle:=float(visual.get("angle",Vector2(shot.direction).angle()))
	if core:PULSE_VFX.flight(draw_surface,pos,Vector2.from_angle(angle))
	# No legacy trail pass: only one finite packet at the authoritative projected position.
	return angle


func draw_ship(pos: Vector2, scale_value: float, hostile: bool, type: int, shield_active: bool) -> void:
	if hostile or not prototype_enabled:
		super.draw_ship(pos,scale_value,hostile,type,shield_active)


func draw_engine_wake(pos: Vector2) -> void:
	if not prototype_enabled: super.draw_engine_wake(pos)


func turret_muzzle(index: int) -> Vector2:
	if prototype_enabled and is_instance_valid(ship_view):
		var point: Vector2 = ship_view.screen_muzzle_for_slot(index)
		if point!=Vector2.ZERO: return battle_logical_point(point)
	return super.turret_muzzle(index)


func player_mount_center(key: String, index: int) -> Vector2:
	if prototype_enabled and is_instance_valid(ship_view):
		for module in ship_view.modules:
			if int(module.slot)!=index: continue
			var point: Vector2 = ship_view.camera.unproject_position(module.mount.global_position)
			return (point-player_render_position()).rotated(PI/2-player_idle_angle())/player_art_scale()
	return super.player_mount_center(key,index)


func player_idle_angle() -> float:
	return 0.0 if prototype_enabled else super.player_idle_angle()


func _stable_player_anchor() -> Vector2:
	var point := super.player_render_position()
	# The inherited renderer adds perpetual sine bob. Remove it only in this
	# renderer; real game.player.x movement, if any, remains the input.
	point-=Vector2(sin(fx_time*TAU/5.7)*float(battle_visual.player_idle_x),sin(fx_time*TAU/4.3)*float(battle_visual.player_idle_y))
	if reference_height>0:
		point.y=minf(point.y,BATTLE_VIEW_SIZE.y-float(battle_visual.player_hud_gap)-reference_height*0.5)
	return point


func player_render_position() -> Vector2:
	if not prototype_enabled:return super.player_render_position()
	if battle_draw_active:return battle_draw_player_position
	return stable_center if stable_center_ready else _stable_player_anchor()


func draw_battle() -> void:
	if effects_enabled: super.draw_battle()



const BATTLE_CREAM := Color("eeeede")
const BATTLE_TEAL := Color("70b8bd")
const BATTLE_NAVY := Color("172c3b")
const BATTLE_WARM := Color("d9a477")

func battle_panel(rect:Rect2)->void:
	var style:=StyleBoxFlat.new()
	style.bg_color=BATTLE_NAVY
	style.set_corner_radius_all(10)
	style.border_color=Color("304958")
	style.set_border_width_all(1)
	draw_surface.draw_style_box(style,rect)

func battle_meter(rect:Rect2,ratio:float,color:Color)->void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("0b1b28")
	style.set_corner_radius_all(3)
	draw_surface.draw_style_box(style,rect)
	if ratio<=0:return
	style=style.duplicate()
	style.bg_color=color
	draw_surface.draw_style_box(style,Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)))

func draw_background()->void:
	# This static frame shares the equipment palette without covering the playfield.
	draw_surface.draw_rect(get_viewport_rect(),BG)
	draw_surface.draw_rect(Rect2(20,96,572,get_viewport_rect().size.y-120),Color("102330"))
	draw_surface.draw_rect(Rect2(BATTLE_ORIGIN,BATTLE_VIEW_SIZE),Color("0d202e"))

func draw_vertical_battle_hud()->void:
	battle_panel(Rect2(30,100,552,98))
	draw_surface.draw_rect(Rect2(44,115,4,24),BATTLE_TEAL)
	text_at(UIText.t("battle.stage",{"stage":str(int(game.stage))}),Vector2(60,134),23,BATTLE_CREAM)
	var state_key:="hud.state.retreat" if game.state==BattleGame.State.RETREAT else "hud.state.combat" if game.state==BattleGame.State.COMBAT else "hud.state.clear" if game.state==BattleGame.State.LEVEL_CLEAR else "hud.state.travel"
	if game.paused and game.pending_unlocks.is_empty():state_key="hud.state.paused"
	text_at(UIText.t(state_key),Vector2(208,132),16,BATTLE_TEAL)
	text_at(UIText.t("battle.draw_battle.text_08",{"group_index":str(game.group_index),"value":str(db.levels[game.stage-1].groups.size())}),Vector2(425,132),15,Color("9eb4bd"))
	battle_meter(Rect2(44,188,524,5),game.distance/maxf(1,float(db.levels[game.stage-1].length)),BATTLE_TEAL)
	if game.state==BattleGame.State.COMBAT and game.is_boss_encounter():
		text_at(UIText.t("battle.draw_battle.text_02"),Vector2(315,132),14,BATTLE_WARM)
	battle_panel(Rect2(30,1132,552,114))
	var status := game.enhancement_protection_status()
	var layers := defense_hud_layers(status)
	draw_defense_hud_row("armour",layers.armour,status,1158,BATTLE_WARM)
	if game.profile.unlocked.has("shield"):
		draw_defense_hud_row("shield",layers.shield,status,1197,BATTLE_TEAL)
	var footer := defense_hud_footer(status)
	if not footer.is_empty():
		draw_defense_caption(footer,Vector2(48,1238),BATTLE_WARM)

func defense_hud_layers(status:Dictionary)->Dictionary:
	# Temporary pool ownership is explicit in the public snapshot's component
	# index. Cover is global in that snapshot; debt can spill into another layer.
	var layers := {"armour":{"current":0.0,"capacity":0.0,"components":[]},"shield":{"current":0.0,"capacity":0.0,"components":[]}}
	for component in status.get("components",[]):
		var key := str(game.slot_entry("defence",int(component.index)).get("key",""))
		if not layers.has(key):continue
		var layer:Dictionary=layers[key]
		layer.current=GrowthNumber.add(layer.current,component.current)
		layer.capacity=GrowthNumber.add(layer.capacity,component.capacity)
		layer.components.append(component)
	return layers

func defense_temporary_caption(layer:Dictionary)->String:
	if GrowthNumber.compare(layer.current,0)<=0 and GrowthNumber.compare(layer.capacity,0)<=0:return ""
	var state := mixed_protection_state_text(layer)
	return UIText.t("battle.defense.temporary",{"current":number(layer.current),"state":state})

func defense_hud_footer(status:Dictionary)->String:
	var captions:Array[String]=[]
	if GrowthNumber.compare(status.get("cover_current",0),0)>0:
		captions.append(UIText.t("battle.defense.cover",{"amount":number(status.cover_current),"duration":NUMBER_FORMAT.precise(ceili(float(status.cover_remaining)*10)/10.0)}))
	var debt=game.enhancement_deferred_total()
	if GrowthNumber.compare(debt,0)>0:
		captions.append(UIText.t("battle.defense.debt",{"amount":number(debt)}))
	return " · ".join(captions)

func defense_caption_size(caption:String,preferred:int)->int:
	var result:=preferred
	while result>13 and font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x>516.0:result-=1
	return result

func draw_defense_caption(caption:String,position:Vector2,color:Color)->void:
	# These three tightly bounded rows share the original 114 px panel. Bypass
	# the legacy text_at minimum only when a complete large-number label needs it.
	draw_surface.draw_string(font,position,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,defense_caption_size(caption,17),color)

func draw_defense_hud_row(key:String,layer:Dictionary,status:Dictionary,y:float,color:Color)->void:
	var body=game.player.armour if key=="armour" else game.player.shield
	var maximum=game.stat("armour") if key=="armour" else game.max_shield()
	var title := UIText.t("battle.hp",{"current_hp":number(body),"max_hp":number(maximum)}) if key=="armour" else UIText.t("battle.shield",{"current_shield":number(body),"max_shield":number(maximum)})
	var temporary:=defense_temporary_caption(layer)
	if not temporary.is_empty():title+=" · "+temporary
	draw_defense_caption(title,Vector2(48,y),BATTLE_CREAM if key=="armour" else BATTLE_TEAL)
	var meter:=Rect2(48,y+10,516,7)
	battle_meter(meter,GrowthNumber.ratio(body,GrowthNumber.maximum(1,maximum)),color)
	if GrowthNumber.compare(status.get("cover_current",0),0)>0:
		# A shared outline embraces the existing bars. It never increases HP fill.
		draw_surface.draw_rect(meter.grow(3),Color("c7d2c4"),false,1.5)
	if GrowthNumber.compare(layer.current,0)>0:
		var ratio:=GrowthNumber.ratio(layer.current,GrowthNumber.maximum(1,layer.capacity))
		draw_surface.draw_line(meter.position-Vector2(0,1),meter.position+Vector2(meter.size.x*ratio,-1),Color("c7d2c4"),2.0)


func enemy_hull_light(enemy:Dictionary)->float:
	# Small silhouettes need readable armor at the native ~390 px battlefield.
	# Raise texture contrast only: keep alpha, footprint, mounts and depth order.
	var depth:=enemy_depth(enemy)
	return lerpf(1.18,1.30,depth) if int(enemy.size)<=2 else lerpf(0.76,1.0,depth)

func prepare_enemy_hulls() -> void:
	for size_class in range(1,7):
		var path := str(ship_visual_entry("enemy_"+str(size_class)).get("texture",""))
		# Optional/unavailable hulls must not introduce an error before encounter.
		# A later configured texture still resolves through the ordinary draw path.
		if path.is_empty() or not ResourceLoader.exists(path):continue
		var texture := visual_texture(path)
		if texture != null:enemy_hull_bounds(texture)

func enemy_hull_bounds(texture: Texture2D) -> Rect2:
	var texture_key:=texture.get_instance_id()
	if not hull_opaque_bounds.has(texture_key):
		var pixels:=texture.get_image().get_used_rect()
		hull_opaque_bounds[texture_key]=Rect2(Vector2(pixels.position)/texture.get_size()-Vector2(0.5,0.5),Vector2(pixels.size)/texture.get_size())
	return hull_opaque_bounds[texture_key]

func draw_enemy_hull_and_status(enemy:Dictionary,offset:Vector2,boss_battle:bool)->void:
	var pos:=enemy_render_position(enemy)+offset
	var width:=enemy_render_width(enemy)
	var dimensions:=Vector2(width,width*2.0)
	var angle:=enemy_render_angle(enemy)
	var light:=enemy_hull_light(enemy)
	draw_enemy_weapon_components(enemy,pos,angle,width,true)
	draw_surface.draw_set_transform(pos,PI+angle)
	draw_surface.draw_texture_rect(ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),Rect2(-dimensions/2,dimensions),false,Color(light,light,light,1.0))
	draw_surface.draw_set_transform(Vector2.ZERO)
	draw_enemy_weapon_components(enemy,pos,angle,width,false)
	# Track the actual opaque silhouette instead of using the transverse width as height.
	var texture:=ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
	var used:=enemy_hull_bounds(texture)
	var top:=pos.y
	for corner in [used.position,Vector2(used.end.x,used.position.y),used.end,Vector2(used.position.x,used.end.y)]:
		top=minf(top,pos.y+(Vector2(corner)*dimensions).rotated(PI+angle).y)
	top-=9.0
	var bar_width:=clampf(width*used.size.x,28,100)
	var left:=clampf(pos.x-bar_width*0.5,6,BATTLE_VIEW_SIZE.x-bar_width-6)
	battle_meter(Rect2(left,maxf(6,top),bar_width,4),float(enemy.hp)/maxf(1,float(enemy.max_hp)),BATTLE_WARM)
	if boss_battle:
		text_at(UIText.t("battle.enemy_marker",{"slot":"%02d" % (int(enemy.slot)+1)}),Vector2(left, maxf(20,top-5)),12,BATTLE_CREAM)

func draw_environment_event(_offset:Vector2)->void:
	# Distant geometry belongs to the background; combat space stays quiet.
	pass

func box(rect:Rect2,color:=PANEL,border:=LINE)->void:
	if is_instance_valid(overlay_layer) and draw_surface==overlay_layer:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(BATTLE_NAVY,color.a)
		style.border_color=Color("304958")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		draw_surface.draw_style_box(style,rect)
	else:super.box(rect,color,border)
