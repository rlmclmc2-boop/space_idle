extends SceneTree
const ClockGame=preload("res://qa/clock_game.gd")
var failures:=0
func check(ok: bool, label: String) -> void:
	if not ok:failures+=1;printerr("FAIL ",label)
func run_case(multiplier: float) -> Dictionary:
	var db:=ShipDatabase.new()
	db.unlock_row("hightech",BattleGame.FURNACE).level=0
	db.data.hightech[BattleGame.FURNACE].para1=10.0
	db.data.hightech[BattleGame.FURNACE].para2=.1
	var g=ClockGame.new(db,false)
	g.profile.hightechLevels[BattleGame.FURNACE]=1
	g.speed=multiplier
	g.rng.seed=20261002
	for step in range(600*60):
		g.wall+=1.0/60.0/multiplier
		# Controlled identical combat-independent receipts, every five game seconds.
		if step%300==0:
			var drop={"uid":step,"id":"1","amount":100.0,"x":200.0,"y":300.0,"age":0.0}
			g.drops.append(drop);g.collect(drop,false)
		g.tick(1.0/60.0)
	var result={"resources":g.profile.resources,"peak":g.profile.furnaceIncomePeak,"production_clock":g.production_time(),"hud_last_real_minute":g.resource_minute_total("1"),"production_window":g.production_minute_total("1"),"research":g.profile.hightechLevels}
	var save=g.portable_save_data()
	var resumed=ClockGame.new(db,false);resumed.wall=g.wall;resumed.load_hightech(save)
	check(resumed.production_time()==g.production_time(),"production clock persists")
	check(resumed.production_minute_total("1")==g.production_minute_total("1"),"production window persists")
	var before: Dictionary=g.profile.resources.duplicate(true)
	var production_before:float=g.production_time()
	g.accrue_chrono_particles(g.wall,g.wall+3600)
	check(g.profile.resources==before and g.production_time()==production_before,"offline accrues no second resource or production clock")
	return result
func battle_case(multiplier: float) -> Dictionary:
	var db:=ShipDatabase.new()
	db.unlock_row("hightech",BattleGame.FURNACE).level=0
	var g=ClockGame.new(db,false)
	g.stat_cache_enabled=true;g.rng.seed=1984;g.speed=multiplier
	g.profile.hightechLevels[BattleGame.FURNACE]=1
	for index in g.weapon_entries().size():g.equip_slot("weapons",index,"laser")
	for index in g.defense_entries().size():g.equip_slot("defence",index,"armour")
	g.start(1,false);g.toggle_loop()
	var counts := {}
	g.event.connect(func(kind, _payload):counts[kind]=int(counts.get(kind,0))+1)
	for step in range(300*60):
		g.wall+=1.0/60.0/multiplier;g.tick(1.0/60.0)
	return {"resources":g.profile.resources,"counts":counts,"rng":str(g.rng.state),"peak":g.profile.furnaceIncomePeak,"player":g.player,"cooldowns":g.cooldowns}
func _initialize() -> void:
	var x1=run_case(1.0);var x10=run_case(10.0)
	check(x1.resources==x10.resources,"X1/X10 identical X1 resource receipts and furnace output")
	check(x1.peak==x10.peak and x1.production_window==x10.production_window,"X1/X10 identical production peak/window")
	check(x1.research==x10.research,"X1/X10 research equality")
	var battle_x1=battle_case(1.0);var battle_x10=battle_case(10.0)
	check(battle_x1==battle_x10,"real combat receipts, events, RNG and cooldowns match at X1/X10")
	print("TIME_EQUIVALENCE ",JSON.stringify({"x1":x1,"x10":x10,"failures":failures,"battle_equal":battle_x1==battle_x10,"battle_x1":battle_x1,"battle_x10":battle_x10}))
	quit(1 if failures else 0)
