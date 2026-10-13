extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func clean(value):
 if value is Dictionary:
  var out={}
  for key in value:out[key]=clean(value[key])
  return out
 if value is Array:
  var out=[]
  for item in value:out.append(clean(item))
  return out
 if value is Object:return value.get_class()
 return value
func fixture()->Dictionary:
 var d={"clock":0.0,"rng_state":418,"resistance":0.5,"repeat_delay":0.011,"ejection_gap":0.009,"player":{"x":50.0,"y":0.0,"armour":1e9,"shield":1e9,"armour_type":2,"shield_type":1},"enemies":[],"weapons":[],"defences":[]}
 for i in 3:d.enemies.append({"uid":100+i,"slot":i,"x":30.0+i*50,"y":50.0,"hp":1e9,"max_hp":1e9,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0})
 for hostile in [false,true]:
  for kind in 4:
   d.weapons.append({"kind":kind,"type":1,"slot":kind,"source":0 if hostile else -1,"hostile":hostile,"damage":10.0,"interval":0.07,"remaining":0.0,"speed":720.0,"charge":0.025,"ramp":0.1,"maximum":2.0,"salvo":3,"muzzle":Vector2.ZERO,"entry":{"key":["laser","cannon","missile","longLaser"][kind],"level":1},"row":{"cd":0.07,"para1":1.0,"para2":1.0,"para3":0.0},"repeat_probability":1.0,"secondary_probability":1.0,"repeat_multiplier":0.7,"chain_count":2})
 return d
func _initialize()->void:call_deferred("run")
func run()->void:
 const DT=1.0/60.0
 var d=fixture();var full=ClassDB.instantiate("SpaceCombatKernel");var sparse=ClassDB.instantiate("SpaceCombatKernel")
 check(full.configure(d) and sparse.configure(d),"pair admitted")
 var supplied:=0
 for step in 180:
  if step==12:
   for w in d.weapons:w.damage=30.0;w.interval=0.09;w.entry.level=2
   var full_update:bool=full.update_configuration(d.duplicate(true))
   var sparse_update:bool=sparse.update_configuration(d.duplicate(true))
   check(full_update and sparse_update,"numeric update with old births pending")
  if step==60:
   for k in [full,sparse]:k.hit_handle(k.actor_handle(100),1e12,1)
  var before=clean(sparse.export_handoff());var rng=sparse.rng_source().state
  var indices:PackedInt32Array=sparse.required_muzzles(DT)
  check(indices==sparse.required_muzzles(DT) and before==clean(sparse.export_handoff()) and rng==sparse.rng_source().state,"query has no state/RNG side effect")
  var points=PackedVector2Array([Vector2(30,50),Vector2(80,50),Vector2(130,50)])
  var all=PackedVector2Array();var selected=PackedVector2Array()
  for i in d.weapons.size():all.append(Vector2(step*0.11+i*2,step*0.07))
  for i in indices:selected.append(all[i])
  supplied+=indices.size()
  full.input_geometry(points,all);sparse.input_geometry(points,PackedVector2Array());sparse.input_muzzles(indices,selected,selected)
  full.input_ballistic_geometry([],points,all)
  sparse.input_ballistic_geometry([],points,PackedVector2Array())
  check(full.advance(DT) and sparse.advance(DT),"step admitted")
  check(clean(full.take_feedback())==clean(sparse.take_feedback()),"full/sparse events equal")
  check(clean(full.export_handoff())==clean(sparse.export_handoff()),"full/sparse complete handoff state equal")
  var expected=[]
  for shot in sparse.projectile_views():
   if shot.get("beam",false) and not shot.hostile and not shot.get("repeated",false) and not shot.get("chain_hop",false) and not shot.dead:expected.append(shot)
  var actual=sparse.primary_beam_views()
  var same:bool=actual.size()==expected.size()
  for i in mini(actual.size(),expected.size()):same=same and is_same(actual[i],expected[i])
  check(same,"indexed primary beams preserve exact view identity/order")
 check(supplied<180*d.weapons.size(),"inactive weapons omitted")
 full.cancel();sparse.cancel()
 check(sparse.required_muzzles(DT).is_empty() and sparse.primary_beam_views().is_empty(),"cancel clears demand and beams")
 print("MUZZLE DEMAND ",checks," checks ",failures," failures supplied ",supplied)
 quit(1 if failures else 0)
