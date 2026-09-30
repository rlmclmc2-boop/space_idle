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
	var row: Dictionary = db.data.hightech[key]
	for threshold in [int(db.config.hightechCostGrowthLevel),12]:
		db.config.hightechCostGrowthLevel=threshold
		for level in [threshold-1,threshold,threshold+1,threshold+20]:
			g.profile.hightechLevels[key]=level
			var expected := roundf(float(row.tpCostBase)*(1+float(row.tpCostMutiple)*level)*pow(1+float(row.tpCostMutiple2),maxi(0,level-threshold)))
			check(is_equal_approx(g.hightech_required(key),expected),"Configured boundary cost: "+str(level))
		for level in [threshold-1,threshold+1]:
			var expected := 0.0
			for i in range(level,level+50):
				expected += float(row.tpCostBase)*(1+float(row.tpCostMutiple)*i)*pow(1+float(row.tpCostMutiple2),maxi(0,i-threshold))
			check(is_equal_approx(g.hightech_bulk_cost(key,level,50),expected),"Bulk sum crosses configured boundary")
	# Exact normal settlement crosses the threshold and preserves remaining points.
	g.profile.cleared=db.data.hightech.keys().map(func(k):return int(db.unlock_row("hightech",k).level))
	g.profile.scientistAssignments[key]=1
	db.config.techPointGet=1
	g.profile.hightechLevels[key]=11
	g.profile.techPoints[key]=0
	var budget := 0.25
	for level in range(11,15):
		budget += roundf(float(row.tpCostBase)*(1+float(row.tpCostMutiple)*level)*pow(1+float(row.tpCostMutiple2),maxi(0,level-12)))
	g.advance_hightech(budget)
	check(g.hightech_level(key)==15 and is_equal_approx(float(g.profile.techPoints[key]),0.25),"Normal research crosses threshold exactly")
	for ratio in [0.1,0.000000001]:
		row.tpCostMutiple2=ratio
		g.profile.hightechLevels[key]=0
		g.profile.techPoints[key]=1e20
		var start := Time.get_ticks_usec()
		g.advance_hightech_bulk(key,0)
		var level := g.hightech_level(key)
		check(g.hightech_bulk_cost(key,0,level)<=1e20 and g.hightech_bulk_cost(key,0,level+1)>1e20,"Bulk stops at affordable exponential level")
		check(Time.get_ticks_usec()-start<1000000,"Bulk remains bounded with small exponential growth")
		check(is_finite(float(g.profile.techPoints[key])),"Finite remainder")
	print("Hightech cost failures: ",failures)
	quit(failures)
