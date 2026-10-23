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
	var N=GrowthNumber
	check(not N.valid({"v":1,"i":"1"+"0".repeat(1000)}),"ordinary growth rejects decimal integer packages")
	for value in [1e-300,1e-10,1.0,1e20,1e300,1e308]:
		var parts:Array=N.parts(value)
		var rebuilt=N.make(parts[0],parts[1])
		check(N.valid(rebuilt) and parts[0]>=1.0 and parts[0]<10.0 and absf(N.ratio(rebuilt,value)-1.0)<1e-12,"finite normalized numeric range "+str(value))
	var huge:Dictionary={"m":2.5,"e":1000.0}
	check(N.add(huge,1)==huge and N.subtract(huge,1)==huge,"subprecision ordinary changes do not allocate decimal digits")
	check(N.compare(N.subtract(huge,huge),0)==0 and N.valid(N.multiply(huge,huge)) and N.valid(N.power(huge,3)),"cancellation, products and powers remain finite representations")
	check(g.economy.credit("1",huge) and g.economy.debit({"1":N.multiply(huge,0.2)}) and absf(N.ratio(g.economy.balance("1"),huge)-0.8)<1e-12,"large ordinary credits and costs share finite arithmetic")
	check(not g.economy.credit("1",{"v":1,"i":"1"+"0".repeat(1000)}),"removed integer resource input cannot reintroduce exact wallet authority")
	var snapshot:Dictionary=g.economy.save_data();var bad:Dictionary=snapshot.duplicate(true);bad.resources["1"]={"v":1,"i":"10000000000000001"}
	check(not g.economy.install_snapshot(bad) and g.economy.save_data()==snapshot,"removed resource shape is rejected before wallet installation")
	check(g.economy.credit("degenerate_matter",9000000000000000-1) and g.economy.debit({"degenerate_matter":1}) and g.economy.balance("degenerate_matter")==9000000000000000-2,"material integer debit remains exact near its domain limit")
	var capacity=N.floor_value(N.make(1.25,400))
	check(N.valid(capacity) and N.parts(capacity)[1]==400 and N.compare(N.parse_input(N.input_text(capacity)),capacity)==0,"capacity directly uses finite growth representation and editable round trip")
	var config:Dictionary=db.config.duplicate(true);config.reactorUpgradeBase=10.0;config.reactorUpgradeGrowth=1.35
	var reactor=g.reactor
	var samples:Array=[1,3,10,100,1000,10000,1000000000]
	var elapsed:=Time.get_ticks_usec()
	for count in samples:
		var price=reactor.purchase_cost(count,config)
		check(N.valid(price) and not (price is Dictionary and price.has("i")),"batch cost has bounded representation "+str(count))
		var quoted:Dictionary=reactor.purchase_quote(count,price,config)
		check(not quoted.is_empty() and quoted.cost==price,"quote accepts its own exact finite representation "+str(count))
		check(reactor.max_upgrades(price,config)==count,"MAX agrees with the same cumulative quote "+str(count))
		check(reactor.purchase_quote(count,N.multiply(price,1.0-1e-8),config).is_empty(),"representably insufficient budget rejects "+str(count))
	print("FINITE_QUOTES elapsed_us=",Time.get_ticks_usec()-elapsed)
	var totals:=0.0
	for count in 100:
		totals+=ceilf(10.0*pow(1.35,count))
		check(reactor.purchase_cost(count+1,config)==totals,"ordinary per-level ceiling remains unchanged "+str(count))
	check(not N.valid(INF) and not N.valid({"m":10.0,"e":300.0}),"nonfinite and unnormalized payloads reject")
	print("Large-number checks: ",checks,"; failures: ",failures)
	quit(failures)
