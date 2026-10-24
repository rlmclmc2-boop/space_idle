extends RefCounted
const FORMATION = preload("res://scripts/enemy_formation.gd")
## Only assembles immutable input. Hit, defence, cooldown, history and RNG stay native.

static func kind(equipment_id: String) -> int:
	if equipment_id in ["laser", "laser_mon", "laser-mon"]: return 0
	if equipment_id in ["cannon", "cannon-mon"]: return 1
	if equipment_id in ["missile", "missile-mon"]: return 2
	if equipment_id in ["longLaser", "longLaser-mon"]: return 3
	return -1

static func list_text(value: String) -> Array[String]:
	var normalized := value.replace("｛", "{").replace("｝", "}").replace("，", ",")
	var result: Array[String] = []
	for entry in normalized.trim_prefix("{").trim_suffix("}").split(","):
		result.append(entry.strip_edges())
	return result

static func points(session, stage: Dictionary) -> Array:
	var result := []
	for entry in list_text(stage.monGroup):
		var pair := entry.split("|")
		result.append({"group": pair[0].to_int(), "distance": pair[1].to_float() * stage.length})
	return result

static func stage_ratio(session, stage: Dictionary, field: String, entry_field: String = "") -> Dictionary:
	var count: int = points(session, stage).size()
	var u: float = 1.0 if count <= 1 else float(session.campaign.point) / (count - 1)
	var entry: Dictionary
	if not entry_field.is_empty() and stage.get(entry_field) != null:
		entry = session.amount(stage[entry_field])
	elif session.campaign.stage == 1: entry = session.amount(1)
	else: entry = session.amount(session.bundle.lookup("level", [session.campaign.stage - 1])[field])
	return session.add(session.mul(entry, session.amount(1.0 - u)), session.mul(session.amount(stage[field]), session.amount(u)))

static func positions(session, slots: Array, definitions: Dictionary) -> Dictionary:
	return FORMATION.positions(slots, definitions, null, session.geometry)

# Static ordinary values feed the same native history/branch evaluator used at
# attack birth and defence reconciliation. No paid level is left in a UI row.
static func ordinary(session, slot: Dictionary, row: Dictionary) -> Dictionary:
	var level: int = slot.paid_level
	var evolution: Dictionary = session.bundle.lookup("equipment_evolution", ["default"])
	var base: Dictionary
	if slot.category == "defence":
		var armour: Dictionary = session.bundle.lookup("equipment", ["armour"])
		base = session.growth(session.amount(armour.para1), evolution.defence_growth, level)
		if slot.equipment_id == "shield":
			base = session.mul(base, session.calculate("div", session.amount(row.para1), session.amount(armour.para1)).value)
	else:
		base = session.growth(session.amount(row.dmg), row.dmgMulti, level)
	var tier: int = level / int(evolution.interval)
	if tier > 0:
		var later: Dictionary = session.calculate("pow", session.amount(evolution.later_stat_multiplier), {}, float(tier - 1)).value
		base = session.mul(base, session.mul(session.amount(evolution.first_stat_multiplier), later))
	# Neutral research/reactor factors still execute their specified ceilings.
	return session.ceil_amount(base)

static func weapon(session, equipment_id: String, source_row: Dictionary, hostile: bool, slot: int, muzzle: Vector2, level: int = 1) -> Dictionary:
	var weapon_kind := kind(equipment_id)
	if weapon_kind < 0: return {"error": "UnknownWeapon"}
	var canonical: String = ["laser", "cannon", "missile", "longLaser"][weapon_kind]
	var fallback: Dictionary = session.bundle.lookup("enemy_weapon_base", [canonical]) if hostile else {}
	var values := {}
	for field in ["dmg", "cd", "dmgtype", "para1", "para2", "para3"]:
		values[field] = source_row.get(field)
		if values[field] == null: values[field] = fallback.get(field)
	if values.dmg == null or values.cd == null or values.dmgtype == null: return {"error": "MissingWeaponField"}
	var damage: Dictionary = session.amount(values.dmg)
	# Enemy levels use the exact row's growth; empty growth never borrows the player's.
	if level > 1 and source_row.get("dmgMulti") != null:
		damage = session.growth(damage, source_row.dmgMulti, level)
	var pixels: float = session.motion.enemy_projectile_pixels_per_unit if hostile else session.motion.player_projectile_pixels_per_unit
	var speed: float = float(values.para1 if weapon_kind != 2 else values.para2) * pixels
	var row := {"kind": weapon_kind, "type": int(values.dmgtype), "slot": slot, "hostile": hostile,
		"damage": damage, "factor": session.amount(1), "interval": values.cd, "speed": speed,
		"muzzle": muzzle, "entry": {"slot": slot}, "row": source_row}
	if weapon_kind == 2: row.salvo = int(values.para1)
	if weapon_kind == 3:
		row.charge = values.para3
		row.ramp = values.para1
		row.maximum = values.para2
	return row

static func initialize(session) -> Dictionary:
	var player_point := Vector2(session.geometry.center_x, session.geometry.player_y)
	var weapons := []
	var defences := []
	var armour: Dictionary = session.amount(0)
	var shield: Dictionary = session.amount(0)
	for slot in session.equipment.slots:
		if slot.equipment_id.is_empty(): continue
		var row: Dictionary = session.bundle.lookup("equipment", [slot.equipment_id])
		if row.is_empty(): return {"ok": false, "reason": "UnknownEquipment"}
		if slot.equipment_id in ["armour", "shield"]:
			var capacity: Dictionary = ordinary(session, slot, row)
			var layer := 1 if slot.equipment_id == "armour" else 0
			if layer == 1: armour = session.add(armour, capacity)
			else: shield = session.add(shield, capacity)
			defences.append({"layer": layer, "type": int(row.dmgtype), "base": capacity, "factor": session.amount(1),
				"maximum": capacity, "loss": session.amount(0), "buffer": session.amount(0), "entry": {"slot": slot.slot},
				"rate": float(row.para2) if layer == 0 else 0.0, "delay": float(row.para3) if layer == 0 else 0.0})
		else:
			var compiled := weapon(session, slot.equipment_id, row, false, slot.slot, player_point)
			if compiled.has("error"): return {"ok": false, "reason": compiled.error}
			compiled.damage = ordinary(session, slot, row)
			weapons.append(compiled)
	var descriptor := {"player": {"armour": armour, "shield": shield, "x": player_point.x, "y": player_point.y},
		"weapons": weapons, "defences": defences, "enemies": [], "rng_state": session.seed,
		"resistance": session.rules.resistance, "target_slot_center": session.geometry.target_slot_center, "drop_rules_compiled": true,
		"jewel_probability": session.rules.jewel_probability, "counter_level": 0,
		"ejection_gap": session.motion.missile_ejection_gap, "launch_speed": session.motion.missile_launch_speed,
		"turn_rate": session.motion.missile_turn_rate, "ignition": session.motion.missile_ignition_at,
		"seek": session.motion.missile_seek_start, "cruise_at": session.motion.missile_cruise_at,
		"lifetime": session.motion.missile_lifetime, "orphan_lifetime": session.motion.missile_orphan_lifetime,
		"brake_range": session.motion.missile_brake_range, "brake_angle": session.motion.missile_brake_angle,
		"min_speed": session.motion.missile_min_guided_speed, "brake_factor": session.motion.missile_brake_factor,
		"hit_radius": session.motion.missile_hit_radius, "chain_speed": session.motion.chain_carrier_speed}
	descriptor.counter_log_base = session.bundle.lookup("enhance_config", ["counter_log_base"]).value
	descriptor.counter_round_scale = session.bundle.lookup("enhance_config", ["bonus_round_scale"]).value
	return {"ok": session.kernel.configure(descriptor), "reason": session.kernel.last_error()}

static func wave(session) -> Dictionary:
	var campaign: Dictionary = session.campaign
	var stage: Dictionary = session.bundle.lookup("level", [campaign.stage])
	var points_list := points(session, stage)
	var group: Dictionary = session.bundle.lookup("monGroup", [points_list[campaign.point].group])
	var members := []
	var slots := []
	var definitions := {}
	for entry in list_text(group.mon):
		if entry == "null":
			slots.append(null)
			continue
		var definition: Dictionary = session.bundle.lookup("mon", [entry.to_int()])
		definitions[str(entry.to_int())] = definition
		members.append({"slot": slots.size(), "definition": definition})
		slots.append(entry.to_int())
	var layout := positions(session, slots, definitions)
	var enemies := []
	var weapons := []
	var attack_ratio := stage_ratio(session, stage, "atkRatio", "entryAtkRatio")
	var life_ratio := stage_ratio(session, stage, "lifeRatio", "entryLifeRatio")
	var resource_ratio := stage_ratio(session, stage, "resRatio")
	for member in members:
		var mon: Dictionary = member.definition
		var point: Vector2 = layout[member.slot]
		var hp: Dictionary = session.ceil_amount(session.mul(session.amount(mon.health), life_ratio))
		var shield: Dictionary = session.ceil_amount(session.mul(session.amount(mon.shield), life_ratio))
		var enemy := {"uid": int(mon.id), "config_id": str(int(mon.id)), "slot": member.slot,
			"hp": hp, "max_hp": hp, "shield": shield, "max_shield": shield,
			"armourType": int(mon.armourType), "shieldType": int(mon.shieldType), "x": point.x, "y": point.y,
			"shieldRecovery": mon.shieldRecovery, "shieldDelay": mon.shieldDelay, "jewel_rolls": 1 if session.content_unlocked("feature", "jewels") else 0,
			"compiled_drops": []}
		if mon.get("reactiveReduction") != null: enemy.reactiveReduction = int(mon.reactiveReduction)
		for drop in session.bundle.drop_rules(int(mon.id)):
			var amount: Dictionary = session.ceil_amount(session.mul(session.amount(drop.amount), resource_ratio))
			enemy.compiled_drops.append({"resource": str(drop.resource).to_int(), "chance": drop.chance, "amount": amount, "base": amount})
		var enemy_index := enemies.size()
		enemies.append(enemy)
		for entry in list_text(mon.equipment):
			var pair := entry.split("|")
			var row: Dictionary = session.bundle.lookup("equipment", [pair[0]])
			var compiled := weapon(session, pair[0], row, true, member.slot, point, pair[1].to_int())
			if compiled.has("error"): return {"error": compiled.error}
			compiled.source = enemy_index
			compiled.damage = session.ceil_amount(session.mul(compiled.damage, session.mul(session.amount(mon.dmgMultiple), attack_ratio)))
			weapons.append(compiled)
	return {"enemies": enemies, "weapons": weapons, "final": campaign.point == points_list.size() - 1, "jewel_ratio": stage.jewelRatio}
