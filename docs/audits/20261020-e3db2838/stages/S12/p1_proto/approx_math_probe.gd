extends "res://max_probe.gd"

const Bound = preload("res://approx_bounds.gd")

func _initialize() -> void:
	var engine = Bound.new()
	var results: Array = []
	var first_overflow := -1
	for target in range(258, 4001):
		if not is_finite(50.0 * pow(1.0 + 0.2, target - 1)):
			first_overflow = target
			break
	for count in [1,2,10,257,50000,1000000000]:
		var started := Time.get_ticks_usec()
		var interval: Array = engine.rounded_fee_envelope(257, count)
		var low = decode(engine.encoded_integer(interval[0], false))
		var high = decode(engine.encoded_integer(interval[1], true))
		var low_28 = currency_from_integer(24)
		var high_25 = currency_from_integer(0)
		for i in 28:
			low_28 = add(low_28, low)
		for i in 25:
			high_25 = add(high_25, high)
		results.append({"count":count,"lower":[I.digits(interval[0][0]),interval[0][1]],"upper":[I.digits(interval[1][0]),interval[1][1]],"ordered":compare(low,high)<=0,"fee_ratio_ok":compare(high_25,low_28)<=0,"low_blocks":low.positions.size(),"high_blocks":high.positions.size(),"elapsed_us":Time.get_ticks_usec()-started})
	print(JSON.stringify({"kind":"exploratory_approx_math","growth":[I.digits(engine.growth[0]),engine.growth[1]],"first_overflow_target":first_overflow,"results":results}))
	quit()
