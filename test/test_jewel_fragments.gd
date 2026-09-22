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
	check(game.profile.jewelFragments==7 and game.profile.jewels.size()==3,"Migrated total batches and retains remainder")
	game.load_jewels(game.profile.duplicate(true))
	game.generate_jewels()
	check(game.profile.jewelFragments==7 and game.profile.jewels.size()==3,"New numeric save does not migrate twice")
	db.levels[0].jewelRatio=1.235
	check(is_equal_approx(game.settle_jewel_fragments(1,"drop"),1.24),"Final ratio amount rounded to two decimals")
	check(is_equal_approx(game.profile.jewelFragments,8.24),"Fraction retained")
	var now := Time.get_unix_time_from_system()
	check(is_equal_approx(game.resource_minute_total("jewel",now),1.24),"Actual scaled production per minute")
	check(game.resource_minute_total("jewel",now+61)==0,"Production ages out after 60 seconds")
	game.settle_jewel_fragments(1,"decompose")
	check(is_equal_approx(game.profile.jewelFragments,9.48) and is_equal_approx(game.resource_minute_total("jewel",now),1.24),"Refund shares multiplier but does not inflate offline production")
	db.levels[0].jewelRatio=0
	check(game.settle_jewel_fragments(100,"drop")==0 and is_equal_approx(game.profile.jewelFragments,9.48),"Zero level multiplier produces no fragments")
	db.levels[0].jewelRatio=2
	game.profile.jewelFragments=1.0
	game.profile.jewels.clear()
	var samples := game.resource_samples.duplicate(true)
	game.settle_offline_resources({"offlineSavedAt":1000,"offlineRates":{"jewel":0.025}},1600)
	check(game.profile.jewels.size()==1 and game.profile.jewelFragments==6,"Offline duration times actual rate, without multiplying twice")
	check(game.offline_rewards.get("jewel",0)==15 and game.resource_samples==samples,"Offline reports total earned and cannot feed income back")
	game.profile.jewelFragments=0.0
	game.profile.jewels.clear()
	game.settle_offline_resources({"offlineSavedAt":1000,"offlineRates":{"jewel":0.025}},10000)
	check(game.profile.jewels.size()==9 and game.profile.jewelFragments==0,"Existing offline cap applies")
	game.settle_offline_resources({"offlineSavedAt":20000,"offlineRates":{"jewel":1}},10000)
	check(game.profile.jewels.size()==9 and game.profile.jewelFragments==0,"Future timestamp cannot award fragments")
	game.settle_offline_resources({"offlineSavedAt":1000,"offlineRates":{"1":0}},2000)
	check(game.profile.jewels.size()==9,"Old save without fragment rate has no invented income")
	game.profile.jewels.clear()
	for i in 200:game.profile.jewels.append(game.new_jewel("1"))
	game.settle_offline_resources({"offlineSavedAt":1000,"offlineRates":{"jewel":0.025}},1600)
	check(game.profile.jewels.size()==200 and game.profile.jewelFragments==15,"Full inventory retains every offline fragment")
	var token: int=game.profile.jewels[0].token
	check(game.socket_jewel("weapons",0,0,token) and game.profile.jewels.size()==200 and game.profile.jewelFragments==5,"Freeing capacity generates held gem without losing socket owner")
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
	game.profile.jewels.clear()
	game.profile.jewelFragments=0.0
	game.rng.seed=315
	game.settle_jewel_fragments(2000,"offline",1)
	var kinds := {}
	for gem in game.profile.jewels:kinds[gem.id]=true
	check(game.profile.jewels.size()==200 and kinds.size()==10,"Batch generates random valid gems of all configured kinds")
	# Isolated roundtrip also verifies the saved per-second rate and no second offline grant.
	game.profile.cleared=range(1,(int(db.unlock_row("feature","jewels").level)+1))
	game.resource_samples=[{"time":Time.get_unix_time_from_system(),"id":"jewel","amount":12.5,"origin":"drop"}]
	game.save_enabled=true
	game.save_progress()
	game.save_enabled=false
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(is_equal_approx(float(saved.offlineRates.jewel)*60,12.5),"Save stores the same actual rate displayed by UI")
	saved.offlineSavedAt=floorf(Time.get_unix_time_from_system())-120
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	var restored := BattleGame.new(db,true)
	check(restored.profile.jewels.size()==200 and restored.profile.jewelFragments>=25 and restored.profile.jewelFragments<25.5,"Constructor awards offline fragments once and keeps capped excess")
	var next := BattleGame.new(db,true)
	check(next.profile.jewelFragments==restored.profile.jewelFragments,"Immediate reload cannot repeat offline reward")
	print("Unified jewel fragments: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
