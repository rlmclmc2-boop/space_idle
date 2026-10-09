extends SceneTree
# Explicit real-command fixture; does not use player saves or judge play value.
const Display=preload("res://scripts/equipment_display.gd")
const N=preload("res://scripts/growth_number.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func equal(a,b)->bool:return absf(float(N.divide(a,b))-1)<1e-6
func _initialize()->void:
 var g:=BattleGame.new(ShipDatabase.new(),false);g.stat_cache_enabled=true
 g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 check(g.switch_ship("Heavy_Battleship"),"legal multi-drone hull")
 var rng:=RandomNumberGenerator.new();rng.seed=347
 var ordinary:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"ordinary","blue","laser",5,"1")
 var legend:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"rebuild","legendary","laser",5,"1")
 ordinary.affixes=[{"key":"attack_speed","tier":5,"value":0.019,"locked":false},{"key":"critical_chance","tier":5,"value":0.019,"locked":false}]
 legend.affixes=[{"key":"global_defence","tier":5,"value":0.08,"locked":false},{"key":"repeat_chance","tier":5,"value":0.019,"locked":false}]
 legend.legendary_effect={"effect_id":"drone_rebuild","parameters":{"damage_and_defence_bonus":0.8}}
 check(Bag.insert(g.profile.hyperspace.inventory,ordinary,g.hyperspace.config) and Bag.insert(g.profile.hyperspace.inventory,legend,g.hyperspace.config),"valid owned rebuild fixtures")
 check(g.hyperspace.set_equipped(g,[ordinary.id,legend.id]),"equip through authority")
 for key in ["laser","cannon","missile","longLaser"]:
  var source:Dictionary=g.module_entry("weapons",0);source.key=key;source.level=12
  g.drone_combat.reset();g.invalidate_stat_cache()
  var baseline:=Display.snapshot(g,source);var defence:Dictionary=g.module_entry("defence",0)
  var baseline_defence:=Display.snapshot(g,defence)
  var live_before=g.jewel_equipment_stat(source)
  check(g.drone_combat.try_rebuild(g),"real rebuild: "+key)
  var profile_state:=JSON.stringify(g.profile);var rng_state:=g.rng.state
  var runtime_state:Dictionary={"disabled":g.drone_combat.disabled.duplicate(),"bonus":g.drone_combat.rebuild_bonus,"stacks":g.drone_combat.rebuild_stacks,"player":g.player.duplicate(true)}
  var live_after=g.jewel_equipment_stat(source)
  check(equal(live_after,N.multiply(live_before,1.8)),"combat retains rebuild damage: "+key)
  check(Display.snapshot(g,source)==baseline,"card excludes rebuild and temporary affix/source loss: "+key)
  check(Display.snapshot(g,defence)==baseline_defence,"defence remains stable")
  check(g.player==runtime_state.player and g.drone_combat.disabled==runtime_state.disabled and g.drone_combat.rebuild_bonus==runtime_state.bonus and g.drone_combat.rebuild_stacks==runtime_state.stacks and JSON.stringify(g.profile)==profile_state and g.rng.state==rng_state,"display preserves battle/profile/RNG")
  check(equal(g.jewel_equipment_stat(source),live_after),"subsequent combat value unchanged")
  # Explicit second temporary loss covers repeat and defence affixes as well.
  g.drone_combat.disabled.append(legend.id);g.invalidate_stat_cache()
  check(Display.snapshot(g,source)==baseline and Display.snapshot(g,defence)==baseline_defence,"all temporarily disabled sources retain configured baseline")
  g.drone_combat.restore_disabled(g,"fixture-wave-end")
  check(Display.snapshot(g,source)==baseline,"restoration with retained rebuild bonus stays stable")
  g.drone_combat.reset();g.invalidate_stat_cache()
  check(Display.snapshot(g,source)==baseline,"new-stage reset stays stable")
 print("STATIC DRONE DISPLAY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
