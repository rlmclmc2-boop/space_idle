extends "res://max_binary_probe.gd"

# Audit-only rolling outward interval for overflow-domain two-significant-digit
# prices. Every level is visited; no answer or saved prefix is loaded. This
# measures whether replacing repeated exponentiation with a rolling interval
# can make the 50,000-level quote stream feasible.
func _initialize() -> void:
	var engine = Price.new()
	var factor: Array = I.decimal_factor(1.0 + 0.2)
	var lower_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 12, false)
	var upper_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 12, true)
	var lower: Array = [50, 0]
	var upper: Array = [50, 0]
	var first_overflow := 0
	var ambiguous := 0
	var checked := 0
	var mismatches: Array = []
	var sampled: Array = []
	var started := Time.get_ticks_usec()
	for target in range(2, 50002):
		lower = engine.multiply_bound(lower, lower_factor, 12, false)
		upper = engine.multiply_bound(upper, upper_factor, 12, true)
		var ordinary := 50.0 * pow(1.0 + 0.2, target - 1)
		if is_finite(ordinary):
			continue
		if first_overflow == 0:
			first_overflow = target
		var lo: Array = engine.rounded_bound(lower)
		var hi: Array = engine.rounded_bound(upper)
		if lo != hi:
			ambiguous += 1
		if target in [first_overflow, 4001, 10000, 50000, 50001]:
			var reference = engine.quote(50.0, 0.2, target)
			var candidate = I.make(str(lo[0]) + "0".repeat(int(lo[1])))
			var okay: bool = lo == hi and I.compare(candidate, reference) == 0
			sampled.append({"level":target,"same_bound":lo==hi,"match":okay,"power":lo[1]})
			checked += 1
			if not okay:
				mismatches.append(target)
	print(JSON.stringify({"kind":"exploratory_rolling_price","levels":50000,"first_overflow":first_overflow,"ambiguous":ambiguous,"checked":checked,"sampled":sampled,"mismatches":mismatches,"elapsed_us":Time.get_ticks_usec()-started}))
	quit(0 if mismatches.is_empty() else 1)
