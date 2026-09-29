extends SceneTree

class LoadOrderGame extends BattleGame:
	var boundaries: Array[String] = []
	func load_progress() -> void:
		boundaries.append("load")
		super.load_progress()
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
	write_save({"version":BattleGame.SAVE_VERSION,"resources":{"1":123.5,"2":-4}})
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.resources=={"1":124.0,"2":0.0},"Legacy fractional save rounds up and negative resource clamps")
	check(loaded.profile.version==BattleGame.SAVE_VERSION and loaded.slot_entry("weapons",0).level==1,"Missing fields retain current version and default equipment")
	check(not loaded.profile.has("levels"),"Compatibility levels never enter runtime")
	var again := BattleGame.new(db,true)
	check(again.profile.resources==loaded.profile.resources and again.profile.loadout==loaded.profile.loadout,"Repeated load does not round or migrate again")
	loaded.profile.resources["1"] = 321
	loaded.save_progress()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.resources["1"]==321 and saved.version==BattleGame.SAVE_VERSION,"Temporary save replaces existing target")
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
	# Loading may credit particles, but must discard the retired charge state.
	db.config.offlineMax = 1.0/3600.0
	var seed := BattleGame.new(db,false)
	seed.profile.cleared = [1]
	seed.profile.resources = {"1":0.0,"2":0.0}
	seed.profile.hightechSavedAt = Time.get_unix_time_from_system()-100
	seed.profile.chronoSavedAt = Time.get_unix_time_from_system()-100
	seed.profile.offlineSavedAt = floorf(Time.get_unix_time_from_system())-100
	seed.profile.offlineRates = {"1":0.0,"2":10.0}
	var old_save := seed.profile.duplicate(true)
	old_save.charge = {"攻击充能":{"level":99,"active":true}}
	write_save(old_save)
	var settled := LoadOrderGame.new(db,true)
	check(settled.boundaries==["load","save","player"],"Load grants particles and saves before resetting player")
	check(settled.profile.chronoParticles==1 and settled.profile.resources["2"]==0,"Offline time credits only particles")
	check(not settled.profile.has("charge"),"Old charge state is discarded")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(disk.resources==settled.profile.resources and disk.chronoParticles==1 and not disk.has("charge"),"Load persists particle credit and removes old charge")
	# The saved timestamp prevents repeated particle credit.
	var repeated := BattleGame.new(db,true)
	check(repeated.profile.resources==settled.profile.resources and repeated.profile.chronoParticles==settled.profile.chronoParticles,"Immediate repeat cannot reclaim offline particle credit")
	var immediate := LoadOrderGame.new(db,false)
	immediate.save_enabled = true
	immediate.profile.cleared = [1]
	immediate.profile.resources["2"] = 1000.0
	immediate.boundaries.clear()
	check(immediate.upgrade_reactor(1),"Reactor upgrade succeeds")
	check(immediate.boundaries.count("save")==1,"Reactor upgrade saves immediately")
	var upgraded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(upgraded.reactorLevel==2 and upgraded.resources["2"]==900,"Saved reactor level and uranium match")
	print("Save boundaries: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
