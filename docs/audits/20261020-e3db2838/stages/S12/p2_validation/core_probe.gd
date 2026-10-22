extends SceneTree
const L = preload("res://scripts/currency_ledger.gd")
const H = preload("res://scripts/currency_host.gd")
const P = preload("res://scripts/equipment_price.gd")
const S = preload("res://scripts/currency_storage.gd")
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		printerr("P2_FAIL ", label)
		quit(1)
		assert(false, label)
func value(raw: Variant) -> L.Value:
	var decoded: L.Outcome = L.decode(raw)
	check(decoded.status == "ok", "decode")
	return decoded.value
func _initialize() -> void:
	var zero: L.Value = value(0)
	var one: L.Value = value(1)
	var far: L.Value = value({"m":1.0,"e":1e308})
	var credited: L.Outcome = L.add(far, one)
	check(credited.status == "ok", "far credit")
	var difference: L.Outcome = L.subtract(credited.value, far)
	check(L.compare(difference.value, one).order == 0, "far low unit survives")
	var fractional: L.Value = value(0.5)
	check(L.finite_research_balance(fractional, 1.0).amount == 0.5, "fraction preserved")
	var end: L.Value = value({"currency_version":1,"blocks":[{"p":"76","d":-5000},{"p":"77","d":2}]})
	check(absf(L.finite_research_balance(end, 1.6e308).amount/1.5e308-1.0)<=0.00001, "finite cancellation projection")
	var minimum: L.Value = value(5e-324)
	check(L.finite_research_balance(minimum, 1.0).amount == 5e-324, "subnormal preserved")
	check(L.subtract(zero, one).status == "insufficient", "no clamp")
	for raw in [{"v":2,"base":{"m":1,"e":400},"sign":1,"delta":1,"places":0},{"v":3,"blocks":[]},{"v":4,"blocks":[]},{"v":1,"i":"1"},{"m":1,"e":3,"extra":0},{"currency_version":1,"blocks":[{"p":"-0","d":1}]},{"currency_version":1,"blocks":[{"p":"0","d":5000}]}]:
		check(L.decode(raw).status != "ok", "reject non-domain")
	var encoded: Dictionary = L.encode(credited.value)
	var restored: L.Value = value(JSON.parse_string(JSON.stringify(encoded)))
	check(L.compare(restored, credited.value).order == 0, "CW1 JSON roundtrip")
	encoded.main.clear()
	check(L.compare(credited.value, far).order > 0, "encoded alias isolated")
	var profile := {"resources":{"1":10.0,"2":0.5},"loadout":{"weapons":[{"level":1}]}}
	var host := H.new()
	host.bind(profile)
	var dependencies := {"level":1}
	var quote := {"1":3,"2":0.5}
	var plan: H.Plan = host.prepare(profile, quote, dependencies)
	quote["1"] = 9
	dependencies.level = 7
	check(host.commit(plan, profile, {"level":1}).status == "committed", "quote input isolation")
	check(L.compare(value(profile.resources["1"]), value(7)).order == 0, "exact debit")
	check(host.commit(plan, profile, {"level":1}).status == "invalid_plan", "no duplicate debit")
	var pending: H.Plan = host.prepare(profile, {"1":1}, {})
	var equal_replacement: Dictionary = profile.duplicate(true)
	host.bind(equal_replacement)
	check(host.commit(pending, equal_replacement, {}).status == "stale", "equal owner replacement")
	var stale: H.Plan = host.prepare(equal_replacement, {"1":1}, {})
	equal_replacement.resources["1"] = 2
	check(host.commit(stale, equal_replacement, {}).status == "stale", "inplace mutation")
	var failed: H.Plan = host.prepare(equal_replacement, {"1":3}, {})
	check(failed.status == "insufficient" and equal_replacement.resources["1"] == 2, "preflight no write")
	var prices := P.new()
	var low: L.Outcome = prices.quote(1e-300*1e-8, 0.195, 4001)
	check(low.status == "ok" and L.compare(low.value, value(25)).order == 0, "low intermediate overflow price")
	var tiny: L.Outcome = prices.quote(1e-300*1e-8, exp(710.0/4000.0)-1.0, 4001)
	check(tiny.status == "ok" and L.compare(tiny.value, value(5)).order == 0, "tiny intermediate overflow price")
	var ordinary: L.Outcome = prices.quote(50.0, 0.2, 2)
	check(ordinary.status == "ok" and L.compare(ordinary.value, value(65)).order == 0, "ordinary rounding")
	var huge: L.Outcome = prices.quote(50.0, 0.2, 1000000000)
	check(huge.status == "ok" and L.encode(huge.value).size()==3 and L.encode(huge.value).currency_version==2, "huge price stays sparse")
	var disk: S.Outcome = S.parse_source('{"resources":{"1":9007199254740993},"hyperspace":{"materials":{"degenerate_matter":9007199254740993}},"loadout":{"weapons":[{"level":9007199254740993}],"defence":[]}}')
	check(disk.status == "ok" and disk.data.resources["1"] is Dictionary and disk.data.resources["1"].i == "9007199254740993", "resource exact token")
	check(disk.data.hyperspace.materials.degenerate_matter == 9007199254740993 and disk.data.loadout.weapons[0].level == 9007199254740993, "material and level exact token")
	check(S.parse_source('{"hyperspace":{"materials":{"x":9223372036854775808}}}').status == "integer_transport", "material transport refuses overflow")
	check(S.parse_source('{"resources":{"1":1,"1":2}}').status == "duplicate_boundary", "duplicate wallet key refused")
	check(S.parse_source('{"resources":{"1":0.5},"note":"resources\\\"1"}').data.resources["1"] == 0.5, "fraction and escaped string")


	for raw in [0.5,1234567,{"m":1.23456789,"e":100.0},{"m":9.999999,"e":300.0},{"m":3.0,"e":-318.0},{"currency_version":1,"blocks":[{"p":"-1","d":-5000},{"p":"0","d":1}]}]:
		var expected:float=0.5 if raw is Dictionary and raw.has("currency_version") else float(raw.m)*pow(10.0,float(raw.e)) if raw is Dictionary else float(raw)
		var projected=L.analysis_value(raw)
		check(projected.status=="ok" and absf((projected.amount-expected)/expected)<=0.00001,"read-only projection 0.001 percent relative tolerance")
	check(L.analysis_value({"m":1.0,"e":-323.0}).status=="out_of_domain","tiny relative-error projection boundary explicit")
	check(L.analysis_value({"m":1.0,"e":3800.0}).status=="out_of_domain","large projection boundary explicit")
	check(L.analysis_value(0).status=="ok" and L.analysis_value(0).amount==0.0,"projection zero exact")
	check(S.parse_source('{"note":'+"[".repeat(47)+'0'+"]".repeat(47)+'}').status=="ok","JSON depth48 retained")
	check(S.parse_source('{"note":'+"[".repeat(48)+'0'+"]".repeat(48)+'}').status=="depth","JSON depth49 rejected")
	check(S.parse_source('{"resources":{"1":1},"resour\\u0063es":{"1":2}}').status=="duplicate_boundary","escaped duplicate root boundary")
	check(S.parse_source('{"levels":{"laser":1,"laser":2}}').status=="duplicate_boundary","duplicate level boundary")

	var accumulated:L.Value=value(1000000000000)
	for unused in 1000:accumulated=L.add(accumulated,value(1)).value
	check(L.compare(accumulated,value(1000000001000)).order==0,"finite residual accumulates repeated small income")
	for unused in 1000:accumulated=L.subtract(accumulated,value(1)).value
	check(L.compare(accumulated,value(1000000000000)).order==0,"finite residual accumulates repeated small debit")
	check(L.subtract(value(49.999999),value(50)).status=="insufficient","no tolerance admission at payment boundary")
	print("P2_CORE_COMPLETE checks=", checks)
	quit(0)

