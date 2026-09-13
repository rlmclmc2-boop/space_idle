extends SceneTree

func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.start(1,false)
	g.profile.unlocked = ["laser","cannon","missile"]
	g.spawn_group()
	for key in g.profile.unlocked:
		g.cooldowns[key] = 10.0
	g.paused = true
	g.tick(0.01)
	assert(g.cooldowns.laser==10.0,"Pause must preserve cooldown")
	g.paused = false
	for enemy in g.enemies:
		enemy.hp = 0
	g.tick(0.01)
	assert(g.state==BattleGame.State.TRAVEL,"Wave completion starts travel")
	for key in g.profile.unlocked:
		assert(is_equal_approx(g.cooldowns[key],float(db.equip(key,1).cd)),"Wave completion resets full interval: "+key)
	g.spawn_group()
	for enemy in g.enemies:
		enemy.equipment = []
	g.tick(0.001)
	for key in g.profile.unlocked:
		assert(not g.projectiles.any(func(p):return p.key==key),"Next encounter must wait: "+key)
		assert(g.cooldowns[key]>0,"Full cooldown counting down: "+key)
	g.begin_retreat()
	g.cooldowns.laser = 10.0
	g.tick(float(db.defaults.deathRetreatDuration))
	assert(g.state==BattleGame.State.TRAVEL and is_equal_approx(g.cooldowns.laser,float(db.equip("laser",1).cd)),"Retreat completion resets full interval")
	g.cooldowns.laser = 10.0
	g.start(1,false)
	assert(is_equal_approx(g.cooldowns.laser,float(db.equip("laser",1).cd)),"Starting a stage resets full interval")
	for key in ["laser","cannon","missile"]:
		var probe := BattleGame.new(db,false)
		probe.profile.unlocked = [key]
		probe.start(1,false)
		var cd := float(db.equip(key,1).cd)
		probe.tick(0.001)
		assert(is_equal_approx(probe.cooldowns[key],cd),"Travel preserves full interval")
		probe.spawn_group()
		for enemy in probe.enemies:
			enemy.equipment = []
		probe.tick(cd*0.99)
		assert(probe.projectiles.is_empty(),"No fire before full interval: "+key)
		var fires: Array = []
		probe.event.connect(func(kind,info):
			if kind=="fire": fires.append(info))
		probe.tick(cd*0.011)
		assert(not fires.is_empty(),"Fire after full interval: "+key)
	print("Travel cooldowns: 22 checks passed")
	quit()
