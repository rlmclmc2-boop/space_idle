extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():call_deferred("run")
func run():
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.cleared=[1];g.profile.reactorLevel=2500
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.stat_cache_enabled=true;g.invalidate_stat_cache();g.save_enabled=false;g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[{"resourceId":1,"amount":100.0,"chance":1.0}],"res_ratio":1.0}])
 var share=R.div_small(g.reactor_capacity(),4)[0]
 g.set_reactor_allocation("smelting",share)
 var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
 print("DESC ",desc.get("error","ok"))
 var admitted=g.admit_native_execution(desc) if not desc.has("error") else false
 print("ADMIT ",admitted," NATIVE ",g.native_execution!=null," ALLOCATION ",R.digits(g.profile.reactorAllocation.smelting).length())
 g.enemies[0].hp=1.0;g.hit_enemy(g.enemies[0],100000,0)
 var drops=g.drops.filter(func(d):return str(d.get("id",""))=="1")
 print("LEGACY_DROPS ",drops.size()," VALID ",GrowthNumber.valid(drops[0].amount) if drops.size()>0 else false)
 quit(0 if not admitted and g.native_execution==null and drops.size()==1 and GrowthNumber.valid(drops[0].amount) else 1)
