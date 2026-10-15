extends SceneTree
# Same native authority, compact compatibility off/on; no shadow Game.
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func actor(uid:int=100,x:float=30.0,hp:float=100.0,slot:int=4)->Dictionary:
 return {"uid":uid,"slot":slot,"x":x,"y":0.0,"hp":hp,"max_hp":hp,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}
func weapon(kind:int=0)->Dictionary:
 return {"kind":kind,"type":1,"slot":0,"source":0,"hostile":false,"damage":10.0,"interval":2.0,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":"laser"},"row":{"cd":2.0,"para1":1.0,"para2":1.0,"para3":0.0}}
func world()->Dictionary:
 return {"clock":0.0,"rng_state":418,"resistance":0.5,"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0,"armour_type":2,"shield_type":1},"enemies":[actor()],"weapons":[weapon()]}
func core(d:Dictionary):
 var k=ClassDB.instantiate("SpaceCombatKernel")
 check(k.configure(d),"admission")
 return k
func plain(v):
 if v is Dictionary:
  var out={}
  for key in v:out[key]=plain(v[key])
  return out
 if v is Array:
  var out=[]
  for item in v:out.append(plain(item))
  return out
 if v is RandomNumberGenerator:return {"rng_state":v.state}
 if v is Object:
  if v.has_method("position") and v.has_method("direction"):return [v.position(),v.direction(),v.speed()]
  return v.get_class()
 return v
func geometry(k):
 var hulls=[]
 for x in [300,550]:hulls.append(PackedVector2Array([Vector2(x-20,-12),Vector2(x+20,-12),Vector2(x+20,12),Vector2(x-20,12)]))
 var points=PackedVector2Array([Vector2(300,0),Vector2(550,0)])
 k.input_ballistic_geometry(hulls,points,PackedVector2Array([Vector2.ZERO]),PackedByteArray([1,1]))
 k.input_geometry(points,PackedVector2Array([Vector2.ZERO]))
func feedback(k):
 var rows=[]
 for row in k.take_feedback():
  # Public payloads differ intentionally; authoritative ordered facts must not.
  var out=row.duplicate();out.erase("shot");out.erase("native_laser")
  rows.append(plain(out))
 return rows
func pair_contract(scenario:int):
 var d=world();d.enemies=[actor(100,300,1000,0),actor(101,550,1000,1)]
 d.defences=[];d.repeat_delay=0.1
 d.weapons[0].source=-1;d.weapons[0].speed=360.0;d.weapons[0].interval=0.2
 d.weapons[0].entry.level=1
 if scenario==0:d.weapons[0].critical_rate=1.0
 d.weapons[0].repeat_probability=1.0 if scenario in [2,3] else 0.0
 d.weapons[0].secondary_probability=1.0 if scenario in [1,3] else 0.0
 var a=core(d);var b=core(d);geometry(a);geometry(b)
 check(b.set_compact_laser_births(true)>=0,"enable compact")
 var saw_repeat=false;var saw_secondary=false;var saw_new_entry_old_attack=false
 var saw_impact=false;var saw_critical=false
 for step in 120:
  if scenario==3 and step==2:
   d.weapons[0].entry.level=2;d.weapons[0].damage=20.0;d.weapons[0].row.para1=2.0
   check(a.update_configuration(d) and b.update_configuration(d),"queued upgrade accepted")
  if scenario==4 and step==10:
   a.hit_handle(a.actor_handle(100),1e9,1);b.hit_handle(b.actor_handle(100),1e9,1)
  check(a.advance(1.0/60.0) and b.advance(1.0/60.0),"step accepted")
  var old_events=feedback(a);var new_events=feedback(b)
  check(old_events==new_events,"ordered feedback equal %d/%d"%[scenario,step])
  for event in old_events:
   if event.kind==8:saw_secondary=true
   if event.kind==1:saw_impact=true
   if event.kind==2 and event.critical:saw_critical=true
  var ea=a.export_handoff();var eb=b.export_handoff()
  check(plain(ea)==plain(eb),"complete handoff equal %d/%d"%[scenario,step])
  check(a.rng_source().state==b.rng_source().state and a.metrics()==b.metrics(),"RNG and live authority equal")
  check(b.presentation_projectile_rows().is_empty(),"export is nonmaterializing")
  for row in eb.flights:
   var view=row.view
   if view.repeated:
    saw_repeat=true;check(view.combat_context.trigger_depth==1,"repeat depth one")
   else:check(view.combat_context.trigger_depth==0,"ordinary depth zero")
   if scenario==3 and view.entry.level==2 and row.snapshot.damage==10.0:saw_new_entry_old_attack=true
 if scenario in [2,3]:check(saw_repeat,"repeat actually born")
 if scenario in [1,3]:check(saw_secondary,"secondary actually born")
 if scenario==0:check(saw_impact and saw_critical,"native impact and critical hit occur")
 if scenario==3:check(saw_new_entry_old_attack,"old queued attack uses actual carrier birth entry")
 var before=plain(b.export_handoff());var full=b.projectile_views()
 check(full is Array and full.size()==int(b.metrics().active_flights),"explicit full request materializes every live body")
 check(b.presentation_projectile_rows().size()==full.size(),"display downgrade publishes complete rows")
 check(plain(b.export_handoff())==before,"materialization preserves authoritative state")
 check(plain(a.projectile_views())==plain(full),"complete old/new compatibility views equal")
 a.cancel();b.cancel()
 check(b.set_compact_laser_births(false)>=0 and b.set_compact_laser_births(true)>=0,"terminal owner closes without blocking")
 check(b.presentation_projectile_rows().is_empty(),"terminal rows empty")
func cancel_contract():
 var d=world();d.enemies=[actor(100,300,1000,0),actor(101,550,1000,1)]
 var k=core(d);geometry(k);k.set_compact_laser_births(true);k.advance(1.0/60.0);k.cancel()
 var events=k.take_feedback();var births=0;var retirements=0
 for e in events:
  if e.kind==0:births+=1;check(e.has("native_laser") and e.native_laser.serial>0,"birth payload survives same-frame retirement")
  if e.kind==5:retirements+=1;check(e.has("native_laser"),"neutral retirement has value-owned identity")
 check(births==1 and retirements==1 and k.metrics().active_flights==0,"born/cancelled once with no live body")
 var g=BattleGame.new(ShipDatabase.new(),false);var seen=[]
 g.event.connect(func(kind,info):seen.append(kind))
 var owner=preload("res://scripts/native_execution_session.gd").new()
 # Replay an actual captured birth/retirement packet through the production consumer.
 var impact=events[0].duplicate();impact.kind=1
 var critical=events[0].duplicate();critical.kind=9
 var bridge=PacketKernel.new();bridge.events=events+[impact,critical];owner.kernel=bridge;owner.consume_feedback(g)
 check(seen==["fire","projectile_impact","critical_impact"],"native laser fire, impact, pass and critical packets map once")
func cold_handoff_contract():
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.stat_cache_enabled=true;g.save_enabled=false;g.profile.loadout.weapons[0].key="laser";g.invalidate_stat_cache()
 g.state=BattleGame.State.COMBAT
 var d=world();d.execution_scope="native_low_contract"
 d.enemies=[actor(100,300,1000,0),actor(101,550,1000,1)]
 d.weapons[0].source=-1;d.weapons[0].speed=180.0;d.weapons[0].interval=10.0
 check(g.admit_native_execution(d),"cold handoff admission")
 var owner=g.native_execution;geometry(owner.kernel)
 check(owner.kernel.set_compact_laser_births(true)>=0,"cold handoff compact enabled")
 check(owner.advance(g,1.0/60.0),"cold handoff birth step")
 var snapshot=owner.kernel.export_handoff()
 check(snapshot.flights.size()>0 and owner.kernel.presentation_projectile_rows().is_empty(),"cold handoff begins with typed-only live flights")
 var serials=[]
 for row in snapshot.flights:serials.append(row.view.serial)
 check(owner.handoff_to_legacy(g,"compact_laser_contract"),"cold handoff commits one owner")
 var received=[]
 for shot in g.projectiles:received.append(shot.serial)
 check(received==serials and g.native_execution==null,"cold handoff retains all flight identities")
 g.begin_retreat()
class PacketKernel extends RefCounted:
 var events:Array=[]
 func take_feedback():var out=events;events=[];return out
func _initialize()->void:call_deferred("run")
func run():
 check(ClassDB.class_exists("SpaceCombatKernel"),"candidate class loaded")
 print("COMPACT_NATIVE_SHA256 ",FileAccess.get_sha256("res://bin/space_native.dll"))
 for scenario in 5:pair_contract(scenario)
 cancel_contract()
 cold_handoff_contract()
 print("COMPACT_LASER_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(1 if failures else 0)
