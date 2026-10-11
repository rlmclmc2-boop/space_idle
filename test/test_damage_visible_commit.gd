extends SceneTree
var failures=0
var checks=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.set_script(load("res://damage_visible_probe_scene.gd"));scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.highestLevel=8;g.rebuild_unlocks();g.profile.loadout.defence[0]={"key":"armour","level":8};g.invalidate_stat_cache();g.start(8,false);g.spawn_group();g.pending_unlocks.clear();g.paused=true
 scene.fx_time=5.
 for enemy in g.enemies:scene.enemy_pose(enemy).born=0.;enemy.hp=0.
 var enemy=g.enemies[0];enemy.hp=100.;enemy.x=BattleGame.BATTLE_SIZE.x*.5;enemy.y=BattleGame.BATTLE_SIZE.y*.4
 scene.set_damage_mode(1);scene.visual_queries=0
 var state=JSON.stringify(g.profile);var rng=g.rng.state
 var event={"player":false,"uid":enemy.uid,"type":1,"amount":10.,"critical":false}
 for i in 100:scene.queue_damage_number(event)
 event.type=2;event.amount=11.;scene.queue_damage_number(event)
 var physical={"player":true,"uid":0,"type":2,"amount":300.,"absorbed":0.,"critical":false}
 var energy={"player":true,"uid":0,"type":1,"amount":100.,"absorbed":20.,"critical":false}
 scene.queue_damage_number(physical);scene.queue_damage_number(energy)
 check(scene.visual_queries==0,"all event categories avoid fonts/origin/collision queries")
 check(scene.damage_history.size()==40,"exact per-hit bounded history remains")
 var outgoing=scene.floats.filter(func(f):return f.get("target","")=="enemy:%s" % enemy.uid)
 check(outgoing.size()==2 and outgoing[0].amount==1000. and outgoing[1].amount==11.,"same target retains energy and physical cumulative amounts")
 check(outgoing.all(func(f):return f.text.is_empty() and f.get("unplaced",false)),"events do not materialize intermediate labels")
 scene.flush_damage_numbers()
 check(scene.visual_queries>0,"visible-frame commit performs presentation work")
 var incoming=scene.floats.filter(func(f):return f.get("incoming_lane",false))
 outgoing=scene.floats.filter(func(f):return f.get("target","")=="enemy:%s" % enemy.uid)
 check(incoming.size()==2 and incoming[0].type==2 and incoming[1].type==1 and incoming[1].pos.y<incoming[0].pos.y,"both incoming types own fixed priority rows")
 check(outgoing.size()==2 and outgoing.all(func(f):return not f.text.is_empty() and not f.unplaced),"both outgoing categories are visible within original capacity")
 check(outgoing.all(func(f):return is_equal_approx(f.life,float(scene.battle_visual.damage_number_normal_duration))),"first visible labels keep full configured duration before ageing")
 for i in scene.floats.size():
  var f=scene.floats[i];var rect=scene.damage_text_rect(scene.battle_point(f.pos),f.text,f.size)
  for j in range(i+1,scene.floats.size()):
   var other=scene.floats[j]
   check(not rect.intersects(scene.damage_text_rect(scene.battle_point(other.pos),other.text,other.size)),"incoming/outgoing categories do not overlap")
  for hull in scene.damage_text_enemy_bounds():check(not rect.intersects(hull),"visible damage text does not cover a live hull")
 var before=scene.floats.duplicate(true);scene._process(.05)
 check(scene.floats==before,"paused visible labels neither flash nor lose lifetime")
 scene.set_damage_mode(1);scene.visual_queries=0;event.type=1;event.amount=13.;event.critical=true;scene.queue_damage_number(event)
 check(scene.visual_queries==0,"critical admission stays event-only")
 scene.flush_damage_numbers()
 var critical=scene.floats.filter(func(f):return f.get("critical",false))
 check(critical.size()==1 and critical[0].type==1 and critical[0].size==19 and not critical[0].text.is_empty(),"critical category remains distinct and visible")
 check(critical.size()==1 and is_equal_approx(critical[0].life,float(scene.battle_visual.damage_number_critical_duration)),"critical visible duration remains configured")
 scene.set_damage_mode(1);scene.visual_queries=0;event.critical=false;scene.queue_damage_number(event)
 check(scene.visual_queries==0,"dead-target ownership capture does not materialize geometry")
 g.enemies.erase(enemy);scene.flush_damage_numbers()
 var departed=scene.floats.filter(func(f):return f.get("target","")=="enemy:%s" % enemy.uid)
 check(departed.size()==1 and is_same(departed[0].target_entity,enemy),"same-frame removal retains exact departed target identity")
 var expected=scene.battle_logical_point(scene.enemy_render_position(enemy)-Vector2(0,scene.enemy_render_width(enemy)+16))
 check(departed.size()==1 and departed[0].origin.is_equal_approx(expected),"dead-target label keeps its target anchor instead of player fallback")
 check(JSON.stringify(g.profile)==state and g.rng.state==rng,"display commit has no gameplay or RNG mutation")
 scene.queue_free();await process_frame;await process_frame
 print("Damage visible commit: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
