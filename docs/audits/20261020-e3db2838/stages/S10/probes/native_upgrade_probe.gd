extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():call_deferred("run")
func run():
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.cleared=[1]
 g.profile.reactorLevel=2500
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.stat_cache_enabled=true;g.invalidate_stat_cache();g.save_enabled=false;g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
 print("DESC ",desc.get("error","ok"))
 var admitted=g.admit_native_execution(desc) if not desc.has("error") else false
 print("ADMIT ",admitted)
 if admitted:
  g.profile.resources["2"]={"m":1.0,"e":400.0}
  var before=g.profile.resources["2"].duplicate(true)
  var bought=g.upgrade_reactor(1)
  print("BOUGHT ",bought," HANDOFF ",g.native_execution==null," LEVEL ",g.profile.reactorLevel," DEBIT ",GrowthNumber.compare(before,g.profile.resources["2"])>0)
  quit(0 if bought and g.native_execution==null and g.profile.reactorLevel==2501 and GrowthNumber.compare(before,g.profile.resources["2"])>0 else 1)
 else:quit(2)
