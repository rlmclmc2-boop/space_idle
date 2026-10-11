extends SceneTree
var failures=0
var checks=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.start(8,false);g.pending_unlocks.clear();g.paused=true
 scene.fx_time=5.0
 for enemy in g.enemies:scene.enemy_pose(enemy).born=0;enemy.hp=0
 var state=JSON.stringify(g.profile);var rng=g.rng.state
 var uid=g.enemies[0].uid
 var outgoing={"player":false,"uid":uid,"type":1,"amount":10.0,"critical":false}
 scene.set_damage_mode(1)
 for i in 100:scene.queue_damage_number(outgoing)
 check(scene.damage_pending.size()==1 and scene.floats.is_empty() and scene.damage_pending[0].amount==1000,"100 ordered events merge without intermediate layout")
 check(scene.damage_history.size()==40,"full per-hit bounded40 history remains")
 outgoing.type=2;scene.queue_damage_number(outgoing);outgoing.critical=true;scene.queue_damage_number(outgoing)
 check(scene.damage_pending.size()==3,"distinct type and critical remain distinct before commit")
 var physical={"player":true,"uid":0,"type":2,"amount":300.0,"absorbed":0.0,"critical":false}
 var energy={"player":true,"uid":0,"type":1,"amount":100.0,"absorbed":20.0,"critical":false}
 scene.queue_damage_number(physical);scene.queue_damage_number(energy)
 scene.flush_damage_numbers()
 var lanes=scene.floats.filter(func(f):return f.get("incoming_lane",false))
 check(lanes.size()==2 and lanes[1].pos.y<lanes[0].pos.y,"both type rows reserved before outgoing")
 for i in scene.floats.size():
  var f=scene.floats[i]
  check(not f.get("display_dirty",false) and not f.text.is_empty(),"visible labels fully committed")
  for j in range(i+1,scene.floats.size()):
   var other=scene.floats[j]
   check(not scene.damage_text_rect(scene.battle_point(f.pos),f.text,f.size).intersects(scene.damage_text_rect(scene.battle_point(other.pos),other.text,other.size)),"no category overlap")
 var frozen=scene.floats.duplicate(true);scene._process(0.1)
 check(scene.floats==frozen,"pause leaves committed rows unchanged")
 scene.set_damage_mode(1);outgoing.type=1;outgoing.critical=false;outgoing.amount=7
 scene.queue_damage_number(outgoing);scene.fx_time+=0.201;outgoing.amount=9;scene.queue_damage_number(outgoing)
 check(scene.damage_pending.size()==2 and scene.damage_pending[0].amount==7 and scene.damage_pending[1].amount==9,"multiple logical steps cannot cross200ms merge boundary")
 scene.fx_time+=0.31;scene.flush_damage_numbers()
 check(scene.damage_pending.is_empty() and scene.floats.is_empty(),"expired backlog never appears later")
 scene.queue_damage_number(energy);scene.reset_battle_transients_for_scene()
 scene.flush_damage_numbers()
 check(scene.floats.filter(func(f):return f.get("damage",false)).is_empty() and scene.damage_pending.is_empty(),"clear discards deferred labels")
 check(JSON.stringify(g.profile)==state and g.rng.state==rng,"display transaction leaves gameplay/RNG unchanged")
 scene.queue_free();await process_frame;await process_frame
 print("Damage batch: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
