extends SceneTree
class HullAuthority extends RefCounted:
 var fx_time:=0.0
 var shape_calls:=0
 func enemy_frontline_y_limit(_enemy:Dictionary)->float:return 42.0
 func enemy_render_position(_enemy:Dictionary)->Vector2:return Vector2(100,12)
 func enemy_render_width(_enemy:Dictionary)->float:return 20.0
 func enemy_render_angle(_enemy:Dictionary)->float:return -PI
 func enemy_recognition_geometry(_enemy:Dictionary,_width:float=-1.0)->Dictionary:
  shape_calls+=1
  return {"inner":PackedVector2Array([Vector2(-10,-20),Vector2(10,-20),Vector2(10,20),Vector2(-10,20)])}
## Run in an isolated project with the built SpaceCombatKernel extension loaded.
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func hull(y:float)->PackedVector2Array:
 return PackedVector2Array([Vector2(90,y-20),Vector2(110,y-20),Vector2(110,y+20),Vector2(90,y+20)])
func run_case(y:float,should_hit:bool)->void:
 var k=ClassDB.instantiate("SpaceCombatKernel")
 var actors=[{"uid":100,"slot":4,"x":100.0,"y":0.0,"hp":100.0,"max_hp":100.0,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}]
 var weapon={"kind":0,"type":1,"slot":0,"source":-1,"hostile":false,"damage":10.0,"interval":10.0,"remaining":0.0,"speed":1200.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":"laser"},"row":{"cd":10.0,"para1":1.0}}
 check(k.configure({"clock":0.0,"rng_state":418,"resistance":0.5,"player":{"x":0.0,"y":0.0,"armour":100.0,"shield":0.0},"enemies":actors,"weapons":[weapon]}),"admit")
 k.input_geometry(PackedVector2Array([Vector2(100,0)]),PackedVector2Array([Vector2.ZERO]))
 k.input_ballistic_geometry([hull(0)],PackedVector2Array([Vector2(100,0)]),PackedVector2Array([Vector2.ZERO]))
 k.advance(1.0/60.0)
 var birth=k.take_feedback()[0].shot
 check(birth.owns_primary_aim and birth.fixed_screen_step==Vector2.RIGHT,"root owns aim and freezes ray")
 var original=k.projectile_views()[0].direction
 k.input_geometry(PackedVector2Array([Vector2(100,y)]),PackedVector2Array([Vector2.ZERO]))
 k.input_ballistic_geometry([hull(y)],PackedVector2Array([Vector2(100,y)]),PackedVector2Array([Vector2.ZERO]))
 var hit=false
 for i in 8:
  k.advance(1.0/60.0)
  for event in k.take_feedback():
   if event.kind==1:
    hit=true
    check(event.position.y==0.0 and event.position.x>=90.0 and event.position.x<=110.0,"impact lies on ray and visible hull")
  if not k.projectile_views().is_empty():check(k.projectile_views()[0].direction==original,"fixed direction never seeks moved center")
 check(hit==should_hit,"moving hull contact agrees with screen ray")
 k.cancel()
func ownership_case()->void:
 var k=ClassDB.instantiate("SpaceCombatKernel")
 var enemies=[{"uid":100,"slot":4,"x":100.0,"y":0.0,"hp":10000.0,"max_hp":10000.0,"armourType":2,"shieldType":1},{"uid":101,"slot":3,"x":150.0,"y":0.0,"hp":10000.0,"max_hp":10000.0,"armourType":2,"shieldType":1}]
 var weapon={"kind":0,"type":1,"slot":0,"source":-1,"hostile":false,"damage":10.0,"interval":10.0,"remaining":0.0,"speed":1200.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":"laser"},"row":{"cd":10.0,"para1":1.0},"secondary_probability":1.0,"repeat_probability":1.0,"chain_count":1}
 check(k.configure({"clock":0.0,"rng_state":418,"resistance":0.5,"chain_count":1,"repeat_delay":0.1,"repeat_multiplier":1.0,"player":{"x":0.0,"y":0.0,"armour":100.0,"shield":0.0},"enemies":enemies,"weapons":[weapon]}),"derived fixture admitted")
 var roots:=0;var derived:=0;var chains:=0
 for step in 30:
  k.advance(1.0/60.0)
  for event in k.take_feedback():
   if event.kind not in [0,4]:continue
   var shot:Dictionary=event.shot
   if shot.chain_hop:chains+=1
   if shot.repeated or shot.chain_hop:
    derived+=1;check(not shot.owns_primary_aim,"secondary, repeat and chain preserve primary turret owner")
   else:roots+=1;check(shot.owns_primary_aim,"main launch owns primary aim")
 check(roots==1 and derived>=3 and chains>0,"root, secondary, repeat and chain launches retained")
 k.cancel()
func _initialize()->void:
 check(ClassDB.class_exists("SpaceCombatKernel"),"native extension must be loaded")
 var presentation=ClassDB.instantiate("SpaceCombatPresentation")
 for y in [-600.0,-512.0,220.0,220.001,273.0,442.0,639.999,640.0,2048.0,2100.0]:
  var low:float=y-220.0;var high:float=y
  for i in 20:
   var middle:float=(low+high)*0.5
   var point:=Vector2(0,middle)
   var mapped:=Vector2(point.x,point.y+smoothstep(220.0,420.0,point.y)*220.0)
   if mapped.y<y:low=middle
   else:high=middle
  check(presentation.battle_logical_point(Vector2(45,y)).distance_to(Vector2(45,(low+high)*0.5))<0.001,"native reuse preserves twenty-step inverse at "+str(y))
 var outlines=[PackedVector2Array([Vector2(-13.5,-27.2),Vector2(8.0,19.5),Vector2(41.0,-2.0)]),PackedVector2Array([Vector2(-30.0,4.0),Vector2(7.0,35.0)]),PackedVector2Array()]
 for angle in [-PI,-0.4,0.0,0.73,PI,7.2]:
  var expected:=0.0
  for outline in outlines:
   for point in outline:expected=minf(expected,Vector2(point).rotated(angle).y)
  check(absf(presentation.rotated_outlines_min_y(outlines,angle)-expected)<0.00001,"native outline reduction preserves every rotated vertex")
 ownership_case()
 run_case(12,true)
 run_case(30,false)
 var model=preload("res://scripts/battle_read_model.gd").new();model.setup(HullAuthority.new())
 check(model._frontline({})==42.0,"legacy display host keeps its frontline contract")
 var shot={"target":{},"x":80.0,"y":0.0,"direction":Vector2.RIGHT,"speed":1200.0,"fixed_screen_step":Vector2.RIGHT,"fixed_screen_origin":Vector2.ZERO,"launch_point":Vector2.ZERO}
 check(is_equal_approx(model.ballistic_contact(shot,1.0/60.0),0.5),"handoff screen ray hits same moved hull boundary")
 model.ballistic_contact(shot,1.0/60.0)
 check(model.host.shape_calls==1,"two shots share one exact-clock hull publication")
 model.host.fx_time=1.0
 model.ballistic_contact(shot,1.0/60.0)
 check(model.host.shape_calls==2,"moving-clock geometry never reuses a stale hull")
 print("BATTLE CONSISTENCY: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
