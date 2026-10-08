extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const R=preload("res://scripts/drone_rewards.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
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
		for key in s.materials:s.materials[key]=1000000000
		s.ultimate_cores=100
		var request:Dictionary={"operation":operation,"drone_id":drone.id,"args":{}}
		var a:=Forge.plan(s.duplicate(true),original,request,g);var b:=Forge.plan(s.duplicate(true),c,request,g)
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
		for key in s.materials:s.materials[key]=1000000000000
		s.ultimate_cores=100
		var request:Dictionary={"operation":operation,"drone_id":drone.id,"args":args}
		var a:=Forge.plan(s.duplicate(true),original,request,g);var b:=Forge.plan(s.duplicate(true),c,request,g)
		check(a.error=="" and b.error=="" and a.draws==b.draws,"complex cost keeps original forecast and draws "+operation)
		for key in a.get("cost",{}):check(b.cost[key]==a.cost[key]*10,"complete complex base cost scales once "+operation)
	# Actual equipped same-type copies add their grown material bonus.
	var module:=make_drone(c);module.hangings=["hyperspace_charge"];module.hanging_slots=1
	Bag.insert(g.profile.hyperspace.inventory,module,c);g.profile.hyperspace.inventory.equipped=[module.id]
	g.profile.hyperspace.hanging_modules.hyperspace_charge={"unlocked":true,"level":3,"exp":0.0};g.invalidate_stat_cache()
	var online:Dictionary=g.hyperspace.online_config(g)
	check(absf(online.material_reward_multiplier-pow(1.1,3))<0.000000000001,"collector level3 gives 1.1 cubed exploration material")
	check(online.energy_cap==c.energy_cap and online.energy_rate==c.energy_rate,"collector no longer changes energy")
	var second:Dictionary=module.duplicate(true);second.id="fixture2";Bag.insert(g.profile.hyperspace.inventory,second,c);g.profile.hyperspace.inventory.equipped.append(second.id);g.invalidate_stat_cache()
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
	# Legacy frozen settlement is converted, never regenerated.
	var old:Dictionary=S.fresh(c);old.erase("material_unit_version");old.next_run=2;old.settled_run=0
	for key in old.materials:old.materials[key]=11
	var receipt:Dictionary={"round_id":1,"run_id":1,"status":"completed_pending","mode":"idle","route":"alpha","level":5,"crew_id":"","crew_snapshot":"","luck":0.0,"crew_luck":0.0,"permanent_luck":0.0,"luck_state":"0","return_journey":{},"ticket":0.0,"duration":3.0,"work":3.0,"reward":{"drone":d.duplicate(true),"materials":{"degenerate_matter":7},"ultimate_cores":1,"hanging_rewards":{"resource_collector":1}}}
	receipt.reward.drone.id="space:1:1";old.idle=receipt;old.ultimate_cores=5
	check(S.valid(old,c,db.levels.size()),"pre-unit v5 frozen save valid")
	var disk_old:Dictionary=JSON.parse_string(JSON.stringify(old))
	var migrated:=S.migrate(disk_old,c)
	for key in old.materials:check(migrated.materials[key]==110,"existing material balance converted once "+key)
	check(migrated.idle.reward.materials.degenerate_matter==70 and migrated.idle.reward.drone==disk_old.idle.reward.drone and migrated.idle.reward.hanging_rewards==disk_old.idle.reward.hanging_rewards and migrated.idle.reward.ultimate_cores==1 and migrated.ultimate_cores==5 and migrated.random_state==old.random_state,"frozen prize conversion keeps drone, module, core and RNG")
	check(migrated.material_unit_version==2 and S.migrate(migrated,c)==migrated,"explicit unit marker prevents second conversion")
	var resumed=fixture(db);check(resumed.hyperspace.load_state(resumed,old),"real load installs unit migration")
	check(resumed.hyperspace.claim(resumed,1,1) and not resumed.hyperspace.claim(resumed,1,1) and resumed.profile.hyperspace.materials.degenerate_matter==180,"converted pending claim settles exactly once")
	var bad:Dictionary=old.duplicate(true);bad.materials.degenerate_matter=900000000000000
	check(not S.valid(bad,c,db.levels.size()),"migration overflow rejects instead of truncating purchasing power")
	var legacy:Dictionary=old.duplicate(true);legacy.version=4;legacy.active=legacy.idle;legacy.active.mode="manual";legacy.active.duration=0.0;legacy.erase("idle")
	check(S.valid(legacy,c,db.levels.size()),"legacy v4 frozen manual receipt valid")
	var legacy_migrated:=S.migrate(JSON.parse_string(JSON.stringify(legacy)),c)
	check(legacy_migrated.active.reward.materials.degenerate_matter==70 and legacy_migrated.history.alpha["5"]==3.0,"legacy v4 migration converts prize and preserves proven win")
	var cached:Dictionary=old.duplicate(true);cached.command_seq=2;cached.last_command={"seq":1,"fingerprint":"unchanged","result_json":JSON.stringify({"operation":"fixture","cost":{"degenerate_matter":3,"ultimate_cores":1},"rewards":{"materials":{"antiproton":2},"modules":{"resource_collector":{"copies":1}}}})}
	check(S.valid(cached,c,db.levels.size()),"legacy cached command valid")
	var cached_migrated:=S.migrate(cached,c);var cached_result:Dictionary=JSON.parse_string(cached_migrated.last_command.result_json)
	check(cached_result.cost.degenerate_matter==30 and cached_result.cost.ultimate_cores==1 and cached_result.rewards.materials.antiproton==20 and cached_result.rewards.modules.resource_collector.copies==1,"cached material result converted, cores and module experience unchanged")
	check(cached_migrated.last_command.fingerprint==cached.last_command.fingerprint and cached_migrated.command_seq==cached.command_seq,"cache command identity remains idempotent")
	var exchanged=fixture(db);exchanged.profile.hyperspace.erase("material_unit_version");exchanged.profile.hyperspace.materials.degenerate_matter=100
	var exchange_quote:Dictionary=exchanged.hyperspace_material_exchange_quote("degenerate_matter","antiproton",10)
	check(exchanged.exchange_hyperspace_materials(exchange_quote.request).error=="","pre-unit exchange cached fixture")
	var exchange_reload=fixture(db);exchange_reload.hyperspace.load_state(exchange_reload,JSON.parse_string(JSON.stringify(exchanged.profile.hyperspace)))
	var exchange_after:Dictionary=exchange_reload.profile.hyperspace.duplicate(true)
	var replay:Dictionary=exchange_reload.exchange_hyperspace_materials(exchange_quote.request)
	check(replay.error=="" and replay.amount==100 and replay.cost.degenerate_matter==200 and exchange_reload.profile.hyperspace==exchange_after,"migrated cached exchange replays converted receipt without second debit")
	var variant:Dictionary=c.duplicate(true);variant.material_unit_scale=7
	check(S.migrate(old,variant).materials.degenerate_matter==77,"migration uses distinct configured unit scale")
	var pending:Dictionary=resumed.portable_save_data();check(Transfer.new().prepare_data(JSON.parse_string(JSON.stringify(pending)),db).error=="","unit-version save exports and validates after claim")
	print("MATERIAL_ECONOMY: ",checks," checks ",failures," failures; formula and migration boundaries only")
	quit(1 if failures else 0)
