extends SceneTree

var checks := 0
var failures := 0
var db: ShipDatabase

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",label)

func advance(g: BattleGame, seconds: float) -> void:
	for i in range(int(ceilf(seconds*60))):
		g.tick(1.0/60.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	db = ShipDatabase.new()
	# Mechanics fixtures live only in memory; designers may freely tune the workbook.
	var baseline := [20,24,29,35,42,50,60,72,86,103,124,149,179,215,258,310,372,446,535,642]
	for i in range(20):
		for key in ["laser","cannon"]:
			db.equipment[key][i].dmg = baseline[i]
			db.equipment[key][i].cd = 3
		for key in BattleGame.EQUIPMENT:
			db.equipment[key][i].cost_2 = (i-8)*10 if i>=9 else null
			db.equipment[key][i].res_2 = 2 if i>=9 else null
	db.equipment.laser_mon[0].cd = 3
	db.equipment["cannon-mon"][0].dmg = null
	db.equipment["cannon-mon"][0].cd = null
	check(db.levels.size()==10,"10 Excel levels")
	check(db.enemies["5"].health==300,"BOSS uses Excel health 300")
	check(db.equip("cannon",1).dmg==20 and db.equip("cannon",1).cd==3,"Cannon uses Excel 20 / 3")
	check(db.config.autoCollectReduce==0.5,"Excel auto collect loss 50%")
	var retreat_probe := BattleGame.new(db,false)
	retreat_probe.start(1,false)
	var saved_back_range := float(db.config.backRange)
	db.config.backRange = 125
	retreat_probe.distance = 900
	retreat_probe.begin_retreat()
	check(retreat_probe.retreat_target==775,"Retreat reads config backRange instead of legacy defaults")
	db.config.backRange = 0
	retreat_probe.begin_retreat()
	check(retreat_probe.retreat_target==900,"Zero backRange preserves distance")
	db.config.backRange = saved_back_range
	check(db.enemy_weapon("laser_mon").dmg==db.equip("laser_mon",1).dmg,"Enemy weapon uses its own base row")
	check(db.enemy_weapon("cannon-mon").dmg==20,"Enemy cannon blank fallback")
	check(is_equal_approx(db.ratio(2,0.5,"lifeRatio"),1.085),"Within-stage interpolation")
	var g := BattleGame.new(db,false)
	g.rng.seed = 42
	check(g.profile.unlocked.has("laser") and not g.profile.unlocked.has("missile"),"Starting equipment")
	check(not g.start(2,false),"Locked stage rejected")
	check(g.start(1,false),"Start level 1")
	advance(g,4.9)
	check(g.state==BattleGame.State.TRAVEL and g.distance<100,"Cruise at 20 units/s")
	advance(g,0.2)
	check(g.state==BattleGame.State.COMBAT and is_equal_approx(g.distance,100),"Encounter at 10%, travel stops")
	check(g.enemies.size()==2 and g.enemies[0].slot==4 and g.enemies[1].slot==5,"Excel slot formation")
	advance(g,7)
	check(g.enemies.any(func(e):return e.hp<e.max_hp),"Laser projectile hits")
	check(g.player.armour<100,"Enemy fire damages player")
	check(is_equal_approx(g.distance,100),"No movement during combat")
	g.paused = true
	var before := float(g.player.armour)
	advance(g,8)
	check(g.player.armour==before,"Pause freezes simulation")
	g.paused = false
	check(g.reduced_damage(5,1,1)==3 and g.reduced_damage(0.2,2,2)==1,"Resistance, ceil, min 1")
	g.player.shield = 10
	g.player.armour = 100
	g.hit_player(30,1)
	check(g.player.shield==0 and g.player.armour==90,"Shield overflow uses remaining raw damage")
	g.player.shield = 5
	g.player.armour = 100
	g.hit_player(15,2)
	check(g.player.shield==0 and g.player.armour==95,"Physical overflow armour resistance")
	g.profile.cleared=[1,2]
	g.rebuild_unlocks()
	g.start(1,false)
	var shield_probe := BattleGame.new(db,false)
	shield_probe.profile.cleared = [1,2]
	shield_probe.rebuild_unlocks()
	shield_probe.start(1,false)
	# Isolate regeneration from encounters during the configured delay.
	shield_probe.group_index = db.levels[0].groups.size()
	shield_probe.player.shield = 0
	shield_probe.since_hit = 0
	var shield_row := db.equip("shield",1)
	var shield_delay := float(shield_row.para3)
	var shield_rate := shield_probe.max_shield() * float(shield_row.para2)
	advance(shield_probe,maxf(0,shield_delay-0.1))
	check(shield_probe.player.shield==0,"Shield waits for configured delay")
	# Start exactly at the delay boundary to measure one full second of recovery.
	shield_probe.since_hit = shield_delay
	advance(shield_probe,1)
	check(is_equal_approx(shield_probe.player.shield,minf(shield_probe.max_shield(),shield_rate)),"Shield regenerates at configured rate")
	shield_probe.hit_player(1,1)
	var shield_after_hit := float(shield_probe.player.shield)
	advance(shield_probe,maxf(0,shield_delay-0.1))
	check(shield_probe.player.shield==shield_after_hit,"Hit restarts shield delay")
	shield_probe.player.shield = shield_probe.max_shield()-0.01
	shield_probe.since_hit = shield_delay
	advance(shield_probe,1)
	check(shield_probe.player.shield==shield_probe.max_shield(),"Shield recovery caps at maximum")
	g.drops=[{"uid":10,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":1.0}]
	g.profile.resources["1"]=0.0
	g.collect_near(Vector2(500,300))
	check(g.profile.resources["1"]==1 and g.drops.is_empty(),"Hover collects full amount")
	g.drops=[{"uid":11,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":1.0}]
	g.leave(BattleGame.State.UPGRADE)
	check(g.profile.resources["1"]==2,"Exit rounds final auto collection up")
	g.drops=[{"uid":12,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":1.0}]
	advance(g,5.1)
	check(g.profile.resources["1"]==3 and g.drops.is_empty(),"Timed pickup rounds each final collection up")
	var resources := BattleGame.new(db,false)
	resources.profile.resources["1"] = 0
	var collected: Array[Dictionary] = []
	resources.event.connect(func(kind, info):
		if kind == "collect":
			collected.append(info))
	var resource_enemy := {"hp":1.0,"armourType":0,"x":500.0,"y":300.0,"res_ratio":1.1,"drops":[{"resourceId":1,"amount":3.0,"chance":1.0}]}
	resources.hit_enemy(resource_enemy,10,1)
	check(resources.drops[0].amount==4,"Drop rounds after multiplier: ceil(3 * 1.1)")
	var original_loss = db.config.autoCollectReduce
	db.config.autoCollectReduce = 0.4
	resources.collect(resources.drops[0],false)
	db.config.autoCollectReduce = original_loss
	check(resources.profile.resources["1"]==3 and resources.run_resources["1"]==3 and collected[0].amount==3,"Auto loss rounds independently and display matches credit: ceil(4 * 0.6)")
	resources.drops=[{"uid":99,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":4.0}]
	resources.collect(resources.drops[0],true)
	check(resources.profile.resources["1"]==7 and resources.run_resources["1"]==7 and collected[1].amount==4,"Manual collection credits the displayed integer drop")
	var original_cost = db.equipment.laser[1].cost_1
	db.equipment.laser[1].cost_1 = 3.2
	resources.profile.resources["1"] = 3
	check(resources.upgrade_cost("laser")["1"]==4 and not resources.can_upgrade("laser"),"Fractional final cost rounds up for affordability")
	resources.profile.resources["1"] = 5
	check(resources.upgrade("laser") and resources.profile.resources["1"]==1,"Upgrade deducts the same rounded cost")
	db.equipment.laser[1].cost_1 = original_cost
	var original_start = db.defaults.startingIron
	db.defaults.startingIron = 1.2
	check(resources.fresh_profile().resources["1"]==2,"Starting resources round up")
	db.defaults.startingIron = original_start
	check(not g.can_upgrade("laser"),"Insufficient resources reject upgrade")
	g.profile.resources["1"]=120
	check(g.upgrade("laser") and g.stat("laser")==24 and g.profile.resources["1"]==0,"Upgrade applies next Excel row and cost")
	g.profile.levels.laser=9
	check(g.upgrade_cost("laser")["2"]==10,"Level 10 titanium cost")
	g.profile.levels.laser=20
	check(not g.can_upgrade("laser"),"Level cap")
	# Only missiles retarget after their original target dies.
	for key in ["laser", "cannon", "missile"]:
		var tracking := BattleGame.new(db,false)
		tracking.start(1,false)
		tracking.spawn_group()
		tracking.profile.unlocked = []
		for enemy in tracking.enemies:
			enemy.equipment = []
		var original := tracking.targets()[0]
		var survivor := tracking.targets()[1]
		var hp_before := float(survivor.hp)
		tracking.fire(tracking.player, original, db.equip(key,1), 1, false, key)
		var shot := tracking.projectiles[0]
		var initial_direction: Vector2 = shot.direction
		original.hp = 0
		tracking.tick(0.001)
		if key == "missile":
			check(tracking.projectiles.size()==1 and shot.target.uid==survivor.uid,"Missile retargets living enemy")
			survivor.hp = 0
			tracking.tick(0.001)
			check(tracking.projectiles.has(shot) and shot.target.is_empty(),"Missile flies on when no living target remains")
		else:
			check(tracking.projectiles.has(shot) and shot.target.is_empty() and shot.direction==initial_direction and survivor.hp==hp_before,key+" keeps its trajectory without retargeting")
			tracking.profile.unlocked = [key]
			tracking.cooldowns[tracking.slot_id("weapons",tracking.first_weapon_index(key))] = 0
			tracking.tick(0.001)
			check(tracking.projectiles.size()==2 and tracking.projectiles[1].target.uid==survivor.uid,key+" selects living enemy on next fire")
		var last_position := Vector2(shot.x,shot.y)
		var last_direction: Vector2 = shot.direction
		tracking.tick_projectiles(0.1)
		check(Vector2(shot.x,shot.y).is_equal_approx(last_position+last_direction*shot.speed*0.1),key+" flies straight after target loss")
		tracking.tick_projectiles(100)
		check(not tracking.projectiles.has(shot),key+" removed only after leaving screen")
	# A dead shooter and wave/level completion must not erase in-flight shots.
	for boss_wave in [false]:
		var lingering := BattleGame.new(db,false)
		lingering.start(1,false)
		lingering.spawn_group()
		lingering.profile.unlocked = []
		var shooter := lingering.enemies[0]
		shooter.boss = boss_wave
		lingering.fire(shooter,lingering.player,db.equip("laser",1),1,true,"laser_mon")
		var enemy_shot := lingering.projectiles[0]
		for enemy in lingering.enemies:
			enemy.hp = 0
		lingering.tick(0.001)
		check(lingering.projectiles.has(enemy_shot),"Dead shooter projectile survives wave end: "+str(boss_wave))
		var previous_x := float(enemy_shot.x)
		lingering.tick(0.001)
		check(enemy_shot.x < previous_x,"Enemy projectile moves after wave end: "+str(boss_wave))
		var armour_before := float(lingering.player.armour)
		enemy_shot.x = lingering.player.x + 0.01
		enemy_shot.y = lingering.player.y
		lingering.tick(0.001)
		check(lingering.player.armour < armour_before and not lingering.projectiles.has(enemy_shot),"Dead shooter projectile still hits player: "+str(boss_wave))
	var death_flight := BattleGame.new(db,false)
	death_flight.start(1,false)
	death_flight.spawn_group()
	death_flight.fire(death_flight.enemies[0],death_flight.player,db.equip("laser",1),1,true,"laser_mon")
	var orphan := death_flight.projectiles[0]
	death_flight.hit_player(99999,1)
	death_flight.tick(0.01)
	check(death_flight.projectiles.has(orphan) and orphan.target.is_empty(),"Player death preserves enemy projectile in straight flight")
	# Missile salvo must select distinct living targets and respect count.
	g.start(2,false)
	g.group_index=1
	g.spawn_group()
	g.tick(0.01)
	var missiles := g.projectiles.filter(func(p):return p.key=="missile")
	check(missiles.size()==3,"Missile fires at most three")
	check(missiles[0].target.uid!=missiles[1].target.uid and missiles[1].target.uid!=missiles[2].target.uid,"Distinct missile targets")
	# Full authentic combat path with upgraded equipment, without forced kills.
	var full := BattleGame.new(db,false)
	full.rng.seed=7
	full.profile.levels.armour=20
	full.profile.levels.laser=20
	full.start(1,false)
	for i in range(60000):
		full.tick(1.0/60.0)
		if full.state in [BattleGame.State.LEVEL_CLEAR,BattleGame.State.DEFEAT]:
			break
	check(full.state==BattleGame.State.LEVEL_CLEAR,"Complete travel, 8 waves, BOSS, clear")
	check(full.distance==900 and full.group_index==9,"Clear immediately at BOSS")
	check(full.profile.highestLevel==2 and full.profile.unlocked.has("missile"),"Unlock level 2 and missile")
	check(full.drops.any(func(d):return d.id=="2"),"Boss titanium guaranteed")
	check(full.pending_unlocks==["missile"],"First clear creates only newly unlocked equipment popup")
	advance(full,8)
	check(full.state==BattleGame.State.LEVEL_CLEAR,"Unlock popup holds automatic progression")
	full.acknowledge_unlocks()
	full.profile.loop=true
	advance(full,6.1)
	check(full.state==BattleGame.State.TRAVEL and full.group_index==0,"Loop restarts stage")
	check(full.profile.resources["2"]==5,"Boss 10 titanium × auto 50% (no invented clear reward)")
	full.hit_player(99999,1)
	check(full.state==BattleGame.State.RETREAT,"Armour zero starts retreat")
	advance(full,1.2)
	check(full.distance==0 and full.player.armour==full.stat("armour"),"Retreat clamps to zero and restores health")
	full.distance=900
	full.hit_player(99999,1)
	check(full.retreat_target==600 and full.enemies.is_empty(),"Boss death retreats 300 and clears enemies")
	advance(full,1.2)
	check(full.distance==600 and full.group_index==5,"Retreat rewinds encounter index to target position")
	full.tick(0.02)
	check(full.state==BattleGame.State.COMBAT and full.group_index==6,"Encounter at retreat destination is replayed")
	full.profile.resources["1"]=1000
	full.profile.levels.laser=1
	full.player.armour=500
	var cd_before := float(full.cooldowns.get("weapons_0",0))
	check(full.upgrade("laser") and full.stat("laser")==24,"Direct in-combat upgrade")
	check(full.player.armour==500 and full.cooldowns.get("weapons_0",0)==cd_before,"Weapon upgrade preserves life and cooldown")
	full.profile.levels.armour=1
	full.player.armour=30
	full.upgrade("armour")
	check(full.player.armour==50,"Armour upgrade adds only capacity delta")
	# All 10 configurations remain playable at max equipment.
	for n in range(2,11):
		full.profile.highestLevel=n
		for key in BattleGame.EQUIPMENT:
			full.profile.levels[key]=20
		full.start(n,false)
		for i in range(60000):
			full.tick(1.0/60.0)
			if full.state in [BattleGame.State.LEVEL_CLEAR,BattleGame.State.DEFEAT]:
				break
		check(full.state==BattleGame.State.LEVEL_CLEAR,"Complete stage %d" % n)
	check(full.profile.unlocked.has("shield") and full.profile.unlocked.has("cannon"),"Shield and cannon unlocked")
	# A real save/load round-trip, in redirected test-only user directory.
	full.save_enabled=true
	full.profile.resources["1"]=123.5
	full.save_progress()
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.resources["1"]==124 and loaded.profile.cleared.size()==10,"Legacy fractional save rounds resources up on load")
	loaded.save_progress()
	check(BattleGame.new(db,true).profile.resources["1"]==124,"Integer resources survive save/load unchanged")
	# Native direct gameplay: no selection or equipment-management screen.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.db = db
	scene.game = BattleGame.new(db,false)
	scene.game.event.connect(scene.on_event)
	scene.game.save_enabled=false
	scene.game.profile=scene.game.fresh_profile()
	scene.game.start(1,false)
	await process_frame
	check(scene.game.state==BattleGame.State.TRAVEL,"Launch directly into gameplay")
	check(scene.upgrade_buttons.size()==2 and scene.upgrade_buttons.has("armour") and scene.upgrade_buttons.has("laser"),"Only unlocked equipment visible")
	scene.game.profile.resources["1"]=1000
	scene.game.player.armour=60
	scene.upgrade_buttons.laser.pressed.emit()
	check(scene.game.stat("laser")==24 and scene.game.player.armour==60,"Actual direct upgrade button applies stats without healing")
	for child in scene.ui.get_children():
		if child is Button:
			check(not ("船坞" in child.text or "航区" in child.text or "解锁" in child.text),"No obsolete or locked controls")
	scene.game.clear_level()
	await process_frame
	check(scene.game.pending_unlocks==["missile"],"Native unlock modal")
	for child in scene.ui.get_children():
		if child is Button and child.text=="继续":
			child.pressed.emit()
	await process_frame
	check(scene.upgrade_buttons.size()==3 and scene.upgrade_buttons.has("missile"),"New equipment appears after acknowledgment")
	advance(scene.game,6.1)
	check(scene.game.stage==2 and scene.game.state==BattleGame.State.TRAVEL,"Auto advances to next level without loop")
	scene.game.clear_level()
	check(scene.game.pending_unlocks==["shield","cannon"],"Multiple newly unlocked equipment in one popup")
	scene.game.acknowledge_unlocks()
	scene.game.start(1,false)
	scene.game.clear_level()
	check(scene.game.pending_unlocks.is_empty(),"Replayed clears do not repeat unlock popup")
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.fire(scene.game.player,scene.game.enemies[0],db.equip("laser",1),1,false,"laser")
	var visible_orphan: Dictionary = scene.game.projectiles.back()
	for enemy in scene.game.enemies:
		enemy.hp = 0
	scene.game.tick(0.001)
	scene.queue_redraw()
	await process_frame
	await process_frame
	check(scene.game.projectiles.has(visible_orphan) and visible_orphan.target.is_empty(),"Scene renders projectile without a target")
	scene.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
