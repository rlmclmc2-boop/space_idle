extends RefCounted
const N=preload("res://scripts/growth_number.gd")
## Concrete coordination of crew, planets and research. Domains own state; Game owns time.

func add_crew_exp(g,crew_id: String, amount: float) -> bool:
	if not g.crew.levels_unlocked(g) or not g.crew.unlocked(g,crew_id):return false
	var plan: Dictionary=g.crew.prepare_experience(g,{crew_id:amount})
	if not prepare_crew_commit(g,plan):return false
	var defence:=capture_progress_health(g,plan.configuration)
	g.crew.commit(plan)
	finish_progress_change(g,plan.configuration,defence)
	notify_crew_changes(g,plan.changes)
	return true

func prepare_crew_commit(g,plan: Dictionary) -> bool:
	if not g.crew.proposal_current(plan):return false
	if plan.configuration and not g.native_before_configuration_change():return false
	return g.crew.proposal_current(plan)

func notify_crew_changes(g,changes: Array, source := "crew") -> void:
	if changes.is_empty():return
	notify_crew_effects(g,changes)
	for change in changes:g.event.emit("crew_changed",{"crewId":change.current.crewId,"previous":change.previous,"current":change.current,"source":source})

func commit_planet_command(g,plan: Dictionary,payload: Dictionary) -> bool:
	if not g.planets.proposal_current(plan):return false
	if plan.configuration and not g.native_before_configuration_change():return false
	if not g.planets.proposal_current(plan):return false
	var defence:=capture_progress_health(g,plan.configuration)
	g.planets.commit(plan)
	if plan.configuration:g.invalidate_tutorial_unlocks()
	finish_progress_change(g,plan.configuration,defence)
	g.event.emit("planet_changed",payload)
	return true

func reforge_planet(g,id: String,keep_drones: Array=[],claim_stages: Dictionary={}) -> bool:
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
	if dt<=0 or not is_finite(dt):return
	for id in g.planets.all():
		var planet_plan: Dictionary=g.planets.prepare_step(g,str(id),dt)
		if planet_plan.is_empty():continue
		if not planet_plan.completed:
			g.planets.commit(planet_plan);continue
		var reward: float=g.planet_exp_reward(str(id));var rewards: Dictionary={}
		if reward>0:
			if g.planet_buffs.shares_experience(g,str(id)):
				for member in g.crew.members():rewards[member.crewId]=reward
			else:rewards[planet_plan.crew_id]=reward
		var crew_plan: Dictionary=g.crew.prepare_experience(g,rewards)
		if not g.crew.proposal_current(crew_plan):return
		if (planet_plan.configuration or crew_plan.configuration) and not g.native_before_configuration_change():return
		if not g.planets.proposal_current(planet_plan) or not g.crew.proposal_current(crew_plan):return
		var refitted: bool=planet_plan.configuration or crew_plan.configuration
		var defence:=capture_progress_health(g,refitted)
		g.planets.commit(planet_plan);g.crew.commit(crew_plan)
		finish_progress_change(g,refitted,defence)
		notify_crew_changes(g,crew_plan.changes,"planet")
		g.event.emit("planet_changed",{"id":id,"crewId":planet_plan.crew_id,"reward":reward})

func assign_crew(g,crew_id: String, assignment_type: String, target_id: String, upgrade_mode := "") -> bool:
	var plan: Dictionary=g.crew.prepare_assignment(g,crew_id,assignment_type,target_id,upgrade_mode)
	if not prepare_crew_commit(g,plan) or not g.crew.can_assign(g,crew_id,assignment_type,target_id):return false
	if plan.changes.is_empty():return true
	var previous: Dictionary=plan.changes[0].previous
	if plan.configuration:
		# Earned time belongs to the previous assignment and is settled before transfer.
		if previous.assignmentType=="galaxy_explore":
			if not g.galaxy_runtime.flush_pending(g,str(previous.targetId)):return false
			if not g.crew.proposal_current(plan) or not g.crew.can_assign(g,crew_id,assignment_type,target_id):return false
		if assignment_type=="galaxy_explore" and not g.galaxy_runtime.flush_pending(g,target_id):return false
		if not g.crew.proposal_current(plan) or not g.crew.can_assign(g,crew_id,assignment_type,target_id):return false
	var defence:=capture_progress_health(g,plan.configuration)
	var factory_was_active: bool= g.crew.factory_active(g)
	g.crew.commit(plan)
	if not factory_was_active and g.crew.factory_active(g):g.research.refresh_auto_inputs(g,g.production_time(),true)
	var started: bool=g.galaxy.start(target_id) if assignment_type=="galaxy_explore" else false
	finish_progress_change(g,plan.configuration,defence)
	notify_crew_changes(g,plan.changes)
	if started:g.event.emit("galaxy_changed",{"key":target_id})
	return true

func set_crew_upgrade_mode(g,crew_id: String, mode: String, assignment := "") -> bool:
	var plan: Dictionary=g.crew.prepare_mode(g,crew_id,mode,assignment)
	if not g.crew.proposal_current(plan):return false
	g.crew.commit(plan);g.save_dirty=true
	notify_crew_changes(g,plan.changes)
	return true

func select_tech(g,id: String) -> bool:
	if not g.research.select(g,id):return false
	g.save_dirty = true
	g.event.emit("tech_tree_changed",{"reason":"selection","id":id})
	return true

func record_research_income(g,id: String) -> void:
	var proposal: Dictionary= g.research.income_peak_proposal(g,id)
	if proposal.is_empty():return
	if proposal.affects_combat and not g.native_before_configuration_change():return
	if not g.research.commit_income_peak(proposal):return
	g.save_dirty = true
	if proposal.affects_combat:
		g.configuration_committed()
		g.event.emit("tech_tree_changed",{"reason":"income_peak","id":id})

func advance_hightech(g,dt: float, _real_dt := -1.0, _end_time := -1.0) -> void:
	if dt<=0.0 or not is_finite(dt):return
	var proposal: Dictionary= g.research.prepare_advance(g,dt)
	if proposal.is_empty():return
	if proposal.completed and not g.native_before_configuration_change():return
	if not g.research.proposal_current(proposal) or proposal.inputs!=g.research.advance_inputs(g,proposal.id):return
	if not g.economy.commit_research_resources(proposal.resources,proposal.resource_revision):return
	g.research.commit_advance(proposal)
	g.save_dirty = true
	if proposal.completed:
		g.configuration_committed()
		g.event.emit("hightech_complete",{"key":proposal.id})
	elif proposal.stopped:g.event.emit("tech_tree_changed",{"reason":"prerequisite_stopped","id":proposal.id})
	var now_ms := Time.get_ticks_msec()
	if not proposal.paid.is_empty() and now_ms-g.ai_tech_last_resource_notice_ms>=250:
		g.ai_tech_last_resource_notice_ms=now_ms
		g.resources_changed(proposal.paid)
	# A completed interval is committed before choosing the following project.
	# Its research starts on the next shared step, with no replayed time or fee.
	if proposal.completed:continue_research(g)

func refresh_factory_inputs(g,dt: float) -> void:
	if not g.crew.factory_active(g):return
	var refreshed: bool= g.research.advance_auto_inputs(g,dt,g.production_time())
	g.save_dirty=true
	if refreshed:g.event.emit("tech_tree_changed",{"reason":"automatic_input"})

func capture_progress_health(g, configuration: bool) -> Dictionary:
	if not configuration:return {}
	var defence: Dictionary={"armour":g.stat("armour"),"shield":g.stat("shield")}
	g.capture_refit_health()
	return defence

func finish_progress_change(g, configuration: bool, defence: Dictionary) -> void:
	g.save_dirty=true
	if not configuration:return
	# Both domain owners are committed before capacity, descriptors and health settle.
	g.reactor.reconcile_capacity(g.reactor_capacity())
	g.configuration_committed()
	# Configuration changes alone must not clear or redistribute module damage.
	if defence.keys().any(func(key):return N.compare(defence[key],g.stat(key))!=0):g.apply_refit_health()

func notify_crew_effects(g,changes: Array) -> void:
	if not g.crew.levels_unlocked(g):return
	var kinds: Dictionary={}
	for change in changes:
		var previous: Dictionary=change.previous;var current: Dictionary=change.current
		if previous.level==current.level and previous.assignmentType==current.assignmentType and previous.targetId==current.targetId:continue
		for member in [previous,current]:
			var job: Dictionary=g.crew.assignments(g).get(str(member.assignmentType),{})
			kinds[str(job.get("targetType",""))]=true
	if kinds.has("equipment") or kinds.has("reactor"):
		for category in ["weapons","defence"]:g.event.emit("equipment_stats",{"category":category})
	if kinds.has("hightech"):g.event.emit("tech_tree_changed",{"reason":"crew_speed"})
	if kinds.has("reactor"):g.event.emit("reactor_changed",{})

func continue_research(g) -> void:
	# Only completion continues research; assignment/load preserve manual pause.
	if not g.crew.factory_active(g) or not g.research.selected().is_empty():return
	var next: String=g.research.shortest_available(g)
	if not next.is_empty():select_tech(g,next)

func clear_runtime(g) -> void:
	g.crew.clear_schedule()
	g.galaxy_runtime.reset()
	g.hyperspace_runtime.reset()
	g.game_time_remainder=0.0;g.departure_remaining=0.0;g.resource_prune_elapsed=0.0
	g.resource_samples.clear();g.pending_unlocks.clear()

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
