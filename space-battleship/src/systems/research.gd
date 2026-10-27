extends RefCounted
var _run_state

signal choices_changed
signal investment_changed

var _state: Dictionary
var _definitions: Dictionary = {}
var _rules: Dictionary = {}
var _api
var _budget_work_cache: Dictionary = {}
var _budget_effect_cache: Dictionary = {}

func save_state() -> Dictionary:
	var state: Dictionary = _state.duplicate(true)
	state.erase("contributions")
	state.erase("gates")
	state.erase("available")
	return state

func restore_state(state: Dictionary) -> Dictionary:
	var initial: Dictionary = _initial(_rules)
	for key in ["levels", "work", "investment", "peaks", "required_work"]:
		if not state.get(key) is Dictionary: return {"ok": false, "reason": "InvalidResearchState"}
		for id in state[key]:
			if not id is String or (key not in ["investment", "peaks"] and not _definitions.has(id)):
				return {"ok": false, "reason": "UnknownResearchId"}
			if key == "levels":
				if not state[key][id] is int or state[key][id] < 0: return {"ok": false, "reason": "InvalidResearchLevel"}
			else:
				var value = state[key][id]
				if not value is Dictionary: return {"ok": false, "reason": "InvalidResearchAmount"}
				var checked: Dictionary = _api.apply("compare", [value, _api.apply("zero", []).value])
				if not checked.get("ok", false) or checked.scalar < 0: return {"ok": false, "reason": "InvalidResearchAmount"}
	for key in ["auto_invest", "ratio", "refresh_elapsed", "current"]:
		if not state.has(key) or typeof(state[key]) != typeof(initial[key]):
			return {"ok": false, "reason": "InvalidResearchState"}
	if not is_finite(state.ratio) or not is_finite(state.refresh_elapsed) or state.ratio < 0.0 or state.refresh_elapsed < 0.0 or (not state.current.is_empty() and not _definitions.has(state.current)):
		return {"ok": false, "reason": "InvalidResearchState"}
	_state = _initial(_rules)
	_budget_work_cache.clear()
	_budget_effect_cache.clear()
	for key in ["levels", "work", "current", "investment", "auto_invest", "ratio", "refresh_elapsed", "peaks", "required_work"]:
		_state[key] = state[key].duplicate(true) if state[key] is Dictionary or state[key] is Array else state[key]
	investment_changed.emit()
	return {"ok": true}

func _init(rows: Array, rules: Dictionary, api, run_state) -> void:
	_run_state = run_state
	for row in rows: _definitions[str(row.id)] = row
	for key in rules:
		if str(key).begins_with("research_"): _rules[key] = rules[key]
	_api = api
	_state = _initial(_rules)

func income_window() -> float:
	return float(_rules.research_income_window)

func panel_model() -> Dictionary:
	var options: Array = []
	for key in _definitions:
		options.append({"id": key, "name": str(_definitions[key].name)})
	var investment: Dictionary = {}
	for resource in ["1", "2"]:
		var amount: Dictionary = _state.investment.get(resource, {"m": 0.0, "e": 0})
		investment[resource] = "0" if str(amount.m) in ["0", "0.0"] else str(amount.m) + "e" + str(amount.e)
	return {"options": options, "research_id": str(_state.current), "ratio": _state.ratio, "minimum_ratio": _rules.research_minimum_ratio,
		"auto_invest": _state.auto_invest, "investment": investment}

## Session supplies detached public inputs; UI never reads private speed assembly.
func budget_preview(request: Dictionary, inputs: Dictionary) -> Dictionary:
	if not request.get("research_id") is String or request.research_id != str(_state.current):
		return {"ok": false, "reason": "ResearchSelectionChanged", "research_id": str(_state.current)}
	if not bool(inputs.get("ok", true)): return inputs.duplicate(true)
	if not inputs.get("wallet") is Dictionary or not inputs.get("income_rates") is Dictionary or not inputs.get("speed_factor") is Dictionary or not inputs.get("staffed") is bool:
		return {"ok": false, "reason": "InvalidResearchPreviewInputs"}
	for resource in ["1", "2"]:
		if not inputs.income_rates.get(resource) is Dictionary: return {"ok": false, "reason": "InvalidResearchPreviewInputs"}
	var context: Dictionary = _budget_work_context()
	var zero: Dictionary = _api.apply("zero", []).value
	var current_rates: Dictionary = {}
	for resource in ["1", "2"]: current_rates[resource] = _state.investment.get(resource, zero)
	var current: Dictionary = _budget_view(current_rates, inputs, context)
	if not current.ok: return current
	var kind: String = str(request.get("kind", ""))
	if kind not in ["once_ratio", "once_amounts", "following_sample"]: return {"ok": false, "reason": "InvalidResearchPreview"}
	var targets: Dictionary = {}
	var errors: Dictionary = {}
	var reason: String = ""
	var ratio: float = 0.0
	if kind == "once_amounts":
		var texts = request.get("amount_texts")
		if not texts is Dictionary: return {"ok": false, "reason": "InvalidResearchPreview"}
		for key in texts:
			if key not in ["1", "2"]: return {"ok": false, "reason": "InvalidResearchResource", "resource": key}
		for resource in ["1", "2"]:
			if not texts.get(resource) is String:
				errors[resource] = {"reason": "InvalidResearchAmount"}
				continue
			var quantity: Dictionary = _api.apply("from_decimal", [texts[resource]])
			if quantity.ok: quantity = _api.apply("floor", [quantity.value])
			if quantity.ok: targets[resource] = quantity.value
			else: errors[resource] = {"reason": str(quantity.get("error", "InvalidResearchAmount")), "text": texts[resource]}
		if not errors.is_empty(): reason = "InvalidResearchAmount"
	else:
		if not request.get("basis_points") is int or request.basis_points < 0 or request.basis_points > 10000:
			return {"ok": false, "reason": "InvalidResearchRatio"}
		ratio = float(request.basis_points) / 10000.0
		if kind == "following_sample":
			if not request.get("enabled") is bool: return {"ok": false, "reason": "InvalidResearchPreview"}
			var admission: Dictionary = _automatic_ratio_admission(ratio, _rules)
			if not admission.ok: reason = str(admission.reason)
			elif not request.enabled: reason = "AutomaticDisabled"
		if reason.is_empty():
			var share: Dictionary = _api.apply("div", [_api.apply("from_decimal", [str(request.basis_points)]).value, _api.apply("from_decimal", ["10000"]).value])
			if not share.ok: return share
			for resource in ["1", "2"]:
				var target: Dictionary = _income_rate_target(inputs.income_rates[resource], share.value, kind == "following_sample", _api)
				if not target.ok: return target
				targets[resource] = target.value
	var compared = null
	if targets.size() == 2 and errors.is_empty():
		compared = _budget_view(targets, inputs, context)
		if not compared.ok: return compared
	var rows: Dictionary = {}
	for resource in ["1", "2"]:
		var row: Dictionary = current.resources[resource].duplicate(true)
		row.current_rate = current.investment[resource]
		row.net_current = row.net
		row.stock_duration_current = row.stock_duration
		row.erase("net")
		row.erase("stock_duration")
		for field in ["draft_rate", "following_sample_rate", "net_draft", "net_sample", "stock_duration_draft", "stock_duration_sample"]: row[field] = null
		if targets.has(resource):
			var resource_view: Dictionary = _budget_resource(resource, targets[resource], inputs)
			if not resource_view.ok: return resource_view
			var following: bool = kind == "following_sample"
			row["following_sample_rate" if following else "draft_rate"] = _api.apply("to_display", [targets[resource]]).text
			row["net_sample" if following else "net_draft"] = resource_view.net
			row["stock_duration_sample" if following else "stock_duration_draft"] = resource_view.stock_duration
		row.can_apply = kind != "following_sample" and targets.has(resource) and _run_state.is_running()
		row.reason = str(errors.get(resource, {}).get("reason", ""))
		rows[resource] = row
	current.erase("resources")
	current.merge(context.details)
	current.automatic_enabled = _state.auto_invest
	current.automatic_ratio = _state.ratio
	current.minimum_ratio = _rules.research_minimum_ratio
	var blocked: String = "AutomaticDisabled" if not _state.auto_invest else "ResearchStaffRequired" if not inputs.staffed else ""
	var comparison = compared if compared != null else {"investment": null, "speed_now": null, "completion_estimate": null, "reason": reason, "field_errors": errors}
	comparison.erase("resources")
	if kind == "following_sample":
		comparison.enabled = request.enabled
		comparison.ratio = ratio
	var applicable: bool = reason in ["", "AutomaticDisabled"] and _run_state.is_running()
	return {"ok": true, "can_apply": applicable, "reason": reason if _run_state.is_running() else "SessionUnavailable",
		"source": {"window_seconds": inputs.get("window_seconds", income_window()), "window_end_game": inputs.get("game_time")},
		"current": current, "resources": rows, "field_errors": errors,
		"immediate_draft": comparison if kind != "following_sample" else null,
		"following_sample": comparison if kind == "following_sample" else null,
		"completion_effects": _budget_completion_effects(),
		"automatic_refresh": {"remaining_game_seconds": maxf(0.0, income_window() - float(_state.refresh_elapsed)),
			"due": automatic_due(inputs.staffed), "reason": blocked}}

func _budget_work_context() -> Dictionary:
	var id: String = str(_state.current)
	var zero: Dictionary = _api.apply("zero", []).value
	var details := {"research_id": id, "level": null,
		"work": null, "required": null, "remaining_work": null, "reason": "NoCurrentResearch"}
	if id.is_empty() or not _definitions.has(id): return {"remaining": null, "details": details}
	details.level = int(_state.levels.get(id, 0))
	var work: Dictionary = _state.work.get(id, zero)
	details.work = _api.apply("to_display", [work]).text
	if int(details.level) == 9223372036854775807:
		details.reason = "ResearchLevelRangeExceeded"
		return {"remaining": null, "details": details}
	var signature := {"id": id, "level": details.level, "saved": _state.required_work.get(id)}
	if _budget_work_cache.get("signature") != signature:
		var detached := {"levels": _state.levels, "required_work": _state.required_work.duplicate(true)}
		_budget_work_cache = {"signature": signature, "required": _required_work(detached, _definitions[id], _api)}
	var required: Dictionary = _budget_work_cache.required
	if not required.ok:
		details.reason = str(required.get("error", "ResearchWorkUnavailable"))
		return {"remaining": null, "details": details}
	var remaining: Dictionary = _api.apply("sub_nonnegative", [required.value, work])
	if not remaining.ok:
		details.reason = str(remaining.get("error", "ResearchWorkUnavailable"))
		return {"remaining": null, "details": details}
	details.required = _api.apply("to_display", [required.value]).text
	details.remaining_work = _api.apply("to_display", [remaining.value]).text
	details.reason = ""
	return {"remaining": remaining.value, "details": details}

func _budget_resource(resource: String, rate: Dictionary, inputs: Dictionary) -> Dictionary:
	var zero: Dictionary = _api.apply("zero", []).value
	var balance: Dictionary = inputs.wallet.get(resource, zero)
	var income: Dictionary = inputs.income_rates[resource]
	var compared: Dictionary = _api.apply("compare", [income, rate])
	if not compared.ok: return compared
	var checked_balance: Dictionary = _api.apply("compare", [balance, zero])
	if not checked_balance.ok: return checked_balance
	var direction: int = int(compared.scalar)
	var net: Dictionary = _api.apply("sub_nonnegative", [income, rate] if direction >= 0 else [rate, income])
	if not net.ok: return net
	var stock := {"kind": "not_spending", "game_seconds": null}
	if _api.apply("compare", [rate, zero]).scalar > 0:
		var duration: Dictionary = _api.apply("div", [balance, rate])
		if not duration.ok: return duration
		stock = {"kind": "finite", "game_seconds": _api.apply("to_display", [duration.value]).text}
	return {"ok": true, "income_rate": _api.apply("to_display", [income]).text, "balance": _api.apply("to_display", [balance]).text,
		"net": {"direction": "surplus" if direction > 0 else "deficit" if direction < 0 else "balanced", "amount": _api.apply("to_display", [net.value]).text},
		"stock_duration": stock}

func _budget_view(rates: Dictionary, inputs: Dictionary, context: Dictionary) -> Dictionary:
	var zero: Dictionary = _api.apply("zero", []).value
	var paying: Dictionary = {}
	var funded: Dictionary = {}
	var investment: Dictionary = {}
	var resources: Dictionary = {}
	for resource in ["1", "2"]:
		investment[resource] = _api.apply("to_display", [rates[resource]]).text
		var row: Dictionary = _budget_resource(resource, rates[resource], inputs)
		if not row.ok: return row
		resources[resource] = row
		if _api.apply("compare", [rates[resource], zero]).scalar > 0:
			funded[resource] = rates[resource]
			if _api.apply("compare", [inputs.wallet.get(resource, zero), zero]).scalar > 0: paying[resource] = rates[resource]
	var result := {"ok": true, "investment": investment, "resources": resources,
		"speed_now": null, "completion_estimate": null, "reason": str(context.details.reason)}
	if str(_state.current).is_empty(): return result
	var speed: Dictionary = _work_speed(_state, _rules, _api, inputs.speed_factor, paying)
	if not speed.ok: return speed
	result.speed_now = _api.apply("to_display", [speed.value]).text
	if context.remaining == null: return result
	var fully_funded: Dictionary = _work_speed(_state, _rules, _api, inputs.speed_factor, funded)
	if not fully_funded.ok: return fully_funded
	if _api.apply("compare", [fully_funded.value, zero]).scalar <= 0:
		result.reason = "NoResearchSpeed"
		return result
	var duration: Dictionary = _api.apply("div", [context.remaining, fully_funded.value])
	if not duration.ok:
		result.reason = str(duration.get("error", "ResearchEstimateUnavailable"))
		return result
	var required_funding: Dictionary = {}
	var enough: bool = true
	for resource in ["1", "2"]:
		var cost: Dictionary = _api.apply("mul", [rates[resource], duration.value])
		if not cost.ok:
			result.reason = str(cost.get("error", "ResearchEstimateUnavailable"))
			return result
		required_funding[resource] = _api.apply("to_display", [cost.value]).text
		enough = enough and _api.apply("compare", [inputs.wallet.get(resource, zero), cost.value]).scalar >= 0
	result.completion_estimate = {"condition": "FrozenInputsContinuouslyFunded", "funded_speed": _api.apply("to_display", [fully_funded.value]).text,
		"game_seconds": _api.apply("to_display", [duration.value]).text, "assumed_paid_resources": funded.keys(),
		"required_funding": required_funding, "current_wallet_sufficient": enough}
	return result

func _budget_completion_effects() -> Array:
	var id: String = str(_state.current)
	if id.is_empty() or not _definitions.has(id) or int(_state.levels.get(id, 0)) == 9223372036854775807: return []
	var signature := {"id": id, "levels": _state.levels.duplicate(), "peaks": _state.peaks.duplicate(true)}
	if _budget_effect_cache.get("signature") == signature: return _budget_effect_cache.rows.duplicate(true)
	var next: Dictionary = _state.duplicate()
	next.levels = _state.levels.duplicate()
	next.levels[id] = int(next.levels.get(id, 0)) + 1
	var rows: Array = []
	for effect in str(_definitions[id].effect).split(","):
		var before: Dictionary
		var after: Dictionary
		if effect == "ai_count":
			var one: Dictionary = _api.apply("from_decimal", ["1"]).value
			before = _api.apply("add", [_api.apply("from_decimal", [str(_state.levels.get("singularity", 0))]).value, one])
			after = _api.apply("add", [_api.apply("from_decimal", [str(next.levels.get("singularity", 0))]).value, one])
		else:
			before = _factor(_state, _definitions, effect, _rules, _api)
			after = _factor(next, _definitions, effect, _rules, _api)
		rows.append({"id": effect, "current": _api.apply("to_display", [before.value]).text if before.ok else null,
			"next": _api.apply("to_display", [after.value]).text if after.ok else null,
			"reason": "" if before.ok and after.ok else "ResearchEffectUnavailable"})
	_budget_effect_cache = {"signature": signature, "rows": rows}
	return rows.duplicate(true)

static func _automatic_ratio_admission(ratio: float, rules: Dictionary) -> Dictionary:
	return {"ok": true} if is_finite(ratio) and ratio >= float(rules.research_minimum_ratio) and ratio <= 1.0 else {"ok": false, "reason": "InvalidResearchRatio"}

static func _income_rate_target(rate: Dictionary, ratio: Dictionary, minimum_one: bool, api) -> Dictionary:
	var target: Dictionary = api.apply("mul", [rate, ratio])
	if not target.ok: return target
	target = api.apply("floor", [target.value])
	if not target.ok or not minimum_one: return target
	return api.apply("max", [api.apply("from_decimal", ["1"]).value, target.value])

static func _work_speed(state: Dictionary, rules: Dictionary, api, external: Dictionary, paying: Dictionary) -> Dictionary:
	var speed: float = (float(int(state.levels.get("singularity", 0))) + float(rules.research_ai_divisor)) / float(rules.research_ai_divisor)
	for resource in ["1", "2"]:
		if not paying.has(resource): continue
		var logarithm: Dictionary = api.apply("log10", [paying[resource]])
		if not logarithm.ok: return logarithm
		speed *= maxf(1.0, 1.0 + logarithm.scalar / float(rules.research_invest_log_divisor))
	var value: Dictionary = api.apply("from_decimal", [str(speed)])
	if not value.ok: return value
	return api.apply("mul", [value.value, external])
func _finish_advance(next: Dictionary, wallet: Dictionary, completed: bool, continuation_error = null, completed_id: String = "") -> Dictionary:
	var changed: bool = _state.available != next.available
	_state = next
	var result := {"ok": true, "wallet": wallet, "completed": completed, "choices_changed": changed}
	if completed: result.completed_id = completed_id
	if continuation_error != null: result.continuation_error = continuation_error
	return result

func publish_choices_changed() -> void:
	choices_changed.emit()

static func _initial(rules: Dictionary) -> Dictionary:
	return {"levels": {}, "work": {}, "current": "", "investment": {},
		"auto_invest": false, "ratio": float(rules.research_default_ratio), "contributions": {}, "refresh_elapsed": 0.0,
		"peaks": {}, "required_work": {}, "gates": {}, "available": {}}

func select(id: String) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	if not state.available.get(id, false):
		return {"ok": false, "reason": "ResearchLocked"}
	state.current = id
	return {"ok": true}

# Research interprets its fields; generic progress availability has one authority.
func refresh_progress(unlocked: Callable, notify: bool = true) -> bool:
	if not _run_state.is_running(): return false
	var state: Dictionary = _state
	var definitions: Dictionary = _definitions
	var gates: Dictionary = {}
	for key in definitions:
		var row: Dictionary = definitions[key]
		gates[key] = (row.legacy_unlock == null or bool(unlocked.call("hightech", str(row.legacy_unlock)))) and (row.unlock == null or bool(unlocked.call("feature", "jewels")))
	if state.gates == gates and not state.available.is_empty(): return false
	state.gates = gates
	var previous: Dictionary = state.available.duplicate()
	_refresh_available(state, definitions)
	var changed: bool = state.available != previous
	if changed and notify: choices_changed.emit()
	return changed

static func _refresh_available(state: Dictionary, definitions: Dictionary) -> void:
	for id in definitions: state.available[id] = _available(definitions[id], state.levels, state.gates)

func choices() -> Dictionary:
	var state: Dictionary = _state
	return state.available.duplicate()

func set_investment_text(resource: String, text: String) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var quantity = _api.apply("from_decimal", [text])
	if not quantity.ok: return quantity
	return set_investment(resource, quantity.value)

func set_investment(resource: String, quantity: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	var api = _api
	if resource not in ["1", "2"]: return {"ok": false, "reason": "InvalidResearchResource"}
	var value = api.apply("floor", [quantity])
	if not value.ok: return value
	state.investment[resource] = value.value
	investment_changed.emit()
	return {"ok": true}

func set_automatic(enabled: bool, ratio: float) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	var rules: Dictionary = _rules
	var admitted: Dictionary = _automatic_ratio_admission(ratio, rules)
	if not admitted.ok: return admitted
	state.auto_invest = enabled
	state.ratio = ratio
	investment_changed.emit()
	return {"ok": true}

func automatic_due(assigned: bool) -> bool:
	var state: Dictionary = _state
	var rules: Dictionary = _rules
	return assigned and state.auto_invest and float(state.refresh_elapsed) >= float(rules.research_income_window)

func contributions() -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	var definitions: Dictionary = _definitions
	var rules: Dictionary = _rules
	var api = _api
	for effect in ["weapon_damage", "equipment_durability", "iron_income", "uranium_income", "fragment_income"]:
		if state.contributions.has(effect): continue
		var value = _factor(state, definitions, effect, rules, api)
		if not value.ok: return value
		state.contributions[effect] = value.value
	state.contributions.make_read_only()
	var output := {"ok": true, "values": state.contributions}
	output.make_read_only()
	return output

static func _available(row: Dictionary, levels: Dictionary, gates: Dictionary) -> bool:
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

static func _required_work(state: Dictionary, row: Dictionary, api) -> Dictionary:
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

static func _factor(state: Dictionary, definitions: Dictionary, effect: String, rules: Dictionary, api) -> Dictionary:
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

func refresh_income(peak_rates: Dictionary, investment_rates: Dictionary, income_changed: bool, automatic_due: bool) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	var definitions: Dictionary = _definitions
	var rules: Dictionary = _rules
	var api = _api
	if not income_changed and not automatic_due:
		return {"ok": true, "factors_changed": false}
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
		for resource in ["1", "2"]:
			var rate: Dictionary = _income_rate_target(investment_rates[resource], ratio.value, true, api)
			if not rate.ok: return rate
			next.investment[resource] = rate.value
	var factors_changed: bool = false
	# Only unification consumes peaks. Compare the actual factors used by Session,
	# keeping peak history even when its effective multipliers stay unchanged.
	if next.peaks != state.peaks and int(state.levels.get("unification", 0)) > 0:
		var effects: PackedStringArray = str(definitions.unification.effect).split(",")
		for effect in ["weapon_damage", "equipment_durability", "iron_income", "uranium_income", "fragment_income"]:
			if effect not in effects: continue
			var before: Dictionary = state.contributions[effect]
			var after = _factor(next, definitions, effect, rules, api)
			if not after.ok: return after
			next.contributions[effect] = after.value
			var compared = api.apply("compare", [before, after.value])
			if not compared.ok: return compared
			if compared.scalar != 0:
				factors_changed = true
	_state = next
	if automatic_due: investment_changed.emit()
	return {"ok": true, "factors_changed": factors_changed}

static func _select_shortest(state: Dictionary, definitions: Dictionary, api) -> Dictionary:
	if not str(state.current).is_empty():
		return {"ok": true}
	var chosen: String = ""
	var shortest: Dictionary = {}
	# Dictionary insertion order is the imported Excel row order; ties keep it.
	var keys: Array = definitions.keys()
	for key in keys:
		if not state.available.get(key, false):
			continue
		var work = _required_work(state, definitions[key], api)
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

func advance(wallet: Dictionary, dt: float, crew_speed: Dictionary, continue_research: bool) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var state: Dictionary = _state
	var definitions: Dictionary = _definitions
	var rules: Dictionary = _rules
	var api = _api
	var next: Dictionary = state.duplicate()
	next.refresh_elapsed = float(next.refresh_elapsed) + dt
	var key: String = str(next.current)
	if key.is_empty():
		if continue_research:
			var selected = _select_shortest(next, definitions, api)
			if not selected.ok: return selected
		return _finish_advance(next, wallet, false)
	next.work = state.work.duplicate()
	var balances: Dictionary = wallet.duplicate()
	# Selection admits gates/requirements; both stay valid until this level completes.
	if not definitions.has(key):
		return {"ok": false, "reason": "ResearchUnavailable"}
	var level: int = int(next.levels.get(key, 0))
	if level == 9223372036854775807:
		return {"ok": false, "reason": "ResearchLevelRangeExceeded"}
	var required = _required_work(next, definitions[key], api)
	if not required.ok:
		return required
	var zero: Dictionary = api.apply("zero", []).value
	var progress: Dictionary = next.work.get(key, zero)
	var remaining: float = dt
	while remaining > 0.0:
		var piece: float = remaining
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
			paying[resource] = rate
		var duration = api.apply("from_decimal", [str(piece)])
		var speed_value: Dictionary = _work_speed(next, rules, api, crew_speed, paying)
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
				var selected = _select_shortest(next, definitions, api)
				if not selected.ok:
					return _finish_advance(next, balances, true, selected.get("error", selected.get("reason", "ResearchContinuationFailed")), key)
			return _finish_advance(next, balances, true, null, key)
		remaining = maxf(0.0, remaining - piece)
	next.work[key] = progress
	return _finish_advance(next, balances, false)
