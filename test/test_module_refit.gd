extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(message)
func _initialize() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax=0
	db.config.equipmentSwitchCooldownSeconds=0 # Isolate refit ownership; lock timing is tested separately.
	db.config.autoGenRes=""
	var game := BattleGame.new(db,false)
	game.profile.cleared=range(1,60)
	game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	game.economy.credit_many({"1":1e20,"2":1e20})
	game.rebuild_unlocks()
	check(game.switch_ship("Cruiser"),"Initial hull selection")
	game.reset_player()
	game.start(4,false)
	game.spawn_group()
	game.profile.loop=true
	game.profile.guardStage=4
	game.profile.guardDistance=game.distance
	game.paused=true
	var travel := [game.stage,game.distance,game.group_index,game.state,game.paused,game.profile.loop,game.profile.guardStage,game.run_resources.duplicate(true)]
	var enemies: Array=game.enemies.duplicate()
	var drops: Array=game.drops.duplicate()
	var player: Dictionary=game.player
	check(game.upgrade_slot("weapons",0,9),"Upgrade module to level 10")
	var cost := game.slot_upgrade_cost("weapons",0)
	var before: Dictionary=game.economy.resources().duplicate()
	var module := game.slot_entry("weapons",0)
	check(module.is_read_only() and game.weapon_entries().is_read_only(),"Read views cannot write module state")
	var detached:=game.equipment.save_data();detached.loadout.weapons[0].level=999
	check(game.slot_entry("weapons",0).level==10,"Exported snapshot cannot write module state")
	for key in BattleGame.WEAPON_KEYS:
		check(game.equip_slot("weapons",0,key),"Free replacement "+key)
		check(game.slot_entry("weapons",0).level==10,"Module assets retained "+key)
		check(game.slot_upgrade_cost("weapons",0)==cost and game.economy.resources()==before,"Same module cost and no refit charge "+key)
	check(game.unequip_slot("weapons",0),"Unload module")
	check(game.slot_entry("weapons",0).level==10 and game.economy.resources()==before,"Empty module retains investment")
	var source:=game.slot_entry("weapons",0)
	check(game.upgrade_slot("weapons",0),"Empty active module can upgrade")
	check(game.same_module(source,game.slot_entry("weapons",0)) and not is_same(source,game.slot_entry("weapons",0)),"Numeric growth preserves source identity without writable references")
	check(game.equip_slot("weapons",0,"laser") and game.slot_entry("weapons",0).level==11,"New weapon inherits empty module level")
	game.player.armour=game.stat("armour")*0.35
	check(game.equip_slot("defence",1,"armour"),"Duplicate defense allowed despite legacy limit")
	check(is_equal_approx(game.player.armour/game.stat("armour"),0.35),"Adding defense preserves health fraction")
	check(game.equip_slot("defence",1,"shield"),"Switch armor to shield")
	game.player.shield=game.max_shield()*0.4
	check(game.unequip_slot("defence",1) and game.equip_slot("defence",1,"shield"),"Zero-capacity cycle")
	check(is_equal_approx(game.player.shield/game.max_shield(),0.4),"Zero capacity cannot reset damage fraction")
	before=game.economy.resources().duplicate()
	check(game.switch_ship("Heavy_Battleship"),"Switch ship in live encounter")
	check([game.stage,game.distance,game.group_index,game.state,game.paused,game.profile.loop,game.profile.guardStage,game.run_resources]==travel,"Ship change preserves journey pause and guard")
	check(game.enemies==enemies and game.drops==drops and is_same(game.player,player),"Ship change preserves entities and player identity")
	check(game.economy.resources()==before and game.slot_entry("weapons",0).level==11,"Ship change neither refunds nor resets growth")
	check(game.weapon_entries().size()==5 and game.defense_entries().size()==3,"Ship only changes active capacity")
	for i in 5:check(game.equip_slot("weapons",i,"laser"),"Unlimited duplicates fill slot "+str(i))
	game.upgrade_slot("weapons",4,4)
	game.cooldowns.weapons_4=0.2
	game.cooldowns["drone:sentinel"]=0.7
	game.jewel_charged["drone:sentinel"]=true
	var dormant: Dictionary=game.slot_entry("weapons",4)
	check(game.switch_ship("Frigate"),"Switch to smaller hull")
	check(game.weapon_entries().size()==1 and game.module_entries("weapons").size()==5,"Dormant modules retained outside active view")
	check(game.cooldowns.get("drone:sentinel")==0.7 and game.jewel_charged.has("drone:sentinel"),"Physical module invalidation preserves independent drone state")
	check(game.slot_entry("weapons",4).is_empty() and is_same(game.module_entry("weapons",4),dormant),"Dormant identity and configuration survive")
	check(not game.can_upgrade_slot("weapons",4) and not game.cooldowns.has("weapons_4"),"Dormant module has no active purchase or cooldown")
	var expected := 0.0
	for entry in game.weapon_entries():expected+=game.jewel_equipment_stat(entry)
	check(is_equal_approx(game.stat("laser"),expected),"Dormant weapons contribute no stats")
	check(game.switch_ship("Heavy_Battleship") and game.slot_entry("weapons",4).level==5,"Large ship restores module growth")
	check(float(game.cooldowns.weapons_4)==float(db.equip("laser",5).cd),"Restored module starts valid cooldown")
	# Existing flights are snapshots; only replaced/deactivated module attacks cancel.
	var ordinary := {"beam":false,"dead":false,"hostile":false,"mount":4,"damage":123.0}
	var beam := {"beam":true,"dead":false,"hostile":false,"mount":4}
	var common_beam := {"beam":true,"dead":false,"hostile":false,"mount":0}
	game.projectiles.assign([ordinary,beam,common_beam])
	game.jewel_repeats=[{"index":4,"entry":game.slot_entry("weapons",4),"remaining":0.3,"multiplier":1.0},{"index":0,"entry":game.slot_entry("weapons",0),"remaining":0.3,"multiplier":1.0}]
	game.jewel_charged={"weapons_4":2.0,"weapons_0":2.0}
	game.switch_ship("Frigate")
	check(beam.dead and not common_beam.dead,"Only deactivated module beam is interrupted")
	check(not ordinary.dead and ordinary.damage==123.0 and game.projectiles.has(ordinary),"In-flight projectile retains snapshotted damage")
	check(game.jewel_repeats.size()==1 and game.jewel_repeats[0].index==0 and not game.jewel_charged.has("weapons_4"),"Dormant module repeat and charge cannot leak")
	game.cooldowns.weapons_0=0.37
	game.equip_slot("weapons",0,"laser")
	check(is_equal_approx(game.cooldowns.weapons_0,0.37),"Same equipment selection preserves cooldown")
	game.equip_slot("weapons",0,"cannon")
	check(common_beam.dead and game.jewel_repeats.is_empty() and not game.jewel_charged.has("weapons_0"),"Replacement cancels old beam repeat and charge")
	check(game.cooldowns.weapons_0==float(db.equip("cannon",game.slot_entry("weapons",0).level).cd),"Replacement starts full new weapon cooldown")
	game.unequip_slot("weapons",0)
	var loaded := BattleGame.new(db,false)
	loaded.load_progress_data(game.portable_save_data())
	check(loaded.module_entry("weapons",4).level==5,"Portable snapshot retains dormant assets")
	check(loaded.slot_entry("weapons",0).level==11 and loaded.slot_entry("weapons",0).key=="","Portable snapshot retains empty module assets without legacy name override")
	# Every notification reads the complete wallet + batch or hull + drone commit.
	var atomic:=BattleGame.new(db,false)
	atomic.profile.cleared=range(1,60);atomic.rebuild_unlocks()
	atomic.economy.credit_many({"1":1e20,"2":1e20,db.evolution_material_id():1000000})
	var upgraded:=atomic.equipment.save_data();upgraded.loadout.weapons[0].level=19
	check(atomic.equipment.install_snapshot(upgraded,db),"Evolution boundary fixture validates")
	var observations:Array=[]
	var observer:=func(kind,_data):
		if kind in ["resources_changed","upgrade","hyperspace_changed","ship_changed"]:observations.append(atomic.portable_save_data())
	atomic.event.connect(observer)
	var material_before:int=atomic.economy.balance(db.evolution_material_id())
	var evolution:Dictionary=atomic.slot_upgrade_cost("weapons",0,1)
	check(atomic.upgrade_equipment_batch("1"),"Whole ordered batch crosses evolution boundary")
	var committed:=atomic.portable_save_data()
	check(not observations.is_empty() and observations.all(func(value):return value.loadout==committed.loadout and value.resources==committed.resources and value.materials==committed.materials),"Every batch notification sees all module levels and both resource kinds committed")
	check(atomic.economy.balance(db.evolution_material_id())==material_before-int(evolution[db.evolution_material_id()]),"Evolution material stays exact and follows displayed quote")
	check(atomic.switch_ship("Heavy_Battleship"),"Prepare larger drone hull")
	var random:=RandomNumberGenerator.new();random.seed=88
	var ids:Array=[]
	for i in int(atomic.hyperspace.config.hull_capacities.Frigate)+1:
		var drone:=preload("res://scripts/drone_rewards.gd").create_drone(random,atomic.hyperspace.config,"hull_"+str(i),"white","laser",1,"1")
		var hs:Dictionary=atomic.hyperspace.save_data();preload("res://scripts/drone_inventory.gd").insert(hs.hyperspace.inventory,drone,atomic.hyperspace.config);assert(atomic.hyperspace.install_snapshot(hs,atomic.db));ids.append(drone.id)
	check(atomic.hyperspace_runtime.set_equipped(atomic,ids),"Prepare equipped drones beyond smaller hull capacity")
	observations.clear()
	check(atomic.switch_ship("Frigate"),"Hull and clipped drone selection commit together")
	committed=atomic.portable_save_data()
	check(observations.size()>=2 and observations.all(func(value):return value.selectedShip=="Frigate" and value.loadout==committed.loadout and value.hyperspace.inventory.equipped==committed.hyperspace.inventory.equipped),"Hull notifications cannot observe the old module or drone selection")
	atomic.event.disconnect(observer)
	# Exercise the changed production generation adapters with one legal record.
	var generator:=preload("res://scripts/player_loadout_generator.gd").new(db)
	var options:=generator.default_options();options.count=1;options.cleared_through=0;options.module_level=1
	var generated:Dictionary=generator.generate(options)
	check(generated.results.size()==1,"Generate one current-configuration loadout")
	var record:Dictionary=generated.results[0]
	print("CURRENT STARTER hull=",record.ship," weapons=",record.equipment.weapons.size()," defences=",record.equipment.defence.size()," stats=",record.stats)
	var upgraded_snapshot:Dictionary=generator.upgraded_profile(db,record,generator.rules.portable_save_data(),1)
	check(not upgraded_snapshot.has("error"),"Generator upgrade returns complete current-format snapshot")
	if not upgraded_snapshot.has("error"):
		var private_db:=ShipDatabase.new()
		var fleet:Dictionary=private_db.groups[str(int(private_db.levels[0].groups[0].id))].duplicate(true)
		var battle=generator.start_validated_battle(private_db,fleet,record,91,"exact",upgraded_snapshot)
		check(battle.equipment.selected_ship()==record.ship and battle.slot_entry("weapons",0).level==2 and battle.state==BattleGame.State.COMBAT,"Prepared battle installs the upgraded equipment owner and spawns")
	print("Module refit: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
