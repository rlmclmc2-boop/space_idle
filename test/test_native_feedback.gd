extends SceneTree
const Session=preload("res://scripts/native_execution_session.gd")
class Observer extends RefCounted:
 signal event(kind,info)
 var drops:Array=[]
 var received:Array=[]
 func projectile_speed(_shot):return 123.0
 func capture(kind,info):
  if kind=="fire":info.shot.prototype_missile=true
  received.append([kind,normalize(info)])
 func normalize(value):
  if value is Dictionary:
   var result={}
   for key in value:result[key]=normalize(value[key])
   return result
  if value is Array:
   var result=[]
   for item in value:result.append(normalize(item))
   return result
  if value is Object:return value.get_class()
  return value
var checked=0
var observed={}
func actor(uid,x):return {"uid":uid,"slot":4,"x":x,"y":0.0,"hp":100000.0,"max_hp":100000.0,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}
func weapon(kind,hostile=false):return {"kind":kind,"type":1,"slot":0,"source":0,"hostile":hostile,"damage":10.0,"interval":0.05,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"chain_count":2,"critical_chance":1.0,"muzzle":Vector2.ZERO,"entry":{"key":["laser","cannon","missile","longLaser"][kind]},"row":{"cd":0.05,"para1":1.0,"para2":1.0,"para3":0.0}}
func _initialize():call_deferred("run")
func run():
 for kind in 4:
  var sessions=[];var observers=[]
  for direct in [false,true]:
   var d={"clock":0.0,"rng_state":418,"resistance":0.5,"player":{"x":50.0,"y":0.0,"armour":100000.0,"shield":100000.0,"armour_type":2,"shield_type":1},"enemies":[actor(100,30.0),actor(101,60.0)],"weapons":[weapon(kind),weapon(kind,true)]}
   var session=Session.new();session.kernel=ClassDB.instantiate("SpaceCombatKernel")
   assert(session.kernel.configure(d));session.direct_feedback=direct
   session.actor_by_uid={100:d.enemies[0],101:d.enemies[1]}
   var observer=Observer.new();observer.event.connect(observer.capture)
   sessions.append(session);observers.append(observer)
  for step in 180:
   for i in 2:
    var session=sessions[i]
    session.kernel.advance(1.0/60.0)
    if step==90:session.kernel.hit_handle(session.kernel.actor_handle(100),1e9,1)
    if step==110:session.kernel.hit_handle(session.kernel.actor_handle(101),1e9,1)
    session.consume_feedback(observers[i])
   assert(observers[0].received==observers[1].received,"event payload/order mismatch kind %d step %d"%[kind,step])
   assert(observers[0].normalize(observers[0].drops)==observers[1].normalize(observers[1].drops),"drop mismatch")
   assert(sessions[0].feedback_rows==sessions[1].feedback_rows,"effect count mismatch")
   checked+=1
  for row in observers[0].received:observed[row[0]]=observed.get(row[0],0)+1
  for session in sessions:session.kernel.cancel()
 print("NATIVE_FEEDBACK_OK checks=",checked," events=",observed)
 quit()
