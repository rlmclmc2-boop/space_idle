extends SceneTree
class SharedObservedGame extends "res://scripts/presented_battle_game.gd":
	var shared_calls:=0
	func advance_shared_clock_and_economy(dt:float)->void:
		shared_calls+=1
		super.advance_shared_clock_and_economy(dt)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func world()->Dictionary:
	return {"rng_state":417,"player":{"armour":100.0,"shield":10.0,"x":50.0,"y":0.0},"enemies":[{"uid":100,"slot":0,"x":100.0,"y":0.0,"hp":100.0,"max_hp":100.0,"compiled_drops":[{"resource":1,"chance":1.0,"base":1.0,"amount":1.0}]}],"weapons":[{"kind":0,"type":1,"slot":0,"source":-1,"damage":1.0,"factor":1.0,"interval":1.0,"speed":100.0,"entry":{"key":"laser"},"row":{}}],"defences":[{"layer":1,"type":0,"base":100.0,"factor":1.0,"maximum":100.0}]}
func _initialize()->void:call_deferred("run")
func run()->void:
	var k=ClassDB.instantiate("SpaceCombatKernel")
	check(k!=null,"actual native class")
	var d=world()
	check(k.configure(d),"baseline admission")
	k.advance(0.01)
	var before=k.export_handoff();var rng=k.rng_source().state
	for path in ["drop","defence","weapon","player"]:
		var bad=world()
		if path=="drop":bad.enemies[0].compiled_drops[0].amount={"m":1.0,"e":400}
		if path=="defence":bad.defences[0].loss={"m":1.0,"e":400}
		if path=="weapon":bad.weapons[0].speed="100"
		if path=="player":bad.player.armour=true
		check(not k.configure(bad),path+" rejects before replacing owner")
		check(k.export_handoff()==before and k.rng_source().state==rng,path+" preserves state and RNG")
	for path in ["counter","capacity","memory","drop_sum","deferred_portions","enum"]:
		var bad=world()
		if path=="counter":bad.counter_growth=1e308;bad.counter_level=1e308
		if path=="capacity":bad.defences[0].base=1e308;bad.defences[0].factor=1e308
		if path=="memory":bad.defences[0].memory_cap=1e308
		if path=="drop_sum":bad.deferred={1:{"shield":1e308,"armour":0.0},2:{"shield":1e308,"armour":0.0}}
		if path=="deferred_portions":bad.deferred_duration=1e308
		if path=="enum":bad.weapons[0].type=3
		check(not k.can_update_configuration(bad) and not k.update_configuration(bad),path+" rejects whole update")
		check(k.export_handoff()==before and k.rng_source().state==rng,path+" leaves CD/instances/RNG untouched")
	check(not k.can_advance(1e308) and not k.advance(1e308),"runtime rejects unsafe untouched step")
	check(k.export_handoff()==before and k.rng_source().state==rng,"runtime rejection preserves complete owner")
	var sentinel=world();sentinel.rng_state=-1;sentinel.weapons[0].charge=-1.0;sentinel.defences[0].last_hit=-100.0
	check(k.configure(sentinel),"signed RNG and time/charge sentinels remain legal")
	var moving=world();moving.enemies[0].x=2.0;moving.weapons[0].remaining=0.0;moving.weapons[0].damage=10.0;moving.weapons[0].muzzle=Vector2.ZERO
	check(k.configure(moving),"moving-target admission");k.advance(0.01)
	k.input_geometry(PackedVector2Array([Vector2(2,10)]),PackedVector2Array([Vector2.ZERO]));k.advance(0.03)
	check(float(k.enemy_views()[0].hp)==100.0,"straight shot does not hit its target's old visible point")
	var enemy=world();enemy.weapons=[{"kind":2,"hostile":true,"source":0,"slot":0,"damage":1.0,"interval":10.0,"remaining":0.0,"speed":100.0,"muzzle":Vector2(100,0)}]
	check(k.configure(enemy),"hostile missile admission");k.advance(0.01)
	k.input_player_point(Vector2(100,20));k.advance(0.05)
	var missile=k.projectile_views()[0]
	check(k.projectile_views().size()==1 and absf(float(missile.speed)-100.0)<0.001,"enemy missile retains table speed")
	check(Vector2(missile.motion_lease.direction()).y>0.99,"enemy missile tracks current player point")
	var periodic=world();periodic.player.armour=1e8;periodic.weapons=[{"kind":3,"hostile":true,"source":0,"slot":0,"damage":1.0,"interval":0.2,"remaining":0.0,"speed":1.0,"charge":-1.0}]
	check(k.configure(periodic),"continuous deadline fixture admission")
	var elapsed_valid=true
	for step in range(200):
		k.advance(1.0/60.0)
		elapsed_valid=elapsed_valid and float(k.metrics().since_hit)>=0 and float(k.export_handoff().since_hit)>=0
	check(elapsed_valid,"eligible rounded deadlines never publish a negative elapsed since_hit")
	var chain=world();chain.weapons[0].muzzle=Vector2.ZERO;chain.chain_speed=37.0;chain.weapons[0].chain_count=1;chain.weapons[0].remaining=0.0;chain.weapons[0].damage=10.0;chain.enemies[0].slot=4;chain.enemies[0].hp=1.0;chain.enemies[0].max_hp=1.0
	chain.enemies.append({"uid":101,"slot":1,"x":200.0,"y":0.0,"hp":100.0,"max_hp":100.0})
	check(k.configure(chain),"configured chain speed admission");k.advance(0.01);k.advance(1.0)
	var hops=k.projectile_views().filter(func(p):return bool(p.get("chain_hop",false)))
	check(not hops.is_empty() and absf(float(hops[0].motion_lease.speed())-37.0)<0.001,"native chain uses table motion speed")
	var g=SharedObservedGame.new(ShipDatabase.new(),false);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}];g.stat_cache_enabled=true;g.invalidate_stat_cache();g.save_enabled=false
	g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	desc.attack_counter=9007199254740990.0
	check(g.admit_native_execution(desc),"actual Game boundary fixture admission")
	var shared_before=g.shared_calls;var before_clock=g.enemy_shield_time
	g.tick(1.0/60.0)
	check(g.native_execution==null and g.native_handoff_count==1,"numeric growth transfers whole encounter before combat")
	check(g.shared_calls==shared_before+1 and is_equal_approx(g.enemy_shield_time-before_clock,1.0/60.0) and g.native_step_remaining==0.0,"fallback consumes shared economy and combat step exactly once")
	g.begin_retreat()
	var cold=SharedObservedGame.new(ShipDatabase.new(),false);cold.profile.unlocked=BattleGame.EQUIPMENT.duplicate();cold.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
	cold.stat_cache_enabled=true;cold.invalidate_stat_cache();cold.save_enabled=false;cold.reset_player();cold.state=BattleGame.State.COMBAT
	cold.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	cold.profile.enhancementAttacks=9007199254740990;cold.native_execution_requested=true;cold.native_execution_scope="native_low_contract";cold.motion_clock=100.0
	cold.tick(1.0/60.0)
	check(cold.native_execution==null and cold.native_handoff_count==1,"cold admission can safely reject its first combat step")
	check(is_equal_approx(cold.motion_clock,100.0+1.0/60.0) and cold.shared_calls==1 and is_equal_approx(cold.enemy_shield_time,1.0/60.0),"legacy-entry cold fallback restores already advanced endpoint without double clock/shared work")
	cold.begin_retreat()
	print("NATIVE_NUMERIC_RANGE_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
