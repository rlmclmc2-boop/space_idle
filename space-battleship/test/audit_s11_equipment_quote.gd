class_name AuditS11EquipmentQuote
extends RefCounted

# Audit-only S12 candidate. Currency amounts are exact nonnegative integers.
const I := preload("res://scripts/reactor_integer.gd")
const G := preload("res://scripts/growth_number.gd")

static func _old_growth(base: float, multiplier: float, level: int) -> float:
	var value := base * pow(1.0 + multiplier, level - 1)
	if not is_finite(value) or value <= 0.0:
		return value
	if value < 100.0:
		return floorf(value / 10.0) * 10.0 + 5.0
	var step := pow(10.0, floorf(log(value) / log(10.0) + 1e-12) - 1.0)
	return floorf(value / step + 0.5) * step

static func _large_growth(base: float, multiplier: float, level: int) -> Variant:
	# The same binary64 operands are converted to decimal factors only after the
	# old float path overflows. Never recur from the preceding rounded quote.
	if base == 0.0:
		return 0
	var product: Array = I.cost_cursor(base, 1.0 + multiplier, level - 1)
	var digits: String = I.digits(product[0])
	var magnitude: int = digits.length() - int(product[1]) - 1
	if magnitude < 2:
		# The intermediate power may overflow even when its product with a
		# subnormal base is below 100. Preserve floor(v/10)*10+5 exactly.
		var tens: Variant = I._integral([product[0], int(product[1]) + 1], false)
		return I.add(I.multiply(tens, 10), 5)
	var step_power: int = magnitude - 1
	var keep: int = digits.length() - int(product[1]) - step_power
	if keep != 2:
		return null
	var leading: int = int(digits.substr(0, 2))
	# floor(value / step + 0.5): the first discarded decimal digit decides
	# the exact half-step boundary, including a carry from 99 to 100.
	if digits.length() > 2 and digits[2] >= "5":
		leading += 1
	return I.make(str(leading) + "0".repeat(step_power))

static func quote_row(row: Dictionary, level: int, evolution: Dictionary) -> Dictionary:
	if level < 1:
		return {"ok": false, "error": "invalid level"}
	var costs := {}
	for field in row:
		var name := str(field)
		if not name.begins_with("res_") or row[field] == null:
			continue
		var suffix := name.trim_prefix("res_")
		var raw = row.get("cost_" + suffix)
		if raw == null:
			continue
		var base := float(raw)
		var multiplier = row.get("cost_multi_" + suffix, row.get("costMulti_" + suffix))
		if not is_finite(base) or base < 0.0:
			return {"ok": false, "error": "invalid base " + suffix}
		var amount: Variant
		if level > 1 and suffix.is_valid_int() and multiplier != null:
			var multi := float(multiplier)
			if not is_finite(multi) or multi <= -1.0:
				return {"ok": false, "error": "invalid multiplier " + suffix}
			var ordinary := _old_growth(base, multi, level)
			if is_finite(ordinary):
				amount = ceilf(ordinary)
			else:
				amount = _large_growth(base, multi, level)
				if amount == null:
					return {"ok": false, "error": "unrepresentable growth " + suffix}
		else:
			amount = ceilf(base)
		if amount is Dictionary:
			if not I.valid(amount):
				return {"ok": false, "error": "invalid quote " + suffix}
		elif not is_finite(float(amount)):
			return {"ok": false, "error": "invalid quote " + suffix}
		# Ordinary ceilf values are integral binary64. Extract their exact integer
		# payload before sum/compare so batch totals cannot overflow float.
		costs[str(int(row[field]))] = I.float_floor(float(amount)) if not amount is Dictionary else amount
	var interval := int(evolution.get("interval", 0))
	if interval <= 0:
		return {"ok": false, "error": "invalid evolution interval"}
	if level >= interval and level % interval == 0:
		var tiers := level / interval
		costs[str(evolution.material_id)] = I.multiply(int(evolution.material_cost_per_tier), tiers)
	return {"ok": true, "costs": costs}

static func batch(row: Dictionary, current: int, count: int, evolution: Dictionary) -> Dictionary:
	if current < 0 or count < 1 or current > 2147483647 - count:
		return {"ok": false, "error": "invalid batch range"}
	var total := {}
	for level in range(current + 1, current + count + 1):
		var item := quote_row(row, level, evolution)
		if not item.ok:
			return item
		for id in item.costs:
			total[id] = I.add(total.get(id, 0), item.costs[id])
	return {"ok": true, "costs": total}

static func affordable(wallet: Dictionary, costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for id in costs:
		if not wallet.has(id):
			return false
		var balance = wallet[id]
		if not G.valid(balance):
			return false
		if balance is Dictionary and balance.has("m"):
			if I.compare_legacy_growth_to_integer(balance, costs[id]) < 0:
				return false
		elif balance is float:
			# Costs are integers. floor(balance) >= cost is equivalent to the
			# legacy comparison, including a valid fractional wallet balance.
			if I.compare(I.float_floor(balance), costs[id]) < 0:
				return false
		else:
			if I.compare(balance, costs[id]) < 0:
				return false
	return true
