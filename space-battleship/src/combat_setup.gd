extends RefCounted
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
		"entry": {"key": key, "name": key, "slot": slot},
		"branch_factors": [], "external_factors": []}

static func build_player(equipment_contribution: Dictionary, geometry: Dictionary, rules: Dictionary,
		resistance: float, motion: Dictionary, upgrades: Dictionary, factors: Dictionary, drone_weapons: Array, seed_value: int) -> Dictionary:
	var base_values: Dictionary = equipment_contribution["values"].duplicate()
	for group in ["weapons", "defences"]: base_values[group] = base_values[group].duplicate()
	var weapons: Array = []
	var defences: Array = []
	var player_point := Vector2(float(geometry.player_x), float(geometry.player_y))
	for drone in drone_weapons:
		var external: Array = factors.external.duplicate()
		external.append_array(drone.get("external_factors", []))
		drone.external_factors = external
	var descriptor := {"player": {"x": player_point.x, "y": player_point.y},
		"enemies": [], "weapons": weapons, "defences": defences,
		"requires_drop_rules": true, "drop_rules_compiled": true,
		"resistance": resistance, "rng_state": seed_value,
		"target_slot_center": float(geometry.target_slot_center), "battle_width": float(geometry.view_width), "battle_height": float(geometry.view_height),
		"attack_counter": 0, "incoming_counter": 0, "jewel_probability": 0.0, "jewel_ratio": 1.0}
	descriptor.merge(upgrades.globals, true)
	descriptor.enhancement_state = {"effects": upgrades.effects, "rules": upgrades.rules}
	for source in equipment_contribution.defences:
		var defence: Dictionary = source.duplicate()
		defence.merge(upgrades.defence, true)
		defences.append(defence)
	for group in [equipment_contribution.weapons, drone_weapons]:
		for source in group:
			var mounted: Dictionary = source.duplicate()
			mounted.base_interval = mounted.interval
			mounted.merge(upgrades.weapon, true)
			mounted.interval = float(mounted.base_interval) * float(upgrades.weapon.interval_multiplier)
			if upgrades.initial_wait_from_interval: mounted.remaining = 0.0 if int(mounted.kind) == 3 else mounted.interval
			weapons.append(mounted)
	for key in ["reactive_volley_window", "reactive_stack_seconds", "reactive_per_stack"]:
		descriptor[key] = rules[key]
	descriptor.reactive_stack_limit = int(rules.reactive_stack_limit)
	for key in ["projectile_min_x", "projectile_max_x", "projectile_min_y", "projectile_max_y"]:
		descriptor[key] = geometry[key]
	var motion_keys := {"missile_departure_angle": "missile_departure_angle",
		"missile_launch_edge_margin": "missile_launch_edge_margin", "missile_launch_forward_y": "missile_launch_forward_y",
		"ejection_gap": "missile_ejection_gap", "launch_speed": "missile_launch_speed",
		"turn_rate": "missile_turn_rate", "ignition": "missile_ignition_at", "seek": "missile_seek_start",
		"cruise_at": "missile_cruise_at", "lifetime": "missile_lifetime", "orphan_lifetime": "missile_orphan_lifetime",
		"brake_range": "missile_brake_range", "brake_angle": "missile_brake_angle",
		"min_speed": "missile_min_guided_speed", "brake_factor": "missile_brake_factor",
		"hit_radius": "missile_hit_radius", "chain_speed": "chain_carrier_speed"}
	for key in motion_keys:
		descriptor[key] = motion[motion_keys[key]]
	return {"ok": true, "descriptor": descriptor, "values": base_values}

static func ratio(current: Dictionary, previous_stage: Dictionary, field: String, point: int, points: int, api, endpoint_only: bool = false) -> Dictionary:
	if endpoint_only: return api.apply("from_decimal", [str(current[field])])
	var previous = 1 if int(current.id) == 1 else previous_stage[field]
	var entry_key: String = "entryAtkRatio" if field == "atkRatio" else "entryLifeRatio" if field == "lifeRatio" else ""
	if not entry_key.is_empty() and current.get(entry_key) != null:
		previous = current[entry_key]
	var u: float = 1.0 if points <= 1 else float(point) / (points - 1)
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

static func build_wave(group: Dictionary, stage: Dictionary, previous_stage: Dictionary,
		point_index: int, point_count: int, enemy_definitions: Dictionary, enemy_weapon_definitions: Dictionary,
		weapon_overrides: Callable, geometry: Dictionary, motion: Dictionary,
		jewel_rolls: int, jewel_probability: float, next_uid: int, api, endpoint_only: bool = false) -> Dictionary:
	var slots: Array = JSON.parse_string(str(group.mon).replace("｛", "[").replace("｝", "]").replace("{", "[").replace("}", "]").replace("，", ","))
	var positions: Dictionary = Geometry.formation_positions(slots, enemy_definitions, geometry, group.get("formation_positions"))
	var final: bool = point_index == point_count - 1
	var life = ratio(stage, previous_stage, "lifeRatio", point_index, point_count, api, endpoint_only)
	var attack = ratio(stage, previous_stage, "atkRatio", point_index, point_count, api, endpoint_only)
	var resources = ratio(stage, previous_stage, "resRatio", point_index, point_count, api, endpoint_only)
	for result in [life, attack, resources]:
		if not result.ok:
			return result
	var enemies: Array = []
	var weapons: Array = []
	var muzzles: Dictionary = {}
	var tier: String = str(group.combatTier) if group.combatTier != null else "normal"
	var leader: int = -1
	for candidate in slots.size():
		if slots[candidate] != null and (leader < 0 or int(enemy_definitions[int(slots[candidate])].size) > int(enemy_definitions[int(slots[leader])].size)):
			leader = candidate
	for slot in slots.size():
		if slots[slot] == null:
			continue
		if next_uid == 9223372036854775807:
			return {"ok": false, "reason": "ActorIdRangeExceeded"}
		next_uid += 1
		var row: Dictionary = enemy_definitions[int(slots[slot])]
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
		actor.hull_scale = float(geometry.enemy_ultimate_leader_scale if tier == "ultimate" else geometry.enemy_boss_leader_scale) if actor.encounter_leader else 1.0
		actor.shieldType = 0 if row.shieldType == null else int(row.shieldType)
		actor.shieldDelay = 0.0 if row.shieldDelay == null else float(row.shieldDelay)
		actor.shieldRecovery = 0.0 if row.shieldRecovery == null else float(row.shieldRecovery)
		actor.reactiveReduction = 0 if row.reactiveReduction == null else int(row.reactiveReduction)
		actor.jewel_rolls = int(group.get("jewel_rolls_by_slot", {}).get(slot, jewel_rolls))
		actor.compiled_drops = []
		var drops := RegEx.new()
		drops.compile("[｛{]([^｝}]+)[｝}]")
		for record in drops.search_all(str(row.res)):
			for record_text in record.get_string(1).replace("\uff1b", ";").split(";", false):
				var fields: PackedStringArray = record_text.replace("，", ",").split(",")
				var base = api.apply("from_decimal", [fields[1]])
				if not base.ok:
					return base
				base = api.apply("mul", [base.value, resources.value])
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
			var definition: Dictionary = enemy_weapon_definitions[key].duplicate(true)
			var overrides: Dictionary = weapon_overrides.call(exact_key)
			for field in overrides:
				if overrides[field] != null: definition[field] = overrides[field]
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
				var row_weapon: Dictionary = weapon(definition, key, text.text, mount, true, motion)
				row_weapon.source = source
				row_weapon.muzzle = positions[slot]
				weapons.append(row_weapon)
				muzzles["enemy:" + str(actor.uid) + ":" + str(mount)] = positions[slot]
				mount += 1
	muzzles.make_read_only()
	return {"ok": true, "wave": {"enemies": enemies, "weapons": weapons, "final": final,
		"jewel_ratio": float(stage.jewelRatio), "jewel_probability": jewel_probability}, "next_uid": next_uid, "muzzles": muzzles}

static func legendary_configuration(source: Dictionary) -> Dictionary:
	var legendary_definitions: Dictionary = {}
	var legendary_constants: Dictionary = {}
	var legendary_ranges: Dictionary = {}
	var drone_limits: Dictionary = {}
	for row in source["\u4f20\u8bf4\u5b9a\u4e49"]:
		legendary_definitions[str(row.effect_id)] = row
	for row in source["\u4f20\u8bf4\u968f\u673a\u53c2\u6570"]:
		if not legendary_ranges.has(str(row.effect_id)):
			legendary_ranges[str(row.effect_id)] = {}
		legendary_ranges[str(row.effect_id)][str(row.parameter)] = {"minimum": row.minimum, "maximum": row.maximum}
	var legacy_bounds: Dictionary = {}
	for row in source["\u56fa\u5b9a\u89c4\u5219_\u517c\u5bb9\u8bf4\u660e"]:
		legacy_bounds[str(row.key)] = row.value
	var old_key: String = "/legendary_effects/drone_master/stored_parameter_ranges/maximum_reduction/"
	if legacy_bounds.has(old_key + "0") and legacy_bounds.has(old_key + "1"):
		legendary_ranges.drone_master.maximum_reduction.compatibility_minimum = legacy_bounds[old_key + "0"]
		legendary_ranges.drone_master.maximum_reduction.compatibility_maximum = legacy_bounds[old_key + "1"]
	for row in source["\u4f20\u8bf4\u5e38\u91cf"]:
		if not legendary_constants.has(str(row.effect_id)):
			legendary_constants[str(row.effect_id)] = {}
		legendary_constants[str(row.effect_id)][str(row.constant_path)] = row.value
	for row in source["\u57fa\u7840\u53c2\u6570"]:
		drone_limits[str(row.key)] = row.value
	return {"legendary_definitions": legendary_definitions, "legendary_constants": legendary_constants,
		"legendary_ranges": legendary_ranges, "drone_limits": drone_limits}
