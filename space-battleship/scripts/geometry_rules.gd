extends RefCounted
## Shared geometry rules for the numerical authority and presentation adapters.
## The caller supplies its own data/pose context; this module owns no scene or state.

static func battle_logical_point(host, point: Vector2) -> Vector2:
	# In these affine regions all original comparisons take the same branch.
	# Preserve the finite-bisection midpoint bias, rather than replacing it
	# with the mathematical inverse and moving missile collision coordinates.
	if point.y>=-512.0 and point.y<=220.0:
		return Vector2(point.x,point.y-host.BATTLE_LINEAR_INVERSE_OFFSET)
	if point.y>=640.0 and point.y<=2048.0:
		return Vector2(point.x,point.y-220.0+host.BATTLE_LINEAR_INVERSE_OFFSET)
	if host.game.combat_presentation!=null:return host.game.combat_presentation.battle_logical_point(point)
	var low = point.y-220.0
	var high = point.y
	for iteration in host.BATTLE_INVERSE_STEPS:
		var middle = (low+high)*0.5
		if host.battle_point(Vector2(0,middle)).y<point.y:low=middle
		else:high=middle
	return Vector2(point.x,(low+high)*0.5)

static func battle_point(host, point: Vector2) -> Vector2:
	# Presentation only: open the engagement corridor without stretching hulls or FX.
	return Vector2(point.x,point.y+smoothstep(220.0,420.0,point.y)*220.0)

static func compose_weapon_components(host, ship_key: String, entries: Array, faction: String) -> Array:
	var components: Array = []
	var ship = host.ship_visual_entry(ship_key)
	var points: Array = ship.get("hardpoints",[])
	for point_index in points.size():
		var point: Dictionary = points[point_index]
		var bound: Array[int] = []
		var owner = -1
		for index in entries.size():
			if host.slot_hardpoint_index(ship_key,index)!=point_index:continue
			bound.append(index)
			var profile = host.weapon_visual_profile(str(entries[index].get("key","")))
			if profile.is_empty() or not point.get("allowed_weapon_visual_class",[]).has(profile.get("visual_class","")):continue
			if owner<0 or (str(host.weapon_visual_profile(str(entries[owner].get("key",""))).get("visual_class",""))=="missile" and str(profile.get("visual_class",""))!="missile"):
				owner=index
		if owner>=0:
			var component=host.WEAPON_VISUAL.new(point,host.weapon_visual_profile(str(entries[owner].key)),bound,owner,faction)
			if faction=="enemy":component.damage_type=int(host.db.enemy_weapon(str(entries[owner].key)).get("dmgtype",0))
			components.append(component)
	return components

static func enemy_component_for_slot(host, enemy: Dictionary, index: int):
	for component in host.enemy_weapon_components(enemy):
		if component.slots.has(index):return component
	return null

static func enemy_config_visual_scale(host, size: int) -> float:
	return float(host.db.config.get("enemyVisualScaleSize"+str(clampi(size,1,6)),1.0))

static func enemy_drop_anchor(host, enemy: Dictionary) -> Vector2:
	var position=host.enemy_render_position(enemy)
	return position+Vector2(0,host.enemy_render_width_at_y(enemy,position.y)+12.0)

static func enemy_formation_anchor(host, slot: int, large: bool, size: int, columns := 10) -> Vector2:
	var scale_offset = maxf(0.0,host.enemy_config_visual_scale(size)-1.0)*35.0
	if columns==5:return BattleGame.enemy_slot_position(slot,columns)+Vector2(0,scale_offset)
	return Vector2(BattleGame.enemy_slot_position(slot).x,(130.0 if large else 120.0)+scale_offset)

static func enemy_port_offset(host, enemy: Dictionary, index: int,render_position:=Vector2.INF) -> Vector2:
	var component=host.enemy_component_for_slot(enemy,index)
	if component!=null:return host.enemy_component_pose(enemy,component,render_position).muzzle
	# Unknown external configurations keep the previous logical mount fallback.
	var point=host.hardpoint_for_slot(host.enemy_ship_key(enemy),index)
	if point.is_empty():return Vector2.ZERO
	var position:Vector2=host.enemy_render_position(enemy) if render_position==Vector2.INF else render_position
	var width=host.enemy_render_width_at_y(enemy,position.y)
	var angle=float(host.enemy_pose(enemy).rotation)
	var origin=Vector2(float(point.pos[0])*width,float(point.pos[1])*width*2.0).rotated(PI+angle)
	var class_scale=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
	return origin+Vector2(width*0.42*class_scale*0.22,0).rotated(PI/2+angle)

static func enemy_shot_mount(host, enemy: Dictionary, shot: Dictionary) -> int:
	if is_same(enemy,shot.get("source",{})) and shot.has("mount"):return int(shot.mount)
	var origin = host.game.projectile_position(shot)
	var best = 0
	var distance = INF
	for index in enemy.equipment.size():
		var logical = Vector2(enemy.x,enemy.y)+host.game.enemy_weapon_offset(enemy,index)
		var candidate = logical.distance_squared_to(origin)
		if candidate<distance:
			distance = candidate
			best = index
	return best

static func enemy_weapon_angle(host, enemy: Dictionary, index: int,render_position:=Vector2.INF) -> float:
	var component = host.enemy_component_for_slot(enemy,index)
	if component==null:return 0.0
	var role: String = component.mode()
	if role!="main" and role!="secondary":return 0.0
	var pose_angle = host.enemy_render_angle(enemy)
	var position:Vector2=host.enemy_render_position(enemy) if render_position==Vector2.INF else render_position
	var desired = wrapf((host.player_render_position()-position).angle()-PI/2-pose_angle,-PI,PI)
	var limit = deg_to_rad(float(component.hardpoint.get("rotation_limit",0)))
	return clampf(desired,-limit,limit)*(1.0 if role=="main" else 0.2)

static func entity_render_position(host, entity: Dictionary) -> Vector2:
	if is_same(entity,host.game.player):return host.player_render_position()
	if entity.has("slot"):return host.enemy_render_position(entity)
	return host.battle_point(Vector2(entity.x,entity.y))

static func hardpoint_for_slot(host, ship_key: String, index: int) -> Dictionary:
	var point = host.slot_hardpoint_index(ship_key,index)
	return host.ship_visual_entry(ship_key).get("hardpoints",[])[point] if point>=0 else {}

static func player_art_scale(host) -> float:
	return host.player_art_scale_for(str(host.game.equipment.selected_ship()))

static func player_art_scale_for(host, ship_key: String) -> float:
	return host.player_base_art_scale_for(ship_key)*float(host.db.config.get("playerVisualScale"+ship_key,1.0))

static func player_base_art_scale(host) -> float:
	return host.player_base_art_scale_for(str(host.game.equipment.selected_ship()))

static func player_base_art_scale_for(host, ship_key: String) -> float:
	var entry = host.ship_visual_entry(ship_key)
	return float(entry.get("display_scale",minf(host.SHIP_VISUALS.scale_for(host.db.ship(ship_key)),0.18)))*host.SHIP_VISUALS.player_display_multiplier()

static func player_component_for_slot(host, index: int):
	for component in host.player_weapon_components():
		if component.slots.has(index):return component
	return null

static func player_weapon_components(host) -> Array:
	if host.battle_draw_active:return host.player_components
	var ship_key = str(host.game.equipment.selected_ship())
	var entries = host.game.weapon_entries()
	var signature = ship_key
	for entry in entries:signature += "|"+str(entry.get("key",""))
	if signature==host.player_components_signature:return host.player_components
	host.player_components_signature=signature
	host.player_components=host.compose_weapon_components(ship_key,entries,"ally")
	return host.player_components

static func ship_visual_entry(host, ship_key: String) -> Dictionary:
	return host.visual_config.get("ships",{}).get(ship_key,{})

static func slot_hardpoint_index(host, ship_key: String, index: int) -> int:
	var ship = host.ship_visual_entry(ship_key)
	var mapping: Array = ship.get("slot_map",[])
	var points: Array = ship.get("hardpoints",[])
	if points.is_empty():return -1
	return clampi(int(mapping[index]) if index<mapping.size() else posmod(index,points.size()),0,points.size()-1)

static func turret_angle(host, index: int) -> float:
	if host.turret_ship!=str(host.game.equipment.selected_ship()) or not host.turret_visuals.has(index):return 0.0
	var pose: Dictionary = host.turret_visuals[index]
	return float(pose.angle) if host.game.same_module(pose.entry,host.game.slot_entry("weapons",index)) and pose.key==str(pose.entry.key) else 0.0

static func weapon_key(host, shot: Dictionary) -> String:
	return host.weapon_visual_key(str(shot.get("chain_weapon",shot.key) if shot.get("chain_hop",false) else shot.key))

static func weapon_visual_angle(host, index: int) -> float:
	var role = host.weapon_visual_role(index)
	var limit = deg_to_rad(float(host.hardpoint_for_slot(str(host.game.equipment.selected_ship()),index).get("rotation_limit",0)))
	return clampf(host.turret_angle(index),-limit,limit)*(1.0 if role=="main" else 0.2 if role=="secondary" else 0.0)

static func weapon_visual_key(host, key:String)->String:
	return str(host.ENEMY_VISUAL_ALIASES.get(key,key.replace("-mon", "").replace("_mon", "")))

static func weapon_visual_profile(host, key: String) -> Dictionary:
	return host.visual_config.get("weapons",{}).get(host.weapon_visual_key(key),{})

static func weapon_visual_role(host, index: int) -> String:
	var component = host.player_component_for_slot(index)
	return component.mode() if component!=null else "embedded"
