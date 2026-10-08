extends "res://scripts/main.gd"
## Live battle presentation. Save, inventory and unlock authority remains BattleGame.

const PROTOTYPE_GAME := preload("res://scripts/presented_battle_game.gd")
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
const ROUTE_SCENERY_ATLAS := preload("res://assets/backgrounds/hyperspace/routes_atlas.png")
var scenery_material_route := ""
const SOLID_BACKGROUND_SHADER := preload("res://scripts/solid_background.gdshader")

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
var hyperspace_visual
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
var encounter_presentation := preload("res://scripts/encounter_presentation.gd").new()


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
	hyperspace_visual=preload("res://scripts/hyperspace_drone_visual.gd").new()
	ship_view.world.add_child(hyperspace_visual)
	hyperspace_visual.sync(game.profile.hyperspace.inventory)
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
	prototype.drone_launch_provider=_prototype_drone_launch_pose
	prototype.target_provider=_prototype_target_point
	prototype.rail_geometry_provider=_rail_geometry
	prototype.rail_target_point_provider=entity_render_position
	return prototype

func _rail_geometry(shot: Dictionary) -> Dictionary:
	return {"origin":battle_point(visual_muzzle(shot)),"aim":entity_render_position(shot.target),"bounds":battle_clip.size,"full_width":rail_vfx.discharge_width(float(shot.get("rail_width_multiplier",1.0)))}


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


func _prototype_drone_launch_pose(id:String,aim:Vector2,ordinal:int)->Dictionary:
	if not is_instance_valid(ship_view) or not is_instance_valid(hyperspace_visual):
		var fallback:=Vector2(game.player.x,game.player.y)
		return {"position":fallback,"direction":(aim-fallback).normalized()}
	var point:Vector2=hyperspace_visual.screen_muzzle_for_drone(id,ordinal,ship_view)
	if close_up:point=player_render_position()+reference_offset+(point-ship_view.rendered_position)/2.8
	var logical:=battle_logical_point(point)
	return {"position":logical,"direction":(aim-logical).normalized()}


func _visual_drone_id(shot:Dictionary)->String:
	if bool(shot.get("hostile",false)):return ""
	var entry_id:String=str(shot.get("entry",{}).get("drone_id",""))
	if not entry_id.is_empty():return entry_id
	var source_id:String=str(shot.get("combat_context",{}).get("source_id",""))
	return source_id.trim_prefix("drone:") if source_id.begins_with("drone:") else ""

func shot_mount(shot:Dictionary)->int:
	# Independent combat sources never address an ordinary turret's visual state.
	if not bool(shot.get("hostile",false)) and (not _visual_drone_id(shot).is_empty() or int(shot.get("mount",-1))>=game.weapon_entries().size()):return -1
	return super.shot_mount(shot)

func visual_muzzle(shot:Dictionary)->Vector2:
	if bool(shot.get("prototype_missile",false)) or shot.has("ballistic_target_origin"):return Vector2(shot.launch_point)
	var id:String=_visual_drone_id(shot)
	if not id.is_empty():return _prototype_drone_launch_pose(id,Vector2.ZERO,0).position
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


func uses_logical_battle_pose() -> bool:
	return true

func before_logical_game_tick(dt:float) -> void:
	# Combat providers consume the same carrier/target/turret sequence at every
	# speed. Keep the historical X1 order: pose first, then fx/turrets, then tick.
	if game.paused:return
	# Initialize every formation member at the previous logical boundary, just
	# as X1 presentation does after spawning; lazy render visits must not set age.
	for enemy in game.enemies:enemy_pose(enemy)
	if is_instance_valid(ship_view):
		if current_hull != str(game.profile.selectedShip):
			current_hull=str(game.profile.selectedShip)
			ship_view.set_hull(current_hull);_set_reference_dimensions()
		ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
		demo_time+=dt
		var aim:Vector2=player_render_position()+Vector2(0,-450)
		if not game.enemies.is_empty():aim=enemy_render_position(game.enemies[0])
		ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,aim,demo_time,shield_enabled,close_up,dt,false)
		hyperspace_visual.sync(game.profile.hyperspace.inventory)
		# Keep substep poses and muzzle providers live; validate the completed
		# fleet once at the display boundary below, not twice per logical tick.
		hyperspace_visual.pose(ship_view,game.drone_combat.disabled,2.8 if close_up else 1.0,false)
	shield_before_hit=game.player.shield
	fx_time+=dt
	advance_turrets(dt)

func _process(delta: float) -> void:
	# End the batch even when the presentation exits early. Each fixed logical
	# step changes fx_time, so accelerated combat never reuses an older limit.
	enemy_entry_batch_active=true
	enemy_entry_distance_time=-INF
	_process_battlefield(delta)
	# Wall-clock presentation survives accelerated simulation without changing
	# the logical pose/entry cache or combat providers.
	if encounter_presentation.sync(game,minf(delta,0.1)):
		stars_layer.queue_redraw()
		battle_layer.queue_redraw()
		battle_hud_layer.queue_redraw()
	enemy_entry_batch_active=false
	enemy_entry_distance_time=-INF

func _process_battlefield(delta: float) -> void:
	if is_instance_valid(ship_view):
		if hyperspace_visual.sync(game.profile.hyperspace.inventory):paused_presentation_signature=""
		ship_view.set_accelerated_quality(game.speed >= 10.0)
		hyperspace_visual.animated=game.speed < 10.0
		if current_hull != str(game.profile.selectedShip):
			current_hull = str(game.profile.selectedShip)
			if not ship_view.set_hull(current_hull):
				prototype_enabled = false
				ship_view.set_rendering(false)
				return
			_set_reference_dimensions()
		ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
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
	rail_events = rail_events.filter(func(e):return fx_time-float(e.born)<rail_vfx.afterglow_seconds())
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
	var pose_signature := str([game.drone_combat.disabled,current_hull,ship_view.loadout_signature,game.player.shield,parameters_signature,prototype_enabled,close_up,shield_enabled,battle_layer.visible,game.paused,player_render_position(),target,fx_time])
	if game.paused and pose_signature==paused_presentation_signature: return
	paused_presentation_signature = pose_signature
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,0.0,target,demo_time,shield_enabled,close_up,0.0,false)
	# Last pose writer: one guard reads actual current global scales for all
	# bodies, including newly attached/hidden/restored members. No scale cache.
	hyperspace_visual.pose(ship_view,game.drone_combat.disabled,2.8 if close_up else 1.0,true)
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
		enemy_recognition.draw_contact(pulse_layer,battle_point(event.position),event.direction,fx_time-float(event.born),int(event.damage_type),event.get("kind","")=="fire")
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
			if event.kind=="fire":
				rail_vfx.flash(pulse_layer,point,event.direction,age,budget)
				rail_vfx.penetration(pulse_layer,point,battle_point(Vector2(event.aim)),event.direction,age,budget,battle_clip.size,float(event.get("full_width",rail_vfx.discharge_width())))
			else:rail_vfx.impact(pulse_layer,point,event.direction,age,bool(event.critical),budget)

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
	if kind=="encounter":encounter_presentation.sync(game,0.0)
	if kind=="wave_clear" and encounter_presentation.tier=="ultimate":encounter_presentation.clear_age=0.0
	if kind=="hyperspace_manual":
		encounter_presentation.return_success=bool(info.get("success",false))
		encounter_presentation.sync(game,0.0)
		if not bool(info.get("active",false)):
			reset_battle_transients_for_scene()
		if is_instance_valid(stars_layer):stars_layer.queue_redraw()
		if is_instance_valid(battle_layer):battle_layer.queue_redraw()
		if is_instance_valid(battle_hud_layer):battle_hud_layer.queue_redraw()
	if kind=="explode" and int(info.get("uid",-2))==encounter_presentation.leader_uid:
		encounter_presentation.leader_fall=0.0
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
		destruction_events.append({"position":point,"width":width,"born":fx_time,"seed":int(info.get("uid",0)),"hyperspace":bool(game.manual_hyperspace.active)})
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
		if kind=="beam_started" and not fast_mode_enabled() and int(info.shot.mount)>=0 and int(info.shot.mount)<game.weapon_entries().size():
			turret_pose(int(info.shot.mount)).fired_at=fx_time
		return
	super.on_event(kind,info)


func reset_battle_transients_for_scene() -> void:
	destruction_events.clear()
	rail_events.clear()
	missile_events.clear()
	pulse_events.clear()
	enemy_impacts.clear()
	beam_full_started.clear()
	player_hit_at=-100.0
	encounter_presentation.leader_fall=2.0
	encounter_presentation.clear_age=2.0
	paused_presentation_signature=""
	super.reset_battle_transients_for_scene()
	# A restored full-power beam is ongoing, not a fresh full-power flash.
	for shot in game.projectiles:
		if shot.get("beam",false) and game.long_laser_valid(shot) and int(shot.ticks)>0 and float(beam_style(shot).power)>=0.999999:
			beam_full_started[int(shot.serial)]=fx_time-100.0
	if is_instance_valid(pulse_layer):pulse_layer.queue_redraw()

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
		enemy_impacts.append({"kind":"fire","position":visual.get("origin",visual_muzzle(shot)),"direction":Vector2.from_angle(float(visual.get("angle",Vector2(shot.direction).angle()))),"damage_type":int(shot.get("type",0)),"born":fx_time})
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
		var origin: Vector2 = visual.get("origin",visual_muzzle(shot))
		var aim: Vector2 = game.target_point(shot.target) if not shot.target.is_empty() else origin+Vector2(shot.direction)*100.0
		# Snapshot the real projected shot path. Target death cannot truncate this event.
		direction = (battle_point(aim)-battle_point(origin)).normalized()
		rail_events.append({"kind":"fire","position":origin,"aim":aim,"direction":direction,"born":fx_time,"critical":false,"full_width":rail_vfx.discharge_width(float(shot.get("rail_width_multiplier",1.0)))})
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
		if not fast_mode_enabled():enemy_impacts.append({"position":pos,"direction":shot.direction,"damage_type":int(shot.get("type",0)),"born":fx_time})
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
		enemy_recognition.draw_projectile(draw_surface,pos,angle,int(shot.get("type",0)),core)
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
	if effects_enabled:
		draw_encounter_backdrop()
		# The inherited renderer owns batch entry/exit and cache invalidation.
		super.draw_battle()



const BATTLE_CREAM := Color("eeeede")
const BATTLE_TEAL := Color("70b8bd")
const BATTLE_NAVY := Color("172c3b")
const BATTLE_WARM := Color("d9a477")
const BATTLE_HEADER_RECT := Rect2(30,100,552,56)

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

func create_draw_layers() -> void:
	super.create_draw_layers()
	var star_material:ShaderMaterial=stars_layer.material
	star_material.set_shader_parameter("route_atlas",ROUTE_SCENERY_ATLAS)
	scenery_material_route=""
	# This override draws only opaque, untextured rectangles. Keep the material
	# off the legacy main.gd background and all star/route/effect/texture layers.
	var solid_material := ShaderMaterial.new()
	solid_material.shader = SOLID_BACKGROUND_SHADER
	background_layer.material = solid_material

func draw_background()->void:
	# This static frame shares the equipment palette without covering the playfield.
	draw_surface.draw_rect(get_viewport_rect(),BG)
	draw_surface.draw_rect(Rect2(20,96,572,get_viewport_rect().size.y-120),Color("102330"))
	draw_surface.draw_rect(Rect2(BATTLE_ORIGIN,BATTLE_VIEW_SIZE),Color("0d202e"))

func draw_vertical_battle_hud()->void:
	battle_panel(BATTLE_HEADER_RECT)
	draw_surface.draw_rect(Rect2(44,115,4,24),BATTLE_TEAL)
	var route := str(game.profile.hyperspace.active.get("route","")) if game.manual_hyperspace.active else ""
	var title := UIText.t("hyperspace."+route) if not route.is_empty() else UIText.t("battle.stage",{"stage":str(int(game.stage))})
	text_at(title,Vector2(60,134),18 if not route.is_empty() else 23,BATTLE_CREAM)
	var state_key:="hud.state.retreat" if game.state==BattleGame.State.RETREAT else "hud.state.combat" if game.state==BattleGame.State.COMBAT else "hud.state.clear" if game.state==BattleGame.State.LEVEL_CLEAR else "hud.state.travel"
	if game.paused and game.pending_unlocks.is_empty():state_key="hud.state.paused"
	text_at(UIText.t(state_key),Vector2(250 if not route.is_empty() else 208,132),16,BATTLE_TEAL)
	text_at(UIText.t("battle.draw_battle.text_08",{"group_index":str(game.group_index),"value":str(game.db.levels[game.stage-1].groups.size())}),Vector2(425,132),15,Color("9eb4bd"))
	battle_meter(Rect2(44,147,524,5),game.distance/maxf(1,float(game.db.levels[game.stage-1].length)),BATTLE_TEAL)
	if game.state==BattleGame.State.COMBAT and game.encounter_tier()!="normal":
		var tier_key := "battle.finale" if game.encounter_tier()=="ultimate" else "battle.encounter_tier."+game.encounter_tier()
		text_at(UIText.t(tier_key),Vector2(330,132),14,BATTLE_WARM)
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
		if texture != null:
			enemy_hull_bounds(texture)
			enemy_recognition.hull_profile(texture)

func enemy_hull_bounds(texture: Texture2D) -> Rect2:
	var texture_key:=texture.get_instance_id()
	if not hull_opaque_bounds.has(texture_key):
		var pixels:=texture.get_image().get_used_rect()
		hull_opaque_bounds[texture_key]=Rect2(Vector2(pixels.position)/texture.get_size()-Vector2(0.5,0.5),Vector2(pixels.size)/texture.get_size())
	return hull_opaque_bounds[texture_key]

func draw_enemy_hull_and_status(enemy:Dictionary,offset:Vector2,boss_battle:bool)->void:
	var pos:=enemy_render_position(enemy)+offset
	var width:=enemy_render_width(enemy)
	var leader := encounter_presentation.is_leader(enemy)
	# The armor silhouette alone grows. Hardpoints, contact geometry, entry
	# bounds and all provider coordinates retain their original cached values.
	var hull_width := width*(1.65 if leader and encounter_presentation.tier=="ultimate" else 1.35 if leader else 1.0)
	var dimensions:=Vector2(hull_width,hull_width*2.0)
	var angle:=enemy_render_angle(enemy)
	var light:=enemy_hull_light(enemy)
	if boss_battle:
		light=1.20 if leader else maxf(0.72,light*0.84)
	if leader:encounter_presentation.draw_leader_frame(draw_surface,pos,hull_width)
	draw_enemy_weapon_components(enemy,pos,angle,width,true)
	draw_surface.draw_set_transform(pos,PI+angle)
	draw_surface.draw_texture_rect(ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),Rect2(-dimensions/2,dimensions),false,Color(light,light,light,1.0))
	enemy_recognition.draw_attack_deck(draw_surface,width,enemy_attack_types(enemy))
	var packet := enemy_recognition_geometry(enemy)
	var status := enemy_recognition.state(enemy,game.enemy_shield_time,game.paused,enemy_pose(enemy))
	# Scale only the protection draw transform, never the shared geometry
	# packet/pose cache consumed by entry limits and combat providers.
	var protection_scale:float=hull_width/width if width>0.0 else 1.0
	draw_surface.draw_set_transform(pos,PI+angle,Vector2.ONE*protection_scale)
	var protection_outline:PackedVector2Array=enemy_recognition.draw_protection(draw_surface,enemy,width,packet,status,game.enemy_shield_time)
	var outline:PackedVector2Array=protection_outline
	if leader:
		outline=PackedVector2Array()
		for point in protection_outline:outline.append(point*protection_scale)
	draw_surface.draw_set_transform(Vector2.ZERO)
	draw_enemy_weapon_components(enemy,pos,angle,width,false)
	var layout:=enemy_status_layout(enemy,pos,hull_width,angle,outline)
	battle_meter(layout.health,float(enemy.hp)/maxf(1,float(enemy.max_hp)),BATTLE_WARM)
	if float(enemy.get("max_shield",0))>0:
		battle_meter(layout.shield,float(enemy.shield)/float(enemy.max_shield),ENEMY_RECOGNITION.shield_color(int(enemy.get("shieldType",0))))
	if boss_battle and leader:text_at(layout.caption,layout.caption_position,17,BATTLE_CREAM)

func encounter_leader_name(enemy:Dictionary)->String:
	# Mainline display bindings must not resolve the manual hyperspace registry's IDs.
	var row:Dictionary=game.db.enemies.get(str(int(enemy.id)),{})
	var caption:=str(row.get("des","")).strip_edges()
	if not game.manual_hyperspace.active and not caption.is_empty():
		caption=UIText.data_text("enemies",str(int(enemy.id)),"des",caption)
	if not caption.is_empty():return caption
	if game.group_index>0 and game.group_index<=game.db.levels[game.stage-1].groups.size():
		var group:Dictionary=game.db.levels[game.stage-1].groups[game.group_index-1]
		var group_row:Dictionary=game.db.groups.get(str(int(group.id)),{})
		return str(group_row.get("description","")).strip_edges()
	return ""

func enemy_status_layout(enemy:Dictionary,pos:Vector2,width:float,angle:float,outline:PackedVector2Array)->Dictionary:
	# Status placement follows the drawn hull/protection, not combat bounds.
	var dimensions:=Vector2(width,width*2.0)
	var texture:=ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
	var used:=enemy_hull_bounds(texture)
	var top:=pos.y
	var bottom:=pos.y
	for corner in [used.position,Vector2(used.end.x,used.position.y),used.end,Vector2(used.position.x,used.end.y)]:
		var corner_y:float=pos.y+(Vector2(corner)*dimensions).rotated(PI+angle).y
		top=minf(top,corner_y)
		bottom=maxf(bottom,corner_y)
	for point in outline:
		var point_y:float=pos.y+point.rotated(PI+angle).y
		top=minf(top,point_y)
		bottom=maxf(bottom,point_y)
	top-=9.0
	var bar_width:=clampf(width*used.size.x,28,100)
	var left:=clampf(pos.x-bar_width*0.5,6,BATTLE_VIEW_SIZE.x-bar_width-6)
	if encounter_presentation.is_leader(enemy):
		# text_at renders at least 17 px: measure the same font size. Place the
		# name and meters as one block, never clamp three rows independently.
		var name:=encounter_leader_name(enemy)
		if name.is_empty():name=UIText.t("battle.enemy_marker",{"slot":"%02d" % (int(enemy.slot)+1)})
		name=fit_battle_text(name,260.0,17)
		var name_size:=font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,17)
		var ascent:float=font.get_ascent(17)
		var descent:float=font.get_descent(17)
		var name_height:float=ascent+descent
		var has_shield:bool=float(enemy.get("max_shield",0))>0.0
		var block_height:float=name_height+6.0+(11.0 if has_shield else 4.0)
		var block_top:float=top+4.0-block_height
		# An enlarged ultimate can reach the header. Move the whole block
		# below its visible outline instead of laying text across hull/meters.
		if block_top<12.0:block_top=bottom+12.0
		block_top=clampf(block_top,12.0,BATTLE_VIEW_SIZE.y-block_height-12.0)
		var name_left:float=clampf(pos.x-name_size.x*0.5,12.0,BATTLE_VIEW_SIZE.x-name_size.x-12.0)
		var baseline:=Vector2(name_left,block_top+ascent)
		var first_meter_y:float=block_top+name_height+6.0
		return {"health":Rect2(left,first_meter_y+(7.0 if has_shield else 0.0),bar_width,4),"shield":Rect2(left,first_meter_y,bar_width,4),"caption":name,"caption_position":baseline,"caption_bounds":Rect2(Vector2(name_left,block_top),Vector2(name_size.x,name_height))}
	var outer_wing:bool=enemy.get("explicit_formation",false) and absf(float(enemy.x)-BATTLE_VIEW_SIZE.x*0.5)>150.0
	if outer_wing:
		# Meters use the same free outer-wing space as their captions.
		left=clampf(pos.x if pos.x>=BATTLE_VIEW_SIZE.x*0.5 else pos.x-bar_width,6,BATTLE_VIEW_SIZE.x-bar_width-6)
	var caption:=UIText.t("battle.enemy_marker",{"slot":"%02d" % (int(enemy.slot)+1)})
	var caption_font_size:=12
	var caption_size:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_font_size)
	var caption_left:=left
	if outer_wing:
		# Outer wing labels use the space away from the neighbouring centre fleet.
		caption_left=clampf(pos.x if pos.x>=BATTLE_VIEW_SIZE.x*0.5 else pos.x-caption_size.x,6,BATTLE_VIEW_SIZE.x-caption_size.x-6)
	var caption_position:=Vector2(caption_left,maxf(20,top-5))
	return {"health":Rect2(left,maxf(6,top),bar_width,4),"shield":Rect2(left,maxf(6,top-7),bar_width,4),"caption":caption,"caption_position":caption_position,"caption_bounds":Rect2(caption_position-Vector2(0,font.get_ascent(caption_font_size)),Vector2(caption_size.x,font.get_ascent(caption_font_size)+font.get_descent(caption_font_size)))}

func draw_environment_event(_offset:Vector2)->void:
	encounter_presentation.draw_fall(draw_surface)

func draw_stars()->void:
	var mat:ShaderMaterial=stars_layer.material
	mat.set_shader_parameter("hyperspace",encounter_presentation.scenery_presence)
	if scenery_material_route!=encounter_presentation.scenery_route:
		scenery_material_route=encounter_presentation.scenery_route
		var route_index:int=maxi(0,["alpha","beta","gamma","delta"].find(scenery_material_route))
		mat.set_shader_parameter("route_origin",Vector2(float(route_index%2)*0.5,0.5 if route_index>=2 else 0.0))
	var scenery_time:float=encounter_presentation.scenery_time
	mat.set_shader_parameter("scene_motion",Vector2(sin(scenery_time*0.075),sin(scenery_time*0.11)))
	super.draw_stars()

func draw_encounter_backdrop()->void:
	# These ordinary CanvasItem primitives must not inherit the star mesh's
	# metadata shader. Use the existing battle layer, behind combat drawings.
	encounter_presentation.draw_space(draw_surface,BATTLE_VIEW_SIZE)
	var cue := ""
	if encounter_presentation.transition<1.8:
		if encounter_presentation.departure:
			cue=UIText.t("battle.return_cleared" if encounter_presentation.return_success else "battle.return_main")
		elif not encounter_presentation.route.is_empty():
			cue=UIText.t("hyperspace."+encounter_presentation.route)
	elif encounter_presentation.clear_age<1.8:
		cue=UIText.t("battle.finale_cleared")
	if not cue.is_empty():
		var cue_width := font.get_string_size(cue,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_surface.draw_rect(Rect2(Vector2((BATTLE_VIEW_SIZE.x-cue_width)*0.5-14,62),Vector2(cue_width+28,34)),Color("101b2b"))
		draw_surface.draw_string(font,Vector2((BATTLE_VIEW_SIZE.x-cue_width)*0.5,86),cue,HORIZONTAL_ALIGNMENT_LEFT,-1,18,encounter_presentation.accent)

func box(rect:Rect2,color:=PANEL,border:=LINE)->void:
	if is_instance_valid(overlay_layer) and draw_surface==overlay_layer:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(BATTLE_NAVY,color.a)
		style.border_color=Color("304958")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		draw_surface.draw_style_box(style,rect)
	else:super.box(rect,color,border)
