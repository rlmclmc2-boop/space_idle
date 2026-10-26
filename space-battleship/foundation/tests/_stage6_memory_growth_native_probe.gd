extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _run() -> void:
	var options: Dictionary = {"authored_memory": true, "damage": "6e4", "interval": 1000000.0, "remaining": 2.5}
	var plain: Dictionary = _defence_case(["", "", ""], false, "memory", 1, {}, options)
	var stronger: Dictionary = _defence_case(["A", "A", "A"], false, "memory", 1, {}, options)
	var capacity: Dictionary = _defence_case(["", "", "B"], false, "memory", 1, {}, options)
	if not plain.ok or not stronger.ok or not capacity.ok or plain.hits.size() != 1 or str(plain.hits[0][1]) != "5e3" or not stronger.hits.is_empty() or not capacity.hits.is_empty():
		printerr("C09 memory A/B3: ", plain, stronger, capacity)
		quit(1)
		return
	options.remaining = 0.5
	options.damage = "3e4"
	var heal_plain: Dictionary = _defence_case(["", "", ""], false, "memory", 1, {}, options)
	var heal_a: Dictionary = _defence_case(["A", "A", "A"], false, "memory", 1, {}, options)
	if not heal_plain.ok or not heal_a.ok or heal_plain.hits.size() != 1 or str(heal_plain.hits[0][1]) != "2.5e3" or not heal_a.hits.is_empty():
		printerr("C09 memory A recovery/charging: ", heal_plain, heal_a)
		quit(1)
		return
	options.shield = true
	options.damage = "6e4"
	var shield_plain: Dictionary = _defence_case(["", "", ""], false, "memory", 1, {}, options)
	var shield_b3: Dictionary = _defence_case(["", "", "B"], false, "memory", 1, {}, options)
	if not shield_plain.ok or not shield_b3.ok or shield_plain.hits.size() != 1 or str(shield_plain.hits[0][1]) != "5e3" or not shield_b3.hits.is_empty():
		printerr("C09 memory B3 shield charging: ", shield_plain, shield_b3)
		quit(1)
		return
	print("STAGE6_MEMORY_GROWTH_NATIVE_OK C09; A1/A2/A3 healing and buffer cap, B3 armour capacity and per-shield charge compared against independent plain cases")
	quit()
