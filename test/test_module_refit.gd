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
	game.profile.resources={"1":1e20,"2":1e20}
	game.profile.selectedShip="Cruiser"
	game.ensure_loadout()
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
	var before: Dictionary=game.profile.resources.duplicate()
	var module := game.slot_entry("weapons",0)
	module.attacks=45
	module.hits=12
	for key in BattleGame.WEAPON_KEYS:
		check(game.equip_slot("weapons",0,key),"Free replacement "+key)
		check(game.slot_entry("weapons",0).level==10 and game.slot_entry("weapons",0).attacks==45,"Module assets retained "+key)
		check(game.slot_upgrade_cost("weapons",0)==cost and game.profile.resources==before,"Same module cost and no refit charge "+key)
	check(game.unequip_slot("weapons",0),"Unload module")
	check(game.slot_entry("weapons",0).level==10 and game.profile.resources==before,"Empty module retains investment and counters")
	check(game.upgrade_slot("weapons",0),"Empty active module can upgrade")
	check(game.equip_slot("weapons",0,"laser") and game.slot_entry("weapons",0).level==11,"New weapon inherits empty module level")
	game.player.armour=game.stat("armour")*0.35
	check(game.equip_slot("defence",1,"armour"),"Duplicate defense allowed despite legacy limit")
	check(is_equal_approx(game.player.armour/game.stat("armour"),0.35),"Adding defense preserves health fraction")
	check(game.equip_slot("defence",1,"shield"),"Switch armor to shield")
	game.player.shield=game.max_shield()*0.4
	check(game.unequip_slot("defence",1) and game.equip_slot("defence",1,"shield"),"Zero-capacity cycle")
	check(is_equal_approx(game.player.shield/game.max_shield(),0.4),"Zero capacity cannot reset damage fraction")
	before=game.profile.resources.duplicate()
	check(game.switch_ship("Heavy_Battleship"),"Switch ship in live encounter")
	check([game.stage,game.distance,game.group_index,game.state,game.paused,game.profile.loop,game.profile.guardStage,game.run_resources]==travel,"Ship change preserves journey pause and guard")
	check(game.enemies==enemies and game.drops==drops and is_same(game.player,player),"Ship change preserves entities and player identity")
	check(game.profile.resources==before and game.slot_entry("weapons",0).level==11,"Ship change neither refunds nor resets growth")
	check(game.weapon_entries().size()==5 and game.defense_entries().size()==3,"Ship only changes active capacity")
	for i in 5:check(game.equip_slot("weapons",i,"laser"),"Unlimited duplicates fill slot "+str(i))
	game.upgrade_slot("weapons",4,4)
	game.slot_entry("weapons",4).attacks=789
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
	check(game.switch_ship("Heavy_Battleship") and game.slot_entry("weapons",4).level==5 and game.slot_entry("weapons",4).attacks==789,"Large ship restores module growth and history")
	check(game.slot_entry("weapons",4).attacks==789 and float(game.cooldowns.weapons_4)==float(db.equip("laser",5).cd),"Restored module retains counters and starts valid cooldown")
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
	game.save_enabled=true
	game.save_progress()
	var loaded := BattleGame.new(db,true)
	loaded.save_enabled=false
	check(loaded.module_entry("weapons",4).level==5,"Save retains dormant assets")
	check(loaded.slot_entry("weapons",0).level==11 and loaded.slot_entry("weapons",0).key=="","Save retains empty module assets without legacy name override")
	print("Module refit: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
