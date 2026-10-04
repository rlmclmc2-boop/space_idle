extends SceneTree
const Bag=preload("res://scripts/drone_inventory.gd")
const State=preload("res://scripts/hyperspace_state.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const R=preload("res://scripts/hyperspace_random.gd")
const Filter=preload("res://scripts/hyperspace_filter.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func opened(db):
	var g=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks()
	var c: Dictionary=g.hyperspace.config.duplicate(true)
	# Explicit test fixture policies; production nulls remain decision gates.
	c.policies.core_reward="additional";c.policies.promotion_success="weighted_draw_stronger"
	c.policies.omen_scope="drone";c.policies.legendary_repeat_action="reroll_effect"
	g.hyperspace.configure(c);g.profile.hyperspace=g.hyperspace.fresh()
	return g
func add(g,id: String,quality: String="blue") -> Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=12345
	var d:=Rewards.create_drone(rng,g.hyperspace.config,id,quality,"laser",5,"1")
	Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
	return g.profile.hyperspace.inventory.drones[id]
func request(g,id: String,op: String,args: Dictionary={}) -> Dictionary:
	return {"round_id":g.profile.hyperspace.round_id,"command_seq":g.profile.hyperspace.command_seq,"drone_id":id,"operation":op,"args":args,"expected_revision":g.profile.hyperspace.inventory.drones[id].forge_revision}
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g=opened(db);var h=g.hyperspace;var s: Dictionary=g.profile.hyperspace
	check(State.valid(s,h.config,db.levels.size()),"current namespace valid")
	check(Permission.bindings_valid(g.portable_save_data(),db.data,h.config),"fresh bindings")
	var a: Dictionary=h.start(g,"alpha",5,"manual")
	check(not a.is_empty() and g.profile.hyperspace.energy==108000,"ticket paid")
	check(h.complete(g,a.round_id,a.run_id,true,{},40,true),"reward generated frozen")
	var pending: Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(pending,db).error=="","current pending export")
	var restored=opened(db);restored.load_progress_data(pending)
	check(restored.hyperspace.claim(restored,a.round_id,a.run_id),"restored claim")
	check(not restored.hyperspace.claim(restored,a.round_id,a.run_id),"claim idempotent")
	check(h.claim(g,a.round_id,a.run_id),"claim generated reward")
	var saved: Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(saved,db).data.hyperspace==saved.hyperspace,"current export exact")
	var corrupt: Dictionary=saved.duplicate(true);corrupt.hyperspace.version=State.VERSION+1
	var baseline: Dictionary=g.profile.duplicate(true);g.load_progress_data(corrupt)
	check(g.profile==baseline and Transfer.new().prepare_data(corrupt,db).error=="format","incompatible version rejected atomically")
	g.profile.hyperspace.energy=216000;a=h.start(g,"alpha",5,"manual");h.advance(g,10800)
	check(h.complete(g,a.round_id,a.run_id,false) and g.profile.hyperspace.energy==324000,"refund over cap")
	h.advance(g,1);check(g.profile.hyperspace.energy==324000,"over cap no recharge")
	check(h.set_auto(g,true,"alpha",5,"navigator"),"real unlocked crew")
	check(not g.idle_planet_crew("navigator"),"reserved cannot planet explore")
	check(not g.crew.can_assign(g,"navigator","weapon","laser"),"reserved cannot reassign")
	check(h.start_auto(g),"progress only automatic start")
	check(g.profile.hyperspace.active.duration==40 and g.profile.hyperspace.active.ticket==108000,"locked crew levels count zero")
	check(h.complete(g,g.profile.hyperspace.active.round_id,g.profile.hyperspace.active.run_id,false),"auto failure refunds")
	h.set_auto(g,false,"",0,"")
	var d:=add(g,"forge");d.affixes=[{"key":"global_damage","tier":5,"value":0.05,"locked":true},{"key":"attack_speed","tier":5,"value":0.01,"locked":false}]
	for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=10000000
	g.profile.hyperspace.ultimate_cores=5
	var q:=request(g,"forge","replace_affix",{"guaranteed_key":"global_damage"})
	baseline=g.profile.hyperspace.duplicate(true)
	var quote: Dictionary=h.preview_forge(g,q)
	check(quote.error=="" and quote.cost.degenerate_matter==5*quote.draws and g.profile.hyperspace==baseline,"read only deterministic forecast")
	var result: Dictionary=h.forge(g,q)
	check(result.error=="" and result.cost==quote.cost,"quote commit cost exact")
	check(g.profile.hyperspace.inventory.drones.forge.affixes[0]==baseline.inventory.drones.forge.affixes[0],"locked never selected")
	var committed: Dictionary=g.profile.hyperspace.duplicate(true)
	check(h.forge(g,q)==result and g.profile.hyperspace==committed,"command retry returns cached result")
	q.args={};check(h.forge(g,q).error=="command_conflict","same command different content conflict")
	q=request(g,"forge","legendary");check(h.forge(g,q).error=="","legend conversion")
	d=g.profile.hyperspace.inventory.drones.forge
	check(d.blue_source_bonus and d.affixes.size()==2 and d.preserved_hanging_slots==baseline.inventory.drones.forge.hanging_slots,"legend retains source and attachments")
	q=request(g,"forge","ultimate");check(h.forge(g,q).error=="","ultimate separate flag")
	var extra: Dictionary=g.profile.hyperspace.inventory.drones.forge.ultimate_affix.duplicate()
	check(h.forge(g,request(g,"forge","lock_affix")).error=="ultimate_modification_forbidden","ultimate modification boundary")
	check(h.forge(g,request(g,"forge","restore_ultimate")).error=="","ultimate restored")
	check(h.forge(g,request(g,"forge","ultimate")).error=="" and g.profile.hyperspace.inventory.drones.forge.ultimate_affix==extra,"ultimate extra archived reused")
	check(h.set_equipped(g,["forge"]),"actual frigate capacity")
	check(not h.set_equipped(g,["forge"],5),"caller cannot forge capacity")
	check(h.forge(g,request(g,"forge","dismantle")).error=="protected_drone","equipped protected")
	h.set_equipped(g,[])
	var module: String=h.config.hanging_modules.keys()[0]
	check(Rewards.credit_modules(g.profile.hyperspace,h.config,{module:1}) and g.profile.hyperspace.hanging_modules[module].level==0,"first module drop unlocks")
	check(Rewards.credit_modules(g.profile.hyperspace,h.config,{module:1}) and g.profile.hyperspace.hanging_modules[module].level==1,"repeat module drop growth")
	var f: Dictionary={"version":2,"enabled":true,"mode":"all","action":"keep_matches","conditions":[{"field":"weapon","value":"laser"},{"field":"affix","key":"global_damage","tier":5}]}
	check(h.set_filter(g,f) and Filter.matches(d,f),"filter all")
	var encoded: String=h.export_filter(g);check(h.import_filter(g,encoded) and not h.import_filter(g,encoded+"!"),"canonical filter codec")
	check(Transfer.new().prepare_data(g.portable_save_data(),db).error=="","filter and forge export schema")
	var reforge: Dictionary=h.reforge_state(g,["forge"],{})
	check(not reforge.is_empty() and reforge.inventory.sealed.forge==30 and Bag.retention_capacity(reforge.inventory,h.config)==10,"first reforge ten slots authoritative seal")
	check(reforge.hanging_modules.values().all(func(m):return not m.unlocked and m.level==0 and m.exp==0),"reforge resets hanging unlock and all growth")
	check(h.reforge_state(g,["forge"],{"forge":1}).is_empty(),"forged sealed thresholds refused")
	var invalid: Dictionary=g.portable_save_data();invalid.hyperspace=reforge.duplicate(true);invalid.hyperspace.inventory.sealed.forge=1
	check(Transfer.new().prepare_data(invalid,db).error=="format","forged threshold rejected on import")
	g.profile.hyperspace=reforge;g.profile.highestLevel=29
	check(not h.claim_sealed(g,"forge"),"seal waits for planet stage")
	g.profile.highestLevel=30;check(h.claim_sealed(g,"forge"),"seal available at reached stage")
	var presets: Dictionary=g.profile.hyperspace.inventory
	presets.presets=[{"name":"partial","drone_ids":["missing","forge"],"hanging_loadouts":{"missing":[],"forge":[]}}]
	check(Bag.valid(presets,h.config) and h.apply_preset(g,0) and presets.equipped==[],"missing preset entries legal")
	check(g.profile.hyperspace.inventory.equipped==["forge"],"partial preset equips present")
	var full=opened(db)
	for i in 210:check(Bag.insert(full.profile.hyperspace.inventory,Rewards.create_drone(R.restore("123"),full.hyperspace.config,"bulk:%d"%i,"white","laser",5,"1"),full.hyperspace.config),"bounded inventory")
	check(not Bag.has_space(full.profile.hyperspace.inventory,full.hyperspace.config),"warehouse overflow saturated")

	var probe=opened(db);var ph=probe.hyperspace
	var pd:=add(probe,"probe");pd.affixes=[{"key":"global_damage","tier":5,"value":0.05,"locked":false},{"key":"attack_speed","tier":4,"value":0.03,"locked":false}]
	for key in probe.profile.hyperspace.materials:probe.profile.hyperspace.materials[key]=100000
	var combat_rng: int=probe.rng.state
	var exploration_rng: String=probe.profile.hyperspace.random_state
	check(ph.forge(probe,request(probe,"probe","enable_omen")).error=="","explicit omen fixture")
	var pc: Dictionary=ph.config.duplicate(true);pc.tier_weights={"1":100000.0,"2":1.0,"3":1.0,"4":1.0,"5":1.0};ph.configure(pc)
	check(ph.forge(probe,request(probe,"probe","promote_affix")).error=="" and probe.profile.hyperspace.inventory.drones.probe.affixes[0].tier==4,"omen prioritizes T5 and successful promotion only one tier")
	check(probe.rng.state==combat_rng and probe.profile.hyperspace.random_state==exploration_rng,"forge RNG isolated")
	probe.profile.hyperspace.materials.glueball=0
	baseline=probe.profile.hyperspace.duplicate(true)
	check(ph.forge(probe,request(probe,"probe","lock_affix")).error=="insufficient_materials" and probe.profile.hyperspace==baseline,"failed cost rollback RNG and command")
	probe.profile.hyperspace.materials.glueball=100000
	check(ph.forge(probe,request(probe,"probe","add_hanging_slot")).error==("hanging_limit" if probe.profile.hyperspace.inventory.drones.probe.hanging_slots>=2 else ""),"hanging hard cap")
	var first_module: String=ph.config.hanging_modules.keys()[0]
	Rewards.credit_modules(probe.profile.hyperspace,ph.config,{first_module:1})
	probe.profile.hyperspace.inventory.drones.probe.hanging_slots=2
	check(not ph.attach_hangings(probe,"probe",[first_module,first_module]),"same drone duplicate hanging denied")
	check(ph.attach_hangings(probe,"probe",[first_module]),"unlocked hanging attaches")
	var synthetic: Dictionary=probe.profile.hyperspace.duplicate(true)
	var weights_config: Dictionary=ph.config.duplicate(true);weights_config.quality_weights={"white":0.0,"blue":0.0,"gold":0.0,"legendary":0.0,"ultimate_core":1.0};weights_config.policies.core_reward="exclusive"
	var core: Dictionary=Rewards.generate(synthetic,weights_config,{"round_id":1,"run_id":1,"route":"alpha","level":5},"1")
	check(core.reward.drone.is_empty() and core.reward.ultimate_cores==1 and State.valid_reward(core.reward,"alpha",weights_config),"exclusive core reward is separate item")
	var alt: Dictionary=ph.config.duplicate(true);alt.policies.core_reward=null
	check(Rewards.generate(synthetic,alt,{"round_id":1,"run_id":1,"route":"alpha","level":5},"1").error=="core_reward_policy_required","undefined core policy explicit gate")
	check(probe.rng.state==combat_rng,"reward creation never consumes combat stream")
	var invalid_bindings: Dictionary=probe.portable_save_data();invalid_bindings.hyperspace.auto={"enabled":true,"route":"alpha","level":5,"crew_id":"captain"}
	check(not Permission.bindings_valid(invalid_bindings,db.data,ph.config),"unavailable crew save binding rejected")
	var writer:=preload("res://scripts/progress_writer.gd").new();writer.path=ProjectSettings.globalize_path("user://stage2-current-only.json")
	var valid_disk: Dictionary=g.portable_save_data()
	var write_error:=writer.write_progress(JSON.stringify(valid_disk).to_utf8_buffer())
	check(write_error==OK and JSON.stringify(writer.read_progress(writer.path).hyperspace)==JSON.stringify(JSON.parse_string(JSON.stringify(valid_disk.hyperspace))),"current safe writer roundtrip")
	invalid_bindings=valid_disk.duplicate(true);invalid_bindings.hyperspace.inventory.sealed.forge=1
	var file:=FileAccess.open(writer.path+".tmp",FileAccess.WRITE);file.store_string(JSON.stringify(invalid_bindings));file.close()
	check(JSON.stringify(writer.read_progress(writer.path).hyperspace)==JSON.stringify(JSON.parse_string(JSON.stringify(valid_disk.hyperspace))),"forged temporary save never replaces current committed file")
	var chance_rng:=RandomNumberGenerator.new();chance_rng.seed=20261004
	var hanging_count:=0;var affix_count:=0
	for i in 20000:
		hanging_count+=Rewards.count_slots(chance_rng,4,0.2,0.25)
		affix_count+=Rewards.count_slots(chance_rng,3,1.0,0.25)
	check(absf(hanging_count/20000.0-(0.2+0.05+0.0125+0.003125))<0.015,"independent hanging probabilities distribution")
	check(absf(affix_count/20000.0-(1.0+0.25+0.0625))<0.02,"independent affix probabilities distribution")
	var reforged_game=opened(db);add(reforged_game,"retained")
	var retained_module: String=reforged_game.hyperspace.config.hanging_modules.keys()[0]
	Rewards.credit_modules(reforged_game.profile.hyperspace,reforged_game.hyperspace.config,{retained_module:2})
	reforged_game.profile.hyperspace.inventory.drones.retained.hanging_slots=1
	check(reforged_game.hyperspace.attach_hangings(reforged_game,"retained",[retained_module]),"retained drone hanging fixture")
	reforged_game.profile.resources={"1":1234.0,"2":5678.0};reforged_game.profile.chronoParticles=123
	reforged_game.profile.planets["1"].degree=400;reforged_game.planet_buildings.sync(reforged_game,"1");reforged_game.profile.planets["1"].buildings.shipyard.status="built"
	check(reforged_game.reforge_planet("1",["retained"]),"actual root reforge command")
	check(reforged_game.profile.resources=={"1":1234.0,"2":5678.0} and reforged_game.profile.chronoParticles==123 and reforged_game.profile.planets["1"].conquered,"root permanent growth preserved")
	check(reforged_game.profile.hyperspace.inventory.sealed.retained==30 and reforged_game.profile.hyperspace.round_id==2,"root reforge sealed namespace")
	check(reforged_game.profile.hyperspace.inventory.drones.retained.hangings==[retained_module] and not reforged_game.profile.hyperspace.hanging_modules[retained_module].unlocked and reforged_game.profile.hyperspace.hanging_modules[retained_module].level==0,"sealed layout retained but current global unlock and growth reset")
	for action in ["keep_matches","clear_matches"]:
		var filtered_game=opened(db);var filtered_config: Dictionary=filtered_game.hyperspace.config.duplicate(true)
		filtered_config.quality_weights={"white":1.0,"blue":0.0,"gold":0.0,"legendary":0.0,"ultimate_core":0.0};filtered_game.hyperspace.configure(filtered_config)
		check(filtered_game.hyperspace.set_filter(filtered_game,{"version":2,"enabled":true,"mode":"all","action":action,"conditions":[{"field":"weapon","value":"laser"}]}),"explicit filter action applies")
		var receipt: Dictionary=filtered_game.hyperspace.start(filtered_game,"alpha",5,"manual")
		check(filtered_game.hyperspace.complete(filtered_game,receipt.round_id,receipt.run_id,true),"explicit filter completion")
		check(filtered_game.profile.hyperspace.active.reward.drone.is_empty()==(action=="clear_matches"),"filter action controls actual frozen reward")
		var roundtrip_filter:=Filter.import_string(filtered_game.hyperspace.export_filter(filtered_game),filtered_config)
		check(roundtrip_filter.action==action,"action roundtrips in rule string")
	var start:=Time.get_ticks_usec()
	for i in 6000:full.hyperspace.advance(full,0.016)
	print("IDLE_US ",Time.get_ticks_usec()-start," namespace_bytes ",JSON.stringify(full.profile.hyperspace).length())
	print("HYPERSPACE_CURRENT ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
