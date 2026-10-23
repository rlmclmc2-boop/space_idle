extends RefCounted
const N=preload("res://scripts/growth_number.gd")
const Result=preload("res://scripts/command_result.gd")
static var NO_CHANGE:Dictionary=Result.make("no_change")
static var PLANET_PROGRESS:Dictionary=Result.make("committed","",["planets"])
static var RESEARCH_PROGRESS:Array=[
	Result.make("committed","",["research"]),
	Result.make("committed","",["research","economy"],["1"]),
	Result.make("committed","",["research","economy"],["2"]),
	Result.make("committed","",["research","economy"],["1","2"])]
## Concrete coordination of crew, planets and research. Domains own state; Game owns time.

func add_crew_exp(g,crew_id: String, amount: float) -> bool:
	return Result.succeeded(add_crew_exp_result(g,crew_id,amount))

func add_crew_exp_result(g,crew_id: String, amount: float) -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	if not g.crew.levels_unlocked(g) or not g.crew.unlocked(g,crew_id):return Result.make("rejected","crew_locked")
	var plan: Dictionary=g.crew.prepare_experience(g,{crew_id:amount})
	var rejected:=prepare_crew_commit(g,plan)
	if not rejected.is_empty():return rejected
	if plan.changes.is_empty():return Result.make("no_change")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	var defence:=capture_progress_health(g,plan.configuration)
	g.crew.commit(plan)
	g.commit_effects.settle_progress(g,plan.configuration,defence)
	return g.commit_effects.finish(g,["crew"],[],[],{"crew_changes":plan.changes},crew_notices(g,plan.changes))

func prepare_crew_commit(g,plan: Dictionary) -> Dictionary:
	if not g.crew.proposal_current(plan):return Result.make("rejected","stale_crew")
	var configuration_before: Array=g.attributes.configuration_inputs(g)
	if plan.configuration and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	if not g.crew.proposal_current(plan):return Result.make("rejected","stale_crew")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	return {}

func crew_notices(g,changes: Array, source := "crew") -> Array:
	var notices:=crew_effect_notices(g,changes)
	for change in changes:notices.append({"kind":"crew_changed","payload":{"crewId":change.current.crewId,"previous":change.previous,"current":change.current,"source":source}})
	return notices

func commit_planet_command(g,plan: Dictionary,payload: Dictionary) -> bool:
	return Result.succeeded(commit_planet_command_result(g,plan,payload))

func commit_planet_command_result(g,plan: Dictionary,payload: Dictionary) -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	plan=plan.duplicate(true)
	Result.freeze(plan)
	if not g.planets.proposal_current(plan):return Result.make("rejected","stale_planet")
	var configuration_before: Array=g.attributes.configuration_inputs(g)
	if plan.configuration and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	if not g.planets.proposal_current(plan):return Result.make("rejected","stale_planet")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	var defence:=capture_progress_health(g,plan.configuration)
	g.planets.commit(plan)
	if plan.configuration:g.invalidate_tutorial_unlocks()
	g.commit_effects.settle_progress(g,plan.configuration,defence)
	return g.commit_effects.finish(g,["planets"],[],[],{"reactor_allocation_changed":plan.configuration},[{"kind":"planet_changed","payload":payload}])

func reforge_planet(g,id: String,keep_drones: Array=[],claim_stages: Dictionary={}) -> bool:
	if g.commit_effects.active:return false
	if not g.can_reforge_planet(id):return false
	if not g.native_before_configuration_change() or not g.can_reforge_planet(id):return false
	var planet_plan: Dictionary=g.planets.prepare_conquest(g,id)
	if planet_plan.is_empty():return false
	var hyperspace_plan: Dictionary=g.hyperspace.prepare_reforge(g,keep_drones,claim_stages)
	if hyperspace_plan.is_empty():return false
	var start_level: int= g.planet_reforge_start(id)
	# Prepare the complete replacement before changing any authoritative state.
	var next: Dictionary= g.fresh_profile()
	next.grantedUnlocks = []
	next.seenUnlocks = g.profile.get("seenUnlocks",[]).duplicate()
	next.readUnlocks = g.profile.get("readUnlocks",[]).duplicate()
	if g.hyperspace.is_unlocked(g) and not next.seenUnlocks.has("hyperspace"):
		next.seenUnlocks.append("hyperspace")
	for gate_id in g.available_unlocks():
		var gate: Dictionary = g.db.data.unlock[gate_id]
		if not next.seenUnlocks.has(gate_id):next.seenUnlocks.append(gate_id)
		if int(gate.level)<=start_level or gate.type in ["crew","planet"] or (gate.type=="feature" and gate.target in ["crew_level","galaxy"]):next.grantedUnlocks.append(gate_id)
	for gate_id in g.granted_unlocks():
		if g.db.data.unlock[gate_id].type == "planet" and not next.grantedUnlocks.has(gate_id):next.grantedUnlocks.append(gate_id)
	# Skip earlier stages without granting combat income. Existing unlock rules
	# derive their availability from this new run's progression as usual.
	next.cleared = range(1,start_level)
	next.bossSeen = next.cleared.duplicate()
	next.lifetime_max_stage=maxi(int(g.profile.get("lifetime_max_stage",1)),int(g.profile.highestLevel))
	# Ordinary reserves survive reforge; only run fragments/reactor reset.
	next.productionElapsed=g.production_time()
	var signals_were_blocked: bool=g.is_blocking_signals()
	g.set_block_signals(true)
	var cancelled_queue: bool=g.manual_hyperspace.cancel_queue(g,"round_changed")
	clear_runtime(g)
	g.profile=next
	g.hyperspace.commit(hyperspace_plan)
	g.planets.commit(planet_plan)
	g.reset_equipment()
	g.enhancement_growth.reset()
	g.research.reset()
	g.economy.reset_run_fragments()
	var empty_wallet: Dictionary= g.economy.material_wallet()
	for material in empty_wallet.materials:empty_wallet.materials[material]=0
	empty_wallet.ultimate_cores=0
	g.economy.install_material_wallet(empty_wallet)
	g.reactor.reset(g.db.config)
	g.drops.clear()
	g.projectiles.clear()
	g.enemies.clear()
	g.speed=g.default_speed()
	g.auto_gen_elapsed=0.0
	rebuild_contributions(g)
	g.ensure_loadout()
	g.reset_player()
	rebuild_schedule(g)
	g.save_dirty=true
	g.set_block_signals(signals_were_blocked)
	var persist: bool= g.save_enabled
	g.save_enabled=false
	g.start(start_level,false)
	g.save_enabled=persist
	if cancelled_queue:g.event.emit("hyperspace_queue",{"status":"cancelled","reason":"round_changed"})
	g.event.emit("unlocks_changed",{})
	g.event.emit("planet_reforged",{"id":id})
	return true

func advance_planets(g,dt: float) -> void:
	if g.commit_effects.active or dt<=0 or not is_finite(dt):return
	var tracked:bool=g.step_progress.active and g.step_progress.phase=="shared" and g.step_progress.stage==4
	if tracked and not g.step_progress.accepted:
		g.step_progress.items=g.planets.all().keys();g.step_progress.accepted=true
	var ids:Array=g.step_progress.items if tracked else g.planets.all().keys()
	var index:int=g.step_progress.item if tracked else 0
	while index<ids.size():
		var id=ids[index]
		var planet_plan: Dictionary=g.planets.prepare_step(g,str(id),dt)
		var result:=commit_planet_step_result(g,planet_plan)
		if not Result.succeeded(result):
			g.block_step(str(result.reason));return
		if tracked and g.step_progress.item==index:g.step_progress.retire_item(4)
		index+=1

func commit_planet_step_result(g,planet_plan: Dictionary) -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	if planet_plan.is_empty():return NO_CHANGE
	if not g.planets.proposal_current(planet_plan):return Result.make("rejected","stale_planet")
	if not planet_plan.completed:
		if not g.commit_effects.begin_progress():return Result.make("blocked","commit_in_progress")
		g.planets.commit(planet_plan)
		g.step_progress.retire_item(4)
		return g.commit_effects.finish_progress(g,PLANET_PROGRESS)
	planet_plan=planet_plan.duplicate(true)
	Result.freeze(planet_plan)
	var id: String=planet_plan.id
	var reward: float=g.planet_exp_reward(id);var rewards: Dictionary={}
	if reward>0:
		if g.planet_buffs.shares_experience(g,id):
			for member in g.crew.members():rewards[member.crewId]=reward
		else:rewards[planet_plan.crew_id]=reward
	var crew_plan: Dictionary=g.crew.prepare_experience(g,rewards)
	if not g.crew.proposal_current(crew_plan):return Result.make("rejected","stale_crew")
	var configuration_before: Array=g.attributes.configuration_inputs(g)
	if (planet_plan.configuration or crew_plan.configuration) and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	if not g.planets.proposal_current(planet_plan) or not g.crew.proposal_current(crew_plan):return Result.make("rejected","stale_planet_step")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	var refitted: bool=planet_plan.configuration or crew_plan.configuration
	var defence:=capture_progress_health(g,refitted)
	g.planets.commit(planet_plan);g.crew.commit(crew_plan)
	g.step_progress.retire_item(4)
	g.commit_effects.settle_progress(g,refitted,defence)
	var notices:=crew_notices(g,crew_plan.changes,"planet")
	notices.append({"kind":"planet_changed","payload":{"id":id,"crewId":planet_plan.crew_id,"reward":reward}})
	var domains:Array=["planets"]
	if not crew_plan.changes.is_empty():domains.append("crew")
	return g.commit_effects.finish(g,domains,[],[],{"crew_changes":crew_plan.changes,"reactor_allocation_changed":true},notices)

func assign_crew(g,crew_id: String, assignment_type: String, target_id: String, upgrade_mode := "") -> bool:
	return Result.succeeded(assign_crew_result(g,crew_id,assignment_type,target_id,upgrade_mode))

func assign_crew_result(g,crew_id: String, assignment_type: String, target_id: String, upgrade_mode := "") -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	var plan: Dictionary=g.crew.prepare_assignment(g,crew_id,assignment_type,target_id,upgrade_mode)
	var rejected:=prepare_crew_commit(g,plan)
	if not rejected.is_empty():return rejected
	if not g.crew.can_assign(g,crew_id,assignment_type,target_id):return Result.make("rejected","assignment_unavailable")
	if plan.changes.is_empty():return Result.make("no_change")
	var previous: Dictionary=plan.changes[0].previous
	if plan.configuration:
		# Earned time belongs to the previous assignment and is settled before transfer.
		if previous.assignmentType=="galaxy_explore":
			if not g.galaxy_runtime.flush_pending(g,str(previous.targetId)):return Result.make("blocked","previous_job_pending")
			if not g.crew.proposal_current(plan) or not g.crew.can_assign(g,crew_id,assignment_type,target_id):return Result.make("rejected","stale_crew")
		if assignment_type=="galaxy_explore" and not g.galaxy_runtime.flush_pending(g,target_id):return Result.make("blocked","target_job_pending")
		if not g.crew.proposal_current(plan) or not g.crew.can_assign(g,crew_id,assignment_type,target_id):return Result.make("rejected","stale_crew")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	var defence:=capture_progress_health(g,plan.configuration)
	var factory_was_active: bool= g.crew.factory_active(g)
	var research_revision: int=g.research.revision
	g.crew.commit(plan)
	if not factory_was_active and g.crew.factory_active(g):g.research.refresh_auto_inputs(g,g.production_time(),true)
	var started: bool=g.galaxy.start(target_id) if assignment_type=="galaxy_explore" else false
	g.commit_effects.settle_progress(g,plan.configuration,defence)
	var notices:=crew_notices(g,plan.changes)
	var domains:Array=["crew"]
	if g.research.revision!=research_revision:domains.append("research")
	if started:
		domains.append("galaxy")
		notices.append({"kind":"galaxy_changed","payload":{"key":target_id}})
	return g.commit_effects.finish(g,domains,[],[],{"crew_changes":plan.changes},notices)

func set_crew_upgrade_mode(g,crew_id: String, mode: String, assignment := "") -> bool:
	return Result.succeeded(set_crew_upgrade_mode_result(g,crew_id,mode,assignment))

func set_crew_upgrade_mode_result(g,crew_id: String, mode: String, assignment := "") -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	var plan: Dictionary=g.crew.prepare_mode(g,crew_id,mode,assignment)
	if not g.crew.proposal_current(plan):return Result.make("rejected","stale_crew")
	if plan.changes.is_empty():return Result.make("no_change")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	g.crew.commit(plan)
	return g.commit_effects.finish(g,["crew"],[],[],{"crew_changes":plan.changes},crew_notices(g,plan.changes))

func select_tech(g,id: String) -> bool:
	return Result.succeeded(select_tech_result(g,id))

func select_tech_result(g,id: String) -> Dictionary:
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	if not g.research.select(g,id):return g.commit_effects.abort("research_selection","rejected")
	return g.commit_effects.finish(g,["research"],[],[],{},[{"kind":"tech_tree_changed","payload":{"reason":"selection","id":id}}])

func record_research_income(g,id: String) -> void:
	record_research_income_result(g,id)

func set_tech_input_result(g,id: String,amount: Variant) -> Dictionary:
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	if not g.research.set_input(g,id,amount):return g.commit_effects.abort("research_input","rejected")
	return g.commit_effects.finish(g,["research"],[],[],{},[{"kind":"tech_tree_changed","payload":{"reason":"input","resource":id}}])

func set_tech_input_ratio_result(g,id: String,ratio: float) -> Dictionary:
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	if not g.research.set_auto_ratio(g,id,ratio):return g.commit_effects.abort("research_input_ratio","rejected")
	return g.commit_effects.finish(g,["research"],[],[],{},[{"kind":"tech_tree_changed","payload":{"reason":"input_ratio","resource":id}}])

func record_research_income_result(g,id: String) -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	var proposal: Dictionary= g.research.income_peak_proposal(g,id)
	if proposal.is_empty():return Result.make("no_change")
	var configuration_before: Array=g.attributes.configuration_inputs(g)
	if proposal.affects_combat and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	if not g.research.proposal_current(proposal):return Result.make("rejected","stale_research")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	var committed: bool=g.research.commit_income_peak(proposal)
	assert(committed,"Research changed inside synchronous commit")
	var notices:Array=[]
	if proposal.affects_combat:
		g.configuration_committed()
		notices.append({"kind":"tech_tree_changed","payload":{"reason":"income_peak","id":id}})
	return g.commit_effects.finish(g,["research"],[],[],{},notices)

func advance_hightech(g,dt: float, _real_dt := -1.0, _end_time := -1.0) -> void:
	if g.commit_effects.active or dt<=0.0 or not is_finite(dt):return
	var proposal: Dictionary= g.research.prepare_advance(g,dt)
	var result:=commit_research_advance_result(g,proposal)
	if result.status!="committed":return
	# Continuation follows the fully published interval; no time or fee is replayed.
	if proposal.completed:continue_research(g)

func commit_research_advance_result(g,proposal: Dictionary) -> Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	if proposal.is_empty():return NO_CHANGE
	if not proposal.completed and not proposal.stopped:
		# No callbacks occur before these two installations. The domain retains
		# its own snapshot; only callback-bearing completion needs a frozen copy.
		if not g.research.proposal_current(proposal) or proposal.inputs!=g.research.advance_inputs(g,proposal.id):return Result.make("rejected","stale_research")
		if not g.commit_effects.begin_progress():return Result.make("blocked","commit_in_progress")
		if not g.economy.commit_research_resources(proposal.resources,proposal.resource_revision):return g.commit_effects.abort("stale_research_wallet","rejected")
		g.research.commit_advance(proposal)
		var mask:int=(1 if proposal.paid.has("1") else 0)+(2 if proposal.paid.has("2") else 0)
		var progress_now_ms:=Time.get_ticks_msec()
		var notify_resources:bool=mask!=0 and progress_now_ms-g.ai_tech_last_resource_notice_ms>=250
		if notify_resources:g.ai_tech_last_resource_notice_ms=progress_now_ms
		return g.commit_effects.finish_progress(g,RESEARCH_PROGRESS[mask],notify_resources)
	proposal=proposal.duplicate(true)
	Result.freeze(proposal)
	var configuration_before: Array=g.attributes.configuration_inputs(g)
	if proposal.completed and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	if not g.research.proposal_current(proposal) or proposal.inputs!=g.research.advance_inputs(g,proposal.id):return Result.make("rejected","stale_research")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	if not g.economy.commit_research_resources(proposal.resources,proposal.resource_revision):return g.commit_effects.abort("stale_research_wallet","rejected")
	g.research.commit_advance(proposal)
	var notices:Array=[]
	if proposal.completed:
		g.configuration_committed()
		notices.append({"kind":"hightech_complete","payload":{"key":proposal.id}})
	elif proposal.stopped:notices.append({"kind":"tech_tree_changed","payload":{"reason":"prerequisite_stopped","id":proposal.id}})
	var now_ms := Time.get_ticks_msec()
	if not proposal.paid.is_empty() and now_ms-g.ai_tech_last_resource_notice_ms>=250:
		g.ai_tech_last_resource_notice_ms=now_ms
		notices.append({"kind":"resources_changed","payload":{"ids":proposal.paid}})
	var domains:Array=["research"]
	if not proposal.paid.is_empty():domains.append("economy")
	return g.commit_effects.finish(g,domains,proposal.paid,[],{},notices)

func refresh_factory_inputs(g,dt: float) -> void:
	if g.commit_effects.active or not g.crew.factory_active(g):return
	var refreshed: bool= g.research.advance_auto_inputs(g,dt,g.production_time())
	g.save_dirty=true
	if refreshed:g.event.emit("tech_tree_changed",{"reason":"automatic_input"})

func capture_progress_health(g, configuration: bool) -> Dictionary:
	if not configuration:return {}
	var defence: Dictionary={"armour":g.stat("armour"),"shield":g.stat("shield")}
	g.capture_refit_health()
	return defence

func crew_effect_notices(g,changes: Array) -> Array:
	var notices:Array=[]
	if not g.crew.levels_unlocked(g):return notices
	var kinds: Dictionary={}
	for change in changes:
		var previous: Dictionary=change.previous;var current: Dictionary=change.current
		if previous.level==current.level and previous.assignmentType==current.assignmentType and previous.targetId==current.targetId:continue
		for member in [previous,current]:
			var job: Dictionary=g.crew.assignments(g).get(str(member.assignmentType),{})
			kinds[str(job.get("targetType",""))]=true
	if kinds.has("equipment") or kinds.has("reactor"):
		for category in ["weapons","defence"]:notices.append({"kind":"equipment_stats","payload":{"category":category}})
	if kinds.has("hightech"):notices.append({"kind":"tech_tree_changed","payload":{"reason":"crew_speed"}})
	if kinds.has("reactor"):notices.append({"kind":"reactor_changed","payload":{}})
	return notices

func continue_research(g) -> void:
	# Only completion continues research; assignment/load preserve manual pause.
	if not g.crew.factory_active(g) or not g.research.selected().is_empty():return
	var next: String=g.research.shortest_available(g)
	if not next.is_empty():select_tech(g,next)

func clear_runtime(g) -> void:
	g.crew.clear_schedule()
	g.galaxy_runtime.reset()
	g.hyperspace_runtime.reset()
	g.step_progress.reset();g.departure_remaining=0.0;g.resource_prune_elapsed=0.0
	g.income_history.clear();g.pending_unlocks.clear()

func install_loaded_domains(g, raw: Dictionary) -> void:
	g.economy.install_snapshot(raw)
	g.equipment.install_snapshot(raw,g.db)
	g.profile.productionElapsed=float(raw.productionElapsed)
	g.enhancement_growth.install_snapshot(raw)
	g.load_hightech(raw)
	g.crew.install_snapshot(raw,g.db)
	g.planets.install_snapshot(raw,g.db)
	g.reactor.install_snapshot(raw,g.db.config)
	g.hyperspace.install_snapshot(raw,g.db)
	g.galaxy.install_snapshot(raw,g.db)

func rebuild_contributions(g) -> void:
	g.rebuild_unlock_gates()
	g.profile.hightechOrder=g.hightech_slots()
	g.refresh_unlock_revision()
	g.galaxy_runtime.refresh_unlocks(g)
	g.configuration_committed()
	var installed_revision: int=g.reactor.revision
	g.reactor.reconcile_capacity(g.reactor_capacity())
	if g.reactor.revision!=installed_revision:g.configuration_committed()

func rebuild_schedule(g) -> void:
	g.crew.reset_schedule(g)
