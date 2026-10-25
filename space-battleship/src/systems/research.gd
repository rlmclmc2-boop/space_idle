extends RefCounted

static func initial() -> Dictionary:
	return {"levels": {}, "work": {}, "current": "", "investment": {},
		"auto_invest": false, "ratio": 0.0, "refresh_elapsed": 0.0,
		"peaks": {}, "completed_unread": {}}

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

static func required_work(row: Dictionary, level: int, api) -> Dictionary:
	var base = api.apply("from_decimal", [str(row.base_seconds)])
	var growth = api.apply("from_decimal", [str(row.growth)])
	for result in [base, growth]:
		if not result.ok:
			return result
	growth = api.apply("pow", [growth.value, level])
	if not growth.ok:
		return growth
	return api.apply("mul", [base.value, growth.value])

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

static func refresh_income(state: Dictionary, peak_rates: Dictionary, investment_rates: Dictionary, rules: Dictionary, api, income_changed: bool, automatic_due: bool) -> Dictionary:
	if not income_changed and not automatic_due:
		return {"ok": true, "state": state}
	var next: Dictionary = state.duplicate(true)
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
	return {"ok": true, "state": next}

static func select_shortest(state: Dictionary, definitions: Dictionary, gates: Dictionary, api) -> Dictionary:
	if not str(state.current).is_empty():
		return {"ok": true}
	var chosen: String = ""
	var shortest: Dictionary = api.apply("zero", []).value
	var keys: Array = definitions.keys()
	keys.sort()
	for key in keys:
		if not available(definitions[key], state.levels, gates):
			continue
		var work = required_work(definitions[key], int(state.levels.get(key, 0)), api)
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

static func advance(state: Dictionary, wallet: Dictionary, definitions: Dictionary, gates: Dictionary,
		dt: float, rules: Dictionary, api, crew_speed: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var balances: Dictionary = wallet.duplicate(true)
	next.refresh_elapsed = float(next.refresh_elapsed) + dt
	var key: String = str(next.current)
	if key.is_empty():
		return {"ok": true, "state": next, "wallet": balances, "completed": false}
	if not definitions.has(key) or not available(definitions[key], next.levels, gates):
		return {"ok": false, "reason": "ResearchUnavailable"}
	var level: int = int(next.levels.get(key, 0))
	if level == 9223372036854775807:
		return {"ok": false, "reason": "ResearchLevelRangeExceeded"}
	var required = required_work(definitions[key], level, api)
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
			next.levels[key] = level + 1
			next.work[key] = zero
			next.current = ""
			next.completed_unread[key] = true
			return {"ok": true, "state": next, "wallet": balances, "completed": true}
		remaining = maxf(0.0, remaining - piece)
	next.work[key] = progress
	return {"ok": true, "state": next, "wallet": balances, "completed": false}
