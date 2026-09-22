extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	var key := BattleGame.ENERGY_FOCUS
	g.profile.cleared = db.data.hightech.keys().map(func(key):return int(db.unlock_row("hightech",key).level))
	g.profile.scientistAssignments[key] = 1
	db.config.techPointGet = 1e20
	db.data.hightech[key].tpCostBase = 10.0
	db.data.hightech[key].tpCostMutiple = 0.2
	var start := Time.get_ticks_usec()
	g.advance_hightech(1.0)
	var elapsed := Time.get_ticks_usec()-start
	var level := g.hightech_level(key)
	check(absf(float(level)-1e10)<10,"1e20 budget settles billions of levels")
	check(float(g.profile.techPoints[key])>=0,"Remainder nonnegative")
	check(elapsed<1000000,"Bulk update finishes under one second")
	g.profile.hightechLevels[key]=0
	g.profile.techPoints[key]=0
	db.config.techPointGet=1e30
	g.advance_hightech(1.0)
	check(absf(float(g.hightech_level(key))-1e15)<10,"1e30 budget remains bounded")
	g.profile.hightechLevels[key]=0
	g.profile.techPoints[key]=0
	db.data.hightech[key].tpCostMutiple=0
	db.config.techPointGet=1e20
	g.advance_hightech(1.0)
	check(g.hightech_level(key)==9000000000000000000,"Flat cost respects integer headroom")
	check(is_finite(float(g.profile.techPoints[key])),"Saturated level keeps finite unspent points")
	g.profile.hightechLevels[key]=0
	g.profile.techPoints[key]=0
	db.data.hightech[key].tpCostBase=100
	g.advance_hightech(1.0)
	check(g.hightech_level(key)==1000000000000000000,"Flat cost bulk division")
	check(NumberFormat.compact(1e20)=="1.00e+20","Threshold uses scientific notation")
	check(NumberFormat.precise(1e30)=="1.00e+30","Large precise display avoids int overflow")
	check(not NumberFormat.compact(INF).is_empty(),"Infinity terminates")
	check(NumberFormat.compact(1234)=="1.2K","Small formatting preserved")
	print("Large-number checks: 11; failures: ",failures,"; 1e20 update usec: ",elapsed)
	quit(failures)
