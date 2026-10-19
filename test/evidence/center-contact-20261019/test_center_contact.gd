extends SceneTree
class Host extends RefCounted:
 var point:=Vector2(100,200)
 var outlines_read:=0
 func enemy_render_position(_enemy:Dictionary)->Vector2:return point
 func enemy_recognition_geometry(_enemy:Dictionary)->Dictionary:
  outlines_read+=1
  return {"inner":PackedVector2Array([Vector2(-100,-100),Vector2(100,-100),Vector2(0,100)])}
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:
 var h=Host.new()
 var m=preload("res://scripts/battle_read_model.gd").new();m.setup(h)
 var e={"uid":1,"x":10,"y":20}
 var shape=m.ballistic_shape(e)
 check(shape.hull.size()==4,"fixed tolerance")
 check(h.outlines_read==0,"no texture outline queried")
 check(is_same(shape,m.ballistic_shape(e)),"stationary centre cached")
 var shot={"target":e,"direction":Vector2.DOWN,"fixed_screen_step":Vector2.DOWN,"fixed_screen_origin":Vector2(100,100),"launch_point":Vector2(100,100),"x":100.0,"y":100.0,"speed":100.0}
 check(m.ballistic_contact(shot,0.5)>1.0,"crossing old outline does not hit")
 check(absf(m.ballistic_contact(shot,1.0)-0.995)<0.0001,"centre tolerance reached")
 e.texture="different";e.size=999
 check(is_same(shape,m.ballistic_shape(e)),"art and size changes do not change contact")
 h.point=Vector2(150,200)
 check(m.ballistic_shape(e).center==h.point,"moving anchor updates contact")
 check(m.ballistic_contact(shot,1.0)>1.0,"old ray misses moved centre")
 print("CENTER_CONTACT ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
