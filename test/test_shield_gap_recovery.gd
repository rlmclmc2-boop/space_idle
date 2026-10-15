extends SceneTree
# Controlled quiet interval on authored 3-5 shielded enemy after real hit-path probe.
const STEP:=1.0/60.0
func _initialize()->void:call_deferred("run")
func run()->void:
	var owner:=OS.get_environment("SHIELD_GAP_OWNER")
	if owner.is_empty():owner="native"
	assert(owner in ["native","legacy"],"known execution owner")
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false)
	var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.stat_cache_enabled=true;g.invalidate_stat_cache()
	g.speed=1.0;g.rng.seed=51050
	g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true
	g.profile.cleared=[1,2];g.profile.unlocked=["armour","laser"]
	g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.loadout={"weapons":[{"key":"laser","level":2},{"key":"missile","level":2},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":2},{"key":"shield","level":1}]}
	g.invalidate_stat_cache();g.reset_player()
	var level:Dictionary=scene.db.levels[2];var point:=5
	var checkpoint={"distance":float(level.groups[point-1].position)*float(level.length),"groupIndex":point,"state":BattleGame.State.COMBAT,"guardArrived":false,"retreatBossPending":false}
	assert(g.start(3,false,checkpoint) and g.enemies.size()==1,"authored shielded checkpoint")
	var enemy:Dictionary=g.enemies[0]
	assert(str(enemy.get("archetype_id",""))=="shielded" and is_equal_approx(float(enemy.max_shield),1080.0),"authored 3-5 shield")
	# Fix only a post-hit deficit and delay clock; no combat value or source table changes.
	enemy.shield=260.0;enemy.shield_hit_at=g.enemy_shield_time;enemy.shield_updated_at=g.enemy_shield_time
	for index in g.combat_weapon_entries().size():g.cooldowns[g.slot_id("weapons",index)]=100.0
	var start_clock:float=g.enemy_shield_time;var starting_shield:float=enemy.shield
	if owner=="native":
		g.native_execution_auto=true
		assert(g.admit_native_compiled_execution("native_rich15_layer2"),"native quiet-gap admission")
		assert(scene.attach_native_display(),"native quiet-gap display")
	var rows:Array=[]
	for tick in 240:
		scene._process(STEP)
		if owner=="native":assert(g.native_execution!=null and g.native_handoff_count==0,"native gap owner retained")
		var actor:Dictionary=g.enemies[0]
		rows.append({"tick":tick+1,"clock":g.enemy_shield_time,"shield":actor.shield,"hit_at":actor.shield_hit_at,"hp":actor.hp})
	var result={"owner":owner,"stage":3,"point":5,"initial_shield":starting_shield,"max_shield":enemy.max_shield,"shield_recovery":enemy.shieldRecovery,"shield_delay":enemy.shieldDelay,"initial_hit_clock":start_clock,"ticks":rows.size(),"rows":rows,"handoffs":g.native_handoff_count,"native_active":g.native_execution!=null,"save":g.save_enabled,"cache":g.stat_cache_enabled}
	FileAccess.open("res://.runtime/shield-gap-"+owner+".json",FileAccess.WRITE).store_string(JSON.stringify(result)+"\n")
	print("SHIELD_GAP_SUMMARY ",JSON.stringify({"owner":owner,"initial":starting_shield,"final":rows[-1].shield,"ticks":rows.size(),"handoffs":g.native_handoff_count}))
	quit()
