extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
var tested:=0
var failed:=0
func check(ok:bool,label:String):
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func muzzle_points(visual,view)->Dictionary:
 var points:Dictionary={}
 for id in visual.identities:
  var sockets:Array=visual.muzzles.get(id,[]);points[id]=[]
  for i in sockets.size():points[id].append(visual.screen_muzzle_for_drone(id,i,view))
 return points
func run():
 var source=OS.get_environment("QA_DRONE_SOURCE");var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
 check(FileAccess.get_sha256(source)=="e82869cd8e6406154e273eb81f02d6767c770a83450bb7fcf4a254ed43ac5f19","Exact actual57600 source bytes")
 var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.stat_cache_enabled=true;check(g.load_hyperspace_routes(),"Actual routes load")
 g.load_progress_data(raw.save);g.resume_progress();g.rng.state=int(str(raw.rng_state))
 var driver=Driver.new();driver.setup(self,g);await process_frame;await process_frame;driver.before_tick(0.0)
 var visual=driver.scene.hyperspace_visual;var view=driver.scene.ship_view;var equipped:Array=g.profile.hyperspace.inventory.equipped.duplicate()
 var expected=muzzle_points(visual,view);check(equipped.size()==4 and visual.identities==equipped,"Four actually owned equipped drones, not injected samples")
 for i in 3:
  check(g.hyperspace.set_equipped(g,[]),"Actual legal unequip command "+str(i))
  var profile=g.profile.duplicate(true);var rng=str(g.rng.state)
  check(visual.sync(g.profile.hyperspace.inventory),"Changed inventory frees previous drone meshes")
  check(visual.nodes.is_empty() and visual.identities.is_empty() and visual.muzzles.is_empty(),"No obsolete nodes/identities/muzzle sockets remain")
  check(profile==g.profile and rng==str(g.rng.state),"Visual free changes no business profile or global RNG")
  check(g.hyperspace.set_equipped(g,equipped),"Actual legal re-equip command "+str(i))
  profile=g.profile.duplicate(true);rng=str(g.rng.state)
  check(visual.sync(g.profile.hyperspace.inventory),"Real mesh instances rebuilt")
  visual.pose(view,g.drone_combat.disabled,1.0)
  check(visual.nodes.size()==4 and visual.identities==equipped,"Owned-source identities and node counts restored")
  check(muzzle_points(visual,view)==expected,"Actual authored muzzle projections unchanged by material lifetime")
  check(profile==g.profile and rng==str(g.rng.state),"Visual rebuild/pose changes no business profile or global RNG")
  check(not visual.sync(g.profile.hyperspace.inventory),"Same source signature does not rebuild meshes")
 driver.close();await process_frame;print("DRONE_MATERIAL_REBUILD ",tested," checks ",failed," failures");quit(2 if failed else 0)
