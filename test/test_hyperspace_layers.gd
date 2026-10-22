extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func opened(db):
	db.ships.Frigate.weaponSlots=2 # Exercise both live attack sources at the session boundary.
	var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
	g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.stat_cache_enabled=true
	g.load_hyperspace_routes();return g
func _initialize()->void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g=opened(db);var h=g.hyperspace
	check(S.valid(g.profile.hyperspace,h.config,db.levels.size()),"fresh current save")
	check(g.hyperspace_route_view("alpha").current_layer==0 and not g.start_hyperspace_idle("alpha"),"no mainline or selection borrowed progress")
	check(not g.start_hyperspace("alpha",5),"arbitrary layer rejected")
	g.start(14,false);g.spawn_group();g.tick(0.1)
	var energy=g.profile.hyperspace.energy;var old_uids=g.enemies.map(func(enemy):return enemy.uid)
	var cleared=g.profile.cleared.duplicate();var earned=g.economy.save_data();var history=g.enhancement_growth.save_data()
	g.player.armour=1.0;g.cooldowns["abandoned"]=123.0
	check(not old_uids.is_empty(),"live production battle exists before departure")
	if failures:
		call_deferred("quit",1);return
	check(g.start_hyperspace_challenge("alpha"),"immediate challenge during actual combat")
	check(g.profile.hyperspace.active.level==1 and g.profile.hyperspace.active.ticket==0 and g.profile.hyperspace.energy==energy,"first challenge layer1 without ticket")
	var export:Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(export,db).error=="","active combat return portable export validates")
	check(g.exit_hyperspace_challenge(),"immediate exit")
	check(g.stage==14 and g.state==g.State.TRAVEL and g.group_index==0 and g.distance==0 and g.enemies.is_empty(),"exit starts original stage from the beginning")
	check(g.N.compare(g.player.armour,g.stat("armour"))==0 and not g.cooldowns.has("abandoned"),"health and cooldown use normal fresh sortie")
	check(g.profile.cleared==cleared and g.economy.save_data()==earned and g.enhancement_growth.save_data()==history,"clearing does not award kills, resources or mainline progress")
	check(export.hyperspace.active.return_target=={"stage":14,"loop":false,"guard_index":0} and not export.has("journey"),"active save retains destination only")
	if failures:
		call_deferred("quit",1);return
	check(not g.exit_hyperspace_challenge() and g.profile.hyperspace.energy==energy,"duplicate exit cannot refund or change state")
	var reloaded=opened(db);reloaded.load_progress_data(export);reloaded.resume_progress()
	check(reloaded.state==g.State.TRAVEL and reloaded.stage==14 and reloaded.enemies.is_empty() and reloaded.group_index==0,"reload interrupted challenge starts fresh main sortie")
	check(reloaded.profile.hyperspace.energy==energy and reloaded.profile.hyperspace.active.is_empty(),"reload zero-ticket settlement once")
	check(g.start_hyperspace_challenge("alpha"),"repeat challenge allowed")
	g.profile.hyperspace.active.work=12.0
	check(g.manual_hyperspace.finish(g,true),"actual manual success transition")
	var pending:Dictionary=g.profile.hyperspace.active.duplicate(true)
	check(g.hyperspace_route_view("alpha").current_layer==1 and h.best_x1(g,"alpha",2)==0,"success advances only won layer, next has no borrowed time")
	check(h.claim(g,pending.round_id,pending.run_id) and not h.claim(g,pending.round_id,pending.run_id),"reward once")
	var main_before:Dictionary={"stage":g.stage,"distance":g.distance,"state":g.state,"player":g.player.duplicate(true)}
	check(g.start_hyperspace_idle("alpha"),"one background round")
	var idle:Dictionary=g.profile.hyperspace.idle.duplicate(true)
	check(idle.duration==12 and {"stage":g.stage,"distance":g.distance,"state":g.state,"player":g.player.duplicate(true)}==main_before,"background starts without battle switch")
	check(not g.start_hyperspace_idle("alpha") and g.profile.hyperspace.idle==idle,"repeat start rejected")
	check(g.start_hyperspace_challenge("alpha"),"challenge and background coexist")
	g.profile.hyperspace.active.work=7.0;g.manual_hyperspace.finish(g,true)
	pending=g.profile.hyperspace.active.duplicate(true)
	h.claim(g,pending.round_id,pending.run_id)
	check(S.valid(g.profile.hyperspace,h.config,db.levels.size()),"out-of-order settlement save valid")
	h.advance(g,12.0)
	check(g.profile.hyperspace.idle.is_empty() and h.current_layer(g,"alpha")==2 and h.best_x1(g,"alpha",2)==7,"old layer background settles once without overwriting new best")
	check(not h.claim(g,idle.round_id,idle.run_id),"background duplicate claim rejected")
	check(g.start_hyperspace_idle("alpha") and g.profile.hyperspace.idle.duration==7,"next background uses newly won layer's own time")
	g.stop_hyperspace_idle("alpha")
	check(S.valid(g.profile.hyperspace,h.config,db.levels.size()),"stopped state valid")
	var legacy:Dictionary=h.fresh();legacy.version=6
	check(not S.valid(legacy,h.config,db.levels.size()),"previous save format explicitly unsupported")
	# Clear real continuous beams and staged missile launches; do not reconstruct them.
	var battle=opened(db)
	var equipment:Dictionary=battle.equipment.save_data()
	equipment.loadout.weapons=[{"key":"longLaser","level":14},{"key":"missile","level":14}]
	check(battle.equipment.install_snapshot(equipment,battle.db),"current equipment fixture installs")
	battle.invalidate_stat_cache();battle.start(14,false);battle.spawn_group()
	battle.cooldowns[battle.slot_id("weapons",1)]=0.0
	battle.tick(0.2)
	check(not battle.projectiles.is_empty() and not battle.missile_queue.is_empty(),"real beam and missile ejection before departure")
	check(battle.start_hyperspace_challenge("beta") and battle.exit_hyperspace_challenge(),"live beam and missile immediate round trip")
	check(battle.projectiles.is_empty() and battle.missile_queue.is_empty() and battle.enemies.is_empty() and battle.jewel_repeats.is_empty() and battle.drone_combat.delayed.is_empty(),"old carriers, actors and delayed attacks are discarded")
	battle.tick(0.01)
	check(battle.group_index==0,"unfinished encounter does not resume on next tick")
	battle.start(14,false);battle.spawn_group();battle.toggle_loop()
	var guard:int=battle.guard_index;var selected_stage:int=battle.profile.guardStage;var previous_uid:int=battle.enemies[0].uid
	check(battle.start_hyperspace_challenge("beta"),"guard can enter immediately")
	var guard_save:Dictionary=battle.portable_save_data()
	check(battle.exit_hyperspace_challenge() and battle.profile.loop and battle.stage==selected_stage and battle.guard_index==guard and battle.group_index==guard+1 and battle.enemies[0].uid!=previous_uid,"guard returns to selected encounter with fresh actors")
	check(Transfer.new().prepare_data(guard_save,battle.db).error=="","guard destination save validates")
	var guard_reload=opened(db);guard_reload.load_progress_data(guard_save);guard_reload.resume_progress()
	check(guard_reload.profile.loop and guard_reload.stage==selected_stage and guard_reload.guard_index==guard and guard_reload.player.armour==guard_reload.stat("armour"),"guard selection and fresh health survive reopen")
	var native=opened(db);native.start(1,false);native.spawn_group()
	check(native.admit_native_compiled_execution("native_rich15_layer2"),"real native session admitted")
	var native_owner=native.native_execution;var handoffs:int=native.native_handoff_count
	native.tick(0.02)
	check(native.start_hyperspace_challenge("alpha"),"native battle enters without legacy transfer")
	check(native.native_execution==null and not native_owner.handed_off and native.native_handoff_count==handoffs,"entry cancels native ownership without actor export")
	check(native.exit_hyperspace_challenge() and native.group_index==0,"native return is a fresh sortie")
	var reentrant=opened(db);reentrant.start(1,false);reentrant.spawn_group()
	var requested:Array=[false,false]
	reentrant.event.connect(func(kind,_data):
		if kind=="fire" and not requested[0]:
			requested[0]=true
			requested[1]=reentrant.start_hyperspace_challenge("alpha") and not reentrant.manual_hyperspace.active and reentrant.logical_step_active)
	for i in 300:
		if requested[0]:break
		reentrant.tick(1.0/60.0)
	check(requested[1] and reentrant.manual_hyperspace.active and reentrant.manual_hyperspace.queued.is_empty(),"request during a logical callback waits only for the completed step")
	var notifications:Array=[]
	reentrant.event.connect(func(kind,_data):
		if kind in ["hyperspace_changed","hyperspace_manual"]:notifications.append(reentrant.manual_hyperspace.active==false and reentrant.group_index==0 and Transfer.new().prepare_data(reentrant.portable_save_data(),reentrant.db).error==""))
	check(reentrant.exit_hyperspace_challenge() and not notifications.is_empty() and notifications.all(func(ok):return ok),"exit notifications see complete destination and receipt settlement")
	# Freeze additive permanent/crew luck when starting, including without a crew.
	conquer(g,true)
	check(g.hyperspace_route_view("alpha").permanent_luck==100.0,"permanent conquered reward without crew")
	check(g.start_hyperspace_idle("alpha"),"permanent luck background starts")
	var lucky_receipt:Dictionary=g.profile.hyperspace.idle.duplicate(true)
	check(lucky_receipt.luck==100.0 and lucky_receipt.crew_snapshot=="","permanent luck frozen in receipt")
	conquer(g,false)
	check(g.profile.hyperspace.idle==lucky_receipt and g.hyperspace_route_view("alpha").total_luck==0.0,"current luck changes cannot reroll active receipt")
	var lucky_save:Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(lucky_save,db).error=="","frozen background luck portable")
	var lucky_reload=opened(db);lucky_reload.load_progress_data(lucky_save)
	check(lucky_reload.profile.hyperspace.idle==lucky_receipt,"reload freezes luck, private random state and work")
	h.advance(g,7.0);lucky_reload.hyperspace.advance(lucky_reload,7.0)
	check(g.profile.hyperspace.inventory==lucky_reload.profile.hyperspace.inventory,"same saved receipt produces same reward after reload")
	check(g.set_hyperspace_auto("alpha","navigator",true),"crew continuous background enabled")
	check(h.start_auto(g),"crew loop starts current won layer")
	check(g.profile.hyperspace.idle.level==2 and g.profile.hyperspace.idle.duration==7.0,"locked crew levels give zero efficiency, exact current best")
	check(g.stop_hyperspace_idle("alpha") and not g.profile.hyperspace.auto.enabled,"stop releases continuous job")
	set_crew_level(g,40)
	conquer(g,true)
	check(g.set_hyperspace_auto("alpha","navigator",true) and h.start_auto(g),"leveled crew starts configured route")
	var combined:Dictionary=g.profile.hyperspace.idle.duplicate(true)
	check(combined.duration==7.0*20.0/60.0 and combined.luck==140.0 and combined.crew_luck==40.0 and combined.permanent_luck==100.0,"K20 duration and additive crew/permanent luck")
	set_crew_level(g,90);conquer(g,false)
	check(g.profile.hyperspace.idle==combined,"crew changes do not alter existing duration or luck")
	g.stop_hyperspace_idle("alpha")
	var blocked=opened(db);var config:Dictionary=blocked.hyperspace.config.duplicate(true)
	config.warehouse_capacity=1;config.overflow_capacity=10;
	for key in config.quality_weights:config.quality_weights[key]=1.0 if key=="white" else 0.0
	check(blocked.hyperspace.configure(config),"full-bag test config valid");blocked.profile.hyperspace.history={"alpha":{"1":3.0}}
	var occupied_rng:=RandomNumberGenerator.new();occupied_rng.seed=5
	var Bag=preload("res://scripts/drone_inventory.gd")
	Bag.insert(blocked.profile.hyperspace.inventory,Rewards.create_drone(occupied_rng,config,"occupied","blue","laser",1,"1"),config)
	check(blocked.start_hyperspace_idle("alpha"),"full-bag job starts with one free slot")
	for i in 10:Bag.insert(blocked.profile.hyperspace.inventory,Rewards.create_drone(occupied_rng,config,"occupied_extra"+str(i),"blue","laser",1,"1"),config)
	blocked.hyperspace.advance(blocked,3.0)
	var blocked_receipt:Dictionary=blocked.profile.hyperspace.idle.duplicate(true)
	check(blocked_receipt.status=="completed_pending" and not blocked.claim_hyperspace() and not blocked.stop_hyperspace_idle("alpha"),"full bag retains pending prize and refuses destructive stop")
	blocked.hyperspace.remove_unprotected(blocked,"occupied")
	check(blocked.claim_hyperspace(blocked_receipt.round_id,blocked_receipt.run_id) and not blocked.claim_hyperspace(blocked_receipt.round_id,blocked_receipt.run_id),"background pending claim after capacity freed settles once")
	check(S.valid(blocked.profile.hyperspace,config,db.levels.size()),"full-bag recovery stays saveable")
	var rng:=RandomNumberGenerator.new();rng.seed=1901
	var sample:Dictionary={"random_state":str(rng.state)}
	var req:Dictionary={"round_id":1,"run_id":1,"route":"alpha","level":1}
	var original:=Rewards.generate(sample,h.config,req,"1")
	req.luck=0.0;req.luck_state="123"
	check(Rewards.generate(sample,h.config,req,"1")==original,"zero luck byte-identical old sampling")
	var lucky_before:=Time.get_ticks_usec()
	for i in 100:
		rng.seed=i;sample.random_state=str(rng.state);req.luck=0.0
		var plain:=Rewards.generate(sample,h.config,req,"1")
		req.luck=1000000000000.0;req.luck_state=str(i+1)
		var lucky:=Rewards.generate(sample,h.config,req,"1")
		var a:Dictionary=plain.reward.drone;var b:Dictionary=lucky.reward.drone
		if not a.is_empty():
			check(a.origin_quality==b.origin_quality and a.weapon==b.weapon and a.hanging_slots==b.hanging_slots and a.affixes.size()==b.affixes.size() and a.forge_rng_state==b.forge_rng_state and a.legendary_effect==b.legendary_effect and plain.random_state==lucky.random_state,"luck only affix tier sample"+str(i))
			for j in a.affixes.size():check(a.affixes[j].key==b.affixes[j].key and int(b.affixes[j].tier)<=int(a.affixes[j].tier),"tier improves without changing type")
	print("LAYER_CORE: ",checks," checks ",failures," failures; huge-luck100 elapsed_us=",Time.get_ticks_usec()-lucky_before)
	quit(1 if failures else 0)

func conquer(g,value:bool)->void:
	var snapshot:Dictionary=g.planets.save_data();snapshot.merge(g.crew.save_data())
	snapshot.planets["1"].conquered=value
	check(g.planets.install_snapshot(snapshot,g.db),"planet fixture installs")
	g.invalidate_stat_cache()
func set_crew_level(g,value:int)->void:
	var snapshot:Dictionary=g.crew.save_data()
	for member in snapshot.crew:
		if member.crewId=="navigator":member.level=value
	check(g.crew.install_snapshot(snapshot,g.db),"crew fixture installs")
	g.invalidate_stat_cache()
