extends "res://max_binary_probe.gd"

# Exploratory generator, not a frozen official input. Finite quotes come from
# the frozen price path; overflow quotes use rolling outward rational bounds.
# Compact [leading, power] entries still denote an exact ordinary integer.
func _initialize() -> void:
	var engine = Price.new()
	var factor: Array = I.decimal_factor(1.0 + 0.2)
	var lower_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 12, false)
	var upper_factor: Array = engine.trim_bound(factor[0], -int(factor[1]), 12, true)
	var lower: Array = [50, 0]
	var upper: Array = [50, 0]
	var prices: Array = []
	var finite_count := 0
	var ambiguous := 0
	var full_hash := HashingContext.new()
	full_hash.start(HashingContext.HASH_SHA256)
	for target in range(2, 50002):
		lower = engine.multiply_bound(lower, lower_factor, 12, false)
		upper = engine.multiply_bound(upper, upper_factor, 12, true)
		var ordinary := 50.0 * pow(1.0 + 0.2, target - 1)
		var text_price: String
		if is_finite(ordinary):
			var finite_price = engine.quote(50.0, 0.2, target)
			if finite_price == null:
				printerr("finite quote failed at ", target)
				quit(2)
				return
			text_price = I.digits(finite_price)
			prices.append(text_price)
			finite_count += 1
		else:
			var lo: Array = engine.rounded_bound(lower)
			var hi: Array = engine.rounded_bound(upper)
			if lo != hi:
				ambiguous += 1
				var fallback = engine.quote(50.0, 0.2, target)
				if fallback == null:
					printerr("ambiguous quote failed at ", target)
					quit(2)
					return
				text_price = I.digits(fallback)
				prices.append(text_price)
			else:
				text_price = str(lo[0]) + "0".repeat(int(lo[1]))
				prices.append(lo)
		full_hash.update((text_price + "\n").to_utf8_buffer())
	var path := "res://generated_wallets/godot_prices_50000_compact.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("compact price file open failed")
		quit(2)
		return
	file.store_string(JSON.stringify(prices))
	file.close()
	print(JSON.stringify({"kind":"exploratory_compact_price_export","count":prices.size(),"finite_count":finite_count,"ambiguous":ambiguous,"full_line_stream_sha256":full_hash.finish().hex_encode(),"compact_file":path,"compact_bytes":FileAccess.get_file_as_bytes(path).size()}))
	quit(0 if prices.size() == 50000 else 1)
