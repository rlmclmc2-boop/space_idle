class_name NumberFormat
extends RefCounted

static func plain(value: float) -> String:
	if not is_finite(value):
		return str(value)
	if absf(value) >= 1e20:
		var exponent := floori(log(absf(value))/log(10.0))
		var mantissa := value/pow(10.0,exponent)
		if absf(mantissa) >= 9.995:
			mantissa /= 10.0
			exponent += 1
		return "%.2fe+%d" % [mantissa,exponent]
	if absf(value) >= 9e18:
		return "%.0f" % value
	return str(int(value)) if is_equal_approx(value,roundf(value)) else "%.1f" % value

static func precise(value: float) -> String:
	if not is_finite(value) or absf(value) >= 9e18:
		return plain(value)
	return ("%.8f" % value).rstrip("0").trim_suffix(".") if value != roundf(value) else str(int(value))

static func compact(value: float) -> String:
	if not is_finite(value) or value >= 1e20:
		return plain(value)
	value = maxf(0.0,value)
	if value < 100.0:
		return plain(value)
	var step := 1.0
	while value >= step * 100.0:
		step *= 10.0
	var truncated := floorf(value / step) * step
	var divisor := 1.0
	var unit := 0
	var suffixes := ["", "K", "M", "B", "T"]
	while truncated >= divisor * 1000.0 and unit < suffixes.size() - 1:
		divisor *= 1000.0
		unit += 1
	return plain(truncated / divisor) + suffixes[unit]

static func rate(value: float) -> String:
	return "%.2f" % value if value < 1000.0 else compact(value)

# Damage presentation only; no rounding is applied to combat values.
static func damage(value: float) -> String:
	value = absf(value)
	if not is_finite(value):return str(value)
	if value==0:return "0"
	if value>=1e36:return "%.2e" % value
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var unit := 0
	while value>=1000 and unit<suffixes.size()-1:
		value /= 1000
		unit += 1
	var decimals := maxi(0,2-floori(log(maxf(value,0.001))/log(10.0)))
	var rounded := snappedf(value,pow(10,-decimals))
	if rounded>=1000 and unit<suffixes.size()-1:
		rounded /= 1000
		unit += 1
		decimals = 2
	return ("%.*f" % [decimals,rounded]).trim_suffix(".00")+suffixes[unit]
