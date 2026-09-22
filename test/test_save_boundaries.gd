extends SceneTree

class LoadOrderGame extends BattleGame:
	var boundaries: Array[String] = []
	func load_progress() -> void:
		boundaries.append("load")
		super.load_progress()
	func advance_charge(dt: float) -> void:
		boundaries.append("charge")
		super.advance_charge(dt)
	func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
		boundaries.append("research")
		super.advance_hightech(dt,real_dt,end_time)
	func save_progress() -> void:
		boundaries.append("save")
		super.save_progress()
	func reset_player() -> void:
		boundaries.append("player")
		super.reset_player()

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func write_save(raw: Dictionary) -> void:
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()

func _initialize() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax = 0
	write_save({"version":1,"resources":{"1":123.5,"2":-4}})
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.resources=={"1":124.0,"2":0.0},"Legacy fractional save rounds up and negative resource clamps")
	check(loaded.profile.version==1 and loaded.slot_entry("weapons",0).level==1,"Missing fields retain version1 and default equipment")
	check(not loaded.profile.has("levels"),"Compatibility levels never enter runtime")
	var again := BattleGame.new(db,true)
	check(again.profile.resources==loaded.profile.resources and again.profile.loadout==loaded.profile.loadout,"Repeated load does not round or migrate again")
	loaded.profile.resources["1"] = 321
	loaded.save_progress()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.resources["1"]==321 and saved.version==1,"Temporary save replaces existing target")
	check(not FileAccess.file_exists(BattleGame.SAVE_PATH+".tmp"),"Successful rename leaves no temporary file")
	# Fail opening the temp file with an isolated directory, never a player path.
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	var errors: Array = []
	loaded.event.connect(func(kind,_payload):
		if kind=="save_error": errors.append(kind))
	loaded.profile.resources["1"] = 999
	loaded.save_progress()
	check(loaded.save_dirty,"Failed save retains dirty state for retry")
	check(errors==["save_error"],"Temporary open failure emits one save_error")
	check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original,"Temporary open failure preserves previous save bytes")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	# A directory at the target isolates rename failure from temporary-file open.
	DirAccess.remove_absolute(BattleGame.SAVE_PATH)
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH)
	loaded.save_progress()
	check(errors==["save_error","save_error"],"Rename failure emits one additional save_error")
	check(DirAccess.dir_exists_absolute(BattleGame.SAVE_PATH),"Rename failure does not destroy the obstructing target")
	check(FileAccess.file_exists(BattleGame.SAVE_PATH+".tmp"),"Observed rename failure retains temporary data; not an atomicity guarantee")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH)
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	# One-second cap makes elapsed wall-clock jitter irrelevant. Offline resource
	# credit must exist before charge consumes it; the result must then be saved.
	db.config.offlineMax = 1.0/3600.0
	var key := "攻击充能"
	db.unlock_row("charge",key).level = 1
	db.data.charge[key].para_2 = 5
	db.data.charge[key].para_5 = 100
	db.data.charge[key].para_4 = 1
	db.data.charge[key].para_7 = 0
	var seed := BattleGame.new(db,false)
	seed.profile.cleared = [1]
	seed.profile.resources = {"1":0.0,"2":0.0}
	seed.profile.hightechSavedAt = Time.get_unix_time_from_system()-100
	seed.profile.offlineSavedAt = floorf(Time.get_unix_time_from_system())-100
	seed.profile.offlineRates = {"1":0.0,"2":10.0}
	seed.profile.charge[key].active = true
	seed.profile.charge[key].started = 1
	write_save(seed.profile)
	var settled := LoadOrderGame.new(db,true)
	check(settled.boundaries==["load","charge","research","save","player"],"Load settles resources then charge then research, saves before resetting player")
	check(settled.offline_rewards.get("2",0)==10 and settled.profile.resources["2"]==5,"Offline credit precedes charge debit at load")
	check(settled.charge_job(key).count>0,"Offline charge progresses using credited resources")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(disk.resources==settled.profile.resources and disk.charge==JSON.parse_string(JSON.stringify(settled.profile.charge)),"Load persists settled resources and charge together")
	# Zero cap isolates duplicate resource credit from a newly elapsed charge interval.
	db.config.offlineMax = 0
	var repeated := BattleGame.new(db,true)
	check(repeated.profile.resources==settled.profile.resources and repeated.offline_rewards.is_empty(),"Immediate repeat cannot reclaim offline resource credit")
	var deferred := LoadOrderGame.new(db,false)
	deferred.save_enabled = true
	deferred.profile.cleared = [1]
	deferred.profile.resources = {"1":1000.0,"2":1000.0}
	deferred.profile.charge[key].active = true
	deferred.profile.charge[key].started = 1
	deferred.save_progress()
	deferred.boundaries.clear()
	var before_tick := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	deferred.tick(0.1)
	check(deferred.save_dirty and deferred.boundaries.count("save")==0,"Charge debit marks dirty without saving during tick")
	check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==before_tick,"Charge tick leaves persisted bytes untouched")
	deferred.hightech_save_elapsed = 4.95
	deferred.tick(0.1)
	check(deferred.boundaries.count("save")==1 and not deferred.save_dirty,"Existing periodic checkpoint flushes and clears dirty")
	deferred.tick(0.1)
	deferred.save_progress()
	var flushed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(flushed.resources==deferred.profile.resources and not deferred.save_dirty,"Explicit exit/key checkpoint flushes pending charge resources")
	print("Save boundaries: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
