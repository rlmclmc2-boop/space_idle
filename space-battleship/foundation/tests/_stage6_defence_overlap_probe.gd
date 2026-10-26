extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _run() -> void:
	var fixture: Dictionary = _defence_case(["B", "", ""], false, "memory", 1,
		{"memory_heal": 0.001, "memory_cap": 0.1}, {"before_advance": true, "shield": true, "remaining": 100.0})
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var session = fixture.session
	for index in 5:
		var oracle := RandomNumberGenerator.new()
		oracle.state = int(session.battle._kernel.persistent_state().rng_state)
		oracle.randf()
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.2)
		if not advanced.ok or int(session.battle._kernel.persistent_state().rng_state) != oracle.state:
			printerr("C09 multiple modules did not share one memory recovery roll at ", index, " ", advanced)
			quit(1)
			return
	var cover: Dictionary = _defence_case(["", "B", ""], true, "adaptation", 1, {},
		{"authored_memory": true, "remaining": 1.34, "interval": 1000000.0, "damage": "4e4", "other_remaining": 1.84, "other_damage": "8e4"})
	if not cover.ok or cover.hits.size() != 1 or not is_equal_approx(float(cover.hits[0][0]), 2.5) or str(cover.hits[0][1]) != "5e3":
		printerr("C09 cover must pay before memory buffer: ", cover)
		quit(1)
		return
	print("STAGE6_DEFENCE_OVERLAP_OK C09 two modules share one B1 roll per recovery tick; cover-before-memory gives exactly5000 loss at2.50")
	quit()
