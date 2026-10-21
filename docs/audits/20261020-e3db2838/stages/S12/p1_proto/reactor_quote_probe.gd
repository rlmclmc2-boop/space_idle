extends SceneTree

# Exploratory quotation readback for the REACTOR-140 preregistration. It never
# debits a game wallet. Main's finite branch is ceilf(10*pow(1.35,level-1)).
const I = preload("res://reference_integer.gd")

func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return "%016x" % bytes.decode_u64(0)

func _initialize() -> void:
	var prices: Array = []
	var float_total := 0.0
	var exact_total: Variant = 0
	for level in range(140, 150):
		var raw := 10.0 * pow(1.35, level - 1)
		var quoted := ceilf(raw)
		var exact = I.float_floor(quoted)
		prices.append({"level":level,"raw_bits":bits(raw),"quote_bits":bits(quoted),"exact_integer":I.digits(exact)})
		float_total += quoted
		exact_total = I.add(exact_total, exact)
	print(JSON.stringify({"kind":"exploratory_reactor_quote","start_level":140,"final_level":150,"uranium_id":"2","base":10,"growth":1.35,"quotes":prices,"batch_float_sum_bits":bits(float_total),"batch_float_sum_exact_integer":I.digits(I.float_floor(float_total)),"exact_sum_of_float_quote_integers":I.digits(exact_total)}))
	quit()
