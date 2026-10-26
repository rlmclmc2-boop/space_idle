extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"
## C09 memory protection and deferred probability-to-damage conversion.

func _run() -> void:
	# Protection resistance belongs to the charged memory buffer, not armour.
	var memory: Dictionary = _defence_case(["", "B", ""], true, "memory", 2, {"memory_heal": 0.001, "memory_cap": 0.1})
	var baseline: Dictionary = _defence_case(["", "", ""], true, "memory", 2, {"memory_heal": 0.001, "memory_cap": 0.1})
	var deferred: Dictionary = _defence_case(["", "B", ""], false, "deferred")
	if not memory.ok or not deferred.ok or not baseline.ok:
		printerr("C09 defence branch fixture: ", memory, deferred)
		quit(1)
		return
	if not is_equal_approx(float(memory.hits[0][0]), 1.41) or not is_equal_approx(float(baseline.hits[0][0]), 1.16) or str(baseline.hits[0][1]) != "2.5e1":
		printerr("C09 memory protected buffer did not absorb first contact: ", memory.hits, baseline.hits)
		quit(1)
		return
	for index in 3:
		if str(memory.hits[index][1]) != ["8e1", "5e1", "1e2"][index]:
			printerr("C09 memory protection/type break/lockout: ", memory.hits)
			quit(1)
			return
	for hit in deferred.hits:
		if str(hit[1]) != "4.4e1":
			printerr("C09 deferred conversion expected ceil(100*(1-0.25*0.5)*0.5)=44: ", deferred.hits)
			quit(1)
			return
	var renewed: Dictionary = _defence_case(["", "B", ""], true, "memory", 2,
		{"memory_heal": 0.001, "memory_cap": 0.1}, {"interval": 2.5})
	if not renewed.ok or renewed.hits.size() != 3 or str(renewed.hits[0][1]) != "8e1" or str(renewed.hits[1][1]) != "2e1" or str(renewed.hits[2][1]) != "1e2" or not is_equal_approx(float(renewed.hits[1][0]), 3.66):
		printerr("C09 memory B2 reacquisition after 3.41 lockout expiry: ", renewed)
		quit(1)
		return
	print("STAGE6_MEMORY_PROTECTION_NATIVE_OK C09 memory B2 same-type protection, different-type break and lockout; deferred B2 conversion gives 44")
	quit()
