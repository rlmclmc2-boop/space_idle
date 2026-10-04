extends RefCounted
## Commands mutate one profile namespace; no battle, ordinary economy, or save IO.
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var config: Dictionary=C.load_config()
var scheduler:=preload("res://scripts/hyperspace_scheduler.gd").new()
var reward_provider: Callable
var last_error:=""

func configure(c: Dictionary) -> bool:
	if not C.valid(c):return false
	config=c.duplicate(true);scheduler.reset();return true

func fresh() -> Dictionary:
	return S.fresh(config)

func load_state(g,raw: Variant) -> bool:
	scheduler.reset()
	if raw==null:g.profile.hyperspace=fresh();return true
	if not raw is Dictionary or not S.valid(raw,config,g.db.levels.size()):
		last_error="invalid_hyperspace_save";return false
	g.profile.hyperspace=raw.duplicate(true);return true

func snapshot(g) -> Dictionary:
	return g.profile.hyperspace.duplicate(true)

func publish(g,next: Dictionary,kind: String) -> void:
	g.profile.hyperspace=next;g.save_dirty=true;last_error=""
	g.event.emit("hyperspace_changed",{"reason":kind,"round_id":next.round_id})

func eligible_level(g,route: String,level: int) -> bool:
	return int(g.profile.highestLevel)>=int(config.unlock_stage) and config.routes.has(route) and level>=int(config.minimum_level) and level<=int(g.profile.highestLevel) and level<=g.db.levels.size()

func best_x1(g,route: String,level: int) -> float:
	if not eligible_level(g,route,level):return 0.0
	return float(g.profile.hyperspace.history.get(route,{}).get(str(level),0.0))

func start(g,route: String,level: int,mode: String,crew_level: int=0) -> Dictionary:
	var s: Dictionary=g.profile.hyperspace
	if not eligible_level(g,route,level) or not s.active.is_empty() or mode not in ["manual","auto"] or crew_level<0:return {}
	var duration:=0.0;var ticket:=float(config.ticket)
	if mode=="auto":
		if not Bag.has_space(s.inventory,config) or float(s.energy)<float(config.energy_cap):return {}
		var best:=best_x1(g,route,level)
		if best<=0 or not reward_provider.is_valid():return {}
		duration=maxf(float(config.minimum_duration),best*100.0/(100.0+crew_level))
		ticket*=20.0/(20.0+crew_level)
	if float(s.energy)<ticket:return {}
	var next: Dictionary=s.duplicate(true)
	next.energy=float(s.energy)-ticket;next.blocked=false
	next.active={"round_id":int(s.round_id),"run_id":int(s.next_run),"status":"started","mode":mode,"route":route,"level":level,"ticket":ticket,"duration":duration,"work":0.0,"reward":{}}
	next.next_run+=1;publish(g,next,"started")
	return next.active.duplicate(true)

func complete(g,round_id: int,run_id: int,success: bool,reward: Dictionary={},x1_seconds: float=0.0,record_x1: bool=false) -> bool:
	var s: Dictionary=g.profile.hyperspace
	var a: Dictionary=s.active
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="started":return false
	var next: Dictionary=s.duplicate(true)
	if not success:
		next.energy=float(next.energy)+float(a.ticket);next.settled_run=run_id;next.active={};next.blocked=false;next.pending_time=0.0
		scheduler.reset();publish(g,next,"refunded");return true
	var frozen: Dictionary=reward.duplicate(true)
	if frozen.get("drone") is Dictionary:
		frozen.drone.id="space:%d:%d"%[round_id,run_id]
	if not S.valid_reward(frozen,str(a.route),config) or int(frozen.drone.level)!=int(a.level):
		last_error="invalid_reward";return false
	if record_x1 and (a.mode!="manual" or not C.number(x1_seconds) or x1_seconds<=0):return false
	next.active.status="completed_pending";next.active.reward=frozen;next.unlocked_drones=true
	if record_x1:
		var history: Dictionary=next.history.get(a.route,{})
		var old:=float(history.get(str(int(a.level)),0.0))
		history[str(int(a.level))]=minf(old,x1_seconds) if old>0 else x1_seconds
		next.history[a.route]=history
	next.blocked=not Bag.has_space(next.inventory,config)
	publish(g,next,"completed_pending");return true

func claim(g,round_id: int,run_id: int) -> bool:
	var s: Dictionary=g.profile.hyperspace;var a: Dictionary=s.active
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="completed_pending":return false
	if not Bag.has_space(s.inventory,config):s.blocked=true;return false
	var next: Dictionary=s.duplicate(true)
	if not Bag.insert(next.inventory,a.reward.drone,config):return false
	for key in a.reward.materials:
		var amount:=int(next.materials[key])+int(a.reward.materials[key])
		if not C.integer(amount):return false
		next.materials[key]=amount
	next.settled_run=run_id;next.active={};next.blocked=not Bag.has_space(next.inventory,config)
	publish(g,next,"claimed");return true

func set_auto(g,enabled: bool,route: String,level: int,crew_level: int) -> bool:
	if enabled and (not eligible_level(g,route,level) or best_x1(g,route,level)<=0 or crew_level<0):return false
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	next.pending_time=0.0
	next.auto={"enabled":enabled,"route":route if enabled else "","level":level if enabled else 0,"crew_level":crew_level if enabled else 0}
	scheduler.reset();publish(g,next,"auto_changed");return true

func auto_eligible(g) -> bool:
	var auto: Dictionary=g.profile.hyperspace.auto
	return auto.enabled and reward_provider.is_valid() and best_x1(g,str(auto.route),int(auto.level))>0

func start_auto(g) -> bool:
	var auto: Dictionary=g.profile.hyperspace.auto
	return not start(g,str(auto.route),int(auto.level),"auto",int(auto.crew_level)).is_empty()

func complete_auto(g) -> bool:
	var a: Dictionary=g.profile.hyperspace.active
	if a.is_empty() or a.mode!="auto" or float(a.work)<float(a.duration) or not reward_provider.is_valid():return false
	var reward=reward_provider.call(a.duplicate(true))
	var ok: bool=reward is Dictionary and complete(g,int(a.round_id),int(a.run_id),true,reward)
	if not ok:reward_provider=Callable() # A broken adapter must be explicitly replaced.
	return ok

func advance(g,dt: float) -> void:
	scheduler.advance(self,g,dt)

func set_equipped(g,ids: Array,hull_capacity: int) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if hull_capacity<0 or not Bag.equipment_valid(next.inventory,ids,hull_capacity,config):return false
	next.inventory.equipped=ids.duplicate();next.inventory.generation+=1
	publish(g,next,"equipment_changed");return true

func set_favorites(g,ids: Array) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if not Bag.references_valid(ids,next.inventory):return false
	next.inventory.favorites=ids.duplicate();next.inventory.generation+=1
	publish(g,next,"favorites_changed");return true

func set_preset(g,index: int,name: String,ids: Array,hanging_loadouts: Dictionary={}) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if index<0 or index>2 or index>next.inventory.presets.size() or name.length()>96 or not Bag.references_valid(ids,next.inventory):return false
	var hangings: Dictionary=hanging_loadouts.duplicate(true)
	if hangings.is_empty():
		for id in ids:hangings[id]=next.inventory.drones[id].hangings.duplicate()
	var preset: Dictionary={"name":name,"drone_ids":ids.duplicate(),"hanging_loadouts":hangings}
	if index==next.inventory.presets.size():next.inventory.presets.append(preset)
	else:next.inventory.presets[index]=preset
	if not Bag.valid(next.inventory,config):return false
	publish(g,next,"preset_changed");return true

func clear_preset(g,index: int) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if index<0 or index>=next.inventory.presets.size():return false
	next.inventory.presets.remove_at(index);publish(g,next,"preset_changed");return true

func remove_unprotected(g,id: String) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if not Bag.remove(next.inventory,id):return false
	Bag.organize(next.inventory,config);next.blocked=false;next.pending_time=0.0;scheduler.reset()
	publish(g,next,"organized");return true

func claim_sealed(g,id: String) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if not next.inventory.sealed.has(id) or int(g.profile.highestLevel)<int(next.inventory.sealed[id]):return false
	next.inventory.sealed.erase(id);next.inventory.generation+=1
	publish(g,next,"unsealed");return true

func reforge_state(g,keep_ids: Array,claim_stages: Dictionary) -> Dictionary:
	var old: Dictionary=g.profile.hyperspace
	var bag:=Bag.reforge(old.inventory,keep_ids,claim_stages,config)
	if bag.is_empty():return {}
	var next:=fresh();next.round_id=int(old.round_id)+1;next.inventory=bag
	next.history=old.history.duplicate(true);next.unlocked_drones=old.unlocked_drones
	return next
