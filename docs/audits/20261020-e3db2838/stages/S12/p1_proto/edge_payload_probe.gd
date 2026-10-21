extends "res://price_probe.gd"

func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return "%016x" % bytes.decode_u64(0)

func _initialize() -> void:
	var small := 1e-300 * 1e-8
	var cases: Array = [
		["Q-LOW-25", small, 0.195, 4001],
		["Q-LOW-5", small, exp(710.0 / 4000.0) - 1.0, 4001],
		["Q-ZERO", 0.0, 0.2, 4001],
	]
	for centre in [["10",[0x4023ffffffffffff,0x4024000000000000,0x4024000000000001]],["95",[0x4057bfffffffffff,0x4057c00000000000,0x4057c00000000001]],["100",[0x4058ffffffffffff,0x4059000000000000,0x4059000000000001]]]:
		for index in 3:
			cases.append(["Q-EDGE-%s-%d" % [centre[0],index], from_bits(centre[1][index]), 0.0, 2])
	for entry in cases:
		var base: float = entry[1]
		var multiplier: float = entry[2]
		var result = quote(base, multiplier, int(entry[3]))
		print(JSON.stringify({"kind":"edge_payload","id":entry[0],"base_bits":bits(base),"multiplier_bits":bits(multiplier),"growth_bits":bits(1.0+multiplier),"level":entry[3],"observed":I.digits(result)}))
	quit()
