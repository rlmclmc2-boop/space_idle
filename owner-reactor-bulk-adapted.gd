extends SceneTree
const Reactor = preload("res://src/systems/reactor.gd")
const Economy = preload("res://src/systems/economy.gd")
const Session = preload("res://src/game_session.gd")
const RunState = preload("res://src/systems/run_state.gd")
class Meter extends RefCounted:
	var native
	var calls: Dictionary = {}
	var fail_operation: String = ""
	func apply(op: String, args: Array) -> Dictionary:
		calls[op] = int(calls.get(op, 0)) + 1
		if op == fail_operation: return {"ok":false,"error":"FixtureAmountFailure"}
		return native.apply(op, args)
var native
var api := Meter.new()
var parameters: Dictionary = {}
var rules: Dictionary = {}
var old
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func amount(text: String) -> Dictionary:
	return native.apply("from_decimal", [text]).value
func same(a: Dictionary, b: Dictionary) -> bool:
	return native.apply("compare", [a,b]).scalar == 0
func inputs() -> Dictionary:
	return {"capacity":amount("1"),"free_charge":0.0}
func fixture(script, custom: Dictionary = {}):
	var owner = script.new(parameters if custom.is_empty() else custom, api, RunState.new())
	owner.refresh_availability(func(_kind,_id): return true, false)
	check(owner.prepare(inputs()).ok, "fixture ready")
	owner.accept()
	return owner
func affordable(wallet: Dictionary) -> Callable:
	return func(costs: Dictionary):
		for id in costs:
			var compared: Dictionary = api.apply("compare", [wallet.get(id,amount("0")),costs[id]])
			if not compared.ok: return compared
			if compared.scalar < 0: return {"ok":false,"reason":"InsufficientResources"}
		return {"ok":true}
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired ", loaded); quit(1); return
	call_deferred("run")
func run() -> void:
	native = ClassDB.instantiate("FoundationAmount"); api.native = native
	var config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	for row in config.config.config: parameters[str(row.name)] = row.para_1
	for row in config.game_rules.game_rules: rules[str(row.id)] = row.value
	old = load(OS.get_environment("SPACE_IDLE_REACTOR_BULK_BASELINE"))
	var owner = fixture(Reactor)
	await process_frame
	var notices: Array = []
	var before: Dictionary = owner.save_state()
	var prepared: Dictionary = owner._prepared_state.duplicate(true)
	var one: Dictionary = old._quote(before,1,parameters,api)
	var resource: String = str(one.costs.keys()[0])
	check(same(one.costs[resource],amount("10")), "original initial-level next cost")
	for count in [1,10]:
		var original: Dictionary = old._purchase(before,count,false,parameters,api)
		var quote: Dictionary = owner.purchase_preview(affordable(original.costs),count)
		check(quote.ok and quote.count == count and quote.can_purchase, "exact fixed count affordable")
		check(same(amount(quote.costs[resource]),original.costs[resource]), "original batch cost parity")
		var low: Dictionary = native.apply("sub_nonnegative",[original.costs[resource],amount("1")]).value
		var insufficient: Dictionary = owner.purchase_preview(affordable({resource:low}),count)
		check(insufficient.ok and not insufficient.can_purchase and insufficient.count == count, "fixed count does not shrink")
		api.calls.clear()
		owner.purchase_preview(affordable(original.costs),count)
		check(api.calls.get("sum_ceiled_geometric",0)==0 and api.calls.get("to_display",0)==0, "fixed budget refresh cached by count")
		quote.costs[resource] = "changed"
		check(owner.purchase_preview(affordable(original.costs),count).costs[resource] != "changed", "detached fixed text")
	var zero: Dictionary = owner.purchase_max_preview(affordable({}))
	check(zero.ok and zero.count == 0 and zero.costs.is_empty() and not zero.can_purchase and resource in zero.cost_resource_ids, "MAX zero preserves budget resource identity")
	for count in [1,2,9,10,31,100,500]:
		var original: Dictionary = old._quote(before,count,parameters,api)
		var max_quote: Dictionary = owner.purchase_max_preview(affordable(original.costs))
		check(max_quote.ok and max_quote.count == count and max_quote.can_purchase, "MAX exact affordable boundary " + str(count))
		check(same(amount(max_quote.costs[resource]),original.costs[resource]), "MAX original cost " + str(count))
		var next: Dictionary = old._quote(before,count+1,parameters,api)
		check(not affordable(original.costs).call(next.costs).ok, "MAX n plus one insufficient")
	check(owner.save_state()==before and owner._prepared_state==prepared, "all previews leave domain/prepared untouched")
	await process_frame
	check(not owner.purchase_preview(affordable({}),0).ok, "invalid count rejects")
	check(not owner.purchase_max_preview(func(_costs): return {"ok":false,"error":"FixtureComparisonFailure"}).ok, "MAX comparison error not insufficient")
	check(not owner.purchase_preview(func(_costs): return {"ok":false,"error":"FixtureComparisonFailure"},10).ok, "fixed comparison error propagates")
	var probes := {"n":0}
	var mid_error: Dictionary = owner.purchase_max_preview(func(_costs):
		probes.n += 1
		return {"ok":true} if probes.n==1 else {"ok":false,"error":"FixtureMidSearchFailure"})
	check(not mid_error.ok and mid_error.error=="FixtureMidSearchFailure", "mid-search error cannot return accepted lower partial MAX")
	api.fail_operation = "sum_ceiled_geometric"
	check(not owner.purchase_max_preview(affordable({})).ok, "MAX quote error not insufficient")
	api.fail_operation = ""
	var attempts := {"pay":0,"publish":0}
	var pay: Callable = func(_costs): attempts.pay += 1; return {"ok":false,"reason":"FixturePayReject"}
	var publish: Callable = func(_f,_wallet,_kind): attempts.publish += 1; return {"ok":false,"reason":"FixturePublishReject"}
	check(not owner.purchase_max(inputs(),affordable({}),pay,publish).ok and attempts.pay==0 and attempts.publish==0, "zero MAX executes nothing")
	var ten: Dictionary = old._quote(before,10,parameters,api)
	check(not owner.purchase_max(inputs(),affordable(ten.costs),pay,publish).ok and attempts.pay==1 and attempts.publish==0, "pay failure executes no publish")
	var wallet: Dictionary = ten.costs.duplicate(true)
	var economy = Economy.new(parameters,rules,api,RunState.new())
	economy.accept_budget(wallet,false)
	var real_pay: Callable = func(costs): attempts.pay += 1; return economy.payment(costs)
	check(not owner.purchase_max(inputs(),economy.can_pay,real_pay,publish).ok and owner.save_state()==before and same(economy.budget()[resource],wallet[resource]), "publish rejection leaves owner and real wallet unchanged")
	# Display failure is checked before payment/publication, even when MAX is payable.
	api.fail_operation = "to_display"
	var pay_before: int = attempts.pay
	check(not owner.purchase_max(inputs(),economy.can_pay,real_pay,publish).ok and attempts.pay==pay_before, "display error cannot follow successful purchase")
	api.fail_operation = ""
	# Signed integer bounds with original rate=1 pricing keep the range probe representable.
	var bounded: Dictionary = parameters.duplicate(true); bounded.reactorUpgradeGrowth = 1.0
	var edge = fixture(Reactor,bounded)
	var edge_state: Dictionary = edge.save_state(); edge_state.level = 9223372036854775804
	check(edge.restore_state(edge_state).ok, "edge level restore")
	var edge_two: Dictionary = old._quote(edge_state,2,bounded,api)
	check(edge.purchase_max_preview(affordable(edge_two.costs)).count==2, "signed bound gives exact interior max")
	check(not edge.purchase_max_preview(func(_costs):return {"ok":true}).ok, "machine limit is explicit range failure")
	# Actual Session/native, original purchase comparison and current-budget execution.
	var host = Session.new()
	check(host.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),161803).ok, "real Session/native initializes")
	host.reactor_system.refresh_availability(func(_kind,_id):return true,false)
	check(host.reactor_system.refresh(host.reactor_inputs(),host.publish_reactor).ok, "real accepted reactor")
	var real_owner = host.reactor_system
	check(real_owner.allocate_text("weapons","7",host.reactor_inputs(),host.publish_reactor).ok, "manual allocation before upgrades")
	var first: Dictionary = real_owner.save_state()
	var q10: Dictionary = old._quote(first,10,parameters,api)
	host.economy.accept_budget(q10.costs,false)
	var initial_allocations: Dictionary = first.allocations.duplicate(true)
	var payments := {"n":0,"publishes":0}
	var tracked_pay: Callable = func(costs): payments.n+=1; return host.economy.payment(costs)
	var tracked_publish: Callable = func(f,w,k): payments.publishes+=1; return host.publish_reactor(f,w,k)
	var short: Dictionary = native.apply("sub_nonnegative",[q10.costs[resource],amount("1")]).value
	host.economy.accept_budget({resource:short},false)
	check(not real_owner.purchase(10,false,host.reactor_inputs(),tracked_pay,tracked_publish).ok and real_owner.save_state()==first and same(host.economy.budget()[resource],short), "exact ten execution rejects whole batch when one unit short")
	check(payments.n==1 and payments.publishes==0, "insufficient ten publishes nothing")
	host.economy.accept_budget(q10.costs,false)
	payments.n=0; payments.publishes=0
	check(real_owner.purchase(10,false,host.reactor_inputs(),tracked_pay,tracked_publish).ok, "real native exact ten purchase")
	check(real_owner.save_state().level==first.level+10 and real_owner.save_state().allocations==initial_allocations and payments.n==1 and payments.publishes==1, "ten is one transaction and no automatic distribution")
	var state: Dictionary = real_owner.save_state()
	var q5: Dictionary = old._quote(state,5,parameters,api)
	var q2: Dictionary = old._quote(state,2,parameters,api)
	host.economy.accept_budget(q5.costs,false)
	check(real_owner.purchase_max_preview(host.economy.can_pay).count==5, "MAX preview current wallet five")
	host.economy.accept_budget(q2.costs,false)
	payments.n=0; payments.publishes=0
	var result: Dictionary = real_owner.purchase_max(host.reactor_inputs(),host.economy.can_pay,tracked_pay,tracked_publish)
	check(result.ok and result.count==2 and real_owner.save_state().level==state.level+2, "MAX executes fresh wallet two, ignores stale five")
	check(payments.n==1 and payments.publishes==1 and real_owner.save_state().allocations==initial_allocations, "MAX one native transaction, manual false")
	check(same(host.economy.budget()[resource],amount("0")) and same(amount(result.costs[resource]),q2.costs[resource]), "MAX actual receipt and exact wallet")
	check(real_owner.purchase_preview(host.economy.can_pay,10).count==10, "level change refreshes fixed ten")
	await process_frame
	print("REACTOR_BULK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
