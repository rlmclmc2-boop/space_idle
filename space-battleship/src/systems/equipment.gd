extends RefCounted
const PlayerText = preload("res://src/ui/player_text.gd")
var _run_state
const BattleSchema = preload("res://src/combat_setup.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")

signal slots_changed(ids: Array)
signal loadout_changed
signal options_changed

var _slots: Array = []
var _pending_slots = null
var _pending_level_slots: Array = []
var _pending_notice: Dictionary = {}
var _material_available: bool = false
var _definitions: Dictionary = {}
var _evolution: Dictionary = {}
var _labels: Dictionary = {}
var _available: Dictionary = {}
var _api
var _cooldown: float
var _material_gate: int

func _init(rows: Array, evolution_rows: Array, unlocks: Array, parameters: Dictionary, rules: Dictionary, api, run_state) -> void:
	_run_state = run_state
	for row in rows:
		var definition: Dictionary = row.duplicate()
		definition.make_read_only()
		_definitions[str(row.name)] = definition
	for row in evolution_rows: _evolution[str(row.key)] = row.value
	for row in unlocks:
		if row.type == "equipment": _labels[str(row.target)] = str(row.title)
	_cooldown = float(parameters.equipmentSwitchCooldownSeconds)
	_material_gate = int(rules.hyperspace_unlock_reached)
	_api = api

func refresh_availability(unlocked: Callable, highest_reached: int, notify: bool = true) -> bool:
	if not _run_state.is_running(): return false
	var next: Dictionary = {}
	for key in _definitions: next[key] = bool(unlocked.call("equipment", key))
	var material: bool = highest_reached >= _material_gate
	if next != _available or material != _material_available:
		_available = next
		_material_available = material
		if notify: options_changed.emit()
		return true
	return false

func publish_availability() -> void:
	options_changed.emit()

func initialize_slots(starts: String, mounts: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var initial: Dictionary = {"weapon": [], "defence": []}
	for candidate in starts.split(","):
		if not _available.get(candidate, false): continue
		if candidate in ["laser", "cannon", "missile", "longLaser"]: initial.weapon.append(candidate)
		elif candidate in ["armour", "shield"]: initial.defence.append(candidate)
	if int(mounts.defence) < 1 or initial.defence.is_empty():
		return {"ok": false, "reason": "FirstDefenceRequired"}
	for category in ["weapon", "defence"]:
		for index in int(mounts[category]):
			_slots.append({"id": category + ":" + str(index), "category": category, "index": index,
				"equipment_id": initial[category][index] if index < initial[category].size() else "",
				"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})
	return {"ok": true}

func save_state() -> Dictionary:
	return {"slots": _slots.duplicate(true)}

func restore_state(state: Dictionary, mounts: Dictionary) -> Dictionary:
	if not state.get("slots") is Array: return {"ok": false, "reason": "InvalidEquipmentState"}
	if state.slots.size() != int(mounts.weapon) + int(mounts.defence):
		return {"ok": false, "reason": "InvalidEquipmentMounts"}
	var seen: Dictionary = {}
	var first_defence: bool = false
	for slot in state.slots:
		if not slot is Dictionary or str(slot.get("category", "")) not in ["weapon", "defence"]:
			return {"ok": false, "reason": "InvalidEquipmentSlot"}
		var category: String = str(slot.category)
		var index: int = int(slot.get("index", -1))
		var id: String = category + ":" + str(index)
		if index < 0 or index >= int(mounts[category]) or str(slot.get("id", "")) != id or seen.has(id) or not slot.get("paid_level") is int or int(slot.paid_level) < 1 or not slot.get("generation") is int or int(slot.generation) < 1 or not slot.get("extra_levels") is int or int(slot.extra_levels) < 0 or not slot.get("switch_ready_at") is float or not is_finite(slot.switch_ready_at):
			return {"ok": false, "reason": "InvalidEquipmentSlot"}
		var equipment_id: String = str(slot.get("equipment_id", ""))
		if not equipment_id.is_empty() and (not _definitions.has(equipment_id) or not _available.get(equipment_id, false)):
			return {"ok": false, "reason": "UnknownEquipment"}
		if category == "defence" and index == 0: first_defence = not equipment_id.is_empty()
		seen[id] = true
	if not first_defence: return {"ok": false, "reason": "FirstDefenceRequired"}
	_slots = state.slots.duplicate(true)
	_pending_slots = null
	_pending_level_slots = []
	_pending_notice = {}
	return {"ok": true}

func enemy_override(id: String) -> Dictionary:
	return _definitions.get(id, {})

func damage_types() -> Dictionary:
	return {"strange_damage_type": int(_definitions.cannon.dmgtype), "wild_damage_type": int(_definitions.missile.dmgtype)}

func drone_weapon_source(weapon_id: String, level_bonus: int, extra_levels: int,
		ai: Dictionary, reactor: Dictionary, motion: Dictionary) -> Dictionary:
	if not _definitions.has(weapon_id) or weapon_id not in ["laser", "missile", "cannon", "longLaser"]:
		return {"ok": false, "reason": "UnknownDroneWeapon"}
	var paid_level: int = 1
	var candidates: Array = _slots if _pending_slots == null else _pending_slots
	for slot in candidates:
		if slot.category == "weapon" and slot.equipment_id == weapon_id:
			paid_level = maxi(paid_level, int(slot.paid_level))
	var slot: Dictionary = {"paid_level": paid_level, "extra_levels": level_bonus}
	var row: Dictionary = _definitions[weapon_id]
	var charged = _charged_base(row, _definitions.armour, slot, extra_levels, _evolution,
		ai.weapon_damage, reactor.weapons, _api)
	if not charged.ok: return charged
	var text = _api.apply("to_display", [charged.value])
	if not text.ok: return text
	var weapon: Dictionary = BattleSchema.weapon(row, weapon_id, str(text.text), 0, false, motion)
	weapon.entry.paid_level = paid_level
	weapon.entry.effective_level = paid_level + level_bonus + extra_levels
	return {"ok": true, "weapon": weapon}

func _slots_for(mounts: Dictionary, candidate = null) -> Array:
	var source: Array = _slots if candidate == null else candidate
	return source.filter(func(slot): return int(slot.index) < int(mounts[slot.category]))

func geometry_changed() -> bool:
	if _pending_slots == null: return false
	for index in _pending_slots.size():
		if index >= _slots.size() or _pending_slots[index].equipment_id != _slots[index].equipment_id: return true
	return false

func equipped_armours(mounts: Dictionary) -> int:
	return _armour_count(_slots_for(mounts, _pending_slots))

func clear_switch_locks() -> void:
	if not _run_state.is_running(): return
	for slot in _slots: slot.switch_ready_at = 0.0
	if _pending_slots != null:
		for slot in _pending_slots: slot.switch_ready_at = 0.0

func label(id: String) -> String:
	return "空槽" if id.is_empty() else str(_labels.get(id, id))

func _slot_option(slot: Dictionary) -> Dictionary:
	return {"id": str(slot.id), "label": ("武器 " if slot.category == "weapon" else "防具 ") + str(int(slot.index) + 1) + " · " + label(str(slot.equipment_id)) + " · Lv." + str(slot.paid_level)}

func panel_slots(mounts: Dictionary, ids: Array = []) -> Array:
	var rows: Array = []
	for slot in _slots_for(mounts):
		if ids.is_empty() or str(slot.id) in ids: rows.append(_slot_option(slot))
	return rows

func panel_equipment(id: String) -> Array:
	var options: Array = [] if id == "defence:0" else [{"id": "", "name": "卸下", "enabled": true}]
	for key in (["laser", "missile", "cannon", "longLaser"] if id.begins_with("weapon:") else ["armour", "shield"]):
		options.append({"id": key, "name": label(key), "enabled": _available.get(key, false)})
	return options

# Read accepted slots only; never consume the pending configuration.
func slot_facts(mounts: Dictionary, game_time: float, extra_bonus: int) -> Array:
	var rows: Array = []
	for slot in _slots:
		var effective = null
		if int(slot.extra_levels) <= 9223372036854775807 - extra_bonus:
			var bonus: int = int(slot.extra_levels) + extra_bonus
			if int(slot.paid_level) <= 9223372036854775807 - bonus: effective = int(slot.paid_level) + bonus
		rows.append({"id": str(slot.id), "category": str(slot.category), "index": int(slot.index),
			"equipment_id": str(slot.equipment_id), "paid_level": int(slot.paid_level), "effective_level": effective,
			"dormant": int(slot.index) >= int(mounts[slot.category]), "switch_ready_at": float(slot.switch_ready_at),
			"cooldown_remaining": maxf(0.0, float(slot.switch_ready_at) - game_time)})
	return rows

func _comparison_value(slot: Dictionary, key: String, count: int, inputs: Dictionary) -> Dictionary:
	var result := {"equipment_id": key, "paid_level": int(slot.paid_level), "effective_level": null,
		"status": "empty" if key.is_empty() else "unknown", "reason": "", "primary": null, "properties": {}}
	if count < 0 or int(slot.paid_level) > 9223372036854775807 - count:
		result.reason = "InvalidEquipmentLevel"; return result
	var candidate: Dictionary = slot.duplicate(true)
	candidate.paid_level = int(candidate.paid_level) + count
	result.paid_level = candidate.paid_level
	if key.is_empty(): return result
	if not _definitions.has(key): result.reason = "EquipmentLocked"; return result
	var row: Dictionary = _definitions[key]
	var value: Dictionary = _charged_base(row, _definitions.armour, candidate, int(inputs.extra_bonus), _evolution,
		inputs.ai.equipment_durability if slot.category == "defence" else inputs.ai.weapon_damage,
		inputs.reactor.defence if slot.category == "defence" else inputs.reactor.weapons, _api)
	if not value.ok: result.reason = str(value.get("reason", value.get("error", "AmountError"))); return result
	var text: Dictionary = _api.apply("to_display", [value.value])
	if not text.ok: result.reason = str(text.get("error", "AmountError")); return result
	result.effective_level = int(candidate.paid_level) + int(candidate.extra_levels) + int(inputs.extra_bonus)
	result.primary = text.text
	result.status = "known"
	result.properties = {"damage_type": int(row.dmgtype)}
	if key in ["armour", "shield"]:
		if key == "shield": result.properties.merge({"recovery_rate": float(row.para2), "recovery_delay_seconds": float(row.para3)})
	else:
		result.properties.interval_seconds = float(row.cd)
		if key == "missile": result.properties.salvo_count = int(row.para1)
		if key == "longLaser": result.properties.charge_seconds = float(row.para3)
	return result

func quote_max_levels(slot_id: String, inputs: Dictionary, can_pay: Callable) -> Dictionary:
	for slot in _slots:
		if str(slot.id) == slot_id:
			return _quote_affordable_levels(_definitions.laser if slot.category == "weapon" else _definitions.armour,
				int(slot.paid_level), _evolution, _material_available, _api,
				func(costs): return bool(can_pay.call(costs, inputs.balances)))
	return {"ok": false, "reason": "UnknownSlot"}

func slot_comparison(slot_id: String, candidate_id: String, count: int, inputs: Dictionary,
		can_pay: Callable, maximum: bool = false) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var selected: Dictionary = {}
	for slot in _slots:
		if str(slot.id) == slot_id: selected = slot; break
	if selected.is_empty(): return {"ok": false, "reason": "UnknownSlot"}
	var quote: Dictionary = quote_max_levels(slot_id, inputs, func(costs, balances): return bool(can_pay.call(costs, balances).ok)) if maximum else quote_slot(slot_id, count)
	var admission: Dictionary = _equip_admission(selected, candidate_id, inputs)
	var upgraded = null
	if quote.ok: upgraded = _comparison_value(selected, str(selected.equipment_id), int(quote.count), inputs)
	var candidate: Dictionary = _comparison_value(selected, candidate_id, 0, inputs)
	if not candidate_id.is_empty() and ((selected.category == "weapon" and candidate_id not in ["laser", "missile", "cannon", "longLaser"]) or (selected.category == "defence" and candidate_id not in ["armour", "shield"])):
		candidate.primary = null; candidate.status = "unknown"; candidate.reason = "EquipmentCategoryMismatch"
	var affordability: Dictionary = can_pay.call(quote.costs, inputs.balances) if quote.ok else quote
	return {"ok": true, "slot_id": slot_id, "candidate_id": candidate_id, "scope": "charged_base",
		"dormant": int(selected.index) >= int(inputs.mounts[selected.category]), "upgrade_count": int(quote.count) if quote.ok else null,
		"quote": quote.duplicate(true), "affordable": quote.ok and affordability.ok, "payment_reason": str(affordability.get("reason", affordability.get("error", ""))),
		"switch_admission": admission, "current": _comparison_value(selected, str(selected.equipment_id), 0, inputs),
		"upgrade": upgraded, "candidate": candidate}

# Capture the execution quote before publication; callbacks may reenter.
func _purchase_result(result: Dictionary, purchases: Array, status: String) -> Dictionary:
	var output: Dictionary = result.duplicate(true)
	var total: Dictionary = {}
	var receipt := {"commit_status": status, "purchases": purchases.duplicate(true) if status == "accepted" else [],
		"spent": null if status == "fault_unknown" else total}
	if status == "accepted":
		for item in purchases:
			for resource in item.spent:
				if not total.has(resource): total[resource] = item.spent[resource].duplicate(true)
				else:
					var summed: Dictionary = _api.apply("add", [total[resource], item.spent[resource]])
					if not summed.ok:
						receipt.spent = null; receipt.error = summed.get("error", "AmountError")
						output.purchase_receipt = receipt; return output
					total[resource] = summed.value
	output.purchase_receipt = receipt
	return output

func price_text(id: String) -> String:
	var quote = quote_slot(id, 1)
	var prices: PackedStringArray = []
	if quote.ok:
		for resource in quote.costs:
			var value = _api.apply("to_display", [quote.costs[resource]])
			prices.append(("铁 " if resource == "1" else "铀 " if resource == "2" else "进化材料 ") + PlayerText.number(str(value.text)))
	return "下一级：" + "，".join(prices) if quote.ok else "进化材料未开放或无法报价"

func _submit_levels(next: Array, balances: Dictionary, changed: Array, publish: Callable) -> Dictionary:
	_pending_slots = next
	_pending_level_slots = changed
	var rows: Array = []
	for slot in changed: rows.append(str(slot.id))
	rows.make_read_only()
	_pending_notice = {"kind": "levels", "ids": rows}
	var result: Dictionary = publish.call(balances)
	if not result.ok: discard_prepared()
	return result

func _submit_refit(next: Array, balances: Dictionary, publish: Callable) -> Dictionary:
	_pending_slots = next
	_pending_notice = {"kind": "refit"}
	var result: Dictionary = publish.call(balances, "refit")
	if not result.ok: discard_prepared()
	return result

func accept_prepared() -> Dictionary:
	_slots = _pending_slots
	var notice: Dictionary = _pending_notice
	discard_prepared()
	return notice

func discard_prepared() -> void:
	_pending_slots = null
	_pending_level_slots = []
	_pending_notice = {}

func publish_accepted(notice: Dictionary) -> void:
	if notice.kind == "levels": slots_changed.emit(notice.ids)
	elif notice.kind == "refit": loadout_changed.emit()
## Static equipment arithmetic stops at charged_base. History stays in native.

static func _growth(base, rate: float, effective_level: int, amount_api) -> Dictionary:
	var quantity = amount_api.apply("from_decimal", [str(base)])
	if not quantity.ok or effective_level < 1:
		return quantity if not quantity.ok else {"ok": false, "reason": "InvalidEquipmentLevel"}
	if effective_level == 1:
		return quantity
	var factor = amount_api.apply("from_decimal", [str(1.0 + rate)])
	if not factor.ok:
		return factor
	factor = amount_api.apply("pow", [factor.value, effective_level - 1])
	if not factor.ok:
		return factor
	quantity = amount_api.apply("mul", [quantity.value, factor.value])
	if not quantity.ok:
		return quantity
	var threshold = amount_api.apply("from_decimal", ["100"])
	var compare = amount_api.apply("compare", [quantity.value, threshold.value])
	if not compare.ok:
		return compare
	if compare.scalar >= 0:
		return amount_api.apply("round_significant", [quantity.value, "2"])
	var ten = amount_api.apply("from_decimal", ["10"])
	quantity = amount_api.apply("div", [quantity.value, ten.value])
	if not quantity.ok:
		return quantity
	quantity = amount_api.apply("floor", [quantity.value])
	if not quantity.ok:
		return quantity
	quantity = amount_api.apply("mul", [quantity.value, ten.value])
	if not quantity.ok:
		return quantity
	var five = amount_api.apply("from_decimal", ["5"])
	return amount_api.apply("add", [quantity.value, five.value])

static func _charged_base(row: Dictionary, armour_row: Dictionary, slot: Dictionary, extra_bonus: int, evolution: Dictionary, ai_factor: Dictionary, reactor_factor: Dictionary, amount_api) -> Dictionary:
	var paid_level: int = int(slot.paid_level)
	if int(slot.extra_levels) > 9223372036854775807 - extra_bonus:
		return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
	var extra_levels: int = int(slot.extra_levels) + extra_bonus
	if paid_level < 1 or extra_levels < 0 or paid_level > 9223372036854775807 - extra_levels:
		return {"ok": false, "reason": "InvalidEquipmentLevel"}
	var inputs: Array = [row.name, paid_level, extra_levels, ai_factor, reactor_factor]
	var cached: Dictionary = slot.get("_charged", {})
	if cached.get("inputs", []) == inputs: return {"ok": true, "value": cached.value}
	var level: int = paid_level + extra_levels
	var defensive: bool = row.name in ["armour", "shield"]
	var source: Dictionary = armour_row if row.name == "shield" else row
	var result = _growth(source.para1 if defensive else source.dmg,
		float(source.para2 if defensive else source.dmgMulti), level, amount_api)
	if not result.ok:
		return result
	if row.name == "shield":
		var shield_base = amount_api.apply("from_decimal", [str(row.para1)])
		var armour_base = amount_api.apply("from_decimal", [str(armour_row.para1)])
		if not shield_base.ok or not armour_base.ok:
			return shield_base if not shield_base.ok else armour_base
		var ratio = amount_api.apply("div", [shield_base.value, armour_base.value])
		if not ratio.ok:
			return ratio
		result = amount_api.apply("mul", [result.value, ratio.value])
		if not result.ok:
			return result
	var interval: int = int(evolution.interval)
	if interval < 1:
		return {"ok": false, "reason": "InvalidEvolutionInterval"}
	@warning_ignore("integer_division")
	var tier: int = paid_level / interval
	if tier > 0:
		var first = amount_api.apply("from_decimal", [str(evolution.first_stat_multiplier)])
		var later = amount_api.apply("from_decimal", [str(evolution.later_stat_multiplier)])
		if not first.ok or not later.ok:
			return first if not first.ok else later
		later = amount_api.apply("pow", [later.value, tier - 1])
		if not later.ok:
			return later
		var factor = amount_api.apply("mul", [first.value, later.value])
		if not factor.ok:
			return factor
		result = amount_api.apply("mul", [result.value, factor.value])
		if not result.ok:
			return result
	result = amount_api.apply("mul", [result.value, ai_factor])
	if not result.ok:
		return result
	result = amount_api.apply("ceil", [result.value])
	if not result.ok:
		return result
	result = amount_api.apply("mul", [result.value, reactor_factor])
	if not result.ok:
		return result
	result = amount_api.apply("ceil", [result.value])
	if result.ok: slot._charged = {"inputs": inputs, "value": result.value}
	return result

# One equipment policy for attributes, individual prices, batch purchases and MAX.
static func _price(base, rate: float, target: int, api) -> Dictionary:
	var value = _growth(base, rate, target, api)
	if not value.ok:
		return value
	return api.apply("ceil", [value.value])

static func _search_price(base, rate: float, target: int, api, search_cache) -> Dictionary:
	if search_cache == null: return _price(base, rate, target, api)
	var key: Array = ["price", base, rate, target]
	if search_cache.has(key): return search_cache[key]
	var result: Dictionary = _price(base, rate, target, api)
	if result.ok: search_cache[key] = result
	return result

static func _quote_cost(base, rate: float, level: int, count: int, api, search_cache = null) -> Dictionary:
	if not is_finite(rate) or rate < 0 or level < 0 or count < 1 or level > 9223372036854775807 - count:
		return {"ok": false, "reason": "InvalidPriceRange"}
	var threshold: Dictionary = api.apply("from_decimal", ["1e15"]).value
	var total: Dictionary = api.apply("zero", []).value
	var at: int = level + 1
	var last: int = level + count
	var cache_key: Array = ["extreme", base, rate, level]
	# The authored first level may lie above its following Q bucket. Handle it
	# separately; all subsequent prices form monotone contiguous equal-price runs.
	if at == 1:
		var first = _search_price(base, rate, at, api, search_cache)
		if not first.ok:
			return first
		total = first.value
		if at == last:
			return {"ok": true, "value": total, "extreme": api.apply("compare", [total, threshold]).scalar >= 0}
		at += 1
	if rate == 0.0:
		var unit = _search_price(base, rate, at, api, search_cache)
		if not unit.ok:
			return unit
		var terms = api.apply("from_decimal", [str(last - at + 1)])
		var part = api.apply("mul", [unit.value, terms.value])
		if not part.ok:
			return part
		var sum = api.apply("add", [total, part.value])
		if not sum.ok:
			return sum
		return {"ok": true, "value": sum.value, "extreme": api.apply("compare", [sum.value, threshold]).scalar >= 0}
	# A MAX search repeatedly quotes this same prefix. Once a complete equal-price
	# run reaches the existing extreme boundary, larger counts use the same raw
	# geometric policy and need not rebuild that ordinary prefix.
	if search_cache != null and search_cache.has(cache_key) and count >= int(search_cache[cache_key]):
		at = last + 1 if last < 9223372036854775807 else last
		total = threshold
	while at <= last and api.apply("compare", [total, threshold]).scalar < 0:
		var unit = _search_price(base, rate, at, api, search_cache)
		if not unit.ok:
			return unit
		if api.apply("compare", [unit.value, threshold]).scalar >= 0:
			if search_cache != null: search_cache[cache_key] = at - level
			break
		var low: int = at
		var high: int = last
		while low < high:
			@warning_ignore("integer_division")
			var middle: int = low + (high - low) / 2 + 1
			var candidate = _search_price(base, rate, middle, api, search_cache)
			if not candidate.ok:
				return candidate
			if api.apply("compare", [candidate.value, unit.value]).scalar == 0:
				low = middle
			else:
				high = middle - 1
		var terms = api.apply("from_decimal", [str(low - at + 1)])
		var part = api.apply("mul", [unit.value, terms.value])
		if not part.ok:
			return part
		var sum = api.apply("add", [total, part.value])
		if not sum.ok:
			return sum
		total = sum.value
		if api.apply("compare", [total, threshold]).scalar >= 0:
			if search_cache != null: search_cache[cache_key] = low - level
			break
		if low == last:
			return {"ok": true, "value": total, "extreme": false}
		at = low + 1
	# Same Amount precision boundary for every caller; extreme quotations use
	# the raw geometric approximation rather than iterating levels.
	var quantity = api.apply("from_decimal", [str(base)])
	var factor = api.apply("from_decimal", [str(1.0 + rate)])
	for result in [quantity, factor]:
		if not result.ok:
			return result
	factor = api.apply("pow", [factor.value, level])
	if not factor.ok:
		return factor
	quantity = api.apply("mul", [quantity.value, factor.value])
	if not quantity.ok:
		return quantity
	var series = api.apply("sum_geometric", [1.0 + rate, str(count)])
	if not series.ok:
		return series
	quantity = api.apply("mul", [quantity.value, series.value])
	if not quantity.ok:
		return quantity
	quantity = api.apply("max", [quantity.value, threshold])
	quantity = api.apply("ceil", [quantity.value])
	if quantity.ok:
		quantity.extreme = true
	return quantity

static func _quote_levels(row: Dictionary, level: int, count: int, evolution: Dictionary,
		material_unlocked: bool, amount_api, search_cache = null) -> Dictionary:
	if count < 1 or level > 9223372036854775807 - count:
		return {"ok": false, "reason": "InvalidEquipmentLevel"}
	var costs: Dictionary = {}
	var extreme: bool = false
	var column: int = 1
	while row.has("res_" + str(column)):
		var resource = row["res_" + str(column)]
		if resource != null:
			var cost = _quote_cost(row["cost_" + str(column)], float(row["costMulti_" + str(column)]), level, count, amount_api, search_cache)
			if not cost.ok:
				return cost
			var key: String = str(int(resource))
			if costs.has(key):
				var merged = amount_api.apply("add", [costs[key], cost.value])
				if not merged.ok:
					return merged
				costs[key] = merged.value
			else:
				costs[key] = cost.value
			extreme = extreme or cost.extreme
		column += 1
	var interval: int = int(evolution.interval)
	@warning_ignore("integer_division")
	var first: int = level / interval + 1
	@warning_ignore("integer_division")
	var last: int = (level + count) / interval
	if last >= first:
		if not material_unlocked:
			return {"ok": false, "reason": "EvolutionMaterialLocked"}
		var sum = amount_api.apply("from_decimal", [str(first + last)])
		var terms = amount_api.apply("from_decimal", [str(last - first + 1)])
		var half_cost = amount_api.apply("from_decimal", [str(float(evolution.material_cost_per_tier) / 2.0)])
		for item in [sum, terms, half_cost]:
			if not item.ok:
				return item
		sum = amount_api.apply("mul", [sum.value, terms.value])
		if not sum.ok:
			return sum
		sum = amount_api.apply("mul", [sum.value, half_cost.value])
		if not sum.ok:
			return sum
		costs[str(evolution.material_id)] = sum.value
	return {"ok": true, "count": count, "costs": costs, "extreme": extreme}

# The economy supplies only affordability; equipment owns MAX search and its limits.
static func _quote_affordable_levels(row: Dictionary, level: int, evolution: Dictionary, material_unlocked: bool, api, can_pay: Callable) -> Dictionary:
	var limit: int = 9223372036854775807 - level
	if limit <= 0:
		return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
	var accepted: Dictionary = {}
	var low: int = 0
	var high: int = 1
	var search_cache: Dictionary = {}
	while high <= limit:
		var quote = _quote_levels(row, level, high, evolution, material_unlocked, api, search_cache)
		if not quote.ok or not bool(can_pay.call(quote.costs)):
			break
		low = high
		accepted = quote
		if high == limit:
			return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
		high = limit if high > limit / 2 else high * 2
	while low + 1 < high:
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2
		var quote = _quote_levels(row, level, middle, evolution, material_unlocked, api, search_cache)
		if quote.ok and bool(can_pay.call(quote.costs)):
			low = middle
			accepted = quote
		else:
			high = middle
	if low == 0:
		return {"ok": false, "reason": "NoChange"}
	return accepted

static func _armour_count(slots: Array) -> int:
	var count: int = 0
	for slot in slots:
		if slot.equipment_id == "armour": count += 1
	return count

func buy_levels(slot_id: String, count: int, inputs: Dictionary, pay: Callable, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var index: int = -1
	for candidate in _slots.size():
		if _slots[candidate].id == slot_id:
			index = candidate
	if index < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var slot: Dictionary = _slots[index]
	var row: Dictionary = _definitions.laser if slot.category == "weapon" else _definitions.armour
	var quote = _quote_levels(row, int(slot.paid_level), count, _evolution, _material_available, _api)
	return _buy_quoted_levels(index, quote, inputs, pay, publish)

func _buy_quoted_levels(index: int, quote: Dictionary, inputs: Dictionary, pay: Callable, publish: Callable) -> Dictionary:
	if not quote.ok: return quote
	var paid = pay.call(quote.costs, inputs.balances)
	if not paid.ok: return paid
	var next: Array = _slots.duplicate(true)
	next[index].paid_level = int(_slots[index].paid_level) + int(quote.count)
	var purchases := [{"slot_id": str(next[index].id), "count": int(quote.count), "spent": quote.costs.duplicate(true)}]
	var committed: Dictionary = _submit_levels(next, paid.wallet, [next[index]], publish)
	return _purchase_result(committed, purchases, "accepted" if committed.ok else "fault_unknown" if committed.get("fault", false) else "rejected")

func _equip_admission(slot: Dictionary, equipment_id: String, inputs: Dictionary) -> Dictionary:
	if slot.category == "defence" and int(slot.index) == 0 and equipment_id.is_empty():
		return {"ok": false, "reason": "FirstDefenceRequired"}
	if equipment_id == str(slot.equipment_id):
		return {"ok": false, "reason": "NoChange"}
	if float(inputs.game_time) < float(slot.switch_ready_at):
		return {"ok": false, "reason": "EquipmentSwitchLocked"}
	if not equipment_id.is_empty():
		if not _definitions.has(equipment_id) or not _available.get(equipment_id, false):
			return {"ok": false, "reason": "EquipmentLocked"}
		if (slot.category == "weapon" and equipment_id not in ["laser", "cannon", "missile", "longLaser"]) or (slot.category == "defence" and equipment_id not in ["armour", "shield"]):
			return {"ok": false, "reason": "EquipmentCategoryMismatch"}
	if int(slot.generation) == 9223372036854775807:
		return {"ok": false, "reason": "ModuleGenerationRangeExceeded"}
	return {"ok": true}

func equip_slot(slot_id: String, equipment_id: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var index: int = -1
	for candidate in _slots.size():
		if _slots[candidate].id == slot_id:
			index = candidate
	if index < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var slot: Dictionary = _slots[index]
	var admitted: Dictionary = _equip_admission(slot, equipment_id, inputs)
	if not admitted.ok: return admitted
	var next: Array = _slots.duplicate(true)
	next[index].equipment_id = equipment_id
	next[index].generation = int(slot.generation) + 1
	next[index].switch_ready_at = float(inputs.game_time) + _cooldown
	return _submit_refit(next, inputs.balances, publish)

func quote_slot(slot_id: String, count: int) -> Dictionary:
	for slot in _slots:
		if str(slot.id) == slot_id:
			var row: Dictionary = _definitions.laser if slot.category == "weapon" else _definitions.armour
			return _quote_levels(row, int(slot.paid_level), count, _evolution, _material_available, _api)
	return {"ok": false, "reason": "UnknownSlot"}

func buy_max_levels(slot_id: String, inputs: Dictionary, can_pay: Callable, pay: Callable, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	for index in _slots.size():
		if str(_slots[index].id) == slot_id:
			return _buy_quoted_levels(index, _quote_affordable_levels(
				_definitions.laser if _slots[index].category == "weapon" else _definitions.armour,
				int(_slots[index].paid_level), _evolution, _material_available,
				_api, func(costs): return bool(can_pay.call(costs, inputs.balances))), inputs, pay, publish)
	return {"ok": false, "reason": "UnknownSlot"}

func buy_all_levels(count: int, maximum: bool, inputs: Dictionary, can_pay: Callable, pay: Callable, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var purchased: Array = []
	var purchases: Array = []
	var changed: Array = []
	var next: Array = _slots.duplicate(true)
	var balances: Dictionary = inputs.balances
	var failure: Dictionary = {}
	var mounts: Dictionary = inputs.mounts
	var material_unlocked: bool = _material_available
	for category in ["weapon", "defence"]:
		for slot in next:
			if slot.category != category or int(slot.index) >= int(mounts[category]):
				continue
			var row: Dictionary = _definitions.laser if category == "weapon" else _definitions.armour
			var quote = _quote_affordable_levels(row, int(slot.paid_level), _evolution, material_unlocked, _api,
				func(costs): return bool(can_pay.call(costs, balances))) if maximum else _quote_levels(row, int(slot.paid_level), count, _evolution, material_unlocked, _api)
			var paid = pay.call(quote.costs, balances) if quote.ok else quote
			if paid.ok:
				balances = paid.wallet
				slot.paid_level = int(slot.paid_level) + int(quote.count)
				purchased.append(str(slot.id))
				purchases.append({"slot_id": str(slot.id), "count": int(quote.count), "spent": quote.costs.duplicate(true)})
				changed.append(slot)
			elif not maximum and paid.get("reason", "") not in ["InsufficientResources", "EvolutionMaterialLocked"]:
				failure = paid
				break
		if not failure.is_empty(): break
	if not purchased.is_empty():
		var committed = _submit_levels(next, balances, changed, publish)
		if not committed.ok: return _purchase_result(committed, purchases, "fault_unknown" if committed.get("fault", false) else "rejected")
	var status: String = "accepted" if not purchased.is_empty() else "not_submitted"
	if not failure.is_empty(): return _purchase_result(failure, purchases, status)
	return _purchase_result({"ok": not purchased.is_empty(), "reason": "NoChange" if purchased.is_empty() else "", "slots": purchased}, purchases, status)

func resize_mounts(current: Dictionary, target: Dictionary, balances: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if int(target.defence) < 1: return {"ok": false, "reason": "FirstDefenceRequired"}
	var next: Array = _slots.duplicate(true)
	for category in ["weapon", "defence"]:
		var old_count: int = int(current[category])
		var new_count: int = int(target[category])
		for index in maxi(old_count, new_count):
			var id: String = category + ":" + str(index)
			var found: bool = false
			for slot in next:
				if slot.id != id:
					continue
				found = true
				if (index < old_count) != (index < new_count):
					if int(slot.generation) == 9223372036854775807:
						return {"ok": false, "reason": "ModuleGenerationRangeExceeded"}
					slot.generation = int(slot.generation) + 1
			if not found:
				next.append({"id": id, "category": category, "index": index, "equipment_id": "",
					"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})
	return _submit_refit(next, balances, publish)

func values(mounts: Dictionary, extra_levels: int, ai: Dictionary, reactor: Dictionary, weapons: bool, defences: bool, changed_only: bool = false) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var slots: Array = _slots_for(mounts, _pending_level_slots if changed_only else _pending_slots)
	var definitions: Dictionary = _definitions
	var evolution: Dictionary = _evolution
	var api = _api
	var result: Dictionary = {"ok": true, "weapons": {}, "defences": {}}
	for slot in slots:
		if str(slot.equipment_id).is_empty() or (slot.category == "weapon" and not weapons) or (slot.category == "defence" and not defences): continue
		var row: Dictionary = definitions[str(slot.equipment_id)]
		var value = _charged_base(row, definitions.armour, slot, extra_levels, evolution,
			ai.equipment_durability if slot.category == "defence" else ai.weapon_damage,
			reactor.defence if slot.category == "defence" else reactor.weapons, api)
		if not value.ok: return value
		var text = api.apply("to_display", [value.value])
		if not text.ok: return text
		result["defences" if slot.category == "defence" else "weapons"][str(slot.id)] = {"key": str(row.name), "generation": int(slot.generation), "base": text.text, "paid_level": int(slot.paid_level), "effective_level": int(slot.paid_level) + int(slot.extra_levels) + extra_levels}
	return result

func mounted_configuration(mounts: Dictionary, extra_levels: int, ai: Dictionary, reactor: Dictionary,
		player_art: Dictionary, player_dimensions: Vector2, geometry: Dictionary, motion: Dictionary, external: Array) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var slots: Array = _slots_for(mounts, _pending_slots)
	var base_values = values(mounts, extra_levels, ai, reactor, true, true)
	if not base_values.ok: return base_values
	var player_point := Vector2(float(geometry.player_x), float(geometry.player_y))
	var weapons: Array = []
	var defences: Array = []
	for slot in slots:
		if str(slot.equipment_id).is_empty():
			continue
		var row: Dictionary = _definitions[str(slot.equipment_id)]
		var text: Dictionary = {"text": base_values["defences" if slot.category == "defence" else "weapons"][str(slot.id)].base}
		if row.name in ["armour", "shield"]:
			defences.append({"entry": {"id": str(slot.id), "key": str(row.name), "generation": int(slot.generation)},
				"layer": 0 if row.name == "shield" else 1, "type": int(row.dmgtype),
				"base": text.text, "maximum": text.text, "factor": 1.0, "loss": "0", "buffer": "0",
				"delay": float(row.para3) if row.name == "shield" else 0.0,
				"rate": float(row.para2) if row.name == "shield" else 0.0,
				"branch_factors": [], "external_factors": external.duplicate()})
		else:
			var row_weapon: Dictionary = BattleSchema.weapon(row, str(row.name), str(text.text), int(slot.index), false, motion)
			row_weapon.muzzle = Geometry.mount_position(player_art, int(slot.index), player_point, player_dimensions)
			row_weapon.external_factors = external.duplicate()
			row_weapon.entry.id = str(slot.id)
			row_weapon.entry.generation = int(slot.generation)
			row_weapon.entry.paid_level = int(slot.paid_level)
			row_weapon.entry.effective_level = int(slot.paid_level) + int(slot.extra_levels) + extra_levels
			weapons.append(row_weapon)
	for group in [weapons, defences]:
		for mounted in group:
			mounted.entry.make_read_only()
			mounted.branch_factors.make_read_only()
			mounted.external_factors.make_read_only()
			mounted.make_read_only()
		group.make_read_only()
	for group in ["weapons", "defences"]:
		for value in base_values[group].values(): value.make_read_only()
		base_values[group].make_read_only()
	base_values.make_read_only()
	var output := {"ok": true, "weapons": weapons, "defences": defences, "values": base_values}
	output.make_read_only()
	return output

func apply_external(values: Dictionary, mounts: Dictionary, external: Array) -> void:
	if not _run_state.is_running(): return
	for slot in _slots_for(mounts):
		if str(slot.equipment_id).is_empty(): continue
		var group: String = "weapons" if slot.category == "weapon" else "defences"
		var row: Dictionary = values[group].get(str(slot.id), {"key": str(slot.equipment_id), "generation": int(slot.generation)})
		row.external = external.duplicate()
		values[group][str(slot.id)] = row
