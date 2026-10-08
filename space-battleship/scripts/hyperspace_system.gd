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
	g.profile.hyperspace=S.migrate(raw)
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

func current_layer(g,route:String)->int:
	var current:=0
	for level in g.profile.hyperspace.history.get(route,{}):
		if float(g.profile.hyperspace.history[route][level])>0:current=maxi(current,int(level))
	return current

func eligible_level(g,route:String,level:int)->bool:
	return is_unlocked(g) and config.routes.has(route) and level==current_layer(g,route)+1 and level<=g.db.levels.size()

func best_x1(g,route:String,level:int)->float:
	return float(g.profile.hyperspace.history.get(route,{}).get(str(level),0.0)) if config.routes.has(route) and level>0 else 0.0

func configured_crew(g,route:String)->String:
	var auto:Dictionary=g.profile.hyperspace.auto
	return str(auto.crew_id) if str(auto.route)==route else ""

func luck_snapshot(g,route:String)->Dictionary:
	var id:=configured_crew(g,route)
	var permanent:=maxf(0.0,float(g.planet_buffs.totals(g).get("hyperspace_luck",0.0)))
	var crew_luck:=0.0
	if not id.is_empty() and g.crew.has_method("hyperspace_luck"):crew_luck=maxf(0.0,float(g.crew.hyperspace_luck(g,id)))
	return {"crew_snapshot":id,"permanent_luck":permanent,"crew_luck":crew_luck,"luck":permanent+crew_luck}

func idle_duration(g,best:float,crew_id:String)->float:
	var efficiency:=1.0
	if not crew_id.is_empty():
		efficiency=float(g.crew.hyperspace_efficiency(g,crew_id)) if g.crew.has_method("hyperspace_efficiency") else (20.0+Permission.crew_level(g,crew_id))/20.0
	return best/maxf(1.0,efficiency)

func auto_quote(best:float,crew_level:int)->Dictionary:
	var base:=float(config.auto_duration_crew_base)
	return {"duration":best*base/(base+crew_level),"ticket":0.0}

func receipt_slot(s:Dictionary,round_id:int,run_id:int)->String:
	for slot in ["active","idle"]:
		var a:Dictionary=s.get(slot,{})
		if not a.is_empty() and int(a.round_id)==round_id and int(a.run_id)==run_id:return slot
	return ""

func start(g,route:String,level:int,mode:String,crew_id:String="",main_return:Dictionary={})->Dictionary:
	var s:Dictionary=g.profile.hyperspace
	var slot:="active" if mode=="manual" else "idle"
	if mode not in ["manual","idle","auto"] or not is_unlocked(g) or not config.routes.has(route) or not s[slot].is_empty() or not generation_ready():return {}
	var duration:=0.0
	if mode=="manual":
		if not eligible_level(g,route,level):return {}
	elif level!=current_layer(g,route) or best_x1(g,route,level)<=0 or not Bag.has_space(s.inventory,config):return {}
	if not main_return.is_empty() and (mode!="manual" or not main_return.get("journey") is Dictionary or not main_return.get("state") is Dictionary or not preload("res://scripts/hyperspace_main_return.gd").valid(main_return.state,main_return.journey,g.db.levels.size())):return {}
	if mode=="auto" and not Permission.crew_available(g,crew_id):return {}
	if mode!="manual":duration=idle_duration(g,best_x1(g,route,level),crew_id if mode=="auto" else "")
	if mode!="manual" and (not is_finite(duration) or duration<=0):return {}
	var next:Dictionary=s.duplicate(true)
	var receipt:Dictionary={"round_id":int(s.round_id),"run_id":int(s.next_run),"status":"started","mode":mode,"route":route,"level":level,"crew_id":crew_id if mode=="auto" else "","return_journey":main_return.get("journey",{}).duplicate(true),"ticket":0.0,"duration":duration,"work":0.0,"reward":{}}
	receipt.merge(luck_snapshot(g,route))
	var private_rng:=RandomNumberGenerator.new()
	private_rng.seed=(str(s.random_state)+"|"+route+"|"+str(s.round_id)+"|"+str(s.next_run)).hash()
	receipt.luck_state=str(private_rng.state)
	if not main_return.is_empty():receipt.return_state=main_return.state.duplicate(true)
	next[slot]=receipt;next.next_run+=1;next.blocked=false;publish(g,next,"started")
	return receipt.duplicate(true)

func complete(g,round_id: int,run_id: int,success: bool,reward: Dictionary={},x1_seconds: float=0.0,record_x1: bool=false) -> bool:
	var s: Dictionary=g.profile.hyperspace
	var slot:=receipt_slot(s,round_id,run_id)
	if slot.is_empty():return false
	var a: Dictionary=s[slot]
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="started":return false
	var next: Dictionary=s.duplicate(true)
	if not success:
		next.energy=float(next.energy)+float(a.ticket);next.settled_run=maxi(int(next.settled_run),run_id);next[slot]={};next.blocked=false;next.pending_time=0.0 if slot=="idle" else next.pending_time
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
	next[slot].status="completed_pending";next[slot].reward=frozen;next.unlocked_drones=true
	if record_x1:
		var history: Dictionary=next.history.get(a.route,{})
		var old:=float(history.get(str(int(a.level)),0.0))
		history[str(int(a.level))]=minf(old,x1_seconds) if old>0 else x1_seconds
		next.history[a.route]=history
	next.blocked=not frozen.drone.is_empty() and not Bag.has_space(next.inventory,config)
	publish(g,next,"completed_pending");return true

func claim(g,round_id: int,run_id: int) -> bool:
	var s: Dictionary=g.profile.hyperspace;var slot:=receipt_slot(s,round_id,run_id)
	if slot.is_empty():return false
	var a: Dictionary=s[slot]
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
	next.settled_run=maxi(int(next.settled_run),run_id);next[slot]={};next.blocked=not Bag.has_space(next.inventory,config)
	publish(g,next,"claimed");return true

func start_idle(g,route:String)->bool:
	if g.profile.hyperspace.auto.enabled:return false
	return not start(g,route,current_layer(g,route),"idle").is_empty()

func stop_idle(g,route:String)->bool:
	var s:Dictionary=g.profile.hyperspace
	var a:Dictionary=s.idle
	if not a.is_empty() and str(a.route)!=route:return false
	if not a.is_empty() and a.status=="completed_pending":return false
	var next:Dictionary=s.duplicate(true)
	if not a.is_empty():next.settled_run=maxi(int(next.settled_run),int(a.run_id));next.idle={}
	if str(next.auto.route)==route:next.auto.enabled=false
	next.pending_time=0.0;publish(g,next,"idle_stopped");return true

func set_auto(g,enabled:bool,route:String,_level:int,crew_id:String)->bool:
	var s:Dictionary=g.profile.hyperspace
	if not config.routes.has(route):return false
	if enabled and (current_layer(g,route)<1 or not Permission.crew_available(g,crew_id) or (not s.idle.is_empty() and (s.idle.mode!="auto" or s.idle.route!=route or s.idle.crew_id!=crew_id))):return false
	if not enabled and not s.idle.is_empty() and s.idle.route==route and s.idle.status=="completed_pending":return false
	var next:Dictionary=s.duplicate(true)
	next.pending_time=0.0
	next.auto={"enabled":enabled,"route":route,"level":current_layer(g,route),"crew_id":crew_id if not crew_id.is_empty() else configured_crew(g,route)}
	if not enabled and not next.idle.is_empty() and next.idle.route==route:
		next.settled_run=maxi(int(next.settled_run),int(next.idle.run_id));next.idle={}
	publish(g,next,"auto_changed");return true

func auto_eligible(g)->bool:
	var auto:Dictionary=g.profile.hyperspace.auto
	return auto.enabled and generation_ready() and best_x1(g,str(auto.route),current_layer(g,str(auto.route)))>0 and Permission.crew_available(g,str(auto.crew_id))

func start_auto(g)->bool:
	var auto:Dictionary=g.profile.hyperspace.auto
	return not start(g,str(auto.route),current_layer(g,str(auto.route)),"auto",str(auto.crew_id)).is_empty()

func complete_auto(g)->bool:
	var a:Dictionary=g.profile.hyperspace.idle
	if a.is_empty() or float(a.work)<float(a.duration):return false
	return complete(g,int(a.round_id),int(a.run_id),true)

func route_view(g,route:String,crew_id:String="")->Dictionary:
	var current:=current_layer(g,route);var best:=best_x1(g,route,current)
	var s:Dictionary=g.profile.hyperspace;var idle:Dictionary=s.idle;var active:Dictionary=s.active
	var receipt:Dictionary=active if not active.is_empty() and active.route==route else (idle if not idle.is_empty() and idle.route==route else {})
	var reasons:Dictionary={"idle_once":"","crew_idle":"","challenge":"","stop":"","exit":""}
	if not is_unlocked(g) or not config.routes.has(route):
		for key in reasons:reasons[key]="locked"
	else:
		if current==0:reasons.idle_once="no_cleared_layer";reasons.crew_idle="no_cleared_layer"
		if not idle.is_empty() or s.auto.enabled:reasons.idle_once="background_busy"
		if not Bag.has_space(s.inventory,config):reasons.idle_once="inventory_full";reasons.crew_idle="inventory_full"
		if crew_id.is_empty():crew_id=configured_crew(g,route)
		if crew_id.is_empty() or not Permission.crew_available(g,crew_id):reasons.crew_idle="crew_unavailable"
		if not idle.is_empty() and (idle.mode!="auto" or idle.route!=route or idle.crew_id!=crew_id):reasons.crew_idle="background_busy"
		if not active.is_empty():reasons.challenge="challenge_busy"
		if current>=g.db.levels.size():reasons.challenge="max_layer"
		if not g.manual_hyperspace.production_accepted:reasons.challenge="unavailable"
		if idle.is_empty() and not (s.auto.enabled and s.auto.route==route):reasons.stop="no_background"
		elif not idle.is_empty() and (idle.route!=route or idle.status=="completed_pending"):reasons.stop="pending_reward" if idle.route==route else "other_route"
		if not g.manual_hyperspace.active or active.is_empty() or active.route!=route:reasons.exit="no_challenge"
	var luck:=luck_snapshot(g,route)
	return {"route":route,"current_layer":current,"next_layer":current+1,"best_time":best,"task_mode":"none" if receipt.is_empty() else ("challenge" if receipt.mode=="manual" else "crew_idle" if receipt.mode=="auto" else "manual_idle"),"work":float(receipt.get("work",0.0)),"duration":float(receipt.get("duration",0.0)),"round_id":int(receipt.get("round_id",s.round_id)),"run_id":int(receipt.get("run_id",0)),"status":str(receipt.get("status","")),"background":idle.duplicate(true) if idle.get("route","")==route else {},"challenge":active.duplicate(true) if active.get("route","")==route else {},"reasons":reasons,"total_luck":luck.luck,"crew_luck":luck.crew_luck,"permanent_luck":luck.permanent_luck,"idle_duration":best,"crew_duration":idle_duration(g,best,crew_id),"crew_id":configured_crew(g,route)}

func advance(g,dt:float)->void:
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

## Select an explicit replacement on multi-slot hulls; single-slot hulls have one unambiguous target.
## Build and validate the final loadout before publishing so rejected changes never unequip anything.
func equip_drone(g,id: String,replace_id: String="") -> Dictionary:
	var bag: Dictionary=g.profile.hyperspace.inventory
	var ids: Array=bag.equipped.duplicate()
	var capacity:=mini(Permission.hull_capacity(g,config),int(config.maximum_equipped))
	var result: Dictionary={"ok":false,"reason":"","changed":false,"capacity":capacity,"equipped":ids.duplicate(),"replaced_id":""}
	if not bag.drones.has(id):result.reason="unknown_drone";return result
	if bag.sealed.has(id):result.reason="sealed";return result
	if not bag.warehouse.has(id):result.reason="not_in_warehouse";return result
	if ids.has(id):result.ok=true;result.reason="already_equipped";return result
	if capacity<=0:result.reason="no_slots";return result
	var target:=replace_id
	if not target.is_empty():
		if not ids.has(target):result.reason="replacement_not_equipped";return result
	elif ids.size()>=capacity:
		if capacity==1 and ids.size()==1:target=str(ids[0])
		else:result.reason="select_replacement";return result
	if target.is_empty():ids.append(id)
	else:ids[ids.find(target)]=id
	if ids.size()>capacity:result.reason="capacity_exceeded";return result
	var legendary:=0;var ultimate:=0
	for equipped_id in ids:
		legendary+=int(bag.drones[equipped_id].legendary);ultimate+=int(bag.drones[equipped_id].ultimate)
	if legendary>int(config.maximum_legendary):result.reason="legendary_limit";return result
	if ultimate>int(config.maximum_ultimate):result.reason="ultimate_limit";return result
	if not equipment_constraints(g,ids,bag):result.reason="weapon_constraint";return result
	if not set_equipped(g,ids):result.reason="invalid_loadout";return result
	result.ok=true;result.changed=true;result.reason="equipped";result.equipped=ids;result.replaced_id=target
	return result

func unequip_drone(g,id: String) -> Dictionary:
	var ids: Array=g.profile.hyperspace.inventory.equipped.duplicate()
	var result: Dictionary={"ok":true,"reason":"already_unequipped","changed":false,"capacity":mini(Permission.hull_capacity(g,config),int(config.maximum_equipped)),"equipped":ids.duplicate(),"replaced_id":""}
	if not ids.has(id):return result
	ids.erase(id)
	if not set_equipped(g,ids):result.ok=false;result.reason="invalid_loadout";return result
	result.changed=true;result.reason="unequipped";result.equipped=ids
	return result

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
