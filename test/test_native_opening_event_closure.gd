extends SceneTree
# Short authored-encounter event probe. One checkpoint per isolated process.
const STEP:=1.0/60.0
var game:BattleGame
var tick_index:=0
var fires:=0
var hits:=0
var enemy_hits:=0
var player_hits:=0
var deaths:Array=[]
var handoff_rows:Array=[]
var hit_rows:Array=[]
var reactive_rows:Array=[]
var last_enemy_hit_tick:Dictionary={}
func watch(kind:String,info:Dictionary)->void:
	if kind=="native_execution_handoff":handoff_rows.append({"tick":tick_index,"reason":info.get("reason","")})
	match kind:
		"fire":fires+=1
		"hit":
			hits+=1
			var uid:=int(info.get("uid",-1))
			if bool(info.get("player",false)):player_hits+=1
			else:
				enemy_hits+=1;last_enemy_hit_tick[uid]=tick_index
			if hit_rows.size()<80:hit_rows.append({"tick":tick_index,"uid":uid,"player":bool(info.get("player",false)),"amount":info.get("amount"),"absorbed":info.get("absorbed"),"reactive_stacks":info.get("reactive_stacks",null),"reactive_multiplier":info.get("reactive_multiplier",null)})
			if info.has("reactive_stacks") and reactive_rows.size()<80:reactive_rows.append({"tick":tick_index,"uid":uid,"stacks":info.reactive_stacks,"multiplier":info.reactive_multiplier})
		"explode":
			if info.has("uid"):deaths.append({"tick":tick_index,"uid":int(info.uid),"id":int(info.get("id",-1))})
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1373,883)
	var stage:=int(OS.get_environment("OPENING_STAGE")) if not OS.get_environment("OPENING_STAGE").is_empty() else 2
	var point:=int(OS.get_environment("OPENING_POINT")) if not OS.get_environment("OPENING_POINT").is_empty() else 1
	var limit:=int(OS.get_environment("OPENING_TICKS")) if not OS.get_environment("OPENING_TICKS").is_empty() else 120
	var owner:=OS.get_environment("OPENING_OWNER")
	if owner.is_empty():owner="native"
	assert(owner in ["native","legacy"],"known owner")
	assert(stage in [2,3] and point>0 and limit>0 and limit<=900,"bounded authored probe")
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false)
	game=scene.game;game.save_enabled=false;game.stat_cache_enabled=true;game.invalidate_stat_cache()
	game.speed=1.0;game.rng.seed=51015+stage*10+point
	if owner=="legacy":game.native_execution_auto=false
	game.profile.onboarding.completed=true;game.profile.onboarding.dismissed=true
	game.profile.cleared=range(1,stage);game.profile.unlocked=["armour","laser"]
	game.rebuild_unlocks();game.pending_unlocks.clear()
	if stage==2:
		game.profile.loadout={"weapons":[{"key":"laser","level":2},{"key":"missile","level":2}],"defence":[{"key":"armour","level":2}]}
	else:
		game.profile.loadout={"weapons":[{"key":"laser","level":2},{"key":"missile","level":2},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":2},{"key":"shield","level":1}]}
	for group in ["weapons","defence"]:
		for entry in game.profile.loadout[group]:assert(game.profile.unlocked.has(entry.key),"stage-illegal equipment")
	game.invalidate_stat_cache();game.reset_player()
	var level:Dictionary=scene.db.levels[stage-1]
	var expected:int=int(level.groups[point-1].id)
	var checkpoint={"distance":float(level.groups[point-1].position)*float(level.length),"groupIndex":point,"state":BattleGame.State.COMBAT,"guardArrived":false,"retreatBossPending":false}
	assert(game.start(stage,false,checkpoint),"authored checkpoint failed")
	if owner=="native" and game.native_execution==null:
		var descriptor=preload("res://scripts/native_execution_compiler.gd").new().compile(game,"native_rich15_layer2")
		print("NATIVE_ADMISSION_ERROR ",descriptor.get("error","unknown")," state ",game.state," enemies ",game.enemies.size()," unlocked ",game.profile.unlocked)
		var candidate=ClassDB.instantiate("SpaceCombatKernel")
		var session=preload("res://scripts/native_execution_session.gd").new()
		print("NATIVE_ADMISSION_DETAIL scope ",descriptor.get("execution_scope","")," count ",descriptor.get("enemies",[]).size()," drop ",descriptor.get("requires_drop_rules",false),"/",descriptor.get("drop_rules_compiled",false)," supports ",session.supports_configuration(candidate,descriptor)," configured ",candidate.configure(descriptor))
		quit(2);return
	assert(game.stat_cache_enabled and not game.save_enabled,"cache/no-save gate")
	if owner=="native" and scene.battle_slice_runtime==null:assert(scene.attach_native_display(),"native display attachment")
	var attached_at_start:=scene.battle_slice_runtime!=null
	var initial:Array=[]
	for enemy in game.enemies:
		var key:String=scene.enemy_ship_key(enemy)
		initial.append({"uid":int(enemy.uid),"id":int(enemy.id),"archetype":str(enemy.get("archetype_id","")),"ship_key":key,"texture":scene.ship_hull_texture(key).resource_path,"hp":enemy.hp,"shield":enemy.shield,"max_shield":enemy.max_shield,"shield_delay":enemy.get("shieldDelay",0)})
	game.event.connect(watch)
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
	var shield_samples:Array=[];var retained_after_death:Array=[];var finish_tick:=limit
	for tick in limit:
		tick_index=tick+1
		scene._process(STEP)
		if owner=="native":scene.draw_retained_enemy_contacts(Vector2.ZERO,game.is_boss_encounter())
		if stage==3 and point==5:
			for enemy in game.enemies:
				if int(enemy.uid)==int(initial[0].uid):shield_samples.append({"tick":tick_index,"shield":enemy.shield,"hp":enemy.hp,"shield_hit_at":enemy.get("shield_hit_at",null),"clock":game.production_time()})
		if owner=="native" and deaths.size()>0 and (tick_index>=int(deaths[0].tick)+2 or game.native_handoff_count>0):
			if game.native_handoff_count>0:
				for extra in 2:
					scene._process(STEP)
					if owner=="native":scene.draw_retained_enemy_contacts(Vector2.ZERO,game.is_boss_encounter())
			var dead_uid:int=int(deaths[0].uid)
			var dead_record=scene.retained_contacts.records.get(dead_uid)
			var dead_enemy=game.enemies.filter(func(e):return int(e.uid)==dead_uid)
			retained_after_death.append({"uid":dead_uid,"in_enemies":not dead_enemy.is_empty(),"enemy_hp":dead_enemy[0].hp if not dead_enemy.is_empty() else null,"record_exists":dead_record!=null,"record_visible":dead_record.root.visible if dead_record!=null else false,"record_alive":dead_record.alive if dead_record!=null else false,"retained_record_count":scene.retained_contacts.records.size()})
			finish_tick=tick_index
			break
		if game.native_handoff_count>0:
			finish_tick=tick_index
			break
	var row={"stage":stage,"point":point,"group":expected,"owner":owner,"display_attached_start":attached_at_start,"display_attached_end":scene.battle_slice_runtime!=null,"tick_limit":limit,"ticks":finish_tick,"initial":initial,"unlocked":game.profile.unlocked,"loadout":game.profile.loadout,"fires":fires,"hits":hits,"enemy_hits":enemy_hits,"player_hits":player_hits,"deaths":deaths,"retained_after_death":retained_after_death,"reactive_rows":reactive_rows,"hit_rows":hit_rows,"shield_samples":shield_samples,"native_active_end":game.native_execution!=null,"handoffs":game.native_handoff_count,"handoff_rows":handoff_rows,"save":game.save_enabled,"cache":game.stat_cache_enabled,"state":game.state,"remaining_uids":game.enemies.map(func(e):return int(e.uid))}
	FileAccess.open("res://.runtime/native-opening-event.json",FileAccess.WRITE).store_string(JSON.stringify(row)+"\n")
	print("NATIVE_OPENING_EVENT ",JSON.stringify(row))
	quit()
