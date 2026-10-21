extends "res://max_binary_probe.gd"

# Exploratory full MAX-50000 on an actual independent exact-integer-reduced
# wallet. The quote stream is generated inside the query, not loaded from the
# compact export. Rolling outward bounds handle overflow-domain prices.
func from_two_digit(leading: int, power: int) -> CurrencyValue:
	var position := power / 4
	var remainder := power % 4
	var value: int = leading * int([1, 10, 100, 1000][remainder])
	var positions := PackedInt64Array()
	var digits := PackedInt32Array()
	var carry := 0
	while value > 0 or carry > 0:
		var raw: int = value % 10000 + carry
		value /= 10000
		carry = 1 if raw >= 5000 else 0
		var digit := raw - carry * 10000
		if digit != 0:
			positions.append(position)
			digits.append(digit)
		position += 1
	return CurrencyValue.new(positions, digits)

func _initialize() -> void:
	var started := Time.get_ticks_usec()
	var profile = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-50000-GODOT-EXPLORATORY.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-50000-GODOT-EXPLORATORY.manifest.json"))
	var wallet = decode(profile.resources["1"])
	if wallet == null:
		printerr("invalid exploratory wallet")
		quit(2)
		return
	var engine = Price.new()
	var factor: Array = I.decimal_factor(1.0 + 0.2)
	var lower_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 10, false)
	var upper_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 10, true)
	var lower: Array = [50, 0]
	var upper: Array = [50, 0]
	var overflow_domain := false
	var level: int = int(profile.laser_level)
	var material_wallet: int = int(profile.hyperspace.materials.degenerate_matter)
	var windows := 0
	var fallback_levels := 0
	var ambiguous := 0
	var ambiguity_levels: Array = []
	var quote_us := 0
	var ledger_us := 0
	var max_window_us := 0
	var first_unaffordable: CurrencyValue = null
	build_powers()
	var setup_us := Time.get_ticks_usec() - started
	while level < 50100:
		var window_started := Time.get_ticks_usec()
		var prices: Array[CurrencyValue] = []
		var pending: Dictionary = {}
		var material_due := 0
		for offset in WINDOW:
			var target := level + offset + 1
			var t := Time.get_ticks_usec()
			lower = engine.multiply_bound(lower, lower_factor, 10, false)
			upper = engine.multiply_bound(upper, upper_factor, 10, true)
			var ordinary := INF if overflow_domain else 50.0 * pow(1.0 + 0.2, target - 1)
			var cost: CurrencyValue
			if is_finite(ordinary):
				cost = fast_quote(target)
			else:
				overflow_domain = true
				var lo: Array = engine.rounded_bound(lower)
				var hi: Array = engine.rounded_bound(upper)
				if lo == hi:
					cost = from_two_digit(int(lo[0]), int(lo[1]))
				else:
					ambiguous += 1
					if ambiguity_levels.size() < 20:
						ambiguity_levels.append({"level":target,"lower":lo,"upper":hi})
					var fallback = engine.quote(50.0, 0.2, target)
					if fallback != null:
						cost = currency_from_integer(fallback)
			quote_us += Time.get_ticks_usec() - t
			if cost == null:
				printerr("quote failed at ", target)
				quit(2)
				return
			t = Time.get_ticks_usec()
			for index in cost.positions.size():
				var position: int = cost.positions[index]
				pending[position] = int(pending.get(position, 0)) + int(cost.digits[index])
			ledger_us += Time.get_ticks_usec() - t
			prices.append(cost)
			material_due += material(target)
		var t := Time.get_ticks_usec()
		var summed: CurrencyValue = normalize_pending(pending)
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
	print(JSON.stringify({"kind":"exploratory_max_stream","window":WINDOW,"level":level,"count":level-int(profile.laser_level),"windows":windows,"fallback_levels":fallback_levels,"ambiguous":ambiguous,"ambiguity_levels":ambiguity_levels,"setup_us":setup_us,"quote_us":quote_us,"ledger_us":ledger_us,"max_window_us":max_window_us,"total_us":total_us,"remaining_matches":remaining_matches,"stop_matches":stop_matches,"remaining_material":material_wallet,"remaining_blocks":wallet.positions.size()}))
	quit(0 if level == 50000 and remaining_matches and stop_matches else 1)
