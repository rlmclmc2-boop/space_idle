extends "res://scripts/main.gd"
## Development-only subclass. Production code, values, UI and assets are untouched.

const PROTOTYPE_GAME := preload("res://dev/toon_ship/prototype_battle_game.gd")
const ENEMY_VFX := preload("res://dev/toon_ship/enemy_weapon_vfx.gd")
var enemy_vfx_enabled:=true
var enemy_launch_context:=false
var enemy_impacts:Array[Dictionary]=[]
const MISSILE_VFX := preload("res://dev/toon_ship/missile_vfx.gd")
const CONTINUOUS_BEAM_VFX := preload("res://dev/toon_ship/continuous_beam_vfx.gd")
const RAIL_VFX := preload("res://dev/toon_ship/rail_vfx.gd")
const PULSE_VFX := preload("res://dev/toon_ship/pulse_vfx.gd")
const SHIP_VIEW := preload("res://dev/toon_ship/ship_view.gd")

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
var stable_center := Vector2.ZERO
var stable_center_ready := false


func create_battle_game(_persist:bool)->BattleGame:
	var prototype=PROTOTYPE_GAME.new(db,false)
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


func _ready() -> void:
	# Existing capture boot is the project's no-save path. Remove its auto-quit after boot.
	var args := OS.get_cmdline_user_args()
	automation_args = PackedStringArray(["--capture"])
	super._ready()
	automation_args = PackedStringArray()
	music.stop()
	if args.has("--prototype-saved-loadout"):
		game.load_progress()
		game.resume_progress()
		build_ui()
	for arg in args:
		if arg.begins_with("--prototype-fixture="):
			fixture_name = arg.trim_prefix("--prototype-fixture=")
			_apply_fixture(fixture_name)
	ship_view = SHIP_VIEW.new()
	ship_view.name = "ToonShipView"
	ship_view.size = BATTLE_VIEW_SIZE
	ship_view.z_index = 0
	battle_clip.add_child(ship_view)
	# Default preserves foreground projectile visibility. O toggles an experimental opaque mask.
	# Neither order changes shot positions, damage, timing or RNG.
	battle_clip.move_child(ship_view,battle_layer.get_index())
	ship_view.set_hull(str(game.profile.selectedShip))
	current_hull = str(game.profile.selectedShip)
	ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
	pulse_layer = Node2D.new()
	pulse_layer.name = "PrototypePulse"
	pulse_layer.z_index = 2
	battle_clip.add_child(pulse_layer)
	pulse_layer.draw.connect(_draw_muzzle_cues)

	_set_reference_dimensions()
	for arg in args:
		if arg.begins_with("--prototype-capture="):
			capture_directory = arg.trim_prefix("--prototype-capture=")
		if arg=="--prototype-exit": requested_exit = true
		if arg=="--prototype-close": close_up = true
		if arg=="--prototype-smooth": toon_enabled = false
		if arg=="--prototype-old-missile": missile_vfx_enabled = false
		if arg=="--prototype-old-beam": continuous_beam_enabled = false
		if arg=="--prototype-old-rail": rail_vfx_enabled = false
		if arg=="--prototype-old-pulse": pulse_vfx_enabled = false
		if arg=="--prototype-no-rim": rim_enabled = false
		if arg=="--prototype-no-shield": shield_enabled = false
		if arg=="--prototype-original": prototype_enabled = false
	_update_title()
	_sync_parameters()
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,player_idle_angle(),player_render_position()+Vector2(0,-600),demo_time,shield_enabled,close_up)


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
	# Update the canonical carrier pose before simulation asks for release points.
	if is_instance_valid(ship_view) and not game.paused:
		demo_time+=delta
		var aim:Vector2=player_render_position()+Vector2(0,-450)
		if not game.enemies.is_empty():aim=enemy_render_position(game.enemies[0])
		ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,aim,demo_time,shield_enabled,close_up,delta)
	super._process(delta)
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
	rail_events = rail_events.filter(func(e):return fx_time-float(e.born)<0.31)
	if accelerated_visual_mode:rail_events.clear()
	enemy_impacts=enemy_impacts.filter(func(e):return fx_time-float(e.born)<0.12)
	if accelerated_visual_mode:enemy_impacts.clear()
	pulse_events = pulse_events.filter(func(e):return fx_time-float(e.born)<0.14)
	prototype_frames += 1
	_sync_parameters()
	if current_hull != str(game.profile.selectedShip):
		current_hull = str(game.profile.selectedShip)
		if not ship_view.set_hull(current_hull):
			prototype_enabled = false
			ship_view.set_rendering(false)
			return
		_set_reference_dimensions()
	ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
	var anchor := _stable_player_anchor()
	if not stable_center_ready:
		stable_center=anchor
		stable_center_ready=true
	elif not game.paused and battle_layer.visible:
		stable_center=stable_center.lerp(anchor,1.0-exp(-3.0*minf(delta,0.1)))
	var target := player_render_position()+Vector2(0,-450)
	if not game.enemies.is_empty(): target = enemy_render_position(game.enemies[0])
	var pose_signature := str([parameters_signature,prototype_enabled,close_up,shield_enabled,battle_layer.visible,game.paused,player_render_position(),target,fx_time])
	if capture_directory!="" and prototype_frames==150: _capture()
	if game.paused and pose_signature==paused_presentation_signature: return
	paused_presentation_signature = pose_signature
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,target,demo_time,shield_enabled,close_up,0.0)
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

	for event in enemy_impacts:
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
			if event.kind=="fire":RAIL_VFX.flash(pulse_layer,point,event.direction,age,budget)
			else:
				RAIL_VFX.penetration(pulse_layer,battle_point(Vector2(event.origin)),point,event.direction,age,budget,BATTLE_VIEW_SIZE)
				RAIL_VFX.impact(pulse_layer,point,event.direction,age,bool(event.critical),budget)

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
	if kind=="prototype_missile_reset":
		missile_events.clear();return
	if kind=="prototype_missile_retired":
		if not missile_vfx_enabled:return
		var coast_time:=1.20+float(posmod(int(info.serial)*13,5))*0.08 if bool(info.coast) else 0.0
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
	var id:=game.slot_id("weapons",slot)
	var remaining:=float(game.cooldowns.get(id,999.0))
	var amount:float=railgun_fx.charge(remaining,maxf(0.01,game.speed))
	if amount<=0.0:return
	var point:Vector2=ship_view.screen_muzzle_for_slot(slot)
	var ahead:Vector2=ship_view.camera.unproject_position(module.muzzle.to_global(Vector3(0,0,-0.5)))
	RAIL_VFX.charge(pulse_layer,point,(ahead-point).normalized(),amount,fx_time)


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
		if core:RAIL_VFX.flight(draw_surface,pos,Vector2.from_angle(angle),fx_time,battle_point(Vector2(visual.get("origin",Vector2(shot.x,shot.y)))))
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


func set_effects(enabled: bool) -> void:
	effects_enabled = enabled
	shield_enabled = enabled
	# The battle renderer skips its transient layer during silhouette inspection.
	battle_layer.queue_redraw()
	pulse_layer.visible = false
	for plume in ship_view.exhaust_nodes: plume.visible = enabled
	ship_view.shield.visible = enabled
	ship_view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if game.paused else SubViewport.UPDATE_ALWAYS


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_T: toon_enabled = not toon_enabled
		KEY_R: rim_enabled = not rim_enabled
		KEY_S:
			shield_enabled = not shield_enabled
			paused_presentation_signature = ""
		KEY_B:
			prototype_enabled = not prototype_enabled
			battle_layer.queue_redraw()
		KEY_C: close_up = not close_up
		KEY_V: set_effects(not effects_enabled)
		KEY_O:
			protect_silhouette = not protect_silhouette
			battle_clip.move_child(ship_view,battle_layer.get_index()+1 if protect_silhouette else battle_layer.get_index())
		KEY_P: game.paused = not game.paused
		_: return
	_sync_parameters()
	_update_title()
	get_viewport().set_input_as_handled()


func _update_title() -> void:
	get_window().title = "五舰混合原型 | %s | %s | C 近看 · V 特效 · O 遮挡保护 · P 暂停" % [str(game.profile.selectedShip),"合成满载夹具（非玩家存档）" if not fixture_name.is_empty() else "隔离预览"]


func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_directory)
	get_viewport().get_texture().get_image().save_png(capture_directory.path_join("battle.png"))
	ship_view.viewport.get_texture().get_image().save_png(capture_directory.path_join("ship-alpha.png"))
	var facts := {"godot":Engine.get_version_info().string,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"ship_reference_pixels":reference_height,"battle_size":BATTLE_VIEW_SIZE,"save_enabled":game.save_enabled,
		"toon":toon_enabled,"rim":rim_enabled,"close_up":close_up,"outline":false,
		"turret_y":ship_view.turret.rotation.y if ship_view.turret!=null else 0.0,"weapon_mounted":ship_view.weapon!=null,"mesh_materials":ship_view.material_entries.size(),
		"engine_count":ship_view.exhaust_nodes.size(),"fps":Engine.get_frames_per_second()}
	var file := FileAccess.open(capture_directory.path_join("facts.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(facts,"\t"))
	print("TOON_PROTOTYPE ",JSON.stringify(facts))
	if requested_exit: get_tree().quit()


func player_idle_angle() -> float:
	return 0.0 if prototype_enabled else super.player_idle_angle()


func _stable_player_anchor() -> Vector2:
	var point := super.player_render_position()
	# The inherited renderer adds perpetual sine bob. Remove it only in this
	# developer view; real game.player.x movement, if any, remains the input.
	point-=Vector2(sin(fx_time*TAU/5.7)*float(battle_visual.player_idle_x),sin(fx_time*TAU/4.3)*float(battle_visual.player_idle_y))
	if reference_height>0:
		point.y=minf(point.y,BATTLE_VIEW_SIZE.y-float(battle_visual.player_hud_gap)-reference_height*0.5)
	if str(game.profile.selectedShip)=="Heavy_Battleship":
		# Reserve an orbit below the mother ship without enlarging the hull itself.
		point.y=minf(point.y,BATTLE_VIEW_SIZE.y*0.66)
	return point


func player_render_position() -> Vector2:
	if not prototype_enabled:return super.player_render_position()
	if battle_draw_active:return battle_draw_player_position
	return stable_center if stable_center_ready else _stable_player_anchor()


func draw_battle() -> void:
	if effects_enabled: super.draw_battle()


func _apply_fixture(key: String) -> void:
	# Explicit in-memory synthetic fixture, never represented as a player save.
	if db.ship(key).is_empty():
		push_error("Unknown synthetic fixture hull: "+key)
		get_tree().quit(1)
		return
	game.profile.selectedShip = key
	game.profile.loadout = game.empty_loadout(key)
	var pattern := ["laser","missile","cannon","longLaser","missile","longLaser","cannon","missile"]
	# Preserve the earlier heavy repeated-weapon review as its dedicated fixture.
	if key == "Heavy_Battleship": pattern = ["laser","missile","missile","missile","missile","longLaser","cannon","longLaser"]
	if OS.get_cmdline_user_args().has("--prototype-pulse-fixture"):pattern.fill("laser")
	if OS.get_cmdline_user_args().has("--prototype-rail-fixture"):pattern.fill("cannon")
	if OS.get_cmdline_user_args().has("--prototype-rail-single"):
		pattern.fill("");pattern[0]="cannon"
	if OS.get_cmdline_user_args().has("--prototype-missile-fixture"):pattern.fill("missile")
	if OS.get_cmdline_user_args().has("--prototype-beam-fixture"):pattern.fill("longLaser")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prototype-single-weapon="):
			pattern.fill("");pattern[0]=arg.trim_prefix("--prototype-single-weapon=")
	if OS.get_cmdline_user_args().has("--prototype-offcenter-source"):
		pattern.fill("");pattern[0]="laser";pattern[1]="missile"
	for index in game.profile.loadout.weapons.size():
		game.profile.loadout.weapons[index].key = pattern[index]
	game.profile.loadout.defence[0].key = "armour"
	game.invalidate_stat_cache()
	game.reset_player()
	game.projectiles.clear()
	projectile_visuals.clear()
	beam_visuals.clear()
	turret_visuals.clear()
	game.paused = true
	build_ui()
