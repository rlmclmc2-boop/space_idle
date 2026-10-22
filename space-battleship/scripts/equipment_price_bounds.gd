extends RefCounted

# Fixed-config audit experiment: positive decimal scientific intervals.
# Coefficients stay at 32 digits while decimal exponents may be very far apart.
const I = preload("res://scripts/currency_integer.gd")
const PRECISION := 32
var growth: Array

func _init() -> void:
	growth = _exact_binary64_decimal(1.0 + 0.2)

func _exact_binary64_decimal(value: float) -> Array:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var bits: int = bytes.decode_u64(0)
	var exponent: int = (bits >> 52) & 2047
	var mantissa: int = (bits & 4503599627370495) + 4503599627370496
	var shift: int = exponent - 1023 - 52
	assert(shift <= 0 and exponent > 0 and exponent < 2047)
	var coefficient: Variant = mantissa
	for i in -shift:
		coefficient = I.multiply(coefficient, 5)
	return [coefficient, shift]

func _trim(coefficient: Variant, exponent: int, up: bool) -> Array:
	var digits: String = I.digits(coefficient)
	if digits == "0" or digits.length() <= PRECISION:
		return [coefficient, exponent]
	var cut := digits.length() - PRECISION
	var kept: Variant = I.make(digits.substr(0, PRECISION))
	if up and digits.substr(PRECISION).lstrip("0") != "":
		kept = I.add(kept, 1)
	return [kept, exponent + cut]

func _mul(a: Array, b: Array, up: bool) -> Array:
	return _trim(I.multiply(a[0], b[0]), int(a[1]) + int(b[1]), up)

func _add(a: Array, b: Array, up: bool) -> Array:
	if I.digits(a[0]) == "0":
		return b
	if I.digits(b[0]) == "0":
		return a
	var high: Array = a if int(a[1]) >= int(b[1]) else b
	var low: Array = b if int(a[1]) >= int(b[1]) else a
	var gap: int = int(high[1]) - int(low[1])
	if gap > PRECISION + 2:
		# Low value is < one quantum at high's exponent.
		return _trim(I.add(high[0], 1) if up else high[0], int(high[1]), up)
	var scale: Variant = I.make("1" + "0".repeat(gap))
	var coefficient: Variant = I.add(I.multiply(high[0], scale), low[0])
	return _trim(coefficient, int(low[1]), up)

func _point(value: Array) -> Array:
	return [value, value]

func _interval_mul(a: Array, b: Array) -> Array:
	return [_mul(a[0], b[0], false), _mul(a[1], b[1], true)]

func _interval_add(a: Array, b: Array) -> Array:
	return [_add(a[0], b[0], false), _add(a[1], b[1], true)]

func power_and_series(count: int) -> Dictionary:
	var result_power: Array = _point([1,0])
	var result_sum: Array = _point([0,0])
	var block_power: Array = _point(growth)
	var block_sum: Array = _point([1,0])
	var remaining := count
	while remaining > 0:
		if remaining % 2 == 1:
			result_sum = _interval_add(result_sum, _interval_mul(result_power, block_sum))
			result_power = _interval_mul(result_power, block_power)
		remaining /= 2
		if remaining > 0:
			block_sum = _interval_add(block_sum, _interval_mul(block_power, block_sum))
			block_power = _interval_mul(block_power, block_power)
	return {"power":result_power,"sum":result_sum}

func raw_sum(start_exponent: int, count: int) -> Array:
	var power: Array = power_and_series(start_exponent).power
	var series: Array = power_and_series(count).sum
	return _interval_mul(_interval_mul(power, series), _point([50,0]))

func rounded_fee_envelope(start_exponent: int, count: int) -> Array:
	var raw: Array = raw_sum(start_exponent, count)
	return [_mul(raw[0], [95,-2], false), _mul(raw[1], [105,-2], true)]

func encoded_integer(bound: Array, up: bool) -> Dictionary:
	var coefficients: String = I.digits(bound[0])
	var exponent: int = int(bound[1])
	if exponent < 0:
		var kept: int = coefficients.length() + exponent
		if kept <= 0:
			return {"currency_version":1,"blocks":[{"p":"0","d":1}]} if up and coefficients != "0" else {"currency_version":1,"blocks":[]}
		var remaining: String = coefficients.substr(kept)
		var whole: Variant = I.make(coefficients.substr(0, kept))
		if up and remaining.lstrip("0") != "":
			whole = I.add(whole, 1)
		coefficients = I.digits(whole)
		exponent = 0
	if coefficients == "0":
		return {"currency_version":1,"blocks":[]}
	var group: int = exponent / 4
	var remainder: int = exponent % 4
	var digits: String = coefficients + "0".repeat(remainder)
	var blocks: Array = []
	var carry := 0
	for end in range(digits.length(), 0, -4):
		var start := maxi(0, end - 4)
		var raw: int = int(digits.substr(start, end - start)) + carry
		carry = 1 if raw >= 5000 else 0
		var digit := raw - carry * 10000
		if digit != 0:
			blocks.append({"p":str(group),"d":digit})
		group += 1
	if carry != 0:
		blocks.append({"p":str(group),"d":carry})
	return {"currency_version":1,"blocks":blocks}

