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
func lifecycle_contract()->void:
 const STEP=1.0/60.0
 for final in [false,true]:
  var d=world(1);d.final_encounter=final;d.enemies[0].hp=5.0
  var friendly=weapon(1);friendly.remaining=2.0*STEP;friendly.interval=10.0;friendly.repeat_probability=1.0
  var hostile=weapon(0,true);hostile.damage=1000.0;hostile.speed=3000.0;hostile.interval=10.0
  d.weapons=[friendly,hostile]
  var k=core(d);k.advance(STEP);k.advance(STEP)
  check(k.enemy_views()[0].hp==0.0,"last target actually killed")
  if final:
   check(k.metrics().final_cleared and k.player_view().armour==100.0 and k.projectile_views().is_empty(),"final wipe commits before later lethal in-flight hit")
   check(k.metrics().repeat_queue==0 and k.metrics().ejection_queue==0,"final wipe leaves no delayed births")
  else:check(not k.metrics().final_cleared and k.player_view().armour==0.0,"normal wave preserves lethal ordinary in-flight hit")
  k.cancel()
 var terminal=world(2);terminal.final_encounter=true;terminal.ejection_gap=0.12-STEP
 terminal.enemies=[actor(100,10000.0,5.0)];terminal.weapons[0].salvo=2;terminal.weapons[0].interval=10.0
 var last=weapon(1);last.slot=1;last.remaining=0.12;last.interval=10.0;terminal.weapons.append(last)
 terminal.defences=[{"layer":1,"type":2,"base":100.0,"factor":1.0,"maximum":100.0}]
 terminal.deferred_interval=0.125;terminal.deferred_duration=0.125;terminal.deferred={1:{"armour":200.0,"shield":0.0}}
 var committed=core(terminal)
 for i in 8:committed.advance(STEP)
 var receipt:Dictionary=committed.export_handoff()
 check(committed.metrics().final_cleared and committed.player_view().armour==0.0 and not receipt.is_empty(),"later due debt preserves already-committed final completion snapshot")
 check(committed.commit_handoff(int(receipt.get("revision",-1))),"committed final state can transfer even after later terminal debt")
 var d=world(0);d.chain_count=1;d.enemies=[actor(100,30.0,5.0),actor(101,100.0,5.0)]
 var later=weapon(1);later.slot=1;later.remaining=5.0*STEP;later.interval=10.0
 d.weapons.append(later)
 var k=core(d)
 for i in 5:k.advance(STEP)
 var chain_seen=false
 for row in k.take_feedback():
  if int(row.kind)==4:chain_seen=row.target_uid==101 and row.target_position==Vector2(100,0)
 check(chain_seen and k.enemy_views()[1].hp==0.0,"chain feedback retains event coordinates after target death")
 k.cancel()
 for kind in [1,3]:
  d=world(kind);d.execution_scope="native_low_contract";d.secondary_probability=1.0;d.drop_rules_compiled=true
  d.enemies=[actor(100,30.0,1e9),actor(101,100.0,5.0)];d.enemies[1].armourType=1
  d.enemies[1].compiled_drops=[{"resource":1,"chance":1.0,"base":2.0,"amount":2.0}]
  var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false);g.state=BattleGame.State.COMBAT
  var observed=[];g.event.connect(func(event,info):
   if event=="enhancement_secondary":observed.append(info))
  check(g.admit_native_execution(d),"secondary lethal feedback Game admission "+str(kind))
  g.tick(STEP)
  check(observed.size()==1 and observed[0].target_uid==101 and observed[0].target==Vector2(100,0),"lethal secondary feedback consumes frozen coordinates "+str(kind))
  check(g.enemies[1].hp==0.0 and g.drops.size()==1 and g.drops[0].amount==2.0,"secondary death/drop settle exactly once "+str(kind))
  g.begin_retreat()
func final_game_contract()->void:
 const STEP=1.0/60.0
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.loadout.weapons[0].key="cannon";g.invalidate_stat_cache();g.reset_player()
 g.state=BattleGame.State.COMBAT;g.stage=1;g.group_index=g.db.levels[0].groups.size()
 var d=world(1);d.execution_scope="native_low_contract";d.final_encounter=true;d.enemies[0].hp=5.0
 var friendly=weapon(1);friendly.remaining=2.0*STEP;friendly.interval=10.0
 var hostile=weapon(0,true);hostile.damage=1000.0;hostile.speed=3000.0;hostile.interval=10.0
 d.weapons=[friendly,hostile]
 check(g.is_final_encounter() and g.admit_native_execution(d),"Game final encounter admission")
 g.tick(STEP);g.tick(STEP)
 check(g.native_execution==null and g.state==BattleGame.State.LEVEL_CLEAR and g.profile.cleared.has(1) and g.player.armour>0,"session commits final clear instead of later enemy-hit retreat")
 g.begin_retreat()
func shield_event_contract()->void:
 const STEP=1.0/60.0
 var d=world(3);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
 d.enemies[0].shield=10.0;d.enemies[0].max_shield=1000.0;d.enemies[0].shieldRecovery=0.1;d.enemies[0].shieldDelay=0.01
 d.enemies[0].shield_updated_at=0.0;d.enemies[0].shield_hit_at=-10.0
 d.weapons[0].charge=0.045;d.weapons[0].interval=0.07
 var cannon=weapon(1);cannon.slot=1;cannon.remaining=4.0*STEP;cannon.interval=4.0*STEP
 d.weapons.append(cannon)
 var k=core(d);var first=[]
 for i in 4:
  k.advance(STEP)
  for row in k.take_feedback():
   if int(row.kind)==2 and not bool(row.player):first.append(float(row.clock))
 # First period at1/60+.045, then the ordinary hit at4/60. Each consumes5 shield.
 var beam_at=STEP+0.045
 var expected=10.0+100.0*beam_at-5.0-5.0
 check(first.size()==2 and is_equal_approx(first[0],beam_at) and is_equal_approx(first[1],4.0*STEP),"nonintegral beam period precedes same-segment ordinary shot")
 check(is_equal_approx(k.enemy_views()[0].shield,expected),"shield recovery integral has no future healing or double recovery")
 var second=[]
 for i in 4:
  k.advance(STEP)
  for row in k.take_feedback():
   if int(row.kind)==2 and not bool(row.player):second.append(float(row.clock))
 var next_beam=beam_at+0.07
 expected+=100.0*(next_beam-(4.0*STEP+0.01))-5.0-5.0
 check(second.size()==2 and is_equal_approx(second[0],next_beam) and is_equal_approx(second[1],8.0*STEP),"next period and boundary shot retain event order")
 check(is_equal_approx(k.enemy_views()[0].shield,expected) and is_equal_approx(k.enemy_views()[0].shield_updated_at,8.0*STEP),"delay-aware integral commits once through segment end")
 var before:float=k.enemy_views()[0].shield
 k.target_views(1);k.target_views(1)
 check(k.enemy_views()[0].shield==before,"same-time target queries do not heal twice")
 k.cancel()
func defence_event_world()->Dictionary:
 var d=world(3);d.weapons[0]=weapon(3,true);d.weapons[0].charge=0.045;d.weapons[0].interval=0.07
 d.player.shield=0.0
 d.defences=[{"layer":0,"type":2,"base":100.0,"maximum":100.0,"loss":100.0,"rate":0.0,"delay":0.01,"last_hit":0.0},
  {"layer":1,"type":2,"base":100.0,"maximum":100.0,"loss":0.0}]
 return d
func player_defence_event_contract()->void:
 const STEP=1.0/60.0
 var beam_at=STEP+0.045
 var d=defence_event_world();d.defences[0].rate=1.0
 var k=core(d);var incoming=[]
 for i in 4:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==2 and bool(e.player):incoming.append(float(e.clock))
 # Recover100*(beam_at-.01)=5.1666667 before raw10; armour paysceil(4.8333333)=5.
 check(incoming.size()==1 and is_equal_approx(incoming[0],beam_at),"hostile period uses actual nonintegral time")
 check(is_equal_approx(k.player_view().armour,95.0) and is_zero_approx(k.player_view().shield),"player shield integrates only before beam and respects hit delay through boundary")
 for i in 4:k.advance(STEP)
 # Next period recovers100*(.07-.01)=6, then armour pays4; no boundary healing yet.
 check(is_equal_approx(k.player_view().armour,91.0) and is_zero_approx(k.player_view().shield),"later period does not borrow future recovery or repeat elapsed integral")
 check(is_equal_approx(k.export_handoff().defence_time,8.0*STEP),"defence cursor accumulates elapsed time exactly once")
 k.cancel()
 d=defence_event_world();d.memory_interval=0.064;d.defences[0].memory_heal=0.2
 k=core(d)
 for i in 4:k.advance(STEP)
 check(is_equal_approx(k.player_view().armour,90.0) and is_equal_approx(k.player_view().shield,20.0),"memory after beam cannot absorb earlier hit")
 k.cancel()
 # Three debt deadlines before the first beam retain their actual feedback clocks.
 d=defence_event_world();d.deferred_interval=0.02;d.deferred={1:{"armour":2.0},2:{"armour":2.0},3:{"armour":2.0}}
 k=core(d);incoming=[]
 for i in 4:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==2 and bool(e.player):incoming.append(float(e.clock))
 check(incoming.size()==4 and is_equal_approx(incoming[0],0.02) and is_equal_approx(incoming[1],0.04) and is_equal_approx(incoming[2],0.06) and is_equal_approx(incoming[3],beam_at),"debt deadlines precede beam in time order without public-clock overwrite")
 check(is_equal_approx(k.player_view().armour,84.0),"three debts and beam each pay once")
 k.cancel()
 # At one deadline: debt consumes5 shield, memory restores20, then beam consumes10.
 d=defence_event_world();d.player.shield=10.0;d.defences[0].loss=90.0;d.defences[0].memory_heal=0.2
 d.memory_interval=beam_at;d.deferred_interval=beam_at;d.deferred={1:{"shield":5.0}}
 k=core(d);incoming=[]
 for i in 4:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==2 and bool(e.player):incoming.append(e)
 check(incoming.size()==2 and int(incoming[0].type)==0 and int(incoming[1].type)==1 and is_equal_approx(float(incoming[0].clock),beam_at) and is_equal_approx(float(incoming[1].clock),beam_at),"same-time debt precedes beam feedback")
 check(is_equal_approx(k.player_view().shield,15.0) and is_equal_approx(k.player_view().armour,100.0),"same-time memory occurs after debt and before beam")
 k.cancel()
 # Earlier beam leaves5 armour; later debt at.064 kills before same-time memory can heal.
 d=defence_event_world();d.player.armour=15.0;d.defences[1].loss=85.0;d.defences[1].memory_heal=0.1
 d.memory_interval=0.064;d.deferred_interval=0.064;d.deferred={1:{"armour":6.0}}
 k=core(d);incoming=[]
 for i in 4:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==2 and bool(e.player):incoming.append(float(e.clock))
 check(incoming.size()==2 and is_equal_approx(incoming[0],beam_at) and is_equal_approx(incoming[1],0.064),"later fatal debt cannot erase an earlier beam hit")
 check(is_zero_approx(k.player_view().armour) and k.export_handoff().is_empty(),"fatal debt stops same-time memory instead of resurrecting player")
 k.cancel()
func shield_phase_repeat_contract()->void:
 const STEP=1.0/60.0
 var d=world(3);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
 d.weapons[0].charge=0.045;d.weapons[0].interval=10.0;d.weapons[0].repeat_probability=1.0;d.repeat_delay=0.071
 var k=core(d);var births=[]
 for i in 7:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==0:births.append(float(e.clock))
 check(births.size()==1 and k.metrics().repeat_queue==1,"nonintegral beam repeat waits until true due time")
 k.advance(STEP)
 for e in k.take_feedback():
  if int(e.kind)==0:births.append(float(e.clock))
 # True deadline=.061666667+.071=.132666667; first legal boundary8/60=.133333333.
 check(births.size()==2 and is_equal_approx(births[1],8.0*STEP),"beam repeat uses actual period plus delay then first legal boundary")
 k.cancel()
 # Ejection at.1328 is after the repeat deadline but before the legal8/60 boundary.
 d=world(3);d.enemies[0].hp=1e9;d.enemies[0].max_hp=1e9
 d.weapons[0].charge=0.045;d.weapons[0].interval=10.0;d.weapons[0].repeat_probability=1.0;d.repeat_delay=0.071
 var split_missile=weapon(2);split_missile.slot=1;split_missile.salvo=2;split_missile.interval=10.0
 d.weapons.append(split_missile);d.ejection_gap=0.1328-STEP
 k=core(d);var repeat_times=[]
 for i in 8:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==0 and bool(e.shot.get("repeated",false)):repeat_times.append(float(e.clock))
 check(repeat_times.size()==1 and is_equal_approx(repeat_times[0],8.0*STEP),"ejection split cannot execute repeat before legal logical boundary")
 k.cancel()
 for key in ["memory_interval","deferred_interval"]:
  for value in [0.0,1e-10]:
   d=defence_event_world();d[key]=value;k=ClassDB.instantiate("SpaceCombatKernel")
   check(not k.configure(d),"reject nonprogressing defence period "+key)
   k.cancel()
 for pair in [["memory_elapsed","memory_interval"],["deferred_elapsed","deferred_interval"]]:
  for value in [-0.01,1.0,1.01]:
   d=defence_event_world();d[pair[1]]=1.0;d[pair[0]]=value;k=ClassDB.instantiate("SpaceCombatKernel")
   check(not k.configure(d),"reject defence phase outside half-open interval "+str(pair[0]))
   k.cancel()
 # A valid near-deadline phase drains once and then makes positive progress.
 d=defence_event_world();d.memory_interval=0.064;d.memory_elapsed=0.064-1e-12
 k=core(d);k.advance(STEP)
 check(is_equal_approx(k.metrics().defence_time,STEP) and is_equal_approx(k.metrics().memory_elapsed,STEP-1e-12),"near-boundary defence phase drains without zero-piece loop")
 k.cancel()
 # Fatal debt occurs before a pending ejection split; session still consumes requested step.
 d=defence_event_world();d.player.armour=15.0;d.defences[1].loss=85.0
 d.deferred_interval=0.064;d.deferred={1:{"armour":6.0}}
 var missile=weapon(2);missile.slot=1;missile.salvo=2;missile.interval=10.0
 d.weapons.append(missile);d.ejection_gap=0.0645-STEP
 k=core(d);k.advance(STEP);k.take_feedback();k.advance(3.0*STEP)
 check(is_zero_approx(k.player_view().armour) and is_equal_approx(k.metrics().clock,4.0*STEP) and is_equal_approx(k.metrics().defence_time,0.064),"death consumes logical-step tail while defence freezes at actual death time")
 k.cancel()
func chain_allowance_contract()->void:
 const STEP=1.0/60.0
 for kind in [0,1,2]:
  var d=world(kind);d.enemies=[actor(100,30,1e9,4),actor(101,100,1e9,0),actor(102,170,1e9,1)]
  d.chain_count=1;d.repeat_delay=0.1;d.ejection_gap=STEP
  d.weapons[0].interval=10.0;d.weapons[0].salvo=2;d.weapons[0].repeat_probability=1.0;d.weapons[0].repeat_multiplier=0.5
  d.weapons[0].secondary_probability=1.0;d.weapons[0].critical_rate=1.0;d.weapons[0].critical_multiplier=2.0
  var k=core(d);var chains=[]
  k.advance(STEP)
  var pending:Dictionary=k.export_handoff();var root_instances={};var primary_seen=false;var secondary_seen=false
  for row in pending.flights:
   if not bool(row.chain):
    root_instances[int(row.instance.id)]=true
    if bool(row.instance_derived):secondary_seen=true
    else:primary_seen=true
  for row in pending.ejections:
   root_instances[int(row.instance.id)]=true
   if bool(row.derived):secondary_seen=true
   else:primary_seen=true
  # Instant cannon carriers retire immediately; its visible chain still has the root instance.
  if kind!=1:check(root_instances.size()==1 and primary_seen and secondary_seen,"root and secondary share instance but retain separate carrier provenance "+str(kind))
  for e in k.take_feedback():
   if int(e.kind)==4:chains.append({"damage":float(e.shot.damage),"critical":bool(e.shot.critical)})
  for i in 119:
   k.advance(STEP)
   for e in k.take_feedback():
    if int(e.kind)==4:chains.append({"damage":float(e.shot.damage),"critical":bool(e.shot.critical)})
  check(k.metrics().root_attacks==2 and chains.size()==2,"normal salvo plus secondary share one allowance; independent repeat owns another "+str(kind))
  if chains.size()==2:check(is_equal_approx(chains[0].damage,20.0) and is_equal_approx(chains[1].damage,10.0) and chains[0].critical and chains[1].critical,"repeat chain inherits root critical outcome and its original multiplier "+str(kind))
  k.cancel()
 # A repeat killing its target may fan its own chain, but never a death explosion.
 var d=world(1);d.enemies=[actor(100,30,15,4),actor(101,100,100,5)];d.enemies[0].jewelExplosion=1.0
 d.chain_count=1;d.repeat_delay=0.1;d.weapons[0].interval=10.0;d.weapons[0].repeat_probability=1.0;d.weapons[0].repeat_multiplier=0.5
 var k=core(d)
 for i in 30:k.advance(STEP)
 check(k.enemy_views()[0].hp==0.0 and is_equal_approx(k.enemy_views()[1].hp,85.0),"derived lethal repeat fans once without opening death explosion permission")
 k.cancel()
 # Repeat30B is exactly one secondary hit, not a second continuous beam or extra link fanout.
 d=world(3);d.enemies=[actor(100,30,1e9,4),actor(101,100,1e9,0)];d.chain_count=1
 d.weapons[0].interval=0.05;d.weapons[0].secondary_probability=1.0
 k=core(d);var births=0;var secondary_hits=0
 for i in 7:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==0:births+=1
   if int(e.kind)==8:secondary_hits+=1
 check(births==1 and secondary_hits==1 and k.metrics().root_attacks==1 and k.metrics().hits==7,"Repeat30B single beam hit shares links without creating a sustained beam")
 k.cancel()
 # Ordinary Repeat startup retains its independent, fixed chain links.
 d=world(3);d.enemies=[actor(100,30,1e9,4),actor(101,100,1e9,3),actor(102,170,1e9,0)];d.chain_count=1;d.repeat_delay=0.1
 d.weapons[0].interval=0.05;d.weapons[0].repeat_probability=1.0
 k=core(d)
 for i in 7:k.advance(STEP)
 var beams:Array=k.projectile_views().filter(func(shot):return bool(shot.get("beam",false)))
 check(beams.size()==2 and k.metrics().root_attacks==2 and k.metrics().hits==8,"ordinary Repeat owns a second beam startup and fixed links")
 if beams.size()==2:check(beams[0].attack_instance.id!=beams[1].attack_instance.id and beams[0].attack_instance.chain.links.size()==1 and beams[1].attack_instance.chain.links.size()==1,"continuous repeat snapshots independent link allowance")
 var original_repeat:Dictionary={}
 for shot in beams:
  if bool(shot.repeated):original_repeat=shot
 check(k.hit_handle(k.actor_handle(100),1e12,1),"break repeat linked target")
 for i in 12:k.advance(STEP)
 # A new primary beam may legitimately bind other targets; the original repeat cannot.
 var retained_links:Array=original_repeat.get("attack_instance",{}).get("chain",{}).get("links",[])
 check(retained_links.size()==1 and int(retained_links[0].target.uid)==100 and bool(retained_links[0].broken),"original repeat retains its broken target identity without replacement")
 k.cancel()
func main_chain_permission_contract()->void:
 const Context=preload("res://scripts/combat_context.gd")
 var root=Context.root(71,"module:0","laser")
 var derived=Context.derive_with_chain(root,"repeat_or_secondary")
 var hop=Context.derive(derived,"chain")
 check(Context.can_chain(derived) and not Context.can_trigger(derived),"derived allowance does not grant new attack/death decisions")
 check(not hop.is_empty() and not Context.can_chain(hop) and not Context.can_trigger(hop) and hop.root_id==root.root_id,"chain hop keeps provenance and cannot recursively trigger")
 for compiled in [false,true]:
  var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
  g.stat_cache_enabled=true;g.save_enabled=false;g.invalidate_stat_cache()
  if compiled:g.enable_compiled_combat_rules()
  g.state=BattleGame.State.COMBAT
  var main_enemies:Array[Dictionary]=[actor(100,30,1000,4),actor(101,100,1000,3),actor(102,170,1000,0)]
  g.enemies=main_enemies
  var snapshot={"id":71,"damage":10.0,"critical":true,"critical_bonus_applied":true,"effects":[{"kind":"hyperspace_chain","chain":true,"chain_targets":1}],"combat_context":root}
  var instance=g.new_attack_instance(snapshot);var rng_before:int=g.rng.state
  var ordinary:Dictionary=g.attack_from_snapshot(snapshot,1.0,instance)
  var secondary:Dictionary=g.attack_from_snapshot(snapshot,1.0,instance)
  var repeated_instance=g.new_attack_instance(snapshot);var repeated:Dictionary=g.attack_from_snapshot(snapshot,1.0,repeated_instance)
  check(g.rng.state==rng_before and ordinary.attack_instance_id==secondary.attack_instance_id and repeated.attack_instance_id!=ordinary.attack_instance_id and repeated.critical==ordinary.critical,"main payloads retain root outcome and shared/fresh instances "+str(compiled))
  g.hit_enemy(g.enemies[0],ordinary.damage,1,ordinary.effects,ordinary.critical,root)
  g.hit_enemy(g.enemies[1],secondary.damage,1,secondary.effects,secondary.critical,derived)
  g.hit_enemy(g.enemies[0],repeated.damage,1,repeated.effects,repeated.critical,derived)
  var hops:Array=g.projectiles.filter(func(shot):return bool(shot.get("chain_hop",false)))
  check(hops.size()==2,"main ordinary/secondary consume one allowance, repeat consumes its own "+str(compiled))
  for shot in hops:g.advance_chain_projectile(shot,1.0)
  check(g.projectiles.size()==2 and g.enemies[1].hp==970.0 and g.enemies[2].hp==1000.0,"main chain arrival settles once without another fanout "+str(compiled))
  g.begin_retreat()
func chain_handoff_contract()->void:
 const STEP=1.0/60.0
 const Context=preload("res://scripts/combat_context.gd")
 for compiled in [false,true]:
  for kind in [0,2]:
   var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
   g.stat_cache_enabled=true;g.save_enabled=false;g.profile.loadout.weapons[0].key="missile" if kind==2 else "laser";g.invalidate_stat_cache()
   if compiled:g.enable_compiled_combat_rules()
   g.state=BattleGame.State.COMBAT
   var d=world(kind);d.execution_scope="native_low_contract";d.enemies=[actor(100,30,1000,4),actor(101,100,1000,0)]
   d.repeat_delay=0.1;d.ejection_gap=0.12;d.chain_count=1;d.weapons[0].interval=10.0
   d.weapons[0].source=-1;d.weapons[0].salvo=2;d.weapons[0].row.para1=2.0 if kind==2 else 720.0;d.weapons[0].row.dmgtype=1
   d.weapons[0].repeat_probability=1.0;d.weapons[0].secondary_probability=1.0;d.weapons[0].critical_rate=1.0
   d.weapons[0].transfer_effects=[{"kind":"hyperspace_chain","chain":true,"chain_targets":1}]
   check(g.admit_native_execution(d),"chain fixture native admission "+str(kind)+str(compiled))
   g.native_execution.advance(g,STEP)
   var owner=g.native_execution;var rng_before:int=g.rng.state
   check(owner.handoff_to_legacy(g,"chain_contract"),"chain in-flight/pending atomic handoff "+str(kind)+str(compiled))
   var instance_ids={};var primary_seen=false;var secondary_seen=false
   for shot in g.projectiles:
    if bool(shot.get("chain_hop",false)):continue
    instance_ids[int(shot.attack_instance_id)]=true
    if Context.can_trigger(shot.combat_context):primary_seen=true
    else:secondary_seen=true
    check(Context.can_chain(shot.combat_context),"handoff carrier keeps allowance permission")
   for pending in g.missile_queue:
    instance_ids[int(pending.attack.attack_instance_id)]=true
    if Context.can_trigger(pending.attack.combat_context):primary_seen=true
    else:secondary_seen=true
    check(Context.can_chain(pending.attack.combat_context),"handoff ejection keeps allowance permission")
   check(instance_ids.size()==1 and primary_seen and secondary_seen,"handoff shares instance while preserving root/secondary provenance")
   var previous_serial:int=g.attack_instance_serial
   g.advance_jewel_repeats(0.1)
   check(g.attack_instance_serial==previous_serial+1 and g.rng.state==rng_before,"post-handoff independent repeat builds one new instance without reroll")
   g.begin_retreat()
func chain_first_and_hop_transfer_contract()->void:
 const STEP=1.0/60.0
 const Context=preload("res://scripts/combat_context.gd")
 # Near secondary arrives before the farther primary, even when that secondary hit kills.
 var d=world(0);d.enemies=[actor(100,100,1000,4),actor(101,30,5,0)];d.chain_count=1
 d.weapons[0].interval=10.0;d.weapons[0].secondary_probability=1.0
 var k=core(d);var origins=[]
 for i in 30:
  k.advance(STEP)
  for e in k.take_feedback():
   if int(e.kind)==4:origins.append(e.position)
 check(origins.size()==1 and origins[0]==Vector2(30,0) and k.enemy_views()[0].hp==980.0,"lethal secondary first hit consumes shared root allowance at its own impact position")
 k.cancel()
 for compiled in [false,true]:
  var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
  g.stat_cache_enabled=true;g.save_enabled=false;g.invalidate_stat_cache()
  if compiled:g.enable_compiled_combat_rules()
  g.state=BattleGame.State.COMBAT
  var main_enemies:Array[Dictionary]=[actor(100,100,1000,4),actor(101,30,1000,0)]
  g.enemies=main_enemies
  var root=Context.root(87,"module:0","laser");var secondary_context=Context.derive_with_chain(root,"secondary")
  var snapshot={"id":87,"damage":10.0,"critical":false,"critical_bonus_applied":false,"effects":[{"kind":"hyperspace_chain","chain":true,"chain_targets":1}]}
  var instance=g.new_attack_instance(snapshot)
  var secondary:Dictionary=g.attack_from_snapshot(snapshot,1.0,instance)
  var primary:Dictionary=g.attack_from_snapshot(snapshot,1.0,instance)
  g.hit_enemy(g.enemies[1],secondary.damage,1,secondary.effects,false,secondary_context)
  g.hit_enemy(g.enemies[0],primary.damage,1,primary.effects,false,root)
  check(g.projectiles.size()==1 and Vector2(g.projectiles[0].x,g.projectiles[0].y)==Vector2(30,0),"main secondary first consumes root ledger without changing death/attack permissions "+str(compiled))
  g.begin_retreat()
  # Transfer an already-born chain carrier; its eventual lethal hit must not explode or fan.
  g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
  g.stat_cache_enabled=true;g.save_enabled=false;g.profile.loadout.weapons[0].key="cannon";g.invalidate_stat_cache()
  if compiled:g.enable_compiled_combat_rules()
  g.state=BattleGame.State.COMBAT
  d=world(1);d.execution_scope="native_low_contract";d.enemies=[actor(100,30,1000,4),actor(101,100,15,5)]
  d.enemies[0].drops=[];d.enemies[1].drops=[];d.enemies[1].jewelExplosion=1.0
  d.chain_count=1;d.weapons[0].source=-1;d.weapons[0].damage=20.0;d.weapons[0].interval=10.0
  d.weapons[0].transfer_effects=[{"kind":"hyperspace_chain","chain":true,"chain_targets":1}]
  check(g.admit_native_execution(d),"chain-hop native admission "+str(compiled))
  g.native_execution.advance(g,STEP);var owner=g.native_execution
  check(owner.handoff_to_legacy(g,"chain_hop_contract"),"chain-hop atomic handoff "+str(compiled))
  var hops:Array=g.projectiles.filter(func(shot):return bool(shot.get("chain_hop",false)))
  check(hops.size()==1,"chain-hop carrier remains present after transfer")
  if hops.size()==1:
   var context:Dictionary=hops[0].combat_context
   check(not context.is_empty() and int(context.root_id)>0 and not Context.can_chain(context) and not Context.can_trigger(context),"transferred chain context preserves provenance without leaking allowance")
   g.advance_chain_projectile(hops[0],1.0)
   check(g.enemies[1].hp<=0 and g.enemies[0].hp==980.0 and g.projectiles.size()==1,"transferred lethal chain neither death-explodes nor recursively fans")
  g.begin_retreat()
func fixed_ray_trace(cached:bool,scenario:int,kind:int)->Dictionary:
 var d=world(kind);d.enemies=[actor(100,300.0,1000.0,0),actor(101,550.0,1000.0,1)]
 d.weapons[0].speed=360.0;d.weapons[0].interval=0.2;d.weapons[0].source=-1;d.defences=[];d.repeat_delay=0.1
 if scenario==4:
  d.enemies[0].hp=15.0;d.weapons.append(d.weapons[0].duplicate(true));d.weapons[1].slot=1
 var k=core(d);var events:Array=[];var frames:Array=[]
 var hull=PackedVector2Array([Vector2(280,-12),Vector2(320,-12),Vector2(320,12),Vector2(280,12)])
 var other=PackedVector2Array([Vector2(530,-12),Vector2(570,-12),Vector2(570,12),Vector2(530,12)])
 var centers=PackedVector2Array([Vector2(300,0),Vector2(550,0)])
 var muzzles=PackedVector2Array([Vector2.ZERO])
 if scenario==4:muzzles.append(Vector2.ZERO)
 for step in 90:
  var fixed:bool=cached
  if scenario==1 and step<25: # Entry/moving target keeps the old predicate.
   fixed=false
   hull=PackedVector2Array([Vector2(280+step,-12),Vector2(320+step,-12),Vector2(320+step,12),Vector2(280+step,12)])
  if scenario==2 and step==25: # Geometry changes while rays are already in flight.
   hull=PackedVector2Array([Vector2(180,-25),Vector2(420,-25),Vector2(420,25),Vector2(180,25)])
  if scenario==3 and step==25:k.hit_handle(k.actor_handle(100),1e9,1)
  if scenario==5 and step==25:check(k.update_configuration(d),"fixed-ray numeric configuration boundary")
  if scenario==6 and step==25:check(k.configure(d),"fixed-ray encounter generation replacement")
  if scenario==7:hull=PackedVector2Array([Vector2(280,2),Vector2(320,2),Vector2(320,12),Vector2(280,12)]) # miss stays conservative
  if scenario==8:hull=PackedVector2Array([Vector2(-2,-2),Vector2(320,-2),Vector2(320,2),Vector2(-2,2)]) # starts inside
  if scenario==9:hull=PackedVector2Array([Vector2(280,0),Vector2(320,20),Vector2(320,40)]) # grazing vertex
  if scenario==10:
   centers[0]=Vector2(300,37);hull=PackedVector2Array()
   for corner in [Vector2(-20,-12),Vector2(20,-12),Vector2(20,12),Vector2(-20,12)]:hull.append(centers[0]+corner.rotated(0.73))
  if scenario==11:hull=PackedVector2Array([Vector2(280,-20),Vector2(320,-20),Vector2(320,20),Vector2(280,20),Vector2(300,0)]) # concave edge
  k.input_ballistic_geometry([hull,other],centers,muzzles,PackedByteArray([1 if fixed else 0,1 if fixed else 0]))
  k.input_geometry(centers,muzzles)
  k.advance(1.0/60.0)
  for event in k.take_feedback():
   events.append([step,event.kind,event.clock,event.position,event.amount,event.absorbed,event.get("uid",-1),event.get("target_uid",-1)])
  var positions:Array=[]
  for shot in k.projectile_views():positions.append([shot.serial,shot.motion_lease.position(),shot.motion_lease.direction(),shot.motion_lease.speed(),shot.get("dead",false)])
  var hp:Array=[]
  for enemy in k.enemy_views():hp.append([enemy.uid,enemy.hp,enemy.shield])
  frames.append([positions,hp,k.rng_source().state])
 var metrics:Dictionary=k.metrics();k.cancel()
 return {"events":events,"frames":frames,"metrics":metrics}

func fixed_ray_contract()->void:
 var saved_checks:=checks
 var total_skips:int=0;var total_checks:int=0;var total_queries:int=0
 for scenario in 12:
  for kind in [0,1,2,3]:
   var reference:Dictionary=fixed_ray_trace(false,scenario,kind)
   var cached:Dictionary=fixed_ray_trace(true,scenario,kind)
   check(reference.events==cached.events and reference.frames==cached.frames,"cached ray preserves exact ordered feedback, motion, HP and RNG: "+str(scenario)+"/"+str(kind))
   if kind in [2,3]:check(int(cached.metrics.ballistic_skips)==0,"missiles and beams retain dynamic/original branch")
   total_skips+=int(cached.metrics.ballistic_skips);total_checks+=int(cached.metrics.ballistic_checks);total_queries+=int(cached.metrics.ballistic_ray_queries)
 check(total_skips>0 and total_queries>0,"fixed target rays actually leave per-step polygon traversal")
 print("FIXED_RAY_RESULT ",JSON.stringify({"checks":checks-saved_checks,"skips":total_skips,"exact_checks":total_checks,"ray_queries":total_queries}))

func _initialize()->void:call_deferred("run")
func run()->void:
 var dll_path="res://bin/space_native.dll";var dll_hash=FileAccess.get_sha256(dll_path)
 var extension_path="res://space_native.gdextension" if FileAccess.file_exists("res://space_native.gdextension") else "res://addons/native_battle/space_native.gdextension"
 var expected=OS.get_environment("QA_NATIVE_SHA256")
 if not expected.is_empty():
  check(GDExtensionManager.is_extension_loaded(extension_path) and GDExtensionManager.get_extension(extension_path).is_library_open() and dll_hash==expected,"expected rebuilt project native library is loaded")
 print("NATIVE_LIBRARY_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"path":ProjectSettings.globalize_path(dll_path),"sha256":dll_hash}))
 check(ClassDB.class_exists("SpaceCombatKernel"),"native extension class registered")
 if not ClassDB.class_exists("SpaceCombatKernel"):quit(1);return
 fixed_ray_contract()
 timing_contract()
 hostile_beam_contract()
 lifecycle_contract()
 final_game_contract()
 shield_event_contract()
 player_defence_event_contract()
 shield_phase_repeat_contract()
 chain_allowance_contract()
 main_chain_permission_contract()
 chain_handoff_contract()
 chain_first_and_hop_transfer_contract()
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
