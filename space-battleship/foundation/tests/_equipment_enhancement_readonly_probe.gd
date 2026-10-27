extends SceneTree
const Session = preload("res://src/game_session.gd")
const Equipment = preload("res://src/systems/equipment.gd")
const Enhancement = preload("res://src/systems/enhancement.gd")
const RunState = preload("res://src/systems/run_state.gd")
var failures: Array = []
var api
var config: Dictionary
var parameters: Dictionary = {}
var rules: Dictionary = {}
var old_equipment
var old_enhancement
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal", [text]).value
func equal(a: Dictionary, b: Dictionary) -> bool:
	return api.apply("compare", [a, b]).scalar == 0
func without_receipt(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true); result.erase("purchase_receipt"); return result
func effect(model: Dictionary, id: String) -> Dictionary:
	for row in model.effects:
		if row.id == id: return row
	return {}
func equipment_fixture(script):
	var owner = script.new(config.equipment.equipment, config.equipment_evolution.equipment_evolution,
		config.unlock.unlock, parameters, rules, api, RunState.new())
	owner.refresh_availability(func(_kind, _id): return true, 100, false)
	owner.initialize_slots("laser,armour", {"weapon": 3, "defence": 2})
	return owner
func enhancement_fixture(script):
	var owner = script.new(config.enhance_config.enhance_config, api, RunState.new())
	owner.evaluate(0, func(_kind, _id): return true, 2)
	owner.accept_output()
	return owner
func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired: ", status); quit(1); return
	call_deferred("run")
func run() -> void:
	api = ClassDB.instantiate("FoundationAmount")
	config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	for item in config.config.config: parameters[str(item.name)] = item.para_1
	for item in config.game_rules.game_rules: rules[str(item.id)] = item.value
	old_equipment = load(OS.get_environment("SPACE_IDLE_EQUIPMENT_BASELINE"))
	old_enhancement = load(OS.get_environment("SPACE_IDLE_ENHANCEMENT_BASELINE"))
	if old_equipment == null or old_enhancement == null: printerr("BaselineRequired"); quit(1); return
	var host = Session.new()
	var initialized: Dictionary = host.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"), 314159)
	check(initialized.ok, "actual Session/native initialization")
	if not initialized.ok: quit(1); return
	var wallet := {"1": amount("1000000"), "2": amount("1000000"), "degenerate_matter": amount("1000000")}
	var inputs := {"mounts": {"weapon": 3, "defence": 2}, "balances": wallet, "game_time": 1.0,
		"extra_bonus": 0, "ai": host._research_factors, "reactor": host._reactor_factors}
	var owner = equipment_fixture(Equipment)
	var original = equipment_fixture(old_equipment)
	var before: Dictionary = owner.save_state()
	var pending = owner._pending_slots
	var can_pay: Callable = host.economy.affordable
	var compare: Callable = host.economy.can_pay
	var pay: Callable = host.economy.payment
	for n in [1, 10]:
		check(owner.quote_slot("weapon:0", n) == original.quote_slot("weapon:0", n), "fixed quantity quote unchanged " + str(n))
		var view: Dictionary = owner.slot_comparison("weapon:0", "cannon", n, inputs, compare)
		check(view.ok and view.upgrade_count == n and view.upgrade.paid_level == 1 + n and view.scope == "charged_base", "comparison binds actual quantity " + str(n))
		var expected: Dictionary = before.slots[0].duplicate(true); expected.paid_level += n
		var charged: Dictionary = original._charged_base(original._definitions.laser, original._definitions.armour, expected, 0, original._evolution, inputs.ai.weapon_damage, inputs.reactor.weapons, api)
		check(view.upgrade.primary == api.apply("to_display", [charged.value]).text, "comparison original charged base " + str(n))
		view.quote.costs["1"].m = "999"; view.current.properties.interval_seconds = 999.0
	check(owner.save_state() == before and owner._pending_slots == pending and owner._pending_level_slots.is_empty(), "comparison/quote do not mutate owner caches/pending")
	var facts: Array = owner.slot_facts({"weapon": 1, "defence": 1}, 1.0, 0)
	check(facts.size() == 5 and facts[1].dormant and facts[1].equipment_id == "", "dormant and empty distinct")
	facts[0].paid_level = 999
	check(owner.save_state() == before, "slot facts detached")
	var bad: Dictionary = owner.slot_comparison("weapon:0", "shield", 1, inputs, compare)
	check(bad.candidate.primary == null and bad.candidate.reason == "EquipmentCategoryMismatch", "invalid category never a valid primary")
	check(owner.slot_comparison("missing", "laser", 1, inputs, compare).reason == "UnknownSlot", "unknown slot distinct")
	check(owner.slot_comparison("defence:0", "", 1, inputs, compare).switch_admission.reason == "FirstDefenceRequired", "original switch admission reused")
	owner._slots[0].switch_ready_at = 10.0
	check(owner.slot_comparison("weapon:0", "cannon", 1, inputs, compare).switch_admission.reason == "EquipmentSwitchLocked" and owner.quote_slot("weapon:0", 1).ok, "switch lock does not ban buying")
	owner._slots[0].switch_ready_at = 0.0
	var low_inputs: Dictionary = inputs.duplicate(true); low_inputs.balances = {"1": amount("1")}
	var too_costly: Dictionary = owner.slot_comparison("weapon:0", "cannon", 10, low_inputs, compare)
	check(too_costly.quote.ok and too_costly.quote.count == 10 and not too_costly.affordable and too_costly.payment_reason == "InsufficientResources", "equipment exact ten never shrinks to affordable prefix")
	check(owner.quote_max_levels("weapon:0", low_inputs, can_pay).reason == "NoChange", "MAX zero original NoChange")
	var max_inputs: Dictionary = inputs.duplicate(true); max_inputs.balances = {"1": amount("1000")}
	var maximum: Dictionary = owner.quote_max_levels("weapon:0", max_inputs, can_pay)
	var old_max = equipment_fixture(old_equipment)
	var expected_max: Dictionary = old_max.buy_max_levels("weapon:0", max_inputs, can_pay, pay, func(_wallet): old_max.accept_prepared(); return {"ok": true})
	check(maximum.ok and int(old_max._slots[0].paid_level) == 1 + int(maximum.count), "MAX search quantity matches original command")
	owner._slots[0].paid_level = 19; original._slots[0].paid_level = 19
	for n in [1, 10]: check(owner.quote_slot("weapon:0", n) == original.quote_slot("weapon:0", n), "evolution boundary original quote " + str(n))
	owner._material_available = false
	check(owner.quote_max_levels("weapon:0", inputs, can_pay).reason == "NoChange", "MAX quote error stays search boundary not leaked")
	owner._material_available = true
	owner._slots[0].paid_level = 9223372036854775807
	check(owner.quote_max_levels("weapon:0", inputs, can_pay).reason == "EquipmentLevelRangeExceeded", "MAX discrete boundary unchanged")
	owner._slots[0].paid_level = 1000; original._slots[0].paid_level = 1000
	check(owner.quote_slot("weapon:0", 10) == original.quote_slot("weapon:0", 10) and owner.quote_slot("weapon:0", 10).extreme, "extreme quote same original Amount")
	# Partial batch can commit and still return a later ordinary failure.
	for script in [old_equipment, Equipment]:
		var batch = equipment_fixture(script)
		var calls := {"pay": 0, "publish": 0}
		var paid_quotes: Array = []
		var result: Dictionary = batch.buy_all_levels(1, false, inputs, can_pay,
			func(costs, balances):
				calls.pay += 1
				if calls.pay == 3: return {"ok": false, "reason": "FixtureLaterFailure"}
				paid_quotes.append(costs.duplicate(true)); return pay.call(costs, balances),
			func(_wallet): calls.publish += 1; batch.accept_prepared(); return {"ok": true})
		check(not result.ok and result.reason == "FixtureLaterFailure" and calls.publish == 1 and batch._slots[0].paid_level == 2 and batch._slots[1].paid_level == 2, "partial batch original semantic")
		if script == Equipment:
			var receipt: Dictionary = result.purchase_receipt
			check(receipt.commit_status == "accepted" and receipt.purchases.size() == 2 and receipt.purchases[0].count == 1 and receipt.purchases[1].spent == paid_quotes[1], "ok=false preserves committed per-slot quote")
			var expected_sum: Dictionary = api.apply("add", [paid_quotes[0]["1"], paid_quotes[1]["1"]]).value
			check(equal(receipt.spent["1"], expected_sum), "batch total sums execution quotes")
	var reject = equipment_fixture(Equipment)
	var rejected: Dictionary = reject.buy_levels("weapon:0", 1, inputs, pay, func(_wallet): return {"ok": false, "reason": "FixtureRejected"})
	check(rejected.purchase_receipt.commit_status == "rejected" and rejected.purchase_receipt.purchases.is_empty() and reject._slots[0].paid_level == 1, "ordinary publication rejection no false purchase")
	var fault: Dictionary = reject.buy_levels("weapon:0", 1, inputs, pay, func(_wallet): return {"ok": false, "fault": true, "reason": "FixtureFault"})
	check(fault.purchase_receipt.commit_status == "fault_unknown" and fault.purchase_receipt.spent == null, "fault never claims rollback or confirmed spend")
	var reentry = equipment_fixture(Equipment)
	var outer_quote: Dictionary = reentry.quote_slot("weapon:0", 10)
	var outer: Dictionary = reentry.buy_levels("weapon:0", 10, inputs, pay, func(_wallet):
		reentry.accept_prepared()
		reentry.buy_levels("weapon:0", 1, inputs, pay, func(_inner): reentry.accept_prepared(); return {"ok": true})
		return {"ok": true})
	check(outer.purchase_receipt.purchases[0].count == 10 and outer.purchase_receipt.spent == outer_quote.costs and reentry._slots[0].paid_level == 12, "reentry cannot replace execution receipt")
	var latest_owner = equipment_fixture(Equipment)
	var stale: Dictionary = latest_owner.slot_comparison("weapon:0", "cannon", 10, inputs, compare)
	latest_owner.buy_levels("weapon:0", 1, inputs, pay, func(_wallet): latest_owner.accept_prepared(); return {"ok": true})
	var latest_quote: Dictionary = latest_owner.quote_slot("weapon:0", 10)
	var latest_result: Dictionary = latest_owner.buy_levels("weapon:0", 10, inputs, pay, func(_wallet): latest_owner.accept_prepared(); return {"ok": true})
	check(latest_result.ok and latest_result.purchase_receipt.spent == latest_quote.costs and latest_quote.costs != stale.quote.costs, "confirmation recomputes latest equipment quote rather than stale preview")
	var enhance = enhancement_fixture(Enhancement)
	var old = enhancement_fixture(old_enhancement)
	var context := {"bonus": 0, "unlocked": func(_kind, _id): return true, "armours": 2}
	var locked_context := {"bonus": 0, "unlocked": func(_kind, _id): return false, "armours": 2}
	var branch: Dictionary = enhance.branch_details("memory", 2, locked_context)
	check(branch.ok and not branch.open and branch.options[0].parameters.has("memory_a_bonus") and branch.options[1].parameters.has("memory_b3_armour_capacity_bonus"), "unselected/locked A/B static rules available")
	branch.options[0].parameters.memory_a_bonus.value = 999
	check(enhance._rules.memory_a_bonus != 999, "option parameters detached")
	var state: Dictionary = enhance.save_state(); state.level = 60
	state.branches = {"proficiency": ["A", "B", "A"], "repeat": ["A", "B", "B"], "critical": ["A", "B", "B"], "adaptation": ["A", "B", "B"], "memory": ["A", "B", "B"], "deferred": ["A", "B", "B"]}
	check(enhance.restore_state(state).ok and old.restore_state(state).ok, "valid enhancement choices fixture")
	enhance.evaluate(0, context.unlocked, 2); enhance.accept_output()
	var saved_state: Dictionary = enhance.save_state(); var accepted_values: Dictionary = enhance.published_output().duplicate(true)
	var pending_values: Dictionary = enhance._pending_output.duplicate(true)
	var model: Dictionary = enhance.presentation_model(context)
	check(model.ok and model.effects.size() == 6 and model.paid == 60 and model.effective == 60, "structured six-effect model")
	check(is_equal_approx(effect(model, "repeat").summary.probability, 0.6) and not effect(model, "repeat").summary.second_generation_active, "repeat A composed B2 disabled")
	check(effect(model, "repeat").nodes[1].choice == "B" and not effect(model, "repeat").nodes[1].function_active, "stored repeat B2 retained")
	var disabled: Dictionary = enhance.branch_details("repeat", 1, context)
	check(disabled.options[1].command_allowed and not disabled.options[1].function_available, "B2 no new command rejection")
	check(effect(model, "critical").summary.effect_trigger_rate == 1.0 and effect(model, "critical").summary.bonus_uses_raw_rate, "critical B3 trigger separate from raw bonus rate")
	check(is_equal_approx(effect(model, "memory").summary.heal_fraction, 0.72) and is_equal_approx(effect(model, "memory").summary.buffer_fraction, 12.96), "memory A and armour B3 included")
	check(not effect(model, "deferred").summary.random_clear_enabled and effect(model, "deferred").summary.forced_clear_probability == 1.0, "deferred B2/B3 clear distinction")
	check(is_equal_approx(effect(model, "critical").summary.raw_critical_rate, 0.4) and is_equal_approx(effect(model, "deferred").summary.incoming_multiplier, 1.36125), "composed A/B static probabilities and incoming multiplier")
	model.effects[0].summary.active_rules[0].parameters.proficiency_a_damage_bonus.value = 999
	check(enhance.save_state() == saved_state and enhance.published_output() == accepted_values and enhance._pending_output == pending_values and enhance._pending_state.is_empty(), "effect/branch reads pure and detached")
	var changed_context: Dictionary = context.duplicate(); changed_context.bonus = 1; changed_context.armours = 1
	enhance.evaluate(1, context.unlocked, 1); enhance.accept_output()
	var refreshed: Dictionary = enhance.presentation_model(changed_context)
	check(refreshed.effective == 61 and not is_equal_approx(effect(refreshed, "memory").summary.buffer_fraction, 12.96), "visible reread covers accept_output external bonus/armour")
	var before_choose: Dictionary = enhance.save_state()
	var selected: Dictionary = enhance.set_branch("repeat", 1, "B", context, func(_changed, _costs, _kind): enhance.accept_prepared(); return {"ok": true})
	check(selected.ok and enhance.save_state() == before_choose, "existing repeat B2 command remains accepted")
	var reordered = enhancement_fixture(Enhancement)
	var order_state: Dictionary = reordered.save_state(); order_state.level = 30
	order_state.branches = {"proficiency": ["A", "B", "A"], "repeat": ["A", "B", "B"]}
	reordered.restore_state(order_state); reordered.evaluate(0, context.unlocked, 2); reordered.accept_output()
	check(effect(reordered.presentation_model(context), "proficiency").summary.damage_multiplier == 2.0, "all open A nodes composed before reorder")
	var moved: Dictionary = reordered.move_forward("repeat", context, func(_v, _c, _k): reordered.accept_prepared(); return {"ok": true})
	var moved_model: Dictionary = reordered.presentation_model(context)
	check(moved.ok and moved_model.weapon_order[0] == "repeat" and effect(moved_model, "proficiency").summary.damage_multiplier == 1.5 and effect(moved_model, "proficiency").nodes[2].choice == "A" and not effect(moved_model, "proficiency").nodes[2].function_active, "reorder recomputes active A and retains locked choice")
	var switched: Dictionary = reordered.set_branch("repeat", 0, "B", context, func(_v, _c, _k): reordered.accept_prepared(); return {"ok": true})
	var switched_summary: Dictionary = effect(reordered.presentation_model(context), "repeat").summary
	check(switched.ok and is_equal_approx(switched_summary.probability, 0.5) and switched_summary.chain_count == 1, "branch change updates full static composition")
	var quote_owner = enhancement_fixture(Enhancement)
	var quota: Dictionary = {"jewel": amount("300")}
	var predicate: Callable = func(costs): return host.economy.affordable(costs, quota)
	var preview_before: Dictionary = quote_owner.save_state()
	var preview: Dictionary = quote_owner.purchase_preview(10, context, predicate)
	check(preview.ok and preview.purchasable_count == 2 and equal(preview.costs.jewel, amount("300")), "enhancement at most ten means actual two / total 300")
	check(quote_owner.save_state() == preview_before and quote_owner._pending_output.is_empty(), "purchase quote no pending/owner writes")
	var no_money: Dictionary = quote_owner.purchase_preview(10, context, func(_costs): return false)
	check(not no_money.ok and no_money.reason == "NoChange" and no_money.purchasable_count == 0 and equal(no_money.first_level_costs.jewel, amount("100")), "zero purchasable separate first-level price")
	var spent: Dictionary = {}
	var bought: Dictionary = quote_owner.purchase(10, context, predicate, func(_values, costs, _kind): spent.merge(costs); quote_owner.accept_prepared(); return {"ok": true})
	check(bought.ok and bought.purchase_receipt.count == 2 and bought.purchase_receipt.spent == spent and quote_owner._state.level == 2, "enhancement actual receipt")
	var original_quote = enhancement_fixture(old_enhancement)
	var old_bought: Dictionary = original_quote.purchase(10, context, predicate, func(_v, _c, _k): original_quote.accept_prepared(); return {"ok": true})
	check(without_receipt(bought) == old_bought and quote_owner.save_state() == original_quote.save_state(), "purchase state/result same fixed original")
	quota.jewel = amount("400")
	var new_purchase: Dictionary = quote_owner.purchase(1, context, predicate, func(_v, _c, _k): quote_owner.accept_prepared(); return {"ok": true})
	check(new_purchase.ok and new_purchase.purchase_receipt.count == 1 and equal(new_purchase.purchase_receipt.spent.jewel, amount("400")) and quote_owner._state.level == 3, "enhancement confirmation requotes current level and budget")
	# Actual Session publication also returns the execution receipt; callbacks see final state.
	check(host.economy.credit_yield("1", amount("100000"), 0.0, 0.0).ok, "native host budget fixture")
	var real_quote: Dictionary = host.equipment.quote_slot("weapon:0", 1)
	var observed := {"calls": 0, "level": 0}
	var observer: Callable = func(_ids): observed.calls += 1; observed.level = host.equipment_slot_facts()[0].paid_level
	host.equipment.slots_changed.connect(observer)
	var real: Dictionary = host.equipment.buy_levels("weapon:0", 1, host.equipment_inputs(), host.economy.payment, host.publish_equipment_levels)
	check(real.ok and real.purchase_receipt.commit_status == "accepted" and real.purchase_receipt.spent == real_quote.costs and observed.calls == 1 and observed.level == 2, "actual Session/native accepted quote and listener sees final facts")
	host.equipment.slots_changed.disconnect(observer)
	if failures.is_empty(): print("PASS: equipment fixed/MAX/evolution/extreme original quotes, charged comparisons and purity; partial-failure/unknown/reentrant receipts; enhancement static A/B rules and composed summaries, original at-most quantity and receipts, accept_output reread; actual Session/native publication")
	else: printerr("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)
