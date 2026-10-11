extends SceneTree
var checks:=0
var failures:=0
var calls:=0
var offset:=Vector2(31,47)
func point(target:Dictionary)->Vector2:
 calls+=1
 return Vector2(target.x,target.y)+offset
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func shot(target:Dictionary,key:String,origin:Vector2)->Dictionary:
 return {"serial":checks+1,"x":origin.x,"y":origin.y,"direction":Vector2.UP,"speed":100.,"prototype_missile":key=="missile","motion_age":0.,"orphan_age":0.,"last_target_point":Vector2.ZERO,"target":target,"key":key,"hostile":false,"damage":1.,"type":1,"dead":false,"chain_hop":key=="chain","jewelEffects":[],"critical":false}
func _initialize()->void:call_deferred("run")
func run()->void:
 for boundary in ["geometry","shape","player","roster","coordinates","event"]:
  var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
  assert(g.native_pipeline!=null,"Native publication gate requires the compiled extension")
  g.profile.highestLevel=8;g.rebuild_unlocks();g.start(8,false);g.spawn_group()
  for e in g.enemies:e.hp=1e100;e.max_shield=0
  g.target_provider=point
  # A minimal revision source isolates the publication contract from rendering.
  var spatial=RevisionSource.new();g.target_spatial_source=spatial
  var first_target:Dictionary=g.enemies[0];var next_target:Dictionary=g.enemies[1]
  var first=shot(first_target,"chain",point(first_target))
  var second=shot(next_target,"missile",Vector2(200,600))
  var third=shot(next_target,"missile",Vector2(220,600))
  for p in [first,second,third]:g.bind_projectile_motion(p);g.projectiles.append(p)
  var triggered=[false]
  var observer=func(kind,info):
   if kind!="hit" or bool(info.player) or triggered[0]:return
   triggered[0]=true;offset+=Vector2(13,19)
   match boundary:
    "geometry":spatial.geometry_revision+=1
    "shape":spatial.shape_revision+=1
    "player":g.player=g.player.duplicate(true)
    "roster":g.enemies.reverse()
    "coordinates":next_target.x+=5
    "event":g.event.emit("equipment_stats",{"counter_only":false})
  g.event.connect(observer)
  calls=0;var rng=g.rng.state
  g.tick_projectiles(1./60.)
  var expected=Vector2(next_target.x,next_target.y)+offset
  check(triggered[0],boundary+": real ordered contact callback executed")
  check(second.motion_lease.last_aim()==expected and third.motion_lease.last_aim()==expected,boundary+": later native flyers use current canonical geometry")
  check(calls==g.enemies.size()+1,boundary+": canonical fallback once per unique target after callback")
  check(g.rng.state==rng,boundary+": geometry fallback consumes no RNG")
  g.event.disconnect(observer)
 # Failed/absent publication must still call the canonical provider, not x/y.
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.highestLevel=8;g.rebuild_unlocks();g.start(8,false);g.spawn_group();g.target_provider=point
 var target:Dictionary=g.enemies[0];target.hp=1e100
 var p=shot(target,"missile",Vector2(200,600));g.bind_projectile_motion(p);g.projectiles.append(p)
 g.end_projectile_target_points();calls=0
 g.native_pipeline.advance(g,1./60.,false,g.projectiles.duplicate())
 check(calls==1 and p.motion_lease.last_aim()==Vector2(target.x,target.y)+offset,"inactive publication preserves canonical provider")
 print("Native target publication: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
class RevisionSource extends RefCounted:
 var shape_revision:=0
 var geometry_revision:=0

