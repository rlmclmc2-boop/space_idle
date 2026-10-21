extends "res://max_chunk_probe.gd"

# Different finite-domain algorithm: convert the exact IEEE-754 quote bits
# directly into radix-10000 limbs. The old S11 reference multiplies decimal
# strings by powers of two for every quote. One precomputed 2^shift limb table
# serves all levels; its construction is included in the query clock.
var powers_of_two: Array[PackedInt32Array] = []

func build_powers() -> void:
	powers_of_two.clear()
	var first := PackedInt32Array([1])
	powers_of_two.append(first)
	for exponent in 1024:
		var previous: PackedInt32Array = powers_of_two[-1]
		var next := PackedInt32Array()
		var carry := 0
		for digit in previous:
			var value := 2 * digit + carry
			next.append(value % 10000)
			carry = value / 10000
		if carry != 0:
			next.append(carry)
		powers_of_two.append(next)

func from_exact_float(value: float) -> CurrencyValue:
	if value <= 0.0:
		return CurrencyValue.new(PackedInt64Array(), PackedInt32Array())
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var bits: int = bytes.decode_u64(0)
	var exponent: int = (bits >> 52) & 2047
	var mantissa: int = bits & 4503599627370495
	var shift: int = -1074 if exponent == 0 else exponent - 1023 - 52
	if exponent != 0:
		mantissa += 4503599627370496
	if shift < 0:
		return currency_from_integer(mantissa >> mini(-shift, 63))
	var mantissa_limbs := PackedInt32Array()
	while mantissa > 0:
		mantissa_limbs.append(mantissa % 10000)
		mantissa /= 10000
	var power: PackedInt32Array = powers_of_two[shift]
	var values := PackedInt64Array()
	values.resize(power.size() + mantissa_limbs.size() + 1)
	for i in power.size():
		for j in mantissa_limbs.size():
			values[i+j] += int(power[i]) * int(mantissa_limbs[j])
	var positions := PackedInt64Array()
	var digits := PackedInt32Array()
	var carry := 0
	for position in values.size():
		var raw: int = values[position] + carry
		var unsigned_digit: int = raw % 10000
		carry = raw / 10000
		if unsigned_digit >= 5000:
			unsigned_digit -= 10000
			carry += 1
		if unsigned_digit != 0:
			positions.append(position)
			digits.append(unsigned_digit)
	while carry != 0:
		var unsigned_digit: int = carry % 10000
		carry /= 10000
		if unsigned_digit >= 5000:
			unsigned_digit -= 10000
			carry += 1
		if unsigned_digit != 0:
			positions.append(values.size())
			digits.append(unsigned_digit)
	return CurrencyValue.new(positions, digits)

func fast_quote(level: int) -> CurrencyValue:
	var ordinary := 50.0 * pow(1.0 + 0.2, level - 1)
	if is_finite(ordinary):
		if ordinary < 100.0:
			return currency_from_integer(int(ceilf(floorf(ordinary / 10.0) * 10.0 + 5.0)))
		var step := pow(10.0, floorf(log(ordinary) / log(10.0) + 1e-12) - 1.0)
		var snapped := ceilf(floorf(ordinary / step + 0.5) * step)
		return from_exact_float(snapped)
	var exact = Price.new().quote(50.0, 0.2, level)
	return currency_from_integer(exact) if exact != null else null

func _initialize() -> void:
	var profile = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-3873-GODOT.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-3873-GODOT.manifest.json"))
	var wallet = decode(profile.resources["1"])
	if wallet == null:
		printerr("invalid wallet")
		quit(2)
		return
	var level: int = int(profile.laser_level)
	var material_wallet: int = int(profile.hyperspace.materials.degenerate_matter)
	var windows := 0
	var fallback_levels := 0
	var quote_us := 0
	var ledger_us := 0
	var max_window_us := 0
	var first_unaffordable: CurrencyValue = null
	var started := Time.get_ticks_usec()
	build_powers()
	var setup_us := Time.get_ticks_usec() - started
	while level < 4000:
		var window_started := Time.get_ticks_usec()
		var prices: Array[CurrencyValue] = []
		var summed := CurrencyValue.new(PackedInt64Array(), PackedInt32Array())
		var material_due := 0
		for offset in WINDOW:
			var target := level + offset + 1
			var t := Time.get_ticks_usec()
			var cost: CurrencyValue = fast_quote(target)
			quote_us += Time.get_ticks_usec() - t
			if cost == null:
				printerr("quote failed at ", target)
				quit(2)
				return
			t = Time.get_ticks_usec()
			summed = add(summed, cost)
			ledger_us += Time.get_ticks_usec() - t
			prices.append(cost)
			material_due += material(target)
		var t := Time.get_ticks_usec()
		if compare(wallet, summed) >= 0 and material_wallet >= material_due:
			wallet = subtract(wallet, summed)
			material_wallet -= material_due
			level += WINDOW
		else:
			for cost in prices:
				var target := level + 1
				fallback_levels += 1
				if compare(wallet, cost) < 0 or material_wallet < material(target):
					first_unaffordable = cost
					break
				wallet = subtract(wallet, cost)
				material_wallet -= material(target)
				level = target
		ledger_us += Time.get_ticks_usec() - t
		windows += 1
		max_window_us = maxi(max_window_us, Time.get_ticks_usec() - window_started)
		if first_unaffordable != null:
			break
	var total_us := Time.get_ticks_usec() - started
	var remaining_matches := compare(wallet, currency_from_integer(I.make(str(expected.remaining_after_expected_purchases)))) == 0
	var stop_matches := first_unaffordable != null and compare(first_unaffordable, currency_from_integer(I.make(str(expected.first_unaffordable_price)))) == 0
	print(JSON.stringify({"kind":"exploratory_max_binary","window":WINDOW,"level":level,"count":level-int(profile.laser_level),"windows":windows,"fallback_levels":fallback_levels,"setup_us":setup_us,"quote_us":quote_us,"ledger_us":ledger_us,"max_window_us":max_window_us,"total_us":total_us,"remaining_matches":remaining_matches,"stop_matches":stop_matches,"remaining_material":material_wallet,"remaining_blocks":wallet.positions.size()}))
	quit(0 if level == 3873 and remaining_matches and stop_matches else 1)
