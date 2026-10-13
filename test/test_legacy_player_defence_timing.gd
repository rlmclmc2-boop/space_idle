extends SceneTree
## Isolated scalar fixtures exercise existing player defence/payment functions.
class TestDatabase extends "res://scripts/database.gd":
 var hostile_row={"dmg":10.0,"dmgtype":1,"cd":0.07,"para1":1.0,"para2":1.0,"para3":0.061666666666667}
 func enemy_weapon(key:String)->Dictionary:
  return hostile_row.duplicate() if key=="longLaser-qa" else super.enemy_weapon(key)
 func ratio(_level:int,_battle_point_index:int,_kind:String)->float:return 1.0
class TestDrone extends "res://scripts/drone_combat_effects.gd":
 var black:Dictionary={}
 var rebuild:Dictionary={}
 func effect(_g,key:String)->Dictionary:
  if key=="black_hole":return black
  if key=="drone_rebuild":return rebuild
  return {}
class TestGame extends "res://scripts/presented_battle_game.gd":
 var params:Dictionary={}
 var shield_rate:=0.0
 var shield_delay:=0.01
 var memory_enabled:=false
 var memory_fraction:=0.0
 var memory_resistance_enabled:=false
 var cover_enabled:=false
 var memory_count:=0
 var debt_count:=0
 var prepared_totals:Dictionary={}
 func enhancement_parameter(key:String)->float:
  return float(params[key]) if params.has(key) else super.enhancement_parameter(key)
 func jewel_equipment_stat(entry:Dictionary,level:int=-1,effects:Variant=null,include_timed_buffs:bool=true)->Variant:
  return 100.0 if str(entry.get("key","")) in ["shield","armour"] else super.jewel_equipment_stat(entry,level,effects,include_timed_buffs)
 func combat_equipment_row(key:String,level:int)->Dictionary:
  var row:=super.combat_equipment_row(key,level).duplicate()
  if key in ["shield","armour"]:
   row.para1=100.0;row.dmgtype=0
   if key=="shield":row.para2=shield_rate;row.para3=shield_delay
  return row
 func hyperspace_totals()->Dictionary:
  return prepared_totals if not prepared_totals.is_empty() else super.hyperspace_totals()
 func enhancement_effects(entry:Dictionary)->Array:
  if str(entry.get("key","")) not in ["shield","armour"]:return []
  var effects:Array=[]
  if memory_enabled:effects.append({"kind":"memory_material","level":1,"p2":memory_fraction,"p4":0.2})
  if cover_enabled:effects.append({"kind":"adaptation","level":1,"p2":0.0,"p4":0.0})
  return effects
 func memory_effect(entry:Dictionary)->Dictionary:
  return {"kind":"memory_material","level":1,"p2":memory_fraction,"p4":0.2} if memory_enabled and str(entry.get("key","")) in ["shield","armour"] else {}
 func _enhancement_effect_index(entry:Dictionary,kind:String)->int:
  for i in enhancement_effects(entry).size():
   if enhancement_effects(entry)[i].kind==kind:return i
  return -1
 func shared_enhancement_effect_count()->int:return 3
 func enhancement_branch_choice(category:String,kind:String,node:int)->String:
  if category=="defence" and kind=="adaptation" and node==2 and cover_enabled:return "B"
  if category=="defence" and kind=="memory_material" and node==2 and memory_resistance_enabled:return "B"
  return ""
 func enhancement_branch_unlocked(_category:String,_kind:String,_node:int)->bool:return true
 func ratio(_kind:String)->float:return 1.0
 func enemy_weapon_offset(_enemy:Dictionary,_index:int)->Vector2:return Vector2.ZERO
 func advance_enhancement_repair_step(dt:float,ticks:int)->void:
  memory_count+=ticks;super.advance_enhancement_repair_step(dt,ticks)
 func advance_enhancement_deferred_tick()->void:
  debt_count+=1;super.advance_enhancement_deferred_tick()
var checks:=0
var failures:=0
const STEP=1.0/60.0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(compiled:bool,options:Dictionary={}):
 var g=TestGame.new(TestDatabase.new(),false)
 g.stat_cache_enabled=true;g.save_enabled=false
 g.params={"memory_interval":1.0,"deferred_interval":1.0,"deferred_duration":1.0,"deferred_clear_probability":0.0,"adaptation_b2_interval":0.02,"adaptation_b2_duration":0.01,"adaptation_b2_capacity_multiplier":0.2,"memory_b2_duration":0.01,"memory_b2_lockout":0.01,"memory_b2_resistance":0.5}
 g.params.merge(options.get("params",{}),true)
 g.shield_rate=float(options.get("rate",0.0));g.memory_enabled=bool(options.get("memory",false));g.memory_fraction=float(options.get("memory_fraction",0.0));g.cover_enabled=bool(options.get("cover",false));g.memory_resistance_enabled=bool(options.get("resistance",false))
 for entry in g.profile.loadout.defence:entry.key="";entry.level=0
 g.profile.loadout.defence[0].key="armour";g.profile.loadout.defence[0].level=1
 g.profile.loadout.defence[1].key="shield";g.profile.loadout.defence[1].level=1
 if not g.profile.unlocked.has("shield"):g.profile.unlocked.append("shield")
 g.prepared_totals=g.hyperspace_totals().duplicate(true)
 g.drone_combat=TestDrone.new();g.invalidate_stat_cache();g.reset_player()
 if compiled:g.enable_compiled_combat_rules()
 g.state=BattleGame.State.COMBAT;g.stage=1;g.group_index=0;g.player.shield=0.0
 g.jewel_defence_damage[0]=0.0;g.jewel_defence_damage[1]=100.0;g.jewel_defence_times[0]=0.0;g.jewel_defence_times[1]=0.0;g.since_hit=0.0
 return g
func source(uid:int=100)->Dictionary:
 return {"uid":uid,"slot":4,"x":30.0,"y":0.0,"hp":1e9,"max_hp":1e9,"shield":0.0,"max_shield":0.0,"armourType":0,"shieldType":0,"dmgMultiple":1.0,"equipment":[{"name":"longLaser-qa"}],"cooldowns":[0.0],"drops":[]}
func hostile(g,due:float,interval:float=1.0)->Dictionary:
 g.db.enemy_source.hostile_row.cd=interval;g.db.enemy_source.hostile_row.para3=due
 var enemy=source();var rows:Array[Dictionary]=[enemy];g.enemies=rows
 g.lock_long_laser(enemy,g.db.enemy_weapon("longLaser-qa"),true,0,enemy.equipment[0])
 var shot:Dictionary=g.projectiles.back();shot.next_hit_at=due
 return shot
func rate_contract(compiled:bool)->void:
 var g=fixture(compiled,{"rate":1.0});hostile(g,STEP+0.045,0.07)
 for i in 4:g.tick_projectiles(STEP)
 check(is_equal_approx(float(g.player.armour),95.0) and is_zero_approx(float(g.player.shield)),"legacy shield delay integral before first period "+str(compiled))
 for i in 4:g.tick_projectiles(STEP)
 check(is_equal_approx(float(g.player.armour),91.0) and is_zero_approx(float(g.player.shield)),"legacy next period has no future recovery "+str(compiled))
 check(is_equal_approx(g.enhancement_defense_time,8.0*STEP) and is_equal_approx(g.since_hit,8.0*STEP-(STEP+0.045+0.07)) and is_equal_approx(float(g.jewel_defence_times[1]),g.since_hit),"persistent clock, since_hit and module times advance once")
 g.begin_retreat()
func window_contract(compiled:bool)->void:
 var g=fixture(compiled,{"cover":true});var shot=hostile(g,0.004,0.002)
 # Only two periods: the source is disabled synchronously after its second hit.
 var data:Dictionary=g.enhancement_branches.defense(g,0);data.cover_elapsed=0.015
 var other:Dictionary=g.enhancement_branches.defense(g,1);other.cover_elapsed=0.015
 var counter={"incoming":0}
 var listener=func(kind:String,info:Dictionary):
  if kind=="hit" and bool(info.player) and not info.get("deferred",false):
   counter.incoming+=1
   if counter.incoming==2:shot.dead=true
 g.event.connect(listener);g.tick_projectiles(STEP);g.event.disconnect(listener)
 check(counter.incoming==2 and g.player.armour==90.0 and g.profile.enhancementHits==2,"cover refresh at.005 cannot protect earlier.004 hit")
 check(data.cover==0.0 and other.cover==0.0 and is_equal_approx(g.since_hit,STEP-0.006),"cover expiry and protected-hit since_hit use same cursor")
 g.begin_retreat()
 g=fixture(compiled,{"memory":true,"resistance":true});g.db.enemy_source.hostile_row.dmgtype=2;shot=hostile(g,0.004,0.002)
 g.enhancement_buffers[1]=10.0;g.enhancement_buffer_owners[1]={"entry":g.slot_entry("defence",1),"key":"shield"}
 data=g.enhancement_branches.defense(g,1);data.resistance_type=1;data.resistance_time=0.005
 counter={"incoming":0}
 listener=func(kind:String,info:Dictionary):
  if kind=="hit" and bool(info.player) and not info.get("deferred",false):
   counter.incoming+=1
   if counter.incoming==2:shot.dead=true
 g.event.connect(listener);g.tick_projectiles(STEP);g.event.disconnect(listener)
 check(counter.incoming==2 and g.player.armour==90.0 and g.enhancement_buffers[1]==0.0,"actual resistance mismatch starts lockout before later hit")
 g.begin_retreat()
func final_pending_contract(compiled:bool)->void:
 var g=fixture(compiled,{"memory":true,"memory_fraction":0.2,"params":{"memory_interval":0.01,"deferred_interval":0.01,"deferred_duration":0.01}})
 # Fixed armour slot0 and obtained shield unlock survive the real clear normalization.
 g.rebuild_unlocks()
 g.player.armour=100.0;g.player.shield=0.0;g.jewel_defence_damage[0]=0.0;g.jewel_defence_damage[1]=100.0
 g.jewel_defence_times[0]=0.0;g.jewel_defence_times[1]=0.0;g.invalidate_stat_cache()
 g.group_index=g.db.levels[0].groups.size()
 var enemy=source();enemy.hp=5.0;enemy.max_hp=5.0;var rows:Array[Dictionary]=[enemy];g.enemies=rows
 g.drone_combat.black={"constants":{"period":1.0,"absorption_duration":0.02},"parameters":{"damage_multiplier":1.0},"drone_id":"qa_black"}
 g.profile.hyperspace.inventory.drones.qa_black={"weapon":"laser"}
 g.drone_combat.black_hole_remaining=0.01;g.drone_combat.black_hole_damage=10.0
 g.enhancement_deferred={1:{"armour":5.0,"shield":0.0}}
 g.tick_projectiles(STEP);g.clear_timer=10.0
 check(g.state==BattleGame.State.LEVEL_CLEAR and g.memory_count==0 and g.debt_count==0 and g.player.armour==100.0,"black-hole final clear forbids same-time debt and memory")
 check(g.enhancement_memory_elapsed==0.0 and g.enhancement_deferred_elapsed==0.0 and g.enhancement_memory_due_pending and g.enhancement_deferred_due_pending and g.enhancement_deferred_total()==5.0,"terminal phases are legal and unexecuted obligations retained")
 var Return=preload("res://scripts/hyperspace_main_return.gd")
 print("PENDING_DEF_SLOTS_BEFORE ",JSON.stringify({"slots":g.defense_entries().map(func(e):return e.key),"armour":g.stat("armour"),"shield":g.max_shield()}))
 var saved:Dictionary=Return.capture(g)
 var point={"stage":g.stage,"distance":g.distance,"groupIndex":g.group_index,"loop":g.profile.loop,"guardArrived":g.guard_arrived,"retreatBossPending":g.retreat_boss_pending,"pendingUnlocks":g.pending_unlocks.duplicate(),"state":int(g.state)}
 check(Return.valid(saved,point,g.db.levels.size()),"pending freeze receipt validates without changing outer schema")
 g.enhancement_memory_due_pending=false;g.enhancement_deferred_due_pending=false;g.enhancement_deferred.clear()
 Return.restore(g,saved,point)
 print("PENDING_DEF_SLOTS_AFTER ",JSON.stringify({"slots":g.defense_entries().map(func(e):return e.key),"armour":g.stat("armour"),"shield":g.max_shield(),"shield_indices":g._jewel_defence_capacity("shield").indices,"armour_indices":g._jewel_defence_capacity("armour").indices}))
 check(g.enhancement_memory_due_pending and g.enhancement_deferred_due_pending and g.enhancement_deferred_total()==5.0,"frozen return restores pending obligations")
 g.tick(STEP)
 print("PENDING_RESUME_VALUES ",JSON.stringify({"compiled":compiled,"state":int(g.state),"memory":g.memory_count,"debt":g.debt_count,"tick":g.enhancement_deferred_tick,"shield":g.player.shield,"armour":g.player.armour,"paused":g.paused,"defence_time":g.enhancement_defense_time,"memory_fraction":g.memory_fraction}))
 check(g.state==BattleGame.State.LEVEL_CLEAR and g.memory_count==2 and g.debt_count==2 and g.enhancement_deferred_tick==2 and g.player.shield==40.0,"next clear step settles pending once plus its one new regular deadline")
 var rng_before:int=g.rng.state;g.advance_jewel_repair(0.0)
 check(not g.enhancement_memory_due_pending and not g.enhancement_deferred_due_pending and g.memory_count==2 and g.debt_count==2 and g.rng.state==rng_before and g.enhancement_memory_elapsed<0.01 and g.enhancement_deferred_elapsed<0.01,"no pending settlement replay or invalid phase after resume")
 g.begin_retreat()
func death_rebuild_contract(compiled:bool,rebuild:bool)->void:
 var g=fixture(compiled,{"params":{"memory_interval":0.064,"deferred_interval":0.064,"deferred_duration":0.064}})
 g.player.armour=15.0;g.jewel_defence_damage[0]=85.0;g.enhancement_deferred={1:{"armour":6.0,"shield":0.0}}
 if rebuild:
  g.drone_combat.rebuild={"constants":{"maximum_stacks":1},"parameters":{"damage_and_defence_bonus":0.0}}
  g.profile.hyperspace.inventory.equipped=["qa_rebuild"]
  g.profile.hyperspace.inventory.drones.qa_rebuild={"id":"qa_rebuild","weapon":"laser","ultimate":false,"legendary":false,"origin_quality":"white","blue_source_bonus":false}
 hostile(g,STEP+0.045,1.0)
 for i in 4:g.tick_projectiles(STEP)
 if rebuild:check(g.state==BattleGame.State.COMBAT and g.drone_combat.rebuild_stacks==1 and g.player.armour==100.0 and g.memory_count==1,"actual rebuild continues same-time pending memory once")
 else:
  check(g.state==BattleGame.State.RETREAT and is_equal_approx(g.enhancement_defense_time,0.064) and is_equal_approx(g.enemy_shield_time,4.0*STEP) and g.memory_count==0 and g.enhancement_memory_due_pending,"fatal debt freezes defence and consumes logical tail")
  g.reset_player();check(not g.enhancement_memory_due_pending and not g.enhancement_deferred_due_pending and g.enhancement_memory_elapsed==0.0,"reset does not resurrect old interrupted settlements")
 g.begin_retreat()
func noncombat_contract(compiled:bool)->void:
 for mode in [BattleGame.State.TRAVEL,BattleGame.State.LEVEL_CLEAR]:
  var g=fixture(compiled);hostile(g,0.005,0.01);g.state=mode;g.enemy_shield_time=2.0
  g.enemies[0].shield=1.0;g.enemies[0].max_shield=100.0;g.enemies[0].shield_updated_at=2.0
  var before=g.enemies[0].duplicate(true);g.tick_projectiles(STEP)
  check(g.enemy_shield_time==2.0 and g.enemy_shield_hit_time==-1.0 and g.enemies[0]==before and g.enhancement_defense_time==0.0,"frozen noncombat beams neither query history nor advance defence")
  g.begin_retreat()
func native_handoff_contract(compiled:bool)->void:
 var g=fixture(compiled,{"memory":true,"memory_fraction":0.2});g.profile.loadout.weapons[0].key="cannon"
 var d={"execution_scope":"native_low_contract","clock":10.0,"rng_state":418,"resistance":0.5,"defence_time":0.995,"memory_elapsed":0.995,"deferred_elapsed":0.995,"deferred_tick":0,"memory_interval":1.0,"deferred_interval":1.0,"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":0.0},"enemies":[source()],"weapons":[{"kind":1,"slot":0,"source":-1,"type":1,"hostile":false,"damage":10.0,"interval":10.0,"remaining":10.0,"speed":720.0,"entry":{"key":"cannon"},"row":{"dmgtype":1,"cd":10.0,"para1":720.0,"para2":1.0}}],"defences":[{"layer":1,"type":0,"base":100.0,"maximum":100.0,"memory_heal":0.2,"memory_cap":0.2},{"layer":0,"type":0,"base":100.0,"maximum":100.0,"loss":100.0,"memory_heal":0.2,"memory_cap":0.2}]}
 check(g.admit_native_execution(d),"native aligned phase fixture admission")
 g.native_execution.advance(g,0.005);var owner=g.native_execution
 check(owner.handoff_to_legacy(g,"player_defence_contract"),"atomic aligned phase handoff")
 var shield=g.player.shield;var tick:int=g.enhancement_deferred_tick;var rng_before:int=g.rng.state
 g.advance_jewel_repair(0.0)
 check(shield==20.0 and g.player.shield==shield and g.enhancement_deferred_tick==tick and g.memory_count==0 and g.rng.state==rng_before and not g.enhancement_memory_due_pending,"already-settled native deadline is not replayed")
 g.begin_retreat()
func simultaneous_contract(compiled:bool)->void:
 var g=fixture(compiled,{"memory":true,"memory_fraction":0.2,"params":{"memory_interval":0.01,"deferred_interval":0.01,"deferred_duration":0.01}})
 g.player.armour=20.0;g.jewel_defence_damage[0]=80.0;g.enhancement_deferred={1:{"armour":5.0,"shield":0.0}}
 hostile(g,0.01);g.tick_projectiles(STEP)
 check(g.player.armour==35.0 and g.player.shield==10.0 and g.memory_count==1 and g.debt_count==1 and g.profile.enhancementHits==1,"same-time debt then memory then incoming hit use existing payment rules")
 check(is_equal_approx(g.since_hit,STEP-0.01) and is_equal_approx(float(g.jewel_defence_times[1]),g.since_hit),"same-time incoming resets timers once after memory settlement")
 g.begin_retreat()
func absorption_contract(compiled:bool)->void:
 var g=fixture(compiled);var shot=hostile(g,0.004,0.002)
 g.drone_combat.black={"constants":{"period":1.0,"absorption_duration":0.02},"parameters":{"damage_multiplier":1.0},"drone_id":"qa_black"}
 g.profile.hyperspace.inventory.drones.qa_black={"weapon":"laser"};g.drone_combat.black_hole_remaining=0.005
 var seen={"attempts":0,"absorbed":0}
 var listener=func(kind:String,info:Dictionary):
  if kind=="hyperspace_absorb" and bool(info.hostile):seen.attempts+=1;seen.absorbed+=1
  if kind=="hit" and bool(info.player):
   seen.attempts+=1
   if seen.attempts==2:shot.dead=true
 g.event.connect(listener);g.tick_projectiles(STEP);g.event.disconnect(listener)
 check(seen.absorbed==1 and seen.attempts==2 and g.profile.enhancementHits==2 and g.player.armour==90.0,"absorption expiry between periods protects only the earlier hit")
 check(g.drone_combat.black_hole_remaining==0.0 and is_equal_approx(g.since_hit,STEP-0.006),"absorbed attempt and body hit retain original since_hit semantics")
 g.begin_retreat()
func native_terminal_phase_contract(compiled:bool)->void:
 var g=fixture(compiled,{"memory":true,"memory_fraction":0.2});g.profile.loadout.weapons[0].key="cannon";g.group_index=g.db.levels[0].groups.size()
 var enemy=source();enemy.hp=5.0;enemy.max_hp=5.0
 var d={"execution_scope":"native_low_contract","final_encounter":true,"clock":10.0,"rng_state":418,"resistance":0.5,"defence_time":0.995,"memory_elapsed":0.995,"deferred_elapsed":0.995,"deferred_tick":0,"memory_interval":1.0,"deferred_interval":1.0,"deferred":{1:{"armour":200.0,"shield":0.0}},"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":0.0},"enemies":[enemy],"weapons":[{"kind":1,"slot":0,"source":-1,"type":1,"hostile":false,"damage":10.0,"interval":10.0,"remaining":0.0,"speed":720.0,"entry":{"key":"cannon"},"row":{"dmgtype":1,"cd":10.0,"para1":720.0,"para2":1.0}}],"defences":[{"layer":1,"type":0,"base":100.0,"maximum":100.0,"memory_heal":0.2,"memory_cap":0.2},{"layer":0,"type":0,"base":100.0,"maximum":100.0,"loss":100.0,"memory_heal":0.2,"memory_cap":0.2}]}
 check(g.admit_native_execution(d),"terminal native phase fixture admission")
 var owner=g.native_execution
 owner.kernel.advance(0.001);owner.kernel.advance(0.004)
 check(owner.kernel.metrics().final_cleared and owner.handoff_to_legacy(g,"terminal_phase_contract"),"native committed completion and fatal debt transfer atomically")
 check(g.player.armour==0.0 and g.enhancement_memory_elapsed<1.0 and g.enhancement_deferred_elapsed<1.0 and g.enhancement_memory_due_pending and not g.enhancement_deferred_due_pending,"native unexecuted memory phase normalizes without replaying paid debt")
 var tick:int=g.enhancement_deferred_tick;g.advance_jewel_repair(0.0)
 check(g.debt_count==0 and g.memory_count==0 and g.enhancement_deferred_tick==tick,"dead imported phase performs no forbidden settlement")
 g.reset_player();g.advance_jewel_repair(0.0)
 check(not g.enhancement_memory_due_pending and g.debt_count==0 and g.memory_count==0,"reset after native terminal transfer cannot replay old obligations")
 g.begin_retreat()
func _initialize()->void:call_deferred("run")
func run()->void:
 var path="res://bin/space_native.dll";var sha=FileAccess.get_sha256(path)
 check(GDExtensionManager.is_extension_loaded("res://addons/native_battle/space_native.gdextension") and sha==OS.get_environment("QA_NATIVE_SHA256"),"expected native library loaded")
 print("PLAYER_DEFENCE_LIBRARY_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"path":ProjectSettings.globalize_path(path),"sha256":sha}))
 var args:=OS.get_cmdline_user_args()
 var selected:Array=["rate","window","pending","death","rebuild","noncombat","native","tie","black","native-terminal"]
 for arg in args:
  if arg.begins_with("--cases="):selected=Array(arg.trim_prefix("--cases=").split(","))
 for compiled in [false,true]:
  if args.has("--mode=false") and compiled:continue
  if args.has("--mode=true") and not compiled:continue
  for name in selected:
   var previous_checks:=checks;var previous_failures:=failures
   match name:
    "rate":rate_contract(compiled)
    "window":window_contract(compiled)
    "pending":final_pending_contract(compiled)
    "death":death_rebuild_contract(compiled,false)
    "rebuild":death_rebuild_contract(compiled,true)
    "noncombat":noncombat_contract(compiled)
    "native":native_handoff_contract(compiled)
    "tie":simultaneous_contract(compiled)
    "black":absorption_contract(compiled)
    "native-terminal":native_terminal_phase_contract(compiled)
   print("PLAYER_CASE_RESULT ",JSON.stringify({"case":name,"compiled":compiled,"checks":checks-previous_checks,"failures":failures-previous_failures}))
 print("LEGACY PLAYER DEFENCE TIMING: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
