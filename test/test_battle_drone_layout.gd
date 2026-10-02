extends SceneTree
## Geometry regression: project actual meshes through the live battlefield camera.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<12:printerr("FAIL: ",label)
func bounds(node:Node3D,camera:Camera3D)->Rect2:
 var result:=Rect2()
 var initialized:=false
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if mesh.name=="PrototypeShield" or mesh.name=="BlueExhaust":continue
  var box:AABB=mesh.get_aabb()
  for i in 8:
   var point:Vector2=camera.unproject_position(mesh.global_transform*box.get_endpoint(i))
   if not initialized:result=Rect2(point,Vector2.ZERO);initialized=true
   else:result=result.expand(point)
 return result
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
 scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 scene.automation_args=[];scene.music.stop();scene.music.stream=null
 var g=scene.game;g.paused=true;g.save_enabled=false;g.speed=1.0
 g.profile.cleared=range(1,90);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.onboarding.completed=true
 var view=scene.ship_view
 var minimum_gap:=INF
 var maximum_step:=0.0
 for key in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
  g.switch_ship(key)
  for entry in g.weapon_entries():entry.key="laser";entry.level=1
  scene._process(0.0)
  var anchor:Vector2=scene.player_render_position()
  var height:float=scene.reference_height
  var actual_count:int=view.carriers.size()
  var profile:String=JSON.stringify(g.profile)
  var rng_state:int=g.rng.state
  for count in [0,1,3,8]:
   var entries:Array=[]
   for i in int(view.hull_config.hull_mount_budget)+count:entries.append({"key":["laser","cannon","missile","longLaser"][i%4],"level":1})
   view.set_loadout(entries,entries.size())
   check(view.carriers.size()==count,"configured count "+key)
   for x in [anchor.x,110.0,462.0]:
    var previous:Array=[]
    # Sample two complete patrols. This advances presentation time only.
    for step in 361:
     view.orbit_elapsed=float(step)*0.1
     view.set_pose(Vector2(x,anchor.y),height,0.0,Vector2(286,100),0,false,false)
     var hull:Rect2=bounds(view.ship,view.camera)
     var points:Array=[]
     for carrier in view.carriers:
      var box:Rect2=bounds(carrier,view.camera)
      check(Rect2(Vector2.ONE*11.0,view.size-Vector2.ONE*22.0).encloses(box),"whole drone clears viewport "+key)
      check(not hull.grow(25.0).intersects(box),"whole drone clears flagship "+key)
      minimum_gap=minf(minimum_gap,hull.position.y-box.end.y)
      var point:Vector2=view.camera.unproject_position(carrier.global_position)
      if not previous.is_empty():maximum_step=maxf(maximum_step,point.distance_to(previous[points.size()]))
      points.append(point)
     previous=points
  check(JSON.stringify(g.profile)==profile and g.rng.state==rng_state,"presentation leaves profile and RNG intact "+key)
  print("HULL ",key," shipped_carriers=",actual_count," center=",anchor," height=",height)
 check(maximum_step<8.0,"continuous orbit at edges")
 print("DRONE LAYOUT: ",checks," checks, ",failures," failures; min actual hull gap=",minimum_gap,"px; max step/0.1s=",maximum_step,"px")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
