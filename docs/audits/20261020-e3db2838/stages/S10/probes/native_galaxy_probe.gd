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
  var preflight=g.native_execution.prepare_galaxy_refit(g,{"equipment_value":1.0,"charge_max":1.0})
  print("GALAXY_PREFLIGHT_EMPTY ",preflight.is_empty())
  var share=R.div_small(g.reactor_capacity(),4)[0]
  var changed=g.set_reactor_allocation("smelting",share)
  print("CHANGED ",changed," HANDOFF ",g.native_execution==null," ALLOCATION ",R.digits(g.profile.reactorAllocation.smelting).length())
  quit(0 if preflight.is_empty() and changed and g.native_execution==null else 1)
 else:quit(2)
