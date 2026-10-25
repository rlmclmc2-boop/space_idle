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
			var base = amount_api.apply("from_decimal", [str(row["cost_" + str(column)])])
			if not base.ok:
				return base
			var cost = amount_api.apply("quote_curve", [base.value, 1.0 + float(row["costMulti_" + str(column)]), str(level), str(count), true])
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
