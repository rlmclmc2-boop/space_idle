extends RefCounted
const ReactorInt = preload("res://scripts/reactor_integer.gd")
## Domain commands prepare their result and exact wallet before a joint commit.
const Economy=preload("res://scripts/economy_state.gd")
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const R=preload("res://scripts/hyperspace_random.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Filter=preload("res://scripts/hyperspace_filter.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var config: Dictionary=C.load_config()
const Clock=preload("res://scripts/hyperspace_scheduler.gd")
var revision:=0
var contribution_revision:=0
var _contribution_inputs:Array=[]
var _state:Dictionary={}
var _receipt:Dictionary={}
var _view:Dictionary={}
var _online_inputs:Array=[]
var _online_config:Dictionary={}
var state:Dictionary:
	get:return view()
var last_error:=""

func configure(c: Dictionary) -> bool:
	if not C.valid(c):return false
	config=c.duplicate(true);freeze(config);_online_inputs=[];revision+=1;contribution_revision+=1;return true

func online_config(g) -> Dictionary:
	var supplied:bool=g.profile.cleared.has(int(config.get("late_supply_unlock_stage",60)))
	var multiplier:=1.0 if _state.inventory.equipped.is_empty() else 1.0+float(g.hyperspace_totals().hangings.get("hyperspace_charge",0))
	var inputs:Array=[supplied,multiplier]
	if inputs!=_online_inputs:
		_online_inputs=inputs
		_online_config=config.duplicate()
		_online_config.energy_rate=float(config.energy_rate)*(float(config.get("late_energy_rate_multiplier",1.0)) if supplied else 1.0)
		_online_config.exploration_material_multiplier=multiplier
		_online_config.material_reward_multiplier=(float(config.get("late_material_reward_multiplier",1)) if supplied else 1.0)*multiplier
		freeze(_online_config)
	return ramp_config(g,_online_config,supplied)

func ramp_config(g,c:Dictionary,supplied:bool)->Dictionary:
	if not supplied or not config.has("late_supply_ramp_seconds"):return c
	var elapsed:float=float(_state.get("late_supply_work",0.0))
	var duration:float=float(config.late_supply_ramp_seconds)
	var progress:float=clampf(elapsed/duration,0.0,1.0)
	var next:Dictionary=c.duplicate()
	next.late_supply_elapsed=elapsed
	next.late_supply_base_rate=float(c.energy_rate)/float(config.late_energy_rate_multiplier)
	next.energy_rate=float(next.late_supply_base_rate)*lerpf(1.0,float(config.late_energy_rate_multiplier),progress)
	next.material_reward_multiplier=float(c.get("exploration_material_multiplier",1.0))*lerpf(1.0,float(config.late_material_reward_multiplier),progress)
	return next

func fresh() -> Dictionary:
	return S.fresh(config)

func _init()->void:
	freeze(config)
	_install(fresh(),fresh_receipt())
static func fresh_receipt()->Dictionary:
	return {"round":0,"run":0,"drone_id":"","unread":false}
static func freeze(value:Variant)->void:
	if value is Dictionary:
		for child in value.values():freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value:freeze(child)
		value.make_read_only()
func view()->Dictionary:
	if _view.is_empty():
		_view=_state.duplicate()
		# Clock updates only replace these two small receipts. Inventory/history
		# remain immutable shared views, independent of online frame frequency.
		for slot in ["active","idle"]:_view[slot]=_state[slot].duplicate(true);freeze(_view[slot])
		_view.make_read_only()
	return _view
func receipt_marker()->Dictionary:return _receipt
func save_data()->Dictionary:
	return {"hyperspace":_state.duplicate(true),"hyperspaceReceipt":_receipt.duplicate(true)}
func contribution_inputs(next:Dictionary)->Array:
	var selected:Array=[]
	for id in next.inventory.equipped:
		if not next.inventory.sealed.has(id):selected.append(next.inventory.drones[id])
	# Inventory is immutable after installation; keep only equipped rows and module growth.
	return [selected,next.hanging_modules]
func _install(next:Dictionary,marker:Dictionary)->void:
	var inputs:=contribution_inputs(next)
	if inputs!=_contribution_inputs:contribution_revision+=1;_contribution_inputs=inputs
	_state=next.duplicate()
	for key in _state:
		if key in ["active","idle"]:_state[key]=_state[key].duplicate(true)
		else:freeze(_state[key])
	_receipt=marker.duplicate(true);freeze(_receipt)
	changed();last_error=""
func changed()->void:
	revision+=1;_view={}
func install_snapshot(raw:Dictionary,db)->bool:
	if not raw.get("hyperspace") is Dictionary or not S.valid(raw.hyperspace,config,db.levels.size()) or not S.valid_marker(raw.get("hyperspaceReceipt")):return false
	_install(raw.hyperspace.duplicate(true),raw.hyperspaceReceipt)
	return true
func acknowledge_receipt(round_id:int,run_id:int)->bool:
	if _receipt.round!=round_id or _receipt.run!=run_id or not _receipt.unread:return false
	_receipt=_receipt.duplicate();_receipt.unread=false;freeze(_receipt);changed();return true
func advance_manual(dt:float)->void:
	if not is_finite(dt) or dt<=0 or _state.active.get("status","")!="started":return
	_state.active.work+=dt;changed()
func add_online_time(dt:float)->void:
	assert(is_finite(dt) and dt>0)
	_state.pending_time+=dt;changed()
func advance_online_work(c:Dictionary,dt:float,idle_work:bool=false,blocked:bool=false)->void:
	assert(is_finite(dt) and dt>=0 and dt<=float(_state.pending_time)+0.000000001)
	if idle_work:_state.idle.work=minf(float(_state.idle.duration),float(_state.idle.work)+dt)
	Clock.charge(_state,c,dt)
	_state.pending_time=maxf(0.0,float(_state.pending_time)-dt);_state.blocked=blocked
	changed()

func snapshot(g) -> Dictionary:
	var result: Dictionary=_state.duplicate(true)
	result.merge(g.economy.material_wallet())
	result.hull_capacity=Permission.hull_capacity(g,config)
	result.auto.crew_level=Permission.crew_level(g,str(result.auto.crew_id))
	result.next_command={"round_id":result.round_id,"command_seq":result.command_seq}
	result.combat={"disabled_drones":g.drone_combat.disabled.duplicate(),"rebuild_stacks":g.drone_combat.rebuild_stacks}
	result.manual_ready=g.manual_hyperspace.production_accepted
	result.manual_error=g.manual_hyperspace.last_error
	return result

func dependencies(g)->Array:
	return [g.equipment.revision,g.crew.revision,g.planets.revision,int(g.profile.highestLevel),g.profile.cleared.hash()]
func proposal(g,next:Dictionary,kind:String,wallet:Dictionary={},wallet_revision:int=-1,result:Variant=true)->Dictionary:
	freeze(next);freeze(wallet)
	return {"revision":revision,"dependencies":dependencies(g),"next":next,"kind":kind,"wallet":wallet,"wallet_revision":wallet_revision,"result":result,"marker":_receipt}
func proposal_current(g,plan:Dictionary)->bool:
	return plan.has("next") and plan.revision==revision and plan.dependencies==dependencies(g)
func commit(plan:Dictionary)->void:
	assert(plan.revision==revision)
	_install(plan.next,plan.marker)

func is_unlocked(g) -> bool:
	return int(g.profile.highestLevel)>=int(config.unlock_stage)

func current_layer(g,route:String)->int:
	var current:=0
	for level in _state.history.get(route,{}):
		if float(_state.history[route][level])>0:current=maxi(current,int(level))
	return current

func eligible_level(g,route:String,level:int)->bool:
	return is_unlocked(g) and config.routes.has(route) and level==current_layer(g,route)+1 and level<=g.db.levels.size()

func best_x1(g,route:String,level:int)->float:
	return float(_state.history.get(route,{}).get(str(level),0.0)) if config.routes.has(route) and level>0 else 0.0

func configured_crew(g,route:String)->String:
	var auto:Dictionary=_state.auto
	return str(auto.crew_id) if str(auto.route)==route else ""

func luck_snapshot(g,route:String,preview_crew_id:String="")->Dictionary:
	var id:=preview_crew_id if not preview_crew_id.is_empty() else configured_crew(g,route)
	var permanent:=maxf(0.0,float(g.planet_buffs.totals(g).get("hyperspace_luck",0.0)))
	var crew_luck:=0.0
	if not id.is_empty() and g.crew.has_method("hyperspace_luck"):crew_luck=maxf(0.0,float(g.crew.hyperspace_luck(g,id)))
	return {"crew_snapshot":id,"permanent_luck":permanent,"crew_luck":crew_luck,"luck":permanent+crew_luck}

func idle_duration(g,best:float,crew_id:String)->float:
	var efficiency:=1.0
	if not crew_id.is_empty():
		efficiency=float(g.crew.hyperspace_efficiency(g,crew_id)) if g.crew.has_method("hyperspace_efficiency") else (20.0+Permission.crew_level(g,crew_id))/20.0
	return best/maxf(1.0,efficiency)

func auto_quote(best:float,crew_level:int,g=null)->Dictionary:
	var base:=20.0 if g==null else float(g.db.data.crew_config.hyperspace_duration_k.value)
	return {"duration":best*base/(base+crew_level),"ticket":0.0}

func receipt_slot(s:Dictionary,round_id:int,run_id:int)->String:
	for slot in ["active","idle"]:
		var a:Dictionary=s.get(slot,{})
		if not a.is_empty() and int(a.round_id)==round_id and int(a.run_id)==run_id:return slot
	return ""

func prepare_start(g,route:String,level:int,mode:String,crew_id:String="",return_target:Dictionary={})->Dictionary:
	var s:Dictionary=_state
	var slot:="active" if mode=="manual" else "idle"
	if mode not in ["manual","idle","auto"] or not is_unlocked(g) or not config.routes.has(route) or not s[slot].is_empty() or not generation_ready():return {}
	var duration:=0.0
	if mode=="manual":
		if not eligible_level(g,route,level):return {}
	elif level!=current_layer(g,route) or best_x1(g,route,level)<=0 or not Bag.has_space(s.inventory,config):return {}
	if mode=="manual":
		if return_target.is_empty():return_target=preload("res://scripts/hyperspace_return_target.gd").destination(g)
		if not preload("res://scripts/hyperspace_return_target.gd").binding_valid(return_target,g.profile,g.db.data):return {}
	elif not return_target.is_empty():return {}
	if mode=="auto" and not Permission.crew_available(g,crew_id):return {}
	if mode!="manual":duration=idle_duration(g,best_x1(g,route,level),crew_id if mode=="auto" else "")
	if mode!="manual" and (not is_finite(duration) or duration<=0):return {}
	var next:Dictionary=s.duplicate(true)
	var receipt:Dictionary={"round_id":int(s.round_id),"run_id":int(s.next_run),"status":"started","mode":mode,"route":route,"level":level,"crew_id":crew_id if mode=="auto" else "","return_target":return_target.duplicate(true),"ticket":0.0,"duration":duration,"work":0.0,"reward":{}}
	receipt.merge(luck_snapshot(g,route))
	var private_rng:=RandomNumberGenerator.new()
	private_rng.seed=(str(s.random_state)+"|"+route+"|"+str(s.round_id)+"|"+str(s.next_run)).hash()
	receipt.luck_state=str(private_rng.state)
	next[slot]=receipt;next.next_run+=1;next.blocked=false
	return proposal(g,next,"started",{},-1,receipt.duplicate(true))

func prepare_complete(g,round_id: int,run_id: int,success: bool,reward: Dictionary={},x1_seconds: float=0.0,record_x1: bool=false)->Dictionary:
	var s: Dictionary=_state
	var slot:=receipt_slot(s,round_id,run_id)
	if slot.is_empty():return {}
	var a: Dictionary=s[slot]
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="started":return {}
	var next: Dictionary=s.duplicate(true)
	if not success:
		next.energy=float(next.energy)+float(a.ticket);next.settled_run=maxi(int(next.settled_run),run_id);next[slot]={};next.blocked=false;next.pending_time=0.0 if slot=="idle" else next.pending_time
		return proposal(g,next,"refunded")
	if not reward.is_empty():last_error="external_reward_forbidden";return {}
	var generated:=Rewards.generate(next,online_config(g),a,Permission.planet_for_level(g.db.data,int(a.level)))
	if not generated.error.is_empty():last_error=generated.error;return {}
	var frozen: Dictionary=generated.reward;next.random_state=generated.random_state
	var filter_match: bool=not frozen.drone.is_empty() and Filter.matches(frozen.drone,next.filter)
	var filtered: bool=next.filter.enabled and ((next.filter.action=="keep_matches" and not filter_match) or (next.filter.action=="clear_matches" and filter_match))
	if not frozen.drone.is_empty() and filtered:
		var rng:=R.restore(frozen.drone.forge_rng_state)
		var dismantled:=Rewards.dismantle(frozen.drone,config,rng)
		for key in dismantled.materials:frozen.materials[key]=int(frozen.materials.get(key,0))+int(dismantled.materials[key])
		frozen.hanging_rewards=dismantled.hanging_rewards;frozen.drone={}
	if not S.valid_reward(frozen,str(a.route),config):last_error="invalid_reward";return {}
	if record_x1 and (a.mode!="manual" or not C.number(x1_seconds) or x1_seconds<=0):return {}
	next[slot].status="completed_pending";next[slot].reward=frozen;next[slot].return_target={};next.unlocked_drones=true
	if record_x1:
		var history: Dictionary=next.history.get(a.route,{})
		var old:=float(history.get(str(int(a.level)),0.0))
		history[str(int(a.level))]=minf(old,x1_seconds) if old>0 else x1_seconds
		next.history[a.route]=history
	next.blocked=not frozen.drone.is_empty() and not Bag.has_space(next.inventory,config)
	return proposal(g,next,"completed_pending")

func prepare_claim(g,round_id: int,run_id: int)->Dictionary:
	var s: Dictionary=_state;var slot:=receipt_slot(s,round_id,run_id)
	if slot.is_empty():return {}
	var a: Dictionary=s[slot]
	if a.is_empty() or a.round_id!=round_id or a.run_id!=run_id or a.status!="completed_pending":return {}
	if not a.reward.drone.is_empty() and not Bag.has_space(s.inventory,config):return {}
	var next: Dictionary=s.duplicate(true)
	if not a.reward.drone.is_empty():
		if not Bag.insert(next.inventory,a.reward.drone,config):return {}
		if a.reward.drone.legendary and not next.legendary_seen.has(a.reward.drone.legendary_effect.effect_id):next.legendary_seen.append(a.reward.drone.legendary_effect.effect_id)
	var wallet: Dictionary=g.economy.material_wallet()
	var wallet_revision: int=g.economy.material_revision
	var gains: Dictionary=a.reward.materials.duplicate()
	gains.ultimate_cores=int(a.reward.ultimate_cores)
	if not Economy.material_credit(wallet,gains):return {}
	if not Rewards.credit_modules(next,config,a.reward.hanging_rewards):return {}
	next.settled_run=maxi(int(next.settled_run),run_id);next[slot]={};next.blocked=not Bag.has_space(next.inventory,config)
	var plan:=proposal(g,next,"claimed",wallet,wallet_revision)
	plan.marker={"round":int(a.round_id),"run":int(a.run_id),"drone_id":str(a.reward.drone.get("id","")),"unread":true}
	plan.reward=a.reward.duplicate(true)
	return plan

func prepare_start_idle(g,route:String)->Dictionary:
	if _state.auto.enabled:return {}
	return prepare_start(g,route,current_layer(g,route),"idle")

func prepare_stop_idle(g,route:String)->Dictionary:
	var s:Dictionary=_state
	var a:Dictionary=s.idle
	if not a.is_empty() and str(a.route)!=route:return {}
	if not a.is_empty() and a.status=="completed_pending":return {}
	var next:Dictionary=s.duplicate(true)
	if not a.is_empty():next.settled_run=maxi(int(next.settled_run),int(a.run_id));next.idle={}
	if str(next.auto.route)==route:next.auto.enabled=false
	next.pending_time=0.0;return proposal(g,next,"idle_stopped")

func prepare_set_auto(g,enabled:bool,route:String,_level:int,crew_id:String)->Dictionary:
	var s:Dictionary=_state
	if not config.routes.has(route):return {}
	if enabled and (current_layer(g,route)<1 or not Permission.crew_available(g,crew_id) or (not s.idle.is_empty() and (s.idle.mode!="auto" or s.idle.route!=route or s.idle.crew_id!=crew_id))):return {}
	if not enabled and not s.idle.is_empty() and s.idle.route==route and s.idle.status=="completed_pending":return {}
	var next:Dictionary=s.duplicate(true)
	next.pending_time=0.0
	next.auto={"enabled":enabled,"route":route,"level":current_layer(g,route),"crew_id":crew_id if not crew_id.is_empty() else configured_crew(g,route)}
	if not enabled and not next.idle.is_empty() and next.idle.route==route:
		next.settled_run=maxi(int(next.settled_run),int(next.idle.run_id));next.idle={}
	return proposal(g,next,"auto_changed")

func auto_eligible(g)->bool:
	var auto:Dictionary=_state.auto
	return auto.enabled and generation_ready() and best_x1(g,str(auto.route),current_layer(g,str(auto.route)))>0 and Permission.crew_available(g,str(auto.crew_id))

func prepare_start_auto(g)->Dictionary:
	var auto:Dictionary=_state.auto
	return prepare_start(g,str(auto.route),current_layer(g,str(auto.route)),"auto",str(auto.crew_id))

func prepare_complete_auto(g)->Dictionary:
	var a:Dictionary=_state.idle
	if a.is_empty() or float(a.work)<float(a.duration):return {}
	return prepare_complete(g,int(a.round_id),int(a.run_id),true)

func route_view(g,route:String,crew_id:String="")->Dictionary:
	var current:=current_layer(g,route);var best:=best_x1(g,route,current)
	var s:Dictionary=_state;var idle:Dictionary=s.idle;var active:Dictionary=s.active
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
	var luck:=luck_snapshot(g,route,crew_id)
	return {"route":route,"current_layer":current,"next_layer":current+1,"best_time":best,"task_mode":"none" if receipt.is_empty() else ("challenge" if receipt.mode=="manual" else "crew_idle" if receipt.mode=="auto" else "manual_idle"),"work":float(receipt.get("work",0.0)),"duration":float(receipt.get("duration",0.0)),"round_id":int(receipt.get("round_id",s.round_id)),"run_id":int(receipt.get("run_id",0)),"status":str(receipt.get("status","")),"background":idle.duplicate(true) if idle.get("route","")==route else {},"challenge":active.duplicate(true) if active.get("route","")==route else {},"reasons":reasons,"total_luck":luck.luck,"crew_luck":luck.crew_luck,"permanent_luck":luck.permanent_luck,"idle_duration":best,"crew_duration":idle_duration(g,best,crew_id),"crew_id":configured_crew(g,route)}

func material_exchange_quote(g,source:String,target:String,amount:Variant)->Dictionary:
	var s:Dictionary=_state
	var result:Dictionary={"error":"","source":source,"target":target,"amount":0,"source_owned":int(g.economy.balance(source)),"target_owned":int(g.economy.balance(target)),"cost":{},"received":{},"max_receive":0,"request":{}}
	var keys:Array=config.routes.values().map(func(route):return str(route.material))
	if source not in keys or target not in keys:result.error="invalid_material";return result
	if source==target:result.error="same_material";return result
	var limit:=Economy.MATERIAL_LIMIT
	result.max_receive=mini(int(result.source_owned)/2,limit-1-int(result.target_owned))
	if not C.integer(amount) or amount<=0 or amount>limit/2:result.error="invalid_amount";return result
	var count:=int(amount);var debit:=count*2
	result.amount=count;result.cost={source:debit};result.received={target:count}
	if debit>int(result.source_owned):result.error="insufficient_materials";return result
	if count>limit-1-int(result.target_owned):result.error="material_limit";return result
	result.request={"round_id":int(s.round_id),"command_seq":int(s.command_seq),"source":source,"target":target,"amount":count}
	return result

func prepare_exchange_materials(g,request:Dictionary)->Dictionary:
	var s:Dictionary=_state
	if not C.integer(request.get("round_id")) or int(request.round_id)!=int(s.round_id):return {"result":Forge.error("stale_round")}
	if not C.integer(request.get("command_seq")):return {"result":Forge.error("stale_command")}
	if not request.get("source") is String or not request.get("target") is String or not C.integer(request.get("amount")):return {"result":Forge.error("invalid_arguments")}
	var fingerprint:=JSON.stringify({"operation":"material_exchange","source":request.source,"target":request.target,"amount":int(request.amount)},"",true,true)
	if not s.last_command.is_empty() and int(request.command_seq)==int(s.last_command.seq):
		return {"result":Forge.restore_result(s.last_command.result_json) if fingerprint==s.last_command.fingerprint else Forge.error("command_conflict")}
	if int(request.command_seq)!=int(s.command_seq):return {"result":Forge.error("stale_command")}
	var quote:=material_exchange_quote(g,request.source,request.target,request.amount)
	if not quote.error.is_empty():return {"result":Forge.error(quote.error)}
	var next:Dictionary=s.duplicate(true)
	var wallet: Dictionary=g.economy.material_wallet()
	var wallet_revision: int=g.economy.material_revision
	if not Economy.material_debit(wallet,quote.cost) or not Economy.material_credit(wallet,quote.received):return {"result":Forge.error("invalid_wallet")}
	var result:Dictionary={"error":"","applied":true,"operation":"material_exchange","source":request.source,"target":request.target,"amount":int(request.amount),"cost":quote.cost,"received":quote.received,"source_after":int(wallet.materials[request.source]),"target_after":int(wallet.materials[request.target])}
	next.last_command={"seq":int(s.command_seq),"fingerprint":fingerprint,"result_json":JSON.stringify(result,"",true,true)};next.command_seq+=1
	if not S.valid(next,config,g.db.levels.size()):return {"result":Forge.error("invalid_result")}
	return proposal(g,next,"materials_exchanged",wallet,wallet_revision,result)

func equipment_constraints(g,ids: Array,bag: Dictionary={},ordinary: Variant=null) -> bool:
	if bag.is_empty():bag=_state.inventory
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
func prepare_equip_drone(g,id: String,replace_id: String="") -> Dictionary:
	var bag: Dictionary=_state.inventory
	var ids: Array=bag.equipped.duplicate()
	var capacity:=mini(Permission.hull_capacity(g,config),int(config.maximum_equipped))
	var result: Dictionary={"ok":false,"reason":"","changed":false,"capacity":capacity,"equipped":ids.duplicate(),"replaced_id":""}
	if not bag.drones.has(id):result.reason="unknown_drone";return {"result":result}
	if bag.sealed.has(id):result.reason="sealed";return {"result":result}
	if not bag.warehouse.has(id):result.reason="not_in_warehouse";return {"result":result}
	if ids.has(id):result.ok=true;result.reason="already_equipped";return {"result":result}
	if capacity<=0:result.reason="no_slots";return {"result":result}
	var target:=replace_id
	if not target.is_empty():
		if not ids.has(target):result.reason="replacement_not_equipped";return {"result":result}
	elif ids.size()>=capacity:
		if capacity==1 and ids.size()==1:target=str(ids[0])
		else:result.reason="select_replacement";return {"result":result}
	if target.is_empty():ids.append(id)
	else:ids[ids.find(target)]=id
	if ids.size()>capacity:result.reason="capacity_exceeded";return {"result":result}
	var legendary:=0;var ultimate:=0
	for equipped_id in ids:
		legendary+=int(bag.drones[equipped_id].legendary);ultimate+=int(bag.drones[equipped_id].ultimate)
	if legendary>int(config.maximum_legendary):result.reason="legendary_limit";return {"result":result}
	if ultimate>int(config.maximum_ultimate):result.reason="ultimate_limit";return {"result":result}
	if not equipment_constraints(g,ids,bag):result.reason="weapon_constraint";return {"result":result}
	var plan:=prepare_set_equipped(g,ids)
	if plan.is_empty():result.reason="invalid_loadout";return {"result":result}
	result.ok=true;result.changed=true;result.reason="equipped";result.equipped=ids;result.replaced_id=target
	plan.result=result;return plan

func prepare_unequip_drone(g,id: String) -> Dictionary:
	var ids: Array=_state.inventory.equipped.duplicate()
	var result: Dictionary={"ok":true,"reason":"already_unequipped","changed":false,"capacity":mini(Permission.hull_capacity(g,config),int(config.maximum_equipped)),"equipped":ids.duplicate(),"replaced_id":""}
	if not ids.has(id):return {"result":result}
	ids.erase(id)
	var plan:=prepare_set_equipped(g,ids)
	if plan.is_empty():result.ok=false;result.reason="invalid_loadout";return {"result":result}
	result.changed=true;result.reason="unequipped";result.equipped=ids
	plan.result=result;return plan

func prepare_set_equipped(g,ids: Array,hull_capacity: int=-1)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	var actual:=Permission.hull_capacity(g,config)
	if hull_capacity!=-1 and hull_capacity!=actual:return {}
	if not Bag.equipment_valid(next.inventory,ids,actual,config) or not equipment_constraints(g,ids,next.inventory):return {}
	next.inventory.equipped=ids.duplicate();next.inventory.generation+=1
	return proposal(g,next,"equipment_changed")

func prepare_set_favorites(g,ids: Array)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if not Bag.references_valid(ids,next.inventory):return {}
	next.inventory.favorites=ids.duplicate();next.inventory.generation+=1
	return proposal(g,next,"favorites_changed")

func prepare_set_preset(g,index: int,name: String,ids: Array,hanging_loadouts: Dictionary={})->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if index<0 or index>2 or index>next.inventory.presets.size() or name.length()>96 or not Bag.references_valid(ids,next.inventory):return {}
	var hangings: Dictionary=hanging_loadouts.duplicate(true)
	if hangings.is_empty():
		for id in ids:hangings[id]=next.inventory.drones[id].hangings.duplicate()
	var preset: Dictionary={"name":name,"drone_ids":ids.duplicate(),"hanging_loadouts":hangings}
	if index==next.inventory.presets.size():next.inventory.presets.append(preset)
	else:next.inventory.presets[index]=preset
	if not Bag.valid(next.inventory,config):return {}
	return proposal(g,next,"preset_changed")

func prepare_clear_preset(g,index: int)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if index<0 or index>=next.inventory.presets.size():return {}
	next.inventory.presets.remove_at(index);return proposal(g,next,"preset_changed")

func prepare_remove_unprotected(g,id: String)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if not Bag.remove(next.inventory,id):return {}
	Bag.organize(next.inventory,config);next.blocked=false;next.pending_time=0.0
	return proposal(g,next,"organized")

func prepare_claim_sealed(g,id: String)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if not next.inventory.sealed.has(id):return {}
	var actual:=Permission.planet_stage(g.db.data,str(next.inventory.drones[id].planet_id))
	if actual<1 or int(next.inventory.sealed[id])!=actual or int(g.profile.highestLevel)<actual:return {}
	next.inventory.sealed.erase(id);next.inventory.generation+=1
	return proposal(g,next,"unsealed")

func prepare_reforge(g,keep_ids: Array,claim_stages: Dictionary) -> Dictionary:
	var old: Dictionary=_state
	var actual:=Permission.claim_stages(old,keep_ids,g.db.data)
	if not keep_ids.is_empty() and actual.is_empty():return {}
	if not claim_stages.is_empty() and claim_stages!=actual:return {}
	var bag:=Bag.reforge(old.inventory,keep_ids,actual,config)
	if bag.is_empty():return {}
	var next:=fresh();next.round_id=int(old.round_id)+1;next.inventory=bag
	next.history=old.history.duplicate(true);next.unlocked_drones=old.unlocked_drones
	var plan:=proposal(g,next,"reforge");plan.marker=fresh_receipt();return plan

func generation_ready() -> bool:
	return config.policies.core_reward in ["exclusive","additional"]

func prepare_forge(g,request: Dictionary) -> Dictionary:
	var s: Dictionary=_state
	if request.get("round_id")!=s.round_id:return {"result":Forge.error("stale_round")}
	if not request.get("args",{}) is Dictionary:return {"result":Forge.error("invalid_arguments")}
	var fingerprint:=JSON.stringify({"operation":request.get("operation"),"drone_id":request.get("drone_id"),"args":request.get("args",{}),"expected_revision":request.get("expected_revision")},"",true,true)
	if not s.last_command.is_empty() and request.get("command_seq")==s.last_command.seq:
		return {"result":Forge.restore_result(s.last_command.result_json) if fingerprint==s.last_command.fingerprint else Forge.error("command_conflict")}
	if request.get("command_seq")!=s.command_seq:return {"result":Forge.error("stale_command")}
	var next: Dictionary=s.duplicate(true)
	var wallet: Dictionary=g.economy.material_wallet()
	var wallet_revision: int=g.economy.material_revision
	var result:=Forge.plan(next,wallet,config,request,g)
	if not result.error.is_empty():return {"result":result}
	next.last_command={"seq":int(s.command_seq),"fingerprint":fingerprint,"result_json":JSON.stringify(result,"",true,true)};next.command_seq+=1
	if not S.valid(next,config,g.db.levels.size()):return {"result":Forge.error("invalid_result")}
	if not equipment_constraints(g,next.inventory.equipped,next.inventory):return {"result":Forge.error("equipment_constraint")}
	return proposal(g,next,"forge_"+str(request.operation),wallet,wallet_revision,result)

func preview_forge(g,request: Dictionary) -> Dictionary:
	var next: Dictionary=_state.duplicate(true)
	var result:=Forge.plan(next,g.economy.material_wallet(),config,request,g)
	return {"error":result.error,"cost":result.get("cost",{}),"draws":result.get("draws",0),"revision":_state.inventory.drones.get(request.get("drone_id"),{}).get("forge_revision",0)}

func prepare_attach_hangings(g,id: String,keys: Array)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if not next.inventory.drones.has(id) or next.inventory.sealed.has(id):return {}
	var d: Dictionary=next.inventory.drones[id]
	if d.ultimate:return {}
	for key in keys:
		if not config.hanging_modules.has(key) or not next.hanging_modules[key].unlocked or int(g.profile.highestLevel)<int(config.hanging_modules[key].unlock_stage):return {}
	d.hangings=keys.duplicate()
	if not Bag.valid_drone(d,config):return {}
	next.inventory.generation+=1;return proposal(g,next,"hangings_changed")

func prepare_set_filter(g,filter: Dictionary)->Dictionary:
	if not Filter.valid(filter,config):return {}
	var next: Dictionary=_state.duplicate(true);next.filter=filter.duplicate(true)
	return proposal(g,next,"filter_changed")

func export_filter(g) -> String:
	return Filter.export_string(_state.filter,config)

func prepare_import_filter(g,value: String)->Dictionary:
	var filter:=Filter.import_string(value,config)
	return prepare_set_filter(g,filter) if not filter.is_empty() else {}

func prepare_set_legendary_collection(g,ids: Array)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	var seen: Dictionary={}
	for id in ids:
		if not next.legendary_seen.has(id) or seen.has(id):return {}
		seen[id]=true
	next.legendary_collection=ids.duplicate();return proposal(g,next,"legendary_collection_changed")

func prepare_apply_preset(g,index: int)->Dictionary:
	var next: Dictionary=_state.duplicate(true)
	if index<0 or index>=next.inventory.presets.size():return {}
	var preset: Dictionary=next.inventory.presets[index]
	var ids: Array=preset.drone_ids.filter(func(id):return next.inventory.drones.has(id) and not next.inventory.sealed.has(id) and next.inventory.warehouse.has(id))
	if not Bag.equipment_valid(next.inventory,ids,Permission.hull_capacity(g,config),config) or not equipment_constraints(g,ids,next.inventory):return {}
	for id in ids:
		var d: Dictionary=next.inventory.drones[id]
		if not d.ultimate:d.hangings=preset.hanging_loadouts.get(id,d.hangings).duplicate()
		for key in d.hangings:
			if not next.hanging_modules[key].unlocked or int(g.profile.highestLevel)<int(config.hanging_modules[key].unlock_stage):return {}
		if not Bag.valid_drone(d,config):return {}
	next.inventory.equipped=ids;next.inventory.generation+=1
	return proposal(g,next,"preset_applied")

func prepare_hull_fit(g,ship:String)->Dictionary:
	var old:Dictionary=_state
	var next:Dictionary=old.duplicate(true)
	var maximum:int=int(config.hull_capacities.get(ship,0))
	var changed:bool=next.inventory.equipped.size()>maximum
	if changed:next.inventory.equipped=next.inventory.equipped.slice(0,maximum);next.inventory.generation+=1
	return {"state":next,"changed":changed,"revision":revision}

func hull_fit_current(g,plan:Dictionary)->bool:
	return revision==plan.revision

func commit_hull_fit(g,plan:Dictionary)->void:
	if plan.changed:_install(plan.state,_receipt)
