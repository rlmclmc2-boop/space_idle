extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
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
	db.data.hightech[key].tpCostMutiple2 = 0.0
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
	for income in [9e19,1e20,2.612345e25,1e100]:
		var row := {"para1":0.02}
		var actual := g.format_description(row,"{过去一分钟的铁生成量*para1*lv,向上取整,不含自身}",185,0,income)
		check(actual==NumberFormat.compact(ceilf(income*0.02*185)),"Large income formulas display computed yield instead of question mark: "+str(income))
	check(g.format_description({"para1":2e20},"{para1^2}",1)==NumberFormat.compact(4e40),"Scientific literal can be a power base")
	check(g.format_description({},"{1e-3*1E3+1/2}",1)=="1.5","Scientific exponents and floating division remain valid")
	for formula in ["{1e+}","{1efoo}","{sin(1)}"]:
		check(g.format_description({},formula,1)=="？","Malformed numeric tokens and arbitrary functions remain rejected")
	for furnace in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE]:
		g.profile.hightechLevels[furnace]=185
		var description := g.ui_description(UIText.data_key("hightech",furnace,"description"),db.data.hightech[furnace],185,2.6e25,2.6e25)
		check(not description.contains("？") and description.contains("e+"),"Both furnace descriptions support large income: "+furnace)
	print("Large-number checks: ",checks,"; failures: ",failures,"; 1e20 update usec: ",elapsed)
	quit(failures)
