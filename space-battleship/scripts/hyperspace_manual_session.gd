extends RefCounted
## Route IDs are injected from the final encounter owner, never borrowed from mainline.
const Return=preload("res://scripts/hyperspace_main_return.gd")
const View=preload("res://scripts/hyperspace_encounter_database.gd")
const RewardBinding=preload("res://scripts/hyperspace_reward_binding.gd")
var reward_binder:RefCounted
const Loader=preload("res://scripts/hyperspace_route_loader.gd")
var route_ids: Dictionary={}
var registry: Dictionary={}
var production_accepted:=false
var base_db: ShipDatabase
var return_journey: Dictionary={}
var round_id:=0
var run_id:=0
var active:=false
var initializing:=false
var last_error:=""
var queued:Dictionary={}
var queue_error:=""
var return_state:Dictionary={}
var loaded_return:Dictionary={}
var last_result:Dictionary={}
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
		var levels:Array=[7]
		var reached:int=clampi(int(g.profile.highestLevel),7,g.db.levels.size())
		if reached!=7:levels.append(reached)
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
	if active or not g.profile.hyperspace.active.is_empty():queue_error="busy";return false
	if not production_accepted or not route_ids.has(route) or not g.hyperspace.eligible_level(g,route,level):queue_error="unavailable";return false
	if float(g.profile.hyperspace.energy)<float(g.hyperspace.config.ticket):queue_error="energy";return false
	if not queued.is_empty():return queued.route==route and int(queued.level)==level
	queued={"route":route,"level":level,"round":int(g.profile.hyperspace.round_id)};queue_error=""
	g.event.emit("hyperspace_queue",{"status":"queued"});return true
func cancel_queue(g,reason:String="")->bool:
	if queued.is_empty():return false
	queued={};queue_error=reason;g.event.emit("hyperspace_queue",{"status":"cancelled","reason":reason});return true
func boundary_reason(g)->String:
	if active:return "busy"
	if g.profile.loop:return "guard"
	if not g.pending_unlocks.is_empty():return "unlock"
	if g.state not in [g.State.MAIN_MENU,g.State.LEVEL_SELECT,g.State.TRAVEL,g.State.LEVEL_CLEAR,g.State.UPGRADE]:return "battle"
	for enemy in g.enemies:
		if g.N.compare(enemy.hp,0)>0:return "battle"
	if not g.projectiles.is_empty() or (g.get("missile_queue") is Array and not g.get("missile_queue").is_empty()) or not g.jewel_repeats.is_empty() or not g.drone_combat.delayed.is_empty():return "projectiles"
	return ""
func dispatch_queued(g)->bool:
	if queued.is_empty():return false
	if int(queued.round)!=int(g.profile.hyperspace.round_id):cancel_queue(g,"round_changed");return false
	if not production_accepted or not route_ids.has(queued.route) or not g.hyperspace.eligible_level(g,str(queued.route),int(queued.level)):cancel_queue(g,"unavailable");return false
	if not g.profile.hyperspace.active.is_empty():cancel_queue(g,"busy");return false
	if float(g.profile.hyperspace.energy)<float(g.hyperspace.config.ticket):cancel_queue(g,"energy");return false
	if not boundary_reason(g).is_empty():return false
	var choice=queued.duplicate();queued={}
	if not start(g,str(choice.route),int(choice.level)):
		queue_error=last_error if not last_error.is_empty() else "setup_failed";g.event.emit("hyperspace_queue",{"status":"rejected","reason":queue_error});return false
	queue_error="";g.event.emit("hyperspace_queue",{"status":"dispatched"});return true
func reset_for_load(g)->void:
	cancel_queue(g,"reload")
	if active:g.db=base_db
	active=false;initializing=false;base_db=null;return_journey={};return_state={};loaded_return={};last_result={}
func start(g,route: String,level: int) -> bool:
	last_error=""
	if active or not queued.is_empty() or not g.profile.hyperspace.active.is_empty() or float(g.profile.hyperspace.energy)<float(g.hyperspace.config.ticket) or not boundary_reason(g).is_empty() or not route_ids.has(route) or not g.hyperspace.eligible_level(g,route,level) or g.N.compare(g.stat("armour"),0)<=0:return false
	var bound_registry:Dictionary=registry
	if reward_binder!=null:
		bound_registry=reward_binder.bind(g.db,registry,level,RewardBinding.latest_cleared_level(g))
		if bound_registry.is_empty():last_error=reward_binder.last_error;production_accepted=false;return false
		production_accepted=true
	# Existing earned drops settle by their ordinary rule, before freezing the main run.
	var point=Return.journey(g);var frozen=Return.capture(g)
	if not Return.valid(frozen,point,g.db.levels.size()):last_error="invalid_main_return";return false
	g.settle_drops();frozen.run_resources=g.run_resources.duplicate(true)
	var receipt: Dictionary=g.hyperspace.start(g,route,level,"manual","",{"journey":point,"state":frozen})
	if receipt.is_empty():return false
	base_db=g.db;return_journey=point;return_state=frozen;round_id=int(receipt.round_id);run_id=int(receipt.run_id)
	var view:=View.new();view.configure(base_db,level,route_ids[route],bound_registry)
	g.db=view;active=true;initializing=true
	var started: bool=g.start(level,false)
	initializing=false
	if not started:finish(g,false,"setup_failed");return false
	g.event.emit("hyperspace_manual",{"active":true,"route":route,"level":level});return true
func finish(g,success: bool,reason: String="failed") -> bool:
	if not active:return false
	g.settle_drops()
	var receipt:Dictionary=g.profile.hyperspace.active.duplicate(true)
	var energy_before:float=float(g.profile.hyperspace.energy)
	var end_point:int=clampi(g.group_index,1,10)
	var elapsed: float=float(receipt.get("work",0))
	if not g.hyperspace.complete(g,round_id,run_id,success,{},elapsed,success):return false
	active=false;g.db=base_db
	var point=return_journey;var frozen=return_state
	return_journey={};return_state={};base_db=null
	last_result={"route":str(receipt.route),"level":int(receipt.level),"reason":"success" if success else reason,"elapsed":elapsed,"end_point":end_point,"refund":maxf(0,float(g.profile.hyperspace.energy)-energy_before),"return_stage":int(point.stage),"return_point":int(point.groupIndex)}
	Return.restore(g,frozen,point)
	# A pending reward no longer owns a suspended main state after it has returned.
	if not g.profile.hyperspace.active.is_empty():
		g.profile.hyperspace.active.return_journey={};g.profile.hyperspace.active.return_state={}
	g.event.emit("hyperspace_manual",{"active":false,"success":success});return true
func positions(g,slots: Array,explicit: Variant) -> Dictionary:
	return preload("res://scripts/enemy_formation.gd").new().call("positions",slots,g.db.enemies,explicit)
