# Historical mixed probe; not a current acceptance suite (TODO U-017).
# See TEST_MAP.md for independently verified rule tests.
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
	# Damage/overflow assertions migrated to test_rule_rounding.gd.
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
	# Staged rounding and cost assertions migrated to test_rule_rounding.gd.
	check(not g.can_upgrade("laser"),"Insufficient resources reject upgrade")
	g.profile.resources["1"]=120
	check(g.upgrade("laser") and g.stat("laser")==24 and g.profile.resources["1"]==0,"Upgrade applies next Excel row and cost")
	g.first_equipment_entry("laser").level=9
	check(g.upgrade_cost("laser")["2"]==10,"Level 10 titanium cost")
	g.first_equipment_entry("laser").level=20
	check(not g.can_upgrade("laser"),"Level cap")
	# Projectile lifecycle assertions migrated to test_projectile_lifecycle.gd.
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
	full.first_equipment_entry("armour").level=20
	full.first_equipment_entry("laser").level=20
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
	full.first_equipment_entry("laser").level=1
	full.player.armour=500
	var cd_before := float(full.cooldowns.get("weapons_0",0))
	check(full.upgrade("laser") and full.stat("laser")==24,"Direct in-combat upgrade")
	check(full.player.armour==500 and full.cooldowns.get("weapons_0",0)==cd_before,"Weapon upgrade preserves life and cooldown")
	full.first_equipment_entry("armour").level=1
	full.player.armour=30
	full.upgrade("armour")
	check(full.player.armour==50,"Armour upgrade adds only capacity delta")
	# All 10 configurations remain playable at max equipment.
	for n in range(2,11):
		full.profile.highestLevel=n
		for key in BattleGame.EQUIPMENT:
			full.first_equipment_entry(key).level=20
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
