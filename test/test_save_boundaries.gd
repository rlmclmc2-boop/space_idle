extends SceneTree

var checks := 0
var failures := 0
var observed: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func observe(kind: String, _payload: Dictionary, game: BattleGame) -> void:
	if kind == "resources_changed":observed.append(game.portable_save_data())

func finish() -> void:
	print("Save boundaries: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remember(data: Dictionary) -> void:
	var file := FileAccess.open("user://expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
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
	var game := BattleGame.new(db, true)
	check(game.save_enabled and game.progress_writer.owns_progress(), "Real native writer lock is held")
	game.profile.cleared = range(1,60)
	game.rebuild_unlocks()
	game.economy.credit("2", 10000.0)
	game.economy.credit_fragments(123.45)
	game.economy.credit_many({"degenerate_matter":9000000000000000-2,"ultimate_cores":11})
	var before = game.economy.balance("2")
	var quoted = game.reactor_upgrade_cost()
	var observer := observe.bind(game)
	game.event.connect(observer)
	check(game.upgrade_reactor(1), "Reactor purchase commits")
	game.event.disconnect(observer)
	check(observed.size() == 1 and observed[0].reactorLevel == 2 and observed[0].resources["2"] == before - quoted, "Notification and save snapshot see the complete purchase")
	check(not FileAccess.file_exists(BattleGame.SAVE_PATH), "Purchase does not write a partial save")
	check(game.set_reactor_allocation("weapons", 31), "Allocate reactor before save")
	var detached := game.economy.resources()
	detached["2"] = 0
	var detached_reactor := game.reactor.allocations()
	detached_reactor.weapons = 0
	check(game.economy.balance("2") == before - quoted and game.reactor.allocation("weapons") == 31, "Read views cannot mutate authoritative domains")
	check(not game.profile.has("resources") and not game.profile.has("reactorLevel") and not game.profile.has("reactorAllocation") and not game.profile.has("jewelFragments") and not game.profile.has("chronoParticles"), "Profile no longer owns migrated state")
	var rejected := game.portable_save_data()
	rejected.resources["2"] = -1
	var prior := game.portable_save_data()
	game.load_progress_data(rejected)
	check(game.economy.save_data().resources == prior.resources and game.reactor.level() == prior.reactorLevel, "Invalid load leaves both domains unchanged")
	game.hyperspace.last_error = ""
	var exchange:=game.hyperspace_material_exchange_quote("degenerate_matter","antiproton",7)
	check(game.exchange_hyperspace_materials(exchange.request).error=="","Commit exchange receipt before real disk write")
	game.economy.credit("1",100)
	check(game.select_tech("weapon_accuracy") and game.set_tech_input("1",10),"Start research with paid input before disk save")
	game.advance_hightech(1.0)
	game.economy.credit("1",100000.0)
	check(game.switch_ship("Heavy_Battleship") and game.upgrade_slot("weapons",4,3),"Prepare invested dormant module")
	check(game.equip_slot("weapons",4,"missile") and game.switch_ship("Frigate"),"Store switch deadline on dormant module")
	check(not game.profile.has("loadout") and not game.profile.has("selectedShip") and not game.profile.has("equipmentSwitchUntil"),"Profile no longer owns equipment or switch deadlines")
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
	# JSON numbers are doubles; this fixture's small integer allocations are exact.
	for key in saved.reactorAllocation:saved.reactorAllocation[key] = int(saved.reactorAllocation[key])
	for key in saved.aiTechInput:saved.aiTechInput[key] = int(saved.aiTechInput[key])
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var restored := BattleGame.new(db, true)
	check(restored.startup_error.is_empty() and restored.progress_writer.owns_progress(), "Fresh game reopens with real persistence enabled")
	check(restored.equipment.selected_ship()==saved.selectedShip and restored.module_entry("weapons",4).level==4 and restored.module_entry("weapons",4).key=="missile" and restored.equipment.save_data().equipmentSwitchUntil==saved.equipmentSwitchUntil,"Disk reopen/recovery preserves hull, dormant investment and switch deadline")
	if phase == "latest":
		check(restored.economy.resources() == saved.latest, "Second real process reopen selects latest commit")
		var damaged := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
		damaged.store_string("{broken")
		damaged.close()
		finish()
		return
	if phase == "recovery":
		check(restored.economy.resources() == saved.resources and restored.economy.balance("degenerate_matter")==int(saved.materials.degenerate_matter) and restored.profile.hyperspace.last_command==saved.hyperspace.last_command and restored.research.progress("weapon_accuracy")==saved.aiTechProgress.weapon_accuracy, "Corrupt primary recovers complete backup including exact wallet and command receipt")
		check(original == "{broken", "Recovery read preserves rejected primary bytes")
		restored.save_progress()
		check(restored.last_save_error == OK and FileAccess.get_file_as_string(BattleGame.SAVE_PATH + ".rejected") == "{broken", "Recovery write retains rejected bytes")
		finish()
		return
	check(restored.economy.balance("degenerate_matter")==int(saved.materials.degenerate_matter) and restored.economy.balance("ultimate_cores")==11 and not restored.profile.hyperspace.has("materials"),"Real reopen restores exact integer wallet into economic authority")
	check(restored.economy.resources() == saved.resources and restored.economy.balance("jewel") == saved.jewelFragments and restored.reactor.level() == saved.reactorLevel and restored.reactor.allocations() == saved.reactorAllocation, "Save/reopen preserves balances, reactor level and allocations")
	check(restored.research.selected()==saved.aiTechActive and restored.research.progress("weapon_accuracy")==saved.aiTechProgress.weapon_accuracy and restored.research.save_data().aiTechInput==saved.aiTechInput and not restored.profile.has("aiTechProgress"),"Real reopen restores selected research, paid progress and input to its owner")
	var wallet_before:=restored.economy.material_wallet()
	var retry:=restored.exchange_hyperspace_materials({"round_id":1,"command_seq":1,"source":"degenerate_matter","target":"antiproton","amount":7})
	check(retry.error=="" and retry.amount==7 and restored.economy.material_wallet()==wallet_before,"Reopened exchange retries cached receipt without a second debit")
	var unchanged := restored.portable_save_data()
	var bad := unchanged.duplicate(true)
	bad.reactorAllocation.weapons = -1
	restored.load_progress_data(bad)
	check(restored.reactor.allocations() == saved.reactorAllocation and restored.economy.resources() == saved.resources, "Invalid allocation cannot install resources first")
	var bad_equipment:=unchanged.duplicate(true)
	bad_equipment.loadout.weapons[0].level=-1;bad_equipment.resources["1"]=999
	restored.load_progress_data(bad_equipment)
	check(restored.module_entry("weapons",0).level==unchanged.loadout.weapons[0].level and restored.economy.resources()==saved.resources,"Invalid equipment rejects the whole snapshot before any balance install")
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
