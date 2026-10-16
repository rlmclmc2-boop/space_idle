extends SceneTree
const CC=preload("res://scripts/combat_context.gd")
const STATS=preload("res://scripts/battle_damage_stats.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func legacy():
	var game=BattleGame.new(ShipDatabase.new(),false)
	game.profile.hightechSavedAt=0
	game.profile.cleared=range(1,41)
	game.rebuild_unlocks();game.pending_unlocks.clear()
	game.profile.loadout={"weapons":[{"key":"laser","level":50}],"defence":[{"key":"armour","level":50},{"key":"shield","level":50}]}
	game.reset_player();game.spawn_group();game.state=BattleGame.State.COMBAT
	return game

func native_world(drone:bool=false)->Dictionary:
	var weapon={"kind":0,"type":1,"slot":0,"source":0,"hostile":false,"damage":100.0,"interval":10.0,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":"laser"},"row":{"cd":10.0,"para1":1.0,"para2":1.0,"para3":0.0}}
	if drone:weapon.entry.drone_id="test-drone"
	return {"clock":0.0,"rng_state":418,"resistance":0.0,"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0,"armour_type":2,"shield_type":1},"enemies":[{"uid":100,"slot":4,"x":30.0,"y":0.0,"hp":5.0,"max_hp":5.0,"armourType":2,"shieldType":1,"shield":3.0,"max_shield":3.0}],"weapons":[weapon]}

func _initialize()->void:call_deferred("run")

func run()->void:
	var stats=STATS.new()
	stats.record("module:0",10)
	check(stats.buckets.is_empty() and stats.totals.is_empty(),"disabled creates no buckets")
	stats.set_enabled(true);stats.advance(0.5)
	stats.record("module:0",10);stats.record("drone:a",20)
	check(N.compare(stats.total,30)==0 and is_equal_approx(stats.snapshot().dps,60),"window total and denominator")
	stats.advance(8)
	check(stats.totals.is_empty() and stats.buckets.size()==stats.COUNT,"window releases expired damage")
	stats.record("module:0",{"m":1.0,"e":200})
	check(N.compare(stats.total,{"m":1.0,"e":200})==0,"growth number remains exact in ledger")
	stats.set_enabled(false)
	check(stats.buckets.is_empty() and stats.totals.is_empty(),"closing releases buckets")

	var game=legacy();game.set_damage_stats_enabled(true);game.db.config.dmgReduce=0.5
	var enemy:Dictionary=game.enemies[0]
	enemy.hp=100;enemy.max_hp=100;enemy.shield=50;enemy.max_shield=50;enemy.shieldType=1;enemy.armourType=2;enemy.shieldRecovery=0
	game.hit_enemy(enemy,100,1,[],false,CC.root(1,"module:0","laser"))
	check(N.compare(game.damage_stats.total,50)==0,"shield records consumed amount only")
	game.hit_enemy(enemy,1000,2,[],false,CC.derive(CC.root(2,"drone:test-drone","laser"),"secondary"))
	check(N.compare(game.damage_stats.total,150)==0 and N.compare(game.damage_stats.totals.get("drone:test-drone",0),100)==0,"health overkill capped and derived drone retained")
	game.hit_enemy(enemy,1000,2,[],false,CC.root(3,"module:0","laser"))
	check(N.compare(game.damage_stats.total,150)==0,"dead target cannot count twice")
	game.paused=true;game.tick(1.0)
	check(game.damage_stats.elapsed==0,"pause stops battle clock")
	game.paused=false;game.tick(1.0/60.0)
	check(is_equal_approx(game.damage_stats.elapsed,1.0/60.0),"logical battle clock advances once")
	game.spawn_group()
	check(game.damage_stats.elapsed==0 and N.compare(game.damage_stats.total,0)==0,"wave resets window")

	check(ClassDB.class_exists("SpaceCombatKernel"),"native extension loaded")
	if ClassDB.class_exists("SpaceCombatKernel"):
		for drone in [false,true]:
			var off=ClassDB.instantiate("SpaceCombatKernel")
			var on=ClassDB.instantiate("SpaceCombatKernel")
			check(off.configure(native_world(drone)) and on.configure(native_world(drone)),"native admission")
			on.set_damage_stats_enabled(true)
			for i in 30:
				off.advance(1.0/60.0);on.advance(1.0/60.0)
			var rows:Array=on.take_damage_stats()
			check(rows.size()==1 and str(rows[0].source)==("drone:test-drone" if drone else "module:0"),"native source")
			if rows.size()==1:check(is_equal_approx(float(rows[0].shield),3.0) and is_equal_approx(float(rows[0].health),5.0),"native actual shield and health")
			check(off.take_damage_stats().is_empty(),"native disabled ledger empty")
			check(off.enemy_views()==on.enemy_views() and off.metrics()==on.metrics() and off.rng_source().state==on.rng_source().state,"native observation leaves battle and RNG unchanged")
			on.set_damage_stats_enabled(false)
			check(on.take_damage_stats().is_empty(),"native close clears pending ledger")
			off.cancel();on.cancel()
	print("Damage statistics: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
