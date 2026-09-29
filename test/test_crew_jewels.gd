extends SceneTree

class TrackedGame extends BattleGame:
	var saves := 0
	func save_progress() -> void:
		saves+=1
		super.save_progress()

var checks := 0
var failures := 0
var db: ShipDatabase
var game: TrackedGame
var notices: Array

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func fresh() -> void:
	game=TrackedGame.new(db,false)
	game.save_enabled=false
	game.profile.cleared=range(1,60)
	game.profile.highestLevel=50
	game.profile.jewelFragments=0.0
	game.profile.jewels.clear()
	game.module_entry("weapons",0).level=40
	game.module_entry("weapons",0).sockets=[game.new_jewel("5"),{},{}]
	game.saves=0
	notices=[]
	game.event.connect(func(kind,info):
		if kind=="jewels_changed":notices.append(info))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	db=ShipDatabase.new()
	db.config.jewelCombine=3
	db.config.jewelCreat=1000000
	db.config.equipmentSocket="1|1,20|2,40|3"
	fresh()
	check(game.crew.assign(game,"navigator","jewel_auto","jewels"),"Crew accepts one jewel-system target")
	game.saves=0
	var old_token: int=game.module_entry("weapons",0).sockets[0].token
	for i in 3:game.profile.jewels.append(game.new_jewel("5"))
	game.crew.advance(game,0.9)
	check(game.module_entry("weapons",0).sockets[0].token==old_token and game.saves==0,"No jewel work before one second")
	var old_critical:=game.jewel_critical(game.module_entry("weapons",0)).x
	game.crew.advance(game,0.1)
	var installed: Dictionary=game.module_entry("weapons",0).sockets[0]
	check(installed.id=="5" and installed.level==2 and installed.token!=old_token,"One deadline combines inventory and replaces installed same-kind gem")
	check(not game.jewel_inventory(old_token).is_empty() and game.profile.jewels.size()==1,"Exchange keeps old gem and unique ownership")
	check(game.jewel_critical(game.module_entry("weapons",0)).x>old_critical,"Automatic replacement uses existing combat jewel effect")
	check(game.saves==2 and notices.size()==2 and notices[1].slots==["weapons_0"],"Combine and all socket changes each save and notify once")
	game.crew.advance(game,1)
	check(game.saves==2 and notices.size()==2,"Fixed point causes no saves or UI notifications")
	game.crew.assign(game,"navigator","","")
	game.saves=0
	game.crew.advance(game,2)
	check(game.saves==0,"Release stops scheduled jewel work")

	fresh()
	for i in 2:game.profile.jewels.append(game.new_jewel("5"))
	var result: Dictionary=game.auto_manage_jewels()
	check(result.combined==0 and result.upgraded==1 and game.module_entry("weapons",0).sockets[0].level==2,"Installed gem can use two matching bag materials through existing upgrade rule")
	check(game.saves==1 and notices.size()==1 and notices[0].slots==["weapons_0"],"In-place upgrade batches one save and targeted notification")

	fresh()
	var other: Dictionary=game.new_jewel("2",2)
	var locked: Dictionary=game.new_jewel("5",3)
	locked.locked=true
	game.profile.jewels=[other,locked]
	result=game.auto_manage_jewels()
	check(result.replaced==0 and game.module_entry("weapons",0).sockets[0].level==1,"Wrong kind and protected candidate cannot replace installed gem")
	locked.erase("locked")
	game.module_entry("weapons",0).sockets[0].disabled=true
	result=game.auto_manage_jewels()
	check(result.replaced==0 and game.saves==0,"Protected installed gem is never replaced")
	game.module_entry("weapons",0).sockets[0].erase("disabled")
	result=game.auto_manage_jewels()
	check(result.replaced==1 and game.module_entry("weapons",0).sockets[0].level==3 and game.jewel_inventory(int(other.token))==other,"Higher same-kind gem replaces installed; unrelated gem survives")
	check(game.saves==1 and notices.size()==1,"Single replacement uses one save and one UI event")

	fresh()
	game.module_entry("weapons",0).sockets=[game.new_jewel("5"),game.new_jewel("4"),{}]
	game.profile.jewels=[game.new_jewel("5",2),game.new_jewel("4",2)]
	result=game.auto_manage_jewels()
	check(result.replaced==2 and game.saves==1 and notices.size()==1,"Multiple sockets batch one save and UI event")
	check(notices[0].slots==["weapons_0"] and game.module_entry("weapons",0).sockets[1].level==2,"Batch event identifies changed equipment card once")

	fresh()
	game.module_entry("weapons",0).sockets=[{}]
	for i in 10:
		game.profile.loadout.weapons.append({"key":"laser","level":40,"sockets":[game.new_jewel("5")],"attacks":0,"hits":0})
		game.profile.jewels.append(game.new_jewel("5",db.jewel_max_level("5")))
	var batch_start:=Time.get_ticks_usec()
	result=game.auto_manage_jewels()
	var batch_us:=Time.get_ticks_usec()-batch_start
	check(result.replaced==10 and game.saves==1 and notices.size()==1 and notices[0].slots.size()==10,"Ten module replacements still save and notify once")
	print("Jewel ten-module replacement: %d us" % batch_us)

	fresh()
	game.module_entry("weapons",0).sockets=[game.new_jewel("5",db.jewel_max_level("5"))]
	for i in 200:game.profile.jewels.append(game.new_jewel("5",db.jewel_max_level("5")))
	var baseline_start:=Time.get_ticks_usec()
	for i in 30:game.combine_all_jewels()
	var baseline_us:=Time.get_ticks_usec()-baseline_start
	var auto_start:=Time.get_ticks_usec()
	for i in 30:game.auto_manage_jewels()
	var auto_us:=Time.get_ticks_usec()-auto_start
	check(game.saves==0 and notices.is_empty() and game.profile.jewels.size()==200,"Full fixed-point bag has no repeated saves or events")
	print("Jewel idle 30 cycles, old full check: %d us; crew precheck: %d us" % [baseline_us,auto_us])

	fresh()
	game.crew.load_state(game,[{"crewId":"navigator","level":2,"exp":7,"assignmentType":"smelting_speed","targetId":game.JEWEL_FURNACE}])
	check(game.crew.entry(game,"navigator").assignmentType=="jewel_auto" and game.crew.entry(game,"navigator").targetId=="jewels" and game.crew.entry(game,"navigator").exp==7,"Old smelting crew assignment migrates to jewel system without losing growth")

	fresh()
	for i in 200:game.profile.jewels.append(game.new_jewel("5"))
	var busy_start:=Time.get_ticks_usec()
	result=game.auto_manage_jewels()
	var busy_us:=Time.get_ticks_usec()-busy_start
	check(result.combined>0 and game.saves<=2 and notices.size()<=2,"Full combinable bag still batches saves and notifications")
	print("Jewel full-bag combine and replace: %d us, %d combines" % [busy_us,result.combined])
	print("Crew jewels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
