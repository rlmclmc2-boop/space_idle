extends SceneTree
var failures=0
var checks=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.highestLevel=8;g.rebuild_unlocks();g.profile.loadout.defence[0]={"key":"armour","level":8};g.invalidate_stat_cache();g.start(8,false);g.spawn_group();g.pending_unlocks.clear();g.paused=true
 scene.fx_time=5.
 for enemy in g.enemies:scene.enemy_pose(enemy).born=0.;enemy.hp=0.
 scene.set_damage_mode(1)
 var state=JSON.stringify(g.profile);var rng=g.rng.state;var uid=g.enemies[0].uid
 var event={"player":false,"uid":uid,"type":1,"amount":7.,"critical":false}
 scene.queue_damage_number(event)
 check(scene.floats.size()==1 and scene.damage_pending.is_empty(),"new category reserves logical slot before display")
 event.type=2;event.amount=11.;scene.queue_damage_number(event)
 check(scene.floats.size()==2 and scene.damage_pending.is_empty(),"second category reserves second logical slot")
 event.type=1;event.critical=true;event.amount=13.;scene.queue_damage_number(event)
 check(scene.floats.size()==2 and scene.damage_pending.size()==1,"third category waits behind original two-slot cap")
 var retiring=scene.floats.filter(func(f):return f.get("retiring",false))
 check(retiring.size()==1 and retiring[0].amount==7. and is_equal_approx(retiring[0].life,.08),"oldest slot retires before visible-frame ageing")
 event.critical=false;event.amount=17.;scene.queue_damage_number(event)
 var old=scene.floats.filter(func(f):return f.get("type",0)==1 and not f.critical)
 check(old.size()==1 and old[0].amount==7.,"later same-frame hit cannot merge into retiring slot")
 check(scene.damage_pending.size()==2,"later noncritical category keeps distinct backlog entry")
 # Exercise visible ageing/admission without ticking gameplay; no event layout required.
 for f in scene.floats:f.life-=.1
 scene.floats=scene.floats.filter(func(f):return f.life>0.)
 scene.flush_damage_numbers()
 var admitted=scene.floats.filter(func(f):return f.get("critical",false))
 check(admitted.size()==1 and admitted[0].amount==13.,"freed slot admits pending category in same visible frame")
 check(admitted.size()==1 and is_equal_approx(admitted[0].life,float(scene.battle_visual.damage_number_critical_duration)),"previously blocked label starts its visible lifetime on admission")
 check(scene.damage_history.size()==4,"all hit history survives slot pressure")
 check(JSON.stringify(g.profile)==state and g.rng.state==rng,"slot lifecycle has no gameplay or RNG effects")
 scene.queue_free();await process_frame;await process_frame
 print("Damage slot lifecycle: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
