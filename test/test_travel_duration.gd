extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func arrive(g: BattleGame, label: String, dt := 1.0/60.0) -> float:
	var seconds := 0.0
	while g.state==BattleGame.State.TRAVEL and seconds<4.0:
		g.tick(dt);seconds+=dt
	check(g.state==BattleGame.State.COMBAT and seconds<=3.000001,label)
	return seconds
func run() -> void:
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.profile.highestLevel=g.db.levels.size()
	# Validate every authored segment/hull, including lengths above the early stages.
	for ship in g.db.ships:
		g.profile.selectedShip=ship
		for index in g.db.levels.size():
			g.stage=index+1
			var previous:=0.0
			for node in g.db.levels[index].groups.size():
				g.group_index=node;g.distance=previous;g.travel_origin=previous
				var destination:=float(g.db.levels[index].groups[node].position)*float(g.db.levels[index].length)
				check((destination-previous)/g.travel_movement()<=3.000001,"All stages and hulls cap each forward segment")
				previous=destination
	for stage in [1,5,20,60,g.db.levels.size()]:
		g.start(stage,false);arrive(g,"First encounter")
		g.enemies.clear();g.change_state(BattleGame.State.TRAVEL)
		arrive(g,"Between encounters")
		g.begin_retreat()
		var elapsed:=0.0
		while g.state==BattleGame.State.RETREAT and elapsed<4:
			g.tick(1.0/60.0);elapsed+=1.0/60.0
		check(elapsed<=3.000001,"Retreat is capped")
		arrive(g,"Failure retry including previous-stage boss")
	g.start(1,false);g.toggle_loop();arrive(g,"Travel to guard point")
	check(g.guarding_here() and g.guard_interval()<=3.0,"Guard cadence cannot conceal long travel wait")
	for mode in [0,1,2]:
		g.start(2,false);g.spawn_group();g.toggle_loop();g.set_guard_death(mode);g.begin_retreat()
		g.tick(1.2)
		if g.state==BattleGame.State.TRAVEL:arrive(g,"Guard death mode %d"%mode)
		check(g.guard_interval()<=3.0,"Guard return/stay cadence")
	g.start(1,false);g.paused=true;g.tick(10)
	check(g.distance==0.0,"Pause freezes travel")
	g.paused=false;g.speed=10
	var x1:=arrive(g,"X10 consumes game time once",1.0/60.0)
	check(is_equal_approx(x1,3.0) and is_equal_approx(x1/g.speed,0.3),"X10 travel uses 3 X1 seconds, 0.3 real seconds")
	g.db.ships[g.profile.selectedShip].movement=1000
	g.start(1,false)
	check(arrive(g,"Already-fast hull retains shorter duration")<1.0,"No minimum wait added")
	g.db.ships[g.profile.selectedShip].movement=0.01
	g.db.levels[0].length=1e9
	g.start(1,false);arrive(g,"Extreme distance/slow hull")
	g.start(1,false,{"distance":1e8,"groupIndex":0,"state":BattleGame.State.TRAVEL,"retreatBossPending":false})
	arrive(g,"Restored travel checkpoint uses remaining distance")
	g.db.defaults.deathRetreatDuration=100
	g.begin_retreat();g.tick(3.0)
	check(g.state!=BattleGame.State.RETREAT,"Configured retreat above cap cannot exceed 3 seconds")
	print("Travel duration: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
