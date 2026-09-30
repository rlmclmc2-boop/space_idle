class_name BattleGame
extends RefCounted

const CLEAR_ADVANCE_DELAY := 3.0

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon", "longLaser"]
const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 3
const N = preload("res://scripts/growth_number.gd")
var planet_buildings := preload("res://scripts/planet_buildings.gd").new()
var planet_buffs := preload("res://scripts/planet_buffs.gd").new()
var galaxy := preload("res://scripts/galaxy_system.gd").new()
const JEWEL_CAPACITY := 200
const FURNACE := "超时空炼铁炉"
const JEWEL_FURNACE := "宝石熔炼炉"
const ENERGY_FOCUS := "正电子聚焦装置"
const DENSE_ARMOUR := "简并态装甲"
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const HIGHTECH_SLOTS_PER_PAGE := 3
const HIGHTECH_MIN_SLOTS := 6
const WEAPON_KEYS := ["laser", "missile", "cannon", "longLaser"]
const DEFENSE_KEYS := ["armour", "shield"]
const BATTLE_SIZE := Vector2(572,696)
const PLAYER_POSITION := Vector2(286,520)
const ENEMY_LINE_LEFT := 66.0
const ENEMY_LINE_SPACING := 440.0 / 9.0
const ENEMY_LINE_Y := 140.0

static func enemy_slot_position(slot: int) -> Vector2:
	return Vector2(ENEMY_LINE_LEFT + float(slot) * ENEMY_LINE_SPACING,ENEMY_LINE_Y)
var db: ShipDatabase
var profile: Dictionary
var crew := preload("res://scripts/crew_system.gd").new()
# Synchronous upgrade sweep only; released before returning to the game loop.
var _upgrade_batch := false
var _upgrade_slots: Array = []
var _upgrade_costs: Dictionary = {}
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
var projectile_serial := 0
var save_enabled := true
var stat_cache_enabled := false
var stat_cache: Dictionary = {}
var jewel_defence_capacity_cache: Dictionary = {}
var login_chrono_particles := 0.0
var pending_unlocks: Array[String] = []
var retreat_from := 0.0
var retreat_target := 0.0
var retreat_elapsed := 0.0
var retreat_boss_pending := false
var rng := RandomNumberGenerator.new()
var hightech_save_elapsed := 0.0
var resource_samples: Array[Dictionary] = []
var auto_gen_elapsed := 0.0
var save_dirty := false
var planet_crew_payout_active := false
var frame_save_batch_active := false
var frame_save_requested := false
var jewel_repeats: Array[Dictionary] = []
var jewel_defence_times: Dictionary = {}
var jewel_defence_damage: Dictionary = {}
var jewel_charged: Dictionary = {}
var jewel_serial := 0
var jewel_bulk_combining := false
# Preserves damage fraction while a capacity temporarily becomes zero during refit.
var refit_health_ratios := {"armour":1.0,"shield":1.0}

# Overridden only by the isolated Debug simulator. Live games retain wall time.
func economy_time() -> float:
	return Time.get_unix_time_from_system()

func _init(database: ShipDatabase, persist := true) -> void:
	db = database
	speed = default_speed()
	save_enabled = persist
	stat_cache_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	galaxy.load_state(self,{})
	crew.load_state(self, [])
	load_planets({})
	profile.hightechOrder = hightech_slots()
	if persist:
		load_progress()
		save_progress()
	reset_player()

func fresh_profile() -> Dictionary:
	var selected := first_ship()
	var profile := {"version":SAVE_VERSION, "highestLevel":1, "cleared":[], "bossSeen":[], "resources":{"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))}, "unlocked":str(db.config.startEquip).split(","), "loop":false, "selectedShip":selected, "loadout":{}, "moduleVersion":1, "hightechLevels":{}, "hightechVersion":2, "scientists":0, "scientistAssignments":{}, "techPoints":{}, "hightechSavedAt":Time.get_unix_time_from_system(), "furnaceElapsed":0.0, "furnaceIncomePeak":0.0}
	# Initial availability also belongs to unlock; startEquip only selects loadout.
	profile.unlocked = EQUIPMENT.filter(func(key):return db.unlock_level(key) == 0)
	var starting: Array = Array(str(db.config.startEquip).split(",")).filter(func(key):return profile.unlocked.has(key))
	profile.loadout = default_loadout(selected, starting)
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":false, "dismissed":false}
	profile.jewels = []
	profile.lifetime_max_stage = 1
	profile.seenUnlocks = []
	profile.jewelFragments = 0.0
	profile.jewelFurnaceElapsed = 0.0
	profile.jewelFurnaceIncomePeak = 0.0
	profile.chronoParticles = 0.0
	profile.reactorLevel = int(db.config.reactorInitialLevel)
	profile.reactorAllocation = {}
	for key in reactor_modules():profile.reactorAllocation[key] = 0
	return profile

func first_ship() -> String:
	return str(db.ships.keys()[0]) if not db.ships.is_empty() else "Frigate"

func ship_unlocked(key: String) -> bool:
	return not db.ship(key).is_empty() and content_unlocked("ship", key)

func unlock_available(id: String) -> bool:
	var row: Dictionary = db.data.get("unlock", {}).get(id, {})
	if row.get("type", "") == "planet" and not planet_buffs.allows_planet(self, str(row.target)):return false
	return unlock_condition_available(id)

func unlock_condition_available(id: String) -> bool:
	var row: Dictionary = db.data.get("unlock", {}).get(id, {})
	if row.is_empty():return false
	if profile.get("grantedUnlocks", []).has(id):return true
	if row.get("type")=="feature" and row.get("target")=="galaxy":
		var definitions: Array=db.data.get("galaxy",{}).values()
		if definitions.is_empty() or not definitions.any(func(definition):return definition.unlock_type=="conquered_planet_count" and galaxy.conquered(self)>=int(definition.unlock_value)):return false
	var gate := int(row.level)
	if gate == 0:return true
	# Reached-mode preserves the former highestLevel semantics, including gaps.
	if row.get("mode", "cleared") == "reached":
		return int(profile.highestLevel) > gate
	return profile.cleared.has(gate)

func content_unlocked(kind: String, key: String) -> bool:
	return unlock_available(db.unlock_id(kind, key))

func granted_unlocks() -> Array[String]:
	# Keep earned level conditions through reforge even while conquest is pending.
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		if unlock_condition_available(str(id)):result.append(str(id))
	return result

func available_unlocks() -> Array[String]:
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		if unlock_available(str(id)):result.append(str(id))
	return result

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
	invalidate_stat_cache()
	login_chrono_particles = 0.0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not raw is Dictionary or int(raw.get("version",0)) not in [2,SAVE_VERSION]:
		return
	# Legacy identities are accepted only at the save migration boundary.
	if int(raw.get("version",0))<3:
		raw = migrate_planet_ids(raw)
	# Old saves remain quiet; fresh profiles alone opt into first-session guidance.
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":true, "dismissed":false}
	if raw.get("onboarding") is Dictionary:
		for key in ["intro", "equipped", "upgraded", "completed", "dismissed"]:
			profile.onboarding[key] = raw.onboarding.get(key, false) == true
	profile.lifetime_max_stage = int(raw.get("lifetime_max_stage",raw.get("highestLevel",1)))
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
		if N.valid(value):
			profile.resources[id] = N.ceiling(value)
	profile.loop = false
	var death_mode = raw.get("guardDeath", 0)
	profile.guardDeath = int(death_mode) if (death_mode is int or death_mode is float) and death_mode == int(death_mode) and int(death_mode) in [0,1,2] else 0
	profile.grantedUnlocks = []
	if raw.get("grantedUnlocks") is Array:
		for id in raw.grantedUnlocks:
			if id is String and db.data.get("unlock", {}).has(id) and not profile.grantedUnlocks.has(id):
				profile.grantedUnlocks.append(id)
	# Older saves explicitly owned equipment; retain it even if gates are edited.
	if raw.get("unlocked") is Array:
		for key in raw.unlocked:
			if key is String and EQUIPMENT.has(key):
				var id := db.unlock_id("equipment", key)
				if not id.is_empty() and not profile.grantedUnlocks.has(id):profile.grantedUnlocks.append(id)
	rebuild_unlocks()
	load_journey(raw.get("journey", {}))
	# Old saves knew ownership but not notification history. Preserve their pending
	# pages; all other previously owned unlocks have already been experienced.
	var seen_source = raw.get("seenUnlocks", available_unlocks().filter(func(key):return not profile.get("journey",{}).get("pendingUnlocks",[]).has(key)))
	if seen_source is Array:
		for key in seen_source:
			if key is String and not profile.seenUnlocks.has(key):profile.seenUnlocks.append(key)
	if profile.has("journey"):
		profile.journey.pendingUnlocks = profile.journey.get("pendingUnlocks",[]).filter(func(key):return not profile.seenUnlocks.has(key))
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
	# Legacy name levels migrate once. Module saves use their own slot levels exclusively.
	if int(raw.get("moduleVersion",0)) < 1:
		for key in EQUIPMENT:
			var entry := first_equipment_entry(key)
			var value = raw.get("levels", {}).get(key, 1) if raw.get("levels") is Dictionary else 1
			if not entry.is_empty():
				entry.level = clampi(int(value),1,db.max_equipment_level(key)) if value is float or value is int else 1
	profile.moduleVersion = 1
	load_jewels(raw)
	load_hightech(raw)
	profile.hightechOrder = hightech_slots()
	galaxy.load_state(self,raw.get("galaxies",{}) if raw.get("galaxies",{}) is Dictionary else {})
	crew.load_state(self, raw.get("crew", []))
	load_reactor(raw)
	load_planets(raw.get("planets", {}))
	galaxy.refresh_unlocks(self)
	var particles = raw.get("chronoParticles", 0)
	profile.chronoParticles = minf(float(particles), chrono_capacity()) if nonnegative_number(particles) else 0.0
	login_chrono_particles = accrue_chrono_particles(raw.get("chronoSavedAt"), Time.get_unix_time_from_system())
	generate_jewels()

func load_journey(value) -> void:
	if not value is Dictionary:
		return
	for key in ["stage", "groupIndex", "state"]:
		if not nonnegative_number(value.get(key)) or float(value[key]) != floorf(float(value[key])):
			return
	if value.stage < 1 or value.stage > profile.highestLevel:
		return
	var level: Dictionary = db.levels[int(value.stage)-1]
	if not nonnegative_number(value.get("distance")) or value.distance > float(level.length) or value.groupIndex > level.groups.size():
		return
	if not int(value.state) in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR, State.RETREAT]:
		return
	if int(value.state) == State.COMBAT and value.groupIndex == 0:
		return
	if int(value.state) == State.LEVEL_CLEAR and (value.groupIndex != level.groups.size() or not profile.cleared.has(int(value.stage))):
		return
	profile.journey = {"stage":int(value.stage), "groupIndex":int(value.groupIndex), "distance":float(value.distance), "state":int(value.state), "guardArrived":value.get("guardArrived") == true, "retreatBossPending":value.get("retreatBossPending") == true}
	profile.journey.pendingUnlocks = []
	if value.get("pendingUnlocks") is Array:
		for key in value.pendingUnlocks:
			if key is String and unlock_available(key) and not profile.journey.pendingUnlocks.has(key):
				profile.journey.pendingUnlocks.append(key)

func resume_progress() -> void:
	var checkpoint: Dictionary = profile.get("journey", {})
	profile.erase("journey")
	if not checkpoint.is_empty():
		start(int(checkpoint.stage), bool(profile.loop), checkpoint)
	else:
		# Old saves retain their previous startup and guard behavior.
		start(int(profile.guardStage) if profile.loop else int(profile.highestLevel), bool(profile.loop))
		if profile.loop:
			resume_guard()
			save_progress()

func chrono_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for item in str(db.config.chronoSpeeds).split(","):
		var fields := item.split("|")
		if fields.size() != 2 or not fields[0].is_valid_float() or not fields[1].is_valid_float():
			continue
		var multiplier := float(fields[0])
		var cost := float(fields[1])
		if is_finite(multiplier) and multiplier > 0 and is_finite(cost) and cost >= 0:
			options.append({"multiplier":multiplier,"cost":cost})
	return options

func default_speed() -> float:
	return float(db.config.chronoDefaultSpeed)

func chrono_cost(multiplier: float) -> float:
	for option in chrono_options():
		if is_equal_approx(float(option.multiplier), multiplier):
			return float(option.cost)
	return -1.0

func set_speed(multiplier: float) -> bool:
	var cost := chrono_cost(multiplier)
	if cost < 0 or (cost > 0 and float(profile.chronoParticles) <= 0):
		return false
	speed = multiplier
	return true

func chrono_capacity() -> float:
	return float(db.config.offlineMax) * 3600.0 * float(db.config.chronoParticlesPerSecond)

func accrue_chrono_particles(saved_at: Variant, now: float) -> float:
	if not nonnegative_number(saved_at):
		return 0.0
	var seconds := clampf(floorf(now - float(saved_at)), 0.0, float(db.config.offlineMax) * 3600.0)
	var earned := maxf(0.0, floorf(seconds * float(db.config.chronoParticlesPerSecond)))
	var available := maxf(0.0, floorf(chrono_capacity() - float(profile.chronoParticles)))
	var gained := minf(earned, available)
	profile.chronoParticles = minf(chrono_capacity(), float(profile.chronoParticles) + gained)
	return gained

func chrono_affordable_seconds(real_dt: float) -> float:
	var cost := chrono_cost(speed)
	if cost < 0:
		speed = default_speed()
		return real_dt
	if cost == 0:
		return real_dt
	var affordable := minf(real_dt, float(profile.chronoParticles) / cost)
	profile.chronoParticles = maxf(0.0, float(profile.chronoParticles) - affordable * cost)
	return affordable

func nonnegative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func load_hightech(raw: Dictionary) -> void:
	invalidate_stat_cache()
	raw = raw.duplicate(true)
	if int(raw.get("hightechVersion",0)) != 2:
		for field in ["hightechLevels","hightechResearch","scientists","scientistAssignments","techPoints","furnaceElapsed","jewelFurnaceElapsed","hightechDrops"]:
			raw.erase(field)
	if raw.get("hightechOrder") is Array:
		profile.hightechOrder = raw.hightechOrder.filter(func(key):return key is String)
	for field in ["hightechSavedAt", "furnaceElapsed", "jewelFurnaceElapsed", "furnaceIncomePeak", "jewelFurnaceIncomePeak"]:
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
			if sample is Dictionary and nonnegative_number(sample.get("time")) and N.valid(sample.get("amount")) and str(sample.get("id", "")) in ["1", "2", "jewel"] and float(sample.time) <= float(profile.hightechSavedAt) and float(sample.time) > float(profile.hightechSavedAt) - 60.0:
				# Legacy samples have no reliable source; keep totals but exclude them
				# from furnace input until this short rolling window expires.
				resource_samples.append({"time":float(sample.time), "amount":sample.amount, "production_base":sample.get("production_base",sample.amount), "id":str(sample.id), "origin":str(sample.get("origin", "unknown"))})
	profile.furnaceIncomePeak = furnace_income_peak(float(profile.hightechSavedAt))
	profile.jewelFurnaceIncomePeak = furnace_income_peak(float(profile.hightechSavedAt),true)
	if raw.get("hightechDrops") is Array:
		for drop in raw.hightechDrops:
			if drop is Dictionary and nonnegative_number(drop.get("age")) and float(drop.age) < 10 and nonnegative_number(drop.get("amount")) and nonnegative_number(drop.get("x")) and nonnegative_number(drop.get("y")):
				var id := str(drop.get("id","1"))
				if id not in ["1","jewel"]:
					continue
				uid += 1
				var drop_x := float(drop.x)
				var drop_y := float(drop.y)
				if drop_x>BATTLE_SIZE.x:
					var old_x := drop_x
					drop_x=lerpf(70,BATTLE_SIZE.x-70,clampf((drop_y-300.0)/205.0,0,1))
					drop_y=lerpf(250,480,clampf((old_x-440.0)/780.0,0,1))
				var restored := {"uid":uid,"x":clampf(drop_x,30,BATTLE_SIZE.x-30),"y":clampf(drop_y,80,BATTLE_SIZE.y-80),"age":float(drop.age),"id":id,"amount":ceilf(float(drop.amount)),"hightech":true}
				if id == "jewel":
					restored.jewel = true
					restored.jewelRatio = 1.0
				drops.append(restored)

func rebuild_unlocks() -> void:
	profile.highestLevel = 1
	for n in profile.cleared:
		profile.highestLevel = mini(db.levels.size(), maxi(profile.highestLevel, int(n) + 1))
	profile.lifetime_max_stage = maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	profile.grantedUnlocks = granted_unlocks()
	for key in EQUIPMENT:
		if content_unlocked("equipment", key) and not profile.unlocked.has(key):
			profile.unlocked.append(key)
	if not ship_unlocked(str(profile.get("selectedShip", first_ship()))):
		profile.selectedShip = first_ship()
	ensure_loadout()
	profile.hightechOrder = hightech_slots()

func ensure_loadout() -> void:
	invalidate_stat_cache()
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
		for i in range(maxi(count,entries.size())):
			var entry = entries[i] if i < entries.size() and entries[i] is Dictionary else (base[category][i] if i<count else {"key":"","level":1})
			var equip_key := str(entry.get("key", "")) if entry is Dictionary else ""
			var level := int(entry.get("level", 1)) if entry is Dictionary and (entry.get("level", 1) is int or entry.get("level", 1) is float) else 1
			if not equip_key.is_empty() and (not allowed.has(equip_key) or not profile.unlocked.has(equip_key)):
				equip_key = ""
			var normalized_entry := {"key":equip_key, "level":clampi(level, 1, 2147483647)}
			for field in ["sockets", "attacks", "hits"]:
				if entry.has(field):
					normalized_entry[field] = entry[field]
			normalized.append(normalized_entry)
		profile.loadout[category] = normalized

func begin_frame_save_batch() -> void:
	frame_save_batch_active = true

func end_frame_save_batch() -> void:
	frame_save_batch_active = false
	if frame_save_requested:
		frame_save_requested = false
		save_progress()

func save_progress() -> void:
	save_dirty = true
	if not save_enabled:
		return
	if frame_save_batch_active and not jewel_bulk_combining:
		frame_save_requested = true
		return
	profile.hightechOrder = hightech_slots()
	profile.hightechSavedAt = Time.get_unix_time_from_system()
	prune_resource_samples(float(profile.hightechSavedAt))
	profile.resourceSamples = resource_samples
	profile.chronoSavedAt = float(profile.hightechSavedAt)
	profile.hightechDrops = drops.filter(func(drop):return drop.get("hightech", false))
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		event.emit("save_error", {})
		return
	# Compatibility projection only; never install name-based levels in runtime.
	var saved := profile.duplicate()
	saved.galaxies=galaxy.save_data()
	saved.grantedUnlocks = granted_unlocks()
	if state in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR, State.RETREAT]:
		# Retreat resumes at its destination, never at the defeated encounter.
		saved.journey = {"stage":stage, "distance":retreat_target if state == State.RETREAT else distance, "groupIndex":group_index, "state":int(state), "guardArrived":guard_arrived, "retreatBossPending":retreat_boss_pending}
		saved.journey.pendingUnlocks = pending_unlocks.duplicate()
	saved.jewels = profile.jewels.map(func(gem):return {"id":gem.id,"level":gem.level})
	saved.loadout = profile.loadout.duplicate(true)
	for category in ["weapons", "defence"]:
		for entry in saved.loadout[category]:
			for gem in entry.get("sockets", []):
				gem.erase("token")
	saved.levels = {}
	for key in EQUIPMENT:
		saved.levels[key] = int(first_equipment_entry(key).get("level", 1))
	file.store_string(JSON.stringify(saved, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		event.emit("save_error", {})
	else:
		save_dirty = false
		if frame_save_batch_active:frame_save_requested = false

func first_equipment_entry(key: String) -> Dictionary:
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
			if str(entry.get("key", "")) == key:
				return entry
	return {}

func module_entries(category: String) -> Array:
	return profile.loadout.get(category, [])

func active_slot_count(category: String, ship_key := "") -> int:
	return int(db.ship(str(profile.selectedShip) if ship_key.is_empty() else ship_key).get("weaponSlots" if category=="weapons" else "defenseSlots",0)) if category in ["weapons","defence"] else 0

func module_entry(category: String, index: int) -> Dictionary:
	var entries := module_entries(category)
	return entries[index] if index>=0 and index<entries.size() else {}

func loadout_entries(category: String) -> Array:
	# Active view contains references to authoritative modules, never copies of entries.
	return module_entries(category).slice(0,active_slot_count(category))

func module_cost_key(category: String) -> String:
	# Current same-category cost curves are identical; modules retain that existing curve.
	return "laser" if category=="weapons" else "armour"


func weapon_entries() -> Array:
	return loadout_entries("weapons")

func defense_entries() -> Array:
	return loadout_entries("defence")

func stat(key: String) -> Variant:
	if stat_cache_enabled and stat_cache.has(key):
		return stat_cache[key]
	var total = 0.0
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
			if str(entry.get("key", "")) == key:
				total = N.add(total,jewel_equipment_stat(entry))
	if stat_cache_enabled:
		stat_cache[key] = total
	return total

func invalidate_stat_cache() -> void:
	stat_cache.clear()
	jewel_defence_capacity_cache.clear()

func invalidate_equipment_counter(key: String) -> void:
	# Attack/hit counters change only this equipment type's proficiency/adaptation.
	# They do not alter planets, research, crew or the other defence capacity.
	stat_cache.erase(key)
	jewel_defence_capacity_cache.erase(key)

func ship_movement() -> float:
	return float(db.ship(str(profile.get("selectedShip", first_ship()))).get("movement", db.config.movement))

func ship_name() -> String:
	return UIText.data_text("ship",str(profile.get("selectedShip",first_ship())),"des")

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
	return {} if entry.is_empty() else upgrade_costs_for_level(module_cost_key(category), int(entry.level), levels)

func upgrade_costs_for_level(key: String, current: int, levels: int) -> Dictionary:
	var total := {}
	if levels <= 0 or current + levels > db.max_equipment_level(key):
		return total
	for level in range(current + 1, current + levels + 1):
		var cost := upgrade_cost_for_level(key, level)
		for id in cost:
			total[id] = float(total.get(id, 0)) + float(cost[id])
	return total

func can_upgrade_slot(category: String, index: int, levels := 1) -> bool:
	var entry := slot_entry(category, index)
	if entry.is_empty() or levels<1:
		return false
	var costs := slot_upgrade_cost(category, index, levels)
	if costs.is_empty():
		return false
	for id in costs:
		if not is_finite(float(costs[id])) or N.compare(profile.resources.get(id,0),costs[id])<0:
			return false
	return true

func refund_equipment(key: String, level: int) -> void:
	for target_level in range(2, level + 1):
		for id in upgrade_cost_for_level(key, target_level):
			profile.resources[id] = N.add(profile.resources.get(id,0),upgrade_cost_for_level(key,target_level)[id])

func equipment_limit() -> int:
	return maxi(active_slot_count("weapons"),active_slot_count("defence")) # Compatibility: only physical capacity remains.

func equipment_count(key: String) -> int:
	var count := 0
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
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
	return true

func capture_refit_health() -> void:
	for key in ["armour","shield"]:
		var maximum = stat(key)
		if N.compare(maximum,0)>0 and player.has(key):
			refit_health_ratios[key] = clampf(N.ratio(player[key],maximum),0,1)

func apply_refit_health() -> void:
	for key in ["armour","shield"]:
		if player.has(key):player[key] = N.multiply(stat(key),float(refit_health_ratios[key]))
	jewel_defence_damage.clear()
	sync_jewel_defence_damage()

func invalidate_module_attack(index: int) -> void:
	jewel_repeats = jewel_repeats.filter(func(p):return int(p.index)!=index)
	jewel_charged.erase(slot_id("weapons",index))
	for shot in projectiles:
		if shot.get("beam",false) and not shot.hostile and int(shot.mount)==index:shot.dead=true
	var entry := slot_entry("weapons",index)
	if entry.is_empty() or str(entry.key).is_empty():
		cooldowns.erase(slot_id("weapons",index))
	else:
		cooldowns[slot_id("weapons",index)] = float(db.equip(str(entry.key),int(entry.level)).cd)

func equip_slot(category: String, index: int, key: String) -> bool:
	if category not in ["weapons","defence"]:return false
	var allowed: Array = WEAPON_KEYS if category=="weapons" else DEFENSE_KEYS
	var entry := slot_entry(category,index)
	if entry.is_empty() or not allowed.has(key) or not profile.unlocked.has(key):return false
	if str(entry.key)==key:return true
	capture_refit_health()
	# Replace the entry reference to invalidate old beams/repeats, keeping module assets.
	var module := entry.duplicate(true)
	module.key = key
	profile.loadout[category][index] = module
	invalidate_stat_cache()
	if category=="weapons":invalidate_module_attack(index)
	apply_refit_health()
	save_progress()
	event.emit("module_changed",{"slot":slot_id(category,index)})
	return true

func unequip_slot(category: String, index: int) -> bool:
	var entry := slot_entry(category,index)
	if entry.is_empty() or str(entry.key).is_empty():return false
	capture_refit_health()
	var module := entry.duplicate(true)
	module.key = ""
	profile.loadout[category][index] = module
	invalidate_stat_cache()
	if category=="weapons":invalidate_module_attack(index)
	apply_refit_health()
	save_progress()
	event.emit("module_changed",{"slot":slot_id(category,index)})
	return true

func refund_all_equipment() -> void:
	# Retained for explicit legacy callers; normal refit never refunds module growth.
	for category in ["weapons","defence"]:
		for entry in loadout_entries(category):
			if not str(entry.key).is_empty():refund_equipment(str(entry.key),int(entry.level))

func switch_ship(key: String, selected_loadout: Dictionary = {}) -> bool:
	if key==str(profile.selectedShip) or not ship_unlocked(key):return false
	if not selected_loadout.is_empty() and not valid_loadout(key,selected_loadout):return false
	capture_refit_health()
	var old_weapon_count := active_slot_count("weapons")
	profile.selectedShip = key
	invalidate_stat_cache()
	for category in ["weapons","defence"]:
		var entries := module_entries(category)
		while entries.size()<active_slot_count(category):entries.append({"key":"","level":1})
		if not selected_loadout.is_empty():
			for index in active_slot_count(category):
				var requested: String = selected_loadout[category][index].key
				if str(entries[index].key)!=requested:
					entries[index] = entries[index].duplicate(true)
					entries[index].key = requested
					if category=="weapons":invalidate_module_attack(index)
	for index in range(mini(old_weapon_count,active_slot_count("weapons")),maxi(old_weapon_count,active_slot_count("weapons"))):invalidate_module_attack(index)
	apply_refit_health()
	save_progress()
	event.emit("ship_changed",{"key":key})
	return true

func permanent_modifiers() -> Dictionary:
	# Same lifetime as the other stat projections: refits, unlocks, research,
	# planet progress and crew changes invalidate them before dependent reads.
	if not stat_cache_enabled:return planet_buffs.totals(self)
	if not stat_cache.has("planet_modifiers"):
		stat_cache.planet_modifiers = planet_buffs.totals(self)
	return stat_cache.planet_modifiers

func equipment_level_bonus() -> int:
	return int(permanent_modifiers().equipment_level_bonus)

func hightech_level_bonus() -> int:
	return int(permanent_modifiers().hightech_level_bonus)

func charge_free_ratio() -> float:
	return float(permanent_modifiers().charge_free_ratio)

func gem_drop_level_bonus() -> int:
	return int(permanent_modifiers().gem_drop_level_bonus)

func effective_equipment_level(actual: int) -> int:
	return actual+equipment_level_bonus()

func effective_hightech_level(key: String) -> int:
	return hightech_level(key)+hightech_level_bonus() if hightech_unlocked(key) else 0

func permanent_level_text(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else hightech_level_bonus()
	return UIText.t("planet.level_with_bonus",{"actual":actual,"bonus":bonus}) if bonus!=0 else str(actual)

func permanent_level_tooltip(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else hightech_level_bonus()
	return UIText.t("planet.level_tooltip",{"actual":actual,"bonus":bonus,"effective":actual+bonus}) if bonus!=0 else ""

func equipment_stat(key: String, level: int) -> float:
	# Base equipment values exclude attack/hit counters. Retain their projection
	# across volleys; full stat invalidation covers every modifier/level change.
	var bases: Dictionary = stat_cache.get("equipment_bases",{}) if stat_cache_enabled else {}
	var levels: Dictionary = bases.get(key,{})
	if levels.has(level):return levels[level]
	# Only the ordinary damage/capacity projection reads the effective level.
	var row := db.equip(key, effective_equipment_level(level))
	var value := float(row.para1 if key in ["armour", "shield"] else row.dmg)
	var tech := DENSE_ARMOUR if key in ["armour", "shield"] else ENERGY_FOCUS
	if effective_hightech_level(tech) > 0:
		value = ceilf(value * pow(1.0 + float(db.data.hightech[tech].para1),effective_hightech_level(tech)))
	var reactor_bonus := reactor_multiplier("defence" if key in ["armour", "shield"] else "weapons")
	if reactor_bonus != 1.0:
		value = ceilf(value * reactor_bonus)
	if stat_cache_enabled:
		# Bound previews as well as equipped modules; reads never retain entries.
		if levels.size()>=32:levels.clear()
		levels[level]=value
		bases[key]=levels
		stat_cache.equipment_bases=bases
	return value

func reactor_modules() -> PackedStringArray:
	return str(db.config.reactorModules).split(",",false)

func reactor_module_unlocked(key: String) -> bool:
	if not reactor_modules().has(key):return false
	var gate := db.unlock_id("reactor_module",key)
	return gate.is_empty() or unlock_available(gate)

func reactor_available_modules() -> PackedStringArray:
	return PackedStringArray(Array(reactor_modules()).filter(func(key):return reactor_module_unlocked(key)))

func reactor_unlocked() -> bool:
	return content_unlocked("feature", "reactor")

func reactor_energy(level := -1) -> float:
	var actual := int(profile.reactorLevel) if level < 0 else level
	return float(db.config.reactorEnergyBase) * pow(float(db.config.reactorEnergyGrowth), actual - 1) * crew.system_effect(self,"charge_bonus") * galaxy.multiplier("charge_max")

func reactor_capacity() -> int:
	return maxi(0, int(floor(reactor_energy())))

func reactor_upgrade_cost(level := -1) -> float:
	var actual := int(profile.reactorLevel) if level < 0 else level
	return float(db.config.reactorUpgradeBase) * pow(float(db.config.reactorUpgradeGrowth), actual - 1)

func reactor_allocated() -> int:
	var total := 0
	for key in reactor_modules():total += int(profile.reactorAllocation.get(key,0))
	return total

func reactor_effective_ratio(key: String) -> float:
	if not reactor_unlocked() or not reactor_module_unlocked(key):return 0.0
	return float(profile.reactorAllocation.get(key,0))/maxf(1.0,reactor_capacity())+charge_free_ratio()

func reactor_multiplier(key: String) -> float:
	if not reactor_module_unlocked(key):return 1.0
	var allocation := float(profile.reactorAllocation.get(key,0))
	if reactor_unlocked():allocation+=float(reactor_capacity())*charge_free_ratio()
	return 1.0 + pow(float(allocation),float(db.config.reactorBoostExponent)) / float(db.config.reactorPercentScale) if allocation > 0 else 1.0

func reactor_max_upgrades() -> int:
	var budget = profile.resources.get(str(int(db.config.reactorUraniumId)),0)
	var level := int(profile.reactorLevel)
	var count := 0
	while true:
		var cost := reactor_upgrade_cost(level)
		if not is_finite(cost) or cost <= 0 or N.compare(cost,budget)>0:break
		budget = N.subtract(budget,cost)
		level += 1
		count += 1
	return count

func upgrade_reactor(amount: int) -> bool:
	if not reactor_unlocked() or amount <= 0:return false
	var budget = profile.resources.get(str(int(db.config.reactorUraniumId)),0)
	var total := 0.0
	for offset in amount:
		var cost := reactor_upgrade_cost(int(profile.reactorLevel)+offset)
		if not is_finite(cost) or cost <= 0 or N.compare(N.add(total,cost),budget)>0:return false
		total += cost
	profile.resources[str(int(db.config.reactorUraniumId))] = N.subtract(budget,total)
	profile.reactorLevel += amount
	save_progress()
	event.emit("reactor_changed", {"level":profile.reactorLevel,"cost":total})
	return true

func set_reactor_allocation(key: String, value: float) -> bool:
	if not reactor_unlocked() or not reactor_module_unlocked(key) or not is_finite(value):return false
	var allowed := maxi(0,reactor_capacity() - reactor_allocated() + int(profile.reactorAllocation.get(key,0)))
	var next := clampi(int(floor(value)),0,allowed)
	if next == int(profile.reactorAllocation.get(key,0)):return false
	profile.reactorAllocation[key] = next
	invalidate_stat_cache()
	if key == "defence":
		player.armour = N.minimum(player.armour,stat("armour"))
		player.shield = N.minimum(player.shield,stat("shield"))
		event.emit("equipment_stats",{"category":"defence"})
	elif key == "weapons":event.emit("equipment_stats",{"category":"weapons"})
	save_progress()
	event.emit("reactor_changed", {"module":key})
	return true

func equalize_reactor_allocation() -> bool:
	if not reactor_unlocked():return false
	var modules := reactor_available_modules()
	if modules.is_empty():return false
	var share := reactor_capacity()/modules.size()
	var remainder := reactor_capacity()%modules.size()
	var changed := false
	for index in modules.size():
		var key := modules[index]
		var allocation := share + (1 if index < remainder else 0)
		if int(profile.reactorAllocation.get(key,0)) != allocation:changed = true
		profile.reactorAllocation[key] = allocation
	if not changed:return false
	invalidate_stat_cache()
	player.armour = N.minimum(player.armour,stat("armour"))
	player.shield = N.minimum(player.shield,stat("shield"))
	save_progress()
	event.emit("equipment_stats",{"category":"weapons"})
	event.emit("equipment_stats",{"category":"defence"})
	event.emit("reactor_changed", {"equalized":true})
	return true

func load_reactor(raw: Dictionary) -> void:
	invalidate_stat_cache()
	var level = raw.get("reactorLevel")
	if nonnegative_number(level) and level == floorf(float(level)) and level >= int(db.config.reactorInitialLevel):profile.reactorLevel = int(level)
	var saved = raw.get("reactorAllocation")
	if not saved is Dictionary:return
	for key in reactor_modules():profile.reactorAllocation[key] = 0
	for key in reactor_modules():
		var value = saved.get(key)
		if reactor_module_unlocked(key) and nonnegative_number(value):profile.reactorAllocation[key] = mini(int(floor(float(value))),maxi(0,reactor_capacity()-reactor_allocated()))

func hightech_level(key: String) -> int:
	return int(profile.get("hightechLevels", {}).get(key, 0))

func hightech_unlocked(key: String) -> bool:
	if not db.data.get("hightech", {}).has(key):
		return false
	return content_unlocked("hightech", key)

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
	var level := hightech_level(key)
	var cost := float(row.tpCostBase) * (1.0 + float(row.tpCostMutiple) * level)
	var threshold := int(db.config.hightechCostGrowthLevel)
	if level > threshold:
		cost *= pow(1.0 + float(row.tpCostMutiple2), level - threshold)
	return roundf(cost)

func description_number(value) -> String:
	if value is Dictionary:return N.text(value)
	# Formula literals must retain float precision; compact notation is for the final text only.
	return "%.1f" % value if absf(value)>=9e18 else NUMBER_FORMAT.precise(value)

func hightech_description(key: String, now := -1.0) -> String:
	if effective_hightech_level(key)==0:
		return UIText.t("system.hightech_description.text_01")
	var row: Dictionary = db.data.hightech[key]
	if key == JEWEL_FURNACE:
		var peak := furnace_income_peak(now,true)
		return ui_description(UIText.data_key("hightech",key,"description"),row,effective_hightech_level(key),peak,peak)
	return ui_description(UIText.data_key("hightech",key,"description"),row,effective_hightech_level(key),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now,true))

func ui_description(text_key: String, row: Dictionary, level: int, minute_income = 0.0, excluded_income = 0.0) -> String:
	var values := {}
	var formulas := UIText.formulas(text_key)
	for i in formulas.size():
		values["effect_%d" % (i+1)] = format_description(row,str(formulas[i]),level,minute_income,excluded_income)
	return UIText.t(text_key,values)

func format_description(row: Dictionary, template: String, level: int, minute_income = 0.0, excluded_income = 0.0) -> String:
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
	var numeric_literal := "(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
	numbers.compile(numeric_literal)
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
		for income_token in ["过去一分钟的铁生成量","过去一分钟的宝石碎片生成量"]:
			formula = formula.replace(income_token,description_number(excluded_income if options.has("不含自身") else minute_income))
		formula = formula.replace("等级",str(level)).replace("lv",str(level)).replace("（","(").replace("）",")")
		var replacement := "？"
		var expression := Expression.new()
		# Expression otherwise uses integer division for literals such as 1/2.
		var literals := numbers.search_all(formula)
		literals.reverse()
		for literal in literals:
			if not literal.get_string().contains(".") and not literal.get_string().to_lower().contains("e"):
				formula = formula.substr(0,literal.get_end()) + ".0" + formula.substr(literal.get_end())
		# Remove complete numeric tokens before checking operators; arbitrary identifiers remain rejected.
		var numeric_only := allowed.search(numbers.sub(formula,"0",true)) != null
		var power := RegEx.new()
		power.compile("(\\([^()^]*\\)|"+numeric_literal+")\\s*\\^\\s*("+numeric_literal+")")
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
			if not is_finite(float(costs[id])) or N.compare(N.add(total.get(id,0),costs[id]),profile.resources.get(id,0))>0:
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
		profile.resources[id] = N.subtract(profile.resources[id],purchase.costs[id])
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

func add_crew_exp(crew_id: String, amount: float) -> bool:
	return crew.gain_exp(self,crew_id,amount)

func planet_row(id: String) -> Dictionary:
	return db.data.get("planet", {}).get(id, {})

func planet_unlocked(id: String) -> bool:
	var row := planet_row(id)
	return not row.is_empty() and planet_buffs.allows_planet(self, id) and unlock_available(str(row.get("unlockId", "")))

func planet_progress(id: String) -> Dictionary:
	return profile.get("planets", {}).get(id, {})

func crew_exploration(crew_id: String) -> String:
	return planet_buildings.occupied(self,crew_id)

func planet_duration(id: String) -> float:
	return planet_duration_from(planet_row(id), planet_progress(id).get("degree", 0))

func planet_exp_multiplier() -> float:
	var level := clampi(maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel)), 1, db.levels.size())
	return float(db.levels[level - 1].get("planetExpRatio", 0)) if level > 0 else 0.0

func planet_exp_reward(id: String) -> float:
	if not crew.levels_unlocked(self):return 0.0
	return roundf(float(planet_row(id).get("baseExp", 0)) * planet_exp_multiplier() * galaxy.multiplier("crew_exp"))

func planet_equipment_multiplier() -> Variant:
	if not stat_cache_enabled:return planet_buildings.multiplier(self,"equipment")
	if not stat_cache.has("planet_equipment"):
		stat_cache.planet_equipment = planet_buildings.multiplier(self,"equipment")
	return stat_cache.planet_equipment

func planet_resource_multiplier() -> Variant:
	if not stat_cache_enabled:return planet_buildings.multiplier(self,"refinery")
	if not stat_cache.has("planet_refinery"):
		stat_cache.planet_refinery = planet_buildings.multiplier(self,"refinery")
	return stat_cache.planet_refinery

func migrate_planet_ids(raw: Dictionary) -> Dictionary:
	var migrated := raw.duplicate(true)
	var aliases := {"first":"1"}
	var planets: Dictionary = migrated.get("planets",{}) if migrated.get("planets") is Dictionary else {}
	for old in aliases:
		if planets.has(old):
			if not planets.has(aliases[old]):planets[aliases[old]]=planets[old]
			planets.erase(old)
	for field in ["grantedUnlocks"]:
		if migrated.get(field) is Array:
			for i in migrated[field].size():
				if migrated[field][i]=="planet/first":migrated[field][i]="planet/1"
	if migrated.get("journey") is Dictionary and migrated.journey.get("pendingUnlocks") is Array:
		for i in migrated.journey.pendingUnlocks.size():
			if migrated.journey.pendingUnlocks[i]=="planet/first":migrated.journey.pendingUnlocks[i]="planet/1"
	migrated.planets=planets
	migrated.version=SAVE_VERSION
	return migrated

func load_planets(raw) -> void:
	invalidate_stat_cache()
	profile.planets = {}
	var pending := {}
	for id in db.data.get("planet", {}):
		var item = raw.get(id, {}) if raw is Dictionary else {}
		if not item is Dictionary:item = {}
		var progress: Dictionary = item.duplicate(true)
		progress.degree = item.get("degree",0) if N.valid(item.get("degree",0)) else 0.0
		progress.unlocked = item.get("unlocked",false)==true or unlock_available(str(planet_row(str(id)).get("unlockId","")))
		progress.conquered = item.get("conquered",false)==true
		progress.auto_explore = item.get("auto_explore",false)==true
		progress.crewId = ""
		progress.elapsed = 0.0
		progress.buildings = item.get("buildings",{}).duplicate(true) if item.get("buildings") is Dictionary else {}
		for key in progress.buildings.keys():
			var building = progress.buildings[key]
			if not building is Dictionary:
				progress.buildings.erase(key)
				continue
			building.status = str(building.get("status","locked"))
			if building.status not in ["locked","building","ready","built"]:building.status="locked"
			building.build_progress = building.get("build_progress",0) if N.valid(building.get("build_progress",0)) else 0
			building.crew = []
		profile.planets[id] = progress
		pending[id] = item
		planet_buildings.sync(self,str(id))
	# Restore all occupation through a single capacity check; duplicates stay idle.
	for id in pending:
		var item: Dictionary=pending[id]
		var progress: Dictionary=profile.planets[id]
		var crew_id := str(item.get("crewId",""))
		if planet_unlocked(str(id)) and idle_planet_crew(crew_id):
			progress.crewId=crew_id
			progress.elapsed=minf(float(item.get("elapsed",0)),planet_duration(str(id))) if nonnegative_number(item.get("elapsed")) else 0.0
		for row in planet_buildings.rows(self,str(id)):
			var building: Dictionary=progress.buildings[str(row.id)]
			var old = item.get("buildings",{}).get(str(row.id),{}) if item.get("buildings") is Dictionary else {}
			if building.status!="building" or not old is Dictionary or not old.get("crew") is Array:continue
			for member_id in old.crew:
				if building.crew.size()<int(row.extra_crew) and idle_planet_crew(str(member_id)):building.crew.append(str(member_id))
		# Missing preference inherits the unlocked default; explicit false is a choice.
		if not item.has("auto_explore"):progress.auto_explore = planet_buildings.built(self,str(id),"auto_explore")
		# Keep the player's preference even when no crew/facility is available.
		# Actual continuation checks facility availability in advance_planets.

func idle_planet_crew(id: String) -> bool:
	var member := crew.entry(self,id)
	return not member.is_empty() and crew.unlocked(self,id) and str(member.assignmentType).is_empty() and crew_exploration(id).is_empty()

func planet_duration_from(row: Dictionary, degree) -> float:
	var base := float(row.get("baseTime",0))
	var minimum := float(row.get("minTime",5.0))
	if not is_finite(minimum) or minimum <= 0.0:minimum = 5.0
	return maxf(minimum,N.ratio(base*base,N.add(base,degree))) if base>0 else 0.0

func set_planet_auto(id: String, enabled: bool) -> bool:
	if not planet_buildings.built(self,id,"auto_explore"):return false
	profile.planets[id].auto_explore=enabled
	save_progress()
	event.emit("planet_changed",{"id":id})
	return true

func can_reforge_planet(id: String) -> bool:
	return planet_unlocked(id) and not planet_progress(id).get("conquered",false) and planet_buildings.built(self,id,"shipyard")

func planet_reforge_start(id: String) -> int:
	return clampi(int(planet_row(id).get("reforgeStartLevel",1)),1,maxi(1,db.levels.size()))

func reforge_planet(id: String) -> bool:
	if not can_reforge_planet(id):return false
	var start_level := planet_reforge_start(id)
	# Prepare the complete replacement before changing any authoritative state.
	var next := fresh_profile()
	next.crew = profile.crew.duplicate(true)
	next.crewEquipment = profile.get("crewEquipment",{}).duplicate(true)
	next.planets = profile.planets.duplicate(true)
	next.galaxies = profile.get("galaxies",{})
	next.grantedUnlocks = []
	next.seenUnlocks = profile.get("seenUnlocks",[]).duplicate()
	for gate_id in available_unlocks():
		var gate: Dictionary = db.data.unlock[gate_id]
		if not next.seenUnlocks.has(gate_id):next.seenUnlocks.append(gate_id)
		if int(gate.level)<=start_level or gate.type in ["crew","planet"] or (gate.type=="feature" and gate.target in ["crew_level","galaxy"]):next.grantedUnlocks.append(gate_id)
	for gate_id in granted_unlocks():
		if db.data.unlock[gate_id].type == "planet" and not next.grantedUnlocks.has(gate_id):next.grantedUnlocks.append(gate_id)
	# Skip earlier stages without granting combat income. Existing unlock rules
	# derive their availability from this new run's progression as usual.
	next.cleared = range(1,start_level)
	next.bossSeen = next.cleared.duplicate()
	for planet_id in next.planets:
		next.planets[planet_id].unlocked = planet_unlocked(str(planet_id))
		# Reforge keeps the planet's current exploration assignment and elapsed work.
		# The crew and planet progress are permanent state, so an in-flight trip
		# must continue after the run is rebuilt.
	next.planets[id].conquered=true
	next.lifetime_max_stage=maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	# Resources are not listed for deletion; preserve their balances.
	next.resources=profile.resources.duplicate(true)
	# Chrono particles are a persistent reserve, independent of run progress.
	next.chronoParticles=profile.chronoParticles
	profile=next
	crew.timers.clear()
	pending_unlocks.clear()
	resource_samples.clear()
	drops.clear()
	projectiles.clear()
	enemies.clear()
	speed=default_speed()
	auto_gen_elapsed=0.0
	hightech_save_elapsed=0.0
	rebuild_unlocks()
	reset_player()
	var persist := save_enabled
	save_enabled=false
	start(start_level,false)
	save_enabled=persist
	save_progress()
	event.emit("planet_reforged",{"id":id})
	return true

func start_planet_exploration(id: String, crew_id: String) -> bool:
	if not planet_unlocked(id) or planet_progress(id).is_empty() or not planet_progress(id).crewId.is_empty():return false
	if not idle_planet_crew(crew_id):return false
	planet_buildings.sync(self,id)
	profile.planets[id].unlocked=true
	profile.planets[id].crewId = crew_id
	profile.planets[id].elapsed = 0.0
	save_progress()
	event.emit("planet_changed", {"id":id, "crewId":crew_id})
	return true

func cancel_planet_exploration(id: String) -> bool:
	if planet_progress(id).is_empty() or str(planet_progress(id).crewId).is_empty():return false
	profile.planets[id].crewId = ""
	profile.planets[id].elapsed = 0.0
	save_progress()
	event.emit("planet_changed", {"id":id})
	return true

func advance_planets(dt: float) -> void:
	if dt <= 0:return
	for id in profile.planets:
		var progress: Dictionary = profile.planets[id]
		if str(progress.crewId).is_empty():continue
		progress.elapsed += dt
		if progress.elapsed < planet_duration(str(id)):continue
		var member_id := str(progress.crewId)
		planet_buildings.complete(self,str(id))
		progress.crewId = member_id if progress.get("auto_explore",false) and planet_buildings.built(self,str(id),"auto_explore") else ""
		progress.elapsed = 0.0
		invalidate_stat_cache()
		var reward := planet_exp_reward(str(id))
		# Persist the completed trip and its entire crew payout together.
		var persist := save_enabled
		save_enabled = false
		if reward > 0:
			planet_crew_payout_active = true
			if planet_buffs.shares_experience(self,str(id)):
				for member in profile.crew:add_crew_exp(str(member.crewId), reward)
			else:add_crew_exp(member_id, reward)
			planet_crew_payout_active = false
		save_enabled = persist
		save_progress()
		event.emit("planet_changed", {"id":id, "crewId":member_id, "reward":reward})

func assign_crew(crew_id: String, assignment_type: String, target_id: String) -> bool:
	return crew.assign(self,crew_id,assignment_type,target_id)

func get_crew_modifier(target_type: String, target_id: String, effect_type: String) -> float:
	return crew.get_modifier(self,target_type,target_id,effect_type)

func dedicated_scientists(key: String) -> int:
	return int(crew.system_effect(self,"tech_ai_per_level")) if hightech_unlocked(key) else 0

func research_rate(key: String, crew_effects: Dictionary = {}) -> float:
	if not hightech_unlocked(key):return 0.0
	# The caller may share these two read-only crew projections while collecting
	# rates. The dictionary never crosses a research event or a simulation step.
	if not crew_effects.has("tech_ai_per_level"):crew_effects.tech_ai_per_level=crew.system_effect(self,"tech_ai_per_level")
	var count := assigned_scientists(key)+int(crew_effects.tech_ai_per_level)
	if count <= 0:return 0.0
	var base := float(db.config.techPointGet)*count
	if not crew_effects.has("tech_speed"):crew_effects.tech_speed=crew.system_effect(self,"tech_speed")
	return (roundf(pow(base,float(db.config.hightechLimit))) if count > 1 else base) * float(crew_effects.tech_speed)

func active_research(rates: Dictionary = {}) -> Array:
	var active: Array = []
	var crew_effects: Dictionary = {}
	for key in db.data.hightech:
		var rate := research_rate(key,crew_effects)
		if not rate > 0:continue
		active.append(key)
		rates[key]=rate
	return active

func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
	if real_dt < 0:
		real_dt = dt
	if end_time < 0:
		end_time = economy_time()
	var wall_per_step := real_dt / dt if dt > 0 else 1.0
	var rates := {}
	var active := active_research(rates)
	# Huge point budgets cannot be settled one level/event at a time.
	# Ignore per-level rounding and use the configured cost series in this regime.
	var bulk := active.any(func(key):return float(profile.techPoints.get(key,0))+float(rates[key])*dt >= 1e20)
	if bulk:
		for key in active:
			advance_hightech_bulk(key,dt)
		# At this scale furnace output uses the end-of-step level (approximate).
		advance_furnace(dt,end_time,wall_per_step)
		return
	# Keep furnace activation at the exact research completion boundary.
	var remaining := maxf(dt,0)
	while remaining > 0:
		var step := remaining
		for key in active:
			step = minf(step,maxf(0,hightech_required(key)-float(profile.techPoints.get(key,0)))/float(rates[key]))
		advance_furnace(step,end_time-(remaining-step)*wall_per_step,wall_per_step)
		remaining -= step
		for key in active:
			profile.techPoints[key] = float(profile.techPoints.get(key,0))+float(rates[key])*step
			var required := hightech_required(key)
			if float(profile.techPoints[key])+0.00000001 >= required:
				profile.techPoints[key] = maxf(0,float(profile.techPoints[key])-required)
				profile.hightechLevels[key] = hightech_level(key)+1
				if key in [DENSE_ARMOUR, ENERGY_FOCUS]:invalidate_stat_cache()
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
	if float(row.tpCostMutiple2) > 0:
		# Binary search the monotone series, including ranges crossing the threshold.
		var low := 0
		var high := int(count)
		while low < high:
			var mid := low + ((high-low+1) >> 1)
			if hightech_bulk_cost(key,level,mid) <= points:
				low = mid
			else:
				high = mid-1
		count = float(low)
		spent = hightech_bulk_cost(key,level,low)
	profile.techPoints[key] = maxf(0,points-spent)
	if count > 0:
		profile.hightechLevels[key] = level+int(count)
		if key in [DENSE_ARMOUR, ENERGY_FOCUS]:invalidate_stat_cache()
		event.emit("hightech_complete", {"key":key})

func hightech_bulk_cost(key: String, level: int, count: int) -> float:
	# Bulk settlement retains the existing unrounded approximation at huge budgets.
	if count <= 0:return 0.0
	var row: Dictionary = db.data.hightech[key]
	var growth := float(row.tpCostBase)*float(row.tpCostMutiple)
	var threshold := int(db.config.hightechCostGrowthLevel)
	var linear_count := mini(count,maxi(0,threshold-level+1))
	var total := float(linear_count)*(float(row.tpCostBase)+growth*level+growth*(linear_count-1)*0.5)
	count -= linear_count
	level += linear_count
	if count == 0:return total
	var ratio := 1.0+float(row.tpCostMutiple2)
	var multiplier := pow(ratio,level-threshold)
	var block_cost := float(row.tpCostBase)+growth*level
	var block_growth := growth
	var block_length := 1.0
	var factor := ratio
	var offset := 0.0
	# Sum arithmetic-geometric blocks in O(log count), without cancellation near ratio=1.
	while count > 0:
		if not is_finite(multiplier) or not is_finite(block_cost):return INF
		if count & 1:
			total += multiplier*(block_cost+offset*block_growth)
			if not is_finite(total):return INF
			multiplier *= factor
			offset += block_length
		count >>= 1
		if count == 0:break
		block_cost = (1.0+factor)*block_cost+factor*block_length*block_growth
		block_growth *= 1.0+factor
		block_length *= 2.0
		factor *= factor
	return total

func prune_resource_samples(now: float) -> void:
	resource_samples = resource_samples.filter(func(sample):return float(sample.time) > now - 60.0)

func resource_minute_total(id: String, now := -1.0, exclude_furnace := false) -> Variant:
	if now < 0:
		now = economy_time()
	var total = 0.0
	for sample in resource_samples:
		if exclude_furnace and sample.get("origin", "drop") != "drop":
			continue
		if sample.id == id and float(sample.time) > now - 60.0 and float(sample.time) <= now:
			total = N.add(total,sample.get("production_base",sample.amount) if exclude_furnace else sample.amount)
	return total

func furnace_income_peak(now := -1.0, jewel := false) -> float:
	return maxf(float(profile.get("jewelFurnaceIncomePeak" if jewel else "furnaceIncomePeak",0.0)),float(resource_minute_total("jewel" if jewel else "1",now,true)))

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
		drop.y += float(drop.speed) * dt
		if drop.y >= float(player.y):
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
		drops.append({"uid":uid,"x":rng.randf_range(70.0,BATTLE_SIZE.x-70.0),"y":0.0,"age":0.0,"id":settings.resource_id,"amount":amount,"speed":settings.speed,"auto_gen":true})

func advance_furnace(dt: float, end_time: float, wall_per_step: float) -> void:
	for drop in drops.duplicate():
		if drop.get("hightech", false):
			drop.age += dt
			if float(drop.age) >= 10.0:
				collect(drop, false)
	for key in [FURNACE,JEWEL_FURNACE]:
		if effective_hightech_level(key) <= 0 or not db.data.get("hightech", {}).has(key):
			continue
		var jewel_furnace: bool = key == JEWEL_FURNACE
		var elapsed_field := "jewelFurnaceElapsed" if jewel_furnace else "furnaceElapsed"
		var row: Dictionary = db.data.hightech[key]
		var target_type := "smelting" if jewel_furnace else "production"
		var interval := float(row.para1) / (1.0 + crew.get_modifier(self,target_type,key,"SPEED"))
		if interval <= 0 or not is_finite(interval):
			continue
		var elapsed := float(profile.get(elapsed_field,0.0)) + dt
		var count := floorf(elapsed / interval)
		profile[elapsed_field] = fposmod(elapsed, interval)
		# Skip expired blocks, with work bounded by the 10-second visible window.
		var visible := mini(int(count), int(ceilf(10.0 / interval)))
		for i in range(visible):
			var age := float(profile[elapsed_field]) + i * interval
			if age >= 10.0:
				break
			uid += 1
			var produced_at := end_time - age * wall_per_step
			var income := furnace_income_peak(produced_at,jewel_furnace)
			profile["jewelFurnaceIncomePeak" if jewel_furnace else "furnaceIncomePeak"] = income
			var amount := ceilf(income * float(row.para2) * effective_hightech_level(key) * (1.0 + crew.get_modifier(self,target_type,key,"OUTPUT") + crew.get_modifier(self,target_type,key,"EFFICIENCY")))
			var block := {"uid":uid,"x":rng.randf_range(70,BATTLE_SIZE.x-70),"y":rng.randf_range(250,480),"age":age,"id":"jewel" if jewel_furnace else "1","amount":amount,"hightech":true}
			if jewel_furnace:
				block.jewel = true
				block.jewelRatio = 1.0
			drops.append(block)

func max_shield() -> Variant:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	invalidate_stat_cache()
	refit_health_ratios = {"armour":1.0,"shield":1.0}
	jewel_repeats.clear()
	jewel_defence_times.clear()
	jewel_defence_damage.clear()
	jewel_charged.clear()
	player = {"x":PLAYER_POSITION.x, "y":PLAYER_POSITION.y, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	if next != State.COMBAT:
		projectiles = projectiles.filter(func(p): return not p.get("beam", false))
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
	if level != stage and not profile.cleared.has(level):
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

func start(level: int, loop_mode: bool, checkpoint: Dictionary = {}) -> bool:
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
	if not checkpoint.is_empty():
		distance = float(checkpoint.distance)
		group_index = int(checkpoint.groupIndex)
		retreat_boss_pending = bool(checkpoint.retreatBossPending)
		if int(checkpoint.state) == State.LEVEL_CLEAR:
			guard_arrived = profile.loop and checkpoint.guardArrived and stage == int(profile.guardStage)
			clear_timer = guard_interval() if guarding_here() else CLEAR_ADVANCE_DELAY
			pending_unlocks.assign(checkpoint.get("pendingUnlocks", []))
			change_state(State.LEVEL_CLEAR)
		elif profile.loop and checkpoint.guardArrived and stage == int(profile.guardStage):
			resume_guard()
		elif int(checkpoint.state) == State.COMBAT:
			group_index -= 1
			spawn_group(true)
		elif int(checkpoint.state) == State.RETREAT:
			retreat_from = distance
			retreat_target = distance
			retreat_elapsed = 0
			change_state(State.RETREAT)
	save_progress()
	return true

func is_active() -> bool:
	return state in [State.TRAVEL, State.COMBAT]

func ratio(kind: String) -> float:
	return db.ratio(stage, maxi(0, group_index - 1), kind)

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
		var slot_position := enemy_slot_position(slot)
		enemy.x = slot_position.x
		enemy.y = slot_position.y
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
		return UIText.t("system.boss_info.text_01")
	var descriptions: Array[String] = []
	var encounters: Array = db.levels[stage - 1].groups
	if encounters.is_empty():
		return UIText.t("system.boss_info.text_01")
	for id in db.groups[str(int(encounters.back().id))].slots:
		if id == null:
			continue
		var row: Dictionary = db.enemies[str(int(id))]
		if not descriptions.has(UIText.data_text("enemies",str(int(id)),"des")):
			descriptions.append(UIText.data_text("enemies",str(int(id)),"des"))
	return " / ".join(descriptions) if not descriptions.is_empty() else UIText.t("system.boss_info.text_01")

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
		if a.y != b.y:
			return a.y > b.y
		var ac := absf(float(a.slot) - 4.5)
		var bc := absf(float(b.slot) - 4.5)
		return ac < bc if ac != bc else a.slot < b.slot)
	return alive

func has_alive_enemy() -> bool:
	for enemy in enemies:
		if enemy.hp > 0:
			return true
	return false

func reduced_damage(raw, type: int, resistance: int) -> Variant:
	return N.maximum(1, N.ceiling(N.multiply(raw,1.0 - float(db.config.dmgReduce) if type == resistance else 1.0)))

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
	# Enemy noses point down, toward the player.
	var launch_y := dimensions.x * 0.45
	if count <= 1:
		return Vector2(0,launch_y)
	# Spread identical mounts across the visible hull, including its wings.
	var half_span := dimensions.y * 0.3
	return Vector2(lerpf(-half_span, half_span, float(ordinal) / float(count - 1)),launch_y)

func player_weapon_offset(index: int) -> Vector2:
	var visuals = preload("res://scripts/ship_visuals.gd")
	return visuals.muzzle(str(profile.selectedShip), index).rotated(-PI/2) * visuals.scale_for(db.ship(str(profile.selectedShip)))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw, hostile: bool, key: String, offset := Vector2.ZERO, visual_spread := 0.0) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + offset.x,"y":float(source.y) + offset.y, "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*float(db.defaults.projectilePixelsPerUnit),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	projectile_serial += 1
	shot.serial = projectile_serial
	shot.direction = Vector2(0,1 if hostile else -1) if key.replace("_mon", "").replace("-mon", "") == "missile" else Vector2(target.x - shot.x, target.y - shot.y).normalized()
	event.emit("fire", {"x":shot.x,"y":shot.y,"type":int(weapon.dmgtype),"shot":shot,"spread":visual_spread})

# A beam is one persistent projectile per mount; timing belongs to that object.
func long_laser_valid(shot: Dictionary) -> bool:
	if state != State.COMBAT or shot.dead or shot.target.is_empty() or not is_same(shot.target, shot.locked_target):
		return false
	if shot.hostile:
		return enemies.has(shot.source) and shot.source.hp > 0 and is_same(shot.target, player) and N.compare(player.armour,0)>0 and shot.mount < shot.source.equipment.size() and is_same(shot.entry, shot.source.equipment[shot.mount])
	return is_same(shot.source, player) and N.compare(player.armour,0)>0 and enemies.has(shot.target) and shot.target.hp > 0 and is_same(shot.entry, slot_entry("weapons", shot.mount)) and shot.entry.key == "longLaser"

func lock_long_laser(source: Dictionary, weapon: Dictionary, hostile: bool, mount: int, entry: Dictionary, repeated := false, repeat_multiplier := 1.0) -> void:
	for shot in projectiles:
		if shot.get("beam", false) and shot.hostile == hostile and is_same(shot.source, source) and shot.mount == mount and bool(shot.get("repeated",false)) == repeated and long_laser_valid(shot):
			return
	var candidates: Array = targets(int(weapon.dmgtype)) if not hostile else []
	var target: Dictionary = player if hostile else (candidates[0] if not candidates.is_empty() else {})
	if not hostile:
		for candidate in candidates:
			if not projectiles.any(func(p):return p.get("beam",false) and not p.hostile and p.mount==mount and long_laser_valid(p) and is_same(p.target,candidate)):
				target = candidate
				break
	if target.is_empty() or float(weapon.cd) <= 0:
		return
	var offset := enemy_weapon_offset(source, mount) if hostile else player_weapon_offset(mount)
	if repeated:
		offset.x += 6.0
	fire(source, target, weapon, 0, hostile, "longLaser-mon" if hostile else "longLaser", offset)
	var shot: Dictionary = projectiles.back()
	shot.merge({"beam":true, "repeated":repeated, "repeat_multiplier":repeat_multiplier, "charged_multiplier":1.0, "locked_target":target, "source":source, "mount":mount, "entry":entry, "elapsed":0.0, "ticks":0, "weapon":weapon, "charge":maxf(0,float(weapon.para3)) if weapon.get("para3") != null else -1.0})
	if not hostile and not repeated:
		var id := slot_id("weapons",mount)
		shot.charged_multiplier = float(jewel_charged.get(id,1.0))
		jewel_charged.erase(id)
	event.emit("beam_started", {"shot":shot})

func long_laser_multiplier(weapon: Dictionary, duration: float) -> float:
	return minf(1.0 + (float(weapon.para2) - 1.0) * duration / float(weapon.para1), float(weapon.para2)) if float(weapon.para1) > 0 else float(weapon.para2)

func tick_long_laser(shot: Dictionary, dt: float) -> void:
	if not long_laser_valid(shot):
		shot.dead = true
		return
	var offset := enemy_weapon_offset(shot.source, shot.mount) if shot.hostile else player_weapon_offset(shot.mount)
	if shot.repeated:
		offset.x += 6.0
	shot.x = float(shot.source.x) + offset.x
	shot.y = float(shot.source.y) + offset.y
	shot.elapsed += dt
	var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else db.equip(shot.entry.key, int(shot.entry.level))
	# Use scheduled hit times, not frame end time, including when a step spans several hits.
	var interval := float(shot.weapon.cd)
	var first_hit := float(shot.charge) if float(shot.charge) >= 0 else interval
	while first_hit + int(shot.ticks) * interval <= float(shot.elapsed) + 0.000000001:
		shot.ticks += 1
		var duration := (int(shot.ticks)-1) * interval if float(shot.charge) >= 0 else int(shot.ticks) * interval
		var multiplier := long_laser_multiplier(weapon, duration)
		event.emit("beam_hit", {"shot":shot})
		if shot.hostile:
			var raw := ceilf(float(weapon.dmg) * float(shot.source.dmgMultiple) * ratio("atkRatio"))
			hit_player(raw * multiplier, int(weapon.dmgtype))
		else:
			shot.entry.attacks = int(shot.entry.get("attacks", 0)) + 1
			invalidate_equipment_counter(str(shot.entry.key))
			event.emit("equipment_stats",{"slot":slot_id("weapons",shot.mount)})
			var boost := float(shot.repeat_multiplier) * float(shot.charged_multiplier)
			if not shot.repeated and int(shot.ticks)==1:
				queue_jewel_repeats(shot.mount,1.0,shot)
			var attack := jewel_attack(shot.mount, multiplier * boost)
			if attack.critical:
				event.emit("critical_impact", {"pos":Vector2(shot.target.x,shot.target.y),"direction":Vector2(shot.target.x-shot.x,shot.target.y-shot.y).normalized()})
			hit_enemy(shot.target,attack.damage,int(weapon.dmgtype),attack.effects,attack.critical)
		if not projectiles.has(shot) or not long_laser_valid(shot):
			shot.dead = true
			break

func hit_player(raw, type: int) -> void:
	if has_defence_jewels():
		jewel_hit_player(raw, type)
		return
	since_hit = 0
	var rest = raw
	var shield_loss = 0.0
	var armour_loss = 0.0
	if N.compare(player.shield,0)>0:
		var factor = 1.0 - float(db.config.dmgReduce) if type == int(db.equip("shield", 1).dmgtype) else 1.0
		shield_loss = N.minimum(player.shield, reduced_damage(raw, type, int(db.equip("shield", 1).dmgtype)))
		player.shield = N.subtract(player.shield,shield_loss)
		rest = N.subtract(raw,N.divide(shield_loss,factor))
	if N.compare(rest,0)>0:
		armour_loss = reduced_damage(rest, type, int(db.equip("armour", 1).dmgtype))
		player.armour = N.subtract(player.armour,armour_loss)
	for entry in defense_entries():
		if (entry.key == "shield" and N.compare(shield_loss,0)>0) or (entry.key == "armour" and N.compare(armour_loss,0)>0):
			entry.hits = int(entry.get("hits", 0)) + 1
			invalidate_equipment_counter(str(entry.key))
			event.emit("equipment_stats",{"category":"defence"})
	event.emit("hit", {"x":player.x,"y":player.y,"amount":N.ceiling(N.add(shield_loss,armour_loss)),"player":true,"type":type})
	if N.compare(player.armour,0)<=0:
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
	# One page per item keeps simultaneous unlocks readable without dropping any.
	if not pending_unlocks.is_empty():
		var key: String = pending_unlocks.pop_front()
		if not profile.seenUnlocks.has(key):profile.seenUnlocks.append(key)
	save_progress()
	event.emit("state", {"state":state})

func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false) -> void:
	if enemy.hp <= 0:
		return
	jewel_on_hit(enemy, effects)
	var amount = reduced_damage(N.multiply(raw,1.0 + float(enemy.get("interference", 0))), type, int(enemy.armourType))
	enemy.hp = N.subtract(enemy.hp,amount)
	event.emit("hit", {"x":enemy.x,"y":enemy.y,"amount":amount,"player":false,"type":type,"uid":enemy.uid,"critical":critical})
	if enemy.hp <= 0:
		if is_boss_encounter() and targets().is_empty():
			projectiles.clear()
		event.emit("explode", enemy)
		jewel_kill_drop(enemy)
		for drop in enemy.drops:
			if rng.randf() < float(drop.chance):
				uid += 1
				var multiplier = reactor_multiplier("smelting") if int(drop.resourceId) == 1 else 1.0
				var base_amount = N.ceiling(N.multiply(N.multiply(drop.amount,float(enemy.res_ratio)*multiplier),1.0+float(enemy.get("jewelIron",0)) if int(drop.resourceId)==1 else 1.0))
				var drop_amount = N.ceiling(N.multiply(base_amount,planet_resource_multiplier())) if int(drop.resourceId) in [1,2] else base_amount
				drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+40,"source_uid":enemy.uid,"age":0.0,"id":str(int(drop.resourceId)),"amount":drop_amount,"production_base":base_amount})

		if float(enemy.get("jewelExplosion", 0)) > 0:
			for adjacent in enemies.duplicate():
				if adjacent.hp > 0 and abs(int(adjacent.slot) - int(enemy.slot)) in [1, 2]:
					hit_enemy(adjacent, float(enemy.max_hp) * float(enemy.jewelExplosion), type)

func collect(drop: Dictionary, manual: bool) -> void:
	if not drops.has(drop):
		return
	if drop.has("jewel"):
		if not jewels_unlocked():
			return
		var core: bool = drop.get("hightech",false)
		if core and not manual and float(drop.get("age",0)) < 10.0:
			return
		drops.erase(drop)
		var amount := float(drop.get("amount",1))
		if core and not manual:
			amount = ceilf(amount * (1.0 - float(db.config.autoCollectReduce)))
		drop.amount = settle_jewel_fragments(amount, "furnace" if core else "drop", 1.0 if core else float(drop.get("jewelRatio", jewel_ratio())))
		jewels_changed()
		event.emit("jewel_pickup", drop)
		return
	if drop.get("hightech", false) and not manual and float(drop.get("age",0)) < 10.0:
		return
	drops.erase(drop)
	# Auto-collection loss is a separate calculation on the integer drop amount.
	var amount = N.ceiling(N.multiply(drop.amount,1.0 if manual else 1.0 - float(db.config.autoCollectReduce)))
	profile.resources[drop.id] = N.add(profile.resources[drop.id],amount)
	resource_samples.append({"time":economy_time(),"id":str(drop.id),"amount":amount,"production_base":N.ceiling(N.multiply(drop.get("production_base",drop.amount),1.0 if manual else 1.0-float(db.config.autoCollectReduce))),"origin":"furnace" if drop.get("hightech",false) else "drop"})
	profile.furnaceIncomePeak = furnace_income_peak()
	run_resources[drop.id] = N.add(run_resources[drop.id],amount)
	var info := drop.duplicate()
	info.amount = amount
	info.manual = manual
	event.emit("collect", info)
	save_progress()

func settle_drops() -> void:
	for drop in drops.duplicate():
		collect(drop, false)

func collect_near(pos: Vector2, clicked := false, position_overrides: Dictionary = {}) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		var core: bool = drop.get("hightech",false) and drop.has("jewel")
		if (drop.get("hightech", false) or drop.has("jewel")) and not clicked and not core:
			continue
		var drop_pos: Vector2 = position_overrides.get(int(drop.uid),Vector2(drop.x,drop.y))
		if drop_pos.distance_to(pos) < 55:
			collect(drop, true)

func clear_level() -> void:
	var previous := available_unlocks()
	first_clear = not profile.cleared.has(stage)
	if first_clear:
		profile.cleared.append(stage)
	rebuild_unlocks()
	for key in available_unlocks():
		if not previous.has(key) and not profile.get("seenUnlocks",[]).has(key) and not pending_unlocks.has(key):
			pending_unlocks.append(key)
	clear_timer = CLEAR_ADVANCE_DELAY
	change_state(State.LEVEL_CLEAR)
	save_progress()
	if not pending_unlocks.is_empty():
		event.emit("unlock", {"items":pending_unlocks.duplicate(), "equipment":pending_unlocks.filter(func(id):return db.data.unlock[id].type == "equipment")})

func upgrade_cost_for_level(key: String, level: int) -> Dictionary:
	if _upgrade_batch and _upgrade_costs.get(key,{}).has(level):
		return _upgrade_costs[key][level]
	var cost := db.equipment_cost(key,level)
	if _upgrade_batch:
		if not _upgrade_costs.has(key):_upgrade_costs[key]={}
		_upgrade_costs[key][level]=cost
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
	var key := module_cost_key(category)
	if entry.is_empty():
		return 0
	var available: Dictionary = profile.resources.duplicate()
	var amount := 0
	var current := int(entry.level)
	var level := current + 1
	while level <= db.max_equipment_level(key):
		var costs := upgrade_cost_for_level(key, level)
		var affordable := true
		for id in costs:
			if not is_finite(float(costs[id])) or N.compare(available.get(id,0),costs[id])<0:
				affordable = false
				break
		if not affordable:
			break
		for id in costs:
			available[id] = N.subtract(available.get(id,0),costs[id])
		amount += 1
		level += 1
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
	var entry = slot_entry(category, index)
	var key = str(entry.key)
	var costs = slot_upgrade_cost(category, index, levels)
	for id in costs:
		profile.resources[id] = N.subtract(profile.resources[id],costs[id])
	var before = jewel_equipment_stat(entry)
	profile.loadout[category][index].level = int(entry.level) + levels
	invalidate_stat_cache()
	var after = jewel_equipment_stat(entry)
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if key == "armour" and state != State.RETREAT:
		player.armour = N.add(player.armour,N.subtract(after,before))
	elif key == "shield" and state != State.RETREAT:
		player.shield = N.add(player.shield,N.subtract(after,before))
	if _upgrade_batch:
		_upgrade_slots.append(slot_id(category,index))
	else:
		save_progress()
	event.emit("upgrade", {"key":key,"slot":slot_id(category,index),"levels":levels,"cost":costs,"batch":_upgrade_batch})
	return true

func upgrade_equipment_batch(mode: String) -> void:
	if _upgrade_batch:return
	_upgrade_batch=true
	for category in ["weapons","defence"]:
		for index in loadout_entries(category).size():
			var amount: int=max_upgrade_amount_slot(category,index) if mode=="max" else int(mode)
			if amount>0:upgrade_slot(category,index,amount)
	_upgrade_batch=false
	_upgrade_costs.clear()
	var changed := _upgrade_slots
	_upgrade_slots=[]
	if not changed.is_empty():
		save_progress()
		event.emit("upgrades_completed",{"slots":changed})

func upgrade_max(key: String) -> bool:
	var levels := max_upgrade_amount(key)
	return levels > 0 and upgrade(key, levels)

func leave(next: State) -> void:
	settle_drops()
	projectiles.clear()
	enemies.clear()
	paused = false
	change_state(next)

func weapon_cooldown_after_shot(remaining_before: float, dt: float, interval: float) -> float:
	if speed < 3.0 or interval <= 0:
		return interval
	# Coarse accelerated ticks retain the fraction elapsed after a scheduled shot.
	var overrun := maxf(0.0,dt-remaining_before)
	var remainder := fposmod(overrun,interval)
	return interval if remainder <= 0.000000001 else interval-remainder

func tick(dt: float) -> void:
	if paused:
		return
	advance_planets(dt)
	galaxy.advance(self,dt)
	crew.advance(self,dt)
	advance_auto_gen(dt)
	advance_hightech(dt, dt / maxf(speed, 0.001))
	hightech_save_elapsed += dt / maxf(speed, 0.001)
	if hightech_save_elapsed >= 5.0:
		hightech_save_elapsed = 0
		save_progress()
	for drop in drops.duplicate():
		if drop.get("hightech", false) or drop.get("auto_gen", false):
			continue
		drop.age += dt
		if drop.age >= (2.0 if drop.has("jewel") else float(db.defaults.autoCollectDelay)):
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
	var defence_jewels := advance_jewel_repair(dt)
	advance_jewel_repeats(dt)
	var shield_entry := first_equipment_entry("shield")
	var shield := db.equip("shield", int(shield_entry.level)) if not shield_entry.is_empty() else db.equip("shield", 1)
	if not defence_jewels and since_hit >= float(shield.para3):
		player.shield = N.minimum(max_shield(),N.add(player.shield,N.multiply(max_shield(),float(shield.para2)*dt)))
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
	projectiles = projectiles.filter(func(p): return not p.get("beam", false) or long_laser_valid(p))
	for index in range(weapon_entries().size()):
		var entry: Dictionary = weapon_entries()[index]
		var key := str(entry.key)
		if key.is_empty():
			continue
		var weapon := db.equip(key, int(entry.level))
		if float(weapon.cd) <= 0:
			continue
		if key == "longLaser":
			lock_long_laser(player, weapon, false, index, entry)
			continue
		var id := slot_id("weapons", index)
		var remaining := float(cooldowns.get(id, float(weapon.cd)))
		var cooldown_after_step := remaining-dt
		cooldowns[id] = maxf(0, cooldown_after_step)
		if cooldowns[id] <= 0:
			var candidates := targets(int(weapon.dmgtype))
			var count := int(weapon.para1) if key == "missile" else 1
			if not candidates.is_empty():
				entry.attacks = int(entry.get("attacks", 0)) + 1
				invalidate_equipment_counter(key)
				event.emit("equipment_stats",{"slot":id})
			var charged := float(jewel_charged.get(id, 1.0))
			if count > 0 and not candidates.is_empty():
				jewel_charged.erase(id)
			for i in range(count):
				if candidates.is_empty():
					break
				var target := candidates[i % candidates.size()] if key == "missile" else candidates[0]
				jewel_fire(index, target, weapon, player_weapon_offset(index), charged, missile_visual_spread(i,count) if key=="missile" else 0.0)
			if count > 0 and not candidates.is_empty():
				cooldowns[id] = weapon_cooldown_after_shot(remaining,dt,float(weapon.cd))
				queue_jewel_repeats(index, charged)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for i in range(enemy.equipment.size()):
			if str(enemy.equipment[i].name).replace("_mon", "").replace("-mon", "") == "longLaser":
				lock_long_laser(enemy, db.enemy_weapon(enemy.equipment[i].name), true, i, enemy.equipment[i])
				continue
			var cooldown_before := float(enemy.cooldowns[i])
			enemy.cooldowns[i] = maxf(0.0,cooldown_before-dt)
			if enemy.cooldowns[i] <= 0:
				var entry: Dictionary = enemy.equipment[i]
				var weapon := db.enemy_weapon(entry.name)
				var raw := ceilf(float(weapon.dmg) * float(enemy.dmgMultiple) * ratio("atkRatio"))
				fire(enemy, player, weapon, raw, true, entry.name, enemy_weapon_offset(enemy, i))
				enemy.cooldowns[i] = weapon_cooldown_after_shot(cooldown_before,dt,float(weapon.cd))
	tick_projectiles(dt)
	if state == State.COMBAT and not has_alive_enemy():
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
	var pending := projectiles.duplicate()
	for index in pending.size():
		var shot: Dictionary = pending[index]
		# Usually the live array retains its order for the whole step. Identity at
		# the snapshot index avoids a full membership scan for every flying shot.
		# Hits/signals may clear, replace or reorder it; retain the original check
		# whenever that position no longer holds this exact projectile.
		if (index>=projectiles.size() or not is_same(projectiles[index],shot)) and not projectiles.has(shot):
			continue
		if shot.get("beam", false):
			tick_long_laser(shot, dt)
			continue
		if not shot.target.is_empty():
			var target_dead: bool = N.compare(shot.target.armour,0)<=0 if shot.hostile else shot.target.hp <= 0 or not enemies.has(shot.target)
			if target_dead:
				# Keep the last heading; a missile never acquires a replacement target.
				shot.target = {}
		if not shot.target.is_empty():
			var delta := Vector2(shot.target.x - shot.x, shot.target.y - shot.y)
			var homing: bool = str(shot.key).replace("_mon", "").replace("-mon", "") == "missile"
			if homing:shot.direction = delta.normalized()
			# Ordinary rounds keep their launch direction. A moving target must
			# intersect this step's segment; proximity alone must not bend the shot.
			var along: float = delta.dot(shot.direction)
			var intersects := along>=0 and along<=float(shot.speed)*dt and absf(delta.cross(shot.direction))<=0.5
			if (delta.length() <= shot.speed*dt) if homing else intersects:
				shot.dead = true
				event.emit("projectile_impact", {"shot":shot,"pos":Vector2(shot.target.x,shot.target.y)})
				if shot.hostile:
					hit_player(shot.damage, shot.type)
				else:
					hit_enemy(shot.target, shot.damage, shot.type, shot.get("jewelEffects", []),shot.get("critical",false))
					# Final-group defeat clears the live array; skip its stale snapshot.
					if projectiles.is_empty():
						return
				continue
		var move: Vector2 = shot.direction * float(shot.speed) * dt
		shot.x += move.x
		shot.y += move.y
		# Include the rendered trail before removing an off-screen projectile.
		if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+32:
			shot.dead = true
	projectiles = projectiles.filter(func(p): return not p.dead and (not p.get("beam", false) or long_laser_valid(p)))

# Jewel ownership lives in profile.jewels or one loadout entry, never both.
# Stable instance tokens make stale UI callbacks harmless after sorting/moving.
func jewels_unlocked() -> bool:
	return content_unlocked("feature", "jewels")

func jewel_valid(value: Variant) -> bool:
	return value is Dictionary and db.jewel_max_level(str(value.get("id", ""))) > 0 and nonnegative_number(value.get("level")) and int(value.level) == float(value.level) and int(value.level) >= 1

func new_jewel(id: String, level := 1) -> Dictionary:
	jewel_serial += 1
	return {"id":id, "level":level, "token":jewel_serial}

func load_jewels(raw: Dictionary) -> void:
	invalidate_stat_cache()
	profile.jewels = []
	profile.jewelFragments = 0.0
	if raw.get("jewels") is Array:
		for gem in raw.jewels:
			if jewel_valid(gem):
				profile.jewels.append(new_jewel(str(gem.id), int(gem.level)))
	if raw.get("jewelFragments") is Dictionary:
		for id in raw.jewelFragments:
			if nonnegative_number(raw.jewelFragments[id]):
				profile.jewelFragments += float(raw.jewelFragments[id])
	elif nonnegative_number(raw.get("jewelFragments")):
		profile.jewelFragments = float(raw.jewelFragments)
	for category in ["weapons", "defence"]:
		for entry in module_entries(category):
			var sockets: Array = []
			var ids: Array = []
			if entry.get("sockets") is Array:
				for gem in entry.sockets:
					if jewel_valid(gem) and not ids.has(str(gem.id)) and jewel_allowed(str(gem.id), category):
						sockets.append(new_jewel(str(gem.id), int(gem.level)))
						ids.append(str(gem.id))
					else:
						sockets.append({})
			entry.sockets = sockets
			for field in ["attacks", "hits"]:
				entry[field] = int(entry.get(field, 0)) if nonnegative_number(entry.get(field, 0)) else 0

func jewel_inventory(token: int) -> Dictionary:
	for gem in profile.jewels:
		if int(gem.token) == token:
			return gem
	return {}

func jewel_ratio() -> float:
	var value = db.levels[clampi(stage-1,0,db.levels.size()-1)].get("jewelRatio",1.0)
	return float(value) if nonnegative_number(value) else 1.0

func jewel_create_cost() -> float:
	var value = db.config.get("jewelCreat",0)
	return float(value) if nonnegative_number(value) and float(value) == floorf(float(value)) else 0.0

func jewel_fragment_amount(amount: float, ratio := -1.0) -> float:
	if not nonnegative_number(amount):
		return 0.0
	var result := amount * (jewel_ratio() if ratio < 0 else ratio)
	return snappedf(result,0.01) if nonnegative_number(result) else 0.0

func settle_jewel_fragments(amount: float, source: String, ratio := -1.0) -> float:
	var earned := jewel_fragment_amount(amount * (crew.system_effect(self,"gem_bonus") * reactor_multiplier("condensation") * galaxy.multiplier("gem_fragment") if source=="drop" else 1.0),ratio)
	profile.jewelFragments = snappedf(float(profile.jewelFragments) + earned,0.01)
	# Production only: refunds must not inflate future income.
	if source in ["drop","furnace"] and earned > 0:
		resource_samples.append({"time":economy_time(),"id":"jewel","amount":earned,"origin":source})
		profile.jewelFurnaceIncomePeak = furnace_income_peak(-1,true)
	generate_jewels()
	return earned

func generate_jewels() -> void:
	var result := generate_jewels_into(profile.jewels,float(profile.jewelFragments),jewel_serial,rng)
	profile.jewelFragments=result.fragments
	jewel_serial=result.serial

func generate_jewels_into(inventory: Array, fragments: float, serial: int, random: RandomNumberGenerator) -> Dictionary:
	var cost := jewel_create_cost()
	if cost <= 0 or not jewels_unlocked():
		return {"fragments":fragments,"serial":serial}
	var ids: Array = db.data.get("jewel",{}).keys().filter(func(id):return db.jewel_max_level(str(id)) > 0)
	var required := jewel_combine_count()
	if ids.is_empty() or required<2 or fragments<cost or inventory.size()>=JEWEL_CAPACITY:
		return {"fragments":fragments,"serial":serial}
	var highest: int=ids.map(func(id):return db.jewel_max_level(str(id))).max()
	var level:=1
	while level<highest and cost*pow(float(required),level)<=fragments:
		level+=1
	var threshold:=cost*pow(float(required),level-1)
	# Fragment value is represented by base-recipe digits. Keep only the three
	# highest occupied levels; discard smaller digits after the whole batch fits.
	var planned: Array=[]
	var remaining:=fragments
	for tier in range(level,maxi(0,level-3),-1):
		if tier<level:threshold=cost*pow(float(required),tier-1)
		var count:=mini(required-1,int(minf(floorf(remaining/threshold),float(required-1))))
		for i in count:planned.append(tier)
		remaining=maxf(0.0,remaining-count*threshold)
	if inventory.size()+planned.size()>JEWEL_CAPACITY:
		return {"fragments":fragments,"serial":serial}
	for tier in planned:
		var eligible: Array=ids.filter(func(id):return db.jewel_max_level(str(id))>=tier)
		if eligible.is_empty():return {"fragments":fragments,"serial":serial}
		serial+=1
		inventory.append({"id":str(eligible[random.randi_range(0,eligible.size()-1)]),"level":tier+gem_drop_level_bonus(),"token":serial})
	return {"fragments":0.0,"serial":serial}

func pickup_jewel_fragment(_legacy_id := "") -> bool:
	if not jewels_unlocked():
		return false
	settle_jewel_fragments(1.0,"drop")
	jewels_changed()
	return true

func jewel_kill_drop(enemy: Dictionary) -> void:
	if enemy.get("jewelDropChecked", false):
		return
	enemy.jewelDropChecked = true
	if not jewels_unlocked() or rng.randf() >= float(db.config.get("jewelDrop",0)):
		return
	uid += 1
	drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+65,"age":0.0,"jewel":true,"jewelRatio":jewel_ratio(),"id":"jewel","amount":1})

func sort_jewels(by_level: bool) -> void:
	profile.jewels.sort_custom(func(a,b):
		if by_level and int(a.level) != int(b.level):
			return int(a.level) > int(b.level)
		if int(a.id) != int(b.id):
			return int(a.id) < int(b.id)
		if int(a.level) != int(b.level):
			return int(a.level) > int(b.level)
		return int(a.token) < int(b.token))
	jewels_changed()

func jewel_combine_count() -> int:
	var value = db.config.get("jewelCombine",0)
	return int(value) if nonnegative_number(value) and float(value)==floorf(float(value)) and float(value)>=2 else 0

func jewel_combine_eligible(gem: Dictionary) -> bool:
	return jewel_valid(gem) and not gem.get("locked",false) and not gem.get("disabled",false) and int(gem.level)<db.jewel_max_level(str(gem.id))

func can_combine_jewels(tokens: Array, inventory: Variant = null) -> bool:
	var required := jewel_combine_count()
	if required < 2 or tokens.size() != required:
		return false
	var source: Array=profile.jewels if inventory==null else inventory
	var by_token := {}
	for gem in source:
		if not gem is Dictionary or not gem.get("token") is int or by_token.has(gem.token):return false
		by_token[gem.token]=gem
	var first: Dictionary={}
	var seen := {}
	for token in tokens:
		if not token is int:
			return false
		var gem: Dictionary=by_token.get(token,{})
		if seen.has(token) or not jewel_combine_eligible(gem):return false
		if first.is_empty():first=gem
		if gem.id != first.id or gem.level != first.level:
			return false
		seen[token] = true
	return true

func combine_inventory_jewels(inventory: Array, tokens: Array, next_token: int) -> bool:
	if not can_combine_jewels(tokens,inventory):
		return false
	var first: Dictionary=inventory.filter(func(gem):return int(gem.token)==int(tokens[0]))[0]
	var result := {"id":str(first.id),"level":int(first.level)+1,"token":next_token}
	for i in range(inventory.size()-1,-1,-1):
		if tokens.has(int(inventory[i].token)):inventory.remove_at(i)
	inventory.append(result)
	return true

func combine_jewels(tokens: Array) -> bool:
	if jewel_bulk_combining or not combine_inventory_jewels(profile.jewels,tokens,jewel_serial+1):return false
	jewel_serial+=1
	jewels_changed()
	return true

func combine_all_jewels(clean_obsolete := true) -> Dictionary:
	var failure := {"ok":false,"message":UIText.t("gem.combine_all_jewels.text_01")}
	var required := jewel_combine_count()
	if jewel_bulk_combining or not jewels_unlocked() or required<2 or not nonnegative_number(profile.jewelFragments):return failure
	var tokens := {}
	var installed := {}
	var highest := {}
	for category in ["weapons","defence"]:
		for entry in module_entries(category):
			for gem in entry.get("sockets",[]):
				if not gem.is_empty():
					installed[int(gem.token)]=true
					var id:=str(gem.id)
					highest[id]=maxi(int(highest.get(id,0)),int(gem.level))
	for gem in profile.jewels:
		if not jewel_valid(gem) or not gem.get("token") is int or int(gem.token)<=0 or int(gem.token)>jewel_serial or tokens.has(gem.token):return failure
		tokens[gem.token]=true
	# Work only on a private array; surviving gem objects retain their identity.
	var working: Array=profile.jewels.duplicate()
	var serial := jewel_serial
	var fragments := float(profile.jewelFragments)
	var random := RandomNumberGenerator.new()
	random.seed=rng.seed
	random.state=rng.state
	var count := 0
	while true:
		var groups := {}
		for gem in working:
			if not installed.has(gem.token) and jewel_combine_eligible(gem):
				var key := "%s:%d" % [gem.id,int(gem.level)]
				if not groups.has(key):groups[key]=[]
				groups[key].append(gem)
		var previous := count
		var consumed := {}
		var produced: Array=[]
		for group in groups.values():
			for offset in range(0,group.size()-required+1,required):
				var first: Dictionary=group[offset]
				# The grouped tokens were validated once above. Settle a whole round
				# together instead of revalidating and scanning 200 gems per recipe.
				for i in required:consumed[group[offset+i].token]=true
				serial+=1
				produced.append({"id":first.id,"level":int(first.level)+1,"token":serial})
				count+=1
		if previous==count:break
		working=working.filter(func(gem):return not consumed.has(gem.token))
		working.append_array(produced)
		# Preserve the existing automatic fragment refill, including its new gems.
		var refill := generate_jewels_into(working,fragments,serial,random)
		fragments=refill.fragments
		serial=refill.serial
	var deleted:=0
	if clean_obsolete:
		for gem in working:
			var id:=str(gem.id)
			highest[id]=maxi(int(highest.get(id,0)),int(gem.level))
		var before_cleanup:=working.size()
		working=working.filter(func(gem):return int(gem.level)>=int(highest[str(gem.id)])-10)
		deleted=before_cleanup-working.size()
	if count==0 and deleted==0:return {"ok":true,"count":0,"consumed":0,"deleted":0,"results":[],"tokens":[]}
	var rewards := {}
	var result_tokens: Array=[]
	for gem in working:
		if int(gem.token)<=jewel_serial or int(gem.level)<=1:continue
		var key := "%s:%d" % [gem.id,int(gem.level)]
		if not rewards.has(key):rewards[key]={"id":gem.id,"level":gem.level,"count":0}
		rewards[key].count+=1
		result_tokens.append(gem.token)
	var results: Array=rewards.values()
	results.sort_custom(func(a,b):return int(a.level)>int(b.level) if a.level!=b.level else str(a.id)<str(b.id))
	# Save the staged profile once. Failed writes restore the live inventory unchanged.
	var original := profile
	profile=profile.duplicate()
	profile.jewels=working
	profile.jewelFragments=fragments
	var failed := [false]
	var on_save := func(kind: String,_info: Dictionary):
		if kind=="save_error":failed[0]=true
	jewel_bulk_combining=true
	event.connect(on_save)
	save_progress()
	event.disconnect(on_save)
	if failed[0]:
		profile=original
		jewel_bulk_combining=false
		return failure
	original.merge(profile,true)
	profile=original
	jewel_serial=serial
	rng.state=random.state
	event.emit("jewels_changed",{"slot":""})
	jewel_bulk_combining=false
	return {"ok":true,"count":count,"consumed":count*required,"deleted":deleted,"results":results,"tokens":result_tokens}

func jewel_auto_stock() -> Dictionary:
	var groups := {}
	var best := {}
	var available: Array = []
	for gem in profile.jewels:
		if not jewel_valid(gem) or not gem.get("token") is int or int(gem.token)<=0 or gem.get("locked",false) or gem.get("disabled",false):continue
		available.append(gem)
		var id := str(gem.id)
		if not best.has(id) or int(gem.level)>int(best[id].level):best[id]=gem
		if int(gem.level)<db.jewel_max_level(id):
			var key := "%s:%d" % [id,int(gem.level)]
			groups[key]=int(groups.get(key,0))+1
	return {"groups":groups,"best":best,"available":available}

func jewel_auto_candidates(category: String, entry: Dictionary, stock: Dictionary) -> Array:
	var occupied := {}
	for installed in entry.get("sockets",[]):
		if installed is Dictionary and not installed.is_empty():
			occupied[str(installed.id)]=true
	var candidates: Array = []
	for gem in stock.get("available",[]):
		if not gem is Dictionary or not jewel_allowed(str(gem.id),category) or occupied.has(str(gem.id)):
			continue
		candidates.append(gem)
	return candidates

func auto_manage_jewels() -> Dictionary:
	var result := {"combined":0,"cleaned":0,"replaced":0,"upgraded":0,"equipped":0}
	if not jewels_unlocked() or jewel_bulk_combining or profile.jewels.is_empty():return result
	var required := jewel_combine_count()
	var stock := jewel_auto_stock()
	if required>=2:
		var combined := combine_all_jewels(true)
		if not combined.ok:return result
		result.combined=int(combined.count)
		result.cleaned=int(combined.deleted)
		stock=jewel_auto_stock()
	var changed_slots := {}
	for category in ["weapons","defence"]:
		for index in loadout_entries(category).size():
			var entry := module_entry(category,index)
			if str(entry.get("key","")).is_empty():continue
			for socket in equipment_socket_count(entry):
				var sockets: Array=entry.get("sockets",[])
				var installed: Dictionary=sockets[socket] if socket<sockets.size() and sockets[socket] is Dictionary else {}
				var changed := false
				var candidate: Dictionary = {}
				if installed.is_empty():
					var candidates := jewel_auto_candidates(category,entry,stock)
					if not candidates.is_empty():
						candidate=candidates[rng.randi_range(0,candidates.size()-1)]
						changed=socket_jewel(category,index,socket,int(candidate.token),false)
						if changed:result.equipped+=1
				elif jewel_combine_eligible(installed):
					candidate=stock.best.get(str(installed.id),{})
					if not candidate.is_empty() and int(candidate.level)>int(installed.level):
						changed=socket_jewel(category,index,socket,int(candidate.token),false)
						if changed:result.replaced+=1
					if not changed and required>=2 and int(stock.groups.get("%s:%d" % [installed.id,int(installed.level)],0))>=required-1:
						changed=upgrade_socket_jewel(category,index,socket,int(installed.token),false)
						if changed:result.upgraded+=1
				if changed:
					changed_slots[slot_id(category,index)]=true
					stock=jewel_auto_stock()
	if not changed_slots.is_empty():jewels_changed("",changed_slots.keys())
	return result

func equipment_socket_count(entry: Dictionary) -> int:
	if str(entry.get("key", "")).is_empty():
		return 0
	var value = db.config.get("equipmentSocket", 0)
	if value is int or value is float:
		return maxi(0, int(value))
	var count := 0
	var latest := -1
	for part in str(value).split(","):
		var pair := part.split("|")
		if pair.size() == 2 and pair[0].is_valid_int() and pair[1].is_valid_int() and int(pair[0]) <= int(entry.level) and int(pair[0]) > latest:
			latest = int(pair[0])
			count = maxi(0, int(pair[1]))
	return count

func jewel_allowed(id: String, category: String) -> bool:
	var kind := int(db.jewel_parameter(id, 1))
	return kind == 0 or kind == (1 if category == "weapons" else 2)

func jewel_socket_error(category: String, index: int, token: int, replacing_socket := -1) -> String:
	var key := jewel_socket_error_key(category,index,token,replacing_socket)
	return UIText.t(key) if not key.is_empty() else ""

func jewel_socket_error_key(category: String, index: int, token: int, replacing_socket := -1) -> String:
	var entry := module_entry(category, index)
	var gem := jewel_inventory(token)
	if not jewels_unlocked() or entry.is_empty() or str(entry.key).is_empty() or gem.is_empty():
		return "gem.jewel_socket_error.text_01"
	if not jewel_allowed(str(gem.id), category):
		return "gem.jewel_socket_error.text_02"
	var sockets: Array = entry.get("sockets", [])
	for i in sockets.size():
		if i == replacing_socket:
			continue
		var installed: Dictionary = sockets[i]
		if not installed.is_empty() and str(installed.id) == str(gem.id):
			return "gem.jewel_socket_error.text_03"
	return ""

func socket_jewel(category: String, index: int, socket: int, token: int, notify := true) -> bool:
	if not jewel_socket_error_key(category, index, token, socket).is_empty():
		return false
	var entry := module_entry(category, index)
	if socket < 0 or socket >= equipment_socket_count(entry):
		return false
	var sockets: Array = entry.get("sockets", []).duplicate()
	while sockets.size() < equipment_socket_count(entry):
		sockets.append({})
	var previous: Dictionary = sockets[socket]
	# Replacement exchanges two owners without increasing inventory size.
	var gem := jewel_inventory(token)
	sockets[socket] = gem
	profile.jewels.erase(gem)
	if not previous.is_empty():
		profile.jewels.append(previous)
	entry.sockets = sockets
	invalidate_stat_cache()
	if notify:jewels_changed(slot_id(category, index))
	return true

func unsocket_jewel(category: String, index: int, socket: int, expected_token: int) -> bool:
	var entry := module_entry(category, index)
	var sockets: Array = entry.get("sockets", [])
	if profile.jewels.size() >= JEWEL_CAPACITY or socket < 0 or socket >= sockets.size() or sockets[socket].is_empty() or int(sockets[socket].token) != expected_token:
		return false
	profile.jewels.append(sockets[socket])
	sockets[socket] = {}
	invalidate_stat_cache()
	jewels_changed(slot_id(category, index))
	return true

func socket_upgrade_materials(category: String, index: int, socket: int) -> Array:
	var sockets: Array=module_entry(category,index).get("sockets",[])
	if socket<0 or socket>=sockets.size() or not jewel_combine_eligible(sockets[socket]):return []
	var installed: Dictionary=sockets[socket]
	var tokens: Array=[]
	for gem in profile.jewels:
		if jewel_combine_eligible(gem) and gem.id==installed.id and gem.level==installed.level:tokens.append(int(gem.token))
	return tokens

func can_upgrade_socket_jewel(category: String, index: int, socket: int) -> bool:
	var required:=jewel_combine_count()
	return jewels_unlocked() and not jewel_bulk_combining and required>=2 and socket_upgrade_materials(category,index,socket).size()>=required-1

func upgrade_socket_jewel(category: String, index: int, socket: int, expected_token: int, notify := true) -> bool:
	if not can_upgrade_socket_jewel(category,index,socket):return false
	var entry:=module_entry(category,index)
	var installed: Dictionary=entry.sockets[socket]
	if int(installed.token)!=expected_token:return false
	var tokens:=socket_upgrade_materials(category,index,socket).slice(0,jewel_combine_count()-1)
	var ingredients: Array=[installed.duplicate(true)]
	for token in tokens:ingredients.append(jewel_inventory(int(token)).duplicate(true))
	var all_tokens: Array=tokens.duplicate()
	all_tokens.append(expected_token)
	# Validate and combine on private ingredients before transferring any real owner.
	if not combine_inventory_jewels(ingredients,all_tokens,jewel_serial+1):return false
	for i in range(profile.jewels.size()-1,-1,-1):
		if tokens.has(int(profile.jewels[i].token)):profile.jewels.remove_at(i)
	jewel_serial+=1
	entry.sockets[socket]=ingredients[0]
	invalidate_stat_cache()
	if notify:jewels_changed(slot_id(category,index))
	return true

func return_socket_jewels(entries: Array) -> bool:
	var gems: Array = []
	for entry in entries:
		for gem in entry.get("sockets", []):
			if not gem.is_empty():
				gems.append(gem)
	if gems.size() + profile.jewels.size() > JEWEL_CAPACITY:
		event.emit("jewel_error", {"message":UIText.t("gem.inventory_full")})
		return false
	profile.jewels.append_array(gems)
	for entry in entries:
		entry.sockets = []
	invalidate_stat_cache()
	return true

func jewels_changed(slot := "", slots: Array = []) -> void:
	invalidate_stat_cache()
	generate_jewels()
	if player.has("armour"):
		player.armour = N.minimum(player.armour,stat("armour"))
		player.shield = N.minimum(player.shield,max_shield())
	save_progress()
	event.emit("jewels_changed", {"slot":slot,"slots":slots})

func jewel_effects(entry: Dictionary) -> Array:
	var cached: Array = stat_cache.get("jewel_effects",[]) if stat_cache_enabled else []
	for item in cached:
		if is_same(item.entry,entry):
			# Attack callers attach their source mount; never expose the cached
			# dictionaries to that mutation or to in-flight projectile effects.
			return item.effects.duplicate(true)
	var result: Array = []
	if str(entry.get("key", "")).is_empty():return result
	var sockets: Array = entry.get("sockets", [])
	for i in mini(sockets.size(), equipment_socket_count(entry)):
		var gem: Dictionary = sockets[i]
		if gem.is_empty():
			continue
		var effect := {"kind":db.jewel_effect(str(gem.id)), "level":int(gem.level)}
		for n in [2, 4, 5]:
			effect["p%d" % n] = db.jewel_parameter(str(gem.id), n)
		result.append(effect)
	if stat_cache_enabled:
		if cached.size()>=32:cached.clear()
		cached.append({"entry":entry,"effects":result.duplicate(true)})
		stat_cache.jewel_effects=cached
	return result

func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null) -> Variant:
	if str(entry.get("key", "")).is_empty():
		return 0
	var value := equipment_stat(str(entry.key), int(entry.level) if level < 0 else level)
	for effect in (jewel_effects(entry) if effects == null else effects):
		if effect.kind in ["proficiency", "adaptation"]:
			var count := maxi(1, int(entry.get("attacks" if effect.kind == "proficiency" else "hits", 0)))
			var bonus := roundf(float(effect.p2) * int(effect.level) * log(float(count)) / log(10.0) * 100.0) / 100.0
			value = ceilf(value * (1.0 + bonus))
	var crew_bonus: float
	if stat_cache_enabled and stat_cache.has("crew_equipment"):
		crew_bonus=stat_cache.crew_equipment
	else:
		crew_bonus=crew.system_effect(self,"equip_bonus")
		if stat_cache_enabled:stat_cache.crew_equipment=crew_bonus
	return N.multiply(N.multiply(N.multiply(value,planet_equipment_multiplier()),crew_bonus),galaxy.multiplier("equipment_value"))

func jewel_critical(entry: Dictionary) -> Vector2:
	var row := db.equip(str(entry.key), int(entry.level))
	var rate := float(row.get("cri", 0))
	var damage := float(db.config.get("baseCriDmg", 1)) + float(row.get("criDmg", 0))
	var multiplier := 1.0
	for effect in jewel_effects(entry):
		if effect.kind == "critical":
			rate += float(effect.p2)
			multiplier *= 1.0 + float(effect.p4) * int(effect.level)
	return Vector2(clampf(rate * multiplier, 0, 1), maxf(0, damage))

func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:
	var entry := slot_entry("weapons",index)
	var critical := jewel_critical(entry)
	var raw = N.multiply(jewel_equipment_stat(entry),multiplier)
	var is_critical := rng.randf() < critical.x
	if is_critical:
		raw = N.multiply(raw,critical.y)
	var effects := jewel_effects(entry)
	for effect in effects:
		effect.source = index
	return {"damage":raw,"effects":effects,"critical":is_critical}

func missile_visual_spread(index: int, count: int) -> float:
	return (float(index)/float(count-1)-0.5)*minf(88.0,float(count-1)*24.0) if count>1 else 0.0

func jewel_fire(index: int, target: Dictionary, weapon: Dictionary, offset: Vector2, multiplier := 1.0, visual_spread := 0.0) -> void:
	# Every player missile path resolves its live mount here, including repeats.
	if str(slot_entry("weapons",index).key)=="missile":
		offset = player_weapon_offset(index)
	var attack := jewel_attack(index,multiplier)
	fire(player,target,weapon,attack.damage,false,str(slot_entry("weapons",index).key),offset,visual_spread)
	projectiles.back().jewelEffects = attack.effects
	projectiles.back().critical = attack.critical

func queue_jewel_repeats(index: int, multiplier: float, beam: Dictionary = {}) -> void:
	if not beam.is_empty():
		if projectiles.any(func(p):return p.get("beam",false) and not p.hostile and p.mount==index and p.get("repeated",false) and long_laser_valid(p)) or jewel_repeats.any(func(p):return p.index==index and p.has("beam")):
			return
	var entry := slot_entry("weapons", index)
	var pending: Array = []
	for effect in jewel_effects(entry):
		if effect.kind == "repeat" and rng.randf() < float(effect.p2):
			pending.append(multiplier * (1.0 + float(effect.p4) * int(effect.level)))
	for i in pending.size():
		var choice := rng.randi_range(i, pending.size()-1)
		var value = pending[choice]
		pending[choice] = pending[i]
		pending[i] = value
		jewel_repeats.append({"index":index, "entry":entry, "remaining":0.5 * (i+1), "multiplier":value})
		if not beam.is_empty():
			jewel_repeats.back().beam = beam
			break

func advance_jewel_repeats(dt: float) -> void:
	for pending in jewel_repeats.duplicate():
		pending.remaining -= dt
		if pending.remaining > 0.000000001:
			continue
		jewel_repeats.erase(pending)
		var entry := slot_entry("weapons", int(pending.index))
		if state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():
			continue
		var weapon := db.equip(str(entry.key), int(entry.level))
		if pending.has("beam"):
			if projectiles.has(pending.beam) and long_laser_valid(pending.beam):
				lock_long_laser(player,weapon,false,int(pending.index),entry,true,float(pending.multiplier))
			continue
		var candidates := targets(int(weapon.dmgtype))
		if candidates.is_empty():
			continue
		entry.attacks = int(entry.get("attacks", 0)) + 1
		invalidate_equipment_counter(str(entry.key))
		event.emit("equipment_stats",{"slot":slot_id("weapons",int(pending.index))})
		for n in (int(weapon.para1) if entry.key == "missile" else 1):
			jewel_fire(int(pending.index), candidates[n % candidates.size()], weapon, player_weapon_offset(int(pending.index)), float(pending.multiplier), missile_visual_spread(n,int(weapon.para1)) if entry.key=="missile" else 0.0)

func jewel_on_hit(enemy: Dictionary, effects: Array) -> void:
	for effect in effects:
		if effect.kind == "iron":
			var source := str(effect.get("source", 0))
			var sources: Dictionary = enemy.get("jewelIronSources", {})
			var stacks := int(sources.get(source, 0))
			if stacks < int(effect.p4):
				sources[source] = stacks + 1
				enemy.jewelIronSources = sources
				enemy.jewelIronStacks = int(enemy.get("jewelIronStacks", 0)) + 1
				enemy.jewelIron = float(enemy.get("jewelIron", 0)) + float(effect.p2) * int(effect.level)
		elif effect.kind == "interference" and rng.randf() < float(effect.p2):
			enemy.interference = maxf(float(enemy.get("interference", 0)), float(effect.p4) * int(effect.level))
			enemy.jewelExplosion = maxf(float(enemy.get("jewelExplosion", 0)), float(effect.p5) * int(effect.level))

func has_defence_jewels() -> bool:
	for entry in defense_entries():
		if str(entry.get("key", "")).is_empty():
			continue
		var sockets: Array = entry.get("sockets", [])
		for index in mini(sockets.size(), equipment_socket_count(entry)):
			var gem: Dictionary = sockets[index]
			if not gem.is_empty():
				return true
	return false

func jewel_defence_hit(index: int) -> void:
	var entry := slot_entry("defence", index)
	entry.hits = int(entry.get("hits", 0)) + 1
	invalidate_equipment_counter(str(entry.key))
	event.emit("equipment_stats",{"slot":slot_id("defence",index)})
	jewel_defence_times[index] = 0.0
	for effect in jewel_effects(entry):
		if effect.kind == "charge" and int(effect.p4) > 0 and int(entry.hits) % int(effect.p4) == 0:
			var indices: Array = []
			for i in weapon_entries().size():
				if not str(weapon_entries()[i].key).is_empty():
					indices.append(i)
			if not indices.is_empty():
				apply_jewel_charge(int(indices[rng.randi_range(0, indices.size()-1)]),1.0 + float(effect.p2) * int(effect.level))

# Charge selects a mount; continuous attacks retain the modifier on existing instances.
func apply_jewel_charge(index: int, multiplier: float) -> void:
	var id := slot_id("weapons",index)
	if str(slot_entry("weapons",index).get("key","")) == "longLaser":
		var applied := false
		for shot in projectiles:
			if shot.get("beam",false) and not shot.hostile and shot.mount==index and long_laser_valid(shot):
				shot.charged_multiplier = maxf(float(shot.charged_multiplier),multiplier)
				applied = true
		if applied:
			jewel_charged.erase(id)
			return
	else:
		cooldowns[id] = 0.0
	jewel_charged[id] = maxf(float(jewel_charged.get(id,1.0)),multiplier)

func jewel_hit_player(raw, type: int) -> void:
	sync_jewel_defence_damage()
	since_hit = 0
	var rest = raw
	var loss = 0.0
	for key in ["shield", "armour"]:
		if N.compare(rest,0)<=0 or N.compare(player[key],0)<=0:
			continue
		var current = player[key]
		var incoming = rest
		var spent = 0.0
		var damage = 0.0
		# The aggregate remains authoritative. At huge capacities, capacity-loss
		# can round to zero while a small, real amount of health still survives.
		var module_remaining = 0.0
		var module_capacity = 0.0
		for index in defense_entries().size():
			var entry = slot_entry("defence",index)
			if entry.key == key:
				var maximum = jewel_equipment_stat(entry)
				module_capacity = N.add(module_capacity,maximum)
				module_remaining = N.add(module_remaining,N.subtract(maximum,jewel_defence_damage.get(index,0)))
		for index in defense_entries().size():
			var entry = slot_entry("defence", index)
			if entry.key != key:
				continue
			var maximum = jewel_equipment_stat(entry)
			var tracked = N.subtract(maximum,jewel_defence_damage.get(index,0))
			var weight = N.ratio(tracked,module_remaining) if N.compare(module_remaining,0)>0 else N.ratio(maximum,module_capacity)
			var remaining = N.multiply(current,weight)
			if N.compare(remaining,0)<=0:
				continue
			var share = N.ratio(remaining,current)
			var row = db.equip(key, int(entry.level))
			var factor = 1.0 - float(db.config.dmgReduce) if type == int(row.dmgtype) else 1.0
			var reduction = 0.0
			for effect in jewel_effects(entry):
				if effect.kind == "resistance":
					reduction = N.add(reduction,N.multiply(maximum,float(effect.p2)*int(effect.level)))
			var part = N.subtract(N.multiply(incoming,share*factor),reduction)
			var taken = N.minimum(remaining,part)
			damage = N.add(damage,taken)
			jewel_defence_damage[index] = N.add(jewel_defence_damage.get(index,0),taken)
			spent = N.add(spent,N.minimum(N.multiply(incoming,share),N.divide(N.add(taken,reduction),maxf(0.001,factor))))
			if N.compare(taken,0)>0:
				jewel_defence_hit(index)
		var rounded = N.minimum(current,N.ceiling(damage))
		player[key] = N.subtract(current,rounded)
		loss = N.add(loss,rounded)
		rest = N.subtract(incoming,spent)
	event.emit("hit", {"x":player.x,"y":player.y,"amount":loss,"player":true,"type":type})
	if N.compare(player.armour,0)<=0:
		event.emit("explode", {"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func advance_jewel_repair(dt: float) -> bool:
	if not has_defence_jewels():
		return false
	var capacities = sync_jewel_defence_damage()
	for index in defense_entries().size():
		var entry = slot_entry("defence", index)
		var key = str(entry.key)
		if key.is_empty():
			continue
		var elapsed = float(jewel_defence_times.get(index, since_hit - dt)) + dt
		jewel_defence_times[index] = elapsed
		var effects: Array = capacities[key].effects[index]
		var tenacity = 0.0
		for effect in effects:
			if effect.kind == "tenacity":
				tenacity = float(effect.p2) * int(effect.level)
		var rate = 0.0
		if key == "shield":
			var row = db.equip(key, int(entry.level))
			rate += float(row.para2) * (1.0 if elapsed >= float(row.para3) else tenacity)
		for effect in effects:
			if effect.kind == "repair":
				rate += float(effect.p2) * int(effect.level) * (1.0 if elapsed >= float(effect.p4) else tenacity)
		var recovered = N.minimum(jewel_defence_damage.get(index,0),N.multiply(capacities[key].maxima[index],rate*dt))
		jewel_defence_damage[index] = N.subtract(jewel_defence_damage.get(index,0),recovered)
		player[key] = N.minimum(capacities[key].total,N.add(player[key],recovered))
	return true

func sync_jewel_defence_damage() -> Dictionary:
	# The aggregate player health stays authoritative. This transient allocation
	# records which module is damaged so its repair cannot heal another module.
	# External capacity/health changes reconcile only their delta, preserving
	# existing per-module losses; nothing is persisted as a second health balance.
	var capacities = {}
	for key in ["shield", "armour"]:
		var capacity: Dictionary = jewel_defence_capacity_cache.get(key, {}) if stat_cache_enabled else {}
		if capacity.is_empty():
			var indices: Array = []
			var maxima = {}
			var effects_by_index = {}
			var total = 0.0
			for index in defense_entries().size():
				var entry = slot_entry("defence", index)
				if entry.key != key:
					continue
				indices.append(index)
				var effects = jewel_effects(entry)
				var maximum = jewel_equipment_stat(entry, -1, effects)
				maxima[index] = maximum
				effects_by_index[index] = effects
				total = N.add(total,maximum)
			capacity = {"indices":indices,"maxima":maxima,"effects":effects_by_index,"total":total}
			if stat_cache_enabled:
				jewel_defence_capacity_cache[key] = capacity
		var indices: Array = capacity.indices
		var maxima: Dictionary = capacity.maxima
		var total = capacity.total
		var missing = 0.0
		for index in indices:
			jewel_defence_damage[index] = N.minimum(jewel_defence_damage.get(index,0),maxima[index])
			missing = N.add(missing,jewel_defence_damage[index])
		var expected = N.subtract(total,player[key])
		var increased = N.compare(expected,missing)>0
		var delta = N.subtract(N.maximum(expected,missing),N.minimum(expected,missing))
		for index in indices:
			var previous = jewel_defence_damage[index]
			var weight = N.ratio(N.subtract(maxima[index],previous),N.maximum(0.001,N.subtract(total,missing))) if increased else N.ratio(previous,N.maximum(0.001,missing))
			jewel_defence_damage[index]=N.minimum(maxima[index],N.add(previous,N.multiply(delta,weight)) if increased else N.subtract(previous,N.multiply(delta,weight)))
		capacities[key] = capacity
	return capacities

func refresh_crew_level_effects(previous: Dictionary, current: Dictionary) -> void:
	if not crew.levels_unlocked(self):return
	if previous.get("level")==current.get("level") and previous.get("assignmentType")==current.get("assignmentType") and previous.get("targetId")==current.get("targetId"):return
	var kinds := {}
	for member in [previous,current]:
		var job: Dictionary=crew.assignments(self).get(str(member.get("assignmentType","")),{})
		kinds[str(job.get("targetType",""))]=true
	if kinds.has("equipment"):
		invalidate_stat_cache()
		apply_refit_health()
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
	if kinds.has("hightech"):event.emit("scientists_changed",{})
	if kinds.has("reactor"):
		var remaining := reactor_capacity()
		for key in reactor_modules():
			profile.reactorAllocation[key]=mini(int(profile.reactorAllocation.get(key,0)),remaining)
			remaining-=int(profile.reactorAllocation[key])
		invalidate_stat_cache()
		apply_refit_health()
		event.emit("reactor_changed",{})
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
