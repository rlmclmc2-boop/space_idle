extends SceneTree
## Legacy-only temporal contract; fixtures use isolated, unsaved Game instances.
class EndlessGame extends "res://scripts/presented_battle_game.gd":
 var fixture_endless:=false
 func hyperspace_totals()->Dictionary:
  var totals:=super.hyperspace_totals()
  if not fixture_endless:return totals
  totals=totals.duplicate();totals.legendary=totals.legendary.duplicate()
  totals.legendary.endless_beam={"parameters":{"maximum_multiplier_bonus":0.0}}
  return totals
var checks:=0
var failures:=0
const STEP=1.0/60.0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func actor(uid:int,slot:int,shield:float=0.0,max_shield:float=0.0,armour_type:int=2)->Dictionary:
 return {"uid":uid,"slot":slot,"x":30.0+uid-100,"y":0.0,"hp":1000.0,"max_hp":1000.0,"shield":shield,"max_shield":max_shield,"shieldType":1,"armourType":armour_type,"shield_updated_at":0.0,"shield_hit_at":-10.0,"shieldDelay":0.01,"shieldRecovery":0.1,"drops":[]}
func fixture(compiled:bool):
 var g=EndlessGame.new(ShipDatabase.new(),false)
 g.stat_cache_enabled=true;g.save_enabled=false;g.fixture_endless=true
 for i in 2:g.profile.loadout.weapons[i].key="longLaser";g.profile.loadout.weapons[i].level=1
 g.invalidate_stat_cache()
 if compiled:g.enable_compiled_combat_rules()
 g.state=BattleGame.State.COMBAT;g.stage=1;g.group_index=0
 return g
func beam(g,mount:int,due:float,interval:float)->Dictionary:
 var row={"dmgtype":1,"cd":interval,"para1":1.0,"para2":1.0,"para3":due}
 g.lock_long_laser(g.player,row,false,mount,g.combat_entry(mount))
 var shot:Dictionary=g.projectiles.back()
 shot.attack_snapshot.damage=10.0;shot.attack_snapshot.effects=[];shot.attack_snapshot.critical=false;shot.attack_snapshot.critical_bonus_applied=false
 shot.attack_snapshot.weapon=row.duplicate();shot.weapon=row.duplicate();shot.charged_multiplier=1.0
 shot.next_hit_at=due
 return shot
func scenario(compiled:bool,reverse:bool,mode:String)->void:
 var g=fixture(compiled)
 var a=actor(100,4,1.0,1000.0);var b=actor(101,0,0.0,0.0,1)
 var early=0.005;var late=0.01;var interval=1.0
 if mode=="priority":a.shield=0.0;a.slot=0;b.slot=4
 if mode=="tie":a.shield=10.0;late=early
 if mode=="multiple":a.shield=10.0;a.shieldDelay=0.002;early=0.003;late=0.002;interval=0.004
 var dead=actor(99,2);dead.hp=0.0
 var rows:Array[Dictionary]=[dead,a,b];g.enemies=rows
 var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
 check(descriptor.get("error","")=="unsupported_legendary:endless_beam" and not g.admit_native_compiled_execution("native_low_contract") and g.native_execution==null,"endless configuration selects actual legacy fallback")
 var endless=beam(g,0,late,interval);var normal=beam(g,1,early,interval)
 endless.target=dead;endless.locked_target=dead
 check(is_same(g.endless_source(),endless.entry),"endless fixture uses actual eligible source identity")
 if reverse:g.projectiles.reverse()
 var hits:Array=[];var periods:Array=[]
 var listener=func(kind:String,info:Dictionary):
  if kind=="hit" and not bool(info.player):hits.append({"at":float(g.enemy_shield_hit_time),"uid":int(info.uid)})
  if kind=="beam_hit":periods.append({"at":float(g.enemy_shield_hit_time),"mount":int(info.shot.mount)})
 g.event.connect(listener)
 g.tick_projectiles(STEP)
 g.event.disconnect(listener)
 check(is_same(endless.target,a) and is_same(endless.locked_target,a),"endless rebind uses step-start resistance ordering "+mode+str(reverse)+str(compiled))
 check(g.enemy_shield_hit_time==-1.0 and is_equal_approx(g.enemy_shield_time,STEP),"query context restores without public-clock pollution")
 check(is_equal_approx(float(endless.elapsed),STEP) and is_equal_approx(float(normal.elapsed),STEP),"rebind preserves existing beam phase advancement")
 if mode in ["damage","priority"]:
  var expected_hp=983.0 if mode=="damage" else 981.0
  check(hits.size()==2 and is_equal_approx(float(hits[0].at),early) and is_equal_approx(float(hits[1].at),late),"earlier period resolves before endless period independent of array order")
  check(is_equal_approx(float(a.hp),expected_hp) and b.hp==1000.0 and a.shield==0.0 and is_equal_approx(float(a.shield_updated_at),late),"actual-time shield integral never borrows end-boundary healing "+mode)
 elif mode=="tie":
  check(periods.size()==2 and int(periods[0].mount)==(1 if reverse else 0) and int(periods[1].mount)==(0 if reverse else 1) and is_equal_approx(float(periods[0].at),early) and is_equal_approx(float(periods[1].at),early),"same-time period tie retains pending index order")
  check(a.hp==1000.0 and is_equal_approx(float(a.shield),0.5),"same-time reads recover once, then both hits settle")
 else:
  var expected:Array=[0.002,0.003,0.006,0.007,0.010,0.011,0.014,0.015]
  var ordered=hits.size()==expected.size()
  if ordered:
   for i in expected.size():ordered=ordered and is_equal_approx(float(hits[i].at),float(expected[i]))
  check(ordered,"multiple periods globally merge by actual due time")
  check(a.hp==940.0 and a.shield==0.0 and is_equal_approx(float(a.shield_updated_at),0.015),"multiple-period delay integral and damage settle exactly once")
 # A subsequent outside-period query must use the restored boundary context.
 g.targets(1)
 check(is_equal_approx(float(a.shield_updated_at),STEP),"post-period target query uses boundary, not leaked period time")
 g.begin_retreat()
func context_restore_contract(compiled:bool)->void:
 var g=fixture(compiled);var rows:Array[Dictionary]=[actor(100,4,1.0,1000.0)];g.enemies=rows
 g.enemy_shield_time=0.02;g.enemy_shield_hit_time=0.02
 g.tick_shield_beams([],0.01)
 check(g.enemy_shield_hit_time==0.02 and g.enemy_shield_time==0.02,"empty collection restores an existing outer query context")
 g.begin_retreat()
func rejection_contract(compiled:bool,expose:bool=false)->void:
 var g=fixture(compiled);var enemy=actor(100,4,1.0,1000.0);enemy.shield_updated_at=STEP
 var rows:Array[Dictionary]=[enemy];g.enemies=rows;g.enemy_shield_time=0.005
 var before=enemy.duplicate(true);var serial:int=g.main_attack_serial;var rng_state:int=g.rng.state
 if expose:
  g.hit_enemy(enemy,10.0,1)
  print("EXPECTED_SHIELD_TIME_REJECTION ",JSON.stringify({"unchanged":enemy==before,"serial_unchanged":g.main_attack_serial==serial,"rng_unchanged":g.rng.state==rng_state}))
 else:
  var errors_enabled:=Engine.print_error_messages
  Engine.print_error_messages=false
  var rejected=not g.settle_enemy_shield(enemy,0.005)
  g.hit_enemy(enemy,10.0,1)
  var candidates=g.targets(1)
  Engine.print_error_messages=errors_enabled
  check(rejected and enemy==before and g.main_attack_serial==serial and g.rng.state==rng_state and candidates.is_empty(),"future ledger explicitly rejects settlement/damage/selection without mutation")
 g.begin_retreat()
func _initialize()->void:call_deferred("run")
func run()->void:
 var dll_path="res://bin/space_native.dll";var sha=FileAccess.get_sha256(dll_path)
 check(GDExtensionManager.is_extension_loaded("res://addons/native_battle/space_native.gdextension") and sha==OS.get_environment("QA_NATIVE_SHA256"),"expected current native library is loaded alongside legacy fixture")
 print("LEGACY_LIBRARY_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"path":ProjectSettings.globalize_path(dll_path),"sha256":sha}))
 if OS.get_cmdline_user_args().has("--shield-time-violation"):
  rejection_contract(false,true);quit(0);return
 for compiled in [false,true]:
  for reverse in [false,true]:
   for mode in ["damage","priority","tie","multiple"]:scenario(compiled,reverse,mode)
  context_restore_contract(compiled);rejection_contract(compiled)
 print("LEGACY BEAM SHIELD TIMING: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
