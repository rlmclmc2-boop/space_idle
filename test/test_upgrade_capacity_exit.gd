extends SceneTree
class ObservedGame extends "res://scripts/presented_battle_game.gd":
 var legacy:=false
 var in_capacity:=false
 var value_calls:=0
 var observations:Array=[]
 func upgrade_capacity_value(entry:Dictionary,key:String)->Variant:
  in_capacity=true
  var value=jewel_equipment_stat(entry) if legacy else super.upgrade_capacity_value(entry,key)
  in_capacity=false
  observations.append(binding_snapshot())
  return value
 func jewel_equipment_stat(entry:Dictionary,level := -1,effects:Variant=null,include_timed_buffs := true,galaxy_equipment := -1.0,galaxy_charge := -1.0)->Variant:
  if in_capacity:value_calls+=1
  return super.jewel_equipment_stat(entry,level,effects,include_timed_buffs,galaxy_equipment,galaxy_charge)
 func binding_snapshot()->Dictionary:
  var result={}
  for index in enhancement_branches.weapons:
   var row:Dictionary=enhancement_branches.weapons[index].duplicate(true)
   row["bound"]=is_same(enhancement_branches.weapons[index].entry,combat_entry(index))
   result[index]=row
  return result
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run_case(legacy:bool,kind:String)->Dictionary:
 var g=ObservedGame.new(ShipDatabase.new(),false);g.legacy=legacy
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.loadout.weapons[0].key="missile"
 g.profile.loadout.defence=[{"key":"shield","level":1},{"key":"armour","level":1}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.RETREAT if kind=="retreat" else BattleGame.State.COMBAT
 g.player.armour=g.N.multiply(g.player.armour,0.5);g.player.shield=g.N.multiply(g.player.shield,0.5)
 g.enhancement_branches.weapons.clear()
 if kind in ["warm","stale","replace","key_change"]:
  var data=g.enhancement_branches.weapon(g,0)
  data.target={"uid":77};data.dwell=12.5;data.next=3;data.stacks=4;data.stack_time=6.5
  if kind=="stale":g.profile.loadout.weapons[0]=g.profile.loadout.weapons[0].duplicate(true)
 var events:Array=[]
 var watch=func(event:String,info:Dictionary):
  if event in ["resources_changed","upgrade"]:
   events.append({"event":event,"info":info.duplicate(true),"bindings":g.binding_snapshot(),"player":g.player.duplicate(true),"wallet":g.profile.resources.duplicate(true)})
  if event=="resources_changed":
   if kind=="replace":g.profile.loadout.weapons[0]=g.profile.loadout.weapons[0].duplicate(true)
   if kind=="key_change":g.profile.loadout.weapons[0].key="shield"
 g.event.connect(watch)
 var category="defence" if kind in ["shield","armour","retreat"] else "weapons"
 var index=1 if kind=="armour" else 0
 var okay=g.upgrade_slot(category,index,1)
 g.event.disconnect(watch)
 var result={"okay":okay,"player":g.player.duplicate(true),"wallet":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"bindings":g.binding_snapshot(),"observations":g.observations.duplicate(true),"events":events,"calls":g.value_calls}
 return result
func run()->void:
 for kind in ["cold","warm","stale","replace","key_change","shield","armour","retreat"]:
  var old=run_case(true,kind);var current=run_case(false,kind)
  check(old.okay and current.okay,kind+": upgrade succeeds")
  check(old.calls==2 and current.calls==(2 if kind in ["shield","armour","retreat"] else 0),kind+": only unused weapon value calls exit")
  old.erase("calls");current.erase("calls")
  check(old==current,kind+": observations, identity bindings, timed state, capacity, wallet and events match")
  if kind=="warm":check(current.observations[0][0].dwell==12.5 and current.observations[0][0].stacks==4 and current.observations[0][0].stack_time==6.5 and current.observations[0][0].next==3,"warm binding retains timed state")
  if kind=="stale":check(current.observations[0][0].dwell==0.0 and current.observations[0][0].bound,"different entry identity resets at original before point")
  if kind=="replace":check(not current.observations[1][0].bound,"removed owner is not rebound by after point")
 var g=ObservedGame.new(ShipDatabase.new(),false)
 g.enhancement_branches.weapons.clear()
 g.upgrade_capacity_value({"key":"missile","level":1},"missile")
 check(g.enhancement_branches.weapons.is_empty() and g.value_calls==0,"detached weapon creates no combat state")
 print("UPGRADE CAPACITY EXIT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
