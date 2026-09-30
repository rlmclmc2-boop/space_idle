extends SceneTree

class TrackedGame extends BattleGame:
	var saves := 0
	var fail_save := false
	func save_progress() -> void:
		saves+=1
		if fail_save:event.emit("save_error",{})
		else:super.save_progress()

var checks := 0
var failures := 0
var db: ShipDatabase
var game: TrackedGame
var notifications := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func fresh() -> void:
	game=TrackedGame.new(db,false)
	game.profile.highestLevel=(int(db.unlock_row("feature","jewels").level)+1)
	game.saves=0
	notifications=0
	game.event.connect(func(kind,_info):
		if kind=="jewels_changed":notifications+=1)

func add(id: String, level: int, count: int) -> void:
	for i in count:game.profile.jewels.append(game.new_jewel(id,level))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	db=ShipDatabase.new()
	db.config.jewelCombine=3
	db.config.jewelCreat=10
	db.data.jewel["1"].maxLevel=3
	db.data.jewel["2"].maxLevel=3
	fresh()
	add("1",1,18)
	add("2",1,3)
	add("1",3,1)
	var old_max: Dictionary=game.profile.jewels.back()
	var result := game.combine_all_jewels()
	check(result.ok and result.count==9 and result.consumed==27,"Chained outputs keep combining; cumulative consumption includes intermediates")
	check(result.results==[{"id":"1","level":3,"count":2},{"id":"2","level":2,"count":1}],"Rewards group only final newly produced high-level gems")
	check(game.profile.jewels.size()==4 and is_same(game.jewel_inventory(int(old_max.token)),old_max),"Existing maximum-level gem survives without being counted as a reward")
	check(notifications==1 and game.saves==1,"Whole operation emits and saves exactly once")
	var before := game.profile.duplicate(true)
	result=game.combine_all_jewels()
	check(result.ok and result.count==0 and game.profile==before and notifications==1 and game.saves==1,"Repeated click at fixed point changes nothing")

	fresh()
	add("1",1,5)
	var locked: Dictionary=game.profile.jewels[0]
	var disabled: Dictionary=game.profile.jewels[1]
	locked.locked=true
	disabled.disabled=true
	var equipped := game.new_jewel("1",1)
	game.slot_entry("weapons",0).sockets=[equipped]
	check(not game.can_combine_jewels([locked.token,disabled.token,game.profile.jewels[2].token]),"Single and bulk paths share protection checks")
	result=game.combine_all_jewels()
	check(result.count==1 and result.consumed==3 and game.profile.jewels.size()==3,"Protected bag gems are excluded from counts")
	check(is_same(game.jewel_inventory(int(locked.token)),locked) and is_same(game.jewel_inventory(int(disabled.token)),disabled),"Locked and disabled gems retain identity and flags")
	check(is_same(game.slot_entry("weapons",0).sockets[0],equipped),"Equipped gem is never consumed")

	fresh()
	add("1",1,2)
	add("1",2,2)
	add("2",1,2)
	before=game.profile.duplicate(true)
	result=game.combine_all_jewels()
	check(result.count==0 and game.profile==before,"Different IDs and levels cannot be pooled together")
	db.config.jewelCombine=2
	result=game.combine_all_jewels()
	check(result.count==3 and result.consumed==6 and result.results[0].level==3,"Combine count and maximum level come from current data")
	db.config.jewelCombine=3

	fresh()
	add("1",1,3)
	game.profile.jewels.append(game.profile.jewels[0])
	before=game.profile.duplicate(true)
	var serial := game.jewel_serial
	var rng_state := game.rng.state
	result=game.combine_all_jewels()
	check(not result.ok and game.profile==before and game.jewel_serial==serial and game.rng.state==rng_state and game.saves==0,"Corrupt duplicate identity fails atomically")
	fresh()
	add("1",1,3)
	before=game.profile.duplicate(true)
	for value in [0,1,2.5,"3"]:
		db.config.jewelCombine=value
		check(not game.combine_all_jewels().ok and game.profile==before,"Invalid combine config cannot debit: "+str(value))
	db.config.jewelCombine=3

	# A single valid type makes refill conservation deterministic without changing files.
	db.data.jewel={"1":db.data.jewel["1"].duplicate(true)}
	fresh()
	add("1",1,200)
	game.profile.jewelFragments=100.0
	result=game.combine_all_jewels()
	check(result.ok and result.count>0 and result.consumed==result.count*3,"Full bag plus held fragments converge through direct-tier refill and upgrades")
	check(game.profile.jewels.size()==24 and game.profile.jewelFragments==0,"Refill consumes exactly ten creation costs, never overflowing inventory")
	check(result.results==[{"id":"1","level":3,"count":23},{"id":"1","level":2,"count":1}],"Final rewards exclude all consumed intermediate outputs")
	check(game.saves==1 and notifications==1,"Refill rounds still commit and notify once")
	for gem in game.profile.jewels:check(int(gem.level)<=db.jewel_max_level(str(gem.id)),"Configured maximum respected")

	# Explicit bulk combine removes only bag gems more than ten levels below each type's peak.
	db.data.jewel=ShipDatabase.new().data.jewel
	fresh()
	var installed_peak:=game.new_jewel("1",30)
	game.slot_entry("weapons",0).sockets=[installed_peak]
	add("1",20,1)
	add("1",19,1)
	add("2",5,1)
	add("2",1,1)
	var obsolete: Dictionary=game.profile.jewels[1]
	obsolete.locked=true
	before=game.profile.duplicate(true)
	result=game.combine_all_jewels(false)
	check(result.ok and result.deleted==0 and game.profile==before,"Automatic management does not clear old bag gems")
	game.fail_save=true
	result=game.combine_all_jewels()
	check(not result.ok and game.profile==before and is_same(game.slot_entry("weapons",0).sockets[0],installed_peak) and notifications==0,"Failed cleanup save restores all bag and equipped gems")
	game.fail_save=false
	game.saves=0
	result=game.combine_all_jewels()
	check(result.ok and result.count==0 and result.deleted==1 and game.profile.jewels.size()==3,"Explicit combine clears only the matching type below the ten-level window")
	check(game.jewel_inventory(int(obsolete.token)).is_empty() and not game.profile.jewels.filter(func(gem):return str(gem.id)=="2").is_empty(),"Cleanup includes stale protected bag records but preserves other types")
	check(is_same(game.slot_entry("weapons",0).sockets[0],installed_peak) and notifications==1 and game.saves==1,"Equipped gem survives cleanup and transaction commits once")

	fresh()
	add("1",1,9)
	game.profile.jewelFragments=100.0
	before=game.profile.duplicate(true)
	var live: Array=game.profile.jewels
	serial=game.jewel_serial
	rng_state=game.rng.state
	game.begin_frame_save_batch()
	game.fail_save=true
	result=game.combine_all_jewels()
	game.end_frame_save_batch()
	check(not result.ok and game.profile==before and is_same(game.profile.jewels,live),"Injected save failure leaves original profile and inventory unchanged")
	check(game.jewel_serial==serial and game.rng.state==rng_state and notifications==0 and not game.jewel_bulk_combining,"Failed transaction consumes no serials/RNG and emits no inventory refresh")
	game.fail_save=false
	game.save_enabled=true
	game.begin_frame_save_batch()
	result=game.combine_all_jewels()
	var transaction_saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	game.end_frame_save_batch()
	game.save_enabled=false
	check(result.ok,"Retry after save failure succeeds")
	check(transaction_saved.jewels.size()==game.profile.jewels.size(),"Jewel transaction saves synchronously inside frame batch")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.jewels.size()==game.profile.jewels.size() and saved.jewelFragments==game.profile.jewelFragments,"Committed result is persisted as the final inventory")
	var restored := BattleGame.new(db,false)
	restored.load_progress()
	check(restored.profile.jewels.map(func(gem):return [gem.id,gem.level])==game.profile.jewels.map(func(gem):return [gem.id,gem.level]),"Batch result survives reload")
	print("Jewel bulk combine: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
