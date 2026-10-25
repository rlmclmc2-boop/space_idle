extends RefCounted

const WEAPON := ["proficiency", "repeat", "critical"]
const DEFENCE := ["adaptation", "memory", "deferred"]

static func initial() -> Dictionary:
	return {"level": 0, "extra_levels": 0, "weapon_order": WEAPON.duplicate(),
		"defence_order": DEFENCE.duplicate(), "branches": {}}

static func describe(state: Dictionary, rules: Dictionary, available: bool) -> Dictionary:
	var level: int = int(state.level) + int(state.extra_levels)
	var effects: Dictionary = {}
	for order in [state.weapon_order, state.defence_order]:
		for position in order.size():
			var key: String = order[position]
			var enabled: bool = available and level >= int(rules["threshold_" + str(position + 1)])
			var effect := {"active": enabled, "a": 0, "b1": false, "b2": false, "b3": false}
			var choices: Array = state.branches.get(key, ["", "", ""])
			for node in 3:
				if not enabled or level < int(rules["branch_threshold_" + str(node + 1)]) + int(rules["branch_position_offset_" + str(position + 1)]):
					continue
				if choices[node] == "A":
					effect.a += 1
				elif choices[node] == "B" and not (key == "repeat" and node == 1):
					effect["b" + str(node + 1)] = true
			effects[key] = effect
	return {"level": level, "effects": effects, "rules": rules}

static func combat(state: Dictionary, bonus: int, rules: Dictionary, available: bool, slots: Array) -> Dictionary:
	if int(state.extra_levels) > 9223372036854775807 - bonus or int(state.level) > 9223372036854775807 - int(state.extra_levels) - bonus:
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	var effective: Dictionary = state.duplicate()
	effective.extra_levels = int(state.extra_levels) + bonus
	var description: Dictionary = describe(effective, rules, available)
	var enabled: Dictionary = description.effects
	var level: int = int(description.level)
	var flags: Dictionary = {}
	for key in enabled:
		var effect: Dictionary = enabled[key]
		flags[key] = {"active": effect.b1 or effect.b2 or effect.b3, "b1": effect.b1, "b2": effect.b2, "b3": effect.b3}
	var armours: int = 0
	for slot in slots:
		if slot.equipment_id == "armour": armours += 1
	var memory_factor: float = 1.0 + int(enabled.memory.a) * float(rules.memory_a_bonus)
	var cap: float = float(rules.memory_buffer_fraction) * level * memory_factor if enabled.memory.active else 0.0
	if enabled.memory.b3: cap *= 1.0 + armours * float(rules.memory_b3_armour_capacity_bonus)
	var scale: float = float(rules.deferred_percent_scale)
	return {"ok": true, "rules": rules, "effects": flags,
		"globals": {"counter_level": level if (enabled.proficiency.active and float(rules.proficiency_growth) != 0.0) or (enabled.adaptation.active and float(rules.adaptation_growth) != 0.0) else 0, "counter_growth": float(rules.proficiency_growth) if enabled.proficiency.active else 0.0,
			"defence_counter_growth": float(rules.adaptation_growth) if enabled.adaptation.active else 0.0,
			"counter_log_base": float(rules.counter_log_base), "counter_round_scale": float(rules.bonus_round_scale),
			"repeat_delay": float(rules.repeat_delay), "memory_interval": float(rules.memory_interval),
			"deferred_interval": float(rules.deferred_interval), "deferred_duration": float(rules.deferred_duration),
			"clear_probability": clampf(float(rules.deferred_clear_probability) + int(enabled.deferred.a) * float(rules.deferred_a_clear_probability), 0.0, 1.0) if enabled.deferred.active else 0.0},
		"weapon": {"branch_factors": [1.0 + int(enabled.proficiency.a) * float(rules.proficiency_a_damage_bonus)],
			"interval_multiplier": float(rules.proficiency_b2_interval_multiplier) if enabled.proficiency.b2 else 1.0,
			"proficiency_pierce": enabled.proficiency.b3, "pierce_resistance": float(rules.proficiency_b3_resistance),
			"repeat_probability": clampf(float(rules.repeat_probability) + int(enabled.repeat.a) * float(rules.repeat_a_probability), 0.0, 1.0) if enabled.repeat.active else 0.0,
			"repeat_multiplier": 1.0 + float(rules.repeat_growth) * level,
			"chain_count": int(rules.repeat_b1_targets) if enabled.repeat.b1 else 0,
			"secondary_probability": float(rules.repeat_b3_probability) if enabled.repeat.b3 else 0.0,
			"critical_rate": (float(rules.base_critical_rate) if enabled.critical.active else 0.0) + int(enabled.critical.a) * float(rules.critical_a_probability),
			"critical_multiplier": float(rules.base_critical_multiplier) + (float(rules.critical_growth) * level if enabled.critical.active else 0.0)},
		"defence": {"branch_factors": [1.0 + int(enabled.adaptation.a) * float(rules.adaptation_a_capacity_bonus)],
			"memory_heal": float(rules.memory_heal_fraction) * level * memory_factor if enabled.memory.active else 0.0, "memory_cap": cap,
			"deferred_fraction": maxf(0.0, (scale - maxf(1.0, ceilf(scale / (1.0 + float(rules.deferred_curve_coefficient) * level)))) / scale) if enabled.deferred.active else 0.0}}

static func changes(previous: Dictionary, next: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for group in ["globals", "weapon", "defence", "effects"]:
		for key in next[group]:
			if previous[group].get(key) == next[group][key]: continue
			if not changed.has(group): changed[group] = {}
			changed[group][key] = next[group][key]
	return changed

static func reorder(state: Dictionary, category: String, order: Array) -> Dictionary:
	var expected: Array = WEAPON if category == "weapon" else DEFENCE if category == "defence" else []
	if order.size() != expected.size() or expected.is_empty():
		return {"ok": false, "reason": "InvalidEnhancementOrder"}
	for key in expected:
		if order.count(key) != 1:
			return {"ok": false, "reason": "InvalidEnhancementOrder"}
	var next: Dictionary = state.duplicate(true)
	next[category + "_order"] = order.duplicate()
	return {"ok": true, "state": next}

static func choose(state: Dictionary, effect: String, node: int, choice: String, rules: Dictionary, available: bool) -> Dictionary:
	if node < 0 or node > 2 or choice not in ["A", "B"]:
		return {"ok": false, "reason": "InvalidEnhancementBranch"}
	var order: Array = state.weapon_order if effect in WEAPON else state.defence_order if effect in DEFENCE else []
	var position: int = order.find(effect)
	if not available or position < 0 or int(state.level) + int(state.extra_levels) < int(rules["branch_threshold_" + str(node + 1)]) + int(rules["branch_position_offset_" + str(position + 1)]):
		return {"ok": false, "reason": "EnhancementBranchLocked"}
	var next: Dictionary = state.duplicate(true)
	var choices: Array = next.branches.get(effect, ["", "", ""])
	choices[node] = choice
	next.branches[effect] = choices
	return {"ok": true, "state": next}

static func quote(state: Dictionary, count: int, rules: Dictionary, amount_api) -> Dictionary:
	var base = amount_api.apply("from_decimal", [str(rules.cost_base)])
	if not base.ok:
		return base
	var cost = amount_api.apply("sum_ceiled_geometric", [base.value, float(rules.cost_growth), str(int(state.level)), str(count)])
	if not cost.ok:
		return cost
	return {"ok": true, "costs": {"jewel": cost.value}, "count": count, "extreme": cost.extreme}

# Purchase quantity is enhancement policy; the economy supplies a read-only predicate.
static func quote_purchase(state: Dictionary, count: int, rules: Dictionary, api, can_pay: Callable) -> Dictionary:
	if count < 1 or int(state.level) > 9223372036854775807 - count:
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	var quoted = quote(state, count, rules, api)
	if not quoted.ok:
		return quoted
	if bool(can_pay.call(quoted.costs)): return quoted
	var accepted: Dictionary = {}
	var low: int = 0
	var high: int = count
	while low < high:
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2 + 1
		var candidate = quote(state, middle, rules, api)
		if candidate.ok and bool(can_pay.call(candidate.costs)):
			low = middle
			accepted = candidate
		else:
			high = middle - 1
	if low == 0:
		return {"ok": false, "reason": "NoChange"}
	return accepted
