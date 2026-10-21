extends "res://bench_sparse.gd"

# Full entry cost, including JSON parse, strict decode of both operands,
# operation, and result serialization. A typed reuse measurement is separated
# and cannot be substituted for this public boundary.
func _initialize() -> void:
	var source: String = JSON.stringify(candidate(10000, false))
	var start := Time.get_ticks_usec()
	var left = decode(JSON.parse_string(source))
	var right = decode(JSON.parse_string(source))
	var loaded_us := Time.get_ticks_usec() - start
	if left == null or right == null:
		quit(1)
		return
	start = Time.get_ticks_usec()
	var comparison: int = compare(left, right)
	var compare_typed_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var sum_value = add(left, right)
	var add_typed_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var sum_json: String = JSON.stringify(encode(sum_value))
	var encoded_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var difference = subtract(sum_value, left)
	var subtract_typed_us := Time.get_ticks_usec() - start
	var correct: bool = comparison == 0 and compare(difference, right) == 0 and sum_json.length() > 0
	print(JSON.stringify({"kind":"exploratory_full_public_ledger_cost","correct":correct,"blocks":10000,"source_bytes":source.to_utf8_buffer().size(),"loaded_two_json_values_us":loaded_us,"compare_typed_us":compare_typed_us,"add_typed_us":add_typed_us,"encode_json_us":encoded_us,"subtract_typed_us":subtract_typed_us,"public_compare_path_us":loaded_us+compare_typed_us,"public_add_path_us":loaded_us+add_typed_us+encoded_us,"typed_reuse_add_us":add_typed_us,"warning":"sequential components; public path includes two parsed and validated operands"}))
	quit(0 if correct else 1)
