extends RefCounted
## Route IDs are injected from the final encounter owner, never borrowed from mainline.
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
			if reward_binder.bind(g.db,registry,level).is_empty():last_error=reward_binder.last_error;route_ids={};registry={};reward_binder=null;return false
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
func start(g,route: String,level: int) -> bool:
	if active or not route_ids.has(route) or not g.hyperspace.eligible_level(g,route,level) or g.N.compare(g.stat("armour"),0)<=0:return false
	var bound_registry:Dictionary=registry
	if reward_binder!=null:
		bound_registry=reward_binder.bind(g.db,registry,level)
		if bound_registry.is_empty():last_error=reward_binder.last_error;production_accepted=false;return false
		production_accepted=true
	var checkpoint: Dictionary={"stage":g.stage,"distance":g.retreat_target if g.state==g.State.RETREAT else g.distance,"groupIndex":g.group_index,"state":int(g.state),"guardArrived":g.guard_arrived,"retreatBossPending":g.retreat_boss_pending,"pendingUnlocks":g.pending_unlocks.duplicate(),"loop":g.profile.loop}
	var receipt: Dictionary=g.hyperspace.start(g,route,level,"manual")
	if receipt.is_empty():return false
	base_db=g.db;return_journey=checkpoint;round_id=int(receipt.round_id);run_id=int(receipt.run_id)
	var view:=View.new();view.configure(base_db,level,route_ids[route],bound_registry)
	g.profile.hyperspace.active.return_journey=checkpoint.duplicate(true)
	g.db=view;active=true;initializing=true
	var started: bool=g.start(level,false)
	initializing=false
	if not started:
		finish(g,false);return false
	g.event.emit("hyperspace_manual",{"active":true,"route":route,"level":level});return true
func finish(g,success: bool) -> bool:
	if not active:return false
	g.settle_drops()
	var elapsed: float=float(g.profile.hyperspace.active.get("work",0))
	if not g.hyperspace.complete(g,round_id,run_id,success,{},elapsed,success):return false
	active=false;g.db=base_db;var checkpoint: Dictionary=return_journey.duplicate(true)
	return_journey={};base_db=null;g.enemies.clear();g.projectiles.clear();g.cooldowns.clear();g.drone_combat.reset();g.invalidate_stat_cache();g.reset_player()
	if int(checkpoint.state) in [g.State.TRAVEL,g.State.COMBAT,g.State.LEVEL_CLEAR,g.State.RETREAT]:g.start(int(checkpoint.stage),bool(checkpoint.loop),checkpoint)
	else:g.change_state(int(checkpoint.state));g.profile.loop=bool(checkpoint.loop)
	g.event.emit("hyperspace_manual",{"active":false,"success":success});return true
func positions(g,slots: Array,explicit: Variant) -> Dictionary:
	return preload("res://scripts/enemy_formation.gd").new().call("positions",slots,g.db.enemies,explicit)
