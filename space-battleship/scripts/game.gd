class_name BattleGame
extends RefCounted

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon"]
const SAVE_PATH := "user://progress.json"
const FURNACE := "超时空炼铁炉"
const ENERGY_FOCUS := "正电子聚焦装置"
const DENSE_ARMOUR := "简并态装甲"
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const HIGHTECH_SLOTS_PER_PAGE := 3
const HIGHTECH_MIN_SLOTS := 6
const WEAPON_KEYS := ["laser", "missile", "cannon"]
const DEFENSE_KEYS := ["armour", "shield"]
var db: ShipDatabase
var profile: Dictionary
var state: State = State.MAIN_MENU
var stage := 1
var distance := 0.0
var group_index := 0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var player: Dictionary = {}
var cooldowns: Dictionary = {}
var since_hit := 100.0
var paused := false
var speed := 1.0
var clear_timer := 0.0
var guard_index := -1
var guard_elapsed := 0.0
var guard_engaged := false
var guard_arrived := false
var first_clear := false
var run_resources := {"1": 0.0, "2": 0.0}
var uid := 0
var save_enabled := true
var pending_unlocks: Array[String] = []
var retreat_from := 0.0
var retreat_target := 0.0
var retreat_elapsed := 0.0
var retreat_boss_pending := false
var rng := RandomNumberGenerator.new()
var hightech_save_elapsed := 0.0
var resource_samples: Array[Dictionary] = []
var offline_rewards: Dictionary = {}
var auto_gen_elapsed := 0.0
var charge_resources_dirty := false

func _init(database: ShipDatabase, persist := true) -> void:
	db = database
	save_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	profile.hightechOrder = hightech_slots()
	if persist:
		load_progress()
		advance_charge(minf(float(db.config.get("offlineMax", 0)) * 3600.0, maxf(0, Time.get_unix_time_from_system() - float(profile.hightechSavedAt))))
		advance_hightech(minf(float(db.config.get("offlineMax", 0)) * 3600.0, maxf(0, Time.get_unix_time_from_system() - float(profile.hightechSavedAt))))
		save_progress()
		charge_resources_dirty = false
	reset_player()

func fresh_profile() -> Dictionary:
	var selected := first_ship()
	var profile := {"version":1, "highestLevel":1, "cleared":[], "bossSeen":[], "resources":{"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))}, "unlocked":str(db.config.startEquip).split(","), "loop":false, "selectedShip":selected, "loadout":{}, "hightechLevels":{}, "hightechVersion":2, "scientists":0, "scientistAssignments":{}, "techPoints":{}, "hightechSavedAt":Time.get_unix_time_from_system(), "furnaceElapsed":0.0, "furnaceIncomePeak":0.0}
	profile.loadout = default_loadout(selected, profile.unlocked)
	profile.charge = {}
	for key in db.data.get("charge", {}):
		profile.charge[key] = {"level":0,"count":0.0,"elapsed":0.0,"active":false,"credit":0.0,"started":0}
	return profile

func first_ship() -> String:
	return str(db.ships.keys()[0]) if not db.ships.is_empty() else "Frigate"

func ship_unlocked(key: String) -> bool:
	var row := db.ship(key)
	var gate := int(row.get("unlock", 0))
	return not row.is_empty() and (gate == 0 or profile.cleared.has(gate))

func default_loadout(key: String, unlocked: Array) -> Dictionary:
	var loadout := empty_loadout(key)
	var weapons: Array = loadout.weapons
	var defence: Array = loadout.defence
	for equip_key in unlocked:
		if WEAPON_KEYS.has(str(equip_key)):
			var empty := weapons.find_custom(func(entry):return str(entry.key).is_empty())
			if empty >= 0:
				weapons[empty].key = str(equip_key)
		elif DEFENSE_KEYS.has(str(equip_key)):
			var empty_defence := defence.find_custom(func(entry):return str(entry.key).is_empty())
			if empty_defence >= 0:
				defence[empty_defence].key = str(equip_key)
	return loadout

func empty_loadout(key: String) -> Dictionary:
	var row := db.ship(key)
	var weapons: Array = []
	var defence: Array = []
	for i in range(int(row.get("weaponSlots", 0))):
		weapons.append({"key":"", "level":1})
	for i in range(int(row.get("defenseSlots", 0))):
		defence.append({"key":"", "level":1})
	return {"weapons":weapons, "defence":defence}

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not raw is Dictionary or raw.get("version") != 1:
		return
	if raw.get("cleared") is Array:
		for n in raw.cleared:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.cleared.has(int(n)):
				profile.cleared.append(int(n))
	profile.bossSeen = profile.cleared.duplicate()
	if raw.get("bossSeen") is Array:
		for n in raw.bossSeen:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.bossSeen.has(int(n)):
				profile.bossSeen.append(int(n))
	for id in ["1", "2"]:
		var value = raw.get("resources", {}).get(id, 0) if raw.get("resources") is Dictionary else 0
		if (value is float or value is int) and is_finite(float(value)):
			profile.resources[id] = ceilf(maxf(0, float(value)))
	profile.loop = false
	var death_mode = raw.get("guardDeath", 0)
	profile.guardDeath = int(death_mode) if (death_mode is int or death_mode is float) and death_mode == int(death_mode) and int(death_mode) in [0,1,2] else 0
	rebuild_unlocks()
	var selected = raw.get("loopLevel", 0)
	profile.loopLevel = int(selected) if (selected is int or selected is float) and profile.cleared.has(int(selected)) else 0
	var guard_stage = raw.get("guardStage", 0)
	var saved_index = raw.get("guardIndex", -1)
	var saved_distance = raw.get("guardDistance", -1)
	if raw.get("loop", false) == true and (guard_stage is int or guard_stage is float) and guard_stage == int(guard_stage) and guard_stage >= 1 and guard_stage <= profile.highestLevel:
		if (saved_index is int or saved_index is float) and saved_index == int(saved_index) and saved_index >= 0 and saved_index < db.levels[int(guard_stage)-1].groups.size() and (saved_distance is int or saved_distance is float) and is_finite(float(saved_distance)) and saved_distance >= 0 and saved_distance <= float(db.levels[int(guard_stage)-1].length):
			profile.loop = true
			profile.guardStage = int(guard_stage)
			profile.guardIndex = int(saved_index)
			profile.guardDistance = float(saved_distance)
	var saved_ship := str(raw.get("selectedShip", first_ship()))
	profile.selectedShip = saved_ship if ship_unlocked(saved_ship) else first_ship()
	profile.loadout = default_loadout(profile.selectedShip, profile.unlocked)
	if raw.get("loadout") is Dictionary:
		profile.loadout = raw.loadout.duplicate(true)
	ensure_loadout()
	# Version 1 gives the legacy level precedence for the first installed instance,
	# even when loadout is present. Resolve that conflict once, at the input boundary.
	for key in EQUIPMENT:
		var entry := first_equipment_entry(key)
		var value = raw.get("levels", {}).get(key, 1) if raw.get("levels") is Dictionary else 1
		if not entry.is_empty():
			entry.level = clampi(int(value), 1, db.max_equipment_level(key)) if value is float or value is int else 1
	load_hightech(raw)
	profile.hightechOrder = hightech_slots()
	load_charge(raw)
	settle_offline_resources(raw, floorf(Time.get_unix_time_from_system()))

func settle_offline_resources(raw: Dictionary, now: float) -> void:
	offline_rewards.clear()
	if not nonnegative_number(raw.get("offlineSavedAt")) or not raw.get("offlineRates") is Dictionary:
		return
	var seconds := clampf(floorf(now) - float(raw.offlineSavedAt), 0, float(db.config.get("offlineMax", 0)) * 3600.0)
	for id in profile.resources:
		var rate = raw.offlineRates.get(id, 0)
		if not nonnegative_number(rate):
			continue
		var amount := ceilf(float(rate) * seconds)
		if is_finite(amount) and amount > 0:
			profile.resources[id] += amount
			offline_rewards[id] = amount

func nonnegative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func load_hightech(raw: Dictionary) -> void:
	raw = raw.duplicate(true)
	if int(raw.get("hightechVersion",0)) != 2:
		for field in ["hightechLevels","hightechResearch","scientists","scientistAssignments","techPoints","furnaceElapsed","hightechDrops"]:
			raw.erase(field)
	if raw.get("hightechOrder") is Array:
		profile.hightechOrder = raw.hightechOrder.filter(func(key):return key is String)
	for field in ["hightechSavedAt", "furnaceElapsed", "furnaceIncomePeak"]:
		if nonnegative_number(raw.get(field)):
			profile[field] = float(raw[field])
	if raw.get("hightechLevels") is Dictionary:
		for key in db.data.get("hightech", {}):
			var value = raw.hightechLevels.get(key, 0)
			if nonnegative_number(value) and float(value) == floorf(float(value)):
				profile.hightechLevels[key] = int(value)
	if nonnegative_number(raw.get("scientists")):
		profile.scientists = int(raw.scientists)
	var available := int(profile.scientists)
	for key in db.data.get("hightech", {}):
		var count = raw.get("scientistAssignments", {}).get(key,0) if raw.get("scientistAssignments") is Dictionary else 0
		if nonnegative_number(count) and hightech_unlocked(key):
			profile.scientistAssignments[key] = mini(int(count),available)
			available -= int(profile.scientistAssignments[key])
		var points = raw.get("techPoints", {}).get(key,0) if raw.get("techPoints") is Dictionary else 0
		if nonnegative_number(points):
			profile.techPoints[key] = float(points)
	if raw.get("resourceSamples") is Array:
		for sample in raw.resourceSamples:
			if sample is Dictionary and nonnegative_number(sample.get("time")) and nonnegative_number(sample.get("amount")) and str(sample.get("id", "")) in ["1", "2"] and float(sample.time) <= float(profile.hightechSavedAt) and float(sample.time) > float(profile.hightechSavedAt) - 60.0:
				# Legacy samples have no reliable source; keep totals but exclude them
				# from furnace input until this short rolling window expires.
				resource_samples.append({"time":float(sample.time), "amount":float(sample.amount), "id":str(sample.id), "origin":str(sample.get("origin", "unknown"))})
	profile.furnaceIncomePeak = furnace_income_peak(float(profile.hightechSavedAt))
	if raw.get("hightechDrops") is Array:
		for drop in raw.hightechDrops:
			if drop is Dictionary and nonnegative_number(drop.get("age")) and float(drop.age) < 10 and nonnegative_number(drop.get("amount")) and nonnegative_number(drop.get("x")) and nonnegative_number(drop.get("y")):
				uid += 1
				drops.append({"uid":uid,"x":clampf(float(drop.x),80,1300),"y":clampf(float(drop.y),285,520),"age":float(drop.age),"id":"1","amount":ceilf(float(drop.amount)),"hightech":true})

func rebuild_unlocks() -> void:
	profile.highestLevel = 1
	profile.unlocked = []
	for n in profile.cleared:
		profile.highestLevel = mini(db.levels.size(), maxi(profile.highestLevel, int(n) + 1))
	for key in EQUIPMENT:
		if db.unlock_level(key) == 0 or profile.cleared.has(db.unlock_level(key)):
			profile.unlocked.append(key)
	if not ship_unlocked(str(profile.get("selectedShip", first_ship()))):
		profile.selectedShip = first_ship()
	ensure_loadout()
	profile.hightechOrder = hightech_slots()

func ensure_loadout() -> void:
	var row := db.ship(str(profile.get("selectedShip", first_ship())))
	if row.is_empty():
		profile.selectedShip = first_ship()
		row = db.ship(profile.selectedShip)
	var base := default_loadout(profile.selectedShip, profile.unlocked)
	var saved: Dictionary = profile.get("loadout", {})
	for category in ["weapons", "defence"]:
		var allowed: Array = WEAPON_KEYS if category == "weapons" else DEFENSE_KEYS
		var count := int(row.get("weaponSlots", 0)) if category == "weapons" else int(row.get("defenseSlots", 0))
		var entries: Array = saved.get(category, []) if saved.get(category, []) is Array else []
		var normalized: Array = []
		for i in range(count):
			var entry = entries[i] if i < entries.size() and entries[i] is Dictionary else base[category][i]
			var equip_key := str(entry.get("key", "")) if entry is Dictionary else ""
			var level := int(entry.get("level", 1)) if entry is Dictionary and (entry.get("level", 1) is int or entry.get("level", 1) is float) else 1
			if not equip_key.is_empty() and (not allowed.has(equip_key) or not profile.unlocked.has(equip_key)):
				equip_key = ""
			normalized.append({"key":equip_key, "level":clampi(level, 1, db.max_equipment_level(equip_key)) if not equip_key.is_empty() else 1})
		profile.loadout[category] = normalized

func save_progress() -> void:
	if not save_enabled:
		return
	profile.hightechOrder = hightech_slots()
	profile.hightechSavedAt = Time.get_unix_time_from_system()
	prune_resource_samples(float(profile.hightechSavedAt))
	profile.resourceSamples = resource_samples
	profile.offlineSavedAt = floorf(float(profile.hightechSavedAt))
	profile.offlineRates = {}
	for id in profile.resources:
		profile.offlineRates[id] = resource_minute_total(id, float(profile.hightechSavedAt)) / 60.0
	profile.hightechDrops = drops.filter(func(drop):return drop.get("hightech", false))
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		event.emit("save_error", {})
		return
	# Compatibility projection only; never install name-based levels in runtime.
	var saved := profile.duplicate()
	saved.levels = {}
	for key in EQUIPMENT:
		saved.levels[key] = int(first_equipment_entry(key).get("level", 1))
	file.store_string(JSON.stringify(saved, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		event.emit("save_error", {})

func first_equipment_entry(key: String) -> Dictionary:
	for category in ["weapons", "defence"]:
		for entry in profile.get("loadout", {}).get(category, []):
			if str(entry.get("key", "")) == key:
				return entry
	return {}

func loadout_entries(category: String) -> Array:
	return profile.loadout.get(category, [])

func weapon_entries() -> Array:
	return loadout_entries("weapons")

func defense_entries() -> Array:
	return loadout_entries("defence")

func stat(key: String) -> float:
	var total := 0.0
	for category in ["weapons", "defence"]:
		for entry in profile.loadout.get(category, []):
			if str(entry.get("key", "")) == key:
				total += equipment_stat(key, int(entry.level))
	return total

func ship_movement() -> float:
	return float(db.ship(str(profile.get("selectedShip", first_ship()))).get("movement", db.config.movement))

func ship_name() -> String:
	return str(db.ship(str(profile.get("selectedShip", first_ship()))).get("des", profile.get("selectedShip", first_ship())))

func slot_entry(category: String, index: int) -> Dictionary:
	var entries := loadout_entries(category)
	return entries[index] if index >= 0 and index < entries.size() else {}

func slot_id(category: String, index: int) -> String:
	return "%s_%d" % [category, index]

func first_weapon_index(key: String) -> int:
	for index in range(weapon_entries().size()):
		if str(weapon_entries()[index].key) == key:
			return index
	return -1

func slot_upgrade_cost(category: String, index: int, levels := 1) -> Dictionary:
	var entry := slot_entry(category, index)
	return {} if entry.is_empty() or str(entry.key).is_empty() else upgrade_costs_for_level(str(entry.key), int(entry.level), levels)

func upgrade_costs_for_level(key: String, current: int, levels: int) -> Dictionary:
	var total := {}
	if levels <= 0 or current + levels > db.max_equipment_level(key):
		return total
	for level in range(current + 1, current + levels + 1):
		var cost := upgrade_cost_for_level(key, level)
		for id in cost:
			total[id] = int(total.get(id, 0)) + int(cost[id])
	return total

func can_upgrade_slot(category: String, index: int, levels := 1) -> bool:
	var entry := slot_entry(category, index)
	if entry.is_empty() or str(entry.key).is_empty() or not profile.unlocked.has(str(entry.key)):
		return false
	if levels > 1 and not EQUIPMENT.has(str(entry.key)):
		return false
	var costs := slot_upgrade_cost(category, index, levels)
	if costs.is_empty():
		return false
	for id in costs:
		if float(profile.resources.get(id, 0)) < float(costs[id]):
			return false
	return true

func refund_equipment(key: String, level: int) -> void:
	for target_level in range(2, level + 1):
		for id in upgrade_cost_for_level(key, target_level):
			profile.resources[id] = float(profile.resources.get(id, 0)) + float(upgrade_cost_for_level(key, target_level)[id])

func equipment_limit() -> int:
	return int(db.ship(str(profile.selectedShip)).get("sameEquipmentLimit", 1))

func equipment_count(key: String) -> int:
	var count := 0
	for category in ["weapons", "defence"]:
		for entry in profile.loadout.get(category, []):
			if str(entry.get("key", "")) == key:
				count += 1
	return count

func valid_loadout(key: String, loadout: Dictionary) -> bool:
	if not ship_unlocked(key):
		return false
	var row := db.ship(key)
	var counts := {}
	for category in ["weapons", "defence"]:
		var allowed: Array = WEAPON_KEYS if category == "weapons" else DEFENSE_KEYS
		var expected := int(row.get("weaponSlots", 0)) if category == "weapons" else int(row.get("defenseSlots", 0))
		var entries = loadout.get(category, [])
		if not entries is Array or entries.size() != expected:
			return false
		for entry in entries:
			if not entry is Dictionary:
				return false
			var equip_key := str(entry.get("key", ""))
			if equip_key.is_empty():
				continue
			if not allowed.has(equip_key) or not profile.unlocked.has(equip_key):
				return false
			counts[equip_key] = int(counts.get(equip_key, 0)) + 1
	for equip_key in counts:
		if int(counts[equip_key]) > int(row.get("sameEquipmentLimit", 1)):
			return false
	return true

func equip_slot(category: String, index: int, key: String) -> bool:
	if category not in ["weapons", "defence"]:
		return false
	var allowed: Array = WEAPON_KEYS if category == "weapons" else DEFENSE_KEYS
	var entries := loadout_entries(category)
	if index < 0 or index >= entries.size() or not allowed.has(key) or not profile.unlocked.has(key):
		return false
	if not str(entries[index].key).is_empty():
		return false
	if equipment_count(key) >= equipment_limit():
		return false
	var old_total_armour := stat("armour")
	var old_total_shield := stat("shield")
	profile.loadout[category][index] = {"key":key, "level":1}
	if category == "defence" and player.has("armour"):
		player.armour = clampf(player.armour + stat("armour") - old_total_armour, 0, stat("armour"))
		player.shield = clampf(player.shield + max_shield() - old_total_shield, 0, max_shield())
	if category == "weapons":
		cooldowns.erase(slot_id(category, index))
	save_progress()
	return true

func unequip_slot(category: String, index: int) -> bool:
	if category not in ["weapons", "defence"]:
		return false
	var entry := slot_entry(category, index)
	if entry.is_empty() or str(entry.key).is_empty():
		return false
	var key := str(entry.key)
	refund_equipment(key, int(entry.level))
	profile.loadout[category][index] = {"key":"", "level":1}
	cooldowns.erase(slot_id(category, index))
	if category == "defence" and player.has("armour"):
		player.armour = minf(player.armour, stat("armour"))
		player.shield = minf(player.shield, max_shield())
	save_progress()
	return true

func refund_all_equipment() -> void:
	for category in ["weapons", "defence"]:
		for entry in profile.loadout.get(category, []):
			if not str(entry.get("key", "")).is_empty():
				refund_equipment(str(entry.key), int(entry.level))

func switch_ship(key: String, selected_loadout: Dictionary = {}) -> bool:
	if key == str(profile.get("selectedShip", "")) or not ship_unlocked(key):
		return false
	var next_loadout := default_loadout(key, profile.unlocked) if selected_loadout.is_empty() else selected_loadout.duplicate(true)
	if not valid_loadout(key, next_loadout):
		return false
	refund_all_equipment()
	profile.selectedShip = key
	profile.loadout = empty_loadout(key)
	for category in ["weapons", "defence"]:
		for index in range(next_loadout[category].size()):
			var equip_key := str(next_loadout[category][index].get("key", ""))
			profile.loadout[category][index] = {"key":equip_key, "level":1}
	profile.loop = false
	return start(1, false)

func equipment_stat(key: String, level: int) -> float:
	var row := db.equip(key, level)
	var value := float(row.para1 if key in ["armour", "shield"] else row.dmg)
	var tech := DENSE_ARMOUR if key in ["armour", "shield"] else ENERGY_FOCUS
	if hightech_level(tech) > 0:
		value = ceilf(value * pow(1.0 + float(db.data.hightech[tech].para1),hightech_level(tech)))
	var charge_bonus := charge_multiplier("防御充能" if key in ["armour", "shield"] else "攻击充能")
	if charge_bonus != 1.0:
		value = ceilf(value * charge_bonus)
	return value

func charge_job(key: String) -> Dictionary:
	return profile.charge[key]

func charge_unlocked(key: String) -> bool:
	if not db.data.get("charge",{}).has(key):
		return false
	var gate := int(db.data.charge[key].unlock)
	return gate == 0 or profile.cleared.has(gate)

func charge_required(key: String) -> float:
	var row: Dictionary = db.data.charge[key]
	return roundf(float(row.para_5) * pow(float(row.para_6),int(charge_job(key).level)))

func charge_multiplier(key: String) -> float:
	if not db.data.get("charge",{}).has(key):
		return 1.0
	return pow(1.0 + float(db.data.charge[key].para_3),int(charge_job(key).level))

func charge_resource_rate(key: String) -> float:
	var row: Dictionary = db.data.charge[key]
	return roundf(float(row.para_2) * pow(1.0 + float(row.get("para_7",0)),int(charge_job(key).level)))

func charge_description(key: String) -> String:
	var row: Dictionary = db.data.charge[key].duplicate()
	for i in range(1,8):
		row["para"+str(i)] = row.get("para_"+str(i),0)
	return format_description(row,str(row.des),int(charge_job(key).level))

func toggle_charge(key: String) -> bool:
	if not charge_unlocked(key):
		return false
	var job := charge_job(key)
	job.active = not job.active
	if job.active:
		var latest := 0
		for existing in profile.charge.values():
			latest = maxi(latest,int(existing.get("started",0)))
		job.started = latest + 1
	save_progress()
	return true

func load_charge(raw: Dictionary) -> void:
	if raw.get("charge") is Dictionary:
		for key in db.data.get("charge",{}):
			var saved = raw.charge.get(key)
			if not saved is Dictionary:
				continue
			if not nonnegative_number(saved.get("level")) or float(saved.level) != floorf(float(saved.level)):
				continue
			var job := charge_job(key)
			job.level = int(saved.level)
			if nonnegative_number(saved.get("count")) and float(saved.count) == floorf(float(saved.count)) and float(saved.count) < charge_required(key):
				job.count = float(saved.count)
			if nonnegative_number(saved.get("elapsed")) and float(saved.elapsed) < float(db.data.charge[key].para_4):
				job.elapsed = float(saved.elapsed)
			job.active = saved.get("active",false) == true
			if nonnegative_number(saved.get("credit")) and float(saved.credit) < 1.0:
				job.credit = float(saved.credit)
			if nonnegative_number(saved.get("started")) and float(saved.started) == floorf(float(saved.started)):
				job.started = int(saved.started)

func advance_charge(dt: float) -> void:
	# A level changes the rate immediately, including within a long offline step.
	while dt > 0.000000001:
		var step := dt
		var funded := false
		for key in db.data.get("charge",{}):
			var job := charge_job(key)
			var row: Dictionary = db.data.charge[key]
			if not charge_unlocked(key) or not job.active:
				continue
			if charge_resource_rate(key) > 0 and float(profile.resources.get(str(int(row.para_1)),0)) <= 0 and float(job.credit) <= 0:
				continue
			funded = true
			if float(row.get("para_7",0)) > 0:
				step = minf(step,(charge_required(key)-float(job.count))*float(row.para_4)-float(job.elapsed))
		if not funded:
			return
		advance_charge_step(step)
		dt -= step

func advance_charge_step(dt: float) -> void:
	if dt <= 0:
		return
	var groups := {}
	for key in db.data.get("charge",{}):
		if charge_unlocked(key) and charge_job(key).active:
			var id := str(int(db.data.charge[key].para_1))
			if not groups.has(id):
				groups[id] = []
			groups[id].append(key)
	for id in groups:
		var balance := floorf(maxf(0,float(profile.resources.get(id,0))))
		var waiting: Array = groups[id].duplicate()
		waiting.sort_custom(func(a,b):return int(charge_job(a).started) < int(charge_job(b).started))
		var allocations := {}
		var demands := {}
		for key in waiting:
			# Buy whole resources; retain their unused charging time across frames
			# and saves, rather than rounding up a separate cost every frame.
			demands[key] = ceilf(maxf(0,charge_resource_rate(key)*dt-float(charge_job(key).credit)-0.000000001))
		while not waiting.is_empty():
			var share := floorf(balance / waiting.size())
			var satisfied := []
			for key in waiting:
				var demand := float(demands[key])
				if demand <= share:
					allocations[key] = demand
					balance -= demand
					satisfied.append(key)
			if satisfied.is_empty():
				var remainder := int(balance - share * waiting.size())
				for key in waiting:
					allocations[key] = share + (1.0 if remainder > 0 else 0.0)
					remainder -= 1
				balance = 0.0
				break
			for key in satisfied:
				waiting.erase(key)
		var previous_balance := float(profile.resources.get(id,0))
		profile.resources[id] = maxf(0,balance)
		if not is_equal_approx(previous_balance,float(profile.resources[id])):
			charge_resources_dirty = true
		for key in allocations:
			var row: Dictionary = db.data.charge[key]
			var job := charge_job(key)
			job.credit += float(allocations[key])
			var rate := charge_resource_rate(key)
			var seconds := minf(dt,float(job.credit)/rate) if rate > 0 else dt
			job.credit = maxf(0,float(job.credit)-seconds*rate)
			var elapsed := float(job.elapsed) + seconds
			var completed := floorf((elapsed + 0.000000001) / float(row.para_4))
			job.elapsed = maxf(0,elapsed - completed * float(row.para_4))
			job.count += completed
			while float(job.count) >= charge_required(key):
				job.count -= charge_required(key)
				job.level += 1

func hightech_level(key: String) -> int:
	return int(profile.get("hightechLevels", {}).get(key, 0))

func hightech_unlocked(key: String) -> bool:
	if not db.data.get("hightech", {}).has(key):
		return false
	var gate := int(db.data.hightech[key].unlock)
	return gate == 0 or profile.cleared.has(gate)

func hightech_slots() -> Array:
	var unlocked: Array = db.data.get("hightech", {}).keys().filter(func(key):return hightech_unlocked(key))
	# Keep an empty slot available and grow by complete visible pages.
	var count := maxi(HIGHTECH_MIN_SLOTS, int(ceilf(float(unlocked.size()+1)/HIGHTECH_SLOTS_PER_PAGE))*HIGHTECH_SLOTS_PER_PAGE)
	var slots: Array = []
	slots.resize(count)
	slots.fill("")
	var stored: Array = profile.get("hightechOrder", [])
	for i in range(mini(stored.size(),count)):
		if unlocked.has(stored[i]) and not slots.has(stored[i]):
			slots[i] = stored[i]
	# New unlocks fill vacancies without shifting the player's existing cards.
	for key in unlocked:
		if not slots.has(key):
			slots[slots.find("")] = key
	return slots

func swap_hightech_slots(source: int, target: int) -> bool:
	var slots := hightech_slots()
	if source < 0 or target < 0 or source >= slots.size() or target >= slots.size() or source == target or slots[source] == "":
		return false
	var key = slots[source]
	slots[source] = slots[target]
	slots[target] = key
	profile.hightechOrder = slots
	save_progress()
	return true

func hightech_required(key: String) -> float:
	var row: Dictionary = db.data.hightech[key]
	# D2 gives a linear series: 10, 12, 14, ...; target level is current + 1.
	return roundf(float(row.tpCostBase) * (1.0 + float(row.tpCostMutiple) * hightech_level(key)))

func description_number(value: float) -> String:
	return NUMBER_FORMAT.precise(value)

func hightech_description(key: String, now := -1.0) -> String:
	if hightech_level(key)==0:
		return "未研发，无效果"
	var row: Dictionary = db.data.hightech[key]
	return format_description(row,str(row.get("description", "")),hightech_level(key),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now,true))

func format_description(row: Dictionary, template: String, level: int, minute_income := 0.0, excluded_income := 0.0) -> String:
	var result := template
	var tokens := RegEx.new()
	tokens.compile("para[0-9]+")
	var braces := RegEx.new()
	braces.compile("\\{([^{}]+)\\}")
	var matches := braces.search_all(result)
	matches.reverse()
	var allowed := RegEx.new()
	allowed.compile("^[0-9. +*/()^\\-]+$")
	var numbers := RegEx.new()
	numbers.compile("[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+")
	for block in matches:
		var parts := block.get_string(1).replace("，",",").split(",")
		var options: Array = Array(parts).slice(1).map(func(option):return str(option).strip_edges())
		var formula := str(parts[0])
		var formula_tokens := tokens.search_all(formula)
		formula_tokens.reverse()
		for token in formula_tokens:
			var token_value = row.get(token.get_string())
			var token_replacement := description_number(float(token_value)) if nonnegative_number(token_value) else "？"
			formula = formula.substr(0,token.get_start()) + token_replacement + formula.substr(token.get_end())
		formula = formula.replace("过去一分钟的铁生成量",description_number(excluded_income if options.has("不含自身") else minute_income)).replace("等级",str(level)).replace("lv",str(level)).replace("（","(").replace("）",")")
		var replacement := "？"
		var expression := Expression.new()
		# Expression otherwise uses integer division for literals such as 1/2.
		var literals := numbers.search_all(formula)
		literals.reverse()
		for literal in literals:
			if not literal.get_string().contains("."):
				formula = formula.substr(0,literal.get_end()) + ".0" + formula.substr(literal.get_end())
		var numeric_only := allowed.search(formula) != null
		var power := RegEx.new()
		power.compile("(\\([^()^]*\\)|[0-9.]+)\\s*\\^\\s*([0-9.]+)")
		formula = power.sub(formula,"pow($1,$2)",true)
		if numeric_only and not formula.contains("^") and options.all(func(option):return option in ["向上取整","不含自身","百分比显示","保留两位小数","即100.3%展示为100%","百分比","四舍五入保留整数百分比部分"]) and expression.parse(formula) == OK:
			var value = expression.execute([],null,false,true)
			if not expression.has_execute_failed() and (value is int or value is float) and is_finite(float(value)):
				if options.has("百分比显示") or options.has("百分比"):
					var percent := float(value) * 100.0
					if options.has("四舍五入保留整数百分比部分"):
						replacement = (NUMBER_FORMAT.precise(roundf(percent)) if percent < 1000.0 else NUMBER_FORMAT.compact(roundf(percent))) + "%"
					elif options.has("即100.3%展示为100%"):
						replacement = NUMBER_FORMAT.compact(floorf(percent + 0.00000001)) + "%"
					elif options.has("保留两位小数") and percent < 1000.0:
						replacement = "%.2f%%" % percent
					else:
						replacement = NUMBER_FORMAT.compact(percent) + "%"
				else:
					replacement = NUMBER_FORMAT.compact(ceilf(float(value)) if options.has("向上取整") else float(value))
		result = result.substr(0,block.get_start()) + replacement + result.substr(block.get_end())
	var remaining_tokens := tokens.search_all(result)
	remaining_tokens.reverse()
	for token in remaining_tokens:
		var token_value = row.get(token.get_string())
		var token_replacement := NUMBER_FORMAT.compact(float(token_value)) if nonnegative_number(token_value) else "？"
		result = result.substr(0,token.get_start()) + token_replacement + result.substr(token.get_end())
	return result

func scientist_cost(offset := 0) -> Dictionary:
	var parts := str(db.config.scientistCost).split(",")
	var multiplier := pow(float(parts[0]),int(profile.scientists)+offset)
	var costs := {}
	for entry in Array(parts).slice(1):
		var pair := str(entry).split("|")
		costs[pair[0]] = roundf(float(pair[1])*multiplier)
	return costs

func scientist_purchase(amount := 1) -> Dictionary:
	var total := {}
	var count := 0
	if not db.data.hightech.keys().any(func(key):return hightech_unlocked(key)):
		return {"count":0,"costs":total}
	while amount < 0 or count < amount:
		var costs := scientist_cost(count)
		var paid := false
		for id in costs:
			paid = paid or float(costs[id]) > 0
			if not is_finite(float(costs[id])) or float(total.get(id,0))+float(costs[id]) > float(profile.resources.get(id,0)):
				return {"count":count if amount < 0 else 0,"costs":total}
		# An unbounded free tail has no finite MAX purchase.
		if amount < 0 and not paid:
			return {"count":count,"costs":total}
		for id in costs:
			total[id] = float(total.get(id,0))+float(costs[id])
		count += 1
	return {"count":count,"costs":total}

func can_generate_scientist(amount := 1) -> bool:
	if amount < 0:
		# MAX is available only if its first purchase is affordable and not free.
		var first := scientist_purchase(1)
		return int(first.count)>0 and first.costs.values().any(func(cost):return float(cost)>0)
	return int(scientist_purchase(amount).count)>0

func generate_scientist(amount := 1) -> bool:
	var purchase := scientist_purchase(amount)
	if int(purchase.count)<=0:
		return false
	for id in purchase.costs:
		profile.resources[id] -= purchase.costs[id]
	profile.scientists += int(purchase.count)
	save_progress()
	event.emit("scientists_changed", {})
	return true

func distribute_scientists() -> bool:
	var keys := hightech_slots().filter(func(key):return not str(key).is_empty())
	if keys.is_empty() or int(profile.scientists)<=0:
		return false
	profile.scientistAssignments.clear()
	var total := int(profile.scientists)
	for i in range(keys.size()):
		profile.scientistAssignments[keys[i]] = total/keys.size() + (1 if i < total%keys.size() else 0)
	save_progress()
	event.emit("scientists_changed", {})
	return true

func assigned_scientists(key: String) -> int:
	return int(profile.scientistAssignments.get(key,0))

func idle_scientists() -> int:
	var count := int(profile.scientists)
	for key in profile.scientistAssignments:
		count -= assigned_scientists(key)
	return count

func can_research(key: String) -> bool:
	return hightech_unlocked(key) and idle_scientists() > 0

func assign_scientist(key: String, delta: int) -> bool:
	if not hightech_unlocked(key) or delta == 0 or (delta > 0 and idle_scientists() <= 0) or (delta < 0 and assigned_scientists(key) <= 0):
		return false
	profile.scientistAssignments[key] = assigned_scientists(key)+clampi(delta,-assigned_scientists(key),idle_scientists())
	save_progress()
	event.emit("scientists_changed", {})
	return true

func research_rate(key: String) -> float:
	var count := assigned_scientists(key)
	if count <= 0 or not hightech_unlocked(key):
		return 0.0
	var base := float(db.config.techPointGet)*count
	return roundf(pow(base,float(db.config.hightechLimit))) if count > 1 else base

func active_research() -> Array:
	return db.data.hightech.keys().filter(func(key):return research_rate(key)>0)

func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
	if real_dt < 0:
		real_dt = dt
	if end_time < 0:
		end_time = Time.get_unix_time_from_system()
	var wall_per_step := real_dt / dt if dt > 0 else 1.0
	# Huge point budgets cannot be settled one level/event at a time.
	# Ignore per-level rounding and use the linear cost series in this regime.
	var bulk := active_research().any(func(key):return float(profile.techPoints.get(key,0))+research_rate(key)*dt >= 1e20)
	if bulk:
		for key in active_research():
			advance_hightech_bulk(key,dt)
		# At this scale furnace output uses the end-of-step level (approximate).
		advance_furnace(dt,end_time,wall_per_step)
		return
	# Keep furnace activation at the exact research completion boundary.
	var remaining := maxf(dt,0)
	while remaining > 0:
		var step := remaining
		for key in active_research():
			step = minf(step,maxf(0,hightech_required(key)-float(profile.techPoints.get(key,0)))/research_rate(key))
		advance_furnace(step,end_time-(remaining-step)*wall_per_step,wall_per_step)
		remaining -= step
		for key in active_research():
			profile.techPoints[key] = float(profile.techPoints.get(key,0))+research_rate(key)*step
			var required := hightech_required(key)
			if float(profile.techPoints[key])+0.00000001 >= required:
				profile.techPoints[key] = maxf(0,float(profile.techPoints[key])-required)
				profile.hightechLevels[key] = hightech_level(key)+1
				event.emit("hightech_complete", {"key":key})

func advance_hightech_bulk(key: String, dt: float) -> void:
	var points := minf(float(profile.techPoints.get(key,0))+research_rate(key)*dt,1e308)
	var row: Dictionary = db.data.hightech[key]
	var level := hightech_level(key)
	var growth := float(row.tpCostBase)*float(row.tpCostMutiple)
	var first := float(row.tpCostBase)+growth*level
	var linear := first-growth*0.5
	# Stable quadratic root; sqrt factors avoid overflowing growth * points.
	var root := absf(linear)
	root = sqrt(pow(root/sqrt(maxf(points,1.0)),2)+2.0*growth)*sqrt(maxf(points,1.0))
	var count := floorf(points/(linear*0.5+root*0.5)) if growth > 0 else floorf(points/maxf(1,roundf(first)))
	# Leave headroom for integer conversion and subsequent level increments.
	count = clampf(count,0,maxf(0,9e18-float(level)))
	var spent := count*(first+growth*(count-1)*0.5) if growth > 0 else count*maxf(1,roundf(first))
	profile.techPoints[key] = maxf(0,points-spent)
	if count > 0:
		profile.hightechLevels[key] = level+int(count)
		event.emit("hightech_complete", {"key":key})

func prune_resource_samples(now: float) -> void:
	resource_samples = resource_samples.filter(func(sample):return float(sample.time) > now - 60.0)

func resource_minute_total(id: String, now := -1.0, exclude_furnace := false) -> float:
	if now < 0:
		now = Time.get_unix_time_from_system()
	var total := 0.0
	for sample in resource_samples:
		if exclude_furnace and sample.get("origin", "drop") != "drop":
			continue
		if sample.id == id and float(sample.time) > now - 60.0 and float(sample.time) <= now:
			total += float(sample.amount)
	return total

func furnace_income_peak(now := -1.0) -> float:
	return maxf(float(profile.get("furnaceIncomePeak",0.0)),resource_minute_total("1",now,true))

func auto_gen_settings() -> Dictionary:
	var raw = db.config.get("autoGenRes", "")
	if not raw is String:
		return {}
	var parts := str(raw).replace("，", ",").split(",")
	if parts.size() != 4:
		return {}
	var interval_text := parts[0].strip_edges()
	var resource_id := parts[1].strip_edges()
	var amount_text := parts[2].strip_edges()
	var speed_text := parts[3].strip_edges()
	if not interval_text.is_valid_float() or not resource_id.is_valid_int() or not amount_text.is_valid_float() or not speed_text.is_valid_float():
		return {}
	var interval := float(interval_text)
	var amount := float(amount_text)
	var speed_value := float(speed_text)
	if interval <= 0 or amount < 0 or speed_value <= 0 or not is_finite(interval) or not is_finite(amount) or not is_finite(speed_value) or not db.data.resources.has(resource_id):
		return {}
	return {"interval":interval,"resource_id":resource_id,"amount":amount,"speed":speed_value}

func advance_auto_gen(dt: float) -> void:
	for drop in drops.duplicate():
		if not drop.get("auto_gen", false):
			continue
		drop.x -= float(drop.speed) * dt
		if drop.x <= float(player.x):
			collect(drop, false)
	var settings := auto_gen_settings()
	if not is_active() or settings.is_empty():
		return
	auto_gen_elapsed += dt
	var count := floori(auto_gen_elapsed / float(settings.interval))
	if count <= 0:
		return
	auto_gen_elapsed = fposmod(auto_gen_elapsed, float(settings.interval))
	for _i in range(count):
		uid += 1
		var amount := ceilf(float(settings.amount) * ratio("resRatio"))
		drops.append({"uid":uid,"x":1440.0,"y":rng.randf_range(285.0,520.0),"age":0.0,"id":settings.resource_id,"amount":amount,"speed":settings.speed,"auto_gen":true})

func advance_furnace(dt: float, end_time: float, wall_per_step: float) -> void:
	for drop in drops.duplicate():
		if drop.get("hightech", false):
			drop.age += dt
			if float(drop.age) >= 10.0:
				drops.erase(drop)
	if hightech_level(FURNACE) > 0 and db.data.get("hightech", {}).has(FURNACE):
		var row: Dictionary = db.data.hightech[FURNACE]
		var interval := float(row.para1)
		var elapsed := float(profile.furnaceElapsed) + dt
		var count := floorf(elapsed / interval)
		profile.furnaceElapsed = fposmod(elapsed, interval)
		# Skip expired offline blocks, with work bounded by the 10-second visible window.
		var visible := mini(int(count), int(ceilf(10.0 / interval)))
		for i in range(visible):
			var age := float(profile.furnaceElapsed) + i * interval
			if age >= 10.0:
				break
			uid += 1
			profile.furnaceIncomePeak = furnace_income_peak(end_time - age * wall_per_step)
			var amount := ceilf(float(profile.furnaceIncomePeak) * float(row.para2) * hightech_level(FURNACE))
			drops.append({"uid":uid,"x":rng.randf_range(440,1220),"y":rng.randf_range(300,505),"age":age,"id":"1","amount":amount,"hightech":true})

func max_shield() -> float:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	player = {"x":280.0, "y":405.0, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	if next == State.TRAVEL:
		cooldowns.clear()
		for index in range(weapon_entries().size()):
			var entry: Dictionary = weapon_entries()[index]
			var key := str(entry.key)
			if key.is_empty():
				continue
			var cd := float(db.equip(key,int(entry.level)).cd)
			if cd > 0:
				cooldowns[slot_id("weapons", index)] = cd
	state = next
	event.emit("state", {"state":state})

func select_loop_level(level: int) -> bool:
	if not profile.cleared.has(level):
		return false
	profile.loopLevel = level
	return start(level, false)

func toggle_loop() -> void:
	if profile.loop:
		profile.loop = false
		guard_elapsed = 0
		guard_arrived = false
		save_progress()
	elif state in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR] and not db.levels[stage-1].groups.is_empty():
		guard_index = clampi(group_index if state == State.TRAVEL else group_index-1, 0, db.levels[stage-1].groups.size()-1)
		profile.loop = true
		guard_elapsed = 0
		profile.guardStage = stage
		guard_engaged = not targets().is_empty()
		profile.guardIndex = guard_index
		guard_arrived = state != State.TRAVEL
		profile.guardDistance = distance if guard_arrived else float(db.levels[stage-1].groups[guard_index].position) * float(db.levels[stage-1].length)
		if state == State.LEVEL_CLEAR:
			clear_timer = guard_interval()
		save_progress()

func guarding_here() -> bool:
	return profile.loop and guard_arrived

func set_guard_death(mode: int) -> void:
	if mode in [0,1,2]:
		profile.guardDeath = mode
		save_progress()

func guard_interval() -> float:
	var encounters: Array = db.levels[stage-1].groups
	var previous := 0.0 if guard_index == 0 else float(encounters[guard_index-1].position)
	var gap := float(encounters[guard_index].position) * float(db.levels[stage-1].length) - previous * float(db.levels[stage-1].length)
	return gap / ship_movement() if ship_movement() > 0 else INF

func respawn_guard() -> void:
	guard_elapsed = 0
	group_index = guard_index
	spawn_group(true)

func resume_guard() -> void:
	retreat_boss_pending = false
	guard_index = int(profile.guardIndex)
	distance = float(profile.guardDistance)
	group_index = guard_index + 1
	guard_elapsed = 0
	guard_engaged = false
	guard_arrived = true
	change_state(State.COMBAT)

func advance_after_clear() -> bool:
	if state != State.LEVEL_CLEAR or not pending_unlocks.is_empty():
		return false
	return start(next_stage(), profile.loop and not guard_arrived)

func next_stage() -> int:
	return mini(stage + 1, db.levels.size())

func start(level: int, loop_mode: bool) -> bool:
	if level < 1 or level > int(profile.highestLevel):
		return false
	settle_drops()
	stage = level
	distance = 0
	group_index = 0
	guard_index = -1
	guard_elapsed = 0
	guard_engaged = false
	guard_arrived = false
	retreat_boss_pending = false
	enemies.clear()
	projectiles.clear()
	cooldowns.clear()
	pending_unlocks.clear()
	reset_player()
	paused = false
	profile.loop = loop_mode
	if loop_mode:
		guard_index = int(profile.get("guardIndex", 0))
	run_resources = {"1":0.0,"2":0.0}
	change_state(State.TRAVEL)
	save_progress()
	return true

func is_active() -> bool:
	return state in [State.TRAVEL, State.COMBAT]

func ratio(kind: String) -> float:
	return db.ratio(stage, distance / float(db.levels[stage - 1].length), kind)

func is_boss_encounter() -> bool:
	# group_index points to the next encounter after spawn_group increments it.
	return group_index > 0 and group_index == db.levels[stage - 1].groups.size()

func spawn_group(keep_distance := false) -> void:
	guard_engaged = true
	var encounter: Dictionary = db.levels[stage - 1].groups[group_index]
	if not keep_distance:
		distance = float(encounter.position) * float(db.levels[stage - 1].length)
	group_index += 1
	if profile.loop and stage == int(profile.guardStage) and group_index == guard_index+1:
		guard_arrived = true
		distance = maxf(distance, float(profile.guardDistance))
		profile.guardDistance = distance
	enemies.clear()
	var slots: Array = db.groups[str(int(encounter.id))].slots
	for slot in range(slots.size()):
		if slots[slot] == null:
			continue
		var row: Dictionary = db.enemies[str(int(slots[slot]))]
		var enemy := row.duplicate(true)
		uid += 1
		enemy.uid = uid
		enemy.slot = slot
		enemy.x = 1130.0
		enemy.y = 198.0 + slot * 44.0
		enemy.hp = ceilf(float(row.health) * ratio("lifeRatio"))
		enemy.max_hp = enemy.hp
		enemy.res_ratio = ratio("resRatio")
		# Legacy hull flag controls drawing/weapon offsets, not stage completion.
		enemy.boss = float(row.size) > 1
		enemy.cooldowns = []
		for entry in row.equipment:
			enemy.cooldowns.append(float(db.enemy_weapon(entry.name).cd))
		enemies.append(enemy)
	if is_boss_encounter() and not profile.bossSeen.has(stage):
		profile.bossSeen.append(stage)
		save_progress()
	change_state(State.COMBAT)
	event.emit("encounter", {"boss":is_boss_encounter()})

func boss_info() -> String:
	if not profile.get("bossSeen", []).has(stage) and not profile.cleared.has(stage):
		return "？？？"
	var descriptions: Array[String] = []
	var encounters: Array = db.levels[stage - 1].groups
	if encounters.is_empty():
		return "？？？"
	for id in db.groups[str(int(encounters.back().id))].slots:
		if id == null:
			continue
		var row: Dictionary = db.enemies[str(int(id))]
		if not descriptions.has(str(row.des)):
			descriptions.append(str(row.des))
	return " / ".join(descriptions) if not descriptions.is_empty() else "？？？"

func targets(damage_type: int = 0) -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for e in enemies:
		if e.hp > 0:
			alive.append(e)
	alive.sort_custom(func(a,b):
		if damage_type != 0:
			var a_resists := int(a.armourType) == damage_type
			var b_resists := int(b.armourType) == damage_type
			if a_resists != b_resists:
				return not a_resists
		if a.x != b.x:
			return a.x < b.x
		var ac := absf(float(a.slot) - 4.5)
		var bc := absf(float(b.slot) - 4.5)
		return ac < bc if ac != bc else a.slot < b.slot)
	return alive

func reduced_damage(raw: float, type: int, resistance: int) -> float:
	return maxf(1, ceilf(raw * (1.0 - float(db.config.dmgReduce) if type == resistance else 1.0)))

func enemy_weapon_offset(enemy: Dictionary, equipment_index: int) -> Vector2:
	var key: String = enemy.equipment[equipment_index].name
	var count := 0
	var ordinal := 0
	for i in range(enemy.equipment.size()):
		if enemy.equipment[i].name == key:
			if i < equipment_index:
				ordinal += 1
			count += 1
	var visuals = preload("res://scripts/ship_visuals.gd")
	var dimensions: Vector2 = visuals.CANVAS * visuals.enemy_scale_for(enemy)
	# fire() adds -45; compensate so all sizes launch from their left hull edge.
	var launch_x := 45.0 - dimensions.x * 0.45
	if count <= 1:
		return Vector2(launch_x,0)
	# Spread identical mounts across the visible hull, including its wings.
	var half_span := dimensions.y * 0.3
	return Vector2(launch_x, lerpf(-half_span, half_span, float(ordinal) / float(count - 1)))

func player_weapon_offset(index: int) -> Vector2:
	var visuals = preload("res://scripts/ship_visuals.gd")
	return visuals.muzzle(str(profile.selectedShip), index) * visuals.scale_for(db.ship(str(profile.selectedShip)))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw: float, hostile: bool, key: String, offset := Vector2.ZERO) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + (-45 if hostile else 0) + offset.x,"y":float(source.y) + offset.y, "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*float(db.defaults.projectilePixelsPerUnit),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	shot.direction = Vector2(target.x - shot.x, target.y - shot.y).normalized()
	event.emit("fire", {"x":shot.x,"y":shot.y,"type":int(weapon.dmgtype)})

func missile_target(candidates: Array[Dictionary]) -> Dictionary:
	for candidate in candidates:
		var occupied := false
		for other in projectiles:
			if other.hostile or other.key != "missile" or other.target.is_empty():
				continue
			if int(other.target.uid) == int(candidate.uid):
				occupied = true
				break
		if not occupied:
			return candidate
	return candidates[0] if not candidates.is_empty() else {}

func hit_player(raw: float, type: int) -> void:
	since_hit = 0
	var rest := raw
	var shield_loss := 0.0
	var armour_loss := 0.0
	if player.shield > 0:
		var factor := 1.0 - float(db.config.dmgReduce) if type == int(db.equip("shield", 1).dmgtype) else 1.0
		shield_loss = minf(player.shield, reduced_damage(raw, type, int(db.equip("shield", 1).dmgtype)))
		player.shield = maxf(0, player.shield - shield_loss)
		rest = maxf(0, raw - shield_loss / factor)
	if rest > 0:
		armour_loss = reduced_damage(rest, type, int(db.equip("armour", 1).dmgtype))
		player.armour = maxf(0, player.armour - armour_loss)
	event.emit("hit", {"x":player.x,"y":player.y,"amount":ceilf(shield_loss + armour_loss),"player":true,"type":type})
	if player.armour <= 0:
		event.emit("explode", {"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func begin_retreat() -> void:
	guard_arrived = false
	guard_elapsed = 0
	guard_engaged = false
	if int(profile.get("guardDeath", 0)) == 0:
		profile.loop = false
	var original_stage := stage
	retreat_boss_pending = false
	retreat_from = distance
	retreat_target = distance - float(db.config.backRange)
	while retreat_target < 0 and stage > 1:
		stage -= 1
		var previous_length := float(db.levels[stage - 1].length)
		retreat_target += previous_length
		retreat_from += previous_length
	retreat_target = maxf(0, retreat_target)
	retreat_elapsed = 0
	enemies.clear()
	cooldowns.clear()
	group_index = 0
	var level: Dictionary = db.levels[stage - 1]
	while group_index < level.groups.size() and float(level.groups[group_index].position)*float(level.length) < retreat_target - 0.001:
		group_index += 1
	if stage < original_stage and group_index == level.groups.size() and group_index > 0:
		group_index -= 1
		retreat_boss_pending = true
	change_state(State.RETREAT)
	event.emit("retreat", {"from":retreat_from,"to":retreat_target})
	save_progress()

func acknowledge_unlocks() -> void:
	pending_unlocks.clear()
	event.emit("state", {"state":state})

func hit_enemy(enemy: Dictionary, raw: float, type: int) -> void:
	if enemy.hp <= 0:
		return
	var amount := reduced_damage(raw, type, int(enemy.armourType))
	enemy.hp = maxf(0, enemy.hp - amount)
	event.emit("hit", {"x":enemy.x,"y":enemy.y,"amount":amount,"player":false,"type":type})
	if enemy.hp <= 0:
		if is_boss_encounter() and targets().is_empty():
			projectiles.clear()
		event.emit("explode", enemy)
		for drop in enemy.drops:
			if rng.randf() < float(drop.chance):
				uid += 1
				var multiplier := charge_multiplier("熔炼器充能") if int(drop.resourceId) == 1 else 1.0
				drops.append({"uid":uid,"x":enemy.x - 40,"y":enemy.y,"age":0.0,"id":str(int(drop.resourceId)),"amount":ceilf(float(drop.amount)*float(enemy.res_ratio)*multiplier)})

func collect(drop: Dictionary, manual: bool) -> void:
	if not drops.has(drop):
		return
	if drop.get("hightech", false) and not manual:
		return
	drops.erase(drop)
	# Auto-collection loss is a separate calculation on the integer drop amount.
	var amount := ceilf(float(drop.amount) * (1.0 if manual else 1.0 - float(db.config.autoCollectReduce)))
	profile.resources[drop.id] += amount
	resource_samples.append({"time":Time.get_unix_time_from_system(),"id":str(drop.id),"amount":amount,"origin":"furnace" if drop.get("hightech",false) else "drop"})
	profile.furnaceIncomePeak = furnace_income_peak()
	run_resources[drop.id] += amount
	var info := drop.duplicate()
	info.amount = amount
	info.manual = manual
	event.emit("collect", info)
	save_progress()

func settle_drops() -> void:
	for drop in drops.duplicate():
		collect(drop, false)

func collect_near(pos: Vector2, clicked := false) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		if drop.get("hightech", false) and not clicked:
			continue
		if Vector2(drop.x, drop.y).distance_to(pos) < 55:
			collect(drop, true)

func clear_level() -> void:
	var previous: Array = Array(profile.unlocked).duplicate()
	first_clear = not profile.cleared.has(stage)
	if first_clear:
		profile.cleared.append(stage)
	rebuild_unlocks()
	for key in profile.unlocked:
		if not previous.has(key):
			pending_unlocks.append(key)
	clear_timer = float(db.defaults.loopDelay)
	change_state(State.LEVEL_CLEAR)
	save_progress()
	if not pending_unlocks.is_empty():
		event.emit("unlock", {"equipment":pending_unlocks.duplicate()})

func upgrade_cost_for_level(key: String, level: int) -> Dictionary:
	var next := db.equip(key, level)
	var cost := {}
	if next.is_empty():
		return cost
	for field in next:
		if str(field).begins_with("res_") and next[field] != null:
			var suffix := str(field).trim_prefix("res_")
			var amount = next.get("cost_" + suffix)
			if amount != null:
				cost[str(int(next[field]))] = ceilf(float(amount))
	return cost

func upgrade_cost(key: String, levels := 1) -> Dictionary:
	var entry := first_equipment_entry(key)
	var current := int(entry.level) if not entry.is_empty() else 1
	return upgrade_cost_for_level(key, current + 1) if levels == 1 else upgrade_costs_for_level(key, current, levels)

func upgrade_costs(key: String, levels: int) -> Dictionary:
	var entry := first_equipment_entry(key)
	var current := int(entry.level) if not entry.is_empty() else 1
	return upgrade_costs_for_level(key, current, levels)

func can_upgrade_amount(key: String, levels: int) -> bool:
	var entry := first_equipment_entry(key)
	if entry.is_empty():
		return false
	return can_upgrade_slot("weapons" if WEAPON_KEYS.has(key) else "defence", (weapon_entries() if WEAPON_KEYS.has(key) else defense_entries()).find(entry), levels)

func can_upgrade(key: String, levels := 1) -> bool:
	return can_upgrade_amount(key, levels)

func max_upgrade_amount(key: String) -> int:
	var entry := first_equipment_entry(key)
	if entry.is_empty():
		return 0
	return max_upgrade_amount_slot("weapons" if WEAPON_KEYS.has(key) else "defence", (weapon_entries() if WEAPON_KEYS.has(key) else defense_entries()).find(entry))

func max_upgrade_amount_slot(category: String, index: int) -> int:
	var entry := slot_entry(category,index)
	var key := str(entry.get("key", ""))
	if entry.is_empty() or key.is_empty() or not EQUIPMENT.has(key) or not profile.unlocked.has(key):
		return 0
	var available: Dictionary = profile.resources.duplicate()
	var amount := 0
	var current := int(entry.level)
	for level in range(current + 1, db.max_equipment_level(key) + 1):
		var costs := upgrade_cost_for_level(key, level)
		var affordable := true
		for id in costs:
			if float(available.get(id, 0)) < float(costs[id]):
				affordable = false
				break
		if not affordable:
			break
		for id in costs:
			available[id] = float(available.get(id, 0)) - float(costs[id])
		amount += 1
	return amount

func upgrade(key: String, levels := 1) -> bool:
	var category := "weapons" if WEAPON_KEYS.has(key) else "defence"
	var entries := weapon_entries() if category == "weapons" else defense_entries()
	var index := -1
	for i in range(entries.size()):
		if str(entries[i].key) == key:
			index = i
			break
	return upgrade_slot(category, index, levels)

func upgrade_slot(category: String, index: int, levels := 1) -> bool:
	if not can_upgrade_slot(category, index, levels):
		return false
	var entry := slot_entry(category, index)
	var key := str(entry.key)
	var costs := slot_upgrade_cost(category, index, levels)
	for id in costs:
		profile.resources[id] -= costs[id]
	var before := equipment_stat(key, int(entry.level))
	profile.loadout[category][index].level = int(entry.level) + levels
	var after := equipment_stat(key, int(profile.loadout[category][index].level))
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if key == "armour" and state != State.RETREAT:
		player.armour += after - before
	elif key == "shield" and state != State.RETREAT:
		player.shield += after - before
	save_progress()
	event.emit("upgrade", {"key":key,"slot":slot_id(category,index),"levels":levels,"cost":costs})
	return true

func upgrade_max(key: String) -> bool:
	var levels := max_upgrade_amount(key)
	return levels > 0 and upgrade(key, levels)

func leave(next: State) -> void:
	settle_drops()
	projectiles.clear()
	enemies.clear()
	paused = false
	change_state(next)

func tick(dt: float) -> void:
	if paused:
		return
	advance_auto_gen(dt)
	advance_charge(dt)
	if charge_resources_dirty:
		charge_resources_dirty = false
		save_progress()
	advance_hightech(dt, dt / maxf(speed, 0.001))
	hightech_save_elapsed += dt / maxf(speed, 0.001)
	if hightech_save_elapsed >= 5.0:
		hightech_save_elapsed = 0
		save_progress()
	for drop in drops.duplicate():
		if drop.get("hightech", false) or drop.get("auto_gen", false):
			continue
		drop.age += dt
		if drop.age >= float(db.defaults.autoCollectDelay):
			collect(drop, false)
	if state == State.LEVEL_CLEAR:
		tick_projectiles(dt)
		if state != State.LEVEL_CLEAR:
			return
		if not pending_unlocks.is_empty():
			return
		clear_timer -= dt
		if clear_timer <= 0:
			if guarding_here():
				respawn_guard()
			else:
				advance_after_clear()
		return
	if state == State.RETREAT:
		tick_projectiles(dt)
		retreat_elapsed += dt
		var duration := float(db.defaults.get("deathRetreatDuration", 1.2))
		distance = lerpf(retreat_from, retreat_target, clampf(retreat_elapsed / duration, 0, 1))
		if retreat_elapsed >= duration:
			distance = retreat_target
			reset_player()
			change_state(State.TRAVEL)
			if profile.loop and int(profile.get("guardDeath", 0)) == 2:
				guard_index = mini(group_index, db.levels[stage-1].groups.size()-1)
				profile.guardStage = stage
				profile.guardIndex = guard_index
				profile.guardDistance = distance
				resume_guard()
				save_progress()
		return
	if not is_active():
		return
	since_hit += dt
	var shield_entry := first_equipment_entry("shield")
	var shield := db.equip("shield", int(shield_entry.level)) if not shield_entry.is_empty() else db.equip("shield", 1)
	if since_hit >= float(shield.para3):
		player.shield = minf(max_shield(), player.shield + max_shield() * float(shield.para2) * dt)
	if state == State.TRAVEL:
		tick_projectiles(dt)
		if state != State.TRAVEL:
			return
		if retreat_boss_pending:
			retreat_boss_pending = false
			spawn_group(true)
			return
		distance += ship_movement() * dt
		var level: Dictionary = db.levels[stage - 1]
		if group_index < level.groups.size() and distance >= float(level.groups[group_index].position)*float(level.length):
			spawn_group()
		return
	for index in range(weapon_entries().size()):
		var entry: Dictionary = weapon_entries()[index]
		var key := str(entry.key)
		if key.is_empty():
			continue
		var weapon := db.equip(key, int(entry.level))
		if float(weapon.cd) <= 0:
			continue
		var id := slot_id("weapons", index)
		var remaining := float(cooldowns.get(id, float(weapon.cd)))
		cooldowns[id] = maxf(0, remaining - dt)
		if cooldowns[id] <= 0:
			var candidates := targets(int(weapon.dmgtype))
			var count := int(weapon.para1) if key == "missile" else 1
			for i in range(count):
				if candidates.is_empty():
					break
				var target := candidates[i % candidates.size()] if key == "missile" else candidates[0]
				var launch_offset := Vector2.ZERO
				if key == "missile" and count > 1:
					# Keep the volley inside its pod instead of outside the hull.
					launch_offset.y = (float(i) / float(count - 1) - 0.5) * preload("res://scripts/ship_visuals.gd").module_width(str(profile.selectedShip)) * preload("res://scripts/ship_visuals.gd").scale_for(db.ship(str(profile.selectedShip))) * 0.2
				fire(player, target, weapon, equipment_stat(key, int(entry.level)), false, key, launch_offset + player_weapon_offset(index))
			if count > 0 and not candidates.is_empty():
				cooldowns[id] = float(weapon.cd)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for i in range(enemy.equipment.size()):
			enemy.cooldowns[i] -= dt
			if enemy.cooldowns[i] <= 0:
				var entry: Dictionary = enemy.equipment[i]
				var weapon := db.enemy_weapon(entry.name)
				var raw := ceilf(float(weapon.dmg) * float(enemy.dmgMultiple) * ratio("atkRatio"))
				fire(enemy, player, weapon, raw, true, entry.name, enemy_weapon_offset(enemy, i))
				enemy.cooldowns[i] = float(weapon.cd)
	tick_projectiles(dt)
	if state == State.COMBAT and targets().is_empty():
		if guarding_here():
			if guard_engaged and is_boss_encounter():
				guard_engaged = false
				projectiles.clear()
				clear_level()
				clear_timer = guard_interval()
				return
			guard_elapsed += dt
			if guard_elapsed >= guard_interval():
				respawn_guard()
			return
		if is_boss_encounter():
			projectiles.clear()
			clear_level()
		else:
			change_state(State.TRAVEL)
			event.emit("wave_clear", {})
	elif state == State.COMBAT:
		guard_elapsed = 0

func tick_projectiles(dt: float) -> void:
	for shot in projectiles.duplicate():
		if not shot.target.is_empty():
			var target_dead: bool = shot.target.armour <= 0 if shot.hostile else shot.target.hp <= 0 or not enemies.has(shot.target)
			if target_dead:
				var candidates: Array[Dictionary] = []
				if not shot.hostile and shot.key == "missile":
					candidates = targets(int(shot.type))
					shot.target = missile_target(candidates)
				else:
					shot.target = {}
		if not shot.target.is_empty():
			var delta := Vector2(shot.target.x - shot.x, shot.target.y - shot.y)
			shot.direction = delta.normalized()
			if delta.length() <= shot.speed*dt:
				shot.dead = true
				if shot.hostile:
					hit_player(shot.damage, shot.type)
				else:
					hit_enemy(shot.target, shot.damage, shot.type)
					# Final-group defeat clears the live array; skip its stale snapshot.
					if projectiles.is_empty():
						return
				continue
		var move: Vector2 = shot.direction * float(shot.speed) * dt
		shot.x += move.x
		shot.y += move.y
		# Include the rendered trail before removing an off-screen projectile.
		if shot.x < -32 or shot.x > 1472 or shot.y < -32 or shot.y > 842:
			shot.dead = true
	projectiles = projectiles.filter(func(p): return not p.dead)
