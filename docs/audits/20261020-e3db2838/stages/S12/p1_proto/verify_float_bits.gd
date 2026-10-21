extends "res://max_binary_probe.gd"

# Compare direct limb conversion with the frozen S11 bit-exact float_floor on
# deterministic binary64 payloads, including subnormal and large exponents.
func _initialize() -> void:
	build_powers()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var cases := 0
	var mismatches := 0
	var examples: Array = []
	for exponent in [0, 1, 50, 1023, 1075, 1500, 2046]:
		for index in 20:
			var mantissa: int = rng.randi_range(0, 4503599627370495)
			var bits: int = (int(exponent) << 52) | mantissa
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_u64(0, bits)
			var value := bytes.decode_double(0)
			var candidate: CurrencyValue = from_exact_float(value)
			var oracle: CurrencyValue = currency_from_integer(I.float_floor(value))
			cases += 1
			if compare(candidate, oracle) != 0:
				mismatches += 1
				if examples.size() < 5:
					examples.append({"exponent":exponent,"index":index,"bits":bits})
	print(JSON.stringify({"kind":"exploratory_float_bits","cases":cases,"mismatches":mismatches,"examples":examples}))
	quit(0 if cases == 140 and mismatches == 0 else 1)
