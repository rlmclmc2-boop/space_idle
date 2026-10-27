extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
	if not ClassDB.class_exists("SpaceCombatKernel"):
		assert(GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))==GDExtensionManager.LOAD_STATUS_OK)
	var session=load("res://src/game_session.gd").new()
	var initialized:Dictionary=session.initialize("res://generated/config.json",123)
	assert(initialized.ok,JSON.stringify(initialized))
	assert(session.campaign_system.start_sortie(1,session.equipment.clear_switch_locks).ok)
	var ship_ids:Array=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var start:int=1
	for row in config.unlock.unlock:
		if str(row.type)=="ship":start=maxi(start,int(row.level))
	assert(session.campaign_system.accept_reforge(session.campaign_system.save_state(),start).ok)
	assert(session._publish_progress().ok)
	var hs=session.hyperspace_system
	var ids:Array=[]
	for index in 6:
		var drone:Dictionary=hs._generate_reward({"route":"alpha","level":10,"run_id":index+1,"luck_state":"1"}).drone
		assert(not drone.is_empty())
		drone.id="capacity-fixture-"+str(index)
		drone.legendary=false;drone.ultimate=false;drone.legendary_effect={};drone.ultimate_affix={}
		hs._warehouse.append(drone);ids.append(drone.id)
	for index in ship_ids.size():
		var hull:String=ship_ids[index]
		var capacity:int=index+1
		assert(int(session.campaign_system.ship_facts(hull).drone_capacity)==capacity)
		assert(session.commit_ship_refit(hull).ok)
		var equipped:Dictionary=session.equip_hyperspace_drones(ids.slice(0,capacity))
		assert(equipped.ok,JSON.stringify(equipped))
		var before:Array=hs.equipped_ids()
		var rejected:Dictionary=session.equip_hyperspace_drones(ids.slice(0,capacity+1))
		assert(not rejected.ok and rejected.reason=="DroneCapacityExceeded")
		assert(hs.equipped_ids()==before)
		print("HULL_CAPACITY ",hull," ",capacity," NATIVE_EQUIP_OK OVERFLOW_REJECTED")
	# A smaller hull still truncates equipped objects through the existing transaction.
	assert(session.commit_ship_refit("Frigate").ok)
	assert(hs.equipped_ids().size()==1)
	assert(session.campaign_system.ship_facts("Heavy_Battleship").drone_capacity==5)
	# Global maximum is a separate domain cap, even when a caller passes a larger hull capacity.
	var global_rejected:Dictionary=hs.prepare_loadout(ids,999,session._hyperspace_weapon_source())
	assert(not global_rejected.ok and global_rejected.reason=="DroneCapacityExceeded")
	# Current table is the authority, not a hardcoded 1..5 lookup in Campaign.
	var alternate:Dictionary=config.duplicate(true)
	alternate.hyperspace_config["舰型容量"][1].capacity=3
	var campaign=load("res://src/systems/campaign.gd").new(alternate,session.campaign_system._parameters,session.campaign_system._rules,session.run_state)
	assert(campaign.ship_facts("Destroyer").drone_capacity==3)
	print("SMALL_HULL_TRUNCATION_GLOBAL_MAX_AND_TABLE_AUTHORITY_OK")
	print("CAPACITY_PROBE_COMPLETE")
	quit(0)
