extends "res://price_probe.gd"

# Exploratory setup: Godot-produced every-level price bytes. The generator is
# kept outside the timed MAX query; it also checks the original finite branch.
func _initialize() -> void:
	var prices: Array = []
	var finite_count := 0
	var finite_mismatch := 0
	var first_mismatches: Array = []
	for level in range(2, 3875):
		var value = quote(50.0, 0.2, level)
		if value == null:
			printerr("quote failed at ", level)
			quit(2)
			return
		var quoted: String = I.digits(value)
		prices.append(quoted)
		var ordinary: float = 50.0 * pow(1.2, level - 1)
		if is_finite(ordinary):
			finite_count += 1
			var old: float = floorf(ordinary / 10.0) * 10.0 + 5.0 if ordinary < 100.0 else floorf(ordinary / pow(10.0, floorf(log(ordinary) / log(10.0) + 1e-12) - 1.0) + 0.5) * pow(10.0, floorf(log(ordinary) / log(10.0) + 1e-12) - 1.0)
			var expected: String = I.digits(I.float_floor(ceilf(old)))
			if quoted != expected:
				finite_mismatch += 1
				if first_mismatches.size() < 5:
					first_mismatches.append({"level":level,"quote":quoted.substr(0,25),"baseline":expected.substr(0,25)})
	var path := "res://generated_wallets/godot_prices_3873.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("price file open failed")
		quit(2)
		return
	file.store_string(JSON.stringify(prices))
	file.close()
	print(JSON.stringify({"kind":"exploratory_price_export","count":prices.size(),"finite_count":finite_count,"finite_mismatch":finite_mismatch,"first_mismatches":first_mismatches,"file":path,"bytes":FileAccess.get_file_as_bytes(path).size()}))
	quit(0 if finite_mismatch == 0 else 1)
