extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	check(db.data.jewel.keys() == ["1", "2", "3", "4", "5", "6"], "Only six authored jewels")
	var expected := ["proficiency", "adaptation", "repair", "repeat", "critical", "tenacity"]
	for i in 6:
		var id := str(i + 1)
		check(db.jewel_effect(id) == expected[i], "Effect " + id)
		check(int(db.jewel_parameter(id, 1)) == (1 if i in [0, 3, 4] else 2), "Category " + id)
		check(not UIText.data_text("jewel", id).is_empty(), "Display name " + id)
	for i in range(7, 11):
		check(db.jewel(str(i)).is_empty(), "Removed jewel " + str(i))
	var old := {"version":1, "resources":{"1":99999,"2":99999}, "jewels":[{"id":"3","level":8}], "loadout":{"weapons":[{"key":"laser","level":10,"sockets":[{"id":"4","level":8}]}], "defence":[]}}
	var file := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var game := BattleGame.new(db, true)
	check(game.profile.version == BattleGame.SAVE_VERSION, "New save version")
	check(game.profile.jewels.is_empty(), "Old inventory discarded")
	for category in ["weapons", "defence"]:
		for entry in game.module_entries(category):
			for gem in entry.get("sockets", []):
				check(gem.is_empty(), "Old socket emptied")
	check(game.profile.resources["1"] != 99999, "Old progress discarded")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.version == BattleGame.SAVE_VERSION and saved.jewels.is_empty(), "Old save overwritten")
	print("JEWEL REDESIGN: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
