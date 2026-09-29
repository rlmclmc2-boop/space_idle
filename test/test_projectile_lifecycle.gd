extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	# Player and enemy non-missile rounds must not steer toward a moving target.
	for hostile in [false,true]:
		for key in ["laser","cannon","missile"]:
			var moving := BattleGame.new(db,false)
			moving.start(1,false)
			moving.spawn_group()
			var source: Dictionary=moving.enemies[0] if hostile else moving.player
			var target: Dictionary=moving.player if hostile else moving.enemies[0]
			source.x=200.0
			source.y=500.0 if not hostile else 100.0
			target.x=200.0
			target.y=100.0 if not hostile else 500.0
			moving.fire(source,target,db.equip(key,1),1.0,hostile,key+"-mon" if hostile else key)
			var shot: Dictionary=moving.projectiles.back()
			var direction: Vector2=shot.direction
			shot.speed=100.0
			target.x+=80.0
			var health: float=target.armour if hostile else target.hp
			moving.tick_projectiles(0.1)
			check(shot.direction!=direction if key=="missile" else shot.direction==direction,key+" moving target steering, hostile="+str(hostile))
			if key!="missile":
				moving.tick_projectiles(4.0)
				check((target.armour if hostile else target.hp)==health,key+" misses a target that left the straight segment")
				check(is_equal_approx(float(shot.x),200.0),key+" retains launch ray through the complete flight")
	# Only missiles retarget after their original target dies.
	for key in ["laser", "cannon", "missile"]:
		var tracking := BattleGame.new(db,false)
		tracking.start(1,false)
		tracking.spawn_group()
		# Exactly two targets are required by the no-survivor boundary below.
		tracking.enemies.resize(2)
		tracking.profile.unlocked = [key]
		tracking.profile.loadout = tracking.empty_loadout(tracking.profile.selectedShip)
		check(tracking.equip_slot("weapons",0,key),key+" fixture installs its weapon")
		tracking.cooldowns.weapons_0 = 10
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
			tracking.cooldowns.weapons_0 = 0
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
		var previous_position := Vector2(enemy_shot.x,enemy_shot.y)
		lingering.tick(0.001)
		check(Vector2(enemy_shot.x,enemy_shot.y).is_equal_approx(previous_position+Vector2(enemy_shot.direction)*float(enemy_shot.speed)*0.001),"Enemy projectile follows its launch ray after wave end: "+str(boss_wave))
		var armour_before := float(lingering.player.armour)
		var impact_position := Vector2(lingering.player.x,lingering.player.y)-Vector2(enemy_shot.direction)*0.01
		enemy_shot.x = impact_position.x
		enemy_shot.y = impact_position.y
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
	print("Projectile lifecycle: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
