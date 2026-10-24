extends RefCounted
const Equipment = preload("res://src/systems/equipment.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
const KINDS := {"laser": 0, "cannon": 1, "missile": 2, "longLaser": 3}

static func weapon(row: Dictionary, key: String, damage: String, slot: int, hostile: bool, motion: Dictionary) -> Dictionary:
	var kind: int = KINDS[key]
	var pixels: float = float(motion.enemy_projectile_pixels_per_unit if hostile else motion.player_projectile_pixels_per_unit)
	var speed: float = float(row.para2 if kind == 2 else row.para1) * pixels
	if kind == 1 and not hostile:
		speed *= float(motion.player_cannon_speed_multiplier)
	return {"kind": kind, "type": int(row.dmgtype), "slot": slot, "hostile": hostile,
		"damage": damage, "factor": 1.0, "interval": float(row.cd), "speed": speed,
		"remaining": 0.0 if kind == 3 else float(row.cd),
		"salvo": int(row.para1) if kind == 2 else 1,
		"charge": float(row.para3) if kind == 3 else 0.0,
		"ramp": float(row.para1) if kind == 3 else 1.0,
		"maximum": float(row.para2) if kind == 3 else 1.0,
		"entry": {"key": key, "name": key, "slot": slot}, "row": row.duplicate(true),
		"branch_factors": [], "external_factors": []}

static func build_player(session) -> Dictionary:
	var api = session.amount_api
	var one = api.apply("from_decimal", ["1"])
	if not one.ok:
		return one
	var player_point := Vector2(float(session.geometry.player_x), float(session.geometry.player_y))
	var weapons: Array = []
	var defences: Array = []
	for slot in session.slots:
		if str(slot.equipment_id).is_empty():
			continue
		var row: Dictionary = session.equipment_definitions[str(slot.equipment_id)]
		var value = Equipment.charged_base(row, session.equipment_definitions.armour,
			int(slot.paid_level), int(slot.extra_levels), session.evolution, one.value, one.value, api)
		if not value.ok:
			return value
		var text = api.apply("to_display", [value.value])
		if not text.ok:
			return text
		if row.name in ["armour", "shield"]:
			defences.append({"entry": {"id": str(slot.id), "key": str(row.name)},
				"layer": 0 if row.name == "shield" else 1, "type": int(row.dmgtype),
				"base": text.text, "maximum": text.text, "factor": 1.0, "loss": "0", "buffer": "0",
				"delay": float(row.para3) if row.name == "shield" else 0.0,
				"rate": float(row.para2) if row.name == "shield" else 0.0,
				"branch_factors": [], "external_factors": []})
		else:
			var row_weapon: Dictionary = weapon(row, str(row.name), str(text.text), int(slot.index), false, session.motion)
			row_weapon.muzzle = Geometry.mount_position(session.player_art, int(slot.index), player_point, session.player_dimensions)
			weapons.append(row_weapon)
	var descriptor := {"player": {"armour": "0", "shield": "0", "x": player_point.x, "y": player_point.y},
		"enemies": [], "weapons": weapons, "defences": defences,
		"requires_module_defense": true, "requires_drop_rules": true, "drop_rules_compiled": true,
		"resistance": float(session.parameters.dmgReduce), "rng_state": session.seed_value,
		"target_slot_center": float(session.geometry.target_slot_center), "battle_width": float(session.geometry.view_width),
		"attack_counter": 0, "incoming_counter": 0, "counter_level": 0,
		"counter_growth": float(session.enhancement.proficiency_growth),
		"defence_counter_growth": float(session.enhancement.adaptation_growth),
		"counter_log_base": float(session.enhancement.counter_log_base),
		"counter_round_scale": float(session.enhancement.bonus_round_scale),
		"jewel_probability": 0.0, "jewel_ratio": 1.0}
	var motion_keys := {"missile_departure_angle": "missile_departure_angle",
		"missile_launch_edge_margin": "missile_launch_edge_margin", "missile_launch_forward_y": "missile_launch_forward_y",
		"ejection_gap": "missile_ejection_gap", "launch_speed": "missile_launch_speed",
		"turn_rate": "missile_turn_rate", "ignition": "missile_ignition_at", "seek": "missile_seek_start",
		"cruise_at": "missile_cruise_at", "lifetime": "missile_lifetime", "orphan_lifetime": "missile_orphan_lifetime",
		"brake_range": "missile_brake_range", "brake_angle": "missile_brake_angle",
		"min_speed": "missile_min_guided_speed", "brake_factor": "missile_brake_factor",
		"hit_radius": "missile_hit_radius", "chain_speed": "chain_carrier_speed"}
	for key in motion_keys:
		descriptor[key] = session.motion[motion_keys[key]]
	return {"ok": true, "descriptor": descriptor}

static func ratio(session, field: String, point: int, points: int) -> Dictionary:
	var current: Dictionary = session.level_definitions[int(session.campaign.stage)]
	var previous = 1 if int(current.id) == 1 else session.level_definitions[int(current.id) - 1][field]
	var entry_key: String = "entryAtkRatio" if field == "atkRatio" else "entryLifeRatio" if field == "lifeRatio" else ""
	if not entry_key.is_empty() and current.get(entry_key) != null:
		previous = current[entry_key]
	var u: float = 1.0 if points <= 1 else float(point) / (points - 1)
	var api = session.amount_api
	var start = api.apply("from_decimal", [str(previous)])
	var finish = api.apply("from_decimal", [str(current[field])])
	var before = api.apply("from_decimal", [str(1.0 - u)])
	var after = api.apply("from_decimal", [str(u)])
	for result in [start, finish, before, after]:
		if not result.ok:
			return result
	start = api.apply("mul", [start.value, before.value])
	finish = api.apply("mul", [finish.value, after.value])
	if not start.ok or not finish.ok:
		return start if not start.ok else finish
	return api.apply("add", [start.value, finish.value])

static func build_wave(session, point_index: int) -> Dictionary:
	var points: Array = session.campaign.points
	var stage: Dictionary = session.level_definitions[int(session.campaign.stage)]
	var group: Dictionary = session.group_definitions[int(points[point_index].id)]
	var slots: Array = JSON.parse_string(str(group.mon).replace("｛", "[").replace("｝", "]").replace("{", "[").replace("}", "]").replace("，", ","))
	var positions: Dictionary = Geometry.formation_positions(slots, session.enemy_definitions, session.geometry, group.get("formation_positions"))
	var final: bool = point_index == points.size() - 1
	var life = ratio(session, "lifeRatio", point_index, points.size())
	var attack = ratio(session, "atkRatio", point_index, points.size())
	var resources = ratio(session, "resRatio", point_index, points.size())
	for result in [life, attack, resources]:
		if not result.ok:
			return result
	var api = session.amount_api
	var enemies: Array = []
	var weapons: Array = []
	var next_uid: int = session.next_enemy_uid
	var tier: String = str(group.combatTier) if group.combatTier != null else "normal"
	var leader: int = -1
	for candidate in slots.size():
		if slots[candidate] != null and (leader < 0 or int(session.enemy_definitions[int(slots[candidate])].size) > int(session.enemy_definitions[int(slots[leader])].size)):
			leader = candidate
	for slot in slots.size():
		if slots[slot] == null:
			continue
		if next_uid == 9223372036854775807:
			return {"ok": false, "reason": "ActorIdRangeExceeded"}
		next_uid += 1
		var row: Dictionary = session.enemy_definitions[int(slots[slot])]
		var hp = api.apply("from_decimal", [str(row.health)])
		var shield = api.apply("from_decimal", [str(0 if row.shield == null else row.shield)])
		for result in [hp, shield]:
			if not result.ok:
				return result
		hp = api.apply("mul", [hp.value, life.value])
		shield = api.apply("mul", [shield.value, life.value])
		for result in [hp, shield]:
			if not result.ok:
				return result
		hp = api.apply("ceil", [hp.value])
		shield = api.apply("ceil", [shield.value])
		if not hp.ok or not shield.ok:
			return hp if not hp.ok else shield
		var actor := row.duplicate(true)
		actor.uid = next_uid
		actor.slot = slot
		actor.x = positions[slot].x
		actor.y = positions[slot].y
		actor.hp = api.apply("to_display", [hp.value]).text
		actor.max_hp = actor.hp
		actor.shield = api.apply("to_display", [shield.value]).text
		actor.max_shield = actor.shield
		actor.dead = false
		actor.wave_final = final
		actor.formation_count = positions.size()
		actor.combat_tier = tier
		actor.encounter_leader = slot == leader and tier in ["boss", "ultimate"]
		actor.hull_scale = float(session.geometry.enemy_ultimate_leader_scale if tier == "ultimate" else session.geometry.enemy_boss_leader_scale) if actor.encounter_leader else 1.0
		actor.shieldType = 0 if row.shieldType == null else int(row.shieldType)
		actor.shieldDelay = 0.0 if row.shieldDelay == null else float(row.shieldDelay)
		actor.shieldRecovery = 0.0 if row.shieldRecovery == null else float(row.shieldRecovery)
		actor.reactiveReduction = 0 if row.reactiveReduction == null else int(row.reactiveReduction)
		actor.jewel_rolls = int(session.rules.jewel_drop_rolls) if session.unlocked("feature", "jewels") else 0
		actor.compiled_drops = []
		var drops := RegEx.new()
		drops.compile("[｛{]([^｝}]+)[｝}]")
		for record in drops.search_all(str(row.res)):
			var fields: PackedStringArray = record.get_string(1).replace("，", ",").split(",")
			var base = api.apply("from_decimal", [fields[1]])
			if not base.ok:
				return base
			base = api.apply("mul", [base.value, resources.value])
			if not base.ok:
				return base
			base = api.apply("ceil", [base.value])
			if not base.ok:
				return base
			var text = api.apply("to_display", [base.value])
			actor.compiled_drops.append({"resource": int(fields[0]), "chance": float(fields[2]), "amount": text.text, "base": text.text})
		var source: int = enemies.size()
		enemies.append(actor)
		var installations: PackedStringArray = str(row.equipment).replace("｛", "").replace("｝", "").replace("{", "").replace("}", "").replace("，", ",").split(",")
		var mount: int = 0
		for installation in installations:
			var parts: PackedStringArray = installation.split("|")
			var exact_key: String = parts[0]
			var key: String = exact_key.replace("_mon", "").replace("-mon", "")
			var definition: Dictionary = session.enemy_weapon_definitions[key].duplicate(true)
			if session.equipment_definitions.has(exact_key):
				for field in session.equipment_definitions[exact_key]:
					if session.equipment_definitions[exact_key][field] != null:
						definition[field] = session.equipment_definitions[exact_key][field]
			var damage = api.apply("from_decimal", [str(definition.dmg)])
			var multiple = api.apply("from_decimal", [str(row.dmgMultiple)])
			if not damage.ok or not multiple.ok:
				return damage if not damage.ok else multiple
			damage = api.apply("mul", [damage.value, multiple.value])
			if not damage.ok:
				return damage
			damage = api.apply("mul", [damage.value, attack.value])
			if not damage.ok:
				return damage
			damage = api.apply("ceil", [damage.value])
			if not damage.ok:
				return damage
			var text = api.apply("to_display", [damage.value])
			for _number in int(parts[1]):
				var row_weapon: Dictionary = weapon(definition, key, text.text, mount, true, session.motion)
				row_weapon.source = source
				row_weapon.muzzle = positions[slot]
				weapons.append(row_weapon)
				mount += 1
	return {"ok": true, "wave": {"enemies": enemies, "weapons": weapons, "final": final,
		"jewel_ratio": float(stage.jewelRatio), "jewel_probability": float(session.parameters.jewelDrop)}, "next_uid": next_uid}
