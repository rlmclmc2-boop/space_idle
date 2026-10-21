extends SceneTree

const I = preload("res://reference_integer.gd")

func trim_bound(coefficient: Variant, exponent: int, precision: int, up: bool) -> Array:
	var digits: String = I.digits(coefficient)
	if digits.length() <= precision:
		return [coefficient, exponent]
	var cut := digits.length() - precision
	var kept = I.make(digits.substr(0, precision))
	if up and digits.substr(precision).lstrip("0") != "":
		kept = I.add(kept, 1)
	return [kept, exponent + cut]

func multiply_bound(a: Array, b: Array, precision: int, up: bool) -> Array:
	return trim_bound(I.multiply(a[0], b[0]), int(a[1]) + int(b[1]), precision, up)

func rounded_bound(bound: Array) -> Array:
	var digits: String = I.digits(bound[0])
	var magnitude := digits.length() + int(bound[1]) - 1
	if magnitude < 2:
		return [int(digits.substr(0,1)) * 10 + 5 if magnitude == 1 else 5, 0]
	var step_power := magnitude - 1
	var shift := int(bound[1]) - step_power
	var shifted: String = digits + "0".repeat(shift) if shift >= 0 else digits
	var whole_length := shifted.length() + mini(shift, 0)
	var leading := int(shifted.substr(0, maxi(0, whole_length)))
	if shift < 0 and whole_length >= 0 and whole_length < shifted.length() and shifted[whole_length] >= "5":
		leading += 1
	return [leading, step_power]

func bounded_large(base: float, growth: float, level: int) -> Variant:
	var base_part: Array = I.decimal_factor(base)
	var growth_part: Array = I.decimal_factor(growth)
	for precision in [16,24,32,48,96,192,384]:
		var lower: Array = [1,0]
		var upper: Array = [1,0]
		var low_power: Array = [growth_part[0], -int(growth_part[1])]
		var high_power: Array = low_power.duplicate()
		var count := level - 1
		while count > 0:
			if count % 2 == 1:
				lower = multiply_bound(lower, low_power, precision, false)
				upper = multiply_bound(upper, high_power, precision, true)
			count /= 2
			if count > 0:
				low_power = multiply_bound(low_power, low_power, precision, false)
				high_power = multiply_bound(high_power, high_power, precision, true)
		lower = multiply_bound(lower, [base_part[0], -int(base_part[1])], precision, false)
		upper = multiply_bound(upper, [base_part[0], -int(base_part[1])], precision, true)
		var low_rounded := rounded_bound(lower)
		var high_rounded := rounded_bound(upper)
		if low_rounded == high_rounded:
			return I.make(str(low_rounded[0]) + "0".repeat(int(low_rounded[1])))
	return null

# This audit-only prototype takes the immutable main decimal-factor primitive
# as input. It applies S09's low/zero/high branch before the final integer.
func quote(base: float, multiplier: float, level: int) -> Variant:
	if level < 1 or base < 0.0 or not is_finite(base) or multiplier <= -1.0 or not is_finite(multiplier):
		return null
	if base == 0.0:
		return 0
	if level == 1:
		return I.float_floor(ceilf(base))
	var growth := 1.0 + multiplier
	var ordinary := base * pow(growth, level - 1)
	if is_finite(ordinary):
		if ordinary <= 0.0:
			return 0
		if ordinary < 100.0:
			return I.float_floor(ceilf(floorf(ordinary / 10.0) * 10.0 + 5.0))
		var step := pow(10.0, floorf(log(ordinary) / log(10.0) + 1e-12) - 1.0)
		return I.float_floor(ceilf(floorf(ordinary / step + 0.5) * step))
	var bounded = bounded_large(base, growth, level)
	if bounded != null:
		return bounded
	var cursor: Array = I.cost_cursor(base, growth, level - 1)
	var digits: String = I.digits(cursor[0])
	var magnitude: int = digits.length() - int(cursor[1]) - 1
	if magnitude < 2:
		# floor(value/10)*10+5, even when pow overflowed before the
		# subnormal base brought the final mathematical price below 100.
		var tens = I._integral([cursor[0], int(cursor[1]) + 1], false)
		return I.add(I.multiply(tens, 10), 5)
	var step_power := magnitude - 1
	var leading := int(digits.substr(0, 2))
	if digits.length() > 2 and digits[2] >= "5":
		leading += 1
	return I.make(str(leading) + "0".repeat(step_power))

func from_bits(bits: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_u64(0, bits)
	return bytes.decode_double(0)

func _initialize() -> void:
	var base := 1e-300 * 1e-8
	var cases: Array = [
		{"id":"Q-LOW-25","base":base,"multiplier":0.195,"level":4001,"expected":"25"},
		{"id":"Q-LOW-5","base":base,"multiplier":exp(710.0/4000.0)-1.0,"level":4001,"expected":"5"},
	]
	for level in [1,20,4001]:
		cases.append({"id":"Q-ZERO-%d" % level,"base":0.0,"multiplier":0.2,"level":level,"expected":"0"})
	for item in [[3873,"803914d47b7bb8203fbb937177fb94088403fe49f6001f805149a4921af03083"],[4001,"d1832976eb7e63ac95898e60c8ffe9cc53958c191f5396d9d40f9f955d17d9d7"],[10000,"2bb656f3a80d7b2b8782173aa00aa65d7bce22e4ca771562e59bdf563b1958b8"],[50000,"6b6c719e275e49faabadae24a6cfd4e5ccf99ff44d912fb0ff733904047a31fb"]]:
		cases.append({"id":"Q-HIGH-%d" % item[0],"base":50.0,"multiplier":0.2,"level":item[0],"expected_sha256":item[1]})
	var edges := [
		["Q-EDGE-10",[0x4023ffffffffffff,0x4024000000000000,0x4024000000000001],["5","15","15"]],
		["Q-EDGE-95",[0x4057bfffffffffff,0x4057c00000000000,0x4057c00000000001],["95","95","95"]],
		["Q-EDGE-100",[0x4058ffffffffffff,0x4059000000000000,0x4059000000000001],["95","100","100"]],
	]
	for edge in edges:
		for i in 3:
			cases.append({"id":"%s-%d" % [edge[0],i],"base":from_bits(edge[1][i]),"multiplier":0.0,"level":2,"expected":edge[2][i]})
	var failures := 0
	for item in cases:
		var started := Time.get_ticks_usec()
		var result = quote(item.base,item.multiplier,item.level)
		var elapsed := Time.get_ticks_usec()-started
		var observed := I.digits(result) if result != null else "error"
		var hasher := HashingContext.new()
		hasher.start(HashingContext.HASH_SHA256)
		hasher.update(observed.to_utf8_buffer())
		var sha: String = hasher.finish().hex_encode()
		var ok: bool = sha == item.expected_sha256 if item.has("expected_sha256") else observed == item.expected
		if not ok:
			failures += 1
		print(JSON.stringify({"kind":"exploratory_price","id":item.id,"base_scientific":String.num_scientific(item.base),"multiplier_scientific":String.num_scientific(item.multiplier),"level":item.level,"expected":item.get("expected",item.get("expected_sha256","")),"observed":observed if observed.length()<=32 else observed.substr(0,20)+"..."+str(observed.length())+" digits","observed_sha256":sha,"ok":ok,"elapsed_us":elapsed}))
	quit(0 if failures == 0 else 1)
