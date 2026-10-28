extends SceneTree
const Reactor = preload("res://src/systems/reactor.gd")
const Economy = preload("res://src/systems/economy.gd")
const Session = preload("res://src/game_session.gd")
const RunState = preload("res://src/systems/run_state.gd")
class Meter extends RefCounted:
	var native
	var calls: Dictionary = {}
	func apply(op: String, args: Array) -> Dictionary:
		calls[op] = int(calls.get(op,0)) + 1
		return native.apply(op,args)
var native
var api := Meter.new()
var parameters: Dictionary = {}
var rules: Dictionary = {}
var failures: Array = []
var assertions: int = 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)
func amount(text: String) -> Dictionary:
	return native.apply("from_decimal",[text]).value
func same(a: Dictionary,b: Dictionary) -> bool:
	return native.apply("compare",[a,b]).scalar == 0
func equal(text,expected: String) -> bool:
	return text is String and same(amount(text),amount(expected))
func inputs(factor: String = "1",free: float = 0.0) -> Dictionary:
	return {"capacity":amount(factor),"free_charge":free}
func fixture(script):
	var owner = script.new(parameters,api,RunState.new())
	owner.refresh_availability(func(_kind,_id):return true,false)
	check(owner.prepare(inputs()).ok,"fixture prepares accepted source")
	owner.accept()
	return owner
func publisher(owner) -> Callable:
	return func(_f,_w,_kind):owner.accept();return {"ok":true}
func by_id(model: Dictionary,id: String) -> Dictionary:
	for row in model.modules:
		if row.id == id:return row
	return {}
func old_readings(model: Dictionary) -> Dictionary:
	var result: Dictionary = model.duplicate(true)
	result.erase("load")
	for row in result.get("modules",[]):
		for field in ["ratio","load","has_free","enabled"]:row.erase(field)
	return result
func flush() -> void:
	await process_frame
	await process_frame
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired: ",loaded);quit(1);return
	call_deferred("run")
func run() -> void:
	native = ClassDB.instantiate("FoundationAmount");api.native=native
	var config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	for row in config.config.config:parameters[str(row.name)]=row.para_1
	for row in config.game_rules.game_rules:rules[str(row.id)]=row.value
	var old_reactor = load(OS.get_environment("SPACE_IDLE_REACTOR_PRESENTATION_BASELINE"))
	var old_economy = load(OS.get_environment("SPACE_IDLE_ECONOMY_PRESENTATION_BASELINE"))
	var owner = fixture(Reactor);var original = fixture(old_reactor)
	check(not owner._presentation_before.available and not owner._presentation_before.ready,"initial baseline retained before availability/state replacement")
	var events: Array = [];var batch := {"tail":false}
	var weak = weakref(owner)
	var observer: Callable = func(tags):events.append({"tags":tags.duplicate(),"model":weak.get_ref().presentation_model(),"tail":batch.tail})
	owner.presentation_changed.connect(observer)
	check(events.is_empty(),"no synchronous initial presentation event")
	batch.tail=true
	await flush()
	check(events.size()==1 and events[0].tail and events[0].model.ok,"initial deferred event observes fully accepted tail")
	events.clear()
	var before: Dictionary = owner._state.duplicate(true)
	var pending: Dictionary = owner._prepared_state.duplicate(true)
	var model: Dictionary = owner.presentation_model()
	var old: Dictionary = original._accepted_plan_readings()
	var reading: Dictionary = model.duplicate(true)
	for key in ["level","can_allocate","reason"]:reading.erase(key)
	check(old_readings(reading)==old,"current original canonical readings unchanged")
	check(model.level==int(before.level) and model.can_allocate and not model.has("purchase_quote"),"current and quote outputs separated")
	for row in model.modules:
		check(row.ratio==0.0 and row.load==0.0 and not row.has_free and is_finite(row.ratio),"zero assigned actual row " + str(row.id))
	model.modules[0].manual="changed"
	check(owner._state==before and owner._prepared_state==pending and not owner._presentation_queued,"deep reads pure and do not mark notices")
	check(owner.prepare(inputs("2",0.25)).ok,"pending capacity/free fixture")
	check(owner.presentation_model().capacity==original._accepted_plan_readings().capacity,"current ignores pending inputs and values")
	await flush();check(events.is_empty(),"prepare produces zero presentation events")
	owner.discard_prepared()
	check(not owner.refresh(inputs("2",0.25),func(_f,_w,_k):return {"ok":false,"reason":"FixtureReject"}).ok,"refresh rejection")
	await flush();check(events.is_empty() and owner._state==before,"discard/reject keep state and do not notify")
	var one: Dictionary = owner.allocate_text("weapons","10",inputs(),publisher(owner))
	var old_one: Dictionary = original.allocate_text("weapons","10",inputs(),publisher(original))
	check(one==old_one and owner.save_state()==original.save_state(),"single allocation original result/state")
	check(same(owner._presentation_before.rows.weapons.assigned,amount("0")),"first accepted allocation baseline is BEFORE replacement")
	check(events.is_empty(),"accept is not a synchronous broadcast")
	owner.allocate_text("weapons","20",inputs(),publisher(owner))
	await flush();check(events.size()==1 and events[0].tags.has("allocation") and equal(by_id(events[0].model,"weapons").manual,"20"),"same-frame accepted writes merge to final state")
	events.clear();before=owner._state.duplicate(true)
	owner.allocate_text("weapons","30",inputs(),publisher(owner))
	owner.allocate_text("weapons","20",inputs(),publisher(owner))
	await flush();check(events.is_empty() and owner._state==before,"A-B-A produces no presentation event")
	owner.allocate_text("weapons","20",inputs(),publisher(owner))
	await flush();check(events.is_empty(),"identical accepted publish produces no presentation event")
	var forecast: Dictionary = owner.allocation_plan_preview({"kind":"equal"},inputs())
	check(forecast.ok and forecast.current.modules[0].has("ratio") and forecast.target.modules[0].has("ratio"),"current and equal target share finite display helper")
	var total_ratio: float = 0.0
	for row in forecast.target.modules:total_ratio+=float(row.ratio)
	check(is_finite(total_ratio) and total_ratio<=1.0000001,"equal target ratios finite and bounded")
	var old_forecast: Dictionary = original.allocation_plan_preview({"kind":"equal"},inputs())
	check(old_readings(forecast.target)==old_forecast.target,"equal forecast original numeric readings")
	var plan: Dictionary = {}
	for row in forecast.target.modules:plan[str(row.id)]=str(row.manual)
	var choices := {"count":0}
	var choice_observer: Callable=func():choices.count+=1
	owner.choices_changed.connect(choice_observer)
	var previous_events: int=events.size()
	var actual: Dictionary = owner.apply_allocation_plan(plan,inputs(),publisher(owner))
	var old_actual: Dictionary = original.apply_allocation_plan(plan,inputs(),publisher(original))
	check(actual.ok and old_actual.ok and old_readings(actual.actual)==old_actual.actual and owner.save_state()==original.save_state(),"whole-plan original acceptance and state")
	await flush()
	check(choices.count==1 and events.size()==previous_events+1,"legacy choices unchanged; new presentation-only observer reads once")
	events.clear()
	check(owner.apply_allocation_plan(plan,inputs(),publisher(owner)).ok,"same confirmed whole plan accepted")
	await flush()
	check(choices.count==2 and events.is_empty(),"legacy choices cannot be used as a second actual-change source")
	owner.choices_changed.disconnect(choice_observer)
	# Real free supply drives actual load even when all manual allocations are zero.
	for id in plan:plan[id]="0"
	check(owner.apply_allocation_plan(plan,inputs("1",0.25),publisher(owner)).ok,"free-only legal accepted state")
	await flush();events.clear()
	model=owner.presentation_model()
	for row in model.modules:check(row.ratio==0.0 and row.has_free and row.load>0.0,"free-only real load " + str(row.id))
	check(model.load>0.0,"core load includes actual free supply")
	owner.refresh(inputs("1",2.0),publisher(owner));await flush();events.clear()
	model=owner.presentation_model();check(model.load==1.0,"core saturation")
	for row in model.modules:check(row.load==1.0 and not equal(row.effective,model.capacity),"row saturation preserves full effective text " + str(row.id))
	owner.refresh(inputs("1e2000",0.25),publisher(owner));await flush();events.clear()
	model=owner.presentation_model()
	check(model.ok and is_finite(float(model.load)),"huge Amount current load stays finite")
	for row in model.modules:check(is_finite(float(row.ratio)) and is_finite(float(row.load)) and row.load>0.0 and row.load<=1.0,"huge Amount display ratio without numeric reconstruction " + str(row.id))
	owner.refresh(inputs("0",2.0),publisher(owner));await flush();events.clear()
	model=owner.presentation_model();check(model.ok and equal(model.capacity,"0") and model.load==0.0,"legal zero capacity")
	for row in model.modules:check(equal(row.free,"0") and equal(row.effective,"0") and equal(row.factor,"1") and row.ratio==0.0 and row.load==0.0,"zero capacity remains original zero supply and unit factor " + str(row.id))
	var legal_zero: Dictionary=owner._state.duplicate(true)
	owner._state=legal_zero.duplicate(true);owner._state._factors.weapons.free=amount("1")
	check(not owner.presentation_model().ok,"impossible zero-capacity/free-positive fixture is not shown as a legal zero")
	owner._state=legal_zero
	# Unknown is not zero; restoration must notify readiness without inventing caches.
	var saved: Dictionary = owner.save_state()
	check(owner.restore_state(saved).ok,"restore accepted state")
	check(owner.presentation_model().reason=="ReactorSnapshotUnavailable","missing accepted cache is unknown")
	await flush();check(events.size()==1 and events[0].tags.has("readiness"),"restore readiness event")
	events.clear();check(not owner.restore_state({}).ok,"bad restore rejected")
	await flush();check(events.is_empty(),"bad restore no notification")
	owner.refresh(inputs(),publisher(owner));await flush();events.clear()
	owner.refresh_availability(func(kind,id):return kind=="feature" or id!="condensation",false)
	check(owner.presentation_model().reason=="ReactorSnapshotUnavailable","availability/cache mismatch is unknown")
	owner.refresh(inputs(),publisher(owner));await flush()
	check(events.size()==1 and events[0].tags.has("availability") and events[0].model.modules.size()==3,"silent availability plus acceptance merges once")
	events.clear()
	# Delivery clears the old marker before callbacks; reentrant acceptance is a new event.
	var reentry := {"done":false}
	var reentrant: Callable = func(_tags):
		if not reentry.done:
			reentry.done=true
			var current = weak.get_ref();current.allocate_text("weapons","19",inputs(),publisher(current))
	owner.presentation_changed.connect(reentrant)
	owner.allocate_text("weapons","18",inputs(),publisher(owner));await flush()
	check(events.size()==2 and equal(by_id(owner.presentation_model(),"weapons").manual,"19"),"reentrant presentation change not overwritten")
	owner.presentation_changed.disconnect(reentrant);events.clear()
	# Price and budget are separate; only per-level costs are cached, never affordability.
	var money = Economy.new(parameters,rules,api,RunState.new())
	var old_money = old_economy.new(parameters,rules,api,RunState.new())
	var budget_events: Array = []
	var money_ref = weakref(money)
	var budget_observer: Callable = func(ids):budget_events.append({"ids":ids.duplicate(),"wallet":money_ref.get_ref().budget().duplicate(true)})
	money.budget_changed.connect(budget_observer)
	var costs: Dictionary = owner.purchase_preview(money.can_pay)
	check(costs.ok and not costs.can_purchase,"initial quote readable but unaffordable")
	var raw: Dictionary = original._purchase(owner._state.duplicate(true),1,false,original._parameters,api)
	for id in raw.costs:check(equal(costs.costs[id],native.apply("to_display",[raw.costs[id]]).text),"quote exactly original cost " + str(id))
	var cost_id: String = str(costs.costs.keys()[0])
	money.accept_budget({cost_id:amount("1000000")},false)
	check(money._budget_before.is_empty(),"budget baseline retained before first wallet replacement")
	check(budget_events.is_empty(),"silent budget acceptance not synchronous")
	await flush();check(budget_events.size()==1 and budget_events[0].ids==PackedStringArray([cost_id]),"true silent budget resource delivered")
	budget_events.clear()
	api.calls.clear()
	var paid_quote: Dictionary = owner.purchase_preview(money.can_pay)
	check(paid_quote.can_purchase and paid_quote.costs==costs.costs,"budget refresh retains cost and updates ability")
	check(api.calls.get("pow",0)==0 and api.calls.get("sum_ceiled_geometric",0)==0 and api.calls.get("to_ratio",0)==0 and api.calls.get("to_display",0)==0,"budget-only quote has no pricing powers, model formatting or preview ratios")
	paid_quote.costs[cost_id]="0"
	check(owner.purchase_preview(money.can_pay).costs==costs.costs,"quote text result detached")
	owner.purchase_preview(func(values):values[cost_id].m="9";return {"ok":true})
	check(owner.purchase_preview(money.can_pay).costs==costs.costs,"quote callback cannot poison cached raw costs")
	var budget_before: Dictionary = money.save_state()
	money.accept_budget({cost_id:amount("2000000")},false)
	money.accept_budget(budget_before.wallet,false)
	await flush();check(budget_events.is_empty(),"budget A-B-A no signal")
	money.accept_budget(budget_before.wallet,false)
	money.payment({cost_id:amount("1")});money.can_pay({cost_id:amount("1")})
	await flush();check(budget_events.is_empty(),"unchanged acceptance/payment/check do not notify")
	var same_wallet: Dictionary = money.budget().duplicate(true);same_wallet["absent_zero"]=amount("0")
	money.accept_budget(same_wallet,false);await flush()
	check(budget_events.is_empty(),"absent and encoded zero are same actual balance")
	money.credit_yield("1",amount("5"),0.0,0.0,false);await flush()
	check(budget_events.size()==1 and budget_events[0].ids==PackedStringArray(["1"]),"credit_yield signals actual resource only")
	budget_events.clear()
	money.credit_yield("1",amount("0"),0.0,0.0,false)
	await flush();check(budget_events.is_empty(),"zero credit no event")
	var restored: Dictionary = money.save_state();restored.wallet[cost_id]=amount("3000000")
	check(money.restore_state(restored).ok,"economy restore fixture")
	await flush();check(budget_events.size()==1 and budget_events[0].ids==PackedStringArray([cost_id]),"economy restore baseline is before replacement")
	budget_events.clear();check(not money.restore_state({}).ok,"economy invalid restore rejected")
	await flush();check(budget_events.is_empty(),"invalid economy restore no notification")
	var factors := {"resource_collection":amount("1"),"uranium":amount("1")}
	var spawned: Dictionary = money._spawn_timed_drop(cost_id,"10",1.0,amount("1"),Vector2.ZERO,0.0,factors)
	check(spawned.ok,"actual timed drop birth fixture")
	money._advance_timed_drops(100.0,1.0,1.0,factors);money.prune_income(10000.0,10000.0,60.0);money.balances_text()
	await flush();check(budget_events.is_empty(),"drop birth/movement, window pruning and display have no budget signal")
	var key: String = str(money._drops.keys()[0])
	check(money.collect_drop(key,false,2.0,2.0,factors,false).ok,"actual collection")
	await flush();check(budget_events.size()==1 and budget_events[0].ids==PackedStringArray([cost_id]),"collect_drop signals only actual wallet change")
	budget_events.clear()
	money.accept_budget({cost_id:amount("1e100")},false);await flush();budget_events.clear()
	money.credit_yield(cost_id,amount("1"),0.0,0.0,false);await flush()
	check(budget_events.is_empty(),"positive credit lost at Amount precision is no actual balance change")
	var budget_reentry := {"done":false}
	var budget_reentrant: Callable = func(_ids):
		if not budget_reentry.done:
			budget_reentry.done=true;money_ref.get_ref().accept_budget({cost_id:amount("120")},false)
	money.budget_changed.connect(budget_reentrant)
	money.accept_budget({cost_id:amount("110")},false);await flush()
	check(budget_events.size()==2 and same(money.budget()[cost_id],amount("120")),"budget callback reentry cannot be overwritten")
	money.budget_changed.disconnect(budget_reentrant)
	# Existing command results and bookkeeping remain equivalent to unmodified source.
	for ledger in [money,old_money]:ledger.accept_budget({cost_id:amount("1000")},false)
	check(money.payment({cost_id:amount("20")})==old_money.payment({cost_id:amount("20")}),"payment original candidate unchanged")
	for ledger in [money,old_money]:ledger.credit_yield(cost_id,amount("2"),0.0,0.0,false)
	check(money.budget()==old_money.budget(),"credit original wallet unchanged")
	await flush()
	# Actual Session/native command and external refresh acceptance paths.
	var baseline_session = load(OS.get_environment("SPACE_IDLE_REACTOR_SESSION_BASELINE"))
	var host = Session.new();var old_host=baseline_session.new()
	var config_path: String=OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")
	check(host.initialize(config_path,314159).ok and old_host.initialize(config_path,314159).ok,"both real Session/native instances initialize")
	for game in [host,old_host]:
		game.reactor_system.refresh_availability(func(_kind,_id):return true,false)
		check(game.reactor_system.refresh(game.reactor_inputs(),game.publish_reactor).ok,"real native reactor refresh")
		game.economy.accept_budget({cost_id:amount("1000000")},false)
	await flush()
	var native_events: Array=[];var host_ref=weakref(host)
	var native_observer: Callable=func(tags):native_events.append({"tags":tags.duplicate(),"level":host_ref.get_ref().reactor_system.presentation_model().level,"wallet":host_ref.get_ref().economy.budget().duplicate(true)})
	host.reactor_system.presentation_changed.connect(native_observer)
	var price_before: Dictionary=host.reactor_system.purchase_preview(host.economy.can_pay)
	var real: Dictionary=host.reactor_system.purchase(1,false,host.reactor_inputs(),host.economy.payment,host.publish_reactor)
	var real_old: Dictionary=old_host.reactor_system.purchase(1,false,old_host.reactor_inputs(),old_host.economy.payment,old_host.publish_reactor)
	check(real==real_old and real.ok and host.reactor_system.save_state()==old_host.reactor_system.save_state() and host.economy.budget()==old_host.economy.budget(),"actual native purchase and wallet baseline parity")
	check(native_events.is_empty(),"native command returns before deferred notice")
	await flush();check(native_events.size()==1 and native_events[0].tags.has("level") and native_events[0].wallet==host.economy.budget(),"native notice sees completed wallet and accepted level")
	var price_after: Dictionary=host.reactor_system.purchase_preview(host.economy.can_pay)
	var original_next: Dictionary=old_host.reactor_system._purchase(old_host.reactor_system._state,1,false,old_host.reactor_system._parameters,old_host.amount_api)
	check(price_after.costs!=price_before.costs,"actual accepted level invalidates old quote cost")
	for id in original_next.costs:check(equal(price_after.costs[id],native.apply("to_display",[original_next.costs[id]]).text),"new level quote matches original source " + str(id))
	native_events.clear()
	for game in [host,old_host]:
		var previous: Dictionary=game._world_factors
		game._world_factors=previous.duplicate();game._world_factors.capacity=amount("2");game._world_factors.free_charge=0.25
		check(game._publish_world_values(previous).ok,"external world native value publication")
	check(native_events.is_empty(),"external acceptance does not synchronously expose partial world state")
	await flush();check(native_events.size()==1 and native_events[0].tags.has("capacity") and native_events[0].tags.has("free"),"external world accept deferred coverage")
	check(host.reactor_system.save_state()==old_host.reactor_system.save_state(),"world acceptance original state parity")
	native_events.clear()
	for game in [host,old_host]:
		var next_world: Dictionary=game._world_factors.duplicate();next_world.capacity=amount("3");game._world_factors=next_world
		check(game.publish_equipment_refit(game.economy.budget(),"refit","",null,false).ok,"real native equipment/world refit accepts Reactor")
	await flush()
	check(native_events.size()==1 and native_events[0].tags.has("capacity"),"equipment refit external accept notifies once")
	check(host.reactor_system.save_state()==old_host.reactor_system.save_state(),"refit original accepted Reactor state parity")
	host.reactor_system.presentation_changed.disconnect(native_observer)
	owner.presentation_changed.disconnect(observer);money.budget_changed.disconnect(budget_observer)
	await flush()
	if failures.is_empty():print("PASS: ",assertions," reactor presentation/budget assertions; baseline numeric and native publication parity; accepted snapshots, pre-replacement baselines, deferred net changes/reentry; cached +1 affordability without model/preview/power refresh.")
	else:printerr("FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
