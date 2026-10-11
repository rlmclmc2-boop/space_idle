extends SceneTree
var checks=0
var failures=0
var calls=0
var game
var construction_complete=true
var reenter=false
var invalidate_during_build=false
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func point(target):
 calls+=1
 if invalidate_during_build:
  invalidate_during_build=false
  game.event.emit("equipment_stats",{"category":"weapons","counter_only":false})
 construction_complete=construction_complete and not game.projectile_target_points_active
 if reenter:
  reenter=false
  return game.target_point(target)
 return Vector2(target.x+3,target.y+7)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 game=scene.game;game.save_enabled=false;game.profile.highestLevel=8;game.rebuild_unlocks();game.start(8,false);game.spawn_group();game.pending_unlocks.clear();game.paused=true
 for enemy in game.enemies:enemy.hp=1e100
 game.target_provider=point
 var enemy=game.enemies[0];var expected=Vector2(enemy.x+3,enemy.y+7);var count=game.enemies.size()
 var rng=game.rng.state
 calls=0;game.begin_projectile_target_points()
 check(calls==count,"one canonical projection per live target at complete publication")
 check(game.projectile_target_points_active and construction_complete,"provider callbacks never see a half-built table")
 var points_equal=true
 for i in 100:points_equal=points_equal and game.target_point(enemy)==expected
 check(points_equal,"repeated direct reads preserve exact canonical point")
 check(calls==count,"repeated same-step queries do not call provider")
 enemy.x+=5;var before=calls
 check(game.target_point(enemy)==expected+Vector2(5,0) and calls==before+1,"genuine logical coordinate change falls back immediately")
 enemy.x-=5;game.begin_projectile_target_points();enemy.hp=0;before=calls;game.target_point(enemy)
 check(calls==before+1 and not game.missile_target_live(enemy),"death is read live, never from publication availability")
 enemy.hp=1e100
 game.begin_projectile_target_points()
 var replacement=enemy.duplicate(true);game.enemies[0]=replacement;before=calls;game.target_point(replacement);game.target_point(enemy)
 check(calls==before+2,"same-uid replacement and removed old identity cannot use stale row")
 game.enemies[0]=enemy
 game.begin_projectile_target_points()
 var player=game.player;game.player=player.duplicate(true);before=calls;game.target_point(enemy)
 check(calls==before+1,"same-step player replacement rejects previous publication")
 game.player=player
 game.begin_projectile_target_points();game.target_spatial_source.invalidate_membership();before=calls;game.target_point(enemy)
 check(calls==before+1 and not game.projectile_target_points_active,"source spatial revision invalidates publication immediately")
 game.end_projectile_target_points();before=calls;game.target_point(enemy)
 check(calls==before+1 and game.projectile_target_points.is_empty(),"queries outside substep use canonical source and release rows")
 for kind in ["state","encounter","explode","retreat","wave_clear","ship_changed","module_changed","upgrade","prototype_missile_reset"]:
  game.begin_projectile_target_points();game._projectile_target_points_event(kind,{})
  check(not game.projectile_target_points_active,"geometry/lifecycle event invalidates: "+kind)
 game.begin_projectile_target_points();game.event.emit("equipment_stats",{"category":"weapons","counter_only":true})
 check(game.projectile_target_points_active,"counter-only equipment event retains geometry publication")
 game.event.emit("equipment_stats",{"category":"weapons","counter_only":false})
 check(not game.projectile_target_points_active,"actual stats event synchronously invalidates before further queries")
 reenter=true;construction_complete=true;game.begin_projectile_target_points()
 check(construction_complete and game.projectile_target_points_active,"reentrant provider query remains canonical during construction")
 game.end_projectile_target_points()
 invalidate_during_build=true;game.begin_projectile_target_points()
 check(not game.projectile_target_points_active and game.projectile_target_points.is_empty(),"geometry event during construction aborts whole publication")
 check(game.rng.state==rng,"publication and fallback consume no combat RNG")
 game.paused=false;game.projectiles.clear();game.missile_queue.clear()
 # Invalid source prevents a launch, but its due-time still splits the original
 # PresentedBattleGame logical step into two actual projectile substeps.
 game.missile_queue.append({"due":game.motion_clock+1.0/150.0,"source":{}})
 calls=0;game.tick(1.0/60.0)
 check(calls==2*count,"missile-ejection due boundary publishes separately for both actual substeps")
 check(not game.projectile_target_points_active,"normal substep exit clears direct-read scope")
 # Preserve ordered kill visibility and step-start snapshot admission.
 game.projectiles.clear();game.missile_queue.clear();enemy.hp=1;enemy.max_shield=0;enemy.drops=[]
 var aim=point(enemy);var other=game.enemies[1];var later={"x":0.,"y":0.,"target":other,"damage":10.,"type":1,"speed":100.,"hostile":false,"key":"chain","dead":false,"direction":Vector2.UP,"chain_hop":true,"jewelEffects":[],"critical":false}
 var hit_count=[0]
 var observer=func(kind,info):
  if kind=="hit" and not info.player and info.uid==enemy.uid:
   hit_count[0]+=1
   if hit_count[0]==1:game.projectiles.append(later)
 game.event.connect(observer)
 var first={"x":aim.x,"y":aim.y,"target":enemy,"damage":10.,"type":1,"speed":100.,"hostile":false,"key":"chain","dead":false,"direction":Vector2.UP,"chain_hop":true,"jewelEffects":[],"critical":false}
 var second=first.duplicate();game.projectiles.append(first);game.projectiles.append(second)
 game.tick_projectiles(1.0/60.0)
 check(hit_count[0]==1 and second.target.is_empty(),"earlier ordered kill invalidates later projectile immediately")
 check(later.x==0 and later.y==0 and game.projectiles.has(later),"callback-created chain carrier waits until next substep snapshot")
 game.event.disconnect(observer)
 game.tick_projectiles(1.0/60.0)
 check(later.x!=0 or later.y!=0,"new carrier advances at next actual substep")
 scene.queue_free();await process_frame;await process_frame
 print("Projectile target publication: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
