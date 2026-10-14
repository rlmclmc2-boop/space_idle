extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func fixture(key:String="missile",beam_chain:bool=false,shared_command:bool=false):
 var db=ShipDatabase.new();db.equipment.shield[0].para2=0.0
 var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout.weapons[0].key=key
 g.profile.loadout.defence=[{"key":"shield","level":1},{"key":"armour","level":1},{"key":"shield","level":1},{"key":"armour","level":1}]
 if beam_chain:
  g.profile.enhancementLevel=40;g.profile.cleared=range(1,61);g.profile.highestLevel=61
  g.rebuild_unlocks();g.set_enhancement_branch("weapons","repeat",1,"B")
  if key=="missile":g.set_enhancement_branch("weapons","repeat",3,"B")
 if key=="longLaser":g.profile.loadout.weapons=[{"key":"laser","level":1},{"key":"missile","level":1},{"key":"longLaser","level":1},{"key":"longLaser","level":15}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0},{"uid":101,"slot":3,"x":240.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 g.cooldowns[g.slot_id("weapons",0)]=0.0
 if key=="longLaser":
  g.cooldowns[g.slot_id("weapons",0)]=0.0;g.cooldowns[g.slot_id("weapons",1)]=0.0
  g.cooldowns[g.slot_id("weapons",2)]=0.0;g.cooldowns[g.slot_id("weapons",3)]=0.0
 var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
 if desc.has("error"):printerr("ADMISSION: ",desc)

 check(g.admit_native_compiled_execution("native_low_contract"),"fixture native admission")
 g.tick(1.0/60.0)
 return g
func _initialize()->void:call_deferred("run")
func run()->void:
 for key in (["longLaser"] if "--order-only" in OS.get_cmdline_user_args() else ["laser","cannon","missile","longLaser"]):
  var g=fixture(key);var core=g.native_execution.kernel
  check(core.has_method("presentation_membership"),"new extension membership")
  var observed=0;var max_beams=0;var orders={}
  for step in 180:
   g.tick(1.0/60.0)
   var before=core.export_handoff()
   var members=core.presentation_membership()
   check(before==core.export_handoff(),"membership is read-only")
   var expected=[];var beams=[]
   for shot in g.projectiles:
    if str(shot.key) in ["longLaser","longLaser_mon","longLaser-mon"]:beams.append(shot);expected.append(int(shot.serial))
    elif str(shot.key)=="cannon":expected.append(int(shot.serial))
    for actor in [shot.get("source",{}),shot.get("target",{})]:
     if actor.has("uid"):
      var found=false
      for row in g.enemies:
       if is_same(row,actor):found=true;break
      check(found,"flight actor retained by canonical encounter")
   max_beams=maxi(max_beams,beams.size())
   orders[str(beams.map(func(b):return int(b.serial)))]=true
   var actual=Array(members.muzzle_serials);actual.sort();expected.sort()
   check(actual==expected,"exact muzzle membership "+key)
   check(members.beams.size()==beams.size(),"exact beam count")
   for index in beams.size():check(is_same(core.presentation_beams()[index],beams[index]),"beam alpha order follows full canonical flight order")
   for beam in members.beams:
    var same=false
    for original in beams:
     if is_same(beam,original):same=true;break
    check(same,"beam retains canonical dictionary identity")
   observed+=g.projectiles.size()
  check(observed>0 or key=="cannon","nonempty retained-flight coverage "+key)
  print("MEMBERSHIP_CASE ",key," observed_rows=",observed)
  if key=="longLaser":
   check(max_beams>=2,"multiple overlapping beams covered")
   check(orders.size()>1,"compaction changed beam order during coverage")
   print("BEAM_ORDERS ",orders.keys())
  g.begin_retreat()
 print("PRESENTATION_MEMBERSHIP checks=",checks," failures=",failures)
 quit(failures)
