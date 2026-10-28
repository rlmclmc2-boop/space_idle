extends SceneTree
const Reactor = preload("res://src/systems/reactor.gd")
const Research = preload("res://src/systems/research.gd")
const Session = preload("res://src/game_session.gd")
const Economy = preload("res://src/systems/economy.gd")
const RunState = preload("res://src/systems/run_state.gd")
class MeteredAPI extends RefCounted:
	var native
	var calls: int = 0
	var powers: int = 0
	func apply(operation: String, operands: Array) -> Dictionary:
		calls += 1
		if operation == "pow": powers += 1
		return native.apply(operation, operands)
var api = MeteredAPI.new()
var failures: Array = []
var publishes: int = 0
var notices := {"reactor":0,"research":0}
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal",[text]).value
func equal(text, expected: String) -> bool:
	return text is String and api.apply("compare",[amount(text),amount(expected)]).scalar == 0
func row(model: Dictionary, id: String) -> Dictionary:
	for item in model.modules:
		if item.id == id: return item
	return {}
func reactor_inputs(factor: String, free: float = 0.0) -> Dictionary:
	return {"capacity":amount(factor),"free_charge":free}
func research_inputs(iron: String="100",uranium: String="20",income1: String="10.9",income2: String="3.2",speed: String="1") -> Dictionary:
	return {"wallet":{"1":amount(iron),"2":amount(uranium)},"income_rates":{"1":amount(income1),"2":amount(income2)},
		"speed_factor":amount(speed),"staffed":false,"window_seconds":60.0,"game_time":100.0}
func _initialize() -> void:
	var status=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired: ",status)
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	api.native=ClassDB.instantiate("FoundationAmount")
	var config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	var parameters: Dictionary={}
	var rules: Dictionary={}
	for item in config.config.config: parameters[str(item.name)]=item.para_1
	for item in config.game_rules.game_rules: rules[str(item.id)]=item.value
	var state=RunState.new()
	var reactor=Reactor.new(parameters,api,state)
	reactor.refresh_availability(func(kind,id): return kind=="feature" or id!="condensation",false)
	reactor.choices_changed.connect(func(): notices.reactor+=1)
	var inputs: Dictionary=reactor_inputs("1.01",0.1)
	var unknown_current: Dictionary=reactor.allocation_plan_preview({"kind":"equal"},inputs)
	check(unknown_current.ok and unknown_current.current.capacity==null and not reactor._state.has("_capacity") and reactor._prepared_state.is_empty(),"fresh preview does not initialize owner capacity cache")
	check(reactor.prepare(inputs).ok,"reactor preparation")
	reactor.accept()
	var live: Dictionary=reactor._state.duplicate(true)
	var prepared: Dictionary=reactor._prepared_state.duplicate(true)
	var shares: Dictionary={"kind":"shares","shares_bp":{"weapons":3333,"defence":3333,"smelting":3334}}
	var preview: Dictionary=reactor.allocation_plan_preview(shares,inputs)
	check(preview.ok and equal(preview.target.capacity,"101") and equal(preview.target.remaining,"2"),"share targets leave floor remainder")
	check(equal(row(preview.target,"weapons").manual,"33") and equal(row(preview.target,"weapons").free,"10.1") and equal(row(preview.target,"weapons").effective,"43.1"),"manual/free/effective units")
	check(preview.source.size()==2 and not preview.source.has("capacity_factor") and not preview.source.has("free_charge"),"source excludes internal inputs")
	var calls: int=api.calls
	preview.target.modules[0].manual="999"
	var cached: Dictionary=reactor.allocation_plan_preview(shares,inputs)
	check(api.calls==calls and cached.target.modules[0].manual!="999","detached repeat cache")
	check(reactor._state==live and reactor._prepared_state==prepared and notices.reactor==0,"reactor preview no owned cache/prepared mutation")
	var equal_plan: Dictionary=reactor.allocation_plan_preview({"kind":"equal"},inputs)
	check(equal(row(equal_plan.target,"weapons").manual,"34") and equal(row(equal_plan.target,"defence").manual,"34") and equal(row(equal_plan.target,"smelting").manual,"33"),"existing equal remainder order")
	check(not reactor.allocation_plan_preview({"kind":"shares","shares_bp":{"weapons":5001,"defence":5000,"smelting":0}},inputs).ok,"reject share total")
	check(not reactor.allocation_plan_preview({"kind":"shares","shares_bp":{"weapons":37.0,"defence":0,"smelting":0}},inputs).ok,"reject float basis points")
	check(not reactor.allocation_plan_preview({"kind":"amounts","amount_texts":{"weapons":"1","defence":"0"}},inputs).ok,"reject missing module")
	var publisher: Callable=func(_factors,_wallet,_kind):
		publishes+=1
		reactor.accept()
		return {"ok":true}
	check(reactor.allocation_plan_preview(shares,{"ok":false,"reason":"FixtureInputsUnavailable"}).reason=="FixtureInputsUnavailable","Reactor preserves public input failure")
	check(not reactor.apply_allocation_plan({}, {}, publisher).ok and publishes==0,"missing source input refuses before publication")
	check(not reactor.allocation_plan_preview(shares,reactor_inputs("1",-1.0)).ok and state.is_running(),"invalid free Amount stays a read error rather than accessing a missing value")
	check(not reactor.apply_allocation_plan({"weapons":"33.9","defence":"33","smelting":"33"},inputs,publisher).ok and publishes==0,"command never rounds confirmed amount")
	var targets: Dictionary={"weapons":"60","defence":"35","smelting":"5"}
	var accepted: Dictionary=reactor.apply_allocation_plan(targets,reactor_inputs("1.1",0.1),publisher)
	check(accepted.ok and publishes==1 and notices.reactor==1 and equal(row(accepted.actual,"weapons").manual,"60") and equal(accepted.actual.remaining,"10"),"larger capacity keeps confirmed whole amounts one publish")
	live=reactor._state.duplicate(true)
	check(not reactor.apply_allocation_plan(targets,reactor_inputs("0.9"),publisher).ok and publishes==1 and reactor._state==live,"smaller capacity rejects without clipping")
	var declined: Dictionary=reactor.apply_allocation_plan({"weapons":"1","defence":"2","smelting":"3"},inputs,func(_f,_w,_k):
		publishes+=1
		return {"ok":false,"reason":"FixturePublicationRejected"})
	check(not declined.ok and publishes==2 and reactor._state==live and reactor._prepared_state.is_empty() and notices.reactor==1,"ordinary publish refusal no partial state or notice")
	check(reactor.distribute(reactor_inputs("1.02"),publisher).ok and publishes==3,"equal command one publication")
	check(equal(api.apply("to_display",[reactor._state.allocations.weapons]).text,"34") and equal(api.apply("to_display",[reactor._state.allocations.smelting]).text,"34"),"equal uses submission-time capacity")
	var changed: Dictionary=reactor.allocation_plan_preview({"kind":"equal"},reactor_inputs("1.1",0.2))
	check(equal(changed.current.capacity,"102") and equal(changed.target.capacity,"110") and equal(row(changed.current,"weapons").free,"0") and equal(row(changed.target,"weapons").free,"22"),"current accepted snapshot and new free-supply target remain distinct")
	var zero_plan: Dictionary=reactor.allocation_plan_preview(shares,reactor_inputs("0"))
	check(zero_plan.ok and equal(zero_plan.target.capacity,"0") and equal(zero_plan.target.remaining,"0"),"zero capacity no invalid ratios")
	var huge: Dictionary=reactor.allocation_plan_preview({"kind":"shares","shares_bp":{"weapons":3700,"defence":0,"smelting":0}},reactor_inputs("1e118"))
	check(huge.ok and equal(row(huge.target,"weapons").manual,"3.7e119"),"reactor huge Amount ratio")
	var tiny_plan: Dictionary=reactor.allocation_plan_preview({"kind":"amounts","amount_texts":{"weapons":"1","defence":"0","smelting":"0"}},reactor_inputs("1e118"))
	check(tiny_plan.ok and equal(tiny_plan.target.allocated,"1") and equal(row(tiny_plan.target,"weapons").manual,"1"),"small allocation inside huge capacity is summed directly not lost by capacity-minus-remaining")
	reactor.refresh_availability(func(_kind,_id): return true,false)
	live=reactor._state.duplicate(true)
	check(not reactor.apply_allocation_plan(targets,reactor_inputs("2"),publisher).ok and publishes==3 and reactor._state==live,"changed enabled set rejects even when capacity sufficient")
	var cleared: Dictionary=reactor.apply_allocation_plan({"weapons":"0","defence":"0","smelting":"0","condensation":"0"},reactor_inputs("1",0.1),publisher)
	check(cleared.ok and equal(row(cleared.actual,"weapons").manual,"0") and equal(row(cleared.actual,"weapons").free,"10") and equal(row(cleared.actual,"weapons").effective,"10"),"clearing manual allocation preserves free supply")
	var research=Research.new(config.ai_tech_tree.ai_tech_tree,rules,api,state)
	var idle: Dictionary=research.budget_preview({"research_id":"","kind":"once_ratio","basis_points":0},research_inputs())
	check(idle.current.level==null and idle.current.work==null and idle.current.required==null and idle.current.remaining_work==null and idle.current.speed_now==null and idle.current.completion_estimate==null,"no current research uses unknown work/speed/level instead of fake zero")
	research.refresh_progress(func(_kind,_id): return true,false)
	check(research.select("singularity").ok and research.panel_model().research_id=="singularity","select and read public research identity")
	research.investment_changed.connect(func(): notices.research+=1)
	var req: Dictionary={"research_id":"singularity","kind":"once_ratio","basis_points":3700}
	var source: Dictionary=research_inputs()
	check(research.budget_preview(req,{"ok":false,"reason":"FixtureInputsUnavailable"}).reason=="FixtureInputsUnavailable","Research preserves public input failure")
	var invalid_source: Dictionary=source.duplicate(true)
	invalid_source.income_rates["1"]={}
	check(not research.budget_preview(req,invalid_source).ok and state.is_running(),"malformed source Amount is a read error not a RunState fault")
	var research_before: Dictionary=research._state.duplicate(true)
	var budget: Dictionary=research.budget_preview(req,source)
	check(budget.ok and equal(budget.resources["1"].draft_rate,"4") and equal(budget.resources["2"].draft_rate,"1"),"research shared income ratio floor")
	check(budget.resources["1"].net_draft.direction=="surplus" and equal(budget.resources["1"].net_draft.amount,"6.9"),"Amount signed net representation")
	check(equal(budget.resources["1"].stock_duration_draft.game_seconds,"25") and equal(budget.resources["2"].stock_duration_draft.game_seconds,"20"),"stock is no-income duration not net deficit")
	check(research._state==research_before and notices.research==0 and state.is_running(),"research query never fills saved work cache or emits")
	var powers: int=api.powers
	research.budget_preview(req,source)
	check(api.powers==powers,"unchanged work and completion effects do not repow")
	budget.current.level=999
	check(research.budget_preview(req,source).current.level==0,"research detached result")
	check(budget.completion_effects[0].id=="ai_count" and equal(budget.completion_effects[0].current,"1") and equal(budget.completion_effects[0].next,"2"),"current-level AI completion effect")
	research.select("weapon_accuracy")
	var effect_preview: Dictionary=research.budget_preview({"research_id":"weapon_accuracy","kind":"once_ratio","basis_points":10000},source)
	check(equal(effect_preview.resources["1"].draft_rate,"10") and equal(effect_preview.resources["2"].draft_rate,"3") and effect_preview.completion_effects[0].id=="weapon_damage" and equal(effect_preview.completion_effects[0].next,"1.1"),"100 percent and original multiplier completion effect")
	research.select("singularity")
	var deficit: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_amounts","amount_texts":{"1":"15","2":"0"}},source)
	check(deficit.resources["1"].net_draft.direction=="deficit" and equal(deficit.resources["1"].net_draft.amount,"4.1"),"deficit uses unsigned Amount magnitude")
	var disabled: Dictionary=research.budget_preview({"research_id":"singularity","kind":"following_sample","enabled":false,"basis_points":3700},source)
	check(disabled.can_apply and disabled.following_sample.investment==null and disabled.resources["1"].following_sample_rate==null,"disabled following never fabricates upcoming investment")
	var broke: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_amounts","amount_texts":{"1":"10000","2":"10000"}},research_inputs("0","0","0","0"))
	check(equal(broke.immediate_draft.speed_now,"1") and equal(broke.immediate_draft.completion_estimate.funded_speed,"4") and equal(broke.immediate_draft.completion_estimate.game_seconds,"15") and not broke.immediate_draft.completion_estimate.current_wallet_sufficient,"funded estimate distinct from cash-starved speed_now")
	var boosted: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_amounts","amount_texts":{"1":"10000","2":"10000"}},research_inputs("0","0","0","0","2"))
	check(equal(boosted.immediate_draft.speed_now,"2") and equal(boosted.immediate_draft.completion_estimate.funded_speed,"8") and equal(boosted.immediate_draft.completion_estimate.game_seconds,"7.5"),"fresh aggregate external speed changes estimate without changing work")
	var large_stock: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_amounts","amount_texts":{"1":"100000","2":"0"}},research_inputs("1e120","0","0","0"))
	check(equal(large_stock.resources["1"].stock_duration_draft.game_seconds,"1e115") and large_stock.resources["2"].stock_duration_draft.kind=="not_spending","unbounded Amount duration not to_ratio")
	var rejected: Dictionary=research.budget_preview({"research_id":"singularity","kind":"following_sample","enabled":true,"basis_points":0},source)
	check(rejected.ok and not rejected.can_apply and rejected.reason=="InvalidResearchRatio" and rejected.following_sample.investment==null,"continuous zero remains rejected")
	var following: Dictionary=research.budget_preview({"research_id":"singularity","kind":"following_sample","enabled":true,"basis_points":10},research_inputs("0","0","0","0"))
	check(following.can_apply and equal(following.resources["1"].following_sample_rate,"1") and following.resources["1"].draft_rate==null,"valid continuous minimum with no income is sample one")
	var instant_zero: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_ratio","basis_points":0},source)
	check(equal(instant_zero.resources["1"].draft_rate,"0") and instant_zero.resources["1"].stock_duration_draft.kind=="not_spending","instant zero remains zero")
	var partial: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_amounts","amount_texts":{"1":"900000","2":"bad"}},source)
	check(not partial.can_apply and partial.resources["1"].can_apply and not partial.resources["2"].can_apply and partial.resources["2"].draft_rate==null and partial.immediate_draft.speed_now==null,"invalid resource does not fake zero or block valid resource")
	check(research.set_investment_text("1","900000").ok and not research.set_investment_text("2","bad").ok and equal(research.panel_model().investment["1"],"900000"),"existing setters retain per-resource success")
	var saved: Dictionary=research.save_state()
	saved.refresh_elapsed=61.0
	check(research.restore_state(saved).ok and research.set_automatic(true,0.37).ok,"restore due phase")
	var overdue: Dictionary=research.budget_preview(req,source)
	check(overdue.automatic_refresh.remaining_game_seconds==0.0 and not overdue.automatic_refresh.due and overdue.automatic_refresh.reason=="ResearchStaffRequired","due phase waits actual staff")
	source.staffed=true
	check(research.budget_preview(req,source).automatic_refresh.due,"actual staff enables due without resetting phase")
	check(research.set_automatic(false,0.37).ok and research.save_state().refresh_elapsed==61.0 and equal(research.panel_model().investment["1"],"900000"),"disabling preserves amount and refresh phase")
	check(not research.budget_preview({"research_id":"weapon_accuracy","kind":"once_ratio","basis_points":3700},source).ok,"stale research identity rejected")
	saved=research.save_state()
	saved.levels={"singularity":472}
	saved.work={}
	saved.required_work={}
	saved.investment={}
	check(research.restore_state(saved).ok,"large real growth level fixture")
	var long_work: Dictionary=research.budget_preview({"research_id":"singularity","kind":"once_ratio","basis_points":0},source)
	check(api.apply("compare",[amount(long_work.current.completion_estimate.game_seconds),amount("1e100")]).scalar>0,"research work estimate remains arbitrary Amount seconds")
	saved=research.save_state()
	saved.current="unification"
	saved.levels={"unification":1,"equipment_finishing":10,"uranium_extraction":10}
	saved.work={}
	saved.required_work={}
	saved.peaks={"1":amount("100"),"2":amount("0"),"jewel":amount("0")}
	check(research.restore_state(saved).ok and research.contributions().ok,"real unification source fixture")
	var peak_request: Dictionary={"research_id":"unification","kind":"once_ratio","basis_points":0}
	var before_peak: Array=research.budget_preview(peak_request,source).completion_effects
	check(research.refresh_income({"1":amount("1000"),"2":amount("0"),"jewel":amount("0")},{"1":amount("0"),"2":amount("0")},true,false).ok,"accepted peak update")
	var after_peak: Array=research.budget_preview(peak_request,source).completion_effects
	check(before_peak[0].current!=after_peak[0].current,"completion effect cache follows accepted peak source")
	var baseline_path: String=OS.get_environment("SPACE_IDLE_RESEARCH_BASELINE")
	check(not baseline_path.is_empty(),"fixed baseline source supplied")
	if not baseline_path.is_empty():
		var Baseline=load(baseline_path)
		for finishing in [false,true]:
			var original=Baseline.new(config.ai_tech_tree.ai_tech_tree,rules,api,RunState.new())
			var revised=Research.new(config.ai_tech_tree.ai_tech_tree,rules,api,RunState.new())
			for owner in [original,revised]:
				owner.refresh_progress(func(_kind,_id): return true,false)
				owner.select("singularity")
				owner.set_investment_text("1","100")
				owner.set_investment_text("2","10000")
				if finishing:
					var fixture: Dictionary=owner.save_state()
					fixture.work={"singularity":amount("59")}
					owner.restore_state(fixture)
			var wallet: Dictionary={"1":amount("25" if not finishing else "100"),"2":amount("10000")}
			revised.budget_preview(req,source)
			var old_result: Dictionary=original.advance(wallet,1.0,amount("1"),false)
			var new_result: Dictionary=revised.advance(wallet,1.0,amount("1"),false)
			check(old_result==new_result and original.save_state()==revised.save_state(),"original advance equivalence exhaustion/finish "+str(finishing))
			if not finishing:
				check(equal(api.apply("to_display",[revised.save_state().work.singularity]).text,"2.25"),"manual piecewise work reference")
				var advanced_inputs: Dictionary=source.duplicate(true)
				advanced_inputs.wallet=new_result.wallet
				check(equal(revised.budget_preview(req,advanced_inputs).current.remaining_work,"57.75"),"work progress invalidates remaining estimate while required-work cache stays reusable")
			for owner in [original,revised]: owner.set_automatic(true,0.37)
			var old_refresh: Dictionary=original.refresh_income({"1":amount("0"),"2":amount("0"),"jewel":amount("0")},{"1":amount("10.9"),"2":amount("0")},true,true)
			var new_refresh: Dictionary=revised.refresh_income({"1":amount("0"),"2":amount("0"),"jewel":amount("0")},{"1":amount("10.9"),"2":amount("0")},true,true)
			check(old_refresh==new_refresh and original.save_state()==revised.save_state(),"original automatic refresh equivalence "+str(finishing))
	var economy=Economy.new(parameters,rules,api,state)
	check(economy.credit_yield("1",amount("600"),100.0,100.0).ok,"actual investment income fixture")
	var session=Session.new()
	session.economy=economy
	session.research=research
	session._research_speed=amount("1")
	session._crew_factors={"research_staffed":false}
	session.wall_time=100.0
	session.game_time=100.0
	var public_inputs: Dictionary=session.research_preview_inputs()
	check(public_inputs.ok and equal(api.apply("to_display",[public_inputs.income_rates["1"]]).text,"10"),"Session public inputs use actual game-window investment income")
	public_inputs.wallet["1"]=amount("0")
	public_inputs.speed_factor.m="999"
	check(equal(api.apply("to_display",[economy.budget()["1"]]).text,"600") and equal(api.apply("to_display",[session._research_speed]).text,"1"),"Session public input snapshots detached")
	session.game_time=160.0
	check(equal(api.apply("to_display",[session.research_preview_inputs().income_rates["1"]]).text,"0") and equal(api.apply("to_display",[economy.budget()["1"]]).text,"600"),"income-window expiry changes preview without wallet event")
	var host=Session.new()
	var ready: Dictionary=host.initialize(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG"),314159)
	check(ready.ok,"native Session initialize: "+str(ready.get("reason",ready.get("error",""))))
	if ready.ok:
		host.reactor_system.refresh_availability(func(kind,id): return kind=="feature" or id!="condensation",false)
		var real_count: Dictionary={"calls":0}
		var committed: Dictionary=host.reactor_system.apply_allocation_plan({"weapons":"45","defence":"35","smelting":"20"},host.reactor_inputs(),func(factors,wallet,kind):
			real_count.calls+=1
			return host.publish_reactor(factors,wallet,kind))
		check(committed.ok and real_count.calls==1 and host.run_state.is_running() and equal(row(committed.actual,"weapons").manual,"45"),"native Session one actual Reactor publication")
		host.research.refresh_progress(func(_kind,_id): return true,false)
		check(host.research.select("singularity").ok,"host research selection")
		var research_state: Dictionary=host.research.save_state()
		var host_preview: Dictionary=host.research.budget_preview({"research_id":host.research.panel_model().research_id,"kind":"once_ratio","basis_points":0},host.research_preview_inputs())
		check(host_preview.ok and equal(host_preview.current.required,"60") and host.research.save_state()==research_state,"actual Session public preview input without saved-cache mutation")
	var before_stop: int=publishes
	reactor.allocation_plan_preview({"kind":"equal"},reactor_inputs("1"))
	state.fail("FixtureStopped")
	check(not reactor.apply_allocation_plan({}, {}, publisher).ok and publishes==before_stop,"stopped command refuses before any plan or publication")
	check(not reactor.allocation_plan_preview({"kind":"equal"},reactor_inputs("1")).can_apply,"preview cache respects stopped status")
	if failures.is_empty(): print("PASS: Reactor Amount plans/one publish/no clipping/current snapshot; Research ratios/durations/funded estimates/purity/caches; baseline advance/refresh equivalence; public Session input/window expiry/native publication")
	else: printerr("FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
