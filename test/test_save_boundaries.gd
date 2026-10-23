extends SceneTree

class RefusingGalaxy extends "res://scripts/galaxy_system.gd":
	func install_snapshot(_raw:Dictionary,_db)->bool:return false
class RefusingLoad extends BattleGame:
	func create_load_candidate(database:ShipDatabase)->BattleGame:
		var candidate:=BattleGame.new(database,false)
		candidate.galaxy=RefusingGalaxy.new()
		return candidate
class RefusingRollback extends "res://scripts/save_transfer.gd":
	func rollback(_transaction:Dictionary)->Error:return ERR_FILE_CANT_WRITE

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func finish() -> void:
	print("Save boundaries: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remember(data: Dictionary) -> void:
	var file := FileAccess.open("user://expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t",true,true))
	file.close()

func _initialize() -> void:
	var area := ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\", "/")
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(area), "Uses isolated player data")
	var db := ShipDatabase.new()
	db.config.offlineMax = 0
	var phase := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "write"
	if phase != "write":
		reopen(db, phase)
		return
	var rejected:=RefusingLoad.new(db,false)
	var prior:=rejected.portable_save_data()
	var incoming:=prior.duplicate(true);incoming.resources["1"]=99999.0
	rejected.load_progress_data(incoming)
	var after_rejected:=rejected.portable_save_data()
	for key in ["chronoSavedAt","hightechSavedAt"]:
		prior.erase(key);after_rejected.erase(key)
	check(rejected.hyperspace.last_error=="domain_install_failed" and after_rejected==prior,"Late private owner refusal leaves all live domains unchanged")
	check(rejected.lifecycle.ready(),"Rejected private load retains old authority")
	var reloadable:=BattleGame.new(db,false)
	for i in 5:reloadable.economy.credit("1",1.0)
	var old_revision:int=reloadable.economy.revision
	var reload_snapshot:=reloadable.portable_save_data()
	reloadable.state=BattleGame.State.COMBAT
	reloadable.enemies.append({"retired":true});reloadable.projectiles.append({"retired":true})
	reloadable.player.armour=0;reloadable.cooldowns["retired"]=1.0
	reloadable.load_progress_data(reload_snapshot)
	check(reloadable.lifecycle.ready() and reloadable.economy.revision>old_revision,"Private replacement preserves monotonic owner versions for existing consumers")
	check(reloadable.state==BattleGame.State.MAIN_MENU and reloadable.enemies.is_empty() and reloadable.projectiles.is_empty() and reloadable.cooldowns.is_empty() and GrowthNumber.compare(reloadable.player.armour,reloadable.stat("armour"))==0,"Memory load installs prepared player and retires old combat session")
	var lab=preload("res://scripts/balance_game.gd").new(db)
	lab.player_power_multiplier=2.0;lab.simulated_time=123.0
	lab.pending_hits.append({"retired":true});lab.repair_cache_active=true
	lab.load_progress_data(reload_snapshot)
	check(lab.lifecycle.ready() and lab.simulated_time==123.0 and lab.pending_hits.is_empty() and not lab.repair_cache_active and GrowthNumber.compare(lab.player.armour,lab.stat("armour"))==0,"Lab replacement preserves simulation policy while retiring stale derived session")
	check_reforge_owners(db)
	var game := BattleGame.new(db, true)
	check(game.save_enabled and game.progress_writer.owns_progress(), "Real native writer lock is held")
	var frozen:=BattleGame.new(db,false)
	frozen.lifecycle.fail("test_recovery","disk")
	var frozen_before:=frozen.portable_save_data()
	frozen.economy.credit("1",100000.0)
	var balance=frozen.economy.balance("1")
	frozen.tick(1.0);frozen.advance_hightech(1.0)
	check(not frozen.upgrade_slot("weapons",0,1) and frozen.economy.balance("1")==balance and not frozen.step_progress.active,"Recovery state gates commands and time even when unpaused")
	frozen.save_enabled=true;frozen.progress_writer.path="user://blocked-save.json";frozen.save_progress()
	check(not FileAccess.file_exists(frozen.progress_writer.path),"Recovery state gates manual/autosave writes")
	var refusing_transfer:=RefusingRollback.new()
	var txgame:=BattleGame.new(db,false);txgame.progress_writer.path="user://lifecycle-progress.json"
	check(txgame.progress_writer.acquire_owner(),"Replacement test owns isolated writer")
	var transaction:=txgame.lifecycle.import_progress(txgame,txgame.portable_save_data(),refusing_transfer)
	check(transaction.error==OK and txgame.lifecycle.state=="installing","Disk success waits for actual scene installation")
	var outcome:=txgame.lifecycle.reload_failed(ERR_CANT_CREATE)
	check(outcome.rollback==ERR_FILE_CANT_WRITE and not txgame.lifecycle.ready() and FileAccess.file_exists(transaction.primary),"Failed rollback preserves recovery state and disk evidence")
	game.profile.cleared = range(1,61)
	game.rebuild_unlocks()
	game.economy.credit("2", 10000.0)
	game.economy.credit_fragments(123.45)
	game.economy.credit_many({"degenerate_matter":9000000000000000-2,"ultimate_cores":11})
	check(game.upgrade_reactor(1) and game.set_reactor_allocation("weapons",31),"Prepare reactor allocation for persistence boundary")
	var exchange:=game.hyperspace_material_exchange_quote("degenerate_matter","antiproton",7)
	check(game.exchange_hyperspace_materials(exchange.request).error=="","Commit exchange receipt before real disk write")
	game.economy.credit("1",100)
	check(game.select_tech("weapon_accuracy") and game.set_tech_input("1",10),"Start research with paid input before disk save")
	game.advance_hightech(1.0)
	game.economy.credit("1",100000.0)
	check(game.switch_ship("Heavy_Battleship") and game.upgrade_slot("weapons",4,3),"Prepare invested dormant module")
	check(game.equip_slot("weapons",4,"missile") and game.switch_ship("Frigate"),"Store switch deadline on dormant module")
	game.economy.credit_fragments(1e12)
	check(game.upgrade_enhancement(30)==30 and game.set_enhancement_order("weapons",["critical","repeat","proficiency"]) and game.set_enhancement_branch("weapons","critical",3,"B"),"Persist purchased enhancement, reordered effects and branch choice")
	var history:=game.enhancement_growth.save_data();history.enhancementAttacks="9007199254740993";history.enhancementHits="9007199254740995"
	check(game.enhancement_growth.install_snapshot(history),"Exact history fixture exceeds JSON double integer precision")
	check(preload("res://scripts/native_execution_compiler.gd").new().compile(game,"native_low_contract").error=="unsupported_native_counter","History beyond native exact range is rejected before double conversion")
	check(game.assign_crew("navigator","reactor_upgrade","reactor") and game.set_crew_upgrade_mode("navigator","10"),"Crew assignment and selected purchase amount commit before save")
	check(game.add_crew_exp("navigator",game.crew.required_exp(game,0)+game.crew.required_exp(game,1)+7),"Crew earns multiple levels and remainder before save")
	check(game.start_planet_exploration("1","engineer"),"Begin an ordinary trip before persistence");game.advance_planets(0.25)
	game.galaxy_runtime.refresh_unlocks(game)
	check(game.assign_crew("researcher","galaxy_explore","galaxy_1"),"Dispatch galaxy crew before saving pending work")
	game.galaxy_runtime.advance(game,0.25)
	check(game.galaxy.pending("galaxy_1")==0.25 and game.galaxy.income_time()==0.25 and not game.profile.has("galaxies"),"Galaxy owner keeps online work and income time before save")
	check(game.stat_cache_enabled,"Real persistence enables contribution caches")
	var base_capacity = game.reactor_capacity()
	var rng:=RandomNumberGenerator.new();rng.seed=234
	var drone:=preload("res://scripts/drone_rewards.gd").create_drone(rng,game.hyperspace.config,"save-storage","white","laser",5,"1")
	drone.affixes=[];drone.hanging_slots=4;drone.hangings=[]
	var hs:Dictionary=game.hyperspace.save_data()
	preload("res://scripts/drone_inventory.gd").insert(hs.hyperspace.inventory,drone,game.hyperspace.config)
	hs.hyperspace.hanging_modules.extra_storage={"unlocked":true,"level":2,"exp":0.0}
	check(game.hyperspace.install_snapshot(hs,db),"storage fixture installs")
	check(game.hyperspace_runtime.set_equipped(game,[drone.id]) and game.hyperspace_runtime.attach_hangings(game,drone.id,["extra_storage"]),"Equip valid storage hanging before disk save")
	var capacity = game.reactor_capacity()
	check(capacity>base_capacity and game.set_reactor_allocation("weapons",capacity),"Persist allocation above capacity without storage")
	check(game.start(14,false),"Start original stage before challenge save")
	game.spawn_group();game.player.armour=1.0
	check(game.start_hyperspace_challenge("alpha"),"Save during a real manual challenge")
	hs=game.hyperspace.save_data();hs.hyperspace.history.beta={"1":3.0};check(game.hyperspace.install_snapshot(hs,db),"background history fixture installs")
	check(game.start_hyperspace_idle("beta"),"Prepare simultaneous background reward")
	var idle:Dictionary=game.hyperspace.state.idle
	check(game.hyperspace_runtime.complete(game,int(idle.round_id),int(idle.run_id),true),"Background result freezes before file commit")
	check(game.claim_hyperspace(int(idle.round_id),int(idle.run_id)) and game.hyperspace.receipt_marker().unread,"Claim records unread reward before any panel exists")
	check(game.start_hyperspace_idle("beta"),"Keep another background receipt for reopen")
	idle=game.hyperspace.state.idle
	check(game.hyperspace_runtime.complete(game,int(idle.round_id),int(idle.run_id),true),"Next pending reward coexists with previous unread claim")
	check(game.economy.credit_many({"1":{"m":4.2,"e":700.0},"2":{"m":3.14,"e":320.0},"jewel":{"m":2.2,"e":410.0}}),"Current format stores finite large ordinary balances")
	game.hyperspace.add_online_time(0.125)
	game.save_progress()
	check(game.last_save_error == OK and not game.save_dirty, "Current committed snapshot writes successfully")
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var saved: Dictionary = JSON.parse_string(original)
	var transfer := preload("res://scripts/save_transfer.gd").new()
	check(transfer.prepare_data(saved, db).error == "", "Written current format passes pure validation")
	var sparse := saved.duplicate(true)
	sparse.erase("reactorAllocation")
	check(not transfer.prepare_data(sparse, db).error.is_empty(), "Incomplete current state is rejected")
	remember(saved)
	finish()

func reopen(db: ShipDatabase, phase: String) -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://expected.json"))
	# GrowthNumber keeps ordinary inputs as floats and large inputs as {m,e}.
	# Preserve the written JSON representation; integer coercion breaks equality.
	for member in saved.crew:member.level=int(member.level)
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var restored := BattleGame.new(db, true)
	restored.resume_progress()
	check(restored.stage==14 and restored.state==restored.State.TRAVEL and restored.distance==0 and restored.group_index==0 and restored.enemies.is_empty() and restored.player.armour==restored.stat("armour"),"Real reopen/recovery starts the return stage with fresh health and no old battle")
	check(restored.hyperspace.state.active.is_empty() and restored.hyperspace.state.idle==saved.hyperspace.idle and restored.hyperspace.state.random_state==saved.hyperspace.random_state,"Interrupted manual receipt settles while pending reward and reward RNG survive")
	check(restored.hyperspace.state.pending_time==0.125 and not restored.profile.has("hyperspace") and not restored.profile.has("hyperspaceReceipt"),"Current disk format preserves pending clock only in hyperspace owner")
	check(restored.hyperspace.receipt_marker()==saved.hyperspaceReceipt and restored.hyperspace.receipt_marker().unread,"Claimed unread receipt persists independently of pending reward and UI")
	check(restored.economy.balance("1")==saved.resources["1"] and restored.economy.balance("2")==saved.resources["2"] and restored.economy.balance("jewel")==saved.jewelFragments,"Scientific ordinary wallet survives real reopen alongside exact materials and history")
	check(restored.startup_error.is_empty() and restored.progress_writer.owns_progress(), "Fresh game reopens with real persistence enabled")
	check(restored.galaxy.pending("galaxy_1")==0.25 and restored.galaxy.pending_crew("galaxy_1")==1 and restored.galaxy.income_time()==0.25,"Reopen/recovery preserves both pending online work and unclaimed income time")
	check(restored.galaxy.regions.galaxy_1.state.build_elapsed==0.0 and str(restored.galaxy.regions.galaxy_1.random.state)==saved.galaxies.galaxy_1.rng_state,"Reopen/recovery neither settles pending work nor advances galaxy RNG")
	check(restored.stat_cache_enabled and float(restored.hyperspace_totals().hangings.get("extra_storage",0))>0,"Reopen/recovery builds enabled cache from restored hanging")
	check(restored.reactor.allocations()==saved.reactorAllocation and restored.reactor.allocation("weapons")==restored.reactor_capacity(),"Reopen/recovery preserves above-base allocation before crew scheduling: actual=%s saved=%s capacity=%s"%[restored.reactor.allocations(),saved.reactorAllocation,restored.reactor_capacity()])
	check(restored.crew.allocation_dependencies==restored.crew.reactor_allocation_state(restored,"navigator"),"Crew schedule captures final restored capacity and allocation")
	check(restored.equipment.selected_ship()==saved.selectedShip and restored.module_entry("weapons",4).level==4 and restored.module_entry("weapons",4).key=="missile" and restored.equipment.save_data().equipmentSwitchUntil==saved.equipmentSwitchUntil,"Disk reopen/recovery preserves hull, dormant investment and switch deadline")
	check(restored.enhancement_level()==30 and restored.enhancement_order("weapons")==["critical","repeat","proficiency"] and restored.enhancement_branch_choice("weapons","critical",3)=="B" and restored.enhancement_growth.attacks()==9007199254740993 and restored.enhancement_growth.hits()==9007199254740995,"Reopen/recovery preserves shared enhancement and exact history without JSON rounding")
	check(restored.crew.save_data().crew==saved.crew and restored.crew.entry(restored,"navigator").level==2 and restored.crew.entry(restored,"navigator").exp==7,"Reopen/recovery keeps complete crew assignment, mode, growth and remainder")
	check(restored.planets.save_data().planets==saved.planets and restored.planet_progress("1").crewId=="engineer" and restored.planet_progress("1").elapsed==0.25,"Reopen/recovery preserves active exploration without offline completion")
	if phase == "latest":
		check(restored.economy.resources() == saved.latest, "Second real process reopen selects latest commit")
		var damaged := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
		damaged.store_string("{broken")
		damaged.close()
		finish()
		return
	if phase == "recovery":
		check(restored.economy.resources() == saved.resources and restored.economy.balance("degenerate_matter")==int(saved.materials.degenerate_matter) and restored.hyperspace.state.last_command==saved.hyperspace.last_command and restored.research.progress("weapon_accuracy")==saved.aiTechProgress.weapon_accuracy, "Corrupt primary recovers complete backup including exact wallet and command receipt")
		check(original == "{broken", "Recovery read preserves rejected primary bytes")
		restored.save_progress()
		check(restored.last_save_error == OK and FileAccess.get_file_as_string(BattleGame.SAVE_PATH + ".rejected") == "{broken", "Recovery write retains rejected bytes")
		finish()
		return
	check(restored.economy.balance("degenerate_matter")==int(saved.materials.degenerate_matter) and restored.economy.balance("ultimate_cores")==int(saved.ultimateCores) and not restored.hyperspace.state.has("materials"),"Real reopen restores exact integer wallet into economic authority")
	var research_parts := {"selected":restored.research.selected()==saved.aiTechActive,"paid_progress":restored.research.progress("weapon_accuracy")==saved.aiTechProgress.weapon_accuracy,"input":restored.research.save_data().aiTechInput==saved.aiTechInput,"owner":not restored.profile.has("aiTechProgress")}
	if research_parts.values().has(false):
		print("RESEARCH_RESTORE ",JSON.stringify({"parts":research_parts,"actual_input":restored.research.save_data().aiTechInput,"expected_input":saved.aiTechInput,"actual_type":typeof(restored.research.save_data().aiTechInput["1"]),"expected_type":typeof(saved.aiTechInput["1"])}))
	check(not research_parts.values().has(false),"Real reopen restores selected research, paid progress and input to its owner")
	var wallet_before:=restored.economy.material_wallet()
	var retry:=restored.exchange_hyperspace_materials({"round_id":1,"command_seq":1,"source":"degenerate_matter","target":"antiproton","amount":7})
	check(retry.error=="" and retry.amount==7 and restored.economy.material_wallet()==wallet_before,"Reopened exchange retries cached receipt without a second debit")
	var unchanged:=restored.portable_save_data()
	var invalids:Array=[]
	var bad:=unchanged.duplicate(true);bad.reactorAllocation.weapons=-1;invalids.append(bad)
	bad=saved.duplicate(true);bad.erase("latest");bad.hyperspace.active.return_target.stage=99999;invalids.append(bad)
	bad=unchanged.duplicate(true);bad.hyperspaceReceipt.unread=1;invalids.append(bad)
	bad=unchanged.duplicate(true);bad.galaxies.galaxy_1.slots[0].work=-1.0;invalids.append(bad)
	bad=unchanged.duplicate(true);bad.loadout.weapons[0].level=-1;invalids.append(bad)
	bad=unchanged.duplicate(true);bad.enhancementOrder.weapons=["critical","critical","repeat"];invalids.append(bad)
	bad=unchanged.duplicate(true);bad.crew[0].assignmentType="missing_job";invalids.append(bad)
	bad=unchanged.duplicate(true);bad.planets["1"].crewId="navigator";invalids.append(bad)
	for candidate in invalids:
		candidate.resources["1"]=999;restored.load_progress_data(candidate)
		check(stable_save(restored)==stable_data(unchanged),"Invalid domain rejects before installing any wallet, growth or session state")
	restored.hyperspace.last_error = ""
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH + ".tmp")
	restored.economy.credit("1", 7)
	restored.save_progress()
	check(restored.last_save_error != OK and restored.save_dirty, "Failed write retains dirty state")
	check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH) == original, "Failed write preserves the committed bytes")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH + ".tmp")
	restored.save_progress()
	check(restored.last_save_error == OK and FileAccess.file_exists(BattleGame.SAVE_PATH + ".bak"), "Retry keeps the prior valid recovery copy")
	saved.latest = restored.economy.resources()
	remember(saved)
	finish()

func stable_save(g)->Dictionary:
	var data:Dictionary=g.portable_save_data()
	data.erase("chronoSavedAt");data.erase("hightechSavedAt")
	return data

func stable_data(data:Dictionary)->Dictionary:
	var result:=data.duplicate(true);result.erase("chronoSavedAt");result.erase("hightechSavedAt");return result

func check_reforge_owners(db:ShipDatabase)->void:
	var g:=BattleGame.new(db,false)
	g.profile.cleared=range(1,61);g.rebuild_unlocks()
	var planets:=g.portable_save_data();planets.planets["1"].degree=1000
	for row in g.planet_buildings.rows(g,"1"):
		planets.planets["1"].buildings[str(row.id)].status="built"
		planets.planets["1"].buildings[str(row.id)].build_progress=float(row.build_explore)
	check(g.planets.install_snapshot(planets,db),"Prepare owner-backed completed facilities for reforge")
	var rng:=RandomNumberGenerator.new();rng.seed=234
	var drone:=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"retained","white","laser",30,"1")
	drone.affixes=[];drone.hanging_slots=1;drone.hangings=[]
	var hs:=g.hyperspace.save_data()
	preload("res://scripts/drone_inventory.gd").insert(hs.hyperspace.inventory,drone,g.hyperspace.config)
	hs.hyperspace.hanging_modules.extra_storage={"unlocked":true,"level":2,"exp":0.0}
	check(g.hyperspace.install_snapshot(hs,db) and g.hyperspace_runtime.attach_hangings(g,"retained",["extra_storage"]),"Prepare retained drone using current owners")
	g.economy.credit_many({"1":1234.0,"2":5678.0,"chrono":123.0,"jewel":55.0,"degenerate_matter":7,"ultimate_cores":2})
	var wallet:=g.economy.resources();var chrono=g.economy.balance("chrono")
	check(g.reforge_planet("1",["retained"]),"Reforge installs complete private domain and session candidate")
	check(g.lifecycle.ready() and g.economy.resources()==wallet and g.economy.balance("chrono")==chrono and g.planet_progress("1").conquered,"Reforge preserves ordinary reserves and publishes conquest together")
	check(g.hyperspace.state.round_id==2 and g.hyperspace.state.inventory.sealed.get("retained")==int(db.data.unlock[db.data.planet["1"].unlockId].level) and g.hyperspace.state.inventory.drones.retained.hangings==["extra_storage"],"Reforge keeps selected drone layout in sealed namespace")
	check(not g.hyperspace.state.hanging_modules.extra_storage.unlocked and g.hyperspace.state.hanging_modules.extra_storage.level==0 and g.economy.balance("degenerate_matter")==0 and g.economy.balance("ultimate_cores")==0 and g.economy.balance("jewel")==0,"Reforge resets current hanging growth and run-only balances")
