extends RefCounted
## Resource boundaries only. Rates, effects and work keep ordinary Amount precision.
static func whole(value: Dictionary, api) -> Dictionary:
	var zero: Dictionary = api.apply("zero", [])
	if not zero.ok: return zero
	var checked: Dictionary = api.apply("compare", [value, zero.value])
	if not checked.ok: return checked
	if checked.scalar < 0: return {"ok":false,"reason":"InvalidResourceAmount"}
	return api.apply("ceil", [value])

static func whole_map(values: Dictionary, api) -> Dictionary:
	var result: Dictionary = {}
	for id in values:
		if not id is String or id.is_empty(): return {"ok":false,"reason":"InvalidResourceId"}
		if not values[id] is Dictionary: return {"ok":false,"reason":"InvalidResourceAmount"}
		var value: Dictionary = whole(values[id], api)
		if not value.ok: return value
		result[id] = value.value
	return {"ok":true,"values":result}

static func progress_map(values: Dictionary, api) -> Dictionary:
	var one: Dictionary = api.apply("from_decimal", ["1"])
	if not one.ok: return one
	for id in values:
		if not id is String or id.is_empty(): return {"ok":false,"reason":"InvalidResourceId"}
		var value = values[id]
		if not value is Dictionary: return {"ok":false,"reason":"InvalidResourceProgress"}
		var checked: Dictionary = whole(value, api)
		if not checked.ok: return checked
		var limit: Dictionary = api.apply("compare", [value, one.value])
		if not limit.ok: return limit
		# A mathematically sub-unit remainder can round to exactly one in Amount.
		if limit.scalar > 0: return {"ok":false,"reason":"InvalidResourceProgress"}
	return {"ok":true,"values":values.duplicate(true)}

## Settle cumulative ceil once, preserving already settled fractional service/work.
## The progress is nontransferable production/consumption progress, never a balance.
static func settle(raw: Dictionary, progress: Dictionary, api) -> Dictionary:
	var checked: Dictionary = whole(raw, api)
	if not checked.ok: return checked
	var valid_progress: Dictionary = progress_map({"value":progress},api)
	if not valid_progress.ok: return valid_progress
	var compared: Dictionary = api.apply("compare", [raw, progress])
	if not compared.ok: return compared
	if compared.scalar <= 0:
		var left: Dictionary = api.apply("sub_nonnegative", [progress,raw])
		if not left.ok: return left
		return {"ok":true,"amount":api.apply("zero",[]).value,"progress":left.value}
	var deficit: Dictionary = api.apply("sub_nonnegative",[raw,progress])
	if not deficit.ok: return deficit
	var charged: Dictionary = whole(deficit.value,api)
	if not charged.ok: return charged
	var left: Dictionary = api.apply("sub_nonnegative",[charged.value,deficit.value])
	if not left.ok: return left
	return {"ok":true,"amount":charged.value,"progress":left.value}

## Integrate a constant rate from its segment clock, rather than round dt products.
## Only elapsed seconds are floats; all resource arithmetic stays in Amount.
static func integrate(rate: Dictionary, seconds: float, meter: Dictionary, api) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0: return {"ok":false,"reason":"InvalidResourceInterval"}
	var checked: Dictionary = whole(rate, api)
	if not checked.ok: return checked
	var elapsed: float = float(meter.get("elapsed",0.0)) if meter.get("rate")==rate else 0.0
	var previous: Dictionary = meter.get("total",api.apply("zero",[]).value) if meter.get("rate")==rate else api.apply("zero",[]).value
	elapsed += seconds
	if not is_finite(elapsed): return {"ok":false,"reason":"InvalidResourceInterval"}
	var duration: Dictionary = api.apply("from_decimal",[str(elapsed)])
	if not duration.ok: return duration
	var total: Dictionary = api.apply("mul",[rate,duration.value])
	if not total.ok: return total
	var delta: Dictionary = api.apply("sub_nonnegative",[total.value,previous])
	if not delta.ok: return delta
	return {"ok":true,"amount":delta.value,"meter":{"rate":rate.duplicate(true),"elapsed":elapsed,"total":total.value}}

static func meters(values: Dictionary, api) -> Dictionary:
	for meter in values.values():
		if not meter is Dictionary or not meter.get("rate") is Dictionary or not meter.get("total") is Dictionary or not meter.get("elapsed") is float or not is_finite(meter.elapsed) or meter.elapsed<0.0:
			return {"ok":false,"reason":"InvalidResourceMeter"}
		var checked: Dictionary = integrate(meter.rate,0.0,{"rate":meter.rate,"elapsed":meter.elapsed,"total":api.apply("zero",[]).value},api)
		if not checked.ok: return checked
		var same: Dictionary = api.apply("compare",[checked.meter.total,meter.total])
		if not same.ok: return same
		if same.scalar!=0: return {"ok":false,"reason":"InvalidResourceMeter"}
	return {"ok":true,"values":values.duplicate(true)}

## No fractional coefficients or float conversion, even for an extreme integer.
static func integer_text(value: Dictionary, api) -> Dictionary:
	var checked: Dictionary = whole(value,api)
	if not checked.ok: return checked
	var shown: Dictionary = api.apply("to_display",[checked.value])
	if not shown.ok: return shown
	var parts: PackedStringArray = str(shown.text).to_lower().split("e")
	var fraction: PackedStringArray = parts[0].split(".")
	var digits: String = fraction[0] + (fraction[1] if fraction.size()>1 else "")
	var exponent: int = (int(parts[1]) if parts.size()>1 else 0) - (fraction[1].length() if fraction.size()>1 else 0)
	while exponent<0 and digits.ends_with("0"):
		digits = digits.trim_suffix("0")
		exponent += 1
	if exponent<0: return {"ok":false,"reason":"FractionalResourceDisplay"}
	return {"ok":true,"text":digits+"0".repeat(exponent) if exponent<=24 else digits+"×10^"+str(exponent)}
