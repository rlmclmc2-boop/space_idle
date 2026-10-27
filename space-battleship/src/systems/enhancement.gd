extends RefCounted
var _run_state

const WEAPON := ["proficiency", "repeat", "critical"]
const DEFENCE := ["adaptation", "memory", "deferred"]

var _state: Dictionary = _initial()
var _rules: Dictionary = {}
var _api
var _values: Dictionary = {}
var _pending_output: Dictionary = {}
var _pending_state: Dictionary = {}

func save_state() -> Dictionary:
	return _state.duplicate(true)

func restore_state(state: Dictionary) -> Dictionary:
	var initial: Dictionary = _initial()
	for key in initial:
		if not state.has(key) or typeof(state[key]) != typeof(initial[key]):
			return {"ok": false, "reason": "InvalidEnhancementState"}
	if state.level < 0 or state.extra_levels < 0 or state.weapon_order.size() != WEAPON.size() or state.defence_order.size() != DEFENCE.size():
		return {"ok": false, "reason": "InvalidEnhancementState"}
	for group in [[state.weapon_order, WEAPON], [state.defence_order, DEFENCE]]:
		for id in group[0]:
			if not id is String or id not in group[1] or group[0].count(id) != 1:
				return {"ok": false, "reason": "InvalidEnhancementOrder"}
	for id in state.branches:
		if not id is String or id not in WEAPON + DEFENCE or not state.branches[id] is Array or state.branches[id].size() != 3:
			return {"ok": false, "reason": "InvalidEnhancementBranch"}
		for choice in state.branches[id]:
			if not choice in ["", "A", "B"]: return {"ok": false, "reason": "InvalidEnhancementBranch"}
	_state = state.duplicate(true)
	_pending_output = {}
	_pending_state = {}
	return {"ok": true}

func _init(rows: Array, api, run_state) -> void:
	_run_state = run_state
	for row in rows: _rules[str(row.id)] = row.value
	_rules.make_read_only()
	_values.make_read_only()
	_api = api

func evaluate(bonus: int, unlocked: Callable, armours: int) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var output = _combat(_state, bonus, _rules, bool(unlocked.call("feature", "jewels")), armours)
	_pending_output = output if output.ok else {}
	return output

func published_output() -> Dictionary:
	return _values

func accept_output() -> void:
	if not _run_state.is_running(): return
	if not _pending_output.is_empty():
		_values = _pending_output
		_pending_output = {}

func discard_output() -> void:
	_pending_output = {}

func difference(output: Dictionary) -> Dictionary:
	return _changes(_values, output)

# Inputs are equipment/world facts. The publisher performs the economy/native transaction.
# Callbacks exist only for this synchronous command; the module retains no Session reference.
func _submit(next: Dictionary, inputs: Dictionary, costs: Dictionary, kind: String, publish: Callable) -> Dictionary:
	var output = _combat(next, int(inputs.bonus), _rules, bool(inputs.unlocked.call("feature", "jewels")), int(inputs.armours))
	if not output.ok: return output
	_pending_state = next
	_pending_output = output
	var committed: Dictionary = publish.call(_changes(_values, output), costs, kind)
	if not committed.ok:
		_pending_state = {}
		_pending_output = {}
	return committed

func accept_prepared() -> void:
	_state = _pending_state
	_values = _pending_output
	_pending_state = {}
	_pending_output = {}

func purchase(count: int, inputs: Dictionary, can_pay: Callable, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not bool(inputs.unlocked.call("feature", "jewels")): return {"ok": false, "reason": "EnhancementLocked"}
	var quoted = _quote_purchase(_state, count, _rules, _api, can_pay)
	if not quoted.ok: return quoted
	var next: Dictionary = _state.duplicate(true)
	next.level = int(next.level) + int(quoted.count)
	return _submit(next, inputs, quoted.costs, "growth", publish)

func set_order(category: String, order: Array, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var changed = _reorder(_state, category, order)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, {}, "selection", publish)

func move_forward(effect: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var category: String = "weapon" if effect in WEAPON else "defence"
	var order: Array = _state[category + "_order"].duplicate()
	var index: int = order.find(effect)
	if index < 0: return {"ok": false, "reason": "InvalidEnhancementOrder"}
	var previous: int = (index + order.size() - 1) % order.size()
	var held = order[previous]
	order[previous] = order[index]
	order[index] = held
	return set_order(category, order, inputs, publish)

func set_branch(effect: String, node: int, choice: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var changed = _choose(_state, effect, node, choice, _rules, bool(inputs.unlocked.call("feature", "jewels")), int(inputs.bonus))
	if not changed.ok: return changed
	return _submit(changed.state, inputs, {}, "selection", publish)

static func _initial() -> Dictionary:
	return {"level": 0, "extra_levels": 0, "weapon_order": WEAPON.duplicate(),
		"defence_order": DEFENCE.duplicate(), "branches": {}}

static func _effective_level(state: Dictionary, bonus: int) -> Dictionary:
	if int(state.extra_levels) > 9223372036854775807 - bonus or int(state.level) > 9223372036854775807 - int(state.extra_levels) - bonus:
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	return {"ok": true, "level": int(state.level) + (int(state.extra_levels) + bonus)}

static func _describe(state: Dictionary, level: int, rules: Dictionary, available: bool) -> Dictionary:
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

static func _combat(state: Dictionary, bonus: int, rules: Dictionary, available: bool, armours: int) -> Dictionary:
	var effective = _effective_level(state, bonus)
	if not effective.ok: return effective
	var description: Dictionary = _describe(state, int(effective.level), rules, available)
	var enabled: Dictionary = description.effects
	var level: int = int(description.level)
	var flags: Dictionary = {}
	for key in enabled:
		var effect: Dictionary = enabled[key]
		flags[key] = {"active": effect.b1 or effect.b2 or effect.b3, "b1": effect.b1, "b2": effect.b2, "b3": effect.b3}
	var memory_factor: float = 1.0 + int(enabled.memory.a) * float(rules.memory_a_bonus)
	var cap: float = float(rules.memory_buffer_fraction) * level * memory_factor if enabled.memory.active else 0.0
	if enabled.memory.b3: cap *= 1.0 + armours * float(rules.memory_b3_armour_capacity_bonus)
	var scale: float = float(rules.deferred_percent_scale)
	var output := {"ok": true, "rules": rules, "effects": flags, "initial_wait_from_interval": enabled.proficiency.b2,
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

	for effect in flags.values(): effect.make_read_only()
	flags.make_read_only()
	output.globals.make_read_only()
	for group in ["weapon", "defence"]:
		output[group].branch_factors.make_read_only()
		output[group].make_read_only()
	output.make_read_only()
	return output

static func _changes(previous: Dictionary, next: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for group in ["globals", "weapon", "defence", "effects"]:
		for key in next[group]:
			if previous[group].get(key) == next[group][key]: continue
			if not changed.has(group): changed[group] = {}
			changed[group][key] = next[group][key]
	return changed

static func _reorder(state: Dictionary, category: String, order: Array) -> Dictionary:
	var expected: Array = WEAPON if category == "weapon" else DEFENCE if category == "defence" else []
	if order.size() != expected.size() or expected.is_empty():
		return {"ok": false, "reason": "InvalidEnhancementOrder"}
	for key in expected:
		if order.count(key) != 1:
			return {"ok": false, "reason": "InvalidEnhancementOrder"}
	var next: Dictionary = state.duplicate(true)
	next[category + "_order"] = order.duplicate()
	return {"ok": true, "state": next}

static func _choose(state: Dictionary, effect: String, node: int, choice: String, rules: Dictionary, available: bool, bonus: int) -> Dictionary:
	if node < 0 or node > 2 or choice not in ["A", "B"]:
		return {"ok": false, "reason": "InvalidEnhancementBranch"}
	var effective = _effective_level(state, bonus)
	if not effective.ok: return effective
	var order: Array = state.weapon_order if effect in WEAPON else state.defence_order if effect in DEFENCE else []
	var position: int = order.find(effect)
	if not available or position < 0 or int(effective.level) < int(rules["branch_threshold_" + str(node + 1)]) + int(rules["branch_position_offset_" + str(position + 1)]):
		return {"ok": false, "reason": "EnhancementBranchLocked"}
	var next: Dictionary = state.duplicate(true)
	var choices: Array = next.branches.get(effect, ["", "", ""])
	choices[node] = choice
	next.branches[effect] = choices
	return {"ok": true, "state": next}

static func _quote(state: Dictionary, count: int, rules: Dictionary, amount_api) -> Dictionary:
	var base = amount_api.apply("from_decimal", [str(rules.cost_base)])
	if not base.ok:
		return base
	var cost = amount_api.apply("sum_ceiled_geometric", [base.value, float(rules.cost_growth), str(int(state.level)), str(count)])
	if not cost.ok:
		return cost
	return {"ok": true, "costs": {"jewel": cost.value}, "count": count, "extreme": cost.extreme}

# Purchase quantity is enhancement policy; the economy supplies a read-only predicate.
static func _quote_purchase(state: Dictionary, count: int, rules: Dictionary, api, can_pay: Callable) -> Dictionary:
	if count < 1 or int(state.level) > 9223372036854775807 - count:
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	var quoted = _quote(state, count, rules, api)
	if not quoted.ok:
		return quoted
	if bool(can_pay.call(quoted.costs)): return quoted
	var accepted: Dictionary = {}
	var low: int = 0
	var high: int = count
	while low < high:
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2 + 1
		var candidate = _quote(state, middle, rules, api)
		if candidate.ok and bool(can_pay.call(candidate.costs)):
			low = middle
			accepted = candidate
		else:
			high = middle - 1
	if low == 0:
		return {"ok": false, "reason": "NoChange"}
	return accepted

func presentation_model(inputs:Dictionary,can_pay:Callable)->Dictionary:
	var effective:Dictionary=_effective_level(_state,int(inputs.bonus))
	if not effective.ok:return {}
	var rows:Array=[]
	for order in [_state.weapon_order,_state.defence_order]:
		for position in order.size():
			var key:String=order[position]
			var nodes:Array=[]
			for node in 3:
				var threshold:int=int(_rules["branch_threshold_"+str(node+1)])+int(_rules["branch_position_offset_"+str(position+1)])
				nodes.append({"level":threshold,"enabled":bool(inputs.unlocked.call("feature","jewels")) and int(effective.level)>=threshold,"choice":_state.branches.get(key,["","",""])[node]})
			rows.append({"id":key,"category":"weapon" if key in WEAPON else "defence","active":bool(inputs.unlocked.call("feature","jewels")) and int(effective.level)>=int(_rules["threshold_"+str(position+1)]),"position":position+1,"nodes":nodes})
	var quote:Dictionary=_quote_purchase(_state,1,_rules,_api,func(_costs):return true)
	var costs:PackedStringArray=[]
	if quote.ok:
		for resource in quote.costs:costs.append("强化碎片 "+str(_api.apply("to_display",[quote.costs[resource]]).text))
	return {"paid":int(_state.level),"bonus":int(_state.extra_levels)+int(inputs.bonus),"level":int(effective.level),"price":" · ".join(costs),"affordable":quote.ok and bool(can_pay.call(quote.costs)),"effects":rows}
