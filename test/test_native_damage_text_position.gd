extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=preload("res://scripts/main.gd").new()
 var native=ClassDB.instantiate("SpaceCombatPresentation")
 var rng=RandomNumberGenerator.new();rng.seed=1701
 var original={"identity":1};var equal_copy=original.duplicate()
 for index in 240:
  var width:float=[0.0,18.0,70.0,160.0,600.0][index%5]
  var metrics={"width":width,"height":24.0,"ascent":19.0}
  var context={"metrics":{["test",19]:metrics},"occupied":[],"enemies":[]}
  var origin=Vector2(rng.randf_range(-20,620),rng.randf_range(-30,760))
  for i in index%13:context.enemies.append(Rect2(rng.randf_range(0,500),rng.randf_range(0,900),80,110))
  for i in index%11:context.occupied.append([original if i%2==0 else equal_copy,Rect2(rng.randf_range(0,500),rng.randf_range(0,900),95,32)])
  var excluded:Dictionary=original if index%3==0 else equal_copy if index%3==1 else {}
  var expected:Vector2=scene.damage_text_position(origin,"test",19,excluded,context)
  var actual:Vector2=native.damage_text_position(origin,metrics,Vector2(572,960),excluded,context.occupied,context.enemies)
  checks+=1
  if actual!=expected:failures+=1;printerr("FAIL ",index," expected ",expected," actual ",actual)
 print("NATIVE_DAMAGE_TEXT_POSITION ",JSON.stringify({"checks":checks,"failures":failures}))
 scene.free()
 quit(0 if failures==0 else 1)
