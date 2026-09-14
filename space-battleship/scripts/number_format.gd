class_name NumberFormat
extends RefCounted

static func plain(value: float) -> String:
	return str(int(value)) if is_equal_approx(value,roundf(value)) else "%.1f" % value

static func precise(value: float) -> String:
	return ("%.8f" % value).rstrip("0").trim_suffix(".") if value != roundf(value) else str(int(value))

static func compact(value: float) -> String:
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
