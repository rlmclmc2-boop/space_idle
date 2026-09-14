extends SceneTree

const KEY := "攻击充能"
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func fixture() -> BattleGame:
	var db := ShipDatabase.new()
	db.data.charge[KEY].merge({"para_2":2,"para_4":1,"para_5":1,"para_6":2,"para_7":1,"unlock":0},true)
	var g := BattleGame.new(db,false)
	g.profile.resources["2"]=100
	g.toggle_charge(KEY)
	return g

func run() -> void:
	var g := fixture()
	check(g.charge_resource_rate(KEY)==2,"Zero level uses base rate")
	g.advance_charge(1)
	check(g.charge_job(KEY).level==1 and g.profile.resources["2"]==98 and g.charge_resource_rate(KEY)==4,"Rate increases immediately at upgrade")
	g.advance_charge(7)
	check(g.charge_job(KEY).level==3 and g.charge_job(KEY).count==1 and g.profile.resources["2"]==42,"Large step charges 2 + 8 + 32 + 16 across levels")
	var fine := fixture()
	var counts := fixture()
	counts.db.data.charge[KEY].merge({"para_5":1,"para_6":1.5},true)
	counts.advance_charge(1)
	check(counts.charge_required(KEY)==2 and counts.charge_job(KEY).level==1,"Required count 1.5 rounds to 2 at level one")
	counts.advance_charge(2)
	check(counts.charge_required(KEY)==2 and counts.charge_job(KEY).level==2 and counts.charge_job(KEY).count==0,"Required count 2.25 rounds to 2 without fractional carry")
	counts.advance_charge(2)
	check(counts.charge_job(KEY).level==3 and counts.charge_required(KEY)==3 and counts.profile.resources["2"]==74,"Rounded thresholds drive cross-level cost boundaries")
	counts.db.data.charge[KEY].para_5=1.5
	counts.charge_job(KEY).level=0
	check(counts.charge_required(KEY)==2,"Base required count is also rounded after calculation")
	for i in range(800):
		fine.advance_charge(0.01)
	check(fine.profile.resources["2"]==g.profile.resources["2"] and fine.charge_job(KEY).level==3 and fine.charge_job(KEY).count==1,"Small online frames match long-step level costs")
	var short := fixture()
	short.profile.resources["2"]=4
	short.advance_charge(100)
	check(short.charge_job(KEY).level==1 and is_equal_approx(short.charge_job(KEY).elapsed,0.5) and short.profile.resources["2"]==0,"Shortage after upgrade retains progress at higher rate")
	short.advance_charge(100)
	check(is_equal_approx(short.charge_job(KEY).elapsed,0.5),"Empty resources do not erase progress")
	short.profile.resources["2"]=2
	short.advance_charge(0.5)
	check(short.charge_job(KEY).count==1 and short.profile.resources["2"]==0,"Refill resumes at current level's rate")
	var rounding := fixture()
	rounding.db.data.charge[KEY].para_2=1
	rounding.db.data.charge[KEY].para_7=0.05
	rounding.charge_job(KEY).level=1
	check(rounding.charge_resource_rate(KEY)==1,"Entire 1.05 rate rounds to nearest integer 1")
	rounding.charge_job(KEY).level=15
	check(rounding.charge_resource_rate(KEY)==2,"Exponent is applied before rounding")
	rounding.db.data.charge[KEY].para_7=0.5
	rounding.charge_job(KEY).level=1
	check(rounding.charge_resource_rate(KEY)==2,"Exact midpoint 1.5 rounds up to 2")
	rounding.db.data.charge[KEY].para_7=0.05
	rounding.db.data.charge[KEY].des="{para7}"
	check(rounding.charge_description(KEY)=="0.1","Description accepts para7 using existing compact formatter")
	rounding.db.data.charge[KEY].erase("para_7")
	check(rounding.charge_resource_rate(KEY)==1,"Legacy data without parameter 7 keeps constant base cost")
	var free := fixture()
	free.db.data.charge[KEY].para_2=0.4
	free.profile.resources["2"]=0
	free.advance_charge(2)
	check(free.charge_job(KEY).level==1 and free.charge_job(KEY).elapsed==0 and free.charge_resource_rate(KEY)==1,"Zero rounded rate advances safely until upgrade requires resources")
	var credit := fixture()
	credit.db.data.charge[KEY].merge({"para_2":1,"para_4":0.5,"para_6":1,"para_7":0.5},true)
	credit.profile.resources["2"]=2
	credit.advance_charge(1)
	check(credit.charge_job(KEY).level==2 and credit.profile.resources["2"]==0 and is_equal_approx(credit.charge_job(KEY).credit,0.5),"Prepaid resource remainder uses new rate across upgrade")
	var offline := fixture()
	offline.db.config.offlineMax=8.0/3600.0
	offline.save_enabled=true
	offline.save_progress()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	raw.hightechSavedAt=Time.get_unix_time_from_system()-100
	raw.offlineRates={}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var loaded := BattleGame.new(offline.db,true)
	check(loaded.profile.resources["2"]==42 and loaded.charge_job(KEY).level==3 and loaded.charge_job(KEY).count==1,"Actual offline load respects cap and each level's rate")
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=[1]
	scene.db.data.charge[KEY].merge({"para_2":1,"para_7":0.05,"unlock":0},true)
	scene.game.charge_job(KEY).level=15
	scene.build_ui()
	check(scene.charge_cards[KEY].cost.text.contains("2/秒"),"Card displays rounded current-level rate")
	print("Charge growth: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
