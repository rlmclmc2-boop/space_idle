extends SceneTree
const Q := preload("res://test/audit_s11_equipment_quote.gd")
const I := preload("res://scripts/reactor_integer.gd")
const DB := preload("res://scripts/database.gd")
const NumberFormat := preload("res://scripts/number_format.gd")

var checks := 0
var failures := 0
var encoded_finite_comparisons := 0

func check(name: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	if actual == expected:
		print("PASS ", name)
	else:
		failures += 1
		printerr("FAIL ", name, " actual=", actual, " expected=", expected)

func digits(value: Variant) -> String:
	return I.digits(value)

func _initialize() -> void:
	var db := DB.new()
	var evolution: Dictionary = db.data.equipment_evolution
	var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/audit_s11_quote_oracle.json"))
	for key in ["laser", "armour"]:
		var row: Dictionary = db.equipment[key][0]
		for level in [1, 2, 3, 4, 5, 6, 10, 20, 50, 100, 500, 1000, 3800, 3850, 3865, 3870, 3873]:
			var got := Q.quote_row(row, level, evolution)
			check(key + " quote ok " + str(level), got.ok, true)
			if not got.ok:
				continue
			var legacy = db.equipment_cost(key, level).get("1", 0)
			if is_finite(float(legacy)):
				if got.costs["1"] is Dictionary:
					encoded_finite_comparisons += 1
				check(key + " legacy " + str(level), digits(got.costs["1"]), digits(I.float_floor(float(legacy))))
			if cases.has(key + ":" + str(level)):
				check(key + " oracle " + str(level), digits(got.costs["1"]), str(cases[key + ":" + str(level)]))
		var high := Q.quote_row(row, 3873, evolution)
		check(key + " 3873 finite", high.ok and I.valid(high.costs["1"]), true)
		check(key + " insufficient 1e300", Q.affordable({"1": {"m": 1.0, "e": 300.0}}, high.costs), false)
		check(key + " sufficient 1e400", Q.affordable({"1": {"m": 1.0, "e": 400.0}, evolution.material_id: 1000000}, high.costs), true)
		var batch := Q.batch(row, 3900, 10, evolution)
		check(key + " batch ok", batch.ok, true)
		check(key + " batch oracle", digits(batch.costs["1"]), str(cases[key + ":batch:3900:10"]))
	for sample in [99.9, 100.0, 149.0, 150.0]:
		var row := {"level": 1, "res_1": 1, "cost_1": sample, "cost_multi_1": 0.0}
		var quoted := Q.quote_row(row, 2, evolution)
		check("boundary " + str(sample), digits(quoted.costs["1"]), str({99.9: 95, 100.0: 100, 149.0: 150, 150.0: 150}[sample]))
	var first := Q.quote_row({"level": 1, "res_1": 1, "cost_1": 50, "cost_multi_1": 0.2}, 1, evolution)
	check("level one unrounded", digits(first.costs["1"]), "50")
	var no_multi := Q.quote_row({"level": 1, "res_1": 1, "cost_1": 50}, 2, evolution)
	check("missing multiplier unrounded", digits(no_multi.costs["1"]), "50")
	var crossing := Q.batch({"level": 1, "res_1": 1, "cost_1": 4.0e307, "cost_multi_1": 0.0}, 1, 10, evolution)
	check("finite items overflow batch", crossing.ok and I.digits(crossing.costs["1"]).length() == 309, true)
	var half := Q.quote_row({"level": 1, "res_1": 1, "cost_1": 1.5e308, "cost_multi_1": 0.5}, 2, evolution)
	check("overflow half-step", digits(half.costs["1"]), "23" + "0".repeat(307))
	var carry := Q.quote_row({"level": 1, "res_1": 1, "cost_1": 9.95e307, "cost_multi_1": 9.0}, 2, evolution)
	check("overflow decade carry", digits(carry.costs["1"]), "1" + "0".repeat(309))
	var material_row := {"level": 1, "res_1": 1, "cost_1": 50, "cost_multi_1": 0.2}
	var material_batch := Q.batch(material_row, 19, 2, evolution)
	check("material crossing", digits(material_batch.costs[evolution.material_id]), "10")
	check("finite float wallet", Q.affordable({"1": 1.0e100, evolution.material_id: 1000}, Q.quote_row(material_row, 100, evolution).costs), true)
	check("fractional wallet sufficient", Q.affordable({"1": 10.5}, {"1": 10}), true)
	check("fractional wallet insufficient", Q.affordable({"1": 9.99}, {"1": 10}), false)
	check("fractional wallet below next integer", Q.affordable({"1": 10.5}, {"1": 11}), false)
	check("integral float wallet boundary", Q.affordable({"1": 10.0}, {"1": 10}), true)
	check("invalid string mantissa", Q.affordable({"1": {"m": "1", "e": "400"}}, {"1": 10}), false)
	check("invalid string exponent", Q.affordable({"1": {"m": 1, "e": "400"}}, {"1": 10}), false)
	check("valid numeric legacy mantissa", Q.affordable({"1": {"m": 1, "e": 400}}, {"1": 10}), true)
	check("invalid extra legacy field", Q.affordable({"1": {"m": 1, "e": 400, "x": 1}}, {"1": 10}), false)
	check("encoded finite legacy comparisons", encoded_finite_comparisons >= 8, true)
	print("S11 checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
