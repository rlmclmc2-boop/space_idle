extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Actors=preload("res://scripts/hyperspace_battle_return.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func opened(db):
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
	var state=g.state;var point=g.group_index;var enemy=g.enemies[0].duplicate(true);var hp=g.player.armour;var energy=g.profile.hyperspace.energy
	var frozen:=Actors.capture(g)
	check(Actors.valid(frozen),"live production battle serializable")
	if failures:
		call_deferred("quit",1);return
	check(g.start_hyperspace_challenge("alpha"),"immediate challenge during actual combat")
	check(g.profile.hyperspace.active.level==1 and g.profile.hyperspace.active.ticket==0 and g.profile.hyperspace.energy==energy,"first challenge layer1 without ticket")
	var export:Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(export,db).error=="","active combat return portable export validates")
	check(g.exit_hyperspace_challenge(),"immediate exit")
	check(g.stage==14 and g.state==state and g.group_index==point and g.enemies[0]==enemy and g.player.armour==hp,"exit retains enemy life, battle point and player health")
	check(Actors.capture(g)==frozen,"all captured actor state exact on exit")
	if failures:
		call_deferred("quit",1);return
	check(not g.exit_hyperspace_challenge() and g.profile.hyperspace.energy==energy,"duplicate exit cannot refund or change state")
	var reloaded=opened(db);reloaded.load_progress_data(export);reloaded.resume_progress()
	check(reloaded.state==state and reloaded.stage==14 and reloaded.enemies[0]==enemy,"reload interrupted challenge restores main combat")
	check(reloaded.profile.hyperspace.energy==energy and reloaded.profile.hyperspace.active.is_empty(),"reload zero-ticket settlement once")
	check(g.start_hyperspace_challenge("alpha"),"repeat challenge allowed")
	g.profile.hyperspace.active.work=12.0
	check(g.manual_hyperspace.finish(g,true),"actual manual success transition")
	var pending:Dictionary=g.profile.hyperspace.active.duplicate(true)
	check(g.hyperspace_route_view("alpha").current_layer==1 and h.best_x1(g,"alpha",2)==0,"success advances only won layer, next has no borrowed time")
	check(h.claim(g,pending.round_id,pending.run_id) and not h.claim(g,pending.round_id,pending.run_id),"reward once")
	var main_before:=Actors.capture(g)
	check(g.start_hyperspace_idle("alpha"),"one background round")
	var idle:Dictionary=g.profile.hyperspace.idle.duplicate(true)
	check(idle.duration==12 and Actors.capture(g)==main_before,"background starts without battle switch")
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
	var legacy:Dictionary=h.fresh();legacy.version=4;legacy.erase("idle");legacy.history={"alpha":{"5":33.0}};legacy.auto={"enabled":true,"route":"alpha","level":34,"crew_id":"navigator"}
	check(S.valid(legacy,h.config,db.levels.size()),"real legacy shape supported")
	var migrated:=S.migrate(legacy)
	check(migrated.history==legacy.history and migrated.auto.level==34,"migration preserves earned history without inventing selected progress")
	# Restore live continuous beams and staged missile launches with shared target identity.
	var battle=opened(db)
	battle.profile.loadout.weapons=[{"key":"longLaser","level":14},{"key":"missile","level":14}]
	battle.invalidate_stat_cache();battle.start(14,false);battle.spawn_group()
	battle.cooldowns[battle.slot_id("weapons",1)]=0.0
	battle.tick(0.2)
	check(not battle.projectiles.is_empty() and not battle.missile_queue.is_empty(),"real beam and missile ejection before suspension")
	var battle_graph:=Actors.capture(battle)
	check(battle.start_hyperspace_challenge("beta") and battle.exit_hyperspace_challenge(),"live beam and missile immediate round trip")
	check(Actors.capture(battle)==battle_graph,"beam projectile and delayed launch graph exact")
	for shot in battle.projectiles:
		if shot.get("beam",false):check(battle.long_laser_valid(shot),"restored beam keeps player, enemy and equipment identity")
	for packet in battle.missile_queue:check(is_same(packet.source,battle.player) and is_same(packet.target,battle.enemies.filter(func(e):return e.uid==packet.target.uid)[0]),"restored missile queue shares actor identity")
	battle.tick(0.01)
	check(not battle.projectiles.is_empty(),"restored attacks remain live on following tick")
	# Freeze additive permanent/crew luck when starting, including without a crew.
	g.profile.planets["1"].conquered=true
	check(g.hyperspace_route_view("alpha").permanent_luck==100.0,"permanent conquered reward without crew")
	check(g.start_hyperspace_idle("alpha"),"permanent luck background starts")
	var lucky_receipt:Dictionary=g.profile.hyperspace.idle.duplicate(true)
	check(lucky_receipt.luck==100.0 and lucky_receipt.crew_snapshot=="","permanent luck frozen in receipt")
	g.profile.planets["1"].conquered=false
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
	# Legacy paid manual interruption refunds exactly once; pending prizes stay frozen.
	var old:Dictionary=h.fresh();old.version=4;old.erase("idle");old.next_run=2;old.energy=0.0
	old.active={"round_id":1,"run_id":1,"status":"started","mode":"manual","route":"alpha","level":5,"crew_id":"","return_journey":{},"ticket":108000.0,"duration":0.0,"work":0.0,"reward":{}}
	check(S.valid(old,h.config,db.levels.size()),"legacy paid receipt remains valid")
	var old_game=opened(db);check(old_game.hyperspace.load_state(old_game,old),"legacy receipt migration")
	check(old_game.profile.hyperspace.energy==108000.0 and not old_game.hyperspace.complete(old_game,1,1,false),"legacy refund once, no replay")
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
