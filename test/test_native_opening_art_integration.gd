extends SceneTree
# One authored encounter checkpoint per process, actual main scene and native owner.
const STEP:=1.0/60.0
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func case_run(stage:int,point:int,seed_value:int)->void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	var g=scene.game
	g.save_enabled=false;g.stat_cache_enabled=true;g.invalidate_stat_cache()
	g.speed=1.0;g.rng.seed=seed_value
	g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true
	g.profile.cleared=range(1,stage);g.profile.highestLevel=stage+1
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.loadout={"weapons":[{"key":"laser","level":2},{"key":"missile","level":2},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":2},{"key":"shield","level":1}]}
	g.invalidate_stat_cache();g.reset_player()
	var level:Dictionary=scene.db.levels[stage-1]
	var expected:int=int(level.groups[point-1].id)
	var checkpoint={"distance":float(level.groups[point-1].position)*float(level.length),"groupIndex":point,"state":BattleGame.State.COMBAT,"guardArrived":false,"retreatBossPending":false}
	assert(g.start(stage,false,checkpoint),"authored checkpoint failed")
	assert(g.stat_cache_enabled and not g.save_enabled and ClassDB.class_exists("SpaceCombatKernel"),"native/cache/save gate")
	assert(g.native_execution!=null,"authored encounter did not admit native owner")
	var start_count:int=g.enemies.size();var starting_uids:Array=g.enemies.map(func(e):return int(e.uid))
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
	for tick in 120:
		scene._process(STEP)
		assert(g.native_execution!=null and g.native_handoff_count==0,"unexpected owner handoff")
		if tick in [0,59,119]:
			scene.refresh_draw_layers(0.0);scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/native-opening-%d-%d-t%d.png"%[stage,point,tick+1])
	var row={"stage":stage,"point":point,"group":expected,"seed":seed_value,"initial_enemies":start_count,"initial_uids":starting_uids,"remaining_enemies":g.enemies.size(),"native_active":g.native_execution!=null,"handoffs":g.native_handoff_count,"logic_steps":120,"logic_dt":STEP,"cache":g.stat_cache_enabled,"save":g.save_enabled,"armour":g.player.armour,"shield":g.player.shield,"state":g.state,"engine":Engine.get_version_info().string,"viewport":str(root.size)}
	rows.append(row);print("NATIVE_OPENING ",JSON.stringify(row))
	# Leave the scene mounted until this one-checkpoint process writes its result.
func run()->void:
	root.size=Vector2i(1373,883)
	var stage:=int(OS.get_environment("OPENING_STAGE")) if not OS.get_environment("OPENING_STAGE").is_empty() else 2
	var point:=int(OS.get_environment("OPENING_POINT")) if not OS.get_environment("OPENING_POINT").is_empty() else 1
	await case_run(stage,point,51015+stage*10+point)
	FileAccess.open("res://.runtime/native-opening-integration.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  ")+"\n")
	print("NATIVE_OPENING_SUMMARY ",rows.size()," checkpoints")
	quit()

