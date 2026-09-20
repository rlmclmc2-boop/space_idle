extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(UIText.reload_catalog().is_empty(),"catalog validates")
	check(UIText.t("battle.hp",{"current_hp":850,"max_hp":1000})=="生命 850 / 1000","named HP parameters")
	var db := ShipDatabase.new()
	var game := BattleGame.new(db)
	for section in ["resources","ship","enemies","jewel","hightech","charge"]:
		for id in db.data[section]:
			var field := "des" if section in ["ship","enemies"] else "name"
			var expected := str(db.data[section][id]) if section=="resources" else str(db.data[section][id].get(field,id))
			check(UIText.data_text(section,str(id),field)==expected,"default name "+section+"/"+str(id))
	for section in ["hightech","charge"]:
		for id in db.data[section]:
			var row: Dictionary = db.data[section][id]
			var field := "description" if section=="hightech" else "des"
			for level in [1,10,100]:
				check(game.ui_description(UIText.data_key(section,id,field),row,level,12345.0,10000.0)==game.format_description(row,str(row[field]),level,12345.0,10000.0),"formula display unchanged "+id+"/"+str(level))
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.game.paused = true
	var panel = scene.jewel_panel
	for id in scene.db.data.jewel:
		for level in [1,2,10]:
			var gem := {"id":id,"level":level}
			check(panel.gem_description(gem)==panel.gem_formula(gem,str(scene.db.jewel(id).des)),"gem formula unchanged "+id+"/"+str(level))
	var before = scene.game.profile.duplicate(true)
	var original := FileAccess.get_file_as_string("res://data/ui_text.json")
	var rows: Array = JSON.parse_string(original)
	for row in rows:
		if row.key=="battle.hp":row.text="耐久：{max_hp} ← {current_hp}"
		if row.key=="weapon.laser_name":row.text="文案测试激光"
		if row.key in ["gem.jewel_socket_error.text_01","gem.socket_error.text_01"]:row.text=""
	write_catalog(rows)
	check(UIText.reload_catalog().is_empty(),"ordinary text and parameter order editable")
	check(UIText.t("battle.hp",{"current_hp":"{max_hp}","max_hp":1000})=="耐久：1000 ← {max_hp}","single-pass interpolation never evaluates parameter values")
	check(scene.game.profile==before,"text changes cannot mutate gameplay state")
	check(scene.game.jewel_socket_error("weapons",0,-1).is_empty(),"error display may be edited to empty")
	check(not scene.game.jewel_socket_error_key("weapons",0,-1).is_empty(),"error decision is a stable key, not displayed text")
	check(not scene.game.socket_jewel("weapons",0,0,-1) and scene.game.profile==before,"blank error copy cannot permit invalid socket operation")
	check(not panel.socket_error_key(-1).is_empty(),"UI disabled state is independent of blank error text")
	var replacement = load("res://main.tscn").instantiate()
	root.add_child(replacement)
	check(replacement.NAMES.laser=="文案测试激光","scene restart refreshes equipment labels from the catalog")
	replacement.queue_free()
	await process_frame
	for invalid in ["耐久：{hp}/{max_hp}","耐久：{current_hp}","耐久：{current_hp}/{max_hp}/{extra}","耐久：{current_hp}/{max_hp}{"]:
		for row in rows:
			if row.key=="battle.hp":row.text=invalid
		write_catalog(rows)
		check(not UIText.reload_catalog().is_empty(),"invalid parameter edit rejected: "+invalid)
		check(UIText.t("battle.hp",{"current_hp":850,"max_hp":1000})=="耐久：1000 ← 850","invalid reload retains last good catalog")
	rows = JSON.parse_string(original)
	for row in rows:
		if row.key in ["battle.hp", "weapon.laser_name", "gem.jewel_socket_error.text_01"]: row.deleted = true
	write_catalog(rows)
	check(UIText.reload_catalog().is_empty(),"deleted rows retain valid parameter interfaces")
	check(UIText.t("battle.hp",{"current_hp":850,"max_hp":1000}).is_empty(),"deleted dynamic text hides all values")
	check(UIText.t("weapon.laser_name").is_empty(),"deleted static text hides without missing-key marker")
	check(not scene.game.jewel_socket_error_key("weapons",0,-1).is_empty(),"deleted error text retains gameplay decision")
	check(not scene.game.socket_jewel("weapons",0,0,-1),"deleted error does not enable forbidden action")
	var stream := FileAccess.open("res://data/ui_text.json",FileAccess.WRITE)
	stream.store_string(original)
	stream.close()
	check(UIText.reload_catalog().is_empty(),"restored original fixture")
	scene.queue_free()
	await process_frame
	print("UI text: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func write_catalog(rows: Array) -> void:
	var stream := FileAccess.open("res://data/ui_text.json",FileAccess.WRITE)
	stream.store_string(JSON.stringify(rows))
	stream.close()
