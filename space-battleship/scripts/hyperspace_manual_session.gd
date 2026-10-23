extends RefCounted
## Route IDs are injected from the final encounter owner, never borrowed from mainline.
const Target=preload("res://scripts/hyperspace_return_target.gd")
const View=preload("res://scripts/hyperspace_encounter_database.gd")
const RewardBinding=preload("res://scripts/hyperspace_reward_binding.gd")
var reward_binder:RefCounted
const Loader=preload("res://scripts/hyperspace_route_loader.gd")
var route_ids: Dictionary={}
var registry: Dictionary={}
var production_accepted:=false
var base_db: ShipDatabase
var return_target: Dictionary={}
var round_id:=0
var run_id:=0
var active:=false
var initializing:=false
var last_error:=""
var queued:Dictionary={}
var queue_error:=""
var finishing:Dictionary={}
var transitioning:=false
var last_result:Dictionary={}
var last_rejection:Dictionary={}
func load_production(g,binding: Variant=null,candidate: Variant=null) -> bool:
	if active:return false
	route_ids={};registry={};production_accepted=false;reward_binder=null
	var loader:=Loader.new()
	var prepared: Dictionary=loader.load_files(g) if binding==null and candidate==null else loader.prepare(g,binding,candidate)
	if prepared.is_empty():last_error=loader.last_error;return false
	if not configure(g,prepared.routes,prepared):return false
	if prepared.get("requires_reward_binding",false):
		reward_binder=RewardBinding.new()
		if not reward_binder.load_contract():last_error=reward_binder.last_error;route_ids={};registry={};return false
		# Validate all forty at unlock and current reach; selected levels rebind before charge.
		var unlock:int=int(g.hyperspace.config.unlock_stage)
		var levels:Array=[unlock]
		var reached:int=clampi(int(g.profile.highestLevel),unlock,g.db.levels.size())
		if reached!=unlock:levels.append(reached)
		for level in levels:
			if reward_binder.bind(g.db,registry,level,RewardBinding.latest_cleared_level(g)).is_empty():last_error=reward_binder.last_error;route_ids={};registry={};reward_binder=null;return false
	production_accepted=true;return true
func configure(g,routes: Dictionary,separate: Dictionary={}) -> bool:
	if active or routes.size()!=4:return false
	var groups: Dictionary=g.db.groups if separate.is_empty() else separate.groups
	var enemies: Dictionary=g.db.enemies if separate.is_empty() else separate.enemies
	var main_ids: Dictionary={}
	for level in g.db.levels:
		for point in level.groups:main_ids[str(int(point.id))]=true
	var seen: Dictionary={}
	for route in g.hyperspace.config.routes:
		if not routes.get(route) is Array or routes[route].size()!=10:return false
		for i in 10:
			if not preload("res://scripts/hyperspace_config.gd").integer(routes[route][i]):last_error="encounter_spec_invalid";return false
			var id=str(int(routes[route][i]));var row: Dictionary=groups.get(id,{})
			if main_ids.has(id) or seen.has(id) or row.is_empty():last_error="new_encounter_ids_required";return false
			var expected: String="normal" if i<4 else "elite" if i<8 else "boss" if i==8 else "ultimate"
			if row.get("combatTier")!=expected or not row.get("slots") is Array or not row.has("formation_positions"):last_error="encounter_spec_invalid";return false
			for slot in row.slots:
				if slot!=null and (not preload("res://scripts/hyperspace_config.gd").integer(slot) or not enemies.has(str(int(slot)))):last_error="encounter_enemy_missing";return false
			var resolver=preload("res://scripts/enemy_formation.gd").new()
			if not resolver.has_method("explicit_error"):last_error="formation_support_required";return false
			if not str(resolver.call("explicit_error",row.slots,enemies,row.formation_positions)).is_empty():last_error="encounter_spec_invalid";return false
			seen[id]=true
	route_ids=routes.duplicate(true);registry=separate.duplicate(true);production_accepted=false;last_error="";return true
func request(g,route:String,level:int)->bool:
	queue_error=""
	if not g.hyperspace.eligible_level(g,route,level):queue_error="unavailable";return false
	return start(g,route,level)
func cancel_queue(g,reason:String="")->bool:
	if queued.is_empty():return false
	queued={};queue_error=reason;g.event.emit("hyperspace_queue",{"status":"cancelled","reason":reason});return true
func dispatch_queued(g)->bool:
	if g.logical_step_active or g.step_progress.active or transitioning:return false
	if not finishing.is_empty():
		var ending=finishing;finishing={}
		return finish(g,bool(ending.success),str(ending.reason))
	if queued.is_empty():return false
	if int(queued.round)!=int(g.hyperspace.state.round_id):cancel_queue(g,"round_changed");return false
	var choice=queued;queued={}
	if not start(g,str(choice.route),int(choice.level)):
		queue_error=last_error if not last_error.is_empty() else "setup_failed";g.event.emit("hyperspace_queue",{"status":"rejected","reason":queue_error});return false
	queue_error="";g.event.emit("hyperspace_queue",{"status":"dispatched"});return true
func reset_for_load(g)->void:
	cancel_queue(g,"reload")
	if active:g.db=base_db
	active=false;initializing=false;base_db=null;return_target={};finishing={};transitioning=false;last_result={}
func start(g,route: String,level: int) -> bool:
	last_error=""
	if transitioning or active or not queued.is_empty() or not g.hyperspace.state.active.is_empty() or not route_ids.has(route) or not g.hyperspace.eligible_level(g,route,level):return false
	if g.logical_step_active:
		queued={"route":route,"level":level,"round":int(g.hyperspace.state.round_id)}
		return true
	if g.step_progress.active:last_error="incomplete_logical_step";return false
	if g.N.compare(g.stat("armour"),0)<=0:return false
	var bound_registry:Dictionary=registry
	if reward_binder!=null:
		bound_registry=reward_binder.bind(g.db,registry,level,RewardBinding.latest_cleared_level(g))
		if bound_registry.is_empty():last_error=reward_binder.last_error;production_accepted=false;return false
		production_accepted=true
	var point:Dictionary=Target.destination(g)
	if not Target.binding_valid(point,g.profile,g.db.data):last_error="invalid_return_target";return false
	var view:=View.new();view.configure(g.db,level,route_ids[route],bound_registry)
	transitioning=true
	# At a completed logical boundary, existing drops settle normally. start()
	# cancels the native owner and clears combat directly, without cold handoff.
	g.settle_drops()
	var signals_were_blocked:bool=g.is_blocking_signals();g.set_block_signals(true)
	var receipt:Dictionary=g.hyperspace_runtime.start(g,route,level,"manual","",point)
	if receipt.is_empty():
		g.set_block_signals(signals_were_blocked);transitioning=false;return false
	base_db=g.db;return_target=point;round_id=int(receipt.round_id);run_id=int(receipt.run_id)
	g.db=view;active=true;initializing=true
	var started:bool=g.start(level,false)
	initializing=false
	g.set_block_signals(signals_were_blocked)
	transitioning=false
	if not started:finish(g,false,"setup_failed");return false
	publish_transition(g,true,false,"started",route,level)
	return true
func publish_transition(g,entered:bool,success:bool,kind:String,route:String="",level:int=0)->void:
	transitioning=true
	g.event.emit("prototype_missile_reset",{})
	g.event.emit("hyperspace_changed",{"reason":kind,"round_id":int(g.hyperspace.state.round_id)})
	g.event.emit("state",{"state":g.state})
	g.event.emit("hyperspace_manual",{"active":entered,"success":success,"route":route,"level":level})
	transitioning=false
func reject_formation(g,errors:Array) -> bool:
	if not active:return false
	last_error="formation_invalid"
	last_rejection={"reason":last_error,"stage":g.stage,"point":g.group_index,"route":g.hyperspace.state.active.get("route",""),"run_id":run_id,"round_id":round_id,"errors":errors.duplicate(true),"uids":g.enemies.map(func(enemy):return int(enemy.uid))}
	g.event.emit("encounter_rejected",last_rejection.duplicate(true))
	return finish(g,false,last_error)
func finish(g,success: bool,reason: String="failed") -> bool:
	if not active or transitioning:return false
	if g.logical_step_active:
		if finishing.is_empty():finishing={"success":success,"reason":reason}
		return true
	if g.step_progress.active:last_error="incomplete_logical_step";return false
	transitioning=true
	g.settle_drops()
	var receipt:Dictionary=g.hyperspace.state.active.duplicate(true)
	var energy_before:float=float(g.hyperspace.state.energy)
	var end_point:int=clampi(g.group_index,1,10)
	var elapsed:float=float(receipt.get("work",0))
	var signals_were_blocked:bool=g.is_blocking_signals();g.set_block_signals(true)
	if not g.hyperspace_runtime.complete(g,round_id,run_id,success,{},elapsed,success):
		g.set_block_signals(signals_were_blocked);transitioning=false;return false
	active=false;g.db=base_db
	var point:Dictionary=return_target
	return_target={};base_db=null;finishing={}
	last_result={"route":str(receipt.route),"level":int(receipt.level),"reason":"success" if success else reason,"elapsed":elapsed,"end_point":end_point,"refund":maxf(0,float(g.hyperspace.state.energy)-energy_before),"return_stage":int(point.stage),"return_point":int(point.guard_index)+1 if point.loop else 0}
	# A normal fresh sortie owns all health/cooldown initialization. Guard mode
	# reopens its selected encounter, never the previous actors or their damage.
	var started:bool=g.start(int(point.stage),bool(point.loop))
	if not started:
		g.reset_sortie(int(point.stage),bool(point.loop));g.change_state(g.State.LEVEL_SELECT)
	if started and point.loop:
		g.profile.guardStage=int(point.stage);g.profile.guardIndex=int(point.guard_index)
		g.profile.guardDistance=Target.checkpoint(point,g.db).distance
		g.resume_guard();g.respawn_guard()
	g.begin_return_departure()
	g.set_block_signals(signals_were_blocked)
	transitioning=false
	publish_transition(g,false,success,"completed_pending" if success else "refunded")
	return true
func positions(g,slots: Array,explicit: Variant) -> Dictionary:
	return preload("res://scripts/enemy_formation.gd").new().call("positions",slots,g.db.enemies,explicit)
