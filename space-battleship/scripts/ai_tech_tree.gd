extends RefCounted

# Research is measured in unaccelerated game seconds. Resource inputs are
# integer units per game second; only paid intervals contribute their factor.
const N = preload("res://scripts/growth_number.gd")

static func level(game, id: String) -> int:
	return int(game.profile.aiTechLevels.get(id, 0))

static func ai_count(game) -> int:
	return 1 + level(game, "singularity")

static func required(game, id: String) -> float:
	var row: Dictionary = game.db.data.ai_tech_tree.get(id, {})
	if row.is_empty():return INF
	var exponent := float(level(game, id)) * log(float(row.growth))
	if exponent > 700.0:return INF
	return float(row.base_seconds) * exp(exponent)

static func eligibility(game, id: String) -> Dictionary:
	var row: Dictionary = game.db.data.ai_tech_tree.get(id, {})
	if row.is_empty():return {"ok":false,"reason":"unknown"}
	if str(row.get("unlock", "")) == "enhancement" and not game.enhancement_unlocked():
		return {"ok":false,"reason":"enhancement_locked"}
	var target := level(game, id) + 1
	for prerequisite in row.get("requirements", {}):
		var condition = row.requirements[prerequisite]
		var minimum := 10 * target + 1 if condition is String and condition == "10*k+1" else int(condition)
		if level(game, prerequisite) < minimum:
			return {"ok":false,"reason":"prerequisite","id":prerequisite,"level":minimum}
	return {"ok":true}

static func select(game, id: String) -> bool:
	if id == game.profile.aiTechActive:return false
	if not id.is_empty() and not bool(eligibility(game, id).ok):return false
	game.profile.aiTechActive = id
	game.save_dirty = true
	game.event.emit("tech_tree_changed", {"reason":"selection","id":id})
	return true

static func set_input(game, resource_id: String, amount: int) -> bool:
	if resource_id not in ["1", "2"] or amount < 0 or amount > 9007199254740991:return false
	if int(game.profile.aiTechInput.get(resource_id, 0)) == amount:return false
	game.profile.aiTechInput[resource_id] = amount
	game.save_dirty = true
	game.event.emit("tech_tree_changed", {"reason":"input","resource":resource_id})
	return true

static func input_factor(amount: int) -> float:
	return 1.0 if amount <= 0 else 1.0 + log(float(amount)) / log(10.0) / 4.0

static func income_factor(game, id: String) -> Variant:
	var cache_key := "ai_tech_factor_" + id
	if game.stat_cache_enabled and game.stat_cache.has(cache_key):return game.stat_cache[cache_key]
	var result: Variant = 1.0
	for tech in game.db.data.ai_tech_tree:
		var row: Dictionary = game.db.data.ai_tech_tree[tech]
		if id in str(row.effect).split(",") and tech != "unification" and tech != "singularity":
			result = N.multiply(result, N.power(float(row.factor), level(game, tech)))
	if game.stat_cache_enabled:game.stat_cache[cache_key] = result
	return result

static func peak_product(game) -> Variant:
	var value: Variant = 1.0
	for id in ["1", "2", "jewel"]:
		var peak = game.profile.aiIncomePeak.get(id, 0.0)
		if N.compare(peak,0) > 0:value = N.multiply(value,1.0 + N.logarithm(peak) / 5.0)
	return value

static func peak_factor(game) -> Variant:
	return 1.0 if level(game, "unification") == 0 else N.multiply(float(level(game, "unification")),peak_product(game))

static func combat_factor(game, id: String) -> Variant:
	return N.multiply(income_factor(game, id), peak_factor(game))

static func record_income(game, id: String) -> void:
	if id not in ["1", "2", "jewel"]:return
	# The resource strip reports the rolling minute as an average per second.
	var rate = N.divide(game.resource_minute_total(id),60.0)
	if N.compare(rate,game.profile.aiIncomePeak.get(id, 0.0)) > 0:
		game.profile.aiIncomePeak[id] = rate
		if level(game, "unification") > 0:
			game.invalidate_stat_cache()
			game.event.emit("tech_tree_changed", {"reason":"income_peak","id":id})

static func snapshot(game) -> Dictionary:
	var selected := str(game.profile.aiTechActive)
	var inputs := {}
	var acceleration := float(ai_count(game) + 9) / 10.0
	for resource_id in ["1", "2"]:
		var amount := int(game.profile.aiTechInput.get(resource_id, 0))
		var affordable := amount == 0 or N.compare(game.profile.resources.get(resource_id, 0), 0) > 0
		var factor := input_factor(amount) if affordable else 1.0
		inputs[resource_id] = {"amount":amount,"factor":factor,"shortage":amount > 0 and not affordable}
		acceleration *= factor
	var nodes := []
	for id in game.db.data.ai_tech_tree:
		var row: Dictionary = game.db.data.ai_tech_tree[id]
		var cost := required(game, id)
		var progress := float(game.profile.aiTechProgress.get(id, 0.0))
		var current: Variant = N.power(float(row.factor),level(game,id))
		var next: Variant = N.power(float(row.factor),level(game,id)+1)
		if id == "singularity":
			current = ai_count(game)
			next = ai_count(game)+1
		elif id == "unification":
			current = peak_factor(game)
			next = N.multiply(float(level(game,id)+1),peak_product(game))
		nodes.append({"id":id,"name":str(row.name),"description":str(row.description),"tier":str(row.tier),"level":level(game,id),"effect":str(row.effect),"factor":float(row.factor),"current_multiplier":current,"next_multiplier":next,"requirements":row.get("requirements",{}),"eligibility":eligibility(game,id),"required_seconds":cost,"progress_seconds":progress,"percent":clampi(int(floor(100.0*progress/cost)),0,99) if is_finite(cost) else 0})
	var remaining := INF
	if not selected.is_empty() and acceleration > 0.0:
		remaining = maxf(0.0, required(game, selected)-float(game.profile.aiTechProgress.get(selected,0.0)))/acceleration
	return {"nodes":nodes,"selected":selected,"inputs":inputs,"ai_count":ai_count(game),"speed":acceleration,"remaining_seconds":remaining,"status":"idle" if selected.is_empty() else "researching"}

static func advance(game, dt: float) -> void:
	if dt <= 0.0 or not is_finite(dt):return
	var id := str(game.profile.aiTechActive)
	if id.is_empty():return
	var remaining := dt
	var paid := {}
	var changed := false
	var iterations := 0
	while remaining > 0.0000000001 and not id.is_empty() and iterations < 256:
		iterations += 1
		if not bool(eligibility(game,id).ok):
			game.profile.aiTechActive = ""
			game.event.emit("tech_tree_changed", {"reason":"prerequisite_stopped","id":id})
			break
		var step := remaining
		var speed := float(ai_count(game) + 9) / 10.0
		var factors := {}
		for resource_id in ["1", "2"]:
			var amount := int(game.profile.aiTechInput.get(resource_id, 0))
			if amount <= 0 or N.compare(game.profile.resources.get(resource_id,0),0) <= 0:continue
			var balance = game.profile.resources.get(resource_id,0)
			if N.compare(balance,float(amount)*remaining) < 0:
				step = minf(step,float(balance)/float(amount))
			factors[resource_id] = amount
			speed *= input_factor(amount)
		var cost := required(game,id)
		if not is_finite(cost):break
		var progress := float(game.profile.aiTechProgress.get(id,0.0))
		if cost-progress <= maxf(1.0,cost)*1e-12:
			game.profile.aiTechProgress[id] = 0.0
			game.profile.aiTechLevels[id] = level(game,id) + 1
			game.invalidate_stat_cache()
			game.event.emit("hightech_complete", {"key":id})
			changed = true
			if not bool(eligibility(game,id).ok):
				game.profile.aiTechActive = ""
				game.event.emit("tech_tree_changed", {"reason":"prerequisite_stopped","id":id})
				break
			continue
		step = minf(step, maxf(0.0, cost-progress)/speed)
		if step <= 0.0000000001:
			for resource_id in factors:
				if N.compare(game.profile.resources.get(resource_id,0),float(factors[resource_id])*0.0000000001) < 0:
					game.profile.resources[resource_id] = 0.0
			continue
		for resource_id in factors:
			var expense := float(factors[resource_id])*step
			var next_balance = N.subtract(game.profile.resources.get(resource_id,0),expense)
			game.profile.resources[resource_id] = next_balance if N.compare(next_balance,0) > 0 else 0.0
			paid[resource_id] = true
		game.profile.aiTechProgress[id] = progress + step*speed
		remaining -= step
		changed = true
		if float(game.profile.aiTechProgress[id]) + maxf(1.0,cost)*1e-12 >= cost:
			game.profile.aiTechProgress[id] = 0.0
			game.profile.aiTechLevels[id] = level(game,id) + 1
			game.invalidate_stat_cache()
			game.event.emit("hightech_complete", {"key":id})
			if not bool(eligibility(game,id).ok):
				game.profile.aiTechActive = ""
				game.event.emit("tech_tree_changed", {"reason":"prerequisite_stopped","id":id})
				break
		id = str(game.profile.aiTechActive)
	if changed:
		game.save_dirty = true
		var now_ms := Time.get_ticks_msec()
		if not paid.is_empty() and now_ms-game.ai_tech_last_resource_notice_ms >= 250:
			game.ai_tech_last_resource_notice_ms = now_ms
			game.resources_changed(paid.keys())
