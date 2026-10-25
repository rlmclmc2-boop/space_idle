extends RefCounted
const FACTOR_JOBS := {"equipment_upgrade": "equipment", "reactor_upgrade": "capacity", "jewel_auto": "fragments", "hightech_scientists": "research"}
## Session owns this data. Members' kind/target are the only personnel registry.

static func initial(definitions: Dictionary, api) -> Dictionary:
	var members: Dictionary = {}
	for id in definitions:
		members[id] = {"level": 0, "exp": api.apply("zero", []).value, "kind": "", "target": "", "mode": "1", "elapsed": 0.0}
	return members

static func assigned(members: Dictionary, kind: String, target: String) -> Array:
	var found: Array = []
	for id in members:
		if members[id].kind == kind and members[id].target == target:
			found.append(id)
	found.sort()
	return found

static func assign(members: Dictionary, id: String, kind: String, target: String, capacity: int, mode: String) -> Dictionary:
	if not members.has(id) or mode not in ["1", "10", "max"]:
		return {"ok": false, "reason": "InvalidCrewAssignment"}
	var occupied: Array = assigned(members, kind, target) if not kind.is_empty() else []
	occupied.erase(id)
	if not kind.is_empty() and occupied.size() >= capacity:
		return {"ok": false, "reason": "CrewTargetOccupied"}
	var member: Dictionary = members[id]
	if member.kind == kind and member.target == target and member.mode == mode:
		return {"ok": false, "reason": "NoChange"}
	var changed_jobs: Array = []
	if member.kind != kind or member.target != target:
		if member.kind == "system_job" and FACTOR_JOBS.has(member.target): changed_jobs.append(member.target)
		if kind == "system_job" and FACTOR_JOBS.has(target) and target not in changed_jobs: changed_jobs.append(target)
	if member.kind != kind or member.target != target:
		member.elapsed = 0.0
	member.kind = kind
	member.target = target
	member.mode = mode
	return {"ok": true, "jobs": changed_jobs}

static func release(members: Dictionary, kind: String, target: String) -> void:
	for id in assigned(members, kind, target):
		assign(members, id, "", "", 0, str(members[id].mode))

static func job_factor(members: Dictionary, definitions: Dictionary, jobs: Dictionary, job: String, rules: Dictionary, api) -> Dictionary:
	var ids: Array = assigned(members, "system_job", job)
	if ids.is_empty():
		var result = api.apply("from_decimal", ["1"])
		result.staffed = false
		return result
	var id: String = str(ids[0])
	var row: Dictionary = jobs[job]
	# levelScale deliberately does not enter the general assignment function.
	var base: float = float(row.baseValue) * pow(float(definitions[id].basePower), float(row.powerScale))
	var level: int = int(members[id].level)
	var value: Dictionary
	if job == "equipment_upgrade":
		value = api.apply("from_decimal", [str(1.0 + float(rules.equip_bonus))])
		value = api.apply("pow", [value.value, level])
	else:
		var key: String = "tech_speed" if job == "hightech_scientists" else "gem_bonus" if job == "jewel_auto" else "charge_bonus"
		value = api.apply("from_decimal", [str(1.0 + float(rules[key]) * level)])
	if not value.ok:
		return value
	var power = api.apply("from_decimal", [str(base)])
	if not power.ok:
		return power
	var result = api.apply("mul", [value.value, power.value])
	result.staffed = true
	return result

static func contributions(members: Dictionary, definitions: Dictionary, jobs: Dictionary, rules: Dictionary, api, previous: Dictionary = {}, changed_jobs: Array = []) -> Dictionary:
	var result: Dictionary = previous.duplicate()
	if result.is_empty():
		result = {"ok": true, "research_staffed": false}
		var one: Dictionary = api.apply("from_decimal", ["1"]).value
		for effect in FACTOR_JOBS.values(): result[effect] = one
	for job in changed_jobs:
		var value = job_factor(members, definitions, jobs, job, rules, api)
		if not value.ok: return value
		result[FACTOR_JOBS[job]] = value.value
		if job == "hightech_scientists": result.research_staffed = value.staffed
	return result

static func advance_jobs(members: Dictionary, jobs: Dictionary, dt: float) -> Array:
	var due: Array = []
	for id in members:
		var member: Dictionary = members[id]
		if member.kind != "system_job" or not jobs.has(member.target):
			continue
		var interval: float = float(jobs[member.target].interval)
		if interval <= 0.0:
			continue # Scientists use research completion and its own investment clock.
		member.elapsed = float(member.elapsed) + dt
		if float(member.elapsed) + 1e-9 >= interval:
			member.elapsed = maxf(0.0, float(member.elapsed) - interval)
			due.append({"id": id, "job": str(member.target), "mode": str(member.mode)})
	return due

static func experience_cost(level: int, count: int, rules: Dictionary, api) -> Dictionary:
	var base = api.apply("from_decimal", [str(rules.base_exp)])
	var growth = api.apply("from_decimal", [str(rules.exp_multiplier)])
	var threshold: Dictionary = api.apply("from_decimal", ["1e15"]).value
	var half: Dictionary = api.apply("from_decimal", ["0.5"]).value
	var total: Dictionary = api.apply("zero", []).value
	if not base.ok or not growth.ok:
		return base if not base.ok else growth
	var factor = api.apply("pow", [growth.value, level])
	if not factor.ok:
		return factor
	var raw = api.apply("mul", [base.value, factor.value])
	if not raw.ok:
		return raw
	var unit: Dictionary = raw.value
	var index: int = 0
	# Only the finite ordinary-precision prefix is rounded per level.
	while index < count and api.apply("compare", [unit, threshold]).scalar < 0:
		var price = api.apply("add", [unit, half])
		price = api.apply("floor", [price.value])
		var sum = api.apply("add", [total, price.value])
		if not sum.ok:
			return sum
		total = sum.value
		index += 1
		if api.apply("compare", [total, threshold]).scalar >= 0:
			break
		var power = api.apply("pow", [growth.value, level + index])
		if not power.ok:
			return power
		var next = api.apply("mul", [base.value, power.value])
		if not next.ok:
			return next
		unit = next.value
	if index == count:
		return {"ok": true, "value": total}
	var series = api.apply("sum_geometric", [float(rules.exp_multiplier), str(count)])
	if not series.ok:
		return series
	return api.apply("mul", [raw.value, series.value])

static func add_experience(members: Dictionary, recipients: Array, amount: Dictionary, rules: Dictionary, api) -> Dictionary:
	var changed_jobs: Array = []
	var changed_members: Array = []
	for id in recipients:
		if not members.has(id):
			return {"ok": false, "reason": "UnknownCrew"}
		var member: Dictionary = members[id]
		var balance = api.apply("add", [member.exp, amount])
		if not balance.ok:
			return balance
		var limit: int = 9223372036854775807 - int(member.level)
		if limit <= 0:
			return {"ok": false, "reason": "CrewLevelRangeExceeded"}
		var low: int = 0
		var high: int = mini(1, limit)
		while high > 0:
			var cost = experience_cost(int(member.level), high, rules, api)
			if not cost.ok or api.apply("compare", [cost.value, balance.value]).scalar > 0:
				break
			low = high
			if high == limit:
				return {"ok": false, "reason": "CrewLevelRangeExceeded"}
			@warning_ignore("integer_division")
			high = limit if high > limit / 2 else high * 2
		while low + 1 < high:
			@warning_ignore("integer_division")
			var middle: int = low + (high - low) / 2
			var cost = experience_cost(int(member.level), middle, rules, api)
			if cost.ok and api.apply("compare", [cost.value, balance.value]).scalar <= 0:
				low = middle
			else:
				high = middle
		if low > 0:
			var cost = experience_cost(int(member.level), low, rules, api)
			balance = api.apply("sub_nonnegative", [balance.value, cost.value])
			if not balance.ok:
				return balance
		if low > 0 and member.kind == "system_job" and FACTOR_JOBS.has(member.target) and member.target not in changed_jobs: changed_jobs.append(member.target)
		if low > 0 or member.exp != balance.value: changed_members.append(id)
		member.level = int(member.level) + low
		member.exp = balance.value
	return {"ok": true, "jobs": changed_jobs, "members": changed_members}
