extends SceneTree
const Resources = preload("res://src/systems/resource_amounts.gd")
const Economy = preload("res://src/systems/economy.gd")
const Research = preload("res://src/systems/research.gd")
const Hyperspace = preload("res://src/systems/hyperspace.gd")
const RunState = preload("res://src/systems/run_state.gd")
const Session = preload("res://src/game_session.gd")
var api
var config: Dictionary
var parameters: Dictionary = {}
var rules: Dictionary = {}
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal",[text]).value
func same(a: Dictionary,b: Dictionary) -> bool:
	return api.apply("compare",[a,b]).scalar==0
func integer(value: Dictionary) -> bool:
	var rounded: Dictionary = api.apply("ceil",[value])
	return rounded.ok and same(rounded.value,value)
func economy(): return Economy.new(parameters,rules,api,RunState.new())
func research():
	var owner = Research.new(config.ai_tech_tree.ai_tech_tree,rules,api,RunState.new())
	var key: String = owner._definitions.keys()[0]
	owner._state.current = key
	owner._state.available[key] = true
	owner._state.required_work[key] = amount("1e6")
	owner.set_investment_text("1","3")
	return owner
func host():
	var owner = Session.new()
	check(owner.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),4242).ok,"actual Session/native initialize")
	check(owner.campaign_system.start_sortie(1,owner.equipment.clear_switch_locks).ok,"real resumable campaign checkpoint")
	return owner
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("extension ",loaded); quit(1); return
	call_deferred("run")
func run() -> void:
	api = ClassDB.instantiate("FoundationAmount")
	config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	for row in config.config.config: parameters[str(row.name)] = row.para_1
	for row in config.game_rules.game_rules: rules[str(row.id)] = row.value
	var owner = economy()
	owner.accept_budget({"1":amount("1.1"),"jewel":amount("0.01"),"antiproton":amount("1.01")},false)
	check(same(owner.budget()["1"],amount("2")) and same(owner.budget().jewel,amount("1")) and same(owner.budget().antiproton,amount("2")),"all wallet resources ceil at adoption")
	var paid: Dictionary = owner.payment({"1":amount("0.01")})
	check(paid.ok and same(paid.wallet["1"],amount("1")) and same(owner.budget()["1"],amount("2")),"fractional cost charges integer candidate, owner unchanged")
	check(owner.can_pay({"1":amount("1.01")}).ok and not owner.can_pay({"1":amount("2.01")}).ok,"can pay uses identical ceil cost")
	var before: Dictionary = owner.save_state()
	var invalid: Dictionary = before.duplicate(true); invalid.yield_progress = {"1":amount("1.1")}
	check(not owner.restore_state(invalid).ok and owner.save_state()==before,"invalid progress rejects before restore writes")
	var registered: Dictionary = owner.register_drops([{"uid":1,"id":"jewel","amount":"0.01","production_base":"0.01","x":0.0,"y":0.0,"jewel":true,"jewelRatio":0.3}],0.0,amount("1"),false)
	check(registered.ok and integer(owner.save_state().drops["native:1"].amount),"pending fragment custody integer")
	var collected: Dictionary = owner.collect_drop("native:1",false,1.0,1.0,{"crew_fragments":amount("1.2"),"jewel":amount("1.1")},false)
	check(collected.ok and integer(collected.amount) and integer(owner.save_state().samples[-1].actual),"final fragment and sample integer, no cents")
	var legacy: Dictionary = owner.save_state(); legacy.wallet.jewel=amount("0.01"); legacy.samples[0].actual=amount("0.01")
	check(owner.restore_state(legacy).ok and same(owner.budget().jewel,amount("1")) and same(owner.save_state().samples[0].actual,amount("1")),"legacy wallet and sample normalized in memory")
	var bulk = economy(); var split = economy()
	bulk.credit_yield("1",amount("1"),1.0,1.0,false)
	for index in 10:
		check(split.credit_yield("1",amount("0.1"),1.0,1.0,false).ok,"continuous yield event")
		if index==4:
			var restored = economy(); check(restored.restore_state(split.save_state()).ok,"yield restore midway"); split=restored
	check(same(bulk.budget()["1"],split.budget()["1"]) and same(split.budget()["1"],amount("1")),"cumulative yield split and restore do not inflate")
	check(integer(split.income_rates(2.0,2.0,60.0,"investment").rates["1"])==false,"income per second remains fractional")
	var ra = research(); var rb = research()
	var wa: Dictionary = {"1":amount("100")}; var wb: Dictionary = wa.duplicate(true)
	var advanced: Dictionary = ra.advance(wa,1.0,amount("1"),false); check(advanced.ok,"research one interval"); wa=advanced.wallet
	for index in 60:
		advanced = rb.advance(wb,1.0/60.0,amount("1"),false)
		check(advanced.ok and integer(advanced.wallet["1"]),"research split integer wallet")
		wb=advanced.wallet
		if index==29:
			var restored = research(); check(restored.restore_state(rb.save_state()).ok,"research service restore"); rb=restored
	check(same(wa["1"],wb["1"]) and same(wb["1"],amount("97")),"research total debit independent of frames")
	var a = host(); var b = host()
	for game in [a,b]: game.economy.accept_budget({"chrono":amount("100")},false); game._chrono_speed=2
	check(a._accept_real_time(1.0,true).ok,"chrono one interval")
	for index in 60:
		check(b._accept_real_time(1.0/60.0,true).ok and integer(b.economy.budget().chrono),"chrono split integer wallet")
	check(same(a.economy.budget().chrono,b.economy.budget().chrono) and same(b.economy.budget().chrono,amount("99")),"chrono total debit independent of frames")
	var packed: Dictionary = b.save_payload(); check(packed.ok,"Session saves paid progress")
	var Codec = load("res://foundation/host/state_codec.gd")
	var unpacked: Dictionary = Codec.unpack(packed.payload)
	check(unpacked.ok,"Session service state unpack")
	var c = Session.new(); var restored_session: Dictionary = c.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),4242,unpacked.value.native,unpacked.value)
	if not restored_session.ok: printerr("SESSION_RESTORE ",restored_session)
	check(restored_session.ok,"Session restores paid progress without user files")
	check(c._chrono_progress==b._chrono_progress,"chrono prepaid progress restored")
	for late in [false,true]:
		var ea = Hyperspace.new(config,api,RunState.new(),91); var eb = Hyperspace.new(config,api,RunState.new(),91)
		for system in [ea,eb]:
			var state: Dictionary = system.save_state(); state.energy=0.1
			check(system.restore_state(state).ok and same(system.save_state().energy,amount("1")),"legacy energy ceil in candidate")
		var cleared: Dictionary = {int(ea._parameters.late_supply_unlock_stage):true} if late else {}
		ea.advance_online(1.0,cleared)
		for index in 60:
			eb.advance_online(1.0/60.0,cleared)
			check(integer(eb.save_state().energy),"energy integer every frame")
			if index==29:
				var restored = Hyperspace.new(config,api,RunState.new(),91); check(restored.restore_state(eb.save_state()).ok,"energy meter restore"); eb=restored
		check(same(ea.save_state().energy,eb.save_state().energy),"energy same elapsed split/ramp/restore")
		check(not str(eb.online_status().energy_text).contains("."),"energy integer display")
	var hs = a.hyperspace_system
	var prepare: Dictionary = hs.prepare_manual("alpha",8,{"stage":8,"point":0,"guard":false,"guard_point":0})
	check(prepare.ok,"real pending reward fixture admission")
	hs.accept_manual(prepare.receipt)
	var state: Dictionary = hs.save_state(); var receipt: Dictionary = state.manual
	receipt.status="CompletedPending"; receipt.reward={"drone":{},"materials":{"degenerate_matter":0.1},"ultimate_cores":0,"hanging_rewards":{}}
	state.receipts[receipt.run_id]=receipt
	var restored_hs: Dictionary = hs.restore_state(state)
	if not restored_hs.ok: printerr("HS_RESTORE ",restored_hs)
	check(restored_hs.ok and same(amount(str(hs.manual_receipt().reward.materials.degenerate_matter)),amount("1")),"legacy fixed reward integer full material unit")
	var converted: Dictionary = a._hyperspace_forge_costs({"costs":{"antiproton":"0.1"}})
	check(converted.ok and same(converted.costs.antiproton,amount("1")),"material final owner fee integer")
	check(same(Resources.whole(amount("1.23456789e1000"),api).value,amount("1.23456789e1000")),"huge resource never float")
	check(Resources.integer_text(amount("1.23456789e1000"),api).ok and not Resources.integer_text(amount("1.23456789e1000"),api).text.contains("."),"huge resource integer coefficient display")
	var tiny: Dictionary = Resources.settle(amount("1e-100"),amount("0"),api)
	check(tiny.ok and Resources.progress_map({"1":tiny.progress},api).ok,"Amount-rounded one-unit service remainder remains valid")
	check(Resources.settle(amount("1e-100"),tiny.progress,api).ok,"tiny continuous service cannot become repeated per-frame rounding")
	await process_frame
	print("INTEGER_RESOURCES checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
