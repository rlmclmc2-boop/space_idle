extends RefCounted

static func initial(rules: Dictionary) -> Dictionary:
	return {"levels": {}, "work": {}, "current": "", "investment": {},
		"auto_invest": false, "ratio": float(rules.research_default_ratio), "contributions": {}, "refresh_elapsed": 0.0,
		"peaks": {}, "required_work": {}, "gates": {}, "available": {}}

static func select(state: Dictionary, id: String) -> Dictionary:
	if not state.available.get(id, false):
		return {"ok": false, "reason": "ResearchLocked"}
	state.current = id
	return {"ok": true}

static func refresh_gates(state: Dictionary, definitions: Dictionary, gates: Dictionary) -> void:
	if state.gates == gates and not state.available.is_empty(): return
	state.gates = gates
	_refresh_available(state, definitions)

static func _refresh_available(state: Dictionary, definitions: Dictionary) -> void:
	for id in definitions: state.available[id] = available(definitions[id], state.levels, state.gates)

static func choices(state: Dictionary) -> Dictionary:
	return state.available.duplicate()

static func set_investment(state: Dictionary, resource: String, quantity: Dictionary, api) -> Dictionary:
	if resource not in ["1", "2"]: return {"ok": false, "reason": "InvalidResearchResource"}
	var value = api.apply("floor", [quantity])
	if not value.ok: return value
	state.investment[resource] = value.value
	return {"ok": true}

static func set_automatic(state: Dictionary, enabled: bool, ratio: float, rules: Dictionary) -> Dictionary:
	if not is_finite(ratio) or ratio < float(rules.research_minimum_ratio) or ratio > 1.0:
		return {"ok": false, "reason": "InvalidResearchRatio"}
	state.auto_invest = enabled
	state.ratio = ratio
	return {"ok": true}

static func automatic_due(state: Dictionary, assigned: bool, rules: Dictionary) -> bool:
	return assigned and state.auto_invest and float(state.refresh_elapsed) >= float(rules.research_income_window)

static func contributions(state: Dictionary, definitions: Dictionary, rules: Dictionary, api) -> Dictionary:
	for effect in ["weapon_damage", "equipment_durability", "iron_income", "uranium_income", "fragment_income"]:
		if state.contributions.has(effect): continue
		var value = factor(state, definitions, effect, rules, api)
		if not value.ok: return value
		state.contributions[effect] = value.value
	return {"ok": true, "values": state.contributions.duplicate()}

static func available(row: Dictionary, levels: Dictionary, gates: Dictionary) -> bool:
	if not gates.get(str(row.id), false):
		return false
	if row.requirements == null:
		return true
	var target: int = int(levels.get(str(row.id), 0)) + 1
	for requirement in str(row.requirements).split(";", false):
		var parts: PackedStringArray = requirement.split(":")
		var threshold: int = 10 * target + 1 if parts[1] == "10*k+1" else int(parts[1])
		if int(levels.get(parts[0], 0)) < threshold:
			return false
	return true

static func required_work(state: Dictionary, row: Dictionary, api) -> Dictionary:
	var key: String = str(row.id)
	if state.required_work.has(key): return {"ok": true, "value": state.required_work[key]}
	var level: int = int(state.levels.get(key, 0))
	var base = api.apply("from_decimal", [str(row.base_seconds)])
	var growth = api.apply("from_decimal", [str(row.growth)])
	for result in [base, growth]:
		if not result.ok:
			return result
	growth = api.apply("pow", [growth.value, level])
	if not growth.ok:
		return growth
	var result = api.apply("mul", [base.value, growth.value])
	if result.ok: state.required_work[key] = result.value
	return result

static func factor(state: Dictionary, definitions: Dictionary, effect: String, rules: Dictionary, api) -> Dictionary:
	var value = api.apply("from_decimal", ["1"])
	for key in definitions:
		var row: Dictionary = definitions[key]
		var level: int = int(state.levels.get(key, 0))
		if level == 0 or effect not in str(row.effect).split(","):
			continue
		var multiplier: Dictionary
		if key == "unification":
			multiplier = api.apply("from_decimal", [str(level)])
			for resource in ["1", "2", "jewel"]:
				var peak: Dictionary = state.peaks.get(resource, api.apply("zero", []).value)
				if api.apply("compare", [peak, api.apply("zero", []).value]).scalar <= 0:
					continue
				var logarithm = api.apply("log10", [peak])
				if not logarithm.ok:
					return logarithm
				var part = api.apply("from_decimal", [str(maxf(1.0, 1.0 + logarithm.scalar / float(rules.research_peak_log_divisor)))])
				multiplier = api.apply("mul", [multiplier.value, part.value])
				if not multiplier.ok:
					return multiplier
		else:
			multiplier = api.apply("from_decimal", [str(row.factor)])
			if not multiplier.ok:
				return multiplier
			multiplier = api.apply("pow", [multiplier.value, level])
		if not multiplier.ok:
			return multiplier
		value = api.apply("mul", [value.value, multiplier.value])
		if not value.ok:
			return value
	return value

static func refresh_income(state: Dictionary, definitions: Dictionary, peak_rates: Dictionary, investment_rates: Dictionary, rules: Dictionary, api, income_changed: bool, automatic_due: bool) -> Dictionary:
	if not income_changed and not automatic_due:
		return {"ok": true, "state": state, "factors_changed": false}
	var next: Dictionary = state.duplicate()
	next.peaks = state.peaks.duplicate()
	next.investment = state.investment.duplicate()
	next.contributions = state.contributions.duplicate()
	var zero: Dictionary = api.apply("zero", []).value
	if income_changed:
		for resource in ["1", "2", "jewel"]:
			var peak = api.apply("max", [next.peaks.get(resource, zero), peak_rates[resource]])
			if not peak.ok:
				return peak
			next.peaks[resource] = peak.value
	if automatic_due:
		next.refresh_elapsed = fmod(float(next.refresh_elapsed), float(rules.research_income_window))
		var ratio = api.apply("from_decimal", [str(next.ratio)])
		var one = api.apply("from_decimal", ["1"])
		for resource in ["1", "2"]:
			var rate = api.apply("mul", [investment_rates[resource], ratio.value])
			if not rate.ok:
				return rate
			rate = api.apply("floor", [rate.value])
			rate = api.apply("max", [one.value, rate.value])
			if not rate.ok:
				return rate
			next.investment[resource] = rate.value
	var factors_changed: bool = false
	# Only unification consumes peaks. Compare the actual factors used by Session,
	# keeping peak history even when its effective multipliers stay unchanged.
	if next.peaks != state.peaks and int(state.levels.get("unification", 0)) > 0:
		var effects: PackedStringArray = str(definitions.unification.effect).split(",")
		for effect in ["weapon_damage", "equipment_durability", "iron_income", "uranium_income", "fragment_income"]:
			if effect not in effects: continue
			var before: Dictionary = {"ok": true, "value": state.contributions[effect]}
			var after = factor(next, definitions, effect, rules, api)
			for result in [before, after]:
				if not result.ok: return result
			next.contributions[effect] = after.value
			var compared = api.apply("compare", [before.value, after.value])
			if not compared.ok: return compared
			if compared.scalar != 0:
				factors_changed = true
	return {"ok": true, "state": next, "factors_changed": factors_changed}

static func select_shortest(state: Dictionary, definitions: Dictionary, api) -> Dictionary:
	if not str(state.current).is_empty():
		return {"ok": true}
	var chosen: String = ""
	var shortest: Dictionary = {}
	# Dictionary insertion order is the imported Excel row order; ties keep it.
	var keys: Array = definitions.keys()
	for key in keys:
		if not state.available.get(key, false):
			continue
		var work = required_work(state, definitions[key], api)
		if not work.ok:
			return work
		work = api.apply("sub_nonnegative", [work.value, state.work.get(key, api.apply("zero", []).value)])
		if not work.ok:
			return work
		if chosen.is_empty() or api.apply("compare", [work.value, shortest]).scalar < 0:
			chosen = key
			shortest = work.value
	state.current = chosen
	return {"ok": true}

static func advance(state: Dictionary, wallet: Dictionary, definitions: Dictionary,
		dt: float, rules: Dictionary, api, crew_speed: Dictionary, continue_research: bool) -> Dictionary:
	var next: Dictionary = state.duplicate()
	next.refresh_elapsed = float(next.refresh_elapsed) + dt
	var key: String = str(next.current)
	if key.is_empty():
		if continue_research:
			var selected = select_shortest(next, definitions, api)
			if not selected.ok: return selected
		return {"ok": true, "state": next, "wallet": wallet, "completed": false}
	next.work = state.work.duplicate()
	var balances: Dictionary = wallet.duplicate()
	# Selection admits gates/requirements; both stay valid until this level completes.
	if not definitions.has(key):
		return {"ok": false, "reason": "ResearchUnavailable"}
	var level: int = int(next.levels.get(key, 0))
	if level == 9223372036854775807:
		return {"ok": false, "reason": "ResearchLevelRangeExceeded"}
	var required = required_work(next, definitions[key], api)
	if not required.ok:
		return required
	var zero: Dictionary = api.apply("zero", []).value
	var progress: Dictionary = next.work.get(key, zero)
	var remaining: float = dt
	while remaining > 0.0:
		var piece: float = remaining
		var speed: float = (float(int(next.levels.get("singularity", 0))) + float(rules.research_ai_divisor)) / float(rules.research_ai_divisor)
		var paying: Dictionary = {}
		var exhausted: Array = []
		var full_dt = api.apply("from_decimal", [str(remaining)])
		for resource in ["1", "2"]:
			var rate: Dictionary = next.investment.get(resource, zero)
			var balance: Dictionary = balances.get(resource, zero)
			if api.apply("compare", [rate, zero]).scalar <= 0 or api.apply("compare", [balance, zero]).scalar <= 0:
				continue
			var wanted = api.apply("mul", [rate, full_dt.value])
			if not wanted.ok:
				return wanted
			var ratio = api.apply("to_ratio", [balance, wanted.value])
			if not ratio.ok:
				return ratio
			if api.apply("compare", [balance, wanted.value]).scalar <= 0:
				var affordable: float = remaining * ratio.scalar
				if affordable < piece:
					piece = affordable
					exhausted.clear()
				if affordable == piece:
					exhausted.append(resource)
			var log_rate = api.apply("log10", [rate])
			if not log_rate.ok:
				return log_rate
			speed *= maxf(1.0, 1.0 + log_rate.scalar / float(rules.research_invest_log_divisor))
			paying[resource] = rate
		var duration = api.apply("from_decimal", [str(piece)])
		var speed_value = api.apply("from_decimal", [str(speed)])
		speed_value = api.apply("mul", [speed_value.value, crew_speed])
		if not speed_value.ok:
			return speed_value
		var work = api.apply("mul", [speed_value.value, duration.value])
		var deficit = api.apply("sub_nonnegative", [required.value, progress])
		for result in [work, deficit]:
			if not result.ok:
				return result
		var completed: bool = api.apply("compare", [work.value, deficit.value]).scalar >= 0
		if completed:
			var fraction = api.apply("to_ratio", [deficit.value, work.value])
			piece *= fraction.scalar
			duration = api.apply("from_decimal", [str(piece)])
			work = deficit
		for resource in paying:
			var cost = api.apply("mul", [paying[resource], duration.value])
			if not cost.ok:
				return cost
			var left = api.apply("sub_nonnegative", [balances.get(resource, zero), cost.value])
			if not left.ok:
				return left
			# The Amount comparison owns this exhaustion boundary. A duration
			# may round to zero as a float; consume the limiting balance once
			# and recompute the remaining step without its acceleration.
			balances[resource] = zero if not completed and resource in exhausted else left.value
		var added = api.apply("add", [progress, work.value])
		if not added.ok:
			return added
		progress = added.value
		if completed:
			next.levels = state.levels.duplicate()
			next.levels[key] = level + 1
			next.available = state.available.duplicate()
			_refresh_available(next, definitions)
			next.required_work = state.required_work.duplicate()
			next.required_work.erase(key)
			next.work[key] = zero
			next.current = ""
			next.contributions = state.contributions.duplicate()
			for effect in str(definitions[key].effect).split(","): next.contributions.erase(effect)
			if continue_research:
				var selected = select_shortest(next, definitions, api)
				if not selected.ok:
					return {"ok": true, "state": next, "wallet": balances, "completed": true, "continuation_error": selected.get("error", selected.get("reason", "ResearchContinuationFailed"))}
			return {"ok": true, "state": next, "wallet": balances, "completed": true}
		remaining = maxf(0.0, remaining - piece)
	next.work[key] = progress
	return {"ok": true, "state": next, "wallet": balances, "completed": false}
