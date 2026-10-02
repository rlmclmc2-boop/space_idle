extends SceneTree
## Exact optimization gate: compare against the original20-step projection inverse.
const UI=preload("res://scripts/main.gd")
var failures:=0
var checks:=0
func reference(point:Vector2)->Vector2:
 var low:=point.y-220.0
 var high:=point.y
 for iteration in 20:
  var middle:=(low+high)*.5
  var visual:=Vector2(0,middle)
  visual=Vector2(visual.x,visual.y+smoothstep(220.0,420.0,visual.y)*220.0)
  if visual.y<point.y:low=middle
  else:high=middle
 return Vector2(point.x,(low+high)*.5)
func _initialize()->void:call_deferred("run")
func run()->void:
 var ui:=UI.new()
 var rng:=RandomNumberGenerator.new();rng.seed=1701
 for y in [-10000.0,-512.001,-512.0,-511.999,0.0,219.999,220.0,220.001,639.999,640.0,640.001,2047.999,2048.0,2048.001,10000.0]:
  compare(ui,Vector2(137.25,y))
 for i in 10000:compare(ui,Vector2(rng.randf_range(-1000,1000),rng.randf_range(-1024,4096)))
 ui.free()
 print("BATTLE COORDINATE INVERSE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func compare(ui:Node,point:Vector2)->void:
 checks+=1
 var expected:Vector2=reference(point)
 var actual:Vector2=ui.battle_logical_point(point)
 if expected!=actual:
  failures+=1
  if failures<10:printerr("FAIL exact inverse ",point," expected ",expected," actual ",actual)
