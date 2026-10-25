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

static func values(slots: Array, extra_levels: int, definitions: Dictionary, evolution: Dictionary, api,
		ai: Dictionary, reactor: Dictionary, weapons: bool, defences: bool) -> Dictionary:
	var result: Dictionary = {"ok": true, "weapons": {}, "defences": {}}
	for slot in slots:
		if str(slot.equipment_id).is_empty() or (slot.category == "weapon" and not weapons) or (slot.category == "defence" and not defences): continue
		var row: Dictionary = definitions[str(slot.equipment_id)]
		var value = Equipment.charged_base(row, definitions.armour, slot, extra_levels, evolution,
			ai.equipment_durability if slot.category == "defence" else ai.weapon_damage,
			reactor.defence if slot.category == "defence" else reactor.weapons, api)
		if not value.ok: return value
		var text = api.apply("to_display", [value.value])
		if not text.ok: return text
		result["defences" if slot.category == "defence" else "weapons"][str(slot.id)] = {"key": str(row.name), "generation": int(slot.generation), "base": text.text, "paid_level": int(slot.paid_level), "effective_level": int(slot.paid_level) + int(slot.extra_levels) + extra_levels}
	return result

static func build_player(slots: Array, extra_levels: int, equipment_definitions: Dictionary, evolution: Dictionary,
		api, player_art: Dictionary, player_dimensions: Vector2, geometry: Dictionary, rules: Dictionary,
		resistance: float, motion: Dictionary, enhancement: Dictionary, effects: Dictionary, factors: Dictionary, drone_weapons: Array, seed_value: int) -> Dictionary:
	var base_values = values(slots, extra_levels, equipment_definitions, evolution, api,
		{"weapon_damage": factors.ai_weapon, "equipment_durability": factors.ai_defence},
		{"weapons": factors.reactor_weapon, "defence": factors.reactor_defence}, true, true)
	if not base_values.ok: return base_values
	var player_point := Vector2(float(geometry.player_x), float(geometry.player_y))
	var weapons: Array = []
	var defences: Array = []
	for slot in slots:
		if str(slot.equipment_id).is_empty():
			continue
		var row: Dictionary = equipment_definitions[str(slot.equipment_id)]
		var text: Dictionary = {"text": base_values["defences" if slot.category == "defence" else "weapons"][str(slot.id)].base}
		if row.name in ["armour", "shield"]:
			defences.append({"entry": {"id": str(slot.id), "key": str(row.name), "generation": int(slot.generation)},
				"layer": 0 if row.name == "shield" else 1, "type": int(row.dmgtype),
				"base": text.text, "maximum": text.text, "factor": 1.0, "loss": "0", "buffer": "0",
				"delay": float(row.para3) if row.name == "shield" else 0.0,
				"rate": float(row.para2) if row.name == "shield" else 0.0,
				"branch_factors": [], "external_factors": factors.external.duplicate()})
		else:
			var row_weapon: Dictionary = weapon(row, str(row.name), str(text.text), int(slot.index), false, motion)
			row_weapon.muzzle = Geometry.mount_position(player_art, int(slot.index), player_point, player_dimensions)
			row_weapon.external_factors = factors.external.duplicate()
			row_weapon.entry.id = str(slot.id)
			row_weapon.entry.generation = int(slot.generation)
			row_weapon.entry.paid_level = int(slot.paid_level)
			row_weapon.entry.effective_level = int(slot.paid_level) + int(slot.extra_levels) + extra_levels
			weapons.append(row_weapon)
	for drone in drone_weapons:
		var external: Array = factors.external.duplicate()
		external.append_array(drone.get("external_factors", []))
		drone.external_factors = external
	weapons.append_array(drone_weapons)
	var descriptor := {"player": {"x": player_point.x, "y": player_point.y},
		"enemies": [], "weapons": weapons, "defences": defences,
		"requires_drop_rules": true, "drop_rules_compiled": true,
		"resistance": resistance, "rng_state": seed_value,
		"target_slot_center": float(geometry.target_slot_center), "battle_width": float(geometry.view_width), "battle_height": float(geometry.view_height),
		"attack_counter": 0, "incoming_counter": 0, "counter_level": int(effects.level),
		"counter_growth": float(enhancement.proficiency_growth) if effects.effects.proficiency.active else 0.0,
		"defence_counter_growth": float(enhancement.adaptation_growth) if effects.effects.adaptation.active else 0.0,
		"counter_log_base": float(enhancement.counter_log_base),
		"counter_round_scale": float(enhancement.bonus_round_scale),
		"jewel_probability": 0.0, "jewel_ratio": 1.0}
	descriptor.enhancement_state = effects
	descriptor.repeat_delay = float(enhancement.repeat_delay)
	descriptor.memory_interval = float(enhancement.memory_interval)
	descriptor.deferred_interval = float(enhancement.deferred_interval)
	descriptor.deferred_duration = float(enhancement.deferred_duration)
	var enabled: Dictionary = effects.effects
	var level: int = int(effects.level)
	descriptor.clear_probability = clampf(float(enhancement.deferred_clear_probability) + int(enabled.deferred.a) * float(enhancement.deferred_a_clear_probability), 0.0, 1.0) if enabled.deferred.active else 0.0
	var shields: int = 0
	var armours: int = 0
	for defence in defences:
		if int(defence.layer) == 0: shields += 1
		else: armours += 1
	for defence in defences:
		defence.branch_factors = [1.0 + int(enabled.adaptation.a) * float(enhancement.adaptation_a_capacity_bonus)]
		if enabled.memory.active:
			var memory_factor: float = 1.0 + int(enabled.memory.a) * float(enhancement.memory_a_bonus)
			defence.memory_heal = float(enhancement.memory_heal_fraction) * level * memory_factor
			defence.memory_cap = float(enhancement.memory_buffer_fraction) * level * memory_factor
			if enabled.memory.b3:
				defence.memory_cap *= 1.0 + armours * float(enhancement.memory_b3_armour_capacity_bonus)
		if enabled.deferred.active:
			var scale: float = float(enhancement.deferred_percent_scale)
			defence.deferred_fraction = maxf(0.0, (scale - maxf(1.0, ceilf(scale / (1.0 + float(enhancement.deferred_curve_coefficient) * level)))) / scale)
	for mounted in weapons:
		mounted.branch_factors = [1.0 + int(enabled.proficiency.a) * float(enhancement.proficiency_a_damage_bonus)]
		if enabled.proficiency.b2:
			mounted.interval *= float(enhancement.proficiency_b2_interval_multiplier)
			mounted.remaining = 0.0 if int(mounted.kind) == 3 else mounted.interval
		mounted.proficiency_pierce = enabled.proficiency.b3
		mounted.pierce_resistance = float(enhancement.proficiency_b3_resistance)
		mounted.repeat_probability = clampf(float(enhancement.repeat_probability) + int(enabled.repeat.a) * float(enhancement.repeat_a_probability), 0.0, 1.0) if enabled.repeat.active else 0.0
		mounted.repeat_multiplier = 1.0 + float(enhancement.repeat_growth) * level
		mounted.chain_count = int(enhancement.repeat_b1_targets) if enabled.repeat.b1 else 0
		mounted.secondary_probability = float(enhancement.repeat_b3_probability) if enabled.repeat.b3 else 0.0
		mounted.critical_rate = (float(enhancement.base_critical_rate) if enabled.critical.active else 0.0) + int(enabled.critical.a) * float(enhancement.critical_a_probability)
		mounted.critical_multiplier = float(enhancement.base_critical_multiplier) + (float(enhancement.critical_growth) * level if enabled.critical.active else 0.0)
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

static func ratio(current: Dictionary, previous_stage: Dictionary, field: String, point: int, points: int, api) -> Dictionary:
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
		equipment_definitions: Dictionary, geometry: Dictionary, motion: Dictionary,
		jewel_rolls: int, jewel_probability: float, next_uid: int, api) -> Dictionary:
	var slots: Array = JSON.parse_string(str(group.mon).replace("｛", "[").replace("｝", "]").replace("{", "[").replace("}", "]").replace("，", ","))
	var positions: Dictionary = Geometry.formation_positions(slots, enemy_definitions, geometry, group.get("formation_positions"))
	var final: bool = point_index == point_count - 1
	var life = ratio(stage, previous_stage, "lifeRatio", point_index, point_count, api)
	var attack = ratio(stage, previous_stage, "atkRatio", point_index, point_count, api)
	var resources = ratio(stage, previous_stage, "resRatio", point_index, point_count, api)
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
		actor.jewel_rolls = jewel_rolls
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
			if equipment_definitions.has(exact_key):
				for field in equipment_definitions[exact_key]:
					if equipment_definitions[exact_key][field] != null:
						definition[field] = equipment_definitions[exact_key][field]
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
	return {"ok": true, "wave": {"enemies": enemies, "weapons": weapons, "final": final,
		"jewel_ratio": float(stage.jewelRatio), "jewel_probability": jewel_probability}, "next_uid": next_uid, "muzzles": muzzles}
