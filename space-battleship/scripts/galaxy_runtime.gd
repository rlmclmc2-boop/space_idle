extends RefCounted
## Concrete galaxy command coordinator owned by Game. The domain supplies work and income plans.
var native_prepared:=false
var native_refit:Dictionary={}
func reset()->void:native_prepared=false;native_refit={}
func refresh_unlocks(g)->void:
	var unlocked:Array=g.galaxy.refresh_unlocks(g)
	if not unlocked.is_empty():g.invalidate_tutorial_unlocks();g.save_dirty=true
	for key in unlocked:g.event.emit("galaxy_unlocked",{"key":key})
func prepare_advance(g,dt:float)->bool:
	if g.native_execution==null or dt<=0 or g.paused:reset();return true
	if native_prepared:return true
	native_refit={}
	var candidate:Dictionary=g.galaxy.preview_advance(g,dt)
	if candidate.has("boundary"):return g.native_execution.handoff_to_legacy(g,"galaxy_crew_configuration" if candidate.boundary=="crew_change" else "galaxy_compound_configuration")
	if not candidate.is_empty() and not prepare_refit(g,g.galaxy.prepare_region(candidate.key,candidate.dt,candidate.count)):return false
	native_prepared=true;return true
func prepare_refit(g,proposal:Dictionary)->bool:
	var session=g.native_execution
	# A building selection or a noncombat contribution needs no native descriptor.
	if not proposal.refitted:
		native_refit={"proposal":proposal,"plan":{},"session":session};return true
	var plan:Dictionary=session.prepare_galaxy_refit(g,g.galaxy.effects.projected_multipliers(g.galaxy,proposal.key,proposal.region)) if session.has_method("prepare_galaxy_refit") else {}
	if plan.is_empty():return session.handoff_to_legacy(g,"galaxy_configuration")
	native_refit={"proposal":proposal,"plan":plan,"session":session};return true
func advance(g,dt:float)->void:
	if dt<=0 or g.paused or g.galaxy.regions.is_empty():return
	if not prepare_advance(g,dt):return
	native_prepared=false
	g.galaxy.add_income_time(dt)
	if g.galaxy.income_due(g):
		refresh_unlocks(g)
		var income:Dictionary=g.galaxy.prepare_income(g)
		if not g.galaxy.income_current(income) or not g.economy.credit_many(income.gains):return
		g.galaxy.commit_income(income)
		# Both currencies and consumed income time are visible before any notification.
		for id in income.gains:g.income_history.record({"time":g.economy_time(),"production_time":g.production_time(),"id":id,"amount":income.gains[id],"origin":"galaxy"})
		g.save_dirty=true
		for id in income.gains:g.event.emit("galaxy_income",{"id":id,"amount":income.gains[id]})
	for key in g.galaxy.regions:
		var region=g.galaxy.regions[key]
		if not region.state.status in ["exploring","developing"]:continue
		var count:int=g.galaxy.crew_count(g,key)
		if count!=g.galaxy.pending_crew(key) and not flush_pending(g,key):return
		g.galaxy.set_pending_context(key,count)
		if count<=0:continue
		g.galaxy.add_pending(key,dt)
		if g.galaxy.pending_due(g,key) and not flush_pending(g,key):return
func flush_pending(g,key:String)->bool:
	if g.commit_effects.active:return false
	if not g.galaxy.regions.has(key) or g.galaxy.pending(key)<=0:return true
	# Reuse only this session's prediction for the exact work still pending.
	var ready:bool=not native_refit.is_empty() and native_refit.session==g.native_execution and native_refit.proposal.key==key and g.galaxy.region_current(native_refit.proposal)
	var proposal:Dictionary=native_refit.proposal if ready else g.galaxy.prepare_region(key,g.galaxy.pending(key),g.galaxy.pending_crew(key))
	if g.native_execution!=null and proposal.refitted:
		if native_refit.is_empty() and not prepare_refit(g,proposal):return block(g)
		if g.native_execution!=null:
			ready=not native_refit.is_empty() and native_refit.session==g.native_execution and native_refit.proposal.key==key and g.galaxy.region_current(native_refit.proposal)
			if ready and not g.native_execution.paused_by_configuration:
				if not g.commit_effects.begin(g):return false
				if g.native_execution.commit_galaxy_refit(g,native_refit.plan):
					proposal=native_refit.proposal
					g.galaxy.commit_region(proposal);native_refit={}
					g.configuration_committed(true)
					g.enhancement_branches.reconcile(g)
					publish(g,proposal);return true
				g.commit_effects.abort("native_refit")
			if not g.native_execution.handoff_to_legacy(g,"galaxy_configuration"):return block(g)
	native_refit={}
	if not g.galaxy.region_current(proposal):return false
	if not g.commit_effects.begin(g):return false
	if proposal.refitted:g.capture_refit_health()
	g.galaxy.commit_region(proposal)
	if proposal.refitted:g.configuration_committed();g.apply_refit_health()
	publish(g,proposal);return true
func publish(g,proposal:Dictionary)->void:
	# Pending work was consumed before map callbacks, saves and business notifications.
	assert(g.commit_effects.active,"Galaxy publication follows its guarded installation")
	if proposal.completed:g.invalidate_tutorial_unlocks()
	var notices:Array=[]
	if proposal.refitted:
		for category in ["weapons","defence"]:notices.append({"kind":"equipment_stats","payload":{"category":category}})
		notices.append({"kind":"reactor_changed","payload":{}})
	notices.append({"kind":"galaxy_changed","payload":{"key":proposal.key}})
	g.commit_effects.finish(g,["galaxy"],[],[],{"reactor_allocation_changed":proposal.refitted},notices,func():g.galaxy.regions[proposal.key].sync_map())
	if proposal.completed:refresh_unlocks(g)
func block(g)->bool:
	g.native_execution.galaxy_refit_blocked=true
	g.native_execution.blocked_shared_step=g.native_step_remaining if g.native_step_phase=="shared" else 0.0
	g.native_execution.advance_blocked=true;g.native_step_phase="blocked";g.paused=true;return false
