extends "res://max_probe.gd"

# A different audit-only MAX search: sum a bounded window of original per-level
# prices into a mutable radix accumulator, normalize once, then compare/debit
# the whole window. If it does not fit, replay that window level by level.
# It never reads the answer from the manifest. Quote generation is included.
const WINDOW: int = 32

func append_price(pending: Dictionary, cost: Variant) -> void:
	var s: String = I.digits(cost)
	var position: int = 0
	for end in range(s.length(), 0, -4):
		var start := maxi(0, end - 4)
		pending[position] = int(pending.get(position, 0)) + int(s.substr(start, end - start))
		position += 1

func normalize_pending(pending: Dictionary) -> CurrencyValue:
	var keys: Array = pending.keys()
	keys.sort()
	var positions := PackedInt64Array()
	var digits := PackedInt32Array()
	var carry := 0
	var carry_position := 0
	for key in keys:
		var position := int(key)
		if carry != 0:
			if carry_position < position:
				positions.append(carry_position)
				digits.append(carry)
				carry = 0
			elif carry_position == position:
				pending[position] = int(pending[position]) + carry
				carry = 0
		var value := int(pending[position])
		var next_carry := int(floori(float(value + 5000) / 10000.0))
		value -= next_carry * 10000
		if value != 0:
			positions.append(position)
			digits.append(value)
		if next_carry != 0:
			carry = next_carry
			carry_position = position + 1
	if carry != 0:
		positions.append(carry_position)
		digits.append(carry)
	return CurrencyValue.new(positions, digits)

func _initialize() -> void:
	var profile = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-3873-GODOT.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-3873-GODOT.manifest.json"))
	var wallet = decode(profile.resources["1"])
	if wallet == null:
		printerr("invalid wallet")
		quit(2)
		return
	var price_engine = Price.new()
	var level: int = int(profile.laser_level)
	var material_wallet: int = int(profile.hyperspace.materials.degenerate_matter)
	var windows := 0
	var fallback_levels := 0
	var quote_us := 0
	var radix_us := 0
	var ledger_us := 0
	var max_window_us := 0
	var first_unaffordable := ""
	var started := Time.get_ticks_usec()
	while level < 4000:
		var window_started := Time.get_ticks_usec()
		var pending: Dictionary = {}
		var prices: Array = []
		var material_due := 0
		for offset in WINDOW:
			var target := level + offset + 1
			var t := Time.get_ticks_usec()
			var cost = price_engine.quote(50.0, 0.2, target)
			quote_us += Time.get_ticks_usec() - t
			if cost == null:
				printerr("quote failed at ", target)
				quit(2)
				return
			t = Time.get_ticks_usec()
			append_price(pending, cost)
			radix_us += Time.get_ticks_usec() - t
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
				var single: CurrencyValue = currency_from_integer(cost)
				fallback_levels += 1
				if compare(wallet, single) < 0 or material_wallet < material(target):
					first_unaffordable = I.digits(cost)
					break
				wallet = subtract(wallet, single)
				material_wallet -= material(target)
				level = target
		ledger_us += Time.get_ticks_usec() - t
		windows += 1
		max_window_us = maxi(max_window_us, Time.get_ticks_usec() - window_started)
		if not first_unaffordable.is_empty():
			break
	var total_us := Time.get_ticks_usec() - started
	var remaining_matches := compare(wallet, currency_from_integer(I.make(str(expected.remaining_after_expected_purchases)))) == 0
	var stop_matches: bool = first_unaffordable == str(expected.first_unaffordable_price)
	print(JSON.stringify({"kind":"exploratory_max_chunk","window":WINDOW,"level":level,"count":level-int(profile.laser_level),"windows":windows,"fallback_levels":fallback_levels,"quote_us":quote_us,"radix_us":radix_us,"ledger_us":ledger_us,"max_window_us":max_window_us,"total_us":total_us,"remaining_matches":remaining_matches,"stop_matches":stop_matches,"remaining_material":material_wallet,"remaining_blocks":wallet.positions.size()}))
	quit(0 if level == 3873 and remaining_matches and stop_matches else 1)
