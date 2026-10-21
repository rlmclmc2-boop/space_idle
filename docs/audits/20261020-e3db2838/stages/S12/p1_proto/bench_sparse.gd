extends SceneTree

# Exploratory Windows/Godot probe, not an official P1 repetition. JSON parsing,
# validation, typed operations and encoding are measured separately and together.
class CurrencyValue:
	extends RefCounted
	var positions: PackedInt64Array
	var digits: PackedInt32Array
	func _init(p: PackedInt64Array, d: PackedInt32Array):
		positions = p
		digits = d

func candidate(n: int, remote: bool) -> Dictionary:
	var blocks: Array = []
	for i in n:
		var position := i
		if remote and i == n - 1:
			position = 250000000
		blocks.append([str(position), 1])
	return {"v":4,"blocks":blocks}

func decode(value: Variant) -> CurrencyValue:
	if not (value is Dictionary and value.size() == 2 and value.get("v") == 4 and value.get("blocks") is Array):
		return null
	var p := PackedInt64Array()
	var d := PackedInt32Array()
	for block in value.blocks:
		if not (block is Array and block.size() == 2 and block[0] is String and (block[1] is int or block[1] is float) and is_finite(float(block[1])) and float(block[1]) == floorf(float(block[1]))):
			return null
		var position_string: String = block[0]
		if not position_string.is_valid_int() or str(int(position_string)) != position_string:
			return null
		var position := int(position_string)
		var digit := int(block[1])
		if digit < -5000 or digit > 4999 or digit == 0 or (not p.is_empty() and position <= p[-1]):
			return null
		p.append(position)
		d.append(digit)
	# Empty blocks are the unique canonical encoding of zero.
	if not d.is_empty() and d[-1] < 0:
		return null
	return CurrencyValue.new(p, d)

func compare(a: CurrencyValue, b: CurrencyValue) -> int:
	var i := a.positions.size() - 1
	var j := b.positions.size() - 1
	while i >= 0 or j >= 0:
		var delta := 0
		if i < 0:
			delta = -b.digits[j]
			j -= 1
		elif j < 0:
			delta = a.digits[i]
			i -= 1
		elif a.positions[i] == b.positions[j]:
			delta = a.digits[i] - b.digits[j]
			i -= 1
			j -= 1
		elif a.positions[i] > b.positions[j]:
			delta = a.digits[i]
			i -= 1
		else:
			delta = -b.digits[j]
			j -= 1
		if delta != 0:
			return 1 if delta > 0 else -1
	return 0

func combine(a: CurrencyValue, b: CurrencyValue, b_sign: int) -> CurrencyValue:
	var p := PackedInt64Array()
	var d := PackedInt32Array()
	var i := 0
	var j := 0
	var carry := 0
	var carry_position := 0
	while i < a.positions.size() or j < b.positions.size() or carry != 0:
		var at: int
		if i < a.positions.size():
			at = a.positions[i]
		elif j < b.positions.size():
			at = b.positions[j]
		else:
			at = carry_position
		if j < b.positions.size():
			at = mini(at, b.positions[j])
		if carry != 0:
			at = mini(at, carry_position)
		var sum := 0
		if i < a.positions.size() and a.positions[i] == at:
			sum += a.digits[i]
			i += 1
		if j < b.positions.size() and b.positions[j] == at:
			sum += b_sign * b.digits[j]
			j += 1
		if carry != 0 and carry_position == at:
			sum += carry
			carry = 0
		var next_carry := int(floori(float(sum + 5000) / 10000.0))
		sum -= next_carry * 10000
		if sum != 0:
			p.append(at)
			d.append(sum)
		if next_carry != 0:
			if at == 9223372036854775807:
				return null
			carry = next_carry
			carry_position = at + 1
	return CurrencyValue.new(p, d)

func add(a: CurrencyValue, b: CurrencyValue) -> CurrencyValue:
	return combine(a, b, 1)

func subtract(a: CurrencyValue, b: CurrencyValue) -> CurrencyValue:
	if compare(a, b) < 0:
		return null
	return combine(a, b, -1)

func encode(value: CurrencyValue) -> Dictionary:
	var blocks: Array = []
	for i in value.positions.size():
		blocks.append([str(value.positions[i]), value.digits[i]])
	return {"v":4,"blocks":blocks}

func _initialize() -> void:
	for n in [1, 100, 1000, 10000]:
		for remote in [false, true]:
			var input := candidate(n, remote)
			var source_json := JSON.stringify(input)
			var t := Time.get_ticks_usec()
			var parsed = JSON.parse_string(source_json)
			var parse_us := Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var a := decode(parsed)
			var decode_us := Time.get_ticks_usec() - t
			if a == null:
				printerr("decode_failed n=", n, " remote=", remote)
				quit(1)
				return
			t = Time.get_ticks_usec()
			var cmp := compare(a, a)
			var compare_us := Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var doubled := add(a, a)
			var add_us := Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var restored := subtract(doubled, a)
			var subtract_us := Time.get_ticks_usec() - t
			if restored == null or compare(restored, a) != 0:
				printerr("roundtrip_failed n=", n, " remote=", remote)
				quit(1)
				return
			t = Time.get_ticks_usec()
			var encoded := JSON.stringify(encode(doubled))
			var encode_us := Time.get_ticks_usec() - t
			print(JSON.stringify({"kind":"exploratory_sparse","n":n,"remote":remote,"input_bytes":source_json.to_utf8_buffer().size(),"output_bytes":encoded.to_utf8_buffer().size(),"parse_us":parse_us,"decode_us":decode_us,"compare_us":compare_us,"add_us":add_us,"subtract_us":subtract_us,"encode_us":encode_us,"compare_result":cmp,"output_blocks":doubled.positions.size()}))
	quit()
