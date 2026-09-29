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
	db.config.autoGenRes=""
	var game := BattleGame.new(db,false)
	game.profile.cleared=range(1,60)
	game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	game.profile.resources={"1":1e20,"2":1e20}
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
	module.sockets=[game.new_jewel("5")]
	module.attacks=45
	module.hits=12
	for key in BattleGame.WEAPON_KEYS:
		check(game.equip_slot("weapons",0,key),"Free replacement "+key)
		check(game.slot_entry("weapons",0).level==10 and game.slot_entry("weapons",0).sockets.size()==1 and game.slot_entry("weapons",0).attacks==45,"Module assets retained "+key)
		check(game.slot_upgrade_cost("weapons",0)==cost and game.profile.resources==before,"Same module cost and no refit charge "+key)
	check(game.unequip_slot("weapons",0),"Unload module")
	check(game.slot_entry("weapons",0).level==10 and game.slot_entry("weapons",0).sockets.size()==1 and game.profile.resources==before,"Empty module retains investment and gem")
	check(game.jewel_effects(game.slot_entry("weapons",0)).is_empty(),"Empty module effects are inactive")
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
	check(game.weapon_entries().size()==8 and game.defense_entries().size()==4,"Ship only changes active capacity")
	for i in 8:check(game.equip_slot("weapons",i,"laser"),"Unlimited duplicates fill slot "+str(i))
	game.upgrade_slot("weapons",7,4)
	game.slot_entry("weapons",7).sockets=[game.new_jewel("5")]
	game.slot_entry("weapons",7).attacks=789
	game.cooldowns.weapons_7=0.2
	var dormant: Dictionary=game.slot_entry("weapons",7)
	check(game.switch_ship("Frigate"),"Switch to smaller hull")
	check(game.weapon_entries().size()==3 and game.module_entries("weapons").size()==8,"Dormant modules retained outside active view")
	check(game.slot_entry("weapons",7).is_empty() and is_same(game.module_entry("weapons",7),dormant),"Dormant identity and configuration survive")
	check(not game.can_upgrade_slot("weapons",7) and not game.cooldowns.has("weapons_7"),"Dormant module has no active purchase or cooldown")
	var expected := 0.0
	for entry in game.weapon_entries():expected+=game.jewel_equipment_stat(entry)
	check(is_equal_approx(game.stat("laser"),expected),"Dormant weapons contribute no stats")
	check(game.switch_ship("Heavy_Battleship") and game.slot_entry("weapons",7).level==5 and game.slot_entry("weapons",7).attacks==789,"Large ship restores module growth and history")
	check(game.slot_entry("weapons",7).sockets.size()==1 and float(game.cooldowns.weapons_7)==float(db.equip("laser",5).cd),"Restored module retains gem and starts valid cooldown")
	# Existing flights are snapshots; only replaced/deactivated module attacks cancel.
	var ordinary := {"beam":false,"dead":false,"hostile":false,"mount":7,"damage":123.0}
	var beam := {"beam":true,"dead":false,"hostile":false,"mount":7}
	var common_beam := {"beam":true,"dead":false,"hostile":false,"mount":1}
	game.projectiles.assign([ordinary,beam,common_beam])
	game.jewel_repeats=[{"index":7,"entry":game.slot_entry("weapons",7),"remaining":0.3,"multiplier":1.0},{"index":1,"entry":game.slot_entry("weapons",1),"remaining":0.3,"multiplier":1.0}]
	game.jewel_charged={"weapons_7":2.0,"weapons_1":2.0}
	game.switch_ship("Frigate")
	check(beam.dead and not common_beam.dead,"Only deactivated module beam is interrupted")
	check(not ordinary.dead and ordinary.damage==123.0 and game.projectiles.has(ordinary),"In-flight projectile retains snapshotted damage")
	check(game.jewel_repeats.size()==1 and game.jewel_repeats[0].index==1 and not game.jewel_charged.has("weapons_7"),"Dormant module repeat and charge cannot leak")
	game.cooldowns.weapons_1=0.37
	game.equip_slot("weapons",1,"laser")
	check(is_equal_approx(game.cooldowns.weapons_1,0.37),"Same equipment selection preserves cooldown")
	game.equip_slot("weapons",1,"cannon")
	check(common_beam.dead and game.jewel_repeats.is_empty() and not game.jewel_charged.has("weapons_1"),"Replacement cancels old beam repeat and charge")
	check(game.cooldowns.weapons_1==float(db.equip("cannon",game.slot_entry("weapons",1).level).cd),"Replacement starts full new weapon cooldown")
	game.unequip_slot("weapons",0)
	game.save_enabled=true
	game.save_progress()
	var loaded := BattleGame.new(db,true)
	loaded.save_enabled=false
	check(loaded.module_entry("weapons",7).level==5 and loaded.module_entry("weapons",7).sockets.size()==1,"Save retains dormant assets")
	check(loaded.slot_entry("weapons",0).level==11 and loaded.slot_entry("weapons",0).sockets.size()==1 and loaded.slot_entry("weapons",0).key=="","Save retains empty module assets without legacy name override")
	print("Module refit: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
