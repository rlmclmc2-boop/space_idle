extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
 if not ok:
  failures+=1
  printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var db=ShipDatabase.new()
 var g=BattleGame.new(db,false)
 g.profile.cleared=[1,15]
 g.rebuild_unlocks()
 g.profile.reactorLevel=2120
 var share=R.div_small(g.reactor_capacity(),4)[0]
 check(g.set_reactor_allocation("condensation",share),"condensation allocation")
 var multiplier=g.reactor_multiplier("condensation")
 check(multiplier is float and is_finite(multiplier),"finite reactor factor")
 var income=g.settle_jewel_fragments(1e20,"drop",1.0)
 check(N.valid(income) and N.compare(income,0)>0,"overflowed fragment input retained")
 var main=preload("res://scripts/main.gd").new()
 main.db=db;main.game=g
 var preview=main.pickup_preview_amount({"jewel":true,"amount":1e20,"hightech":false,"jewelRatio":1.0},true)
 check(N.valid(preview) and N.compare(preview,0)>0,"overflowed pickup preview retained")
 main.free()
 var battle=preload("res://scripts/presented_battle_game.gd").new(db,false)
 battle.profile.unlocked=BattleGame.EQUIPMENT.duplicate();battle.profile.cleared=[1]
 battle.profile.reactorLevel=2120
 battle.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 battle.stat_cache_enabled=true;battle.invalidate_stat_cache();battle.save_enabled=false;battle.reset_player();battle.state=BattleGame.State.COMBAT
 battle.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[{"resourceId":1,"amount":100.0,"chance":1.0}],"res_ratio":1e20}])
 check(battle.set_reactor_allocation("smelting",R.div_small(battle.reactor_capacity(),4)[0]),"smelting allocation")
 check(battle.reactor_multiplier("smelting") is float,"finite smelting factor")
 battle.enemies[0].hp=1.0
 battle.hit_enemy(battle.enemies[0],100000,0)
 var iron=battle.drops.filter(func(d):return str(d.get("id",""))=="1")
 check(iron.size()==1 and N.valid(iron[0].amount) and N.compare(iron[0].amount,0)>0,"overflowed legacy drop retained")
 print("FACTOR ",N.text(multiplier)," INCOME ",N.text(income)," PREVIEW ",N.text(preview)," DROPS ",iron.size())
 print("CONSUMER ROUND3 FAILURES ",failures)
 quit(1 if failures else 0)
