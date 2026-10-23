extends RefCounted
## Game-owned coordination for hyperspace commands and economic/native commits.
const Economy=preload("res://scripts/economy_state.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Result=preload("res://scripts/command_result.gd")
var advancing:=false
func commit(g,plan:Dictionary)->bool:
	return Result.succeeded(commit_result(g,plan))

func commit_result(g,plan:Dictionary)->Dictionary:
	if g.commit_effects.active:return Result.make("blocked","commit_in_progress")
	if not g.hyperspace.proposal_current(g,plan):return Result.make("rejected","stale_hyperspace")
	plan=plan.duplicate(true)
	Result.freeze(plan)
	var wallet:Dictionary=plan.wallet
	var previous_wallet:Dictionary=g.economy.material_wallet()
	if not wallet.is_empty() and (plan.wallet_revision!=g.economy.material_revision or not Economy.valid_material_wallet(wallet,previous_wallet.materials.keys())):return Result.make("rejected","stale_material_wallet")
	var kind:String=plan.kind
	var refit:bool=kind in ["equipment_changed","hangings_changed","preset_applied","claimed"] or kind.begins_with("forge_")
	var configuration_before:Array=g.attributes.configuration_inputs(g)
	if refit and not g.native_before_configuration_change():return Result.make("blocked","native_handoff")
	# A native handoff can notify observers. Recheck all prepared inputs afterwards.
	if not g.hyperspace.proposal_current(g,plan):return Result.make("rejected","stale_hyperspace")
	if not wallet.is_empty() and plan.wallet_revision!=g.economy.material_revision:return Result.make("rejected","stale_material_wallet")
	if configuration_before!=g.attributes.configuration_inputs(g):return Result.make("rejected","stale_configuration")
	if not g.commit_effects.begin(g):return Result.make("blocked","commit_in_progress")
	if refit:g.capture_refit_health()
	var previous_capacity=g.reactor_capacity() if refit else 0
	var credited:Array=[];var changed_resources:Array=[];var domains:Array=["hyperspace"];var notices:Array=[]
	if not wallet.is_empty():
		for id in wallet.materials:
			if int(wallet.materials[id])!=int(previous_wallet.materials[id]):changed_resources.append(id)
			if int(wallet.materials[id])>int(previous_wallet.materials[id]):credited.append(id)
		if int(wallet.ultimate_cores)!=int(previous_wallet.ultimate_cores):changed_resources.append("ultimate_cores")
		# All failure checks precede this synchronous pair of installations.
		var installed:bool=g.economy.install_material_wallet(wallet)
		assert(installed,"Validated material wallet must install without callbacks")
		if not changed_resources.is_empty():domains.append("economy")
	g.hyperspace.commit(plan)
	var capacity_changed:=false
	if refit:
		var capacity=g.reactor_capacity()
		g.reactor.reconcile_capacity(capacity)
		g.configuration_committed();g.apply_refit_health()
		capacity_changed=capacity!=previous_capacity
		if capacity_changed:notices.append({"kind":"reactor_changed","payload":{"capacity":capacity}})
	var payload:Dictionary={"reason":kind,"round_id":int(g.hyperspace.state.round_id)}
	if plan.has("reward"):payload.reward=plan.reward.duplicate(true);payload.receipt=g.hyperspace.receipt_marker().duplicate()
	if not credited.is_empty():notices.append({"kind":"resources_changed","payload":{"ids":credited}})
	notices.append({"kind":"hyperspace_changed","payload":payload})
	return g.commit_effects.finish(g,domains,changed_resources,[],{"reactor_allocation_changed":capacity_changed},notices)
func start(g,route:String,level:int,mode:String,crew_id:String="",return_target:Dictionary={})->Dictionary:
	var plan:Dictionary=g.hyperspace.prepare_start(g,route,level,mode,crew_id,return_target)
	return plan.result.duplicate(true) if commit(g,plan) else {}
func complete(g,round_id:int,run_id:int,success:bool,reward:Dictionary={},x1_seconds:float=0.0,record_x1:bool=false)->bool:
	return commit(g,g.hyperspace.prepare_complete(g,round_id,run_id,success,reward,x1_seconds,record_x1))
func claim(g,round_id:int,run_id:int)->bool:
	return commit(g,g.hyperspace.prepare_claim(g,round_id,run_id))
func settle_interrupted(g)->void:
	var receipt:Dictionary=g.hyperspace.state.active
	if receipt.is_empty() or receipt.status!="started":return
	var refund:float=float(receipt.ticket)
	if complete(g,int(receipt.round_id),int(receipt.run_id),false) and refund>0:
		g.manual_hyperspace.last_result={"route":str(receipt.route),"level":int(receipt.level),"reason":"interrupted_reload","refund":refund}
func reset()->void:advancing=false
func advance(g,dt:float)->void:
	if advancing or not is_finite(dt) or dt<=0 or g.paused or not g.hyperspace.is_unlocked(g):return
	advancing=true
	g.hyperspace.add_online_time(dt);g.save_dirty=true
	_advance(g)
	advancing=false
func _advance(g)->void:
	var owner=g.hyperspace
	var c:Dictionary=owner.online_config(g)
	var completions:=0
	while float(owner.state.pending_time)>0.000000001:
		var s:Dictionary=owner.state
		for slot in ["active","idle"]:
			var pending:Dictionary=s[slot]
			if pending.get("status","")=="completed_pending":
				if not claim(g,int(pending.round_id),int(pending.run_id)):
					owner.advance_online_work(c,float(owner.state.pending_time),false,not Bag.has_space(owner.state.inventory,c));return
				s=owner.state
		if s.idle.is_empty():
			if not owner.auto_eligible(g) or not Bag.has_space(s.inventory,c):
				owner.advance_online_work(c,float(s.pending_time),false,s.auto.enabled and not Bag.has_space(s.inventory,c));return
			if not start_auto(g):owner.advance_online_work(c,float(owner.state.pending_time));return
			s=owner.state
		var a:Dictionary=s.idle
		var once:bool=a.mode=="idle"
		var step:=minf(float(s.pending_time),maxf(0.0,float(a.duration)-float(a.work)))
		owner.advance_online_work(c,step,true)
		if float(owner.state.idle.work)+0.000000001<float(a.duration):return
		if not complete_auto(g):owner.advance_online_work(c,float(owner.state.pending_time));return
		completions+=1
		if not claim(g,int(a.round_id),int(a.run_id)):
			owner.advance_online_work(c,float(owner.state.pending_time),false,not Bag.has_space(owner.state.inventory,c));return
		if once:owner.advance_online_work(c,float(owner.state.pending_time));return
		if not Bag.has_space(owner.state.inventory,c):owner.advance_online_work(c,float(owner.state.pending_time),false,true);return
		# Unconsumed online time stays in the owner before every notification and
		# across the bounded completion budget, so a save cannot lose that work.
		if completions>=int(c.completion_budget):return
func start_idle(g,route:String)->bool:
	return commit(g,g.hyperspace.prepare_start_idle(g,route))
func stop_idle(g,route:String)->bool:
	return commit(g,g.hyperspace.prepare_stop_idle(g,route))
func set_auto(g,enabled:bool,route:String,level:int,crew_id:String)->bool:
	return commit(g,g.hyperspace.prepare_set_auto(g,enabled,route,level,crew_id))
func start_auto(g)->bool:
	return commit(g,g.hyperspace.prepare_start_auto(g))
func complete_auto(g)->bool:
	return commit(g,g.hyperspace.prepare_complete_auto(g))
func set_equipped(g,ids:Array,hull_capacity:int=-1)->bool:
	return commit(g,g.hyperspace.prepare_set_equipped(g,ids,hull_capacity))
func set_favorites(g,ids:Array)->bool:
	return commit(g,g.hyperspace.prepare_set_favorites(g,ids))
func set_preset(g,index:int,name:String,ids:Array,hanging_loadouts:Dictionary={})->bool:
	return commit(g,g.hyperspace.prepare_set_preset(g,index,name,ids,hanging_loadouts))
func clear_preset(g,index:int)->bool:
	return commit(g,g.hyperspace.prepare_clear_preset(g,index))
func remove_unprotected(g,id:String)->bool:
	return commit(g,g.hyperspace.prepare_remove_unprotected(g,id))
func claim_sealed(g,id:String)->bool:
	return commit(g,g.hyperspace.prepare_claim_sealed(g,id))
func attach_hangings(g,id:String,keys:Array)->bool:
	return commit(g,g.hyperspace.prepare_attach_hangings(g,id,keys))
func set_filter(g,filter:Dictionary)->bool:
	return commit(g,g.hyperspace.prepare_set_filter(g,filter))
func import_filter(g,value:String)->bool:
	return commit(g,g.hyperspace.prepare_import_filter(g,value))
func set_legendary_collection(g,ids:Array)->bool:
	return commit(g,g.hyperspace.prepare_set_legendary_collection(g,ids))
func apply_preset(g,index:int)->bool:
	return commit(g,g.hyperspace.prepare_apply_preset(g,index))
func forge(g,request:Dictionary)->Dictionary:
	var plan:Dictionary=g.hyperspace.prepare_forge(g,request)
	if not plan.has("next"):return plan.result
	if commit(g,plan):return plan.result
	return Forge.error("native_handoff_failed")
func exchange_materials(g,request:Dictionary)->Dictionary:
	var plan:Dictionary=g.hyperspace.prepare_exchange_materials(g,request)
	if not plan.has("next"):return plan.result
	if commit(g,plan):return plan.result
	return Forge.error("wallet_changed")
func equip_drone(g,id:String,replace_id:String="")->Dictionary:
	var plan:Dictionary=g.hyperspace.prepare_equip_drone(g,id,replace_id)
	if not plan.has("next"):return plan.result
	if commit(g,plan):return plan.result
	var failed:Dictionary=plan.result.duplicate();failed.ok=false;failed.changed=false;failed.reason="invalid_loadout";failed.equipped=g.hyperspace.state.inventory.equipped.duplicate();return failed
func unequip_drone(g,id:String)->Dictionary:
	var plan:Dictionary=g.hyperspace.prepare_unequip_drone(g,id)
	if not plan.has("next"):return plan.result
	if commit(g,plan):return plan.result
	var failed:Dictionary=plan.result.duplicate();failed.ok=false;failed.changed=false;failed.reason="invalid_loadout";failed.equipped=g.hyperspace.state.inventory.equipped.duplicate();return failed
