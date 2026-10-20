extends SceneTree

class ClockGame extends BattleGame:
	const NOW := 1000000.0
	func accrue_chrono_particles(saved_at: Variant, _now: float) -> float:
		return super.accrue_chrono_particles(saved_at,NOW)
	func _build_save_data() -> Dictionary:
		var saved := super._build_save_data()
		saved.chronoSavedAt=NOW
		profile.chronoSavedAt=NOW
		return saved



var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	# Fixed arithmetic scenarios; live configuration is covered by the matrix tests.
	db.config.offlineMax=12
	db.config.chronoParticlesPerSecond=1
	var game := BattleGame.new(db,false)
	check(game.default_speed()==1 and game.chrono_options().size()==10,"Default multiplier and option count read from config")
	for option in game.chrono_options():
		check(game.chrono_cost(float(option.multiplier))==float(option.multiplier)-1,"Configured cost: "+str(option.multiplier))
	game.accrue_chrono_particles(null,2000)
	check(game.profile.chronoParticles==0,"Old save without timestamp starts at zero")
	game.accrue_chrono_particles(1000.5,1001.4)
	check(game.profile.chronoParticles==0,"Only complete offline seconds count")
	game.accrue_chrono_particles(1000.5,1002.5)
	check(game.profile.chronoParticles==2,"Each complete offline second awards configured particles")
	game.accrue_chrono_particles(3000,2000)
	check(game.profile.chronoParticles==2,"Clock rollback awards nothing")
	game.profile.chronoParticles=0
	game.accrue_chrono_particles(1000,100000)
	check(game.profile.chronoParticles==game.chrono_capacity() and game.chrono_capacity()==43200,"Stored particles cap at twelve configured hours")
	game.profile.chronoParticles=game.chrono_capacity()-1
	game.accrue_chrono_particles(1000,1010)
	check(game.profile.chronoParticles==game.chrono_capacity(),"Already stored particles respect capacity")
	game.profile.chronoParticles=2
	check(game.set_speed(5),"Funded configured multiplier can be selected")
	check(is_equal_approx(game.chrono_affordable_seconds(1),0.5) and game.profile.chronoParticles==0,"Only affordable real seconds use accelerated rate")
	check(not game.set_speed(5),"Empty particles reject paid multiplier")
	game.speed=game.default_speed()
	check(game.chrono_affordable_seconds(1)==1 and game.profile.chronoParticles==0,"Default multiplier is free")
	db.config.offlineMax=0.5
	db.config.chronoParticlesPerSecond=2
	game.profile.chronoParticles=0
	game.accrue_chrono_particles(1000,100000)
	check(game.chrono_capacity()==3600 and game.profile.chronoParticles==3600,"Rate and capacity follow modified config")
	db.config.offlineMax=12
	db.config.chronoParticlesPerSecond=1
	game.profile.resources={"1":10.0,"2":20.0}
	game.profile.chronoParticles=3
	game.save_enabled=true
	game.save_progress()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.chronoParticles==3 and not saved.has("offlineRates") and not saved.has("offlineSavedAt"),"Save persists particles without legacy resource snapshots")
	saved.chronoSavedAt=ClockGame.NOW-10.5
	saved.hightechSavedAt=Time.get_unix_time_from_system()-1000
	var energy := BattleGame.ENERGY_FOCUS
	saved.cleared=db.data.hightech.keys().map(func(key):return int(db.unlock_row("hightech",key).level))
	saved.scientists=1
	saved.scientistAssignments={energy:1}
	saved.techPoints={energy:0.0}
	saved.aiTechActive="singularity"
	saved.aiTechProgress={"singularity":7.0}
	saved.aiTechLevels={"singularity":0}
	saved.offlineSavedAt=1000
	saved.offlineRates={"1":100000,"2":100000,"jewel":100000}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	var loaded := ClockGame.new(db,true)
	check(loaded.profile.chronoParticles>=13 and loaded.profile.chronoParticles<15,"Reopening awards offline particles once")
	check(loaded.login_chrono_particles>=10 and loaded.login_chrono_particles<12,"Login report counts only newly credited particles")
	check(loaded.profile.resources=={"1":10.0,"2":20.0} and loaded.profile.jewelFragments==0,"Legacy offline rates award no resources or fragments")
	check(loaded.profile.aiTechActive=="singularity" and loaded.hightech_level("singularity")==0 and float(loaded.profile.aiTechProgress.singularity)==7.0,"Offline time does not advance current AI research")
	check(loaded.assigned_scientists(energy)==0,"Retired scientist assignments are not reactivated")
	check(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)).chronoParticles==3,"Load keeps particle settlement in memory until explicit save")
	loaded.save_progress()
	var loaded_again := ClockGame.new(db,true)
	check(loaded_again.profile.chronoParticles==loaded.profile.chronoParticles,"Immediate reload cannot repeat offline interval")
	check(loaded_again.login_chrono_particles==0,"Immediate reload reports zero new particles")
	saved.erase("chronoParticles")
	saved.erase("chronoSavedAt")
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	var legacy := ClockGame.new(db,true)
	check(legacy.profile.chronoParticles==0 and legacy.profile.resources=={"1":10.0,"2":20.0},"Old save initializes particles at zero without old gains")
	check(legacy.login_chrono_particles==0,"Old save without chrono timestamp reports zero")
	legacy.profile.chronoSavedAt=1000.0
	legacy.save_progress()
	var background_saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(background_saved.chronoSavedAt==ClockGame.NOW,"Online save updates the timestamp used for later offline particles")
	saved.chronoParticles=game.chrono_capacity()-2
	saved.chronoSavedAt=ClockGame.NOW-10
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	var capped := ClockGame.new(db,true)
	check(capped.profile.chronoParticles==game.chrono_capacity() and capped.login_chrono_particles==2,"Login report uses actual credited amount at capacity")
	print("Chrono offline: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
