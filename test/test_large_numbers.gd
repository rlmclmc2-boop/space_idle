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
	# Retired scientist bulk-cost arithmetic is no longer a game rule.
	# Retain current large-number formatting and expression rejection coverage.
	check(NumberFormat.compact(1e20)=="100Qi","Large quantity stays on the suffix ladder")
	check(NumberFormat.compact(1e33)=="1e+33","Beyond the suffix ladder uses scientific notation")
	check(NumberFormat.precise(1e30)=="1.00e+30","Large precise display avoids int overflow")
	check(not NumberFormat.compact(INF).is_empty(),"Infinity terminates")
	check(NumberFormat.compact(1234)=="1.23K","Small formatting preserved")
	for income in [9e19,1e20,2.612345e25,1e100]:
		var row := {"para1":0.02}
		var actual := g.format_description(row,"{过去一分钟的铁生成量*para1*lv,向上取整,不含自身}",185,0,income)
		check(actual==NumberFormat.compact(ceilf(income*0.02*185)),"Large income formulas display computed yield instead of question mark: "+str(income))
	check(g.format_description({"para1":2e20},"{para1^2}",1)==NumberFormat.compact(4e40),"Scientific literal can be a power base")
	check(g.format_description({},"{1e-3*1E3+1/2}",1)=="1.5","Scientific exponents and floating division remain valid")
	for formula in ["{1e+}","{1efoo}","{sin(1)}"]:
		check(g.format_description({},formula,1)=="？","Malformed numeric tokens and arbitrary functions remain rejected")
	print("Large-number checks: ",checks,"; failures: ",failures)
	quit(failures)
