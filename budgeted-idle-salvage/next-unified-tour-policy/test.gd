extends SceneTree
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const Config=preload("res://scripts/hyperspace_config.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
class FakeH:
 extends RefCounted
 var config:Dictionary=Config.load_config()
 var fail:=false
 func preview_forge(_g,_request):return {"error":"","cost":{}}
 func forge(g,request):
  if fail:return {"error":"fixture_rejection"}
  g.profile.hyperspace.inventory.warehouse.erase(request.drone_id)
  g.profile.hyperspace.inventory.drones.erase(request.drone_id)
  g.profile.hyperspace.command_seq+=1
  return {"error":""}
class FakeG:
 extends RefCounted
 var hyperspace:=FakeH.new()
 var profile:Dictionary={"highestLevel":60,"selectedShip":"fixture-zero-hull","hyperspace":{"round_id":1,"command_seq":0,"active":{},"inventory":{"drones":{},"warehouse":[],"overflow":[],"equipped":[],"favorites":[],"presets":[],"sealed":{},"reforge_count":0}}}
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func add(g,id:String,level:int,quality:String="white",weapon:String="laser"):
 var rng=RandomNumberGenerator.new();rng.seed=101
 var d=Rewards.create_drone(rng,g.hyperspace.config,id,quality,weapon,level,"fixture")
 g.profile.hyperspace.inventory.drones[id]=d;g.profile.hyperspace.inventory.warehouse.append(id)
func _initialize():
 var g=FakeG.new();var bag:Dictionary=g.profile.hyperspace.inventory;var p=Policy.new();p.idle_salvage_enabled=true
 for i in range(6):add(g,"w"+str(i),i+1)
 bag.drones.w5.level=200
 add(g,"equipped",20);bag.equipped=["equipped"]
 add(g,"favorite",1);bag.favorites=["favorite"]
 add(g,"preset",1);bag.presets=[{"drone_ids":["preset"]}]
 add(g,"sealed",1);bag.sealed={"sealed":999}
 add(g,"ultimate",1);bag.drones.ultimate.ultimate=true
 add(g,"mounted",1);bag.drones.mounted.hangings=["distributed_algorithm"]
 add(g,"cannon-backup",1,"white","cannon")
 add(g,"blue",1,"blue")
 var candidates:Array=p.salvage_candidates(g,true)
 check(candidates==["w0","w1","w2","w3","w4"],"Protected objects, best unequipped backup, other weapon backup and blue all retained")
 for i in range(3):
  var choice:Dictionary=p.idle_salvage_choice(g,100.0+float(i)*0.3,90.0)
  check(choice.request.drone_id=="w"+str(i),"Finite same-tour visible-score order")
  check(p.execute(g,choice,100.0+float(i)*0.3),"Successful transaction charged")
 check(p.idle_salvage_choice(g,100.9,90.0).is_empty(),"Fourth same-tour salvage blocked")
 var resumed=Policy.new();CP.apply_fields(resumed,CP.fields(p,CP.POLICY),CP.POLICY)
 check(resumed.idle_salvage_enabled and resumed.idle_salvage_choice(g,200,90).is_empty(),"Checkpoint restore keeps opt-in and spent tour budget")
 var next:Dictionary=p.idle_salvage_choice(g,400,390)
 check(next.request.drone_id=="w3" and p.idle_salvage_budget.used==0,"Next actual tour restores budget")
 g.hyperspace.fail=true;check(not p.execute(g,next,400) and p.idle_salvage_budget.used==0 and bag.drones.has("w3"),"Failed transaction preserves budget and object")
 g.hyperspace.fail=false
 # Full-storage recovery is tested independently of idle mode and its spent budget.
 var full=FakeG.new();var fullbag:Dictionary=full.profile.hyperspace.inventory
 for i in range(int(full.hyperspace.config.warehouse_capacity)):add(full,"full"+str(i),i+1,"blue")
 fullbag.overflow.resize(int(full.hyperspace.config.overflow_capacity));fullbag.overflow.fill("fixture")
 p.idle_salvage_budget={"round":1,"used":3,"tour_started":390.0}
 for enabled in [true,false]:
  p.idle_salvage_enabled=enabled
  var recovery:Dictionary=p.space_action(full,400,390)
  check(recovery.get("storage_pressure",false) and not recovery.get("idle_salvage",false) and recovery.request.drone_id=="full0","Full storage retains legal nonwhite recovery independently of idle budget/flag")
 print("TOUR_SALVAGE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
