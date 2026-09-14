class_name BattleGame
extends RefCounted

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon"]
const BULK_EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon"]
const SAVE_PATH := "user://progress.json"
const FURNACE := "超时空炼铁炉"
const ENERGY_FOCUS := "正电子聚焦装置"
const DENSE_ARMOUR := "简并态装甲"
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const HIGHTECH_SLOTS_PER_PAGE := 3
const HIGHTECH_MIN_SLOTS := 6
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

func _init(database: ShipDatabase, persist := true) -> void:
	db = database
	save_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	if persist:
		load_progress()
		advance_charge(minf(float(db.config.get("offlineMax", 0)) * 3600.0, maxf(0, Time.get_unix_time_from_system() - float(profile.hightechSavedAt))))
		advance_hightech(minf(float(db.config.get("offlineMax", 0)) * 3600.0, maxf(0, Time.get_unix_time_from_system() - float(profile.hightechSavedAt))))
		save_progress()
	reset_player()

func fresh_profile() -> Dictionary:
	return {"version":1, "highestLevel":1, "cleared":[], "bossSeen":[], "levels":{"armour":1,"shield":1,"laser":1,"missile":1,"cannon":1}, "resources":{"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))}, "unlocked":str(db.config.startEquip).split(","), "loop":false, "hightechLevels":{}, "hightechResearch":{}, "hightechSavedAt":Time.get_unix_time_from_system(), "furnaceElapsed":0.0, "furnaceIncomePeak":0.0}

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
	for key in EQUIPMENT:
		var value = raw.get("levels", {}).get(key, 1) if raw.get("levels") is Dictionary else 1
		if value is float or value is int:
			profile.levels[key] = clampi(int(value), 1, db.max_equipment_level(key))
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
	load_hightech(raw)
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
	if raw.get("hightechResearch") is Dictionary:
		# Preserve already-started work if the configured concurrency is later reduced.
		for key in raw.hightechResearch:
			var job = raw.hightechResearch[key]
			if db.data.get("hightech", {}).has(key) and job is Dictionary and nonnegative_number(job.get("remaining")) and nonnegative_number(job.get("duration")) and float(job.remaining) <= float(job.duration):
				profile.hightechResearch[key] = {"remaining":float(job.remaining), "duration":float(job.duration), "active":job.get("active", true) == true}
	if raw.get("resourceSamples") is Array:
		for sample in raw.resourceSamples:
			if sample is Dictionary and nonnegative_number(sample.get("time")) and nonnegative_number(sample.get("amount")) and str(sample.get("id", "")) in ["1", "2"] and float(sample.time) <= float(profile.hightechSavedAt) and float(sample.time) > float(profile.hightechSavedAt) - 60.0:
				# Legacy samples have no reliable source; keep totals but exclude them
				# from furnace input until this short rolling window expires.
				resource_samples.append({"time":float(sample.time), "amount":float(sample.amount), "id":str(sample.id), "origin":str(sample.get("origin", "unknown"))})
	furnace_income_peak(float(profile.hightechSavedAt))
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

func save_progress() -> void:
	if not save_enabled:
		return
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
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		event.emit("save_error", {})

func stat(key: String) -> float:
	return equipment_stat(key, int(profile.levels[key]))

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
	if not profile.has("charge"):
		profile.charge = {}
	if not profile.charge.has(key):
		profile.charge[key] = {"level":0,"count":0.0,"elapsed":0.0,"active":false,"credit":0.0,"started":0}
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
		profile.resources[id] = maxf(0,balance)
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
	profile.hightechOrder = slots
	return slots

func swap_hightech_slots(source: int, target: int) -> bool:
	var slots := hightech_slots()
	if source < 0 or target < 0 or source >= slots.size() or target >= slots.size() or source == target or slots[source] == "":
		return false
	var key = slots[source]
	slots[source] = slots[target]
	slots[target] = key
	save_progress()
	return true

func hightech_duration(key: String) -> float:
	var row: Dictionary = db.data.hightech[key]
	# D2 gives a linear series: 10, 12, 14, ...; target level is current + 1.
	return roundf(float(row.timeCostBase) * (1.0 + float(row.timeCostMutiple) * hightech_level(key)))

func description_number(value: float) -> String:
	return ("%.8f" % value).rstrip("0").trim_suffix(".") if value != roundf(value) else str(int(value))

func hightech_description(key: String, now := -1.0) -> String:
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

func can_research(key: String) -> bool:
	return hightech_unlocked(key) and not active_research().has(key) and int(db.config.get("hightechLimit", 0)) > 0

func active_research() -> Array:
	return profile.hightechResearch.keys().filter(func(key):return profile.hightechResearch[key].get("active", true))

func research(key: String, replace_key := "") -> bool:
	if not can_research(key):
		return false
	var active := active_research()
	if active.size() >= int(db.config.hightechLimit):
		if replace_key.is_empty() and active.size() == 1:
			replace_key = str(active[0])
		if not active.has(replace_key):
			return false
		profile.hightechResearch[replace_key].active = false
	if not profile.hightechResearch.has(key):
		var duration := hightech_duration(key)
		profile.hightechResearch[key] = {"remaining":duration,"duration":duration}
	profile.hightechResearch[key].active = true
	save_progress()
	event.emit("research", {"key":key})
	return true

func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
	if real_dt < 0:
		real_dt = dt
	if end_time < 0:
		end_time = Time.get_unix_time_from_system()
	var wall_per_step := real_dt / dt if dt > 0 else 1.0
	# Split at completion boundaries, so a newly completed furnace only runs afterward.
	var remaining := dt
	while true:
		var step := remaining
		for key in active_research():
			var job: Dictionary = profile.hightechResearch[key]
			step = minf(step, float(job.remaining))
		advance_furnace(step, end_time - (remaining - step) * wall_per_step, wall_per_step)
		remaining -= step
		for key in active_research():
			var job: Dictionary = profile.hightechResearch[key]
			job.remaining = maxf(0, float(job.remaining) - step)
			if job.remaining <= 0:
				profile.hightechLevels[key] = hightech_level(key) + 1
				job.duration = hightech_duration(key)
				job.remaining = job.duration
				# Armour research changes the maximum only; do not heal current armour.
				event.emit("hightech_complete", {"key":key})
		if remaining <= 0:
			break

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
	profile.furnaceIncomePeak = maxf(float(profile.get("furnaceIncomePeak",0.0)),resource_minute_total("1",now,true))
	return float(profile.furnaceIncomePeak)

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
			var amount := ceilf(furnace_income_peak(end_time - age * wall_per_step) * float(row.para2) * hightech_level(FURNACE))
			drops.append({"uid":uid,"x":rng.randf_range(440,1220),"y":rng.randf_range(300,505),"age":age,"id":"1","amount":amount,"hightech":true})

func max_shield() -> float:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	player = {"x":280.0, "y":405.0, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	if next == State.TRAVEL:
		cooldowns.clear()
		for key in profile.unlocked:
			var cd := float(db.equip(key,int(profile.levels[key])).cd)
			if cd > 0:
				cooldowns[key] = cd
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
	return gap / float(db.config.movement) if float(db.config.movement) > 0 else INF

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
		enemy.y = 198.0 + (slot + (float(row.size) - 1.0) / 2.0) * 44.0
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
		var ac := absf(float(a.slot) + (float(a.size)-1)/2 - 4.5)
		var bc := absf(float(b.slot) + (float(b.size)-1)/2 - 4.5)
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
	if count <= 1:
		return Vector2.ZERO
	# Spread identical mounts across the visible hull, including its wings.
	var half_span := 39.0 * (1.4 if enemy.boss else 0.53)
	return Vector2(0, lerpf(-half_span, half_span, float(ordinal) / float(count - 1)))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw: float, hostile: bool, key: String, offset := Vector2.ZERO) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + (-45 if hostile else 70) + offset.x,"y":float(source.y) + offset.y, "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*float(db.defaults.projectilePixelsPerUnit),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	shot.direction = Vector2(target.x - shot.x, target.y - shot.y).normalized()
	event.emit("fire", {"x":source.x,"y":source.y,"type":int(weapon.dmgtype)})

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
	furnace_income_peak()
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
	return upgrade_cost_for_level(key, int(profile.levels[key]) + 1) if levels == 1 else upgrade_costs(key, levels)

func upgrade_costs(key: String, levels: int) -> Dictionary:
	var total := {}
	if levels <= 0 or not profile.levels.has(key):
		return total
	var current := int(profile.levels[key])
	if current + levels > db.max_equipment_level(key):
		return total
	for level in range(current + 1, current + levels + 1):
		var cost := upgrade_cost_for_level(key, level)
		for id in cost:
			total[id] = int(total.get(id, 0)) + int(cost[id])
	return total

func can_upgrade_amount(key: String, levels: int) -> bool:
	if levels <= 0 or not profile.unlocked.has(key) or not profile.levels.has(key):
		return false
	if levels > 1 and not BULK_EQUIPMENT.has(key):
		return false
	if int(profile.levels[key]) + levels > db.max_equipment_level(key):
		return false
	var costs := upgrade_costs(key, levels)
	for id in costs:
		if float(profile.resources.get(id, 0)) < float(costs[id]):
			return false
	return true

func can_upgrade(key: String, levels := 1) -> bool:
	return can_upgrade_amount(key, levels)

func max_upgrade_amount(key: String) -> int:
	if not BULK_EQUIPMENT.has(key) or not profile.unlocked.has(key) or not profile.levels.has(key):
		return 0
	var available: Dictionary = profile.resources.duplicate()
	var amount := 0
	var current := int(profile.levels[key])
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
	if not can_upgrade_amount(key, levels):
		return false
	var costs := upgrade_costs(key, levels)
	for id in costs:
		profile.resources[id] -= costs[id]
	var before := stat(key)
	profile.levels[key] += levels
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if key == "armour" and state != State.RETREAT:
		player.armour += stat(key) - before
	elif key == "shield" and state != State.RETREAT:
		player.shield += stat(key) - before
	save_progress()
	event.emit("upgrade", {"key":key,"levels":levels,"cost":costs})
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
	var shield := db.equip("shield", int(profile.levels.shield))
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
		distance += float(db.config.movement) * dt
		var level: Dictionary = db.levels[stage - 1]
		if group_index < level.groups.size() and distance >= float(level.groups[group_index].position)*float(level.length):
			spawn_group()
		return
	for key in profile.unlocked:
		var weapon := db.equip(key, int(profile.levels[key]))
		if float(weapon.cd) <= 0:
			continue
		cooldowns[key] = maxf(0, float(cooldowns.get(key, 0)) - dt)
		if cooldowns[key] <= 0:
			var candidates := targets(int(weapon.dmgtype))
			var count := int(weapon.para1) if key == "missile" else 1
			for i in range(count):
				if candidates.is_empty():
					break
				var target := candidates[i % candidates.size()] if key == "missile" else candidates[0]
				var launch_offset := Vector2.ZERO
				if key == "missile" and count > 1:
					launch_offset.y = (float(i) - float(count - 1) / 2.0) * 12.0
				fire(player, target, weapon, stat(key), false, key, launch_offset)
			if count > 0 and not candidates.is_empty():
				cooldowns[key] = float(weapon.cd)
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
