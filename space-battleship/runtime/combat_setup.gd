extends RefCounted
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

static func positions(session, members: Array) -> Dictionary:
	var sorted := members.duplicate(true)
	sorted.sort_custom(func(a, b):
		if a.definition.size != b.definition.size: return a.definition.size > b.definition.size
		if a.definition.id != b.definition.id: return a.definition.id < b.definition.id
		return a.slot < b.slot)
	var columns: int = session.geometry.columns
	var row_count: int = ceili(float(sorted.size()) / columns)
	var cursor := 0
	var result := {}
	for row in range(row_count):
		var count: int = mini(columns, ceili(float(sorted.size() - cursor) / (row_count - row)))
		var ordered := []
		for column in range(count): ordered.append(column)
		ordered.sort_custom(func(a, b):
			var da: float = absf(a - (count - 1) * 0.5)
			var db: float = absf(b - (count - 1) * 0.5)
			return da < db if da != db else a < b)
		var y: float = session.geometry.single_row_y if row_count == 1 else session.geometry.back_row_y if row == 0 else session.geometry.middle_row_y if row == 1 else session.geometry.front_row_y
		var spacing: float = minf(session.geometry.maximum_spacing, session.geometry.formation_width / maxi(1, count - 1))
		for column in ordered:
			result[sorted[cursor].slot] = Vector2(session.geometry.center_x + (column - (count - 1) * 0.5) * spacing, y)
			cursor += 1
	return result

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
		damage = session.mul(damage, session.calculate("pow", session.amount(1.0 + source_row.dmgMulti), {}, level - 1).value)
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
		var row: Dictionary = session.bundle.lookup("equipment", [slot.equipment_id])
		if row.is_empty(): return {"ok": false, "reason": "UnknownEquipment"}
		if slot.equipment_id in ["armour", "shield"]:
			var capacity: Dictionary = session.amount(row.para1)
			var layer := 1 if slot.equipment_id == "armour" else 0
			if layer == 1: armour = session.add(armour, capacity)
			else: shield = session.add(shield, capacity)
			defences.append({"layer": layer, "type": int(row.dmgtype), "base": capacity, "factor": session.amount(1),
				"maximum": capacity, "loss": session.amount(0), "buffer": session.amount(0), "entry": {"slot": slot.slot},
				"rate": float(row.para2) if layer == 0 else 0.0, "delay": float(row.para3) if layer == 0 else 0.0})
		else:
			var compiled := weapon(session, slot.equipment_id, row, false, slot.slot, player_point)
			if compiled.has("error"): return {"ok": false, "reason": compiled.error}
			weapons.append(compiled)
	var descriptor := {"player": {"armour": armour, "shield": shield, "x": player_point.x, "y": player_point.y},
		"weapons": weapons, "defences": defences, "enemies": [], "rng_state": session.seed,
		"resistance": session.rules.resistance, "drop_rules_compiled": true,
		"jewel_probability": session.rules.jewel_probability, "counter_level": 0,
		"ejection_gap": session.motion.missile_ejection_gap, "launch_speed": session.motion.missile_launch_speed,
		"turn_rate": session.motion.missile_turn_rate, "ignition": session.motion.missile_ignition_at,
		"seek": session.motion.missile_seek_start, "cruise_at": session.motion.missile_cruise_at,
		"lifetime": session.motion.missile_lifetime, "orphan_lifetime": session.motion.missile_orphan_lifetime,
		"brake_range": session.motion.missile_brake_range, "brake_angle": session.motion.missile_brake_angle,
		"min_speed": session.motion.missile_min_guided_speed, "brake_factor": session.motion.missile_brake_factor,
		"hit_radius": session.motion.missile_hit_radius, "chain_speed": session.motion.chain_carrier_speed}
	return {"ok": session.kernel.configure(descriptor), "reason": session.kernel.last_error()}

static func wave(session) -> Dictionary:
	var campaign: Dictionary = session.campaign
	var stage: Dictionary = session.bundle.lookup("level", [campaign.stage])
	var points_list := points(session, stage)
	var group: Dictionary = session.bundle.lookup("monGroup", [points_list[campaign.point].group])
	var members := []
	var slots := list_text(group.mon)
	for i in range(slots.size()):
		if slots[i] == "null": continue
		var definition: Dictionary = session.bundle.lookup("mon", [slots[i].to_int()])
		members.append({"slot": i, "definition": definition})
	var layout := positions(session, members)
	var enemies := []
	var weapons := []
	var ratio: float = 1.0 if points_list.size() <= 1 else float(campaign.point) / (points_list.size() - 1)
	var previous: Dictionary = session.bundle.lookup("level", [campaign.stage - 1])
	var attack_entry: float = float(stage.entryAtkRatio) if stage.get("entryAtkRatio") != null else 1.0 if campaign.stage == 1 else float(previous.atkRatio)
	var life_entry: float = float(stage.entryLifeRatio) if stage.get("entryLifeRatio") != null else 1.0 if campaign.stage == 1 else float(previous.lifeRatio)
	var attack_ratio: float = lerpf(attack_entry, stage.atkRatio, ratio)
	var life_ratio: float = lerpf(life_entry, stage.lifeRatio, ratio)
	var resource_entry: float = 1.0 if campaign.stage == 1 else float(previous.resRatio)
	var resource_ratio: float = lerpf(resource_entry, stage.resRatio, ratio)
	for member in members:
		var mon: Dictionary = member.definition
		var point: Vector2 = layout[member.slot]
		var hp: Dictionary = session.ceil_amount(session.mul(session.amount(mon.health), session.amount(life_ratio)))
		var shield: Dictionary = session.ceil_amount(session.mul(session.amount(mon.shield), session.amount(life_ratio)))
		var enemy := {"uid": int(mon.id), "config_id": str(int(mon.id)), "slot": member.slot,
			"hp": hp, "max_hp": hp, "shield": shield, "max_shield": shield,
			"armourType": int(mon.armourType), "shieldType": int(mon.shieldType), "x": point.x, "y": point.y,
            "shieldRecovery": mon.shieldRecovery, "shieldDelay": mon.shieldDelay, "jewel_rolls": 1 if session.content_unlocked("feature", "jewels") else 0,
			"compiled_drops": []}
		if mon.get("reactiveReduction") != null: enemy.reactiveReduction = int(mon.reactiveReduction)
		if mon.get("res") != null:
			var regex := RegEx.new()
			regex.compile("\\{([^{}]+)\\}")
			for match_value in regex.search_all(str(mon.res).replace("｛", "{").replace("｝", "}")):
				var drop := match_value.get_string(1).split(",")
				var amount: Dictionary = session.ceil_amount(session.mul(session.amount(drop[1]), session.amount(resource_ratio)))
				enemy.compiled_drops.append({"resource": drop[0].to_int(), "chance": drop[2].to_float(), "amount": amount, "base": amount})
		var enemy_index := enemies.size()
		enemies.append(enemy)
		for entry in list_text(mon.equipment):
			var pair := entry.split("|")
			var row: Dictionary = session.bundle.lookup("equipment", [pair[0]])
			var compiled := weapon(session, pair[0], row, true, member.slot, point, pair[1].to_int())
			if compiled.has("error"): return {"error": compiled.error}
			compiled.source = enemy_index
			compiled.damage = session.ceil_amount(session.mul(compiled.damage, session.mul(session.amount(mon.dmgMultiple), session.amount(attack_ratio))))
			weapons.append(compiled)
    return {"enemies": enemies, "weapons": weapons, "final": campaign.point == points_list.size() - 1, "jewel_ratio": stage.jewelRatio}
