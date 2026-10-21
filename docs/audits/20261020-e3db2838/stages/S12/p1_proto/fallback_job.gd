extends RefCounted

# Audit-only resumable high-price quote. A call advances at most one binary
# exponentiation iteration or one final bound check; cancellation is checked
# between those units. This is not yet a worst-case proof for arbitrary large
# precision multiplication, and does not authorize a public game interface.
const I = preload("res://reference_integer.gd")
const Price = preload("res://price_probe.gd")
const PRECISIONS := [16, 24, 32, 48, 96, 192, 384]

var engine = Price.new()
var base_part: Array
var growth_part: Array
var level: int
var precision_index := 0
var precision := 0
var lower: Array
var upper: Array
var low_power: Array
var high_power: Array
var count: int
var phase := "begin"
var cancelled := false
var outcome: Array = []
var work_units := 0
var return_bounds := false

func _init(base: float, growth: float, target_level: int, want_bounds: bool = false) -> void:
	base_part = I.decimal_factor(base)
	growth_part = I.decimal_factor(growth)
	level = target_level
	return_bounds = want_bounds
	if base <= 0.0 or growth <= 0.0 or target_level < 1:
		phase = "error"

func cancel() -> void:
	cancelled = true

func step() -> Dictionary:
	if cancelled:
		phase = "cancelled"
		return {"state":"cancelled"}
	if phase == "complete":
		return {"state":"complete","lower":lower,"upper":upper} if return_bounds else {"state":"complete","price":outcome}
	if phase == "error":
		return {"state":"error"}
	if phase == "begin":
		if precision_index >= PRECISIONS.size():
			phase = "error"
			return {"state":"error","reason":"precision_unresolved"}
		precision = PRECISIONS[precision_index]
		lower = [1, 0]
		upper = [1, 0]
		low_power = [growth_part[0], -int(growth_part[1])]
		high_power = low_power.duplicate()
		count = level - 1
		phase = "power"
		return {"state":"pending"}
	if phase == "power":
		if count > 0:
			if count % 2 == 1:
				lower = engine.multiply_bound(lower, low_power, precision, false)
				upper = engine.multiply_bound(upper, high_power, precision, true)
			count /= 2
			if count > 0:
				low_power = engine.multiply_bound(low_power, low_power, precision, false)
				high_power = engine.multiply_bound(high_power, high_power, precision, true)
			work_units += 1
			return {"state":"pending"}
		phase = "finish"
		return {"state":"pending"}
	if phase == "finish":
		lower = engine.multiply_bound(lower, [base_part[0], -int(base_part[1])], precision, false)
		upper = engine.multiply_bound(upper, [base_part[0], -int(base_part[1])], precision, true)
		if return_bounds:
			phase = "complete"
			work_units += 1
			return {"state":"complete","lower":lower,"upper":upper}
		var lo: Array = engine.rounded_bound(lower)
		var hi: Array = engine.rounded_bound(upper)
		work_units += 1
		if lo == hi:
			outcome = lo
			phase = "complete"
			return {"state":"complete","price":outcome}
		precision_index += 1
		phase = "begin"
		return {"state":"pending"}
	phase = "error"
	return {"state":"error","reason":"unknown_phase"}
