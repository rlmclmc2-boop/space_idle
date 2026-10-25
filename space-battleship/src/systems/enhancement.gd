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
