extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	# Rule fixtures are explicit; no dependency on historical workbook tuning.
	var db := ShipDatabase.new()
	db.config.dmgReduce = 0.5
	db.config.autoCollectReduce = 0.4
	db.equipment.shield[0].dmgtype = 1
	db.equipment.armour[0].dmgtype = 2
	var g := BattleGame.new(db,false)
	check(g.reduced_damage(5,1,1)==3,"Matching resistance rounds damage up")
	check(g.reduced_damage(0.2,2,2)==1,"Reduced damage has minimum one")
	check(g.reduced_damage(2.1,1,2)==3,"Nonmatching resistance still rounds up")
	g.player.shield = 10
	g.player.armour = 100
	g.hit_player(30,1)
	check(g.player.shield==0 and g.player.armour==90,"Shield overflow uses remaining raw damage")
	g.player.shield = 5
	g.player.armour = 100
	g.hit_player(15,2)
	check(g.player.shield==0 and g.player.armour==95,"Physical overflow armour resistance")
	g.player.shield = 10
	g.player.armour = 100
	g.hit_player(20,1)
	check(g.player.shield==0 and g.player.armour==100,"Exact shield absorption does not apply minimum damage to armour")
	var resources := BattleGame.new(db,false)
	resources.profile.resources["1"] = 0
	var collected: Array[Dictionary] = []
	resources.event.connect(func(kind, info):
		if kind == "collect":
			collected.append(info))
	var resource_enemy := {"hp":1.0,"armourType":0,"x":500.0,"y":300.0,"res_ratio":1.1,"drops":[{"resourceId":1,"amount":3.0,"chance":1.0}]}
	resources.hit_enemy(resource_enemy,10,1)
	check(resources.drops[0].amount==4,"Drop rounds after multiplier: ceil(3 * 1.1)")
	resources.collect(resources.drops[0],false)
	check(resources.profile.resources["1"]==3 and resources.run_resources["1"]==3 and collected[0].amount==3,"Auto loss rounds independently and display matches credit: ceil(4 * 0.6)")
	resources.drops=[{"uid":99,"x":500.0,"y":300.0,"age":0.0,"id":"1","amount":4.0}]
	resources.collect(resources.drops[0],true)
	check(resources.profile.resources["1"]==7 and resources.run_resources["1"]==7 and collected[1].amount==4,"Manual collection credits the displayed integer drop")
	db.equipment.laser[1].cost_1 = 3.2
	db.equipment.laser[1].res_2 = null
	db.equipment.laser[1].cost_2 = null
	resources.profile.resources["1"] = 3
	check(resources.slot_upgrade_cost("weapons",0)["1"]==4 and not resources.can_upgrade_slot("weapons",0),"Fractional final cost rounds up for affordability")
	resources.profile.resources["1"] = 5
	check(resources.upgrade_slot("weapons",0) and resources.profile.resources["1"]==1,"Upgrade deducts the same rounded cost")
	db.defaults.startingIron = 1.2
	check(resources.fresh_profile().resources["1"]==2,"Starting resources round up")
	db.levels[0].lifeRatio = 1.1
	db.levels[1].lifeRatio = 1.3
	check(is_equal_approx(db.ratio(2,0.5,"lifeRatio"),1.2),"Within-stage interpolation between adjacent endpoints")
	check(db.ratio(1,0,"lifeRatio")==1.0,"First stage starts at base ratio one")
	check(db.ratio(2,-1,"lifeRatio")==1.1 and db.ratio(2,2,"lifeRatio")==1.3,"Interpolation clamps progress at both endpoints")
	db.equipment.cannon[0].dmg = 20
	db.equipment["cannon-mon"][0].dmg = null
	db.equipment.laser_mon[0].dmg = 7
	check(db.enemy_weapon("laser_mon").dmg==7,"Enemy weapon uses its own base row")
	check(db.enemy_weapon("cannon-mon").dmg==20,"Enemy cannon blank fallback")
	check(db.equipment["cannon-mon"][0].dmg==null,"Fallback read does not fill source configuration")
	print("Rule rounding: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
