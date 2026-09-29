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
	db.config.jewelCreat = 10
	db.config.offlineMax = 1
	var game := BattleGame.new(db,false)
	game.profile.highestLevel = (int(db.unlock_row("feature","jewels").level)+1)
	game.load_jewels({"jewelFragments":{"1":12,"2":8,"deleted-id":7},"jewels":[{"id":"3","level":2}]})
	check(game.profile.jewelFragments==27 and game.profile.jewels.size()==1,"Migration sums every legacy type 1:1 including removed IDs")
	game.rng.seed=187
	game.generate_jewels()
	check(game.profile.jewelFragments==0 and game.profile.jewels.size()==3,"Migrated fragments produce two level-one gems and discard sub-cost tail")
	game.load_jewels(game.profile.duplicate(true))
	game.generate_jewels()
	check(game.profile.jewelFragments==0 and game.profile.jewels.size()==3,"New numeric save does not migrate twice")
	db.levels[0].jewelRatio=1.235
	check(is_equal_approx(game.settle_jewel_fragments(1,"drop"),1.24),"Final ratio amount rounded to two decimals")
	check(is_equal_approx(game.profile.jewelFragments,1.24),"Sub-cost fragments accumulate")
	var now := Time.get_unix_time_from_system()
	check(is_equal_approx(game.resource_minute_total("jewel",now),1.24),"Actual scaled production per minute")
	check(game.resource_minute_total("jewel",now+61)==0,"Production ages out after 60 seconds")
	game.settle_jewel_fragments(1,"other")
	check(is_equal_approx(game.profile.jewelFragments,2.48) and is_equal_approx(game.resource_minute_total("jewel",now),1.24),"Other credited fragments share multiplier but do not inflate production")
	db.levels[0].jewelRatio=0
	check(game.settle_jewel_fragments(100,"drop")==0 and is_equal_approx(game.profile.jewelFragments,2.48),"Zero level multiplier produces no fragments")
	db.levels[0].jewelRatio=2
	game.profile.jewelFragments=1.0
	game.profile.jewels.clear()
	var samples := game.resource_samples.duplicate(true)
	game.accrue_chrono_particles(1000,1600)
	check(game.profile.jewels.is_empty() and game.profile.jewelFragments==1 and game.resource_samples==samples,"Offline particles do not create jewel fragments or income")
	game.profile.jewels.clear()
	for i in 200:game.profile.jewels.append(game.new_jewel("1"))
	game.profile.jewelFragments=0
	game.settle_jewel_fragments(15,"other",1)
	check(game.profile.jewels.size()==200 and game.profile.jewelFragments==15,"Full inventory retains earned fragments")
	var token: int=game.profile.jewels[0].token
	check(game.socket_jewel("weapons",0,0,token) and game.profile.jewels.size()==200 and game.profile.jewelFragments==0,"Freeing capacity generates held gem and discards sub-cost tail")
	game.profile.jewels.clear()
	game.profile.jewelFragments=0.0
	db.config.jewelDrop=1.0
	game.jewel_kill_drop({"x":300,"y":300})
	var drop: Dictionary=game.drops[0]
	game.stage=2
	db.levels[1].jewelRatio=7
	game.collect(drop,true)
	check(game.profile.jewelFragments==2,"Drop uses the originating level even if pickup follows a stage change")
	game.collect(drop,true)
	check(game.profile.jewelFragments==2,"Repeated pickup is idempotent")
	db.config.jewelCreat=100
	for example in [{"fragments":400.0,"levels":[2,1]},{"fragments":1300.0,"levels":[3,2,1]},{"fragments":3700.0,"levels":[4,3]}]:
		game.profile.jewels.clear()
		game.profile.jewelFragments=0
		game.settle_jewel_fragments(example.fragments,"other",1)
		check(game.profile.jewels.map(func(gem):return int(gem.level))==example.levels and game.profile.jewelFragments==0,"Direct high-level production: "+str(example.fragments))
	game.profile.jewels.clear()
	game.profile.jewelFragments=0
	game.settle_jewel_fragments(100.0*pow(3.0,99.0),"other",1)
	check(game.profile.jewels.size()==1 and int(game.profile.jewels[0].level)==100,"Large finite batch directly produces level 100")
	game.profile.jewels.clear()
	game.profile.jewelFragments=0
	game.settle_jewel_fragments(pow(3.0,100.0),"other",1)
	check(game.profile.jewels.map(func(gem):return int(gem.level)).max()==96,"Fixed triple cost maps three-to-the-hundredth fragments to level 96")
	game.profile.jewels.clear()
	for i in 199:game.profile.jewels.append(game.new_jewel("1"))
	game.profile.jewelFragments=0
	game.settle_jewel_fragments(400,"other",1)
	check(game.profile.jewels.size()==199 and game.profile.jewelFragments==400,"Incomplete capacity holds the entire two-gem batch")
	game.profile.jewels.remove_at(0)
	game.generate_jewels()
	check(game.profile.jewels.size()==200 and game.profile.jewelFragments==0 and game.profile.jewels[-2].level==2 and game.profile.jewels[-1].level==1,"Pending batch settles together after two spaces open")
	db.config.jewelCreat=10
	game.profile.jewels.clear()
	game.profile.jewelFragments=0.0
	game.rng.seed=315
	game.settle_jewel_fragments(2000,"other",1)
	check(game.profile.jewels.map(func(gem):return int(gem.level))==[5,5,4,3] and game.profile.jewelFragments==0,"Large batch keeps three highest base-three digits")
	# Isolated roundtrip verifies no old offline fragment grant.
	game.profile.cleared=range(1,(int(db.unlock_row("feature","jewels").level)+1))
	game.resource_samples=[{"time":Time.get_unix_time_from_system(),"id":"jewel","amount":12.5,"origin":"drop"}]
	game.save_enabled=true
	game.save_progress()
	game.save_enabled=false
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(not saved.has("offlineRates"),"Save no longer stores offline fragment rates")
	saved.chronoSavedAt=Time.get_unix_time_from_system()-120
	saved.offlineRates={"jewel":100000}
	saved.offlineSavedAt=1000
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	var restored := BattleGame.new(db,true)
	check(restored.profile.jewels.size()==4 and restored.profile.jewelFragments==saved.jewelFragments and restored.profile.chronoParticles>=120,"Constructor ignores old fragment rates and awards particles")
	var next := BattleGame.new(db,true)
	check(next.profile.jewelFragments==restored.profile.jewelFragments and next.profile.chronoParticles==restored.profile.chronoParticles,"Immediate reload cannot repeat offline reward")
	print("Unified jewel fragments: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
