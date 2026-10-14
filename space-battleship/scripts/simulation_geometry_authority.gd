extends RefCounted
## Prototype simulation-owned mathematical geometry. No active scene objects.
const FIXED_LAYOUT=preload("res://scripts/enemy_fixed_layout.gd")
const ENEMY_VISUAL_ALIASES := {"laser_mon":"laser","cannon-mon":"cannon","missile-mon":"missile","longLaser-mon":"longLaser","missile_mon":"missile"}
var fixed_enemy_layout:=true
# Geometry publication belongs to this authority. Consumers retain only derived values.
var target_geometry_revision:=0
var target_geometry_signature:Array=[]
var target_geometry_entities:Array=[]
var fleet_geometry_revision:=0
var fleet_geometry_signature:Array=[]
var fleet_display_revision:int=-1
var fleet_display_arrays:Dictionary={}
var fixed_layout_revision:=0
var fixed_layout_signature:Array=[]
var game:BattleGame
var db:ShipDatabase
var fleet_angles_dirty := true
var fleet_pose
var player_anchor=Vector2.ZERO
var screen_scale=1.0
var captured_visuals:Dictionary={}
var captured_bounds={}
var prepared_hulls:Dictionary={}

const BATTLE_INVERSE_STEPS := 20

const BATTLE_LINEAR_INVERSE_OFFSET := 110.0 / (1 << BATTLE_INVERSE_STEPS)

const BATTLE_VIEW_SIZE := Vector2(572,960)

const ENEMY_FORMATION_WIDTH_CAP := 74.0

const BATTLE_VISUAL_DEFAULTS := {
	"player_ship_y":0.91, "player_hud_gap":14.0, "player_core_scale":0.65,
	"enemy_base_scale":0.34, "enemy_offset_y":12.0,
	"enemy_max_y":0.36, "enemy_player_min_gap":0.20, "enemy_entry_distance":50.0,
	"enemy_scale_variance":Vector2(0.90,1.08), "enemy_rotation_variance":4.0,
	"enemy_depth_scale_min":0.82, "enemy_depth_scale_max":1.12,
	"player_idle_x":5.0, "player_idle_y":3.0, "player_idle_rotation":0.7,
	"enemy_idle_x":8.0, "enemy_idle_y":7.0, "enemy_idle_rotation":1.3,
	"background_far_speed":3.0, "background_mid_speed":18.0,
	"background_near_speed":90.0, "background_object_density":0.9,
	"background_mid_opacity":0.16, "background_fog_opacity":0.22,
	"bullet_trail_scale":0.72, "laser_glow_scale":1.12, "missile_trail_scale":0.76,
	"muzzle_pulse_duration":0.12, "beam_hit_spark_scale":0.75,
	"damage_number_normal_duration":0.42, "damage_number_critical_duration":0.58,
	"hit_flash_duration":0.08, "destroy_effect_duration":0.52,
	"environment_event_enabled":true, "environment_event_interval":55.0,
	"boss_destroy_shake":3.0
}

var battle_visual: Dictionary = BATTLE_VISUAL_DEFAULTS.duplicate()

var enemy_poses: Dictionary = {}
var boundary_dead_geometry:Dictionary={}
var display_shapes:Dictionary={}
var pending_display_shapes:Array=[]
var display_row_cache:Dictionary={}
var display_row_builds:int=0
var display_row_reuses:int=0

const SHIP_ART_CANVAS := Vector2(887, 1774)

const SHIP_VISUALS := preload("res://scripts/ship_visuals.gd")

const ENEMY_RECOGNITION := preload("res://scripts/enemy_recognition_visual.gd")

var enemy_recognition = ENEMY_RECOGNITION.new()

const WEAPON_VISUAL := preload("res://scripts/weapon_visual.gd")

var visual_config: Dictionary = {}

var player_components: Array = []

var player_components_signature := ""

var enemy_entry_batch_active := false

var enemy_provider_query_active := false

var enemy_entry_distance_time := -INF

var enemy_entry_distance_value := 0.0

var battle_draw_active := false

var battle_draw_enemy_positions: Dictionary = {}

var turret_visuals: Dictionary = {}

var turret_ship := ""

var fx_time := 0.0

var battle_read_model=preload("res://scripts/battle_read_model.gd").new()

var battle_read_model_enabled:=true

func weapon_visual_key(key:String)->String:
	return str(ENEMY_VISUAL_ALIASES.get(key,key))

func weapon_key(shot: Dictionary) -> String:
	return weapon_visual_key(str(shot.key))

func turret_angle(index: int) -> float:
	if turret_ship!=str(game.profile.selectedShip) or not turret_visuals.has(index):return 0.0
	var pose: Dictionary = turret_visuals[index]
	return float(pose.angle) if is_same(pose.entry,game.slot_entry("weapons",index)) and pose.key==str(pose.entry.key) else 0.0

func ship_visual_entry(ship_key: String) -> Dictionary:
	return visual_config.get("ships",{}).get(ship_key,{})

func weapon_visual_profile(key: String) -> Dictionary:
	return visual_config.get("weapons",{}).get(weapon_visual_key(key),{})

func slot_hardpoint_index(ship_key: String, index: int) -> int:
	var ship := ship_visual_entry(ship_key)
	var mapping: Array = ship.get("slot_map",[])
	var points: Array = ship.get("hardpoints",[])
	if points.is_empty():return -1
	return clampi(int(mapping[index]) if index<mapping.size() else posmod(index,points.size()),0,points.size()-1)

func hardpoint_for_slot(ship_key: String, index: int) -> Dictionary:
	var point := slot_hardpoint_index(ship_key,index)
	return ship_visual_entry(ship_key).get("hardpoints",[])[point] if point>=0 else {}

func weapon_visual_role(index: int) -> String:
	var component = player_component_for_slot(index)
	return component.mode() if component!=null else "embedded"

func weapon_visual_angle(index: int) -> float:
	var role := weapon_visual_role(index)
	var limit := deg_to_rad(float(hardpoint_for_slot(str(game.profile.selectedShip),index).get("rotation_limit",0)))
	return clampf(turret_angle(index),-limit,limit)*(1.0 if role=="main" else 0.2 if role=="secondary" else 0.0)

func player_weapon_components() -> Array:
	if battle_draw_active:return player_components
	var ship_key := str(game.profile.selectedShip)
	var entries := game.weapon_entries()
	var signature := ship_key
	for entry in entries:signature += "|"+str(entry.get("key",""))
	if signature==player_components_signature:return player_components
	player_components_signature=signature
	player_components=compose_weapon_components(ship_key,entries,"ally")
	return player_components

func compose_weapon_components(ship_key: String, entries: Array, faction: String) -> Array:
	var components: Array = []
	var ship := ship_visual_entry(ship_key)
	var points: Array = ship.get("hardpoints",[])
	for point_index in points.size():
		var point: Dictionary = points[point_index]
		var bound: Array[int] = []
		var owner := -1
		for index in entries.size():
			if slot_hardpoint_index(ship_key,index)!=point_index:continue
			bound.append(index)
			var profile := weapon_visual_profile(str(entries[index].get("key","")))
			if profile.is_empty() or not point.get("allowed_weapon_visual_class",[]).has(profile.get("visual_class","")):continue
			if owner<0 or (str(weapon_visual_profile(str(entries[owner].get("key",""))).get("visual_class",""))=="missile" and str(profile.get("visual_class",""))!="missile"):
				owner=index
		if owner>=0:
			var component=WEAPON_VISUAL.new(point,weapon_visual_profile(str(entries[owner].key)),bound,owner,faction)
			if faction=="enemy":component.damage_type=int(db.enemy_weapon(str(entries[owner].key)).get("dmgtype",0))
			components.append(component)
	return components

func enemy_weapon_components(enemy: Dictionary) -> Array:
	if battle_read_model_enabled and battle_read_model.active:return battle_read_model.components(enemy)
	return _source_enemy_weapon_components(enemy)

func _source_enemy_weapon_components(enemy: Dictionary) -> Array:
	return _source_enemy_appearance(enemy).components

func enemy_appearance(enemy: Dictionary) -> Dictionary:
	if battle_read_model_enabled and battle_read_model.active:return battle_read_model.appearance(enemy)
	return _source_enemy_appearance(enemy)

func _source_enemy_appearance(enemy: Dictionary) -> Dictionary:
	# The immutable appearance owns components, descriptors and attack types
	# together. A spatial publication can outlive this slot's mutable pose.
	var pose := enemy_pose(enemy)
	var ship_key := "enemy_"+str(clampi(int(enemy.size),1,6))
	var signature := ship_key+":"+str(db.get_instance_id())
	for equipment in enemy.equipment:signature += "|"+str(equipment.get("name",""))
	if not pose.has("appearance") or str(pose.appearance.signature)!=signature:
		var entries: Array = []
		for equipment in enemy.equipment:entries.append({"key":str(equipment.get("name",""))})
		var components=compose_weapon_components(ship_key,entries,"enemy")
		var types:Array=[]
		for equipment in enemy.equipment:
			var damage_type:=int(db.enemy_weapon(str(equipment.name)).get("dmgtype",0))
			if damage_type in [1,2] and not types.has(damage_type):types.append(damage_type)
		pose.appearance={"signature":signature,"components":components,"mounts":enemy_recognition.descriptors(components),"types":types}
	return pose.appearance

func enemy_recognition_mounts(enemy:Dictionary)->Array:
	return enemy_appearance(enemy).mounts

func turret_pose(index: int) -> Dictionary:
	if turret_ship!=str(game.profile.selectedShip):
		turret_visuals.clear()
		fleet_angles_dirty=true
		turret_ship = str(game.profile.selectedShip)
	var entry := game.slot_entry("weapons",index)
	if not turret_visuals.has(index) or not is_same(turret_visuals[index].entry,entry) or turret_visuals[index].key!=str(entry.key):
		turret_visuals[index] = {"entry":entry,"key":str(entry.key),"angle":0.0,"target":{},"recoil":0.0}
		fleet_angles_dirty=true
	return turret_visuals[index]

func turret_muzzle(index:int)->Vector2:
	return launch_pose(index,Vector2.ZERO,0).position

func player_component_for_slot(index: int):
	for component in player_weapon_components():
		if component.slots.has(index):return component
	return null

func shot_mount(shot: Dictionary) -> int:
	if shot.hostile:return -1
	if not drone_identity(shot).is_empty() or int(shot.get("mount",-1))>=game.weapon_entries().size():return -1
	if shot.has("mount"):return int(shot.mount)
	var closest := -1
	var distance := INF
	for index in game.weapon_entries().size():
		if str(game.slot_entry("weapons",index).key)!=weapon_key(shot):continue
		var muzzle := Vector2(game.player.x,game.player.y)+game.player_weapon_offset(index)
		var candidate := muzzle.distance_squared_to(game.projectile_position(shot))
		if candidate<distance:
			distance = candidate
			closest = index
	return closest

func enemy_render_angle(enemy:Dictionary)->float:
	var pose:=enemy_pose(enemy)
	return float(pose.rotation)

# Supplied positions stay within one synchronous solve; no value survives it.

func enemy_component_pose(enemy:Dictionary,component,render_position:=Vector2.INF,known_width:float=-1.0)->Dictionary:
	var row:Dictionary=display_enemy(enemy)
	if (render_position==Vector2.INF or render_position==row.position) and (known_width<0.0 or known_width==float(row.width)):
		return row.components[int(component.owner_slot)]
	return _source_enemy_component_pose(enemy,component,render_position,known_width)

func _source_enemy_component_pose(enemy:Dictionary,component,render_position:=Vector2.INF,known_width:float=-1.0,frozen_angle:float=INF)->Dictionary:
	var point:Dictionary=component.hardpoint
	var position:Vector2=enemy_render_position(enemy) if render_position==Vector2.INF else render_position
	var width:=enemy_render_width_at_y(enemy,position.y) if known_width<0.0 else known_width
	var hull_angle:=enemy_render_angle(enemy) if frozen_angle==INF else frozen_angle
	var normalized:Array=point.pos
	var origin:=Vector2(float(normalized[0])*width,float(normalized[1])*width*2.0).rotated(PI+hull_angle)
	var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
	var module_width:=width*0.42*class_scale
	var angle:=PI/2+hull_angle+enemy_weapon_angle(enemy,component.owner_slot,position)+deg_to_rad(float(point.get("base_rotation",0)))
	var muzzle:Array=component.profile.get("muzzle",[[0.22,0]])
	var port:=Vector2(float(muzzle[0][0]),float(muzzle[0][1]))*module_width
	return {"origin":origin,"angle":angle,"width":module_width,"port":port,"muzzle":origin+port.rotated(angle)}

func execution_enemy_port_offset(enemy:Dictionary,index:int,render_position:Vector2)->Vector2:
	# A native input asks only for this muzzle, not a complete display packet.
	# Dead/departed contacts retain the existing frozen publication path.
	if GrowthNumber.compare(enemy.get("hp",0),0)<=0 or boundary_dead_geometry.has(int(enemy.uid)):
		return enemy_port_offset(enemy,index,render_position)
	var component=enemy_component_for_slot(enemy,index)
	if component!=null:return _source_enemy_component_pose(enemy,component,render_position).muzzle
	return enemy_port_offset(enemy,index,render_position)

func enemy_port_offset(enemy: Dictionary, index: int,render_position:=Vector2.INF) -> Vector2:
	var component=enemy_component_for_slot(enemy,index)
	if component!=null:return enemy_component_pose(enemy,component,render_position).muzzle
	# Unknown external configurations keep the previous logical mount fallback.
	var point:=hardpoint_for_slot("enemy_"+str(clampi(int(enemy.size),1,6)),index)
	if point.is_empty():return Vector2.ZERO
	var position:Vector2=enemy_render_position(enemy) if render_position==Vector2.INF else render_position
	var width:=enemy_render_width_at_y(enemy,position.y)
	var angle:=float(enemy_pose(enemy).rotation)
	var origin:=Vector2(float(point.pos[0])*width,float(point.pos[1])*width*2.0).rotated(PI+angle)
	var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
	return origin+Vector2(width*0.42*class_scale*0.22,0).rotated(PI/2+angle)

func enemy_weapon_angle(enemy: Dictionary, index: int,render_position:=Vector2.INF) -> float:
	var component = enemy_component_for_slot(enemy,index)
	if component==null:return 0.0
	var role: String = component.mode()
	if role!="main" and role!="secondary":return 0.0
	var pose_angle := enemy_render_angle(enemy)
	var position:Vector2=enemy_render_position(enemy) if render_position==Vector2.INF else render_position
	var desired := wrapf((player_render_position()-position).angle()-PI/2-pose_angle,-PI,PI)
	var limit := deg_to_rad(float(component.hardpoint.get("rotation_limit",0)))
	return clampf(desired,-limit,limit)*(1.0 if role=="main" else 0.2)

func enemy_component_for_slot(enemy: Dictionary, index: int):
	for component in enemy_weapon_components(enemy):
		if component.slots.has(index):return component
	return null

func enemy_shot_mount(enemy: Dictionary, shot: Dictionary) -> int:
	if is_same(enemy,shot.get("source",{})) and shot.has("mount"):return int(shot.mount)
	var origin := game.projectile_position(shot)
	var best := 0
	var distance := INF
	for index in enemy.equipment.size():
		var logical := Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,index)
		var candidate := logical.distance_squared_to(origin)
		if candidate<distance:
			distance = candidate
			best = index
	return best

func advance_turrets(dt: float) -> void:
	if game.paused:return
	var entries := game.weapon_entries()
	# Targets remain selected per mount. Reuse only their visual positions for
	# this invocation; identity guards slot reuse, and nothing survives a step.
	var target_positions: Dictionary = {}
	var beam_targets:Dictionary={}
	for shot in game.projectiles if game.state==BattleGame.State.COMBAT and not entries.is_empty() else []:
		if not shot.get("beam",false) or shot.hostile or shot.get("repeated",false):continue
		var mount:=int(shot.mount)
		if mount<0 or mount>=entries.size() or str(entries[mount].get("key","")).is_empty() or beam_targets.has(mount):continue
		if not bool(shot.get("chain_hop",false)) and game.long_laser_valid(shot):beam_targets[mount]=shot.target
	for index in turret_visuals.keys():
		if int(index)>=entries.size() or str(entries[index].key).is_empty():turret_visuals.erase(index)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if str(entry.key).is_empty():continue
		var pose := turret_pose(index)
		pose.recoil = maxf(0,float(pose.recoil)-dt)
		var target: Dictionary = pose.target
		# Preserve the first valid main beam in projectile order for each mount.
		# Repeats never own aim. This invocation's read-only index expires below.
		if beam_targets.has(index):target=beam_targets[index]
		if game.state!=BattleGame.State.COMBAT:
			target = {}
		elif target.is_empty() or not game.enemies.has(target) or float(target.get("hp",0))<=0:
			var candidates := game.targets(int(db.equip(str(entry.key),int(entry.level)).dmgtype))
			target = candidates[0] if not candidates.is_empty() else {}
		pose.target = target
		var desired := 0.0
		if not target.is_empty():
			var pivot := player_render_position()+player_mount_center(str(game.profile.selectedShip),index).rotated(-PI/2+player_idle_angle())*player_art_scale()
			var limit := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_limit_degrees",85.0)))
			var target_slot := int(target.get("slot",-1))
			var target_position: Vector2
			if target_positions.has(target_slot) and is_same(target_positions[target_slot].entity,target):
				target_position = target_positions[target_slot].position
			else:
				target_position = entity_render_position(target)
				target_positions[target_slot] = {"entity":target,"position":target_position}
			desired = clampf(wrapf((target_position-pivot).angle()+PI/2-player_idle_angle(),-PI,PI),-limit,limit)
		var speed := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_turn_degrees_per_second",240.0)))
		pose.angle = rotate_toward(float(pose.angle),desired,maxf(0,speed)*dt)

func visual_muzzle(shot: Dictionary) -> Vector2:
	var identity=drone_identity(shot)
	if not identity.is_empty():return drone_launch_pose(identity,Vector2.ZERO,0).position
	if shot.has("ballistic_target_origin"):return Vector2(shot.launch_point)
	var pos := game.projectile_position(shot)
	if shot.hostile:
		var nearest: Dictionary = {}
		var distance := INF
		for enemy in game.enemies:
			if is_same(enemy,shot.get("source",{})):
				var position:=enemy_render_position(enemy)
				return battle_logical_point(position+enemy_port_offset(enemy,enemy_shot_mount(enemy,shot),position))
			for index in enemy.equipment.size():
				var candidate := pos.distance_squared_to(Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,index))
				if candidate<distance:
					distance=candidate
					nearest=enemy
		if not nearest.is_empty():
			var position:=enemy_render_position(nearest)
			return battle_logical_point(position+enemy_port_offset(nearest,enemy_shot_mount(nearest,shot),position))
		return pos
	var index := shot_mount(shot)
	if index>=0:return turret_muzzle(index)
	var source := Vector2(game.player.x,game.player.y)
	return source+(pos-source)*player_art_scale()/SHIP_VISUALS.scale_for(db.ship(str(game.profile.selectedShip)))

func player_base_art_scale_for(ship_key: String) -> float:
	var entry := ship_visual_entry(ship_key)
	return float(entry.get("display_scale",minf(SHIP_VISUALS.scale_for(db.ship(ship_key)),0.18)))*SHIP_VISUALS.player_display_multiplier()

func player_base_art_scale() -> float:
	return player_base_art_scale_for(str(game.profile.selectedShip))

func player_art_scale_for(ship_key: String) -> float:
	return player_base_art_scale_for(ship_key)*float(db.config.get("playerVisualScale"+ship_key,1.0))

func player_art_scale() -> float:
	return player_art_scale_for(str(game.profile.selectedShip))

func enemy_config_visual_scale(size: int) -> float:
	return float(db.config.get("enemyVisualScaleSize"+str(clampi(size,1,6)),1.0))

func enemy_formation_anchor(slot: int, large: bool, size: int, columns := 10) -> Vector2:
	var scale_offset := maxf(0.0,enemy_config_visual_scale(size)-1.0)*35.0
	if columns==5:return BattleGame.enemy_slot_position(slot,columns)+Vector2(0,scale_offset)
	return Vector2(BattleGame.enemy_slot_position(slot).x,(130.0 if large else 120.0)+scale_offset)

func enemy_pose(enemy: Dictionary) -> Dictionary:
	var frozen:Dictionary=boundary_dead_geometry.get(int(enemy.uid),{})
	if not frozen.is_empty() and is_same(frozen.entity,enemy):return frozen.pose
	# One mutable pose per slot, with exact entity identity. Residual access
	# to a dead/departed entity may recreate this legacy pose; appearance
	# publications own their immutable descriptors independently. Consumers
	# rebind when this mutable identity changes, including same-uid replacement.
	var slot := int(enemy.slot)
	if enemy_poses.has(slot) and is_same(enemy_poses[slot].entity,enemy):return enemy_poses[slot]
	# Local deterministic generator never consumes the combat RNG stream.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(enemy.get("uid",slot))*7919+slot*104729
	var phase := rng.randf()*TAU
	var offset := Vector2(0,rng.randf_range(-battle_visual.enemy_offset_y,battle_visual.enemy_offset_y))
	var large := game.is_final_encounter() or game.enemies.any(func(item):return int(item.size)>=4)
	var columns:=int(enemy.get("formation_columns",10))
	if game.enemies.size()>columns and not enemy.get("explicit_formation",false):columns=5
	var anchor := enemy_formation_anchor(slot,large,int(enemy.size),columns)
	anchor.x += float(enemy.x)-BattleGame.enemy_slot_position(slot,columns).x
	if enemy.get("size_formation",false):
		anchor = battle_point(Vector2(enemy.x,enemy.y))
		offset = Vector2.ZERO
	# Preserve left-to-right slot order. Hull overlap is allowed for this line.
	var target := anchor+offset
	if not enemy.get("explicit_formation",false):target.x = clampf(target.x,54.0,BATTLE_VIEW_SIZE.x-54.0)
	var pose := {"entity":enemy,"logical_position":Vector2(enemy.x,enemy.y),"target":target,"phase":phase,"born":fx_time,
		"variance":rng.randf_range(battle_visual.enemy_scale_variance.x,battle_visual.enemy_scale_variance.y),
		"rotation":deg_to_rad(rng.randf_range(-battle_visual.enemy_rotation_variance,battle_visual.enemy_rotation_variance)),
		"duration":rng.randf_range(0.65,1.15),"entry_x":rng.randf_range(-2,2)}
	enemy_poses[slot] = pose
	return pose

func enemy_render_width(enemy: Dictionary) -> float:
	return enemy_render_width_at_y(enemy,enemy_render_position(enemy).y)

func enemy_render_width_at_y(enemy: Dictionary, y:float) -> float:
	if battle_read_model_enabled and battle_read_model.active:return battle_read_model.width_at(enemy,y)
	return _source_enemy_render_width_at_y(enemy,y)

func _source_enemy_render_width_at_y(enemy:Dictionary,_y:float,variance:float=-1.0,_frozen_frontline:float=INF)->float:
	if variance>=0.0:return FIXED_LAYOUT.width(self,enemy,variance)
	return float(FIXED_LAYOUT.ensure(self,enemy,enemy_pose(enemy)).width)

func enemy_display_top_clearance(enemy:Dictionary,_y:float)->float:
	return float(FIXED_LAYOUT.ensure(self,enemy,enemy_pose(enemy)).top)

func enemy_safe_entry_distance()->float:
	return float(battle_visual.enemy_entry_distance)

func enemy_frontline_y_limit(enemy: Dictionary) -> float:
	if battle_read_model_enabled and battle_read_model.active:return battle_read_model.frontline(enemy)
	return _source_enemy_frontline_y_limit(enemy)

func _source_enemy_frontline_y_limit(enemy:Dictionary)->float:
	return float(FIXED_LAYOUT.ensure(self,enemy,enemy_pose(enemy)).frontline)

func enemy_render_position(enemy: Dictionary) -> Vector2:
	var frozen:Dictionary=boundary_dead_geometry.get(int(enemy.uid),{})
	if not frozen.is_empty() and is_same(frozen.entity,enemy):return frozen.value.position
	var cached:Dictionary=battle_draw_enemy_positions.get(int(enemy.slot),{}) if battle_draw_active else {}
	if not cached.is_empty() and is_same(cached.entity,enemy):return cached.position
	var point:Vector2=battle_read_model.position(enemy) if battle_read_model_enabled and battle_read_model.active else _source_enemy_render_position(enemy)
	if battle_draw_active:battle_draw_enemy_positions[int(enemy.slot)]={"entity":enemy,"position":point}
	return point

func _source_enemy_render_position(enemy:Dictionary)->Vector2:
	var frozen:Dictionary=boundary_dead_geometry.get(int(enemy.uid),{})
	if not frozen.is_empty() and is_same(frozen.entity,enemy):return frozen.value.position
	var point:Vector2=FIXED_LAYOUT.position(self,enemy,enemy_pose(enemy))
	if battle_draw_active:battle_draw_enemy_positions[int(enemy.slot)]={"entity":enemy,"position":point}
	return point

func entity_render_position(entity: Dictionary) -> Vector2:
	if is_same(entity,game.player):return player_render_position()
	if entity.has("slot"):return enemy_render_position(entity)
	return battle_point(Vector2(entity.x,entity.y))

func battle_point(point: Vector2) -> Vector2:
	# Presentation only: open the engagement corridor without stretching hulls or FX.
	return Vector2(point.x,point.y+smoothstep(220.0,420.0,point.y)*220.0)

func enemy_drop_anchor(enemy: Dictionary) -> Vector2:
	var position:=enemy_render_position(enemy)
	return position+Vector2(0,enemy_render_width_at_y(enemy,position.y)+12.0)

func battle_logical_point(point: Vector2) -> Vector2:
	# In these affine regions all original comparisons take the same branch.
	# Preserve the finite-bisection midpoint bias, rather than replacing it
	# with the mathematical inverse and moving missile collision coordinates.
	if point.y>=-512.0 and point.y<=220.0:
		return Vector2(point.x,point.y-BATTLE_LINEAR_INVERSE_OFFSET)
	if point.y>=640.0 and point.y<=2048.0:
		return Vector2(point.x,point.y-220.0+BATTLE_LINEAR_INVERSE_OFFSET)
	if game.combat_presentation!=null:return game.combat_presentation.battle_logical_point(point)
	var low := point.y-220.0
	var high := point.y
	for iteration in BATTLE_INVERSE_STEPS:
		var middle := (low+high)*0.5
		if battle_point(Vector2(0,middle)).y<point.y:low=middle
		else:high=middle
	return Vector2(point.x,(low+high)*0.5)

func beam_style(shot: Dictionary) -> Dictionary:
	var weapon: Dictionary = game.db.enemy_weapon(shot.entry.name) if shot.hostile else shot.weapon # Match damage source.
	var multiplier := game.long_laser_multiplier(weapon,maxf(0,float(shot.elapsed)-maxf(0,float(shot.charge))))
	var power := clampf((multiplier-1.0)/(float(weapon.para2)-1.0),0,1) if float(weapon.para2)>1 else 1.0
	var first_hit := float(shot.charge) if float(shot.charge)>=0 else float(shot.weapon.cd)
	var since_tick := float(shot.elapsed)-(first_hit+(int(shot.ticks)-1)*float(shot.weapon.cd))
	var pulse := maxf(0,1.0-since_tick/minf(0.12,float(shot.weapon.cd)*0.6)) if int(shot.ticks)>0 else 0.0
	return {"power":power,"width":lerpf(1.2,2.8,power)+pulse*0.6,"glow":0.05+power*0.045+pulse*0.2,"pulse":pulse}

func enemy_recognition_geometry(enemy: Dictionary, known_width:float=-1.0) -> Dictionary:
	var texture := ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
	var mounts := enemy_recognition_mounts(enemy)
	var width:=enemy_render_width(enemy) if known_width<0.0 else known_width
	return geometry_from_descriptor(texture,width,mounts,float(enemy.get("max_shield",0))>0 and float(enemy.get("shieldRecovery",0))>0,enemy_pose(enemy),enemy_recognition_screen_scale(),int(enemy.size)>=4)

var reference_height=0.0
var demo_time=0.0
var canonical_generation=0
var prepared=false
var previous_providers:Dictionary={}
var previous_spatial_source
var current_hull=""

# Main-thread preparation captures immutable imported descriptors and alpha
# envelopes. No prepare/texture read/scene method is permitted after ownership
# is handed to a simulation owner.
func prepare(owner,simulation:BattleGame)->void:
	game=simulation;db=simulation.db
	# The fixture/UI may have changed loadout since the last native pose.
	# Complete this main-thread descriptor boundary before capturing ownership.
	owner.ship_view.set_hull(str(game.profile.selectedShip))
	owner.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
	owner.current_hull=str(game.profile.selectedShip)
	owner._set_reference_dimensions()
	owner.hyperspace_visual.sync(game.profile.hyperspace.inventory)
	battle_visual=owner.battle_visual.duplicate(true)
	visual_config=owner.visual_config.duplicate(true)
	player_anchor=owner.player_render_position()
	screen_scale=owner.enemy_recognition_screen_scale()
	reference_height=owner.reference_height
	demo_time=owner.demo_time;fx_time=owner.fx_time
	turret_ship=owner.turret_ship
	# Bind live entity identities exclusively to this simulation instance.
	turret_visuals=owner.turret_visuals.duplicate(true)
	for index in turret_visuals:
		turret_visuals[index].entry=game.slot_entry("weapons",int(index))
		var previous:Dictionary=owner.turret_visuals[index].target
		turret_visuals[index].target=resolve_entity(previous)
	enemy_poses=owner.enemy_poses.duplicate(true)
	for slot in enemy_poses:enemy_poses[slot].entity=resolve_entity(owner.enemy_poses[slot].entity)
	for key in visual_config.get("ships",{}):
		var texture=owner.ship_hull_texture(key)
		if texture!=null:
			var identity=texture.get_instance_id()
			var bounds=owner.enemy_hull_bounds(texture)
			var profile=owner.enemy_recognition.hull_profile(texture).duplicate()
			captured_visuals[str(visual_config.ships[key].get("texture",""))]={"identity":identity,"bounds":bounds,"profile":profile}
			captured_bounds[identity]=bounds
	fleet_pose=preload("res://scripts/logical_fleet_pose.gd").new()
	fleet_pose.prepare(owner.ship_view)
	fleet_pose.manifest=fleet_pose.manifest.duplicate(true)
	fleet_pose.configure(str(game.profile.selectedShip),game.weapon_entries(),game.active_slot_count("weapons"),game.profile.hyperspace.inventory)
	# Capture every authored hull's footprint before worker admission. Runtime
	# ship commands choose immutable descriptors; they never instantiate/read Nodes.
	for key in fleet_pose.manifest.hulls:
		var texture=owner.ship_hull_texture(key);var image=texture.get_image()
		var factor=float(battle_visual.player_core_scale)*player_art_scale_for(key)
		var hull:Dictionary=fleet_pose.manifest.hulls[key]
		var radius=float(fleet_pose.manifest.weapon_contract.conservative_xz_rotation_radius)
		var left=float(hull.godot_aabb_min[0]);var right=float(hull.godot_aabb_max[0])
		for point in hull.weapon_mounts:
			left=minf(left,float(point.position[0])-radius);right=maxf(right,float(point.position[0])+radius)
		for offset in hull.drone_offsets:
			left=minf(left,float(offset[0])+minf(-radius,float(fleet_pose.manifest.drone.godot_aabb_min[0])))
			right=maxf(right,float(offset[0])+maxf(radius,float(fleet_pose.manifest.drone.godot_aabb_max[0])))
		var height=minf(float(image.get_used_rect().size.y)*factor,BATTLE_VIEW_SIZE.x*0.90*float(hull.model_span)/(right-left))
		height*=0.74 if key=="Heavy_Battleship" else 0.85 if key=="Battleship" else 1.0
		image.convert(Image.FORMAT_RGBA8);var pixels=image.get_data();var width=image.get_width();var bottom=image.get_height()
		for y in range(image.get_height()-1,-1,-1):
			var found=false
			for x in range(0,width,2):
				if pixels[(y*width+x)*4+3]>8:bottom=y+1;found=true;break
			if found:break
		var tail=(float(bottom)-SHIP_ART_CANVAS.y*0.5)*factor
		var reference_half=SHIP_ART_CANVAS.y*float(battle_visual.player_core_scale)*0.18*1.15*0.5
		var anchor_y=BATTLE_VIEW_SIZE.y*float(battle_visual.player_ship_y)+maxf(0,reference_half-SHIP_ART_CANVAS.y*factor*0.5)
		anchor_y=minf(anchor_y,1132.0-owner.BATTLE_ORIGIN.y-float(battle_visual.player_hud_gap)-tail-absf(float(battle_visual.player_idle_y)))
		anchor_y=minf(anchor_y,BATTLE_VIEW_SIZE.y-float(battle_visual.player_hud_gap)-height*0.5)
		prepared_hulls[key]={"height":height,"anchor_y":anchor_y}
	current_hull=str(game.profile.selectedShip)
	# Ownership handoff begins at the exact existing logical pose, including
	# startup steps. Descriptors alone do not reproduce accumulated orbit time.
	fleet_pose.orbit_elapsed=owner.ship_view.orbit_elapsed
	fleet_pose.elapsed=owner.ship_view.elapsed
	fleet_pose.ship_transform=owner.ship_view.ship.transform
	fleet_pose.orbit_center=owner.ship_view.orbit_center
	fleet_pose.rendered_position=owner.ship_view.rendered_position
	fleet_pose.rendered_height=owner.ship_view.rendered_height
	for index in fleet_pose.modules.size():fleet_pose.modules[index].pivot=owner.ship_view.modules[index].pivot.transform
	for index in fleet_pose.carriers.size():
		fleet_pose.carriers[index].transform=owner.ship_view.carriers[index].transform
		fleet_pose.carriers[index].euler=owner.ship_view.carriers[index].rotation
	for index in fleet_pose.drones.size():fleet_pose.drones[index].transform=owner.hyperspace_visual.nodes[index].transform
	fleet_pose.invalidate_pose()
	battle_read_model.setup(self)
	sync_fixed_layout()
	prepared=true

func sync_fixed_layout()->bool:
	if not FIXED_LAYOUT.sync(self):return false
	display_row_cache.clear()
	battle_read_model.invalidate_membership()
	refresh_frozen_layouts()
	return true

func sync_screen_scale(value:float)->bool:
	if not is_finite(value) or value<=0.0 or is_equal_approx(screen_scale,value):return false
	screen_scale=value
	display_row_cache.clear();display_shapes.clear();pending_display_shapes.clear()
	battle_draw_enemy_positions.clear();enemy_entry_distance_time=-INF
	battle_read_model.invalidate_membership()
	for pose in enemy_poses.values():invalidate_pose_scale(pose)
	sync_fixed_layout()
	return true

func refresh_frozen_layouts()->void:
	for record in boundary_dead_geometry.values():
		invalidate_pose_scale(record.pose)
		var enemy:Dictionary=record.entity;var row:Dictionary=record.value.duplicate()
		var variance:float=record.pose.variance;var frontline:float=row.frontline
		var width:=_source_enemy_render_width_at_y(enemy,row.position.y,variance,frontline)
		row.width=width
		row.width_low=_source_enemy_render_width_at_y(enemy,90.0,variance,frontline)
		row.width_high=_source_enemy_render_width_at_y(enemy,floorf(frontline),variance,frontline)
		var components:Dictionary={}
		for component in record.pose.appearance.components:
			components[int(component.owner_slot)]=_source_enemy_component_pose(enemy,component,row.position,width,row.angle)
		row.components=components;row.recognition_id=display_shape(enemy,width,record.pose)
		record.value=row

func invalidate_pose_scale(pose:Dictionary)->void:
	# Shield recovery and birth/animation history are not geometry caches.
	for key in ["fixed_layout","top_geometries","steady_position_key","steady_position_time","recognition_signature","recognition_geometry","recognition_contract_signature","recognition_width_packets","recognition_width_order"]:pose.erase(key)

func freeze_display_entity(enemy:Dictionary,current:bool=false)->void:
	var uid:int=int(enemy.uid)
	if boundary_dead_geometry.has(uid) and is_same(boundary_dead_geometry[uid].entity,enemy):return
	var cached:Dictionary=display_row_cache.get(uid,{})
	if not current and not cached.is_empty() and is_same(cached.entity,enemy):
		boundary_dead_geometry[uid]={"entity":enemy,"pose":cached.pose,"value":cached.value}
	else:
		var row:=display_enemy(enemy)
		boundary_dead_geometry[uid]={"entity":enemy,"pose":enemy_pose(enemy),"value":row}

func player_render_position()->Vector2:
	return player_anchor
func player_idle_angle()->float:return 0.0
func player_mount_center(_key:String,index:int)->Vector2:
	var point:Vector2=fleet_pose.screen_mount_for_slot(index)
	return (point-player_render_position()).rotated(PI/2)/player_art_scale()
func enemy_recognition_screen_scale()->float:return screen_scale
func player_visible_tail()->float:return reference_height*0.5
func visual_texture(path:String)->Dictionary:
	assert(captured_visuals.has(path),"Uncompiled visual geometry descriptor")
	return captured_visuals[path]
func ship_hull_texture(key:String)->Dictionary:
	return visual_texture(str(ship_visual_entry(key).get("texture","")))
func enemy_hull_bounds(descriptor:Dictionary)->Rect2:
	return descriptor.bounds
func visual_region(path:String)->Rect2:
	return visual_texture(path).bounds
func geometry_from_descriptor(descriptor:Dictionary,width:float,mounts:Array,repair:bool,cache:Dictionary,scale_value:float,large:bool=false)->Dictionary:
	return enemy_recognition.geometry_from_profile(int(descriptor.identity),descriptor.profile,width,mounts,repair,cache,scale_value,large)

func sync_hull()->void:
	var key=str(game.profile.selectedShip)
	if key==current_hull:return
	assert(prepared_hulls.has(key),"Hull has no main-thread compiled descriptors")
	current_hull=key;reference_height=prepared_hulls[key].height
	player_anchor=Vector2(game.player.x,prepared_hulls[key].anchor_y)
	fleet_pose.configuration_dirty=true
	fleet_pose.configure(key,game.weapon_entries(),game.active_slot_count("weapons"),game.profile.hyperspace.inventory)

func refresh_target_geometry()->void:
	# One boundary scan. Include exact identity, entry progress and actual movement;
	# elapsed time alone is not a dependency of a resident hull.
	var signature:Array=[fixed_layout_revision,battle_read_model.shape_revision,player_anchor,screen_scale]
	var entities:Array=[]
	var replaced:bool=target_geometry_entities.size()!=game.enemies.size()
	for enemy in game.enemies:
		var index:int=entities.size()
		entities.append(enemy)
		if not replaced and not is_same(target_geometry_entities[index],enemy):replaced=true
		var pose:Dictionary=enemy_pose(enemy)
		signature.append([int(enemy.uid),Vector2(enemy.x,enemy.y),enemy.hp>0,pose.target,pose.logical_position,pose.born,pose.duration,pose.entry_x,pose.rotation,pose.variance,minf(fx_time,float(pose.born)+float(pose.duration))])
	if not replaced and signature==target_geometry_signature:return
	target_geometry_signature=signature;target_geometry_entities=entities
	target_geometry_revision+=1

func refresh_fleet_geometry()->void:
	ensure_fleet_geometry()
	var signature:Array=[current_hull,fleet_pose.ship_transform,fleet_pose.rendered_position,fleet_pose.rendered_height]
	for module in fleet_pose.modules:signature.append([module.assignment,module.pivot])
	for carrier in fleet_pose.carriers:signature.append(carrier.transform)
	for drone in fleet_pose.drones:signature.append([drone.id,drone.transform])
	if signature==fleet_geometry_signature:return
	fleet_geometry_signature=signature;fleet_geometry_revision+=1

func before_tick(dt:float)->void:
	assert(prepared)
	sync_fixed_layout()
	if game.paused:return
	enemy_entry_batch_active=true;enemy_entry_distance_time=-INF
	if battle_read_model_enabled:battle_read_model.begin()
	for enemy in game.enemies:enemy_pose(enemy)
	sync_hull()
	fleet_pose.configure(current_hull,game.weapon_entries(),game.active_slot_count("weapons"),game.profile.hyperspace.inventory)
	demo_time+=dt
	fleet_pose.pose_base(player_render_position(),reference_height,0.0,demo_time,false,dt)
	fx_time+=dt
	advance_turrets(dt)
	sync_fleet_angles()
	canonical_generation+=1

func finish_display_boundary()->void:
	# Original label placement consumes the completed pose before Main removes
	# dead pose caches. Preserve that display value while source cleanup remains
	# at its required logical boundary; a later residual query may recreate pose.
	for enemy in game.enemies:
		if GrowthNumber.compare(enemy.get("hp",0),0)<=0:freeze_display_entity(enemy,true)
	# Match Main.refresh_draw_layers once per external advance, not per substep.
	# Legacy dead/departed records may be queried again and recreate their pose.
	for slot in enemy_poses.keys():
		var record:Dictionary=enemy_poses[slot].entity
		if not game.enemies.has(record) or GrowthNumber.compare(record.get("hp",0),0)<=0:
			freeze_display_entity(record);enemy_poses.erase(slot)
	for enemy in game.enemies:
		if GrowthNumber.compare(enemy.get("hp",0),0)>0:enemy_pose(enemy)
func after_tick()->void:
	if battle_read_model_enabled:battle_read_model.end()
	enemy_entry_batch_active=false
	enemy_entry_distance_time=-INF

func target_point(target:Dictionary)->Vector2:
	var previous=enemy_provider_query_active
	enemy_provider_query_active=true
	var result=battle_logical_point(entity_render_position(target))
	enemy_provider_query_active=previous
	return result
func sync_fleet_angles()->void:
	var angles:Array=[]
	for index in game.weapon_entries().size():angles.append(turret_angle(index))
	fleet_pose.set_slot_angles(angles)
	fleet_angles_dirty=false

func ensure_fleet_geometry()->void:
	if fleet_pose.configuration_dirty:
		fleet_pose.configure(current_hull,game.weapon_entries(),game.active_slot_count("weapons"),game.profile.hyperspace.inventory)
		fleet_pose.pose_base(player_render_position(),reference_height,0.0,demo_time,false,0.0)
		fleet_angles_dirty=true
	if fleet_angles_dirty:sync_fleet_angles()

func launch_pose(slot:int,aim:Vector2,ordinal:int)->Dictionary:
	# Launch providers run before fire feedback; validate only this source slot.
	turret_pose(slot)
	ensure_fleet_geometry()
	var point:Vector2=battle_logical_point(fleet_pose.screen_muzzle_for_slot(slot,ordinal))
	return {"position":point,"direction":(aim-point).normalized(),"screen_origin":battle_point(point),"screen_aim":battle_point(aim)}
func drone_launch_pose(identity:String,aim:Vector2,ordinal:int)->Dictionary:
	ensure_fleet_geometry()
	var point:Vector2=battle_logical_point(fleet_pose.screen_muzzle_for_drone(identity,ordinal))
	return {"position":point,"direction":(aim-point).normalized(),"screen_origin":battle_point(point),"screen_aim":battle_point(aim)}
func rail_geometry(shot:Dictionary)->Dictionary:
	return {"origin":battle_point(visual_muzzle(shot)),"aim":entity_render_position(shot.target),"bounds":BATTLE_VIEW_SIZE,"full_width":maxf(12.0,float(db.weapon_motion_value("rail_trail_width",28.0)))*maxf(1.0,float(shot.get("rail_width_multiplier",1.0)))}

func on_simulation_event(kind:String,info:Dictionary)->void:
	if kind=="explode":
		for enemy in game.enemies:
			if int(enemy.uid)==int(info.get("uid",-1)):freeze_display_entity(enemy,true);break
	var changed=kind in ["state","encounter","explode","retreat","wave_clear","ship_changed","module_changed","upgrade","configuration_changed","progress_loaded"] or (kind=="equipment_stats" and not bool(info.get("counter_only",false)))
	if changed:
		display_row_cache.clear()
		for pose in enemy_poses.values():pose.erase("fixed_layout")
		sync_hull()
		battle_read_model.invalidate_membership()
		enemy_entry_distance_time=-INF
		fleet_pose.configuration_dirty=true
		fleet_angles_dirty=true
	if kind in ["fire","beam_started"] and info.has("shot"):
		var shot:Dictionary=info.shot
		var mount=shot_mount(shot)
		if mount<0:return
		var pose=turret_pose(mount)
		if kind=="beam_started":pose.fired_at=fx_time;return
		var key=weapon_key(shot)
		if key=="longLaser":return
		if key=="cannon":pose.recoil=0.13
		if not bool(shot.get("owns_primary_aim",not bool(shot.get("repeated",false)) and not bool(shot.get("chain_hop",false)))):return
		# Follow the kernel's main selection. Distributed tubes/scatter births carry
		# that same owner target; repeats and secondary/chain carriers cannot write it.
		pose.target=shot.get("primary_target",shot.target)
		pose.fired_at=fx_time

func drone_identity(shot:Dictionary)->String:
	if bool(shot.get("hostile",false)):return ""
	var identity=str(shot.get("entry",{}).get("drone_id",""))
	if not identity.is_empty():return identity
	var source=str(shot.get("combat_context",{}).get("source_id",""))
	return source.trim_prefix("drone:") if source.begins_with("drone:") else ""

func resolve_entity(previous:Dictionary)->Dictionary:
	if previous.is_empty():return {}
	if not previous.has("uid"):return game.player
	for enemy in game.enemies:
		if int(enemy.get("uid",-1))==int(previous.uid):return enemy
	return {}

func close(restoration:Dictionary={})->void:
	# RefCounted signal/provider/spatial links form cycles unless detached explicitly.
	if game!=null:
		if game.event.is_connected(on_simulation_event):game.event.disconnect(on_simulation_event)
		var providers:Dictionary=restoration.get("providers",previous_providers)
		for key in providers:game.set(key,providers[key])
		game.target_spatial_source=restoration.get("spatial",previous_spatial_source)
	previous_providers.clear();previous_spatial_source=null
	battle_read_model.end();battle_read_model.host=null
	battle_read_model.records.clear();battle_read_model.bounds_members.clear()
	captured_visuals.clear();captured_bounds.clear()
	enemy_poses.clear();display_shapes.clear();boundary_dead_geometry.clear();display_row_cache.clear();turret_visuals.clear();fleet_pose=null
	game=null;db=null;prepared=false

func display_descriptor(enemy:Dictionary)->Dictionary:
	var appearance:Dictionary=enemy_appearance(enemy)
	var components:Array=[]
	for component in appearance.components:
		components.append({"hardpoint":component.hardpoint.duplicate(true),"profile":component.profile.duplicate(true),"slots":component.slots.duplicate(),"owner_slot":component.owner_slot,"damage_type":component.damage_type})
	return {"components":components,"mounts":appearance.mounts.duplicate(true),"types":appearance.types.duplicate()}
func display_enemy(enemy:Dictionary)->Dictionary:
	var frozen:Dictionary=boundary_dead_geometry.get(int(enemy.uid),{})
	if not frozen.is_empty() and is_same(frozen.entity,enemy):return frozen.value
	var uid:int=int(enemy.uid);var pose:Dictionary=enemy_pose(enemy)
	var logical:Vector2=Vector2(enemy.x,enemy.y)
	var cached:Dictionary=display_row_cache.get(uid,{})
	# The pose owns stationary geometry. Clock changes alone do not invalidate
	# this immutable row; entry, layout, aim anchor and authoring changes do.
	if not cached.is_empty() and is_same(cached.entity,enemy) and is_same(cached.pose,pose) and is_same(cached.layout,pose.get("fixed_layout")) and cached.settled and fx_time>=float(pose.born)+float(pose.duration) and cached.player_anchor==player_anchor and cached.logical==logical and display_pose_values_match(cached.value.pose,pose) and is_same(cached.appearance,pose.get("appearance")):
		display_row_reuses+=1;return cached.value
	var position:Vector2=enemy_render_position(enemy)
	display_row_builds+=1
	var width:float=enemy_render_width_at_y(enemy,position.y)
	var components:Dictionary={}
	for component in enemy_weapon_components(enemy):
		components[int(component.owner_slot)]=_source_enemy_component_pose(enemy,component,position,width)
	var values:Dictionary={}
	for key in ["logical_position","target","phase","born","variance","rotation","duration","entry_x"]:values[key]=pose[key]
	var result={"position":position,"width":width,"angle":enemy_render_angle(enemy),"frontline":enemy_frontline_y_limit(enemy),"width_low":enemy_render_width_at_y(enemy,90.0),"width_high":enemy_render_width_at_y(enemy,floorf(enemy_frontline_y_limit(enemy))),"components":components,"recognition_id":display_shape(enemy,width),"pose":values}
	display_row_cache[uid]={"settled":fx_time>=float(pose.born)+float(pose.duration),"entity":enemy,"pose":pose,"layout":pose.get("fixed_layout"),"player_anchor":player_anchor,"logical":logical,"appearance":pose.get("appearance"),"value":result}
	return result
func display_frame(enemies:Array,with_fleet:bool=true)->Dictionary:
	var values:Dictionary={}
	for enemy in enemies:
		if enemy.has("uid"):
			var uid:int=int(enemy.uid)
			values[uid]=boundary_dead_geometry[uid].value if with_fleet and boundary_dead_geometry.has(uid) else display_enemy(enemy)
	var result={"player_position":player_render_position(),"enemies":values,"shapes":pending_display_shapes}
	pending_display_shapes=[]
	if with_fleet:
		ensure_fleet_geometry()
		refresh_fleet_geometry()
		if fleet_display_revision!=fleet_geometry_revision:
			var pivots:Array=[];var carriers:Array=[];var drones:Dictionary={}
			for module in fleet_pose.modules:pivots.append({"slot":int(module.assignment.slot),"transform":module.pivot})
			for carrier in fleet_pose.carriers:carriers.append(carrier.transform)
			for drone in fleet_pose.drones:drones[str(drone.id)]=drone.transform
			fleet_display_arrays={"pivots":pivots,"carriers":carriers,"drones":drones}
			fleet_display_revision=fleet_geometry_revision
		result.fleet={"hull":current_hull,"ship":fleet_pose.ship_transform,"pivots":fleet_display_arrays.pivots,"carriers":fleet_display_arrays.carriers,"drones":fleet_display_arrays.drones,"rendered_position":fleet_pose.rendered_position,"rendered_height":fleet_pose.rendered_height,"orbit_center":fleet_pose.orbit_center,"orbit_elapsed":fleet_pose.orbit_elapsed,"elapsed":fleet_pose.elapsed}
	return result

func display_shape(enemy:Dictionary,width:float,frozen_pose:Dictionary={})->String:
	# Static outline packets travel only on birth/bucket/contract changes. Their
	# stable entity+bucket ID avoids repeating every packed outline in hit events.
	var uid:int=int(enemy.uid);var bucket:int=ceili(width*maxf(0.1,screen_scale)/2.0)
	var packet:Dictionary=enemy_recognition_geometry(enemy,width) if frozen_pose.is_empty() else geometry_from_descriptor(ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),width,frozen_pose.appearance.mounts,float(enemy.get("max_shield",0))>0 and float(enemy.get("shieldRecovery",0))>0,frozen_pose,screen_scale,int(enemy.size)>=4)
	if not display_shapes.has(uid):display_shapes[uid]={}
	var packets:Dictionary=display_shapes[uid];var identity:String=str(uid)+":"+str(bucket)
	if not packets.has(bucket) or (not is_same(packets[bucket],packet) and packets[bucket]!=packet):
		packets[bucket]=packet;pending_display_shapes.append({"id":identity,"uid":uid,"value":packet})
	return identity
func retire_display_entity(uid:int)->void:
	display_shapes.erase(uid);boundary_dead_geometry.erase(uid);display_row_cache.erase(uid)

func display_geometry_metrics()->Dictionary:
	return {"source_row_builds":display_row_builds,"source_row_reuses":display_row_reuses,"source_cached_entities":display_row_cache.size(),"source_shape_entities":display_shapes.size()}

func display_pose_values_match(values:Dictionary,pose:Dictionary)->bool:
	# A source callback may edit the same pose dictionary without a clock change.
	# Numeric inputs are compared by value; cache/recognition bookkeeping is not
	# an input, while a replaced appearance contract invalidates separately above.
	for key in ["logical_position","target","phase","born","variance","rotation","duration","entry_x"]:
		if values[key]!=pose[key]:return false
	return true
