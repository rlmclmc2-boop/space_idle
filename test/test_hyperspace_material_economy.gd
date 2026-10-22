extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const R=preload("res://scripts/drone_rewards.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
class RefusedHandoff:
	extends RefCounted
	func handoff_to_legacy(_game,_reason)->bool:return false

class ChangedWalletHandoff:
	extends RefCounted
	func handoff_to_legacy(game,_reason)->bool:
		game.economy.credit("degenerate_matter",1);return true

var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(db):
	var g=BattleGame.new(db,false);g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();return g
func make_drone(c:Dictionary)->Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=123
	var d:=R.create_drone(rng,c,"fixture","blue","laser",5,"1")
	d.affixes=[{"key":"global_damage","tier":5,"value":float(c.affixes.global_damage.ranges["5"][0]),"locked":false}]
	return d
func _initialize()->void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g=fixture(db);var c:Dictionary=g.hyperspace.config
	check(c.material_unit_scale==10 and c.ultimate_core_probability==0.002,"authoritative configuration loaded")
	var original:Dictionary=c.duplicate(true);original.material_unit_scale=1
	for route in c.routes:
		var req:Dictionary={"round_id":1,"run_id":1,"route":route,"level":20,"luck":0.0,"luck_state":"0"}
		var rng:=RandomNumberGenerator.new();rng.seed=761
		var state:Dictionary={"random_state":str(rng.state)}
		var a:=R.generate(state,original,req,"1");var b:=R.generate(state,c,req,"1")
		var key:String=c.routes[route].material
		check(b.reward.materials[key]==a.reward.materials[key]*10,"exploration scales only corresponding material "+route)
		check(a.reward.drone==b.reward.drone and a.reward.ultimate_cores==b.reward.ultimate_cores and a.random_state==b.random_state,"units do not alter drone, core or RNG "+route)
	var fractional:Dictionary=c.duplicate(true);fractional.material_reward_multiplier=1.037
	var base:int=int(c.material_base_reward)
	check(R.material_amount(fractional,1)==floori(float(base)*1.037*10.0),"final exploration amount rounds after multiplier and unit scale")
	var d:=make_drone(c)
	var rng_a:=RandomNumberGenerator.new();rng_a.seed=7
	var rng_b:=RandomNumberGenerator.new();rng_b.seed=7
	var drops_a:=R.dismantle(d,original,rng_a);var drops_b:=R.dismantle(d,c,rng_b)
	for key in drops_a.materials:check(drops_b.materials[key]==drops_a.materials[key]*10,"dismantle material scales")
	check(drops_a.hanging_rewards==drops_b.hanging_rewards and rng_a.state==rng_b.state,"dismantle module copies and random draws unchanged")
	var operations:Array=["add_affix","replace_affix","add_hanging_slot","lock_affix","promote_affix","reroll_values","enable_omen","disable_omen","legendary","modernize","ultimate","restore_ultimate"]
	for operation in operations:
		var s:Dictionary=S.fresh(c);var drone:=make_drone(c)
		if operation=="disable_omen":drone.omen=true
		if operation=="restore_ultimate":
			drone.legendary=true;drone.legendary_effect=R.legendary(rng_a,c,drone.weapon);drone.ultimate=true;drone.ultimate_affix=drone.affixes[0].duplicate()
		s.inventory.drones[drone.id]=drone;s.inventory.warehouse=[drone.id];s.history={"alpha":{"10":2.0}}
		var wallet:Dictionary=g.economy.material_wallet()
		for key in wallet.materials:wallet.materials[key]=1000000000
		wallet.ultimate_cores=100
		var request:Dictionary={"operation":operation,"drone_id":drone.id,"args":{}}
		var a:=Forge.plan(s.duplicate(true),wallet.duplicate(true),original,request,g);var b:=Forge.plan(s.duplicate(true),wallet.duplicate(true),c,request,g)
		check(a.error=="" and b.error=="","base and scaled forge operation available "+operation)
		for key in a.get("cost",{}):check(b.cost[key]==a.cost[key]*(1 if key=="ultimate_cores" else 10),"complete forge formula scales material, never core "+operation+":"+key)
	# Rounding and multiple-draw costs finish in base units before conversion.
	for operation in ["lock_affix","replace_affix","reroll_values","legendary"]:
		var s:Dictionary=S.fresh(c);var drone:=make_drone(c);drone.origin_quality="gold";drone.blue_source_bonus=false
		var args:Dictionary={}
		if operation=="lock_affix":
			drone.affixes=[drone.affixes[0].duplicate(),drone.affixes[0].duplicate(),drone.affixes[0].duplicate()];drone.affixes[0].locked=true;drone.affixes[1].locked=true
		if operation=="replace_affix":args.guaranteed_key="attack_speed"
		if operation=="reroll_values":args.guaranteed_max=true
		if operation=="legendary":
			var wanted:String=c.legendary_effects.keys().filter(func(key):return c.legendary_effects[key].weapon=="laser")[0]
			s.legendary_collection=[wanted];args.guaranteed_effect=wanted
		s.inventory.drones[drone.id]=drone;s.inventory.warehouse=[drone.id]
		var wallet:Dictionary=g.economy.material_wallet()
		for key in wallet.materials:wallet.materials[key]=1000000000000
		wallet.ultimate_cores=100
		var request:Dictionary={"operation":operation,"drone_id":drone.id,"args":args}
		var a:=Forge.plan(s.duplicate(true),wallet.duplicate(true),original,request,g);var b:=Forge.plan(s.duplicate(true),wallet.duplicate(true),c,request,g)
		check(a.error=="" and b.error=="" and a.draws==b.draws,"complex cost keeps original forecast and draws "+operation)
		for key in a.get("cost",{}):check(b.cost[key]==a.cost[key]*10,"complete complex base cost scales once "+operation)
	# Guard integral conversion before it can wrap a huge positive price negative.
	var overflow_config: Dictionary=c.duplicate(true)
	overflow_config.forge_costs.lock_affix.glueball=1e30
	var overflow_state: Dictionary=g.hyperspace.state.duplicate(true)
	var overflow_drone:=make_drone(c)
	overflow_state.inventory.drones[overflow_drone.id]=overflow_drone
	overflow_state.inventory.warehouse=[overflow_drone.id]
	var overflow_request: Dictionary={"operation":"lock_affix","drone_id":overflow_drone.id,"args":{}}
	check(Forge.plan(overflow_state,g.economy.material_wallet(),overflow_config,overflow_request,g).error=="cost_limit","out-of-range material price is rejected before integer conversion")
	# Actual equipped same-type copies add their grown material bonus.
	var module:=make_drone(c);module.hangings=["hyperspace_charge"];module.hanging_slots=1
	var hs:Dictionary=g.hyperspace.save_data()
	Bag.insert(hs.hyperspace.inventory,module,c);hs.hyperspace.inventory.equipped=[module.id]
	hs.hyperspace.hanging_modules.hyperspace_charge={"unlocked":true,"level":3,"exp":0.0};check(g.hyperspace.install_snapshot(hs,db),"module fixture installs");g.invalidate_stat_cache()
	var online:Dictionary=g.hyperspace.online_config(g)
	check(absf(online.material_reward_multiplier-pow(1.1,3))<0.000000000001,"collector level3 gives 1.1 cubed exploration material")
	check(online.energy_cap==c.energy_cap and online.energy_rate==c.energy_rate,"collector no longer changes energy")
	var second:Dictionary=module.duplicate(true);second.id="fixture2";hs=g.hyperspace.save_data();Bag.insert(hs.hyperspace.inventory,second,c);hs.hyperspace.inventory.equipped.append(second.id);check(g.hyperspace.install_snapshot(hs,db),"second module fixture installs");g.invalidate_stat_cache()
	online=g.hyperspace.online_config(g)
	check(absf(online.material_reward_multiplier-(1.0+2.0*(pow(1.1,3)-1.0)))<0.000000000001,"two collector copies add bonuses rather than multiply")
	check(R.dismantle(module,online,rng_a).materials==R.dismantle(module,c,rng_b).materials,"collector does not boost dismantle material")
	var normalized:=R.quality_weights(c);var total:=0.0
	for weight in normalized.values():total+=float(weight)
	check(absf(float(normalized.ultimate_core)/total-0.002)<0.000000000000001,"actual normalized core probability is 0.2 percent")
	var noncore:Array=normalized.keys().filter(func(key):return key!="ultimate_core")
	check(absf(float(normalized[noncore[0]])/float(normalized[noncore[1]])-float(c.quality_weights[noncore[0]])/float(c.quality_weights[noncore[1]]))<0.000000000001,"other quality relative weights retained")
	var forced:Dictionary=online.duplicate(true);forced.ultimate_core_probability=1.0;forced.policies=forced.policies.duplicate(true);forced.policies.core_reward="additional"
	var base_forced:Dictionary=forced.duplicate(true);base_forced.material_reward_multiplier=1.0
	var state:Dictionary={"random_state":"123"};var request:Dictionary={"round_id":1,"run_id":1,"route":"alpha","level":5}
	var core_base:=R.generate(state,base_forced,request,"1");var core_boosted:=R.generate(state,forced,request,"1")
	check(core_base.error=="" and core_boosted.error=="" and core_base.reward.ultimate_cores==1 and core_boosted.reward.ultimate_cores==1,"collector never multiplies actual core reward")
	check(core_base.reward.drone==core_boosted.reward.drone and core_base.random_state==core_boosted.random_state,"collector never changes actual drone or reward RNG")
	# Current pending reward is credited together with its receipt, or not at all.
	var resumed=fixture(db)
	hs=resumed.hyperspace.save_data();hs.hyperspace.next_run=2
	var receipt:Dictionary={"round_id":1,"run_id":1,"status":"completed_pending","mode":"idle","route":"alpha","level":5,"crew_id":"","crew_snapshot":"","luck":0.0,"crew_luck":0.0,"permanent_luck":0.0,"luck_state":"0","return_target":{},"ticket":0.0,"duration":3.0,"work":3.0,"reward":{"drone":d.duplicate(true),"materials":{"degenerate_matter":7},"ultimate_cores":1,"hanging_rewards":{"resource_collector":1}}}
	receipt.reward.drone.id="space:1:1";hs.hyperspace.idle=receipt;check(resumed.hyperspace.install_snapshot(hs,db),"pending reward fixture installs")
	resumed.economy.credit("degenerate_matter",9000000000000000-1)
	var baseline:Dictionary=resumed.hyperspace.state.duplicate(true)
	check(not resumed.hyperspace_runtime.claim(resumed,1,1) and resumed.hyperspace.state==baseline and resumed.economy.balance("ultimate_cores")==0,"overflow keeps pending receipt, inventory, modules and core unchanged")
	resumed.economy.debit({"degenerate_matter":100})
	var seen:Array=[]
	resumed.event.connect(func(kind,_info):
		if kind=="hyperspace_changed":seen.append(resumed.portable_save_data())
	)
	check(resumed.hyperspace_runtime.claim(resumed,1,1) and not resumed.hyperspace_runtime.claim(resumed,1,1),"current pending reward settles exactly once")
	check(seen.size()==1 and seen[0].ultimateCores==1 and seen[0].hyperspace.idle.is_empty() and seen[0].hyperspace.inventory.drones.has("space:1:1") and seen[0].hyperspaceReceipt=={"round":1,"run":1,"drone_id":"space:1:1","unread":true},"claim notification sees earned wallet and claim fact together")
	var pending:Dictionary=resumed.portable_save_data()
	check(Transfer.new().prepare_data(JSON.parse_string(JSON.stringify(pending)),db).error=="","current save exports and validates after claim")
	for invalid in [-1,0.5,9000000000000000]:
		var bad:Dictionary=pending.duplicate(true);bad.materials.degenerate_matter=invalid
		resumed.load_progress_data(bad)
		check(resumed.economy.balance("degenerate_matter")==pending.materials.degenerate_matter and resumed.hyperspace.state==pending.hyperspace,"invalid material cannot install partial save "+str(invalid))
	var forged=fixture(db)
	var drone:=make_drone(c);hs=forged.hyperspace.save_data();Bag.insert(hs.hyperspace.inventory,drone,c);check(forged.hyperspace.install_snapshot(hs,db),"forge fixture installs")
	var command:Dictionary={"round_id":1,"command_seq":1,"drone_id":drone.id,"operation":"add_affix","args":{},"expected_revision":0}
	var before_state:Dictionary=forged.hyperspace.state.duplicate(true)
	var no_funds:Dictionary=forged.hyperspace_runtime.forge(forged,command)
	check(no_funds.error=="insufficient_materials" and forged.hyperspace.state==before_state,"failed forge leaves RNG, item and command sequence unchanged")
	check(forged.economy.credit_many(no_funds.cost),"fund actual quote")
	var preview:Dictionary=forged.hyperspace.preview_forge(forged,command)
	check(forged.hyperspace.state==before_state,"forecast keeps authoritative RNG and inventory unchanged")
	var funded:Dictionary=forged.economy.save_data()
	forged.native_execution=RefusedHandoff.new()
	check(forged.hyperspace_runtime.forge(forged,command).error=="native_handoff_failed" and forged.economy.save_data()==funded and forged.hyperspace.state==before_state,"refused native preparation leaves paid wallet, RNG and item untouched")
	forged.native_execution=null
	var proposal:Dictionary=forged.hyperspace.prepare_forge(forged,command)
	check(proposal.has("next") and forged.hyperspace.state==before_state and forged.economy.save_data()==funded,"prepare keeps every live domain unchanged")
	check(proposal.next.is_read_only() and proposal.next.inventory.drones[drone.id].affixes.is_read_only(),"prepared randomized state is recursively immutable")
	forged.hyperspace.add_online_time(0.25)
	check(not forged.hyperspace_runtime.commit(forged,proposal) and forged.economy.save_data()==funded,"stale state proposal cannot overwrite newer clock or debit")
	proposal=forged.hyperspace.prepare_forge(forged,command)
	forged.economy.credit("degenerate_matter",1)
	check(not forged.hyperspace_runtime.commit(forged,proposal) and forged.hyperspace.state.command_seq==1,"stale wallet proposal cannot install random result")
	forged.economy.debit({"degenerate_matter":1})
	proposal=forged.hyperspace.prepare_forge(forged,command)
	forged.add_crew_exp("navigator",1.0)
	check(not forged.hyperspace_runtime.commit(forged,proposal) and forged.hyperspace.state.command_seq==1,"changed preparation dependency rejects before commit")
	forged.native_execution=ChangedWalletHandoff.new()
	check(forged.hyperspace_runtime.forge(forged,command).error=="native_handoff_failed" and forged.hyperspace.state.command_seq==1 and forged.hyperspace.state.inventory==before_state.inventory,"handoff-time wallet change is rechecked before installing RNG or item")
	forged.native_execution=null;forged.economy.debit({"degenerate_matter":1})
	var forged_seen:Array=[]
	forged.event.connect(func(kind,_info):
		if kind=="hyperspace_changed":forged_seen.append(forged.portable_save_data())
	)
	var committed:Dictionary=forged.hyperspace_runtime.forge(forged,command)
	check(committed.error=="" and committed.cost==preview.cost and forged_seen.size()==1,"forge commits the same quoted price")
	check(forged_seen[0].hyperspace.command_seq==2 and forged_seen[0].hyperspace.inventory.drones[drone.id].forge_revision>0 and forged_seen[0].materials.degenerate_matter==0,"forge notification sees price, RNG, growth and receipt together")
	check(not forged.profile.has("hyperspace") and not forged.profile.has("hyperspaceReceipt"),"shared profile has no hyperspace or receipt write authority")
	var view:Dictionary=forged.hyperspace.state
	check(view.is_read_only() and view.inventory.is_read_only() and view.inventory.warehouse.is_read_only() and view.inventory.drones[drone.id].is_read_only() and forged.hyperspace.receipt_marker().is_read_only(),"published state and receipt are recursively read-only")
	var detached_hs:Dictionary=forged.hyperspace.save_data();detached_hs.hyperspace.inventory.drones[drone.id].level=999
	check(forged.hyperspace.state.inventory.drones[drone.id].level==5,"save copies cannot mutate owner")
	var hull_plan:Dictionary=forged.hyperspace.prepare_hull_fit(forged,"Frigate")
	forged.hyperspace.add_online_time(0.25)
	check(not forged.hyperspace.hull_fit_current(forged,hull_plan) and is_same(view.inventory,forged.hyperspace.state.inventory),"clock invalidates stale hull replacement without copying inventory")
	var wallet_after:Dictionary=forged.economy.save_data()
	check(forged.hyperspace_runtime.forge(forged,command)==committed and forged.economy.save_data()==wallet_after,"retry returns same randomized result without second cost")
	# Actual equipment evolution uses both balances in one debit.
	var evolved=fixture(db);var equipment:Dictionary=evolved.equipment.save_data();equipment.loadout.weapons[0].level=19;check(evolved.equipment.install_snapshot(equipment,db),"evolution fixture installs")
	evolved.economy.credit("1",1000000000000)
	var upgrade:Dictionary=evolved.slot_upgrade_cost("weapons",0)
	var original_resources:Dictionary=evolved.economy.resources()
	check(not evolved.upgrade_slot("weapons",0) and evolved.economy.resources()==original_resources and evolved.module_entry("weapons",0).level==19,"missing integer material cannot debit resources or grow equipment")
	var material:String=db.evolution_material_id()
	evolved.economy.credit(material,upgrade[material])
	check(evolved.upgrade_slot("weapons",0) and evolved.module_entry("weapons",0).level==20 and evolved.economy.balance(material)==0,"actual evolution consumes quoted material and advances equipment")
	print("MATERIAL_ECONOMY: ",checks," checks ",failures," failures; formula and committed ownership boundaries")
	quit(1 if failures else 0)
