extends RefCounted
var _run_state
signal members_changed(ids: Array)
signal options_changed
const FACTOR_JOBS := {"equipment_upgrade": "equipment", "reactor_upgrade": "capacity", "jewel_auto": "fragments", "hightech_scientists": "research"}
const JOB_NAMES := {"equipment_upgrade": "装备升级", "hightech_scientists": "科研", "jewel_auto": "强化", "reactor_upgrade": "反应炉"}

var _members: Dictionary
var _definitions: Dictionary = {}
var _rules: Dictionary = {}
var _jobs: Dictionary = {}
var _available: Dictionary = {}
var _features: Dictionary = {}
var _factors: Dictionary = {}
var _dirty_jobs: Array = []
var _api

func _init(rows: Array, rules: Array, jobs: Array, api, run_state) -> void:
	_run_state = run_state
	for row in rows: _definitions[str(row.id)] = row
	for row in rules: _rules[str(row.id)] = row.value
	for row in jobs: _jobs[str(row.id)] = row
	_api = api
	_members = _initial(_definitions, api)

func refresh_availability(unlocked: Callable, notify: bool = true) -> bool:
	if not _run_state.is_running(): return false
	var next: Dictionary = {}
	for id in _definitions: next[id] = bool(unlocked.call("crew", id))
	var features := {"levels": bool(unlocked.call("feature", "crew_level")), "jewels": bool(unlocked.call("feature", "jewels")), "reactor": bool(unlocked.call("feature", "reactor"))}
	if next != _available or features != _features:
		_available = next
		_features = features
		if notify: options_changed.emit()
		return true
	return false

func publish_availability() -> void:
	options_changed.emit()

func experience_enabled() -> bool:
	return _features.levels

func _mark_jobs(jobs: Array) -> void:
	for job in jobs:
		if job not in _dirty_jobs: _dirty_jobs.append(job)

func contributions() -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var result = _contributions(_members, _definitions, _jobs, _rules, _api, _factors, _dirty_jobs)
	if result.ok:
		result.make_read_only()
		_factors = result
		_dirty_jobs = []
	return result

func step_assignments() -> Dictionary:
	return _step_assignments(_members)

func hyperspace_candidate(id: String) -> Dictionary:
	if not _members.has(id) or not _available.get(id, false): return {"ok": false, "reason": "CrewLocked"}
	if not str(_members[id].kind).is_empty(): return {"ok": false, "reason": "CrewOccupied"}
	return {"ok": true, "level": int(_members[id].level)}

func reserve_hyperspace(id: String, route: String, notify: bool = true) -> void:
	_assign(_members, id, "hyperspace", route, 1, str(_members[id].mode))
	if notify: members_changed.emit([id])

func release_hyperspace(route: String, notify: bool = true) -> Array:
	return release("hyperspace", route, notify)

func assign(id: String, kind: String, target: String, mode: String, target_admission: Callable, notify: bool = true) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _members.has(id) or not _available.get(id, false): return {"ok": false, "reason": "CrewLocked"}
	var capacity: int = 0
	if kind == "system_job":
		if not _jobs.has(target) or _jobs[target].targetType == "galaxy": return {"ok": false, "reason": "UnknownCrewJob"}
		if (target == "jewel_auto" and not _features.jewels) or (target == "reactor_upgrade" and not _features.reactor): return {"ok": false, "reason": "CrewJobLocked"}
		capacity = int(_jobs[target].maxCrew)
	elif kind in ["planet_explore", "planet_build", "galaxy"]:
		var admitted: Dictionary = target_admission.call(kind, target)
		if not admitted.ok: return admitted
		capacity = int(_jobs.galaxy_explore.maxCrew) if kind == "galaxy" else int(admitted.capacity)
	elif not kind.is_empty(): return {"ok": false, "reason": "CrewAssignmentUnavailable"}
	var old_kind: String = str(_members[id].kind)
	var old_target: String = str(_members[id].target)
	if old_kind == "hyperspace": return {"ok": false, "reason": "HyperspaceCrewReserved"}
	var selected_mode: String = mode if kind == "system_job" and target == "equipment_upgrade" else str(_members[id].mode)
	var changed = _assign(_members, id, kind, target if not kind.is_empty() else "", capacity, selected_mode)
	if not changed.ok: return changed
	_mark_jobs(changed.jobs)
	if notify: members_changed.emit([id])
	return {"ok": true, "old_kind": old_kind, "old_target": old_target, "effects_changed": not changed.jobs.is_empty()}

func release(kind: String, target: String, notify: bool = true) -> Array:
	if not _run_state.is_running(): return []
	var ids = _release(_members, kind, target)
	if notify and not ids.is_empty(): members_changed.emit(ids)
	return ids

func award_exploration(explorer: String, share: bool, amount: Dictionary, notify: bool = true) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var result = _add_experience(_members, _members.keys() if share else [explorer], amount, _rules, _api)
	if result.ok:
		_mark_jobs(result.jobs)
		if notify and not result.members.is_empty(): members_changed.emit(result.members)
		result.effects_changed = not result.jobs.is_empty()
	return result

func publish_members(ids: Array) -> void:
	if not ids.is_empty(): members_changed.emit(ids)

func advance_jobs(ids: Array, dt: float) -> Array:
	if not _run_state.is_running(): return []
	var requests: Array = []
	for attempt in _advance_jobs(_members, ids, _jobs, dt):
		if attempt.job == "equipment_upgrade": requests.append({"module": "equipment", "count": 1 if attempt.mode == "max" else int(attempt.mode), "maximum": attempt.mode == "max"})
		elif attempt.job == "jewel_auto": requests.append({"module": "enhancement", "count": 1})
		elif attempt.job == "reactor_upgrade": requests.append({"module": "reactor", "count": 1, "automatic": true})
	return requests

func member_options(ids: Array = []) -> Array:
	var rows: Array = []
	for id in (_definitions.keys() if ids.is_empty() else ids):
		if not _available.get(id, false): continue
		rows.append({"id": str(id), "name": str(_definitions[id].name) + (" · Lv." + str(_members[id].level) if _features.levels else "")})
	return rows

func job_options() -> Array:
	var rows: Array = []
	for job in JOB_NAMES: rows.append({"label": JOB_NAMES[job], "kind": "system_job", "target": job})
	return rows

func status_rows(ids: Array = []) -> Array:
	var rows: Array = []
	for id in (_definitions.keys() if ids.is_empty() else ids):
		if not _available.get(id, false): continue
		var member: Dictionary = _members[id]
		var job: String = str(JOB_NAMES.get(member.target, member.target)) if member.kind == "system_job" else str({"": "空闲", "planet_explore": "行星探索", "planet_build": "行星施工", "galaxy": "星系建设"}.get(member.kind, member.kind))
		var text: String = "%s · %s" % [_definitions[id].name, job]
		if _features.levels:
			var experience = _api.apply("to_display", [member.exp])
			text = "%s Lv.%d · %s · 经验 %s" % [_definitions[id].name, int(member.level), job, experience.text]
		rows.append({"id": str(id), "text": text})
	return rows

static func _initial(definitions: Dictionary, api) -> Dictionary:
	var members: Dictionary = {}
	for id in definitions:
		members[id] = {"level": 0, "exp": api.apply("zero", []).value, "kind": "", "target": "", "mode": "1", "elapsed": 0.0}
	return members

static func _step_assignments(members: Dictionary) -> Dictionary:
	var views: Dictionary = {"explorers": {}, "builders": {}, "galaxies": {}, "jobs": []}
	for id in members:
		var member: Dictionary = members[id]
		if member.kind == "system_job": views.jobs.append(id)
		elif member.kind == "galaxy": views.galaxies[member.target] = int(views.galaxies.get(member.target, 0)) + 1
		elif member.kind in ["planet_explore", "planet_build"]:
			var group: Dictionary = views.explorers if member.kind == "planet_explore" else views.builders
			if not group.has(member.target): group[member.target] = []
			group[member.target].append(id)
	for group in [views.explorers, views.builders]:
		for ids in group.values(): ids.sort()
	return views

static func _assigned(members: Dictionary, kind: String, target: String) -> Array:
	var found: Array = []
	for id in members:
		if members[id].kind == kind and members[id].target == target:
			found.append(id)
	found.sort()
	return found

static func _assign(members: Dictionary, id: String, kind: String, target: String, capacity: int, mode: String) -> Dictionary:
	if not members.has(id) or mode not in ["1", "10", "max"]:
		return {"ok": false, "reason": "InvalidCrewAssignment"}
	var occupied: Array = _assigned(members, kind, target) if not kind.is_empty() else []
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

static func _release(members: Dictionary, kind: String, target: String) -> Array:
	var ids: Array = _assigned(members, kind, target)
	for id in ids: _assign(members, id, "", "", 0, str(members[id].mode))
	return ids

static func _job_factor(members: Dictionary, definitions: Dictionary, jobs: Dictionary, job: String, rules: Dictionary, api) -> Dictionary:
	var ids: Array = _assigned(members, "system_job", job)
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

static func _contributions(members: Dictionary, definitions: Dictionary, jobs: Dictionary, rules: Dictionary, api, previous: Dictionary = {}, changed_jobs: Array = []) -> Dictionary:
	var result: Dictionary = previous.duplicate()
	if result.is_empty():
		result = {"ok": true, "research_staffed": false}
		var one: Dictionary = api.apply("from_decimal", ["1"]).value
		for effect in FACTOR_JOBS.values(): result[effect] = one
	for job in changed_jobs:
		var value = _job_factor(members, definitions, jobs, job, rules, api)
		if not value.ok: return value
		result[FACTOR_JOBS[job]] = value.value
		if job == "hightech_scientists": result.research_staffed = value.staffed
	return result

static func _advance_jobs(members: Dictionary, ids: Array, jobs: Dictionary, dt: float) -> Array:
	var due: Array = []
	for id in ids:
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

static func _experience_cost(level: int, count: int, rules: Dictionary, api) -> Dictionary:
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

static func _add_experience(members: Dictionary, recipients: Array, amount: Dictionary, rules: Dictionary, api) -> Dictionary:
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
		var accepted: Dictionary = {}
		var low: int = 0
		var high: int = mini(1, limit)
		while high > 0:
			var cost = _experience_cost(int(member.level), high, rules, api)
			if not cost.ok or api.apply("compare", [cost.value, balance.value]).scalar > 0:
				break
			low = high
			accepted = cost
			if high == limit:
				return {"ok": false, "reason": "CrewLevelRangeExceeded"}
			@warning_ignore("integer_division")
			high = limit if high > limit / 2 else high * 2
		while low + 1 < high:
			@warning_ignore("integer_division")
			var middle: int = low + (high - low) / 2
			var cost = _experience_cost(int(member.level), middle, rules, api)
			if cost.ok and api.apply("compare", [cost.value, balance.value]).scalar <= 0:
				low = middle
				accepted = cost
			else:
				high = middle
		if low > 0:
			balance = api.apply("sub_nonnegative", [balance.value, accepted.value])
			if not balance.ok:
				return balance
		if low > 0 and member.kind == "system_job" and FACTOR_JOBS.has(member.target) and member.target not in changed_jobs: changed_jobs.append(member.target)
		if low > 0 or member.exp != balance.value: changed_members.append(id)
		member.level = int(member.level) + low
		member.exp = balance.value
	return {"ok": true, "jobs": changed_jobs, "members": changed_members}
