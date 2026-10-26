extends "res://foundation/tests/_stage6_repeat_identity_probe.gd"

func _run() -> void:
	for row in [["cannon", 480], ["missile", 460], ["longLaser", 260]]:
		var result: Dictionary = _case(["B", "", "B"], true, 0.0, 0.5, "1e6", {}, row[0], row[1])
		if not result.ok:
			printerr(row, result)
			quit(1)
			return
		var amounts: Dictionary = {}
		for hit in result.hits:
			var key: int = int(round(float(hit.damage)))
			amounts[key] = int(amounts.get(key, 0)) + 1
		var expected: Dictionary = {100: 3, 1100: 2} if row[0] == "cannon" else {100: 9, 1100: 5} if row[0] == "missile" else {100: 3, 125: 2, 150: 2, 175: 2, 200: 2, 225: 2, 250: 2, 1100: 2}
		var total: String = "2500" if row[0] == "cannon" else "6400" if row[0] == "missile" else "4750"
		var api = ClassDB.instantiate("FoundationAmount")
		if int(result.history.attacks) != 1 or amounts != expected or result.totals.size() != 1 or int(api.apply("compare", [result.totals["module:0"].health, api.apply("from_decimal", [total]).value]).scalar) != 0:
			printerr("C09/C10 repeat weapon identity: ", row[0], " ", amounts, result.history, result.totals)
			quit(1)
			return
		print("C09/C10 ", row[0], " root1 source module:0 total=", total, " damage groups=", amounts)
	print("STAGE6_REPEAT_WEAPON_MATRIX_OK C09/C10 cannon/missile/beam chain-secondary-repeat ownership; laser covered separately")
	quit()
