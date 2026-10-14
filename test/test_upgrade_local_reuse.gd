extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const OldCompiler=preload("res://qa_old_compiler.gd")
const NewGame=preload("res://scripts/presented_battle_game.gd")
const OldGame=preload("res://qa_old_upgrade.gd")
class UI extends "res://scripts/battlefield.gd":
 var projections:=0
 var synthetic:=false
 var original_number={"m":2.5,"e":400.0}
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func equipment_display_snapshot(entry:Dictionary,level:=-1)->Dictionary:
  projections+=1
  if synthetic:return {"base":original_number,"expected":original_number,"trigger":0.0,"bonus_probability":0.0,"critical_multiplier":2.0,"guaranteed":false}
  return super.equipment_display_snapshot(entry,level)
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func fixture(type=NewGame,compiled:=false):
 var g=type.new(ShipDatabase.new(),false)
 g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":1e30,"2":1e30}
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.cleared=range(1,61);g.profile.highestLevel=61;g.profile.enhancementLevel=40
 g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout.weapons=[{"key":"laser","level":3},{"key":"laser","level":3},{"key":"missile","level":4},{"key":"longLaser","level":5},{"key":"longLaser","level":3},{"key":"cannon","level":3}]
 g.profile.loadout.defence=[{"key":"shield","level":3},{"key":"armour","level":4},{"key":"shield","level":3},{"key":"armour","level":4}]
 if compiled:g.enable_compiled_combat_rules()
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.rng.seed=991
 g.enemies.assign([{"uid":100,"slot":0,"x":280.0,"y":150.0,"hp":1e12,"max_hp":1e12,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 return g
func compiler_checks()->void:
 for compiled in [false,true]:
  var g=fixture(NewGame,compiled)
  check((g.compiled_combat_rules!=null)==compiled,"compiler mode "+str(compiled))
  var recipes={}
  for entry in g.combat_weapon_entries()+g.defense_entries():
   var category="weapons" if entry.key in BattleGame.WEAPON_KEYS else "defence"
   var recipe=g.enhancement_recipe(entry)
   if recipes.has(category):check(recipe==recipes[category],"category recipe exact with mode "+str(compiled))
   else:recipes[category]=recipe.duplicate(true)
  for upgrade in [{},{"weapon_levels":{0:7,1:9,4:12},"defence_levels":{1:8}},{"weapon_levels":{0:1.5}},{"defence_levels":{0:INF}}]:
   var a=OldCompiler.new().compile(g,"native_low_contract",upgrade.duplicate(true));var b=Compiler.new().compile(g,"native_low_contract",upgrade.duplicate(true))
   check(a==b,"descriptor/error exact mode="+str(compiled)+" upgrade="+str(upgrade))
   if upgrade.is_empty():check(not b.has("error"),"valid compiler fixture")
   if not b.has("error"):
    for w in b.weapons:
     if w.get("hostile",false):continue
     check(g.enhancement_recipe(w.entry)==recipes.weapons,"source recipe unchanged")
    if not b.weapons.is_empty() and not b.weapons[0].transfer_effects.is_empty():
     b.weapons[0].transfer_effects[0].qa_mutation=true
     check(not g.enhancement_recipe(b.weapons[0].entry)[0].has("qa_mutation"),"transfer mutation isolated")
     if b.weapons.size()>1:check(not b.weapons[1].transfer_effects[0].has("qa_mutation"),"birth descriptors isolated")
  var old=g.db.config.dmgReduce;g.db.config.dmgReduce={"m":1.0,"e":400.0}
  check(OldCompiler.new().compile(g,"native_low_contract")==Compiler.new().compile(g,"native_low_contract"),"GrowthNumber scalar refusal exact")
  g.db.config.dmgReduce=old
func scalar_copy(value):
 if value is RandomNumberGenerator:return {"class":"RandomNumberGenerator","state":str(value.state)}
 if value is Object:return {"class":value.get_class()}
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[key]=scalar_copy(value[key])
  return out
 if value is Array:
  var out:Array=[]
  for item in value:out.append(scalar_copy(item))
  return out
 return value
func clean_kernel(g)->Dictionary:
 var d=g.native_execution.kernel.export_handoff().duplicate(true)
 for flight in d.get("flights",[]):
  var view:Dictionary=flight.view
  flight.view={"serial":view.get("serial"),"target_uid":view.get("target",{}).get("uid",-1),"source_uid":view.get("source",{}).get("uid",-1),"primary_uid":view.get("primary_target",{}).get("uid",-1)}
 return scalar_copy(d)
func upgrade_checks()->void:
 for native in [false,true]:
  var a=fixture(OldGame,true);var b=fixture(NewGame,true)
  if native:
   check(a.admit_native_compiled_execution("native_low_contract"),"old native admission")
   check(b.admit_native_compiled_execution("native_low_contract"),"new native admission")
   a.tick(1.0/60);b.tick(1.0/60)
  var events_a:Array=[];var events_b:Array=[]
  a.event.connect(func(k,i):
   if k in ["resources_changed","upgrade","upgrades_completed"]:events_a.append([k,i.duplicate(true)]))
  b.event.connect(func(k,i):
   if k in ["resources_changed","upgrade","upgrades_completed"]:events_b.append([k,i.duplicate(true)]))
  var shots:Array=b.projectiles.duplicate();var old_damage:Array=[]
  for shot in shots:old_damage.append(shot.get("damage"))
  check(a.upgrade_equipment_batch("1")==b.upgrade_equipment_batch("1"),"batch return native="+str(native))
  check(events_a==events_b and not events_a.is_empty(),"ordered resource/upgrade events exact")
  check(a.profile.resources==b.profile.resources,"sequential wallet exact")
  check(a.player==b.player,"defence delta exact")
  check(a.profile.loadout==b.profile.loadout and a.cooldowns==b.cooldowns,"levels/CD exact")
  if native:
   check(clean_kernel(a)==clean_kernel(b),"kernel post-upgrade exact except construction seed")
   for i in shots.size():check(shots[i].get("damage")==old_damage[i] and b.projectiles.has(shots[i]),"old flight damage/lifetime retained")
   for i in 4:a.tick(1.0/60);b.tick(1.0/60)
   check(clean_kernel(a)==clean_kernel(b),"future birth/update parity")
   check(a.native_execution.handoff_to_legacy(a,"qa")==b.native_execution.handoff_to_legacy(b,"qa"),"handoff parity")
   check(a.cooldowns==b.cooldowns and a.player==b.player,"handoff CD/health exact")
  a.profile.resources={"1":0.0,"2":0.0};b.profile.resources=a.profile.resources.duplicate()
  var before=b.profile.loadout.duplicate(true)
  check(not a.upgrade_equipment_batch("1") and not b.upgrade_equipment_batch("1"),"insufficient wallet refused")
  check(b.profile.loadout==before and b.profile.resources==a.profile.resources,"refusal no debit/mutation")
func ui_checks():
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);root.add_child(scene);scene.set_process(false);scene.beginner_guide.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear();g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.loadout.weapons=[{"key":"laser","level":3},{"level":3,"key":"laser"},{"key":"laser","level":4},{"key":"laser","level":3}]
 g.invalidate_stat_cache();var panel=scene.equipment_panel;var cache=[];scene.projections=0
 var a=panel.equipment_item("weapons",0,cache);var b=panel.equipment_item("weapons",1,cache)
 check(scene.projections==1,"equal full entry different insertion order shares projection")
 check(a.projection==b.projection and is_same(a.projection,b.projection),"shared projection exact identity")
 var c=panel.equipment_item("weapons",2,cache);var inactive=panel.equipment_item("weapons",3,cache)
 check(scene.projections==2,"different level is distinct; equal inactive entry shares only projection")
 check(a.id!=b.id and a.name!=b.name and inactive.locked and not a.locked,"slot/active context not shared")
 check(a.projection.is_read_only(),"shared projection readonly")
 scene.synthetic=true;scene.projections=0;cache=[]
 var owned=panel.equipment_item("weapons",0,cache).projection
 check(owned.is_read_only() and owned.base.is_read_only() and owned.expected.is_read_only(),"nested GrowthNumber readonly")
 check(not scene.original_number.is_read_only() and not is_same(owned.base,scene.original_number),"original GrowthNumber not frozen or aliased")
 scene.original_number.m=3.5;check(owned.base.m==2.5 and scene.original_number.m==3.5,"original mutation cannot contaminate shared copy")
 scene.synthetic=false;panel.show();panel.detail_frame.hide();panel.refresh();panel.select_item("weapons_1")
 scene.projections=0;panel.refresh_slots(["weapons_0","weapons_1","weapons_2"])
 check(scene.projections==2,"refresh_slots scoped cache")
 var first=panel.items.weapons_0.projection;scene.projections=0;panel.refresh_slots(["weapons_0","weapons_1"])
 check(scene.projections==1 and not is_same(first,panel.items.weapons_0.projection),"next refresh uses fresh cache")
 check(panel.selected=="weapons_1" and panel.items.weapons_0.level!=panel.items.weapons_2.level,"selection/level ownership unchanged")
 for index in 3:
  var item=panel.items["weapons_"+str(index)]
  var costs=g.slot_upgrade_cost("weapons",index,1)
  check(item.cost==scene.cost_text(costs) and item.direct_upgradeable==g.can_afford_upgrade_costs(costs),"slot price/affordability independent "+str(index))
 check(panel.items.weapons_0.cost!=panel.items.weapons_2.cost,"different levels retain different prices")
 scene.queue_free();await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 compiler_checks();upgrade_checks();await ui_checks()
 var result={"checks":checks,"failures":failures}
 FileAccess.open("res://.runtime/upgrade-local-check.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("UPGRADE_LOCAL_CHECK ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
