extends RefCounted
const SETUP = preload("res://runtime/combat_setup.gd")
const STEP := 1.0 / 60.0

var bundle
var kernel
var seed: int
var _numbers
var _modules
var rules := {}
var geometry := {}
var motion := {}
var profile := {}
var campaign := {}
var equipment := {}
var economy := {"wallet": {}, "drops": {}, "claimed": {}, "income": [], "peaks": {}, "timed_elapsed": 0.0}
var notifications := {"seen": {}, "read": {}}
var settings := {"skip_guides": false}
var time := {"wall": 0.0, "game": 0.0, "ticks": 0, "pending": 0.0, "accepted": [], "sample_wall": 0.0, "pause_reasons": {}, "departure": 0.0, "speed": 1}
var change_number: int = 0
var stopped_error := ""
var _unlock_rows: Array = []

static func create(config, random_seed: int = 17) -> Dictionary:
	if config.entry != "GameSession": return {"ok": false, "reason": "IncompatibleConfigEntry"}
	if not ClassDB.class_exists("SpaceCombatKernel") or not ClassDB.class_exists("SpaceAmount") or not ClassDB.class_exists("SpaceModuleEvaluator"):
		return {"ok": false, "reason": "MissingNativeDependency"}
	var session = load("res://runtime/game_session.gd").new()
	session.bundle = config
	session._unlock_rows = config.rows("unlock")
	session.seed = random_seed
	session.kernel = ClassDB.instantiate("SpaceCombatKernel")
	session._numbers = ClassDB.instantiate("SpaceAmount")
	session._modules = ClassDB.instantiate("SpaceModuleEvaluator")
	for row in config.rows("battle_rules"): session.rules[row.key] = row.value
	session.rules.retreat_seconds = clampf(session.rules.retreat_seconds, session.rules.minimum_retreat_seconds, session.rules.maximum_retreat_seconds)
	for row in config.rows("battle_geometry"): session.geometry[row.key] = row.value
	for row in config.rows("weapon_motion"): session.motion[row.id] = row.value
	session.profile = config.lookup("initial_profile", ["default"])
	if session.profile.is_empty() or session.rules.is_empty() or session.geometry.is_empty() or session.motion.is_empty():
		return {"ok": false, "reason": "MissingRuntimeDefinition"}
	var profile: Dictionary = session.profile
	session.campaign = {"stage": int(profile.initial_stage), "point": 0, "distance": 0.0, "segment_origin": 0.0,
		"phase": "menu", "highestReached": int(profile.initial_stage), "lifetimeHighestReached": int(profile.initial_stage),
		"clearedStageIds": {}, "permanentGrants": {}, "garrison": {}, "death_option": int(profile.death_option), "wait": 0.0}
	var ship: Dictionary = config.lookup("ship", [profile.ship_id])
	if ship.is_empty(): return {"ok": false, "reason": "UnknownShip"}
	session.equipment = {"ship_id": profile.ship_id, "slots": [], "reactor": {"level": 1, "allocation": {"weapons": 0, "defence": 0, "smelting": 0, "condensation": 0}}}
	var start: Dictionary = config.lookup("config", ["startEquip"])
	if start.is_empty(): return {"ok": false, "reason": "MissingInitialEquipment"}
	var used := {"weapon": 0, "defence": 0}
	for equipment_id in str(start.para_1).split(","):
		var category := "defence" if equipment_id in ["armour", "shield"] else "weapon"
		used[category] += 1
		if not session.content_unlocked("equipment", equipment_id): return {"ok": false, "reason": "InitialEquipmentLocked"}
		session.equipment.slots.append({"slot": session.equipment.slots.size(), "equipment_id": equipment_id, "paid_level": int(profile.initial_slot_level), "category": category})
	if used.weapon > int(ship.para_1) or used.defence > int(ship.para_2): return {"ok": false, "reason": "InitialSlotCapacity"}
	for category in ["weapon", "defence"]:
		var capacity: int = int(ship.para_1 if category == "weapon" else ship.para_2)
		for index in range(used[category], capacity):
			session.equipment.slots.append({"slot": session.equipment.slots.size(), "equipment_id": "", "paid_level": int(profile.initial_slot_level), "category": category})
	var indices := {"weapon": 0, "defence": 0}
	for slot in session.equipment.slots:
		slot.index = indices[slot.category]
		slot.id = slot.category + "/" + str(slot.index)
		slot.generation = 0
		slot.switch_ready_at = 0.0
		indices[slot.category] += 1
	for resource in [str(int(profile.iron_id)), str(int(profile.uranium_id)), profile.fragment_id]:
		session.economy.wallet[resource] = session.amount(profile.initial_amount)
	session.economy.wallet[profile.chrono_id] = session.amount(profile.initial_chrono)
	var initialized: Dictionary = SETUP.initialize(session)
	if not initialized.ok: return initialized
	if not session.stopped_error.is_empty(): return {"ok": false, "reason": session.stopped_error}
	for row in session._unlock_rows:
		if session.unlocked(row): session.notifications.seen[row.name] = true
	return {"ok": true, "session": session}

func calculate(operation: String, left: Dictionary = {}, right: Dictionary = {}, parameter: float = 0.0, count: int = 0) -> Dictionary:
	var result: Dictionary = _numbers.calculate(operation, left, right, parameter, count)
	if not result.ok: stopped_error = result.error
	return result

func amount(value) -> Dictionary:
	if value is Dictionary: return calculate("decode", value).get("value", {})
	return calculate("from_decimal", {"text": str(value)}).get("value", {})
func add(a: Dictionary, b: Dictionary) -> Dictionary: return calculate("add", a, b).get("value", {})
func mul(a: Dictionary, b: Dictionary) -> Dictionary: return calculate("mul", a, b).get("value", {})
func ceil_amount(a: Dictionary) -> Dictionary: return calculate("ceil", a).get("value", {})

func growth(base: Dictionary, rate: float, level: int) -> Dictionary:
	var result: Dictionary = _modules.growth({"base": base, "growth": rate, "level": str(level)})
	if not result.ok: stopped_error = result.error
	return result.get("value", {})

func unlocked(row: Dictionary) -> bool:
	if campaign.permanentGrants.has(row.name) or int(row.level) == 0: return true
	if row.mode == "cleared": return campaign.clearedStageIds.has(str(int(row.level)))
	return campaign.highestReached > int(row.level) if row.mode == "reached" else false

func content_unlocked(category: String, target: String) -> bool:
	for row in _unlock_rows:
		if row.type == category and row.target == target: return unlocked(row)
	return false

func set_pause(reason: String, enabled: bool) -> void:
	if enabled: time.pause_reasons[reason] = true
	else: time.pause_reasons.erase(reason)

func set_speed(speed: int) -> Dictionary:
	if speed < 1 or speed > int(rules.maximum_speed): return {"ok": false, "reason": "InvalidSpeed"}
	time.speed = speed
	return {"ok": true}

func depart(stage: int = -1) -> Dictionary:
	if stage < 0: stage = campaign.stage
	if bundle.lookup("level", [stage]).is_empty(): return {"ok": false, "reason": "UnknownStage"}
	if stage > campaign.highestReached: return {"ok": false, "reason": "StageLocked"}
	if campaign.phase != "menu": return {"ok": false, "reason": "AlreadyDeparted"}
	if not kernel.prepare_departure(): return {"ok": false, "reason": "NoArmour"}
	campaign.stage = stage
	campaign.point = 0
	campaign.distance = 0.0
	campaign.segment_origin = 0.0
	campaign.phase = "travel"
	time.departure = rules.departure_seconds
	change_number += 1
	return {"ok": true}

func frame(real_dt: float, focused: bool = true, step_budget: int = 600) -> void:
	if not stopped_error.is_empty(): return
	if not is_finite(real_dt) or real_dt < 0 or step_budget < 0:
		stopped_error = "InvalidFrameInput"
		return
	if not is_finite(time.wall + real_dt):
		stopped_error = "TimeRangeExceeded"
		return
	time.wall += real_dt
	if not focused: time.speed = 1
	if not time.pause_reasons.is_empty(): return
	var accepted := real_dt
	if time.departure > 0:
		var departure: float = minf(time.departure, accepted)
		time.departure -= departure
		accepted -= departure
	if accepted > 0:
		var speed: int = int(time.speed) if focused else 1
		var accelerated := accepted
		if speed > 1:
			var cost: Dictionary = mul(amount(accepted), amount(speed - 1))
			var fraction: float = calculate("to_ratio", economy.wallet[profile.chrono_id], cost).scalar
			accelerated *= fraction
		var credit: float = accelerated * speed + accepted - accelerated
		if not is_finite(time.pending + credit) or time.pending + credit - STEP == time.pending + credit:
			stopped_error = "TimeRangeExceeded"
			return
		if speed > 1:
			var payment: Dictionary = mul(amount(accelerated), amount(speed - 1))
			economy.wallet[profile.chrono_id] = calculate("sub_nonnegative", economy.wallet[profile.chrono_id], payment).value
		var start: float = time.wall - accepted
		if accelerated > 0:
			time.accepted.append({"game": accelerated * speed, "wall": start, "speed": speed})
		if accepted > accelerated:
			time.accepted.append({"game": accepted - accelerated, "wall": start + accelerated, "speed": 1})
		time.pending += credit
	var steps := 0
	while stopped_error.is_empty() and time.pause_reasons.is_empty() and time.departure <= 0 and time.pending + 1e-10 >= STEP and steps < step_budget:
		time.pending = maxf(0.0, time.pending - STEP)
		consume_accepted_time(STEP)
		step_game(STEP)
		steps += 1

func consume_accepted_time(game_dt: float) -> void:
	var remaining := game_dt
	while remaining > 1e-10 and not time.accepted.is_empty():
		var segment: Dictionary = time.accepted[0]
		var consumed: float = minf(remaining, segment.game)
		segment.wall += consumed / segment.speed
		segment.game -= consumed
		remaining -= consumed
		time.sample_wall = segment.wall
		if segment.game < 1e-10: time.accepted.pop_front()

func step_game(dt: float) -> void:
	if time.ticks == 9223372036854775807:
		stopped_error = "IntegerRangeExceeded"
		return
	time.ticks += 1
	time.game = time.ticks * STEP
	spawn_timed_resources(dt)
	collect_due_drops()
	advance_campaign(dt)
	refresh_unlocks()
	change_number += 1
	var retained_wall: float = minf(time.wall, time.sample_wall)
	economy.income = economy.income.filter(func(sample): return sample.wall > retained_wall - 60 or sample.game > time.game - 60)

func spawn_timed_resources(dt: float) -> void:
	if campaign.phase == "menu": return
	economy.timed_elapsed += dt
	while economy.timed_elapsed + 1e-10 >= rules.timed_drop_interval:
		economy.timed_elapsed -= rules.timed_drop_interval
		var allocated: Dictionary = kernel.allocate_drop_id()
		if not allocated.ok:
			stopped_error = allocated.error
			return
		var id := str(allocated.id)
		var stage: Dictionary = bundle.lookup("level", [campaign.stage])
		var value := ceil_amount(mul(amount(rules.timed_drop_amount), SETUP.stage_ratio(self, stage, "resRatio")))
		var created: float = time.game - economy.timed_elapsed
		economy.drops[id] = {"id": id, "resource": str(int(profile.uranium_id)), "amount": value, "production_base": value,
			"due": created + maxf(0.0, geometry.player_y - geometry.timed_spawn_y) / rules.timed_drop_speed,
			"fragment": false, "jewel_ratio": amount(1), "source": "timed_drop", "x": geometry.center_x, "y": geometry.timed_spawn_y}

func income_per_second(resource: String, clock: String = "wall", production_base: bool = false) -> Dictionary:
	var total := amount(0)
	var now: float = time.wall if clock == "wall" else time.game
	for sample in economy.income:
		if sample.resource != resource or sample[clock] <= now - 60 or sample[clock] > now: continue
		if production_base and sample.source == "fragment_drop": continue
		total = add(total, sample.production_base if production_base else sample.actual)
	return calculate("div", total, amount(60)).value

func refresh_income_peak(resource: String) -> void:
	# Manual input can arrive while accepted time is queued. Re-evaluate the
	# retained chronological windows so processing order cannot change peaks.
	var samples: Array = economy.income.filter(func(sample): return sample.resource == resource and sample.source in ["enemy_drop", "timed_drop", "fragment_drop"])
	samples.sort_custom(func(a, b): return a.wall < b.wall if a.wall != b.wall else a.game < b.game)
	var total := amount(0)
	var peak: Dictionary = economy.peaks.get(resource, amount(0))
	var left := 0
	for right in range(samples.size()):
		total = add(total, samples[right].actual)
		while left <= right and samples[left].wall <= samples[right].wall - 60:
			total = calculate("sub_nonnegative", total, samples[left].actual).value
			left += 1
		peak = calculate("max", peak, calculate("div", total, amount(60)).value).value
	economy.peaks[resource] = peak

func refresh_unlocks() -> void:
	for row in _unlock_rows:
		if unlocked(row) and not notifications.seen.has(row.name):
			notifications.seen[row.name] = true
			if not settings.skip_guides: set_pause("unlock/" + row.name, true)

func current_points() -> Array:
	return SETUP.points(self, bundle.lookup("level", [campaign.stage]))

func advance_campaign(dt: float) -> void:
	if campaign.phase == "menu": return
	if campaign.phase == "retreat":
		campaign.retreat_elapsed += dt
		var ratio: float = 1.0 if campaign.retreat_elapsed + 1e-10 >= rules.retreat_seconds else campaign.retreat_elapsed / rules.retreat_seconds
		campaign.distance = lerpf(campaign.retreat_origin, campaign.retreat_target, ratio)
		if ratio >= 1:
			if not kernel.finish_retreat(): campaign.phase = "menu"
			else:
				campaign.phase = "travel"
				campaign.segment_origin = campaign.distance
		return
	if campaign.phase in ["clear_wait", "garrison_wait"]:
		advance_native(dt, time.game)
		if campaign.phase not in ["clear_wait", "garrison_wait"]: return
		campaign.wait -= dt
		if campaign.wait <= 1e-10:
			if campaign.phase == "garrison_wait":
				campaign.phase = "travel"
				campaign.segment_origin = campaign.distance
			else: continue_campaign()
		return
	if campaign.phase == "travel":
		var target: float = current_points()[campaign.point].distance
		var ship: Dictionary = bundle.lookup("ship", [equipment.ship_id])
		var speed: float = maxf(ship.para_3, (target - campaign.segment_origin) / rules.maximum_travel_seconds)
		var travel_dt: float = minf(dt, maxf(0.0, target - campaign.distance) / speed)
		if travel_dt > 0:
			campaign.distance += speed * travel_dt
			advance_native(travel_dt, time.game - dt + travel_dt)
		if campaign.phase != "travel" or not stopped_error.is_empty(): return
		if campaign.distance + 1e-8 >= target:
			campaign.distance = maxf(campaign.distance, target)
			var wave: Dictionary = SETUP.wave(self)
			if wave.has("error") or not kernel.start_wave(wave):
				stopped_error = wave.get("error", "NativeWaveAdmission")
				return
			campaign.phase = "combat"
			if dt > travel_dt + 1e-10: advance_native(dt - travel_dt, time.game)
		return
	advance_native(dt, time.game)

func advance_native(dt: float, global_end: float) -> void:
	if not kernel.advance(dt):
		stopped_error = kernel.last_error()
		if stopped_error.is_empty(): stopped_error = "NativeAdvanceRejected"
		return
	var result: Dictionary = kernel.take_results()
	for drop in result.drops:
		var id := str(int(drop.uid))
		var fragment: bool = str(drop.id) == profile.fragment_id
		var delay: float = rules.fragment_collect_delay if fragment else rules.auto_collect_delay
		var created: float = global_end - (result.clock - drop.created_at)
		economy.drops[id] = {"id": id, "resource": str(drop.id), "amount": amount(drop.amount) if not drop.amount is Dictionary else drop.amount,
			"production_base": drop.get("production_base", amount(drop.amount) if not drop.amount is Dictionary else drop.amount),
			"due": created + delay, "fragment": fragment, "jewel_ratio": drop.get("jewelRatio", 1.0),
			"source": "fragment_drop" if fragment else "enemy_drop", "x": drop.x, "y": drop.y}
	if result.player_died:
		begin_retreat()
	elif result.wave_cleared:
		if not kernel.finish_wave(result.final_cleared):
			stopped_error = "NativeWaveFinish"
			return
		if result.final_cleared:
			collect_all_drops()
			campaign.clearedStageIds[str(campaign.stage)] = true
			campaign.phase = "clear_wait"
			campaign.wait = rules.clear_wait_seconds
		else:
			campaign.phase = "travel"
		if not campaign.garrison.is_empty() and campaign.garrison.stage == campaign.stage and campaign.garrison.point == campaign.point:
			var list := current_points()
			var previous_distance: float = 0.0 if campaign.point == 0 else list[campaign.point - 1].distance
			var ship: Dictionary = bundle.lookup("ship", [equipment.ship_id])
			campaign.phase = "garrison_wait"
			campaign.wait = minf(rules.maximum_travel_seconds, (list[campaign.point].distance - previous_distance) / ship.para_3)
		elif not result.final_cleared:
			campaign.point += 1
			campaign.segment_origin = campaign.distance

func set_garrison(enabled: bool) -> Dictionary:
	if enabled:
		if campaign.phase in ["menu", "retreat"]: return {"ok": false, "reason": "NoGarrisonPoint"}
		campaign.garrison = {"stage": campaign.stage, "point": campaign.point, "distance": current_points()[campaign.point].distance}
	else:
		campaign.garrison = {}
		if campaign.phase == "garrison_wait":
			if campaign.point == current_points().size() - 1:
				campaign.phase = "clear_wait"
			else:
				campaign.point += 1
				campaign.phase = "travel"
				campaign.segment_origin = campaign.distance
	change_number += 1
	return {"ok": true}

func set_death_option(option: int) -> Dictionary:
	if option < 0 or option > 2: return {"ok": false, "reason": "InvalidDeathOption"}
	campaign.death_option = option
	change_number += 1
	return {"ok": true}

func continue_campaign() -> void:
	if not campaign.garrison.is_empty():
		campaign.stage = campaign.garrison.stage
		campaign.point = campaign.garrison.point
		campaign.distance = campaign.garrison.distance
	elif not bundle.lookup("level", [campaign.stage + 1]).is_empty():
		campaign.stage += 1
		campaign.highestReached = maxi(campaign.highestReached, campaign.stage)
		campaign.lifetimeHighestReached = maxi(campaign.lifetimeHighestReached, campaign.stage)
		campaign.point = 0
		campaign.distance = 0.0
	else:
		campaign.phase = "menu"
		return
	campaign.phase = "travel"
	campaign.segment_origin = campaign.distance

func begin_retreat() -> Dictionary:
	if campaign.phase in ["menu", "retreat"]: return {"ok": false, "reason": "NoActiveJourney"}
	if not kernel.begin_retreat(): return {"ok": false, "reason": "NativeRetreatRejected"}
	var target: float = campaign.distance - rules.back_distance
	var origin: float = campaign.distance
	while target < 0 and campaign.stage > int(profile.initial_stage):
		campaign.stage -= 1
		var length: float = bundle.lookup("level", [campaign.stage]).length
		target += length
		origin += length
	campaign.phase = "retreat"
	campaign.distance = origin
	campaign.retreat_origin = origin
	campaign.retreat_target = maxf(0.0, target)
	campaign.retreat_elapsed = 0.0
	campaign.point = 0
	var list := current_points()
	while campaign.point + 1 < list.size() and list[campaign.point].distance < campaign.retreat_target: campaign.point += 1
	if campaign.death_option == 0: campaign.garrison = {}
	elif campaign.death_option == 2: campaign.garrison = {"stage": campaign.stage, "point": campaign.point, "distance": campaign.retreat_target}
	return {"ok": true}

func collect_drop(id: String, automatic: bool = false) -> Dictionary:
	if economy.claimed.has(id) or not economy.drops.has(id): return {"ok": false, "reason": "NoChange"}
	var drop: Dictionary = economy.drops[id]
	var value: Dictionary = drop.amount
	var base: Dictionary = drop.production_base
	if drop.fragment:
		value = mul(value, amount(drop.jewel_ratio))
		value = calculate("div", calculate("floor", add(mul(value, amount(100)), amount(0.5))).value, amount(100)).value
	elif automatic:
		value = ceil_amount(mul(value, amount(1.0 - rules.auto_collect_reduce)))
		base = ceil_amount(mul(base, amount(1.0 - rules.auto_collect_reduce)))
	if not economy.wallet.has(drop.resource): economy.wallet[drop.resource] = amount(0)
	economy.wallet[drop.resource] = add(economy.wallet[drop.resource], value)
	economy.income.append({"resource": drop.resource, "source": drop.source, "actual": value,
		"production_base": base, "wall": time.sample_wall if automatic else time.wall, "game": time.game})
	refresh_income_peak(drop.resource)
	economy.claimed[id] = true
	economy.drops.erase(id)
	change_number += 1
	return {"ok": true, "amount": value}

func collect_due_drops() -> void:
	for id in economy.drops.keys():
		if economy.drops[id].due <= time.game + 1e-10: collect_drop(id, true)

func collect_all_drops() -> void:
	for id in economy.drops.keys(): collect_drop(id, true)

func view() -> Dictionary:
	return {"campaign": campaign.duplicate(true), "wallet": economy.wallet.duplicate(true), "drops": economy.drops.duplicate(true),
		"player": kernel.player_view(), "history": kernel.read_history(), "time": time.duplicate(true), "error": stopped_error}
