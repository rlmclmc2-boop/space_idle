extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const Handoff=preload("res://scripts/native_execution_handoff.gd")
const Session=preload("res://scripts/native_execution_session.gd")
class StrangeGame extends "res://scripts/presented_battle_game.gd":
 var strange:Variant={"parameters":{"damage_multiplier":2.0},"constants":{"spawn_probability":1.0,"kill_spawns":3,"delay":0.2}}
 var transfer_due:=false
 func hyperspace_totals()->Dictionary:
  var totals=super.hyperspace_totals().duplicate(true)
  if strange!=null:totals.legendary.strange_matter=strange
  return totals
 func advance_shared_clock_and_economy(dt:float)->void:
  super.advance_shared_clock_and_economy(dt)
  if transfer_due:
   transfer_due=false;native_execution.handoff_to_legacy(self,"test_shared")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func world()->Dictionary:
 return {"clock":0.0,"repeat_delay":0.1,"rng_state":418,"resistance":0.5,"requires_strange_matter":true,"strange_probability":1.0,"strange_delay":0.2,"strange_damage_multiplier":2.0,"strange_kill_spawns":3,"strange_damage_type":1,"defences":[],"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0},"enemies":[{"uid":100,"slot":4,"x":200.0,"y":0.0,"hp":1000.0,"max_hp":1000.0,"armour_type":0}],"weapons":[{"kind":1,"type":1,"slot":0,"source":-1,"hostile":false,"damage":10.0,"factor":1.0,"interval":10.0,"remaining":0.0,"speed":10.0,"charge":-1.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"critical_rate":0.0,"critical_multiplier":2.0,"repeat_probability":0.0,"repeat_multiplier":1.0,"entry":{"key":"cannon"},"row":{"cd":10.0,"para1":10.0}}]}
func fixture():
 var g=StrangeGame.new(ShipDatabase.new(),false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.loadout.weapons[0].key="cannon"
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":0,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 g.cooldowns[g.slot_id("weapons",0)]=0.0
 return g
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 print("CONFIG cap=",Engine.max_fps," vsync=",DisplayServer.window_get_vsync_mode()," display=",DisplayServer.get_name())
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world()
 check(k.configure(d) and k.advance(0.1),"first cannon hit")
 var state=k.export_handoff();var packet=state.strange_pending[0]
 check(state.strange_pending.size()==1 and is_equal_approx(packet.remaining,0.2) and packet.damage==20.0,"survival produces base raw packet")
 check(packet.context.trigger_depth==1 and packet.context.trigger=="strange_matter" and not packet.context.has("chain_allowance"),"derived no recursion context")
 check(k.advance(0.1) and k.metrics().hits==1,"not due boundary")
 check(k.advance(0.1) and k.metrics().hits==2 and k.metrics().strange_pending==0,"due once and no recursion")
 check(is_equal_approx(k.enemy_views()[0].shield_hit_at,0.2),"damage time is step start though deadline checked at end")
 check(k.enemy_views()[0].hp==970.0,"primary plus derived damage")
 d=world();d.strange_delay=0.0;k.configure(d);k.advance(0.1)
 check(k.metrics().hits==1 and k.metrics().strange_pending==1,"zero delay newborn waits")
 k.advance(0.1);check(k.metrics().hits==2 and k.metrics().strange_pending==0,"zero delay next step")
 d=world();d.enemies[0].hp=5.0;k.configure(d);k.advance(0.1)
 check(k.metrics().strange_pending==3,"kill count branch")
 var seed_after=k.rng_source().state
 d.strange_probability=0.0;k.configure(d);k.advance(0.1)
 check(k.rng_source().state==seed_after and k.metrics().strange_pending==3,"kill branch no probability draw")
 d=world();d.strange_probability=0.0;k.configure(d);k.advance(0.1)
 check(k.metrics().strange_pending==0,"survival probability zero")
 d=world();d.strange_delay=0.0;d.final_encounter=true;d.enemies[0].hp=25.0;k.configure(d);k.advance(0.1)
 var roots=k.metrics().root_attacks
 k.advance(0.1)
 check(k.metrics().final_cleared and k.metrics().hits==2 and k.metrics().root_attacks==roots and is_equal_approx(k.metrics().clock,0.2),"last target dies at boundary without extra roots or time")
 d=world();k.configure(d);k.advance(0.1);packet=k.export_handoff().strange_pending[0].duplicate(true)
 d.requires_strange_matter=false;d.strange_damage_multiplier=100.0;d.strange_delay=9.0
 check(k.update_configuration(d) and k.export_handoff().strange_pending[0]==packet,"configuration removal preserves existing packet")
 k.advance(0.2);check(k.metrics().strange_pending==0 and k.enemy_views()[0].hp==970.0,"removed effect still settles old damage")
 # Changed delay can reorder deadlines, but a single boundary uses insertion order.
 d=world();d.weapons[0].interval=0.1;d.strange_delay=0.4;k.configure(d);k.advance(0.1)
 d.weapons[0].damage=20.0;d.strange_delay=0.0
 check(k.update_configuration(d) and k.advance(0.1),"changed delay creates second packet")
 d.requires_strange_matter=false;d.weapons[0].interval=10.0;k.update_configuration(d);k.take_feedback()
 k.advance(0.4)
 var due_hits=k.take_feedback().filter(func(e):return e.kind==2)
 check(due_hits.size()>=2 and due_hits[0].amount==20.0 and due_hits[1].amount==40.0,"different deadlines settle due packets in insertion order")
 # Old high-damage flight plus new small weapon: current births are finite,
 # retained raw times the new hit-time multiplier is not.
 d=world();d.strange_damage_multiplier=1.0
 var laser=d.weapons[0].duplicate(true);laser.kind=0;laser.damage=1e150;laser.slot=1;laser.entry={"key":"laser"}
 d.weapons.append(laser)
 check(k.configure(d) and k.advance(0.01),"old high raw flight fixture")
 state=k.export_handoff();check(not state.flights.is_empty(),"high raw remains in flight")
 var old_rng=k.rng_source().state
 d.weapons[1].damage=1.0;d.strange_damage_multiplier=1e100
 check(k.can_update_configuration(d),"same old-flight update otherwise valid with finite product")
 d.strange_damage_multiplier=1e200
 check(not k.can_update_configuration(d) and not k.update_configuration(d),"retained raw times new multiplier overflow rejected")
 check(k.export_handoff()==state and k.rng_source().state==old_rng,"overflow reject atomic queues hp RNG clocks")
 for field in ["strange_probability","strange_delay","strange_damage_multiplier","strange_kill_spawns","strange_damage_type"]:
  for value in [-1,INF,NAN,"1",true]:
   var bad=world();bad[field]=value
   check(not k.configure(bad) and k.export_handoff()==state,"invalid descriptor atomic "+field+" "+str(value))
 var bad=world();bad.strange_probability=1.1;check(not k.configure(bad),"probability upper bound")
 bad=world();bad.strange_damage_type=3;check(not k.configure(bad),"type upper bound")
 bad=world();bad.strange_kill_spawns=2147483648;check(not k.configure(bad),"count int32 bound")
 bad=world();bad.erase("strange_delay");check(not k.configure(bad),"required parameter")
 d=world();d.weapons[0].damage=1e150;d.strange_damage_multiplier=1e150;d.counter_growth=1e10;d.counter_level=1.0
 check(k.configure(d),"runtime growth fixture admission")
 state=k.export_handoff();old_rng=k.rng_source().state
 check(not k.advance(0.1) and k.export_handoff()==state and k.rng_source().state==old_rng,"runtime derived overflow refuses untouched step")
 k.cancel()
 var g=fixture();var compiled=Compiler.new().compile(g,"native_low_contract")
 check(not compiled.has("error") and compiled.requires_strange_matter and compiled.strange_damage_multiplier==2.0,"compiler current params")
 g.strange.constants.delay=-1.0;check(Compiler.new().compile(g,"native_low_contract").has("error"),"compiler invalid data");g.strange.constants.delay=0.2
 check(g.admit_native_compiled_execution("native_low_contract"),"Game native admission")
 g.tick(0.1);var owner=g.native_execution;var core=owner.kernel;state=core.export_handoff()
 check(state.strange_pending.size()==1 and g.drone_combat.delayed.is_empty(),"one native queue owner")
 var prepared=Handoff.new();bad=state.duplicate();bad.strange_pending=state.strange_pending.duplicate(true);bad.strange_pending[0].context.trigger_depth=0
 check(not prepared.prepare(g,owner,bad) and core.export_handoff()==state and g.drone_combat.delayed.is_empty(),"bad handoff rejects before ownership mutation")
 var production=g.production_time();var motion=g.motion_clock;var revision=core.metrics().steps
 g.transfer_due=true;g.tick(0.05)
 check(g.native_execution==null and core.metrics().steps==revision,"shared-stage handoff skips native combat")
 check(is_equal_approx(g.production_time()-production,0.05) and is_equal_approx(g.motion_clock-motion,0.05),"shared and combat clocks advance once")
 check(g.drone_combat.delayed.size()==1 and is_equal_approx(g.drone_combat.delayed[0].remaining,0.15),"handoff pending countdown exactly once")
 var hp=g.enemies[0].hp;var due_damage=g.drone_combat.delayed[0].damage
 g.tick(0.15);check(g.drone_combat.delayed.is_empty() and is_equal_approx(float(hp-g.enemies[0].hp),float(due_damage)),"legacy settles transferred packet once")
 g=fixture();g.admit_native_compiled_execution("native_low_contract");g.tick(0.1);owner=g.native_execution;packet=owner.kernel.export_handoff().strange_pending[0].duplicate(true)
 owner.cancel(g);check(g.drone_combat.delayed.size()==1 and g.drone_combat.delayed[0]==packet,"cancel exports pending before release")
 g.drone_combat.reset();check(g.drone_combat.delayed.is_empty(),"existing reset clears queue")
 g=fixture();g.strange.constants.spawn_probability=0.0;g.strange.constants.delay=0.35;g.strange.parameters.damage_multiplier=3.7
 compiled=Compiler.new().compile(g,"native_low_contract");check(compiled.strange_probability==0.0 and compiled.strange_delay==0.35 and compiled.strange_damage_multiplier==3.7,"distinct configuration compiled")
 for final_wave in [false,true]:
  g=fixture();g.enemies[0].hp=1.0
  if final_wave:g.group_index=g.db.levels[g.stage-1].groups.size()
  check(g.admit_native_compiled_execution("native_low_contract"),"wave lifecycle admission")
  g.tick(0.1)
  check(g.native_execution==null and g.drone_combat.delayed.size()==3,"wave clear preserves kill packets")
  check(g.state==(BattleGame.State.LEVEL_CLEAR if final_wave else BattleGame.State.TRAVEL),"actual wave state transition")
  var remaining=float(g.drone_combat.delayed[0].remaining)
  g.tick(0.05)
  check(is_equal_approx(g.drone_combat.delayed[0].remaining,remaining if final_wave else remaining-0.05),"final queue frozen ordinary travel queue advances")
 print("STRANGE_MATTER checks=",checks," failures=",failures)
 quit(1 if failures else 0)
