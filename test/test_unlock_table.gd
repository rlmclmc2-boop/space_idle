extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax = 0
	check(db.data.unlock.size()>=28 and db.data.unlock.values().filter(func(row):return str(row.type)=="hightech").size()==4,"Original four hightech gates remain in the unlock table")
	db.unlock_row("equipment","laser").level=1
	var initial := BattleGame.new(db,false)
	check(not initial.profile.unlocked.has("laser"),"startEquip cannot bypass an authored stage gate")
	db.unlock_row("equipment","laser").level=0
	initial=BattleGame.new(db,false)
	check(initial.profile.unlocked.has("laser") and initial.profile.unlocked.has("armour"),"Authored zero gates retain initial availability")
	for stage in range(1,db.levels.size()+1):
		var game := BattleGame.new(db,false)
		game.profile.cleared = range(1,stage)
		game.rebuild_unlocks()
		game.start(stage,false)
		game.group_index = db.levels[stage-1].groups.size()
		var before_clear := game.available_unlocks()
		game.clear_level()
		var expected: Array[String] = []
		for id in game.available_unlocks():
			if not before_clear.has(id):expected.append(id)
		check(game.pending_unlocks==expected,"Every unlock fires at stage "+str(stage))
		var original := game.pending_unlocks.duplicate()
		game.clear_level()
		check(game.pending_unlocks==original,"Repeated clear never duplicates queued items")
		while not game.pending_unlocks.is_empty():
			var count := game.pending_unlocks.size()
			game.acknowledge_unlocks()
			check(game.pending_unlocks.size()==count-1,"Each acknowledgment advances one item")
		game.clear_level()
		check(game.pending_unlocks.is_empty(),"Replays do not renotify")
	var game := BattleGame.new(db,false)
	game.profile.cleared=[10]
	game.rebuild_unlocks()
	check(game.jewels_unlocked() and game.ship_unlocked("Destroyer") and not game.profile.unlocked.has("shield"),"Gapped saves preserve reached-vs-exact gate semantics")
	db.unlock_row("feature","reactor").level=9
	check(not game.reactor_unlocked(),"Only unlock table sets gate")
	game.profile.cleared.append(9)
	game.rebuild_unlocks()
	check(game.reactor_unlocked(),"Edited gate triggers")
	db.unlock_row("feature","reactor").level=40
	game.rebuild_unlocks()
	check(game.reactor_unlocked(),"Earned content cannot relock after config change")
	# Old save without new fields; use isolated user:// supplied by run.py.
	var raw := {"version":BattleGame.SAVE_VERSION,"cleared":[1,2,3,7,10,12],"unlocked":["laser","armour","longLaser"],"selectedShip":"Destroyer"}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw));file.close()
	var loaded := BattleGame.new(db,true)
	check(loaded.jewels_unlocked() and loaded.ship_unlocked("Destroyer") and loaded.hightech_unlocked(BattleGame.JEWEL_FURNACE),"Old saves retain all cleared systems")
	check(loaded.profile.unlocked.has("longLaser"),"Explicit old equipment ownership retained")
	check(loaded.pending_unlocks.is_empty(),"Old ownership does not generate new notices")
	loaded.start(2,false)
	loaded.group_index=db.levels[1].groups.size()
	loaded.state=BattleGame.State.LEVEL_CLEAR
	loaded.pending_unlocks.assign(loaded.available_unlocks().slice(0,2))
	for id in loaded.pending_unlocks:loaded.profile.seenUnlocks.erase(id)
	var saved_queue: Dictionary = JSON.parse_string(JSON.stringify(loaded.portable_save_data()))
	var resumed := BattleGame.new(db,false)
	resumed.load_progress_data(saved_queue)
	resumed.resume_progress()
	check(resumed.pending_unlocks==loaded.pending_unlocks,"Mixed queue survives restart in full")
	resumed.acknowledge_unlocks()
	var saved_partial: Dictionary = JSON.parse_string(JSON.stringify(resumed.portable_save_data()))
	var again := BattleGame.new(db,false)
	again.load_progress_data(saved_partial)
	again.resume_progress()
	check(again.pending_unlocks==resumed.pending_unlocks and again.pending_unlocks.size()==1,"Partial acknowledgment persists")
	check(again.profile.unlocked.has("longLaser"),"Ownership retained across second load")
	print("Unlock table: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
