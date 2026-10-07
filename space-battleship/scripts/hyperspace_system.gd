extends RefCounted
## Commands mutate one profile namespace; no battle, ordinary economy, or save IO.
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const R=preload("res://scripts/hyperspace_random.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Filter=preload("res://scripts/hyperspace_filter.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var config: Dictionary=C.load_config()
var scheduler:=preload("res://scripts/hyperspace_scheduler.gd").new()
var last_error:=""

func configure(c: Dictionary) -> bool:
	if not C.valid(c):return false
	config=c.duplicate(true);scheduler.reset();return true

func online_config(g) -> Dictionary:
	var supplied:bool=g.profile.cleared.has(int(config.get("late_supply_unlock_stage",60)))
	var cache_key:="hyperspace_energy_config_late" if supplied else "hyperspace_energy_config"
	if g.stat_cache_enabled and g.stat_cache.has(cache_key):return ramp_config(g,g.stat_cache[cache_key],supplied)
	var multiplier:=1.0 if g.profile.hyperspace.inventory.equipped.is_empty() else 1.0+float(g.hyperspace_totals().hangings.get("hyperspace_charge",0))
	var rate_multiplier:float=float(config.get("late_energy_rate_multiplier",1.0)) if supplied else 1.0
	var material_multiplier:int=int(config.get("late_material_reward_multiplier",1)) if supplied else 1
	if multiplier==1.0 and rate_multiplier==1.0 and material_multiplier==1:return config
	var next: Dictionary=config.duplicate()
	next.energy_cap=float(config.energy_cap)*multiplier;next.energy_rate=float(config.energy_rate)*multiplier*rate_multiplier
	next.material_reward_multiplier=material_multiplier
	if g.stat_cache_enabled:g.stat_cache[cache_key]=next
	return ramp_config(g,next,supplied)

func ramp_config(g,c:Dictionary,supplied:bool)->Dictionary:
	if not supplied or not config.has("late_supply_ramp_seconds"):return c
	var elapsed:float=float(g.profile.hyperspace.get("late_supply_work",0.0))
	var duration:float=float(config.late_supply_ramp_seconds)
	var progress:float=clampf(elapsed/duration,0.0,1.0)
	var next:Dictionary=c.duplicate()
	next.late_supply_elapsed=elapsed
	next.late_supply_base_rate=float(c.energy_rate)/float(config.late_energy_rate_multiplier)
	next.energy_rate=float(next.late_supply_base_rate)*lerpf(1.0,float(config.late_energy_rate_multiplier),progress)
	next.material_reward_multiplier=lerpf(1.0,float(config.late_material_reward_multiplier),progress)
	return next

func fresh() -> Dictionary:
	return S.fresh(config)

func load_state(g,raw: Variant) -> bool:
	scheduler.reset()
	if raw==null:g.profile.hyperspace=fresh();return true
	if not raw is Dictionary or not S.valid(raw,config,g.db.levels.size()):
		last_error="invalid_hyperspace_save";return false
	g.profile.hyperspace=raw.duplicate(true)
	var receipt: Dictionary=g.profile.hyperspace.active
	if not receipt.is_empty() and receipt.mode=="manual" and receipt.status=="started":
		if not receipt.get("return_state",{}).is_empty():g.manual_hyperspace.loaded_return={"journey":receipt.return_journey.duplicate(true),"state":receipt.return_state.duplicate(true)}
		var energy_before:float=float(g.profile.hyperspace.energy)
		var refunded:bool=complete(g,int(receipt.round_id),int(receipt.run_id),false)
		var actual_refund:float=float(g.profile.hyperspace.energy)-energy_before
		# Session-only feedback for this real settlement, never persisted/replayed.
		if refunded and actual_refund>0:
			g.manual_hyperspace.last_result={"route":str(receipt.route),"level":int(receipt.level),"reason":"interrupted_reload","refund":actual_refund}
	return true

func snapshot(g) -> Dictionary:
	var result: Dictionary=g.profile.hyperspace.duplicate(true)
	result.hull_capacity=Permission.hull_capacity(g,config)
	result.auto.crew_level=Permission.crew_level(g,str(result.auto.crew_id))
	result.next_command={"round_id":result.round_id,"command_seq":result.command_seq}
	result.combat={"disabled_drones":g.drone_combat.disabled.duplicate(),"rebuild_stacks":g.drone_combat.rebuild_stacks}
	result.manual_ready=g.manual_hyperspace.production_accepted
	result.manual_error=g.manual_hyperspace.last_error
	return result

func publish(g,next: Dictionary,kind: String) -> void:
	var refit: bool=kind in ["equipment_changed","hangings_changed","preset_applied","claimed"] or kind.begins_with("forge_")
	if refit:g.capture_refit_health()
	var previous_capacity: int=g.reactor_capacity() if refit else 0
	g.profile.hyperspace=next;g.save_dirty=true;last_error=""
	if refit or kind=="hull_capacity_changed":g.invalidate_stat_cache()
	if refit:
		var capacity: int=g.reactor_capacity()
		var remaining: int=capacity
		for key in g.reactor_modules():
			g.profile.reactorAllocation[key]=mini(int(g.profile.reactorAllocation.get(key,0)),remaining)
			remaining-=int(g.profile.reactorAllocation[key])
		g.apply_refit_health()
		if capacity!=previous_capacity:g.event.emit("reactor_changed",{"capacity":capacity})
	g.event.emit("hyperspace_changed",{"reason":kind,"round_id":next.round_id})

func is_unlocked(g) -> bool:
	return int(g.profile.highestLevel)>=int(config.unlock_stage)

func eligible_level(g,route: String,level: int) -> bool:
	return is_unlocked(g) and config.routes.has(route) and level>=int(config.minimum_level) and level<=int(g.profile.highestLevel) and level<=g.db.levels.size()

func best_x1(g,route: String,level: int) -> float:
	if not eligible_level(g,route,level):return 0.0
	return float(g.profile.hyperspace.history.get(route,{}).get(str(level),0.0))

func auto_quote(best:float,crew_level:int) -> Dictionary:
	var duration_base:=float(config.auto_duration_crew_base)
	var ticket_base:=float(config.auto_ticket_crew_base)
	return {"duration":maxf(float(config.minimum_duration),best*duration_base/(duration_base+crew_level)),"ticket":float(config.ticket)*ticket_base/(ticket_base+crew_level)}

func start(g,route: String,level: int,mode: String,crew_id: String="",main_return:Dictionary={}) -> Dictionary:
	var s: Dictionary=g.profile.hyperspace
	if not eligible_level(g,route,level) or not s.active.is_empty() or mode not in ["manual","auto"] or not generation_ready():return {}
	if not main_return.is_empty() and (mode!="manual" or not main_return.get("journey") is Dictionary or not main_return.get("state") is Dictionary or not preload("res://scripts/hyperspace_main_return.gd").valid(main_return.state,main_return.journey,g.db.levels.size())):return {}
	var duration:=0.0;var ticket:=float(config.ticket)
	if mode=="auto":
		if not Bag.has_space(s.inventory,config) or float(s.energy)<float(online_config(g).energy_cap):return {}
		var best:=best_x1(g,route,level)
		if best<=0 or not Permission.crew_available(g,crew_id):return {}
		var crew_level:=Permission.crew_level(g,crew_id)
		var quote:=auto_quote(best,crew_level)
		duration=float(quote.duration);ticket=float(quote.ticket)
	if float(s.energy)<ticket:return {}
	var next: Dictionary=s.duplicate(true)
	next.energy=float(s.energy)-ticket;next.blocked=false
	next.active={"round_id":int(s.round_id),"run_id":int(s.next_run),"status":"started","mode":mode,"route":route,"level":level,"crew_id":crew_id if mode=="auto" else "","return_journey":main_return.get("journey",{}).duplicate(true),"ticket":ticket,"duration":duration,"work":0.0,"reward":{}}
	if not main_return.is_empty():next.active.return_state=main_return.state.duplicate(true)
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
	if not reward.is_empty():last_error="external_reward_forbidden";return false
	var generated:=Rewards.generate(next,online_config(g),a,Permission.planet_for_level(g.db.data,int(a.level)))
	if not generated.error.is_empty():last_error=generated.error;return false
	var frozen: Dictionary=generated.reward;next.random_state=generated.random_state
	var filter_match: bool=not frozen.drone.is_empty() and Filter.matches(frozen.drone,next.filter)
	var filtered: bool=next.filter.enabled and ((next.filter.action=="keep_matches" and not filter_match) or (next.filter.action=="clear_matches" and filter_match))
	if not frozen.drone.is_empty() and filtered:
		var rng:=R.restore(frozen.drone.forge_rng_state)
		var dismantled:=Rewards.dismantle(frozen.drone,config,rng)
		for key in dismantled.materials:frozen.materials[key]=int(frozen.materials.get(key,0))+int(dismantled.materials[key])
		frozen.hanging_rewards=dismantled.hanging_rewards;frozen.drone={}
	if not S.valid_reward(frozen,str(a.route),config):last_error="invalid_reward";return false
	if record_x1 and (a.mode!="manual" or not C.number(x1_seconds) or x1_seconds<=0):return false
	next.active.status="completed_pending";next.active.reward=frozen;next.unlocked_drones=true
	if record_x1:
		var history: Dictionary=next.history.get(a.route,{})
		var old:=float(history.get(str(int(a.level)),0.0))
		history[str(int(a.level))]=minf(old,x1_seconds) if old>0 else x1_seconds
		next.history[a.route]=history
	next.blocked=not frozen.drone.is_empty() and not Bag.has_space(next.inventory,config)
	publish(g,next,"completed_pending");return true

func claim(g,round_id: int,run_id: int) -> bool:
	var s: Dictionary=g.profile.hyperspace;var a: Dictionary=s.active
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="completed_pending":return false
	if not a.reward.drone.is_empty() and not Bag.has_space(s.inventory,config):s.blocked=true;return false
	var next: Dictionary=s.duplicate(true)
	if not a.reward.drone.is_empty():
		if not Bag.insert(next.inventory,a.reward.drone,config):return false
		if a.reward.drone.legendary and not next.legendary_seen.has(a.reward.drone.legendary_effect.effect_id):next.legendary_seen.append(a.reward.drone.legendary_effect.effect_id)
	for key in a.reward.materials:
		var amount:=int(next.materials[key])+int(a.reward.materials[key])
		if not C.integer(amount):return false
		next.materials[key]=amount
	next.ultimate_cores+=int(a.reward.ultimate_cores)
	if not Rewards.credit_modules(next,config,a.reward.hanging_rewards):return false
	next.settled_run=run_id;next.active={};next.blocked=not Bag.has_space(next.inventory,config)
	publish(g,next,"claimed");return true

func set_auto(g,enabled: bool,route: String,level: int,crew_id: String) -> bool:
	var active: Dictionary=g.profile.hyperspace.active
	if enabled and not active.is_empty() and active.mode=="auto" and active.crew_id!=crew_id:return false
	if enabled and (not eligible_level(g,route,level) or best_x1(g,route,level)<=0 or not Permission.crew_available(g,crew_id)):return false
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	next.pending_time=0.0
	next.auto={"enabled":enabled,"route":route if enabled else "","level":level if enabled else 0,"crew_id":crew_id if enabled else ""}
	scheduler.reset();publish(g,next,"auto_changed");return true

func auto_eligible(g) -> bool:
	var auto: Dictionary=g.profile.hyperspace.auto
	return auto.enabled and generation_ready() and best_x1(g,str(auto.route),int(auto.level))>0 and Permission.crew_available(g,str(auto.crew_id))

func start_auto(g) -> bool:
	var auto: Dictionary=g.profile.hyperspace.auto
	return not start(g,str(auto.route),int(auto.level),"auto",str(auto.crew_id)).is_empty()

func complete_auto(g) -> bool:
	var a: Dictionary=g.profile.hyperspace.active
	if a.is_empty() or a.mode!="auto" or float(a.work)<float(a.duration):return false
	return complete(g,int(a.round_id),int(a.run_id),true)

func advance(g,dt: float) -> void:
	scheduler.advance(self,g,dt)

func equipment_constraints(g,ids: Array,bag: Dictionary={},ordinary: Variant=null) -> bool:
	if bag.is_empty():bag=g.profile.hyperspace.inventory
	var count:=0;var higgs:=false
	for entry in (g.weapon_entries() if ordinary==null else ordinary):
		if entry.key=="cannon":count+=1
	for id in ids:
		if not bag.drones.has(id):return false
		var d: Dictionary=bag.drones[id]
		if d.weapon=="cannon":count+=1
		if d.legendary and d.legendary_effect.get("effect_id")=="higgs_cannon":higgs=true
	return not higgs or count<=int(config.legendary_effects.higgs_cannon.constants.maximum_cannon_sources)

func set_equipped(g,ids: Array,hull_capacity: int=-1) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	var actual:=Permission.hull_capacity(g,config)
	if hull_capacity!=-1 and hull_capacity!=actual:return false
	if not Bag.equipment_valid(next.inventory,ids,actual,config) or not equipment_constraints(g,ids,next.inventory):return false
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
	if not next.inventory.sealed.has(id):return false
	var actual:=Permission.planet_stage(g.db.data,str(next.inventory.drones[id].planet_id))
	if actual<1 or int(next.inventory.sealed[id])!=actual or int(g.profile.highestLevel)<actual:return false
	next.inventory.sealed.erase(id);next.inventory.generation+=1
	publish(g,next,"unsealed");return true

func reforge_state(g,keep_ids: Array,claim_stages: Dictionary) -> Dictionary:
	var old: Dictionary=g.profile.hyperspace
	var actual:=Permission.claim_stages(old,keep_ids,g.db.data)
	if not keep_ids.is_empty() and actual.is_empty():return {}
	if not claim_stages.is_empty() and claim_stages!=actual:return {}
	var bag:=Bag.reforge(old.inventory,keep_ids,actual,config)
	if bag.is_empty():return {}
	var next:=fresh();next.round_id=int(old.round_id)+1;next.inventory=bag
	next.history=old.history.duplicate(true);next.unlocked_drones=old.unlocked_drones
	return next

func generation_ready() -> bool:
	return config.policies.core_reward in ["exclusive","additional"]

func forge(g,request: Dictionary) -> Dictionary:
	var s: Dictionary=g.profile.hyperspace
	if request.get("round_id")!=s.round_id:return Forge.error("stale_round")
	if not request.get("args",{}) is Dictionary:return Forge.error("invalid_arguments")
	var fingerprint:=JSON.stringify({"operation":request.get("operation"),"drone_id":request.get("drone_id"),"args":request.get("args",{}),"expected_revision":request.get("expected_revision")},"",true,true)
	if not s.last_command.is_empty() and request.get("command_seq")==s.last_command.seq:
		return Forge.restore_result(s.last_command.result_json) if fingerprint==s.last_command.fingerprint else Forge.error("command_conflict")
	if request.get("command_seq")!=s.command_seq:return Forge.error("stale_command")
	var next: Dictionary=s.duplicate(true)
	var result:=Forge.plan(next,config,request,g)
	if not result.error.is_empty():return result
	next.last_command={"seq":int(s.command_seq),"fingerprint":fingerprint,"result_json":JSON.stringify(result,"",true,true)};next.command_seq+=1
	if not S.valid(next,config,g.db.levels.size()):return Forge.error("invalid_result")
	if not equipment_constraints(g,next.inventory.equipped,next.inventory):return Forge.error("equipment_constraint")
	publish(g,next,"forge_"+str(request.operation));return result

func preview_forge(g,request: Dictionary) -> Dictionary:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	var result:=Forge.plan(next,config,request,g)
	return {"error":result.error,"cost":result.get("cost",{}),"draws":result.get("draws",0),"revision":g.profile.hyperspace.inventory.drones.get(request.get("drone_id"),{}).get("forge_revision",0)}

func attach_hangings(g,id: String,keys: Array) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if not next.inventory.drones.has(id) or next.inventory.sealed.has(id):return false
	var d: Dictionary=next.inventory.drones[id]
	if d.ultimate:return false
	for key in keys:
		if not config.hanging_modules.has(key) or not next.hanging_modules[key].unlocked or int(g.profile.highestLevel)<int(config.hanging_modules[key].unlock_stage):return false
	d.hangings=keys.duplicate()
	if not Bag.valid_drone(d,config):return false
	next.inventory.generation+=1;publish(g,next,"hangings_changed");return true

func set_filter(g,filter: Dictionary) -> bool:
	if not Filter.valid(filter,config):return false
	var next: Dictionary=g.profile.hyperspace.duplicate(true);next.filter=filter.duplicate(true)
	publish(g,next,"filter_changed");return true

func export_filter(g) -> String:
	return Filter.export_string(g.profile.hyperspace.filter,config)

func import_filter(g,value: String) -> bool:
	var filter:=Filter.import_string(value,config)
	return not filter.is_empty() and set_filter(g,filter)

func set_legendary_collection(g,ids: Array) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	var seen: Dictionary={}
	for id in ids:
		if not next.legendary_seen.has(id) or seen.has(id):return false
		seen[id]=true
	next.legendary_collection=ids.duplicate();publish(g,next,"legendary_collection_changed");return true

func apply_preset(g,index: int) -> bool:
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	if index<0 or index>=next.inventory.presets.size():return false
	var preset: Dictionary=next.inventory.presets[index]
	var ids: Array=preset.drone_ids.filter(func(id):return next.inventory.drones.has(id) and not next.inventory.sealed.has(id) and next.inventory.warehouse.has(id))
	if not Bag.equipment_valid(next.inventory,ids,Permission.hull_capacity(g,config),config) or not equipment_constraints(g,ids,next.inventory):return false
	for id in ids:
		var d: Dictionary=next.inventory.drones[id]
		if not d.ultimate:d.hangings=preset.hanging_loadouts.get(id,d.hangings).duplicate()
		for key in d.hangings:
			if not next.hanging_modules[key].unlocked or int(g.profile.highestLevel)<int(config.hanging_modules[key].unlock_stage):return false
		if not Bag.valid_drone(d,config):return false
	next.inventory.equipped=ids;next.inventory.generation+=1
	publish(g,next,"preset_applied");return true

func fit_hull(g) -> void:
	var maximum:=Permission.hull_capacity(g,config)
	if g.profile.hyperspace.inventory.equipped.size()<=maximum:return
	var next: Dictionary=g.profile.hyperspace.duplicate(true)
	next.inventory.equipped=next.inventory.equipped.slice(0,maximum);next.inventory.generation+=1
	publish(g,next,"hull_capacity_changed")
