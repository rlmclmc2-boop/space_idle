extends SceneTree
var checks := 0
var failures: Array = []
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
	var game=scene.game;game.save_enabled=false;game.profile.highestLevel=8;game.rebuild_unlocks();game.start(8,false);game.spawn_group();game.paused=true
	scene.reset_battle_transients_for_scene();scene.visual_packets.clear()
	var enemy:Dictionary=game.enemies[0]
	var rng=game.rng.state
	var shot:Dictionary={"key":"laser","hostile":false,"mount":0,"target":enemy,"x":game.player.x,"y":game.player.y,"direction":Vector2.UP,"serial":912345,"launch_point":Vector2(250,600),"ballistic_target_origin":Vector2(enemy.x,enemy.y),"critical":false,"type":1,"beam":false}
	scene.fx_time=10.0
	scene.on_event("fire",{"shot":shot,"type":1})
	check(scene.projectile_visuals.is_empty() and scene.pulse_events.is_empty(),"fire publishes no drawing record before display boundary")
	check(is_same(scene.turret_pose(0).target,enemy),"canonical turret target settles immediately")
	var packet:Dictionary=scene.visual_packets[0]
	check(packet.is_read_only() and packet.info.is_read_only() and packet.info.shot.is_read_only() and packet.info.shot.target.is_read_only(),"event payload is recursively immutable")
	var direction:Vector2=Vector2.from_angle(float(packet.launch_seed.angle))
	scene.fx_time=10.01
	scene.on_event("projectile_impact",{"shot":shot,"pos":Vector2(280,140)})
	check(scene.pulse_events.is_empty(),"same-step impact waits for display boundary")
	check(scene.visual_packets[1].visual.origin==Vector2(250,600),"impact resolves preceding launch from logical record registry")
	enemy.x+=100;enemy.hp=0;shot.direction=Vector2.DOWN;shot.target={}
	scene.fx_time=20.0;scene.commit_visual_events()
	check(scene.pulse_events.size()==2 and scene.pulse_events[0].kind=="fire" and scene.pulse_events[1].kind=="hit","fire and impact preserve ordered publication")
	check(scene.pulse_events[0].position==Vector2(250,600) and scene.pulse_events[0].direction==direction,"launch position and direction survive mutation/death")
	check(scene.pulse_events[1].direction==direction,"impact uses event-time angle")
	check(scene.pulse_events[0].born==10.0 and scene.pulse_events[1].born==10.01 and scene.fx_time==20.0,"event clocks freeze and logical clock is restored")
	check(is_same(scene.projectile_visuals[0].shot,shot),"live flight lifetime handle retains original shot identity")
	check(scene.visual_packets.is_empty() and not scene.visual_batch_started,"display consumption releases queue and step registry")
	check(game.rng.state==rng,"visual consumer never advances combat RNG")
	scene.on_event("fire",{"shot":shot,"type":1})
	scene.reset_battle_transients_for_scene()
	scene.on_event("fire",{"shot":shot,"type":1})
	scene.commit_visual_events()
	check(scene.pulse_events.size()==1 and scene.projectile_visuals.size()==1,"scene marker discards old records and preserves subsequent fire")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	# Quit owns the tree teardown; freeing here races queued UI refresh callbacks.
	quit(0 if failures.is_empty() else 1)
