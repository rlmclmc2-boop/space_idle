extends SceneTree
const Session = preload("res://src/game_session.gd")
var failures: Array = []
var count: int = 0
var api
var notices := {"budget": 0}
class TracedAmount extends RefCounted:
	var delegate
	var fail_op: String = ""
	var calls: Array = []
	func apply(operation: String, args: Array) -> Dictionary:
		calls.append(operation)
		if operation == fail_op: return {"ok": false, "reason": "FixtureAmount_" + operation}
		return delegate.apply(operation, args)
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures.append(label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal", [text]).value
func snapshot(host) -> Dictionary:
	return {"h": host.hyperspace_system.save_state(), "e": host.equipment.save_state(),
		"money": host.economy.save_state(), "pending": host.equipment._pending_slots,
		"enhance": host.enhancement.save_state()}
func drone(id: String, weapon: String = "laser") -> Dictionary:
	return {"id": id, "origin_quality": "gold", "weapon": weapon, "level": 5,
		"planet_id": "1", "legendary": false, "ultimate": false, "blue_source_bonus": false,
		"affixes": [], "hangings": [], "hanging_slots": 2, "preserved_hanging_slots": 0,
		"legendary_effect": {}, "ultimate_affix": {}, "omen": false, "forge_revision": 0,
		"weapon_generation": 1, "forge_rng_state": "123456"}
func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired: ", status); quit(1); return
	call_deferred("run")
func run() -> void:
	api = ClassDB.instantiate("FoundationAmount")
	var baseline = load(OS.get_environment("SPACE_IDLE_M9_BASELINE_SESSION"))
	var host = Session.new()
	var old = baseline.new()
	var path: String = OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")
	check(host.initialize(path, 314159).ok and old.initialize(path, 314159).ok, "both actual Sessions/native initialize")
	var h = host.hyperspace_system
	var prior = old.hyperspace_system
	var observer: Callable = func(): notices.budget += 1
	host.economy.display_changed.connect(observer)
	for owner in [h, prior]:
		owner._warehouse = [drone("a"), drone("b", "cannon")]
		owner._overflow = [drone("overflow")]
		for id in owner._modules:
			owner._modules[id] = {"unlocked": true, "level": 3, "exp": 42.0}
	var module_id: String = str(h._modules.keys()[0])
	var gated: String = ""
	for id in h._module_definitions:
		if int(h._module_definitions[id].unlock_stage) > 0: gated = str(id)
	h._warehouse[0].hangings = [module_id, gated]; prior._warehouse[0].hangings = [module_id, gated]
	h._equipped = ["a"]; prior._equipped = ["a"]
	h._reforge_count = 4
	var before: Dictionary = snapshot(host)
	var warehouse: Dictionary = h.warehouse()
	check(warehouse.main_capacity == h._warehouse_capacity() and warehouse.overflow_capacity == int(h._parameters.overflow_capacity), "capacities use originals including reforge")
	warehouse.main[0].hanging_slots = 999
	check(snapshot(host) == before, "warehouse detached")
	var details: Dictionary = host.hyperspace_module_details()
	check(details.ok and details.rows.size() == 5, "five actual module rows")
	for row in details.rows:
		var definition: Dictionary = h._module_definitions[row.id]
		check(row.required_exp == float(definition.base_exp) * pow(1.0 + float(definition.exp_growth), 3), "shared required exp " + row.id)
		check(row.per_copy_bonus == pow(1.0 + float(definition.effect_growth), 3) - 1.0, "shared per copy " + row.id)
		if row.id == gated: check(not row.available and row.aggregate_contribution > 0.0, "cycle gate does not erase accepted contribution")
	check(h.module_contributions() == prior.module_contributions(), "aggregate arithmetic unchanged")
	check(h._modules_after_credit({module_id: 9}) == prior._modules_after_credit({module_id: 9}), "credit growth unchanged")
	details.rows[0].level = 900
	check(snapshot(host) == before, "module read detached and pure")
	h._modules[module_id].level = 1000000
	var nonfinite: Dictionary = host.hyperspace_module_details()
	for row in nonfinite.rows:
		if row.id == module_id: check(row.required_exp == null and row.progress_ratio == null and not row.growth_reason.is_empty() and row.per_copy_bonus == null, "nonfinite growth remains unknown with reason")
	h._modules[module_id].level = 3
	check(not host.hyperspace_hangings_preview("a", [gated]).ok, "actual cycle gate")
	host.campaign_system._cycle_reached = 20
	check(host.hyperspace_hangings_preview("overflow", [module_id]).ok, "overflow installation preserved")
	check(not host.hyperspace_hangings_preview("a", [module_id,module_id]).ok, "duplicate denied")
	check(not host.hyperspace_hangings_preview("a", [module_id,module_id,module_id]).ok, "actual purchased slot limit")
	h._warehouse[0].ultimate = true
	check(host.hyperspace_hangings_preview("a", []).reason == "UltimateLocked", "ultimate slots do not permit edits")
	h._warehouse[0].ultimate = false
	var loadout: Dictionary = host.hyperspace_loadout_preview(["a"])
	check(loadout.ok and loadout.ids == ["a"] and loadout.admission_scope == "hyperspace_prepare" and not loadout.has("contributions"), "loadout scoped projection")
	for ids in [["missing"],["a","a"],["overflow"],["a","b"]]:
		var expected: Dictionary = h.prepare_loadout(ids, int(host.campaign_system.ship_facts().drone_capacity), host._hyperspace_weapon_source())
		var actual: Dictionary = host.hyperspace_loadout_preview(ids)
		check(actual.ok == expected.ok and actual.get("reason", "") == expected.get("reason", ""), "loadout original admission " + str(ids))
	h.save_preset("fixture")
	var preset: Dictionary = host.hyperspace_preset_preview("fixture")
	check(preset.ok and preset.entries[0].hangings == [module_id,gated], "preset projects each hanging")
	preset.entries[0].hangings.clear()
	check(h._presets[0].entries[0].hangings.size() == 2, "preset detached")
	host.campaign_system._cycle_reached = 0
	var preset_before: Dictionary = snapshot(host)
	check(host.hyperspace_preset_preview("fixture").reason == "HangingUnavailable" and snapshot(host) == preset_before, "preset rejects whole group on one gated hanging")
	host.campaign_system._cycle_reached = 20
	h._warehouse[0].hangings = []; h._equipped = []
	var dismantle_before: Dictionary = snapshot(host)
	var reward: Dictionary = prior.prepare_dismantle("b")
	var dismantle: Dictionary = host.hyperspace_dismantle_preview("b")
	var copies: int = 0
	for n in reward.reward.hanging_rewards.values(): copies += int(n)
	check(dismantle.ok and dismantle.materials == reward.reward.materials and dismantle.hanging_copies == copies and not dismantle.has("hanging_rewards"), "dismantle exact portions but random kinds pending")
	check(snapshot(host) == dismantle_before, "dismantle local RNG leaves all owner state unchanged")
	dismantle.materials.clear()
	check(snapshot(host) == dismantle_before, "dismantle output detached")
	for kind in ["favorite","sealed","preset","equipped"]:
		h._favorites = ["b"] if kind == "favorite" else []
		h._sealed = {"b": 10} if kind == "sealed" else {}
		h._equipped = ["b"] if kind == "equipped" else []
		h._presets = [{"name":"p","drone_ids":["b"],"entries":[]}] if kind == "preset" else []
		check(host.hyperspace_dismantle_preview("b").reason == "ProtectedDrone", "protection " + kind)
	h._favorites = []; h._sealed = {}; h._equipped = []; h._presets = []
	check(host.hyperspace_dismantle_preview("missing").reason == "DroneUnavailable", "missing dismantle target")
	var affix_key: String = str(h._affix_ranges.keys()[0])
	var tier: int = int(h._affix_ranges[affix_key].keys()[0])
	var range_row: Dictionary = h._affix_ranges[affix_key][tier]
	h._warehouse[0].affixes = [{"key":affix_key,"tier":tier,"value":float(range_row.minimum),"locked":true}]
	var limits: Dictionary = h.forge_display_limits("a")
	check(limits.ok and limits.hanging_slots == 2 and limits.reroll_ranges[0].locked and not limits.reroll_ranges[0].modifiable and limits.reroll_ranges[0].minimum == range_row.minimum, "locked affix range remains visible")
	h._warehouse[0].legendary = true; h._warehouse[0].preserved_hanging_slots = 3
	var legend_id: String = str(h._legend_parameters.keys()[0])
	var params: Dictionary = {}
	for row in h._legend_parameters[legend_id]: params[str(row.parameter)] = float(row.minimum)
	h._warehouse[0].legendary_effect = {"effect_id":legend_id,"parameters":params}
	limits = h.forge_display_limits("a")
	check(limits.hanging_limit == 3 and limits.hanging_slots == 2 and limits.reroll_ranges.size() == 1 + params.size(), "legend stored slots and parameter ranges")
	h._warehouse[0].ultimate = true
	limits = h.forge_display_limits("a")
	check(limits.reason == "UltimateLocked" and limits.reroll_ranges.all(func(row):return not row.modifiable), "ultimate locks all ranges without removing them")
	limits.reroll_ranges[0].current = 99999
	check(h._warehouse[0].affixes[0].value == float(range_row.minimum), "range rows detached")
	h._sealed = {"a": 10}
	check(h.forge_display_limits("a").reason == "DroneUnavailable" and host.hyperspace_hangings_preview("a",[]).reason == "DroneUnavailable", "seal precedes ultimate modification guard")
	h._sealed = {}
	h._warehouse[0] = drone("a"); prior._warehouse[0] = drone("a")
	for owner in [host,old]:
		var money: Dictionary = {}
		for id in h.material_ids(): money[id] = amount("10000000")
		money.degenerate_matter = amount("10000000"); money.ultimate_cores = amount("100")
		owner.economy.accept_budget(money, false)
	before = snapshot(host); var noticed: int = notices.budget
	for operation in ["add_affix","add_hanging_slot","enable_omen","reroll_values","ultimate","modernize","missing"]:
		var raw: Dictionary = prior.preview_forge("a", operation, {}, 20)
		var forecast: Dictionary = host.preview_hyperspace_forge("a", operation)
		check(raw.ok == forecast.ok and raw.get("reason", "") == forecast.get("reason", ""), "forge original reason " + operation)
		if raw.ok:
			check(forecast.drone == raw.drone and forecast.costs == raw.costs and forecast.draws == raw.draws and forecast.source.forge_revision == 0, "forge random and cost parity " + operation)
	check(snapshot(host) == before and notices.budget == noticed, "all forge queries preserve saves rng revisions budgets notices")
	var forecast: Dictionary = host.preview_hyperspace_forge("a", "enable_omen")
	forecast.drone.hangings.append("client mutation"); forecast.costs.clear(); forecast.cost_amounts.clear()
	check(snapshot(host) == before, "forge candidate and costs detached")
	h._warehouse[0].affixes = [{"key":affix_key,"tier":tier,"value":float(range_row.minimum),"locked":false}]
	prior._warehouse[0].affixes = h._warehouse[0].affixes.duplicate(true)
	var raw_guaranteed: Dictionary = prior.preview_forge("a","reroll_values",{"guaranteed":true},20)
	var quote_guaranteed: Dictionary = host.preview_hyperspace_forge("a","reroll_values",{"guaranteed":true})
	check(quote_guaranteed.ok == raw_guaranteed.ok and quote_guaranteed.get("costs",{}) == raw_guaranteed.get("costs",{}) and quote_guaranteed.get("drone",{}) == raw_guaranteed.get("drone",{}), "guaranteed Amount cost and draw unchanged")
	var accepted: Dictionary = host.forge("a", "enable_omen", {}, "once")
	var accepted_old: Dictionary = old.forge("a", "enable_omen", {}, "once")
	check(accepted == accepted_old and accepted.ok and host.economy.budget() == old.economy.budget(), "actual forge command and wallet match baseline")
	var repeated_before: Dictionary = snapshot(host)
	check(host.forge("a", "enable_omen", {}, "once") == accepted and snapshot(host) == repeated_before, "forge idempotency retained")
	check(host.preview_hyperspace_forge("a", "enable_omen").reason == "OmenAlreadyEnabled", "old forecast cannot skip latest revalidation")
	# Genuine Equipment prepare callback: reads follow actual; command still uses pending.
	h._warehouse = [drone("a")]; h._equipped = ["a"]
	host.equipment._slots[0].paid_level = 9
	var actual_source: Dictionary = host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0])
	var input: Dictionary = host.equipment_inputs()
	var boundary: Dictionary = host.equipment.equip_slot("weapon:0", "", input, func(_wallet, _kind):
		var pending_before = host.equipment._pending_slots.duplicate(true)
		check(host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0]) == actual_source, "accepted weapon ignores pending")
		check(host._hyperspace_weapon_source().call(h._warehouse[0]) != actual_source, "command retains pending highest-paid source")
		check(host.hyperspace_loadout_preview(["a"]).ok and host.preview_hyperspace_forge("a","enable_omen").loadout_admission.ok, "pending loadout and forge prechecks")
		check(host.equipment._pending_slots == pending_before, "queries preserve pending")
		return {"ok":false,"reason":"FixtureDiscard"})
	check(not boundary.ok and host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0]) == actual_source, "prepare callback discarded and read remains actual")
	var accepted_boundary: Dictionary = host.equipment.equip_slot("weapon:0", "", host.equipment_inputs(), func(_wallet, _kind):
		host.equipment.accept_prepared()
		return {"ok":true})
	check(accepted_boundary.ok and host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0]) != actual_source, "accept updates weapon read source")
	var latest: Dictionary = host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0])
	host.equipment.clear_switch_locks()
	host.equipment.equip_slot("weapon:0", "laser", host.equipment_inputs(), func(_wallet, _kind):
		check(host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0]) == latest, "reverse pending keeps latest actual")
		return {"ok":false,"reason":"FixtureDiscard"})
	check(host._hyperspace_weapon_source(null,null,-1,true).call(h._warehouse[0]) == latest, "discard does not rewind actual source")
	# Exchange traces compare complete original command preparation through target credit.
	var ids: Array = h.material_ids(); var source: String = str(ids[0]); var target: String = str(ids[1])
	for mode in ["valid","zero","fraction","same","unknown","insufficient","subtract_error","credit_error"]:
		var money := {source:amount("100"),target:amount("30")}
		if mode == "insufficient": money[source] = amount("1")
		for owner in [host,old]: owner.economy.accept_budget(money,false)
		var traced := TracedAmount.new(); traced.delegate = api
		var original_trace := TracedAmount.new(); original_trace.delegate = api
		if mode == "subtract_error": traced.fail_op="sub_nonnegative"; original_trace.fail_op=traced.fail_op
		if mode == "credit_error": traced.fail_op="add"; original_trace.fail_op=traced.fail_op
		host.amount_api=traced; host.economy._api=traced; old.amount_api=original_trace; old.economy._api=original_trace
		var text: String = "0" if mode=="zero" else "0.5" if mode=="fraction" else "10"
		var dst: String = source if mode=="same" else "missing" if mode=="unknown" else target
		before=snapshot(host); noticed=notices.budget
		if mode in ["subtract_error","credit_error"]:
			check(host.economy.can_pay({source:amount("20")}).ok, "can_pay succeeds before later exchange error " + mode)
			traced.calls.clear()
		var preview: Dictionary = host.hyperspace_exchange_preview(source,dst,text)
		var executed: Dictionary = old.exchange_hyperspace_materials(source,dst,text)
		check(preview.ok == executed.ok and preview.get("reason", "") == executed.get("reason", ""), "exchange full admission parity " + mode)
		check(traced.calls.slice(0, original_trace.calls.size()) == original_trace.calls, "exchange original operation order " + mode)
		check(snapshot(host)==before and notices.budget==noticed, "exchange pure " + mode)
		if preview.ok:
			check(api.apply("compare",[amount(preview.payment),amount("20")]).scalar==0 and api.apply("compare",[amount(preview.received),amount("10")]).scalar==0 and not preview.has("wallet"), "exchange receive unit and no wallet leak")
			check(host.exchange_hyperspace_materials(source,dst,text).ok and host.economy.budget()==old.economy.budget(), "exchange command exact accepted wallet")
		host.amount_api=api; host.economy._api=api; old.amount_api=api; old.economy._api=api
	# A formerly payable quote must recheck after a wallet change.
	host.economy.accept_budget({},false)
	check(not host.exchange_hyperspace_materials(source,target,"10").ok, "exchange confirms latest budget")
	host.run_state.fail("FixtureStopped"); old.run_state.fail("FixtureStopped")
	check(host.hyperspace_exchange_preview("missing","missing","bad") == old.exchange_hyperspace_materials("missing","missing","bad"), "RunState guard precedes material and Amount errors")
	host.economy.display_changed.disconnect(observer)
	if failures.is_empty(): print("PASS: ",count," focused M9 assertions; baseline growth/forge/exchange parity; owner snapshots and RNG purity; pending callback isolation; original admission, revalidation and idempotency.")
	else: printerr("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)
