class_name NumberFormat
extends RefCounted

static func plain(value) -> String:
	if value is Dictionary:return GrowthNumber.text(value)
	if not is_finite(value):
		return str(value)
	if absf(value) >= 1e20:
		var exponent := floori(log(absf(value))/log(10.0))
		var mantissa: float = value/pow(10.0,exponent)
		if absf(mantissa) >= 9.995:
			mantissa /= 10.0
			exponent += 1
		return "%.2fe+%d" % [mantissa,exponent]
	if absf(value) >= 9e18:
		return "%.0f" % value
	return str(int(value)) if is_equal_approx(value,roundf(value)) else "%.1f" % value

static func precise(value) -> String:
	if value is Dictionary:return GrowthNumber.text(value)
	if not is_finite(value) or absf(value) >= 9e18:
		return plain(value)
	return ("%.8f" % value).rstrip("0").trim_suffix(".") if value != roundf(value) else str(int(value))

# Shared presentation ladder. Never converts large-number dictionaries to float.
const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"]

static func trimmed_decimal(value: float, decimals: int) -> String:
	var text := "%.*f" % [decimals,value]
	return text.rstrip("0").trim_suffix(".") if text.contains(".") else text

static func compact(value, suffix_decimals := -1) -> String:
	var mantissa: float
	var exponent: float
	if value is Dictionary:
		mantissa = float(value.m)
		exponent = float(value.e)
	else:
		var amount := float(value)
		if not is_finite(amount):return str(amount)
		if amount==0:return "0"
		exponent = floorf(log(absf(amount))/log(10.0))
		# Normalize subnormal floats without dividing by an underflowed power.
		mantissa = (amount*1e300)/pow(10.0,exponent+300.0) if exponent < -300 else amount/pow(10.0,exponent)
	if mantissa==0:return "0"
	var sign := "-" if mantissa<0 else ""
	# Percentages opt into integer points and one decimal after a suffix.
	# The default quantity path below keeps its existing three significant digits.
	if suffix_decimals>=0:
		if exponent<3:
			var integer := roundf(absf(mantissa)*pow(10.0,exponent))
			return sign+("%.0f" % integer) if integer<1000.0 else sign+"1K"
		if exponent>=33:
			var scale := pow(10.0,suffix_decimals)
			var rounded_mantissa := roundf(absf(mantissa)*scale+1e-9)/scale
			if rounded_mantissa>=10.0:rounded_mantissa/=10.0;exponent+=1.0
			return sign+trimmed_decimal(rounded_mantissa,suffix_decimals)+"e+"+("%.0f" % exponent)
		var suffix_index := floori(exponent/3.0)
		var scaled := absf(mantissa)*pow(10.0,exponent-suffix_index*3.0)
		var decimal_scale := pow(10.0,suffix_decimals)
		scaled=roundf(scaled*decimal_scale+1e-9)/decimal_scale
		if scaled>=1000.0:scaled=1.0;suffix_index+=1
		if suffix_index>=SUFFIXES.size():return sign+"1e+33"
		return sign+trimmed_decimal(scaled,suffix_decimals)+SUFFIXES[suffix_index]
	# Round only local display components; carry before choosing the suffix.
	var rounded := roundf(absf(mantissa)*100.0+1e-9)/100.0
	if rounded>=10.0:
		rounded /= 10.0
		exponent += 1.0
	if exponent>=33:
		return sign+trimmed_decimal(rounded,2)+"e+"+("%.0f" % exponent)
	if exponent<0:
		return sign+"0."+"0".repeat(int(-exponent)-1)+trimmed_decimal(rounded,2).replace(".","")
	var unit := floori(exponent/3.0)
	var within_unit := int(exponent)-unit*3
	return sign+trimmed_decimal(rounded*pow(10.0,within_unit),2-within_unit)+SUFFIXES[unit]

# Input is percentage points, not a fractional probability or multiplier.
static func percentage(value) -> String:
	return compact(value if value is Dictionary else roundf(float(value)),1)

# Match both endpoints and their signed change on the same presentation ladder.
static func signed_difference(value, previous) -> String:
	var direction := GrowthNumber.compare(value,previous)
	var magnitude = GrowthNumber.subtract(GrowthNumber.maximum(value,previous),GrowthNumber.minimum(value,previous))
	return ("+" if direction>=0 else "-")+compact(magnitude)

static func rate(value) -> String:
	if value is Dictionary:return compact(value)
	return "%.2f" % value if absf(value) < 1000.0 else compact(value)

# Damage presentation only; no rounding is applied to combat values.
static func damage(value) -> String:
	return compact(value if value is Dictionary else absf(value))
