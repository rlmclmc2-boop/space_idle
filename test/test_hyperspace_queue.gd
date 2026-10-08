extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const Actors=preload("res://scripts/hyperspace_battle_return.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture():
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.load_hyperspace_routes();g.profile.hyperspace.history={"alpha":{"1":12.0},"beta":{"1":12.0},"gamma":{"1":12.0},"delta":{"1":12.0}}
 g.start(8,false);g.spawn_group();return g
func _initialize()->void:
 var g=fixture();var h=g.hyperspace
 check(g.start_hyperspace_idle("alpha"),"start single background")
 h.advance(g,3.0)
 var before:Dictionary=g.profile.hyperspace.duplicate(true);var actors:=Actors.capture(g)
 for route in ["alpha","beta","gamma","delta"]:
  check(not g.start_hyperspace_idle(route) and not g.start_hyperspace_challenge(route) and not g.set_hyperspace_auto(route,"navigator",true),"all modes reject while alpha background occupies: "+route)
 check(not h.complete(g,int(before.idle.round_id),int(before.idle.run_id),true),"authoritative completion rejects unfinished background work")
 check(g.profile.hyperspace==before and Actors.capture(g)==actors,"repeated busy starts do not debit, reroll, settle drops or move battle")
 var busy:Dictionary=h.queue_status(g)
 check(busy.busy and busy.reason=="queue_busy" and busy.route=="alpha" and busy.mode=="idle" and not busy.message.is_empty(),"unified busy owner and readable reason")
 check(g.stop_hyperspace_idle("alpha") and not g.profile.hyperspace.auto.enabled,"stop explicitly pauses progress and disables continuation")
 var paused:Dictionary=g.profile.hyperspace.paused[0].duplicate(true)
 check(paused.run_id==before.idle.run_id and paused.work==3.0 and paused.luck_state==before.idle.luck_state,"pause preserves original progress and private RNG")
 h.advance(g,30.0)
 check(g.profile.hyperspace.paused[0]==paused and g.profile.hyperspace.inventory.drones.is_empty() and g.profile.hyperspace.idle.is_empty(),"paused task never advances, settles or takes over")
 var view:Dictionary=h.route_view(g,"alpha")
 check(view.paused and view.paused_remaining==9.0,"route exposes paused progress and remaining time")
 check(g.start_hyperspace_idle("alpha") and g.profile.hyperspace.idle.run_id==paused.run_id and g.profile.hyperspace.idle.work==3.0,"explicit matching start resumes original receipt")
 h.advance(g,9.0)
 check(g.profile.hyperspace.idle.is_empty() and g.profile.hyperspace.inventory.drones.size()==1,"resumed one-shot completes exactly once")
 check(not h.claim(g,paused.round_id,paused.run_id),"duplicate resumed reward rejected")
 check(g.start_hyperspace_challenge("beta"),"challenge owns free slot")
 before=g.profile.hyperspace.duplicate(true);actors=Actors.capture(g)
 check(not g.start_hyperspace_idle("delta") and not g.set_hyperspace_auto("gamma","navigator",true) and not g.start_hyperspace_challenge("alpha"),"challenge blocks other modes across routes")
 check(g.profile.hyperspace==before and Actors.capture(g)==actors,"challenge rejected commands preserve world and namespace")
 check(g.exit_hyperspace_challenge() and not h.queue_status(g).busy,"explicit exit releases global slot")
 check(g.set_hyperspace_auto("gamma","navigator",true),"crew policy reserves free slot before first scheduler step")
 before=g.profile.hyperspace.duplicate(true)
 check(not g.start_hyperspace_idle("alpha") and not g.start_hyperspace_challenge("delta") and not g.set_hyperspace_auto("gamma","navigator",true) and g.profile.hyperspace==before,"policy reservation and duplicate enable cannot be bypassed")
 check(h.start_auto(g),"own scheduler starts reserved crew receipt")
 h.advance(g,2.0)
 check(g.stop_hyperspace_idle("gamma") and not g.profile.hyperspace.auto.enabled,"stop crew continuation preserves current receipt paused")
 before=g.profile.hyperspace.duplicate(true);h.advance(g,50.0)
 check(g.profile.hyperspace.paused==before.paused and g.profile.hyperspace.idle.is_empty(),"stopped auto never restarts or claims paused work")
 check(g.start_hyperspace_idle("gamma") and g.profile.hyperspace.idle.run_id==before.paused[0].run_id,"manual continue keeps original crew receipt identity")
 h.advance(g,10.0)
 check(not g.profile.hyperspace.auto.enabled and g.profile.hyperspace.idle.is_empty() and g.profile.hyperspace.inventory.drones.size()==2,"manual continuation of stopped crew task runs only once")
 # Construct the real legacy double-slot state without using the new guarded API.
 var old_background=fixture();old_background.start_hyperspace_idle("alpha");old_background.hyperspace.advance(old_background,4.0)
 var legacy_idle:Dictionary=old_background.profile.hyperspace.idle.duplicate(true)
 var legacy=fixture();legacy.start_hyperspace_challenge("beta")
 var raw:Dictionary=legacy.profile.hyperspace.duplicate(true)
 legacy_idle.run_id=2;raw.idle=legacy_idle;raw.next_run=3;raw.pending_time=1.5;raw.erase("queue_policy_version");raw.erase("paused")
 raw.auto={"enabled":true,"route":"alpha","level":1,"crew_id":"navigator"}
 check(S.valid(raw,h.config,g.db.levels.size()),"actual previous-version challenge/background save accepted")
 var loaded=fixture();check(loaded.hyperspace.load_state(loaded,raw),"load normalizes legacy slots and refunds interrupted challenge")
 check(loaded.profile.hyperspace.active.is_empty() and loaded.profile.hyperspace.idle.is_empty() and not loaded.profile.hyperspace.auto.enabled and loaded.profile.hyperspace.paused.size()==1,"legacy background remains paused after challenge interruption")
 check(loaded.profile.hyperspace.paused[0].work==4.0 and loaded.profile.hyperspace.paused[0].pending_time==1.5 and loaded.profile.hyperspace.paused[0].luck_state==legacy_idle.luck_state,"legacy progress and deferred elapsed time preserved")
 loaded.hyperspace.advance(loaded,100.0)
 check(loaded.profile.hyperspace.inventory.drones.is_empty() and loaded.profile.hyperspace.paused[0].work==4.0,"load cannot silently continue background or produce rewards")
 check(loaded.start_hyperspace_challenge("beta"),"paused legacy progress leaves slot free for explicit challenge")
 loaded.profile.hyperspace.active.work=2.0
 check(loaded.manual_hyperspace.finish(loaded,true) and loaded.hyperspace.claim(loaded,int(loaded.profile.hyperspace.active.round_id),int(loaded.profile.hyperspace.active.run_id)),"challenge completes normally with legacy task paused")
 loaded.hyperspace.advance(loaded,30.0)
 check(loaded.profile.hyperspace.paused[0].work==4.0 and loaded.profile.hyperspace.idle.is_empty() and not loaded.profile.hyperspace.auto.enabled,"challenge success never resumes paused legacy task")
 check(S.valid(loaded.profile.hyperspace,h.config,g.db.levels.size()),"paused receipt survives schema validation")
 check(Transfer.new().prepare_data(loaded.portable_save_data(),loaded.db).error=="","paused progress portable save validates")
 check(loaded.start_hyperspace_idle("alpha") and loaded.profile.hyperspace.pending_time==1.5,"explicit legacy continue restores deferred work")
 loaded.hyperspace.advance(loaded,6.5)
 check(loaded.profile.hyperspace.idle.is_empty() and loaded.profile.hyperspace.inventory.drones.size()==2,"legacy deferred work settled once on explicit continue")
 # Freeze an already generated reward too; no second RNG generation on resume.
 var pending=fixture();pending.start_hyperspace_idle("delta");pending.profile.hyperspace.idle.work=12.0;pending.hyperspace.complete_auto(pending)
 var reward:Dictionary=pending.profile.hyperspace.idle.reward.duplicate(true);var rng_state:String=pending.profile.hyperspace.random_state
 check(pending.hyperspace.route_view(pending,"delta").reasons.stop.is_empty(),"pending receipt stop projection allows safe pause")
 check(pending.stop_hyperspace_idle("delta"),"pending receipt may be safely paused without throwing away reward")
 check(not pending.hyperspace.claim(pending,1,1),"paused pending reward cannot settle behind occupying task")
 check(S.valid(pending.profile.hyperspace,h.config,pending.db.levels.size()),"paused pending reward validates")
 check(pending.start_hyperspace_idle("delta"),"explicit continue pending receipt")
 pending.hyperspace.advance(pending,0.01)
 check(pending.profile.hyperspace.inventory.drones.get(reward.drone.id,{})==reward.drone and pending.profile.hyperspace.random_state==rng_state,"frozen pending reward claimed without reroll")
 print("HYPERSPACE_QUEUE %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
