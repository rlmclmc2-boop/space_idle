extends "res://bench_sparse.gd"

# A deliberately direct resumable query experiment. It consumes the actual
# generated candidate wallet and compares/debits with typed sparse values.
# Its sequential cost work is measured, not moved into unmeasured setup.
const Price = preload("res://price_probe.gd")
const I = preload("res://reference_integer.gd")

func currency_from_integer(value: Variant) -> CurrencyValue:
	var s: String = I.digits(value)
	if s == "0":
		return CurrencyValue.new(PackedInt64Array(), PackedInt32Array())
	var p := PackedInt64Array()
	var d := PackedInt32Array()
	var group := 0
	var carry := 0
	for end in range(s.length(), 0, -4):
		var start := maxi(0, end - 4)
		var raw := int(s.substr(start, end - start)) + carry
		carry = 1 if raw >= 5000 else 0
		var digit := raw - carry * 10000
		if digit != 0:
			p.append(group)
			d.append(digit)
		group += 1
	if carry:
		p.append(group)
		d.append(carry)
	return CurrencyValue.new(p, d)

func material(level: int) -> int:
	return 10 * (level / 20) if level % 20 == 0 else 0

func _initialize() -> void:
	var name := "MAX-3873-GODOT"
	var raw := FileAccess.get_file_as_string("res://generated_wallets/" + name + ".json")
	var profile = JSON.parse_string(raw)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/MAX-3873-GODOT.manifest.json"))
	var diagnostic_prices = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/godot_prices_3873.json"))
	if not profile is Dictionary:
		printerr("missing generated wallet")
		quit(2)
		return
	var wallet = decode(profile.resources["1"])
	if wallet == null:
		printerr("invalid generated wallet")
		quit(2)
		return
	var price_engine = Price.new()
	var level := int(profile.laser_level)
	var material_wallet := int(profile.hyperspace.materials.degenerate_matter)
	var count := 0
	var slices := 0
	var max_slice_us := 0
	var max_level_us := 0
	var first_slices: Array = []
	var start_us := Time.get_ticks_usec()
	var first_unaffordable := ""
	var price_mismatch_count := 0
	var first_price_mismatches: Array = []
	while level < 4000:
		var slice_start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - slice_start < 4000:
			var level_start := Time.get_ticks_usec()
			var next := level + 1
			var price = price_engine.quote(50.0, 0.2, next)
			if price == null:
				printerr("price failed at ", next)
				quit(2)
				return
			if I.digits(price) != str(diagnostic_prices[next - 2]):
				price_mismatch_count += 1
				if first_price_mismatches.size() < 5:
					first_price_mismatches.append({"level":next,"godot":I.digits(price).substr(0,25),"python":str(diagnostic_prices[next-2]).substr(0,25)})
			var cost = currency_from_integer(price)
			if compare(wallet, cost) < 0 or material_wallet < material(next):
				first_unaffordable = I.digits(price)
				break
			wallet = subtract(wallet, cost)
			material_wallet -= material(next)
			level = next
			count += 1
			max_level_us = maxi(max_level_us, Time.get_ticks_usec() - level_start)
		slices += 1
		var slice_us := Time.get_ticks_usec() - slice_start
		max_slice_us = maxi(max_slice_us, slice_us)
		if first_slices.size() < 10:
			first_slices.append({"n":slices,"elapsed_us":slice_us,"level":level})
		if not first_unaffordable.is_empty():
			break
	var total_us := Time.get_ticks_usec() - start_us
	var remaining_matches := compare(wallet, currency_from_integer(I.make(str(expected.remaining_after_expected_purchases)))) == 0
	var stop_matches: bool = first_unaffordable == str(expected.first_unaffordable_price)
	print(JSON.stringify({"kind":"exploratory_max","id":name,"count":count,"level":level,"first_unaffordable":first_unaffordable.substr(0,20)+"..."+str(first_unaffordable.length())+" digits","stop_matches_generator":stop_matches,"remaining_matches_generator":remaining_matches,"remaining_storage":encode(wallet),"price_mismatch_count":price_mismatch_count,"first_price_mismatches":first_price_mismatches,"slices":slices,"max_slice_us":max_slice_us,"max_level_us":max_level_us,"total_us":total_us,"remaining_material":material_wallet,"remaining_blocks":wallet.positions.size(),"first_slices":first_slices}))
	quit(0 if level == 3873 and count == 3872 and remaining_matches and stop_matches else 1)
