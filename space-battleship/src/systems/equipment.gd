extends RefCounted
## Static equipment arithmetic stops at charged_base. History stays in native.

static func growth(base, rate: float, effective_level: int, amount_api) -> Dictionary:
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

static func charged_base(row: Dictionary, armour_row: Dictionary, paid_level: int, extra_levels: int, evolution: Dictionary, ai_factor: Dictionary, reactor_factor: Dictionary, amount_api) -> Dictionary:
	if paid_level < 1 or extra_levels < 0 or paid_level > 9223372036854775807 - extra_levels:
		return {"ok": false, "reason": "InvalidEquipmentLevel"}
	var level: int = paid_level + extra_levels
	var defensive: bool = row.name in ["armour", "shield"]
	var source: Dictionary = armour_row if row.name == "shield" else row
	var result = growth(source.para1 if defensive else source.dmg,
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
	return amount_api.apply("ceil", [result.value])

# One equipment policy for attributes, individual prices, batch purchases and MAX.
static func _price(base, rate: float, target: int, api) -> Dictionary:
	var value = growth(base, rate, target, api)
	if not value.ok:
		return value
	return api.apply("ceil", [value.value])

static func quote_cost(base, rate: float, level: int, count: int, api) -> Dictionary:
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

static func quote_levels(row: Dictionary, level: int, count: int, evolution: Dictionary,
		material_unlocked: bool, amount_api) -> Dictionary:
	if count < 1 or level > 9223372036854775807 - count:
		return {"ok": false, "reason": "InvalidEquipmentLevel"}
	var costs: Dictionary = {}
	var extreme: bool = false
	var column: int = 1
	while row.has("res_" + str(column)):
		var resource = row["res_" + str(column)]
		if resource != null:
			var cost = quote_cost(row["cost_" + str(column)], float(row["costMulti_" + str(column)]), level, count, amount_api)
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
