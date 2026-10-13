extends SceneTree
## Native-only low-load contract. No legacy Game or shadow battle executes.
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func actor(uid:int=100,x:float=30.0,hp:float=100.0,slot:int=4)->Dictionary:
 return {"uid":uid,"slot":slot,"x":x,"y":0.0,"hp":hp,"max_hp":hp,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}
func weapon(kind:int,hostile:bool=false)->Dictionary:
 return {"kind":kind,"type":1,"slot":0,"source":0,"hostile":hostile,"damage":10.0,"interval":2.0,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":["laser","cannon","missile","longLaser"][kind]},"row":{"cd":2.0,"para1":1.0,"para2":1.0,"para3":0.0}}
func world(kind:int=0)->Dictionary:
 return {"clock":0.0,"rng_state":418,"resistance":0.5,"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0,"armour_type":2,"shield_type":1},"enemies":[actor()],"weapons":[weapon(kind)]}
func core(d:Dictionary):
 var k=ClassDB.instantiate("SpaceCombatKernel")
 check(k.configure(d),"admission")
 return k
func timing_contract()->void:
 const STEP=1.0/60.0
 for kind in [0,1,2,3]:
  var d=world(kind);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
  d.weapons[0].interval=0.03;d.weapons[0].charge=-1.0
  var k=core(d);var launches:Array=[];var periods:Array=[]
  for step in 60:
   k.advance(STEP)
   for e in k.take_feedback():
    if int(e.kind)==0:launches.append(step+1)
    if int(e.kind)==6:periods.append(float(e.clock))
  if kind==3:
   check(launches==[1] and periods.size()==32,"persistent beam uses CD for32 periods, not new roots")
   for i in periods.size():check(is_equal_approx(periods[i],STEP+0.03*(i+1)),"beam period has authored due time")
  else:
   var expected:Array=[]
   for step in range(1,61,2):expected.append(step)
   check(launches==expected and k.metrics().root_attacks==30,"fixed-step reset CD across weapon "+str(kind))
  k.cancel()
 var d=world(3);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
 d.weapons[0].charge=0.1;d.weapons[0].interval=0.05
 var k=core(d);var periods:Array=[]
 for step in 20:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==6:periods.append(float(e.clock))
 check(periods.size()==5 and is_equal_approx(k.enemy_views()[0].hp,1e9-50.0),"nonzero charge pays exactly five continuous periods")
 for i in periods.size():check(is_equal_approx(periods[i],STEP+0.1+0.05*i),"charge then authored continuous period time")
 k.cancel()
 for kind in [0,1,2,3]:
  d=world(kind);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
  d.weapons[0].interval=10.0;d.weapons[0].charge=0.05;d.weapons[0].repeat_probability=1.0;d.repeat_delay=0.1
  k=core(d);var births:Array=[]
  var repeat_step=10 if kind==3 else 7
  for step in repeat_step-1:
   k.advance(STEP)
   for e in k.take_feedback():
    if int(e.kind)==0:births.append(float(e.clock))
  check(births.size()==1 and k.metrics().repeat_queue==1,"repeat waits full delay for weapon "+str(kind))
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==0:births.append(float(e.clock))
  check(births.size()==2 and is_equal_approx(births[1],repeat_step*STEP),"probability1 repeat born once at due boundary "+str(kind))
  for step in 60:
   k.advance(STEP)
   for e in k.take_feedback():
    if int(e.kind)==0:births.append(float(e.clock))
  check(births.size()==2 and k.metrics().repeat_queue==0 and k.metrics().root_attacks==2,"derived repeat cannot recursively repeat "+str(kind))
  k.cancel()
func hostile_beam_contract()->void:
 const STEP=1.0/60.0
 var d=world(3);d.enemies=[actor(100),actor(101,200.0)]
 var pulse=weapon(0,true);pulse.damage=7.0;pulse.interval=10.0
 d.weapons=[weapon(3,true),pulse];d.weapons[0].interval=0.05
 var k=core(d);k.advance(STEP);k.take_feedback()
 var beam:Dictionary=k.projectile_views().filter(func(shot):return bool(shot.get("beam",false)))[0]
 var shield:float=k.player_view().shield
 check(k.hit_handle(k.actor_handle(100),1000.0,1),"hostile beam source killed while another enemy lives")
 check(beam.dead and k.projectile_views().any(func(shot):return not bool(shot.get("beam",false)) and not bool(shot.dead)),"source death retires only continuous beam, ordinary carrier survives")
 k.take_feedback()
 for i in 3:k.advance(STEP)
 var incoming=0
 for e in k.take_feedback():
  if int(e.kind)==2 and bool(e.player):incoming+=1
 check(incoming==0 and k.player_view().shield==shield,"dead hostile source cannot pay another beam period")
 for i in 10:k.advance(STEP)
 for e in k.take_feedback():
  if int(e.kind)==2 and bool(e.player):incoming+=1
 check(incoming==1 and k.player_view().shield<shield,"ordinary hostile in-flight shot still settles once after source death")
 k.cancel()
 d=world(3);d.enemies=[actor(100),actor(101,200.0)]
 var friendly=weapon(3);friendly.damage=1000.0
 d.weapons=[friendly,weapon(3,true)]
 k=core(d);k.advance(STEP)
 check(k.enemy_views()[0].hp==0.0 and k.player_view().shield==100.0,"earlier lethal period invalidates later queued hostile period in same segment")
 k.cancel()
 d=world(1);d.weapons[0].source=-1;d.weapons[0].remaining=0.3;d.weapons[0].interval=0.3;d.repeat_delay=0.1;d.defences=[]
 k=core(d);k.advance(0.1)
 var before:Dictionary=k.export_handoff().duplicate(true)
 check(is_equal_approx(k.cooldown_remaining(0),0.2) and k.export_handoff()==before,"cooldown read observes root deadline without mutation")
 k.advance(0.2)
 check(is_equal_approx(k.cooldown_remaining(0),0.3),"first shot publishes next root cooldown")
 d.weapons[0].damage=20.0
 check(k.update_configuration(d) and is_equal_approx(k.cooldown_remaining(0),0.3),"numeric update preserves pending root deadline")
 k.advance(0.3)
 check(k.metrics().root_attacks==2 and is_equal_approx(k.cooldown_remaining(0),0.3),"second firing cycle uses the same authoritative deadline")
 k.cancel()
func _initialize()->void:call_deferred("run")
func run()->void:
 check(ClassDB.class_exists("SpaceCombatKernel"),"native extension class registered")
 if not ClassDB.class_exists("SpaceCombatKernel"):quit(1);return
 timing_contract()
 hostile_beam_contract()
 for kind in [0,1,2,3]:
  var d=world(kind);d.enemies[0].x=100.0
  var k=core(d)
  for i in 180:k.advance(1.0/60.0)
  check(float(k.enemy_views()[0].hp)<100.0,"execution type hit deducts health "+str(kind))
  check(k.metrics().old_game_callbacks==0 and k.metrics().object_refreshes==0,"no old Game callback/refresh "+str(kind))
  var feedback=k.take_feedback();var fires=0;var hits=0
  for e in feedback:
   if int(e.kind)==0:fires+=1
   if int(e.kind)==2:hits+=1
   check(float(e.clock)>=0.0 and float(e.clock)<=float(k.metrics().clock),"feedback stays in executed time range")
  check(fires>0 and hits>0,"launch and damage feedback present "+str(kind))
  k.cancel()
 var k=core(world(0));k.advance(1.0/60.0)
 check(k.metrics().active_flights==1 and k.metrics().physics_visits==0,"birth phase does not advance new carrier early")
 check(k.projectile_views()[0].motion_lease.position()==Vector2.ZERO,"new carrier starts at committed muzzle")
 k.advance(1.0/60.0)
 check(k.projectile_views()[0].motion_lease.position().distance_to(Vector2(12,0))<0.001,"continuous native position advances next phase")
 var h=k.actor_handle(100)
 check(k.hit_handle(h,1000.0,1),"ordered lethal command accepted")
 check(k.enemy_views()[0].hp==0.0 and not k.hit_handle(h,10.0,1),"dead generation rejects stale target")
 check(k.configure(world(0)),"new encounter generation")
 check(not k.hit_handle(h,10.0,1) and k.enemy_views()[0].hp==100.0,"old encounter handle cannot damage reused uid")
 k.cancel()
 var d=world(2);d.weapons[0].salvo=3;d.enemies[0].x=400.0
 k=core(d);k.advance(1.0/60.0);k.advance(0.12)
 var shots=k.projectile_views()
 check(shots.size()==2,"due queue releases only two due tubes")
 if shots.size()>=2:check(shots[0].attack_instance.id==shots[1].attack_instance.id,"salvo shares one mutable attack instance")
 check(k.metrics().ejection_queue==1,"third tube still queued")
 k.cancel();var before=k.metrics().steps;k.advance(1.0)
 check(k.metrics().active_flights==0 and k.metrics().ejection_queue==0 and k.metrics().repeat_queue==0 and k.metrics().steps==before,"cancellation releases active and pending work")
 d=world(0);d.enemies=[actor(100,30,5,4),actor(101,100,100,0)];d.chain_count=1
 k=core(d)
 for i in 4:k.advance(1.0/60.0)
 check(k.enemy_views()[0].hp==0.0 and k.projectile_views().size()==1,"lethal hit creates exactly one chain carrier")
 if k.projectile_views().size()==1:check(k.projectile_views()[0].motion_lease.position()==Vector2(30,0),"hit-born chain waits for next execution phase")
 k.advance(0.2)
 check(k.enemy_views()[1].hp==90.0 and k.projectile_views().is_empty(),"derived carrier settles once without recursive chain")
 k.cancel()
 d=world(3);d.enemies=[actor(100,30,5,4),actor(101,100,100,0)];d.chain_count=1
 k=core(d);k.advance(1.0/60.0)
 check(k.enemy_views()[0].hp==0.0 and k.enemy_views()[1].hp==90.0,"lethal beam period retains its ordered linked hit")
 k.cancel()
 d=world(0);d.weapons=[];d.requires_module_defense=true;d.memory_interval=1.0;d.deferred_interval=0.1;d.deferred_duration=0.5
 d.defences=[{"layer":0,"type":1,"base":100.0,"factor":1.0,"maximum":100.0,"memory_heal":0.2,"memory_cap":0.1,"deferred_fraction":0.5},{"layer":1,"type":2,"base":100.0,"factor":1.0,"maximum":100.0}]
 k=core(d);k.advance(1.0)
 check(k.receive_player_hit(20.0,2),"native incoming event")
 check(k.player_view().shield==95.0 and k.player_view().armour==100.0,"memory protection then fractional deferral/body payment")
 var found=false
 for e in k.take_feedback():
  if e.kind==2 and bool(e.player):found=is_equal_approx(e.amount,5.0) and is_equal_approx(e.absorbed,10.0)
 check(found,"incoming feedback matches protection and actual paid damage")
 k.advance(0.1)
 check(k.player_view().shield==94.0,"deferred portion pays at next due boundary")
 k.cancel()
 k=core(world(0));k.advance(1.0/60.0)
 var lease_weak=weakref(k.projectile_views()[0].motion_lease)
 k.cancel();k.take_feedback()
 check(lease_weak.get_ref()==null,"retired flight releases presentation lease after feedback consumption")
 check(k.configure(world(0)) and k.take_feedback().is_empty(),"new encounter drops prior feedback authority")
 d=world(0);d.scatter=true;d.scatter_bonus=4.0;d.weapons=[weapon(0,true)];d.player.shield_type=2
 k=core(d);k.advance(1.0/60.0)
 check(k.projectile_views()[0].damage==10.0,"friendly scatter legendary never increases hostile shot")
 for i in 8:k.advance(1.0/60.0)
 check(k.player_view().shield==90.0,"hostile scatter-isolated actual hit pays original damage")
 k.cancel()
 d.weapons=[weapon(0,false)];k=core(d);k.advance(1.0/60.0)
 check(k.projectile_views()[0].damage==50.0,"friendly single-target scatter bonus retained")
 k.cancel()
 var rejection=world(0);rejection.weapons[0].damage=INF
 check(not k.configure(rejection),"nonfinite configuration rejected before execution")
 k.advance(1.0);check(k.metrics().active_flights==0,"rejected configuration cannot execute")
 rejection=world(0);rejection.weapons[0].damage={"mantissa":1.0,"exponent":400}
 check(not k.configure(rejection),"unsupported extended numeric domain explicitly rejected")
 rejection=world(0);rejection.unsupported_rules=["unimplemented_legendary"]
 check(not k.configure(rejection),"unsupported rule refuses candidate")
 k=core(world(0));h=k.actor_handle(100);k.cancel()
 check(not k.hit_handle(h,1.0,1) and k.enemy_views()[0].hp==100.0,"cancelled encounter rejects mutation commands")
 if OS.get_cmdline_user_args().has("--core-only"):
  print("NATIVE CORE ONLY: ",checks," checks, ",failures," failures");quit(1 if failures else 0);return
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.state=BattleGame.State.COMBAT
 var old_enemies=g.enemies;var old_player=g.player;var old_projectiles=g.projectiles
 var observed=[];g.event.connect(func(kind,info):observed.append({"kind":kind,"info":info}))
 d=world(0);d.execution_scope="native_low_contract";d.enemies=[actor(100,30,5,4),actor(101,1000,100,0)]
 check(g.admit_native_execution(d),"one existing Game accepts bounded native execution")
 check(g.native_execution!=null and g.native_execution.kernel.metrics().old_game_callbacks==0 and not is_same(g.enemies,old_enemies) and not is_same(g.player,old_player) and not is_same(g.projectiles,old_projectiles),"old bodies and callback pipeline retired at admission")
 var stable_enemies=g.enemies;var stable_player=g.player;var stable_projectiles=g.projectiles
 for i in 5:g.tick(1.0/60.0)
 check(g.enemies[0].hp==0.0,"Game read view observes native real lethal settlement")
 check(is_same(g.enemies,stable_enemies) and is_same(g.player,stable_player) and is_same(g.projectiles,stable_projectiles),"tick retains stable views instead of exporting the world")
 var fire_seen=false;var hit_seen=false;var death_seen=false
 for row in observed:
  if row.kind=="fire":fire_seen=true
  if row.kind=="hit":hit_seen=true;check(row.info.amount==10.0 and row.info.uid==100,"direct hit consumer agrees with paid target")
  if row.kind=="explode":death_seen=true;check(is_same(row.info,g.enemies[0]),"death consumer sees authoritative actor")
 check(fire_seen and hit_seen and death_seen,"direct launch/hit/death display events delivered")
 check(g.cooldowns.is_empty() and g.jewel_repeats.is_empty() and g.missile_queue.is_empty() and is_equal_approx(g.motion_clock,5.0/60.0),"old combat and presented schedulers stay out of execution")
 g.change_state(BattleGame.State.RETREAT)
 check(g.native_execution==null and g.projectiles.is_empty(),"Game exit cancels owner without restarting old runtime")
 var rejected=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false);rejected.state=BattleGame.State.COMBAT
 d=world(0);d.execution_scope="rich15"
 check(not rejected.admit_native_execution(d) and rejected.native_execution==null,"unfinished rich15 compilation explicitly refuses candidate")
 d=world(0);d.weapons[0].interval=0.03;d.enemies[0].x=100000.0
 k=core(d)
 for i in 60:k.advance(1.0/60.0)
 check(k.metrics().root_attacks==30,"authored reset-on-shot interval matches fixed-step firing cadence")
 k.cancel()
 d=world(0);d.weapons=[];d.requires_drop_rules=true;d.drop_rules_compiled=true;d.drop_uid=700;d.jewel_probability=1.0;d.jewel_ratio=2.0
 d.enemies[0].jewel_rolls=1;d.enemies[0].compiled_drops=[{"resource":1,"chance":1.0,"base":5.0,"amount":10.0}]
 k=core(d);check(k.hit_handle(k.actor_handle(100),1000.0,1),"native lethal drop command")
 var born=[]
 for e in k.take_feedback():
  if e.kind==7:born.append(e.shot)
 check(born.size()==2 and born[0].id=="jewel" and born[1].id=="1" and born[1].amount==10.0 and born[1].source_uid==100,"native death creates ordered jewel/resource drops with full amounts")
 check(k.metrics().drop_uid==702,"drop uid owned and advanced by native death")
 k.cancel()
 print("NATIVE EXECUTION KERNEL: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
