extends "res://max_binary_probe.gd"

# Independent Godot finite-price export was made through the original S11
# exact float payload path before this candidate existed. Compare every item,
# not just the terminal MAX wallet and the first unaffordable quote.
func _initialize() -> void:
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/godot_prices_3873.json"))
	build_powers()
	var mismatches := 0
	var examples: Array = []
	var begun := Time.get_ticks_usec()
	for index in reference.size():
		var target := index + 2
		var fast: CurrencyValue = fast_quote(target)
		var oracle: CurrencyValue = currency_from_integer(I.make(str(reference[index])))
		if compare(fast, oracle) != 0:
			mismatches += 1
			if examples.size() < 5:
				examples.append(target)
	print(JSON.stringify({"kind":"exploratory_binary_price_parity","count":reference.size(),"mismatches":mismatches,"examples":examples,"elapsed_us":Time.get_ticks_usec()-begun}))
	quit(0 if mismatches == 0 and reference.size() == 3873 else 1)
