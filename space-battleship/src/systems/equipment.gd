extends RefCounted
var _run_state
const BattleSchema = preload("res://src/combat_setup.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")

signal slots_changed(ids: Array)
signal loadout_changed
signal options_changed

var _slots: Array = []
var _pending_slots = null
var _pending_level_slots: Array = []
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

func refresh_availability(unlocked: Callable, highest_reached: int) -> void:
	if not _run_state.is_running(): return
	var next: Dictionary = {}
	for key in _definitions: next[key] = bool(unlocked.call("equipment", key))
	var material: bool = highest_reached >= _material_gate
	if next != _available or material != _material_available:
		_available = next
		_material_available = material
		options_changed.emit()

func initialize_slots(starts: String, mounts: Dictionary) -> void:
	if not _run_state.is_running(): return
	var initial: Dictionary = {"weapon": [], "defence": []}
	for candidate in starts.split(","):
		if not _available.get(candidate, false): continue
		if candidate in ["laser", "cannon", "missile", "longLaser"]: initial.weapon.append(candidate)
		elif candidate in ["armour", "shield"]: initial.defence.append(candidate)
	for category in ["weapon", "defence"]:
		for index in int(mounts[category]):
			_slots.append({"id": category + ":" + str(index), "category": category, "index": index,
				"equipment_id": initial[category][index] if index < initial[category].size() else "",
				"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})

func enemy_override(id: String) -> Dictionary:
	return _definitions.get(id, {})

func damage_types() -> Dictionary:
	return {"strange_damage_type": int(_definitions.cannon.dmgtype), "wild_damage_type": int(_definitions.missile.dmgtype)}

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
	var options: Array = [{"id": "", "name": "卸下", "enabled": true}]
	for key in (["laser", "missile", "cannon", "longLaser"] if id.begins_with("weapon:") else ["armour", "shield"]):
		options.append({"id": key, "name": label(key), "enabled": _available.get(key, false)})
	return options

func price_text(id: String) -> String:
	var quote = quote_slot(id, 1)
	var prices: PackedStringArray = []
	if quote.ok:
		for resource in quote.costs:
			var value = _api.apply("to_display", [quote.costs[resource]])
			prices.append(("铁 " if resource == "1" else "铀 " if resource == "2" else "进化材料 ") + str(value.text))
	return "下一级：" + "，".join(prices) if quote.ok else "进化材料未开放或无法报价"

func _submit_levels(next: Array, balances: Dictionary, changed: Array, publish: Callable) -> Dictionary:
	_pending_slots = next
	_pending_level_slots = changed
	var result: Dictionary = publish.call(balances)
	_pending_slots = null
	_pending_level_slots = []
	if result.ok:
		_slots = next
		var rows: Array = []
		for slot in changed: rows.append(str(slot.id))
		rows.make_read_only()
		slots_changed.emit(rows)
	return result

func _submit_refit(next: Array, balances: Dictionary, publish: Callable) -> Dictionary:
	_pending_slots = next
	var result: Dictionary = publish.call(balances, "refit")
	_pending_slots = null
	if result.ok:
		_slots = next
		loadout_changed.emit()
	return result
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

static func _quote_cost(base, rate: float, level: int, count: int, api) -> Dictionary:
	if not is_finite(rate) or rate < 0 or level < 0 or count < 1 or level > 9223372036854775807 - count:
		return {"ok": false, "reason": "InvalidPriceRange"}
	var threshold: Dictionary = api.apply("from_decimal", ["1e15"]).value
	var total: Dictionary = api.apply("zero", []).value
	var at: int = level + 1
	var last: int = level + count
	# The authored first level may lie above its following Q bucket. Handle it
	# separately; all subsequent prices form monotone contiguous equal-price runs.
	if at == 1:
		var first = _price(base, rate, at, api)
		if not first.ok:
			return first
		total = first.value
		if at == last:
			return {"ok": true, "value": total, "extreme": api.apply("compare", [total, threshold]).scalar >= 0}
		at += 1
	if rate == 0.0:
		var unit = _price(base, rate, at, api)
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
	while at <= last and api.apply("compare", [total, threshold]).scalar < 0:
		var unit = _price(base, rate, at, api)
		if not unit.ok:
			return unit
		if api.apply("compare", [unit.value, threshold]).scalar >= 0:
			break
		var low: int = at
		var high: int = last
		while low < high:
			@warning_ignore("integer_division")
			var middle: int = low + (high - low) / 2 + 1
			var candidate = _price(base, rate, middle, api)
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
		material_unlocked: bool, amount_api) -> Dictionary:
	if count < 1 or level > 9223372036854775807 - count:
		return {"ok": false, "reason": "InvalidEquipmentLevel"}
	var costs: Dictionary = {}
	var extreme: bool = false
	var column: int = 1
	while row.has("res_" + str(column)):
		var resource = row["res_" + str(column)]
		if resource != null:
			var cost = _quote_cost(row["cost_" + str(column)], float(row["costMulti_" + str(column)]), level, count, amount_api)
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
	while high <= limit:
		var quote = _quote_levels(row, level, high, evolution, material_unlocked, api)
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
		var quote = _quote_levels(row, level, middle, evolution, material_unlocked, api)
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
	return _submit_levels(next, paid.wallet, [next[index]], publish)

func equip_slot(slot_id: String, equipment_id: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var index: int = -1
	for candidate in _slots.size():
		if _slots[candidate].id == slot_id:
			index = candidate
	if index < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var slot: Dictionary = _slots[index]
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
				changed.append(slot)
			elif not maximum and paid.get("reason", "") not in ["InsufficientResources", "EvolutionMaterialLocked"]:
				failure = paid
				break
		if not failure.is_empty(): break
	if not purchased.is_empty():
		var committed = _submit_levels(next, balances, changed, publish)
		if not committed.ok: return committed
	if not failure.is_empty(): return failure
	return {"ok": not purchased.is_empty(), "reason": "NoChange" if purchased.is_empty() else "", "slots": purchased}

func resize_mounts(current: Dictionary, target: Dictionary, balances: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
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
