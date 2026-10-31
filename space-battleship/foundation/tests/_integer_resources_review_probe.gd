extends SceneTree
const Session = preload("res://src/game_session.gd")
const Codec = preload("res://foundation/host/state_codec.gd")
var api
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal",[text]).value
func same(a: Dictionary,b: Dictionary) -> bool:
	return api.apply("compare",[a,b]).scalar==0
func same_state(a: Dictionary,b: Dictionary) -> bool:
	# NaN is deliberately invalid input and is not equal to itself.
	return var_to_bytes(a)==var_to_bytes(b)
func host(balance: String = "5"):
	var game = Session.new()
	check(game.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),8675309).ok,"actual Session/native initialization")
	game.economy.accept_budget({"chrono":amount(balance)},false)
	game._chrono_speed=2
	check(game.pause_reasons.is_empty() and not game.campaign_system.departure_active(),"no pause or departure")
	return game
func pending(game, materials: Dictionary) -> int:
	var system = game.hyperspace_system
	var prepared: Dictionary = system.prepare_manual("alpha",8,{"stage":8,"point":0,"guard":false,"guard_point":0})
	check(prepared.ok,"original manual receipt admission")
	system.accept_manual(prepared.receipt)
	system._manual.status="CompletedPending"
	system._manual.reward={"drone":{},"materials":materials.duplicate(true),"ultimate_cores":0,"hanging_rewards":{}}
	return int(system._manual.run_id)
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("extension ",loaded);quit(1);return
	call_deferred("run")
func run() -> void:
	api=ClassDB.instantiate("FoundationAmount")
	var game=host()
	var id: int = pending(game,{"degenerate_matter":1})
	var valid: Dictionary = game.hyperspace_system.save_state()
	check(game.hyperspace_system.restore_state(valid).ok,"canonical valid receipt baseline")
	valid=game.hyperspace_system.save_state()
	var wallet: Dictionary = game.economy.budget().duplicate(true)
	for bad in [{"":0.1},{"degenerate_matter":-0.1},{"degenerate_matter":{"m":NAN,"e":0}}]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.manual.reward.materials=bad.duplicate(true)
		malformed.receipts[id]=malformed.manual.duplicate(true)
		var restored: Dictionary = game.hyperspace_system.restore_state(malformed)
		check(not restored.ok and same_state(game.hyperspace_system.save_state(),valid),"malformed reward restore has zero adoption")
		check(game.economy.budget()==wallet and game.run_state.is_running(),"restore failure leaves wallet and run state unchanged")
		# Defend live credit separately, even if a bad receipt bypasses restore.
		game.hyperspace_system._manual.reward.materials=bad.duplicate(true)
		var before: Dictionary = game.hyperspace_system.save_state()
		for attempt in 2:
			var claimed: Dictionary = game.claim_hyperspace(id)
			check(not claimed.ok and same_state(game.hyperspace_system.save_state(),before) and game.economy.budget()==wallet,"malformed claim cannot mark or credit on retry")
		check(game.hyperspace_system.restore_state(valid).ok,"valid fixture restored after rejected live claim")
	var claimed: Dictionary = game.claim_hyperspace(id)
	check(claimed.ok and game.hyperspace_system.manual_receipt().status=="Claimed","valid claim accepted")
	check(same(game.economy.budget().degenerate_matter,amount("1")),"valid claim credits once")
	var after: Dictionary = game.economy.budget().duplicate(true)
	claimed=game.claim_hyperspace(id)
	check(claimed.ok and claimed.already_claimed and game.economy.budget()==after,"already claimed cannot pay twice")
	# Zero reward makes accept_budget legitimately false, still a successful claim.
	var empty=host();var empty_id: int=pending(empty,{"degenerate_matter":0})
	empty.economy.accept_budget({"chrono":amount("5"),"degenerate_matter":amount("0")},false)
	var empty_wallet: Dictionary=empty.economy.budget().duplicate(true)
	check(empty.claim_hyperspace(empty_id).ok and empty.hyperspace_system.manual_receipt().status=="Claimed" and empty.economy.budget()==empty_wallet,"unchanged wallet false is not failure")
	# The reported frame bug: real Session.frame, no pause/departure, include backlog.
	var once=host();var split=host()
	once.frame(10.0,true)
	for index in 10: split.frame(1.0,true)
	check(once.run_state.is_running() and split.run_state.is_running(),"real frames remain running")
	check(absf(once.game_time+once.pending_seconds-15.0)<1e-9 and absf(split.game_time+split.pending_seconds-15.0)<1e-9,"ten seconds versus ten one-second frames both accept fifteen")
	check(same(once.economy.budget().chrono,amount("0")) and same(split.economy.budget().chrono,amount("0")),"real frame paths both charge exactly five")
	for balance in ["0","5","10"]:
		var a=host(balance);var b=host(balance)
		var one: Dictionary=a._accept_real_time(10.0,true)
		var total: float=0.0
		for index in 10:
			var part: Dictionary=b._accept_real_time(1.0,true)
			check(part.ok,"split acceptance succeeds")
			total+=part.accepted
		var expected: float=10.0 if balance=="0" else 15.0 if balance=="5" else 20.0
		check(one.ok and absf(one.accepted-expected)<1e-9 and absf(total-expected)<1e-9,"zero insufficient and exact boundary accepted equally")
		check(same(a.economy.budget().chrono,b.economy.budget().chrono),"zero insufficient and exact boundary charged equally")
		var snapshot: Dictionary=b.economy.save_state();var meter: Dictionary=b._chrono_meter.duplicate(true);var progress: Dictionary=b._chrono_progress.duplicate(true)
		check(b._accept_real_time(0.0,true).accepted==0.0 and b.economy.save_state()==snapshot and b._chrono_meter==meter and b._chrono_progress==progress,"zero window has no charge or meter mutation")
	# Restore an already partially paid interval without writing any user file.
	var saving=host()
	check(saving.campaign_system.start_sortie(1,saving.equipment.clear_switch_locks).ok,"restore-valid original campaign checkpoint")
	saving.campaign_system.consume_departure(100.0)
	var head: Dictionary=saving._accept_real_time(2.5,true)
	var packed: Dictionary=saving.save_payload();check(packed.ok,"service interval packs")
	var decoded: Dictionary=Codec.unpack(packed.payload);check(decoded.ok,"service interval unpacks")
	var resumed=Session.new()
	var ready: Dictionary=resumed.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),8675309,decoded.value.native,decoded.value)
	check(ready.ok,"actual Session candidate restore")
	if ready.ok:
		var tail: Dictionary=resumed._accept_real_time(7.5,true)
		check(head.ok and tail.ok and absf(head.accepted+tail.accepted-15.0)<1e-9 and same(resumed.economy.budget().chrono,amount("0")),"restored service interval accepts fifteen and charges five")
	await process_frame
	print("INTEGER_RESOURCE_REVIEW_FIXES checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
