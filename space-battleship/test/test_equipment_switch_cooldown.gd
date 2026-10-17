extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func fixture() -> BattleGame:
	var game := BattleGame.new(ShipDatabase.new(),false)
	for key in ["cannon","shield"]:
		if not game.profile.unlocked.has(key):game.profile.unlocked.append(key)
	return game

func _initialize() -> void:
	var game := fixture()
	check(game.equipment_switch_remaining("weapons",0)==0.0,"fresh weapon slot ready")
	check(game.equip_slot("weapons",0,"cannon"),"first weapon switch succeeds")
	check(is_equal_approx(game.equipment_switch_remaining("weapons",0),10.0),"configured ten game seconds")
	check(not game.equip_slot("weapons",0,"laser") and not game.unequip_slot("weapons",0),"both switch paths reject cooldown")
	game.profile.resources={"1":1e20,"2":1e20}
	check(game.can_upgrade_slot("weapons",0) and game.upgrade_slot("weapons",0),"normal upgrade works during switch cooldown")
	check(game.equip_slot("weapons",0,"cannon"),"same equipment no-op remains safe")
	check(game.equipment_switch_remaining("defence",0)==0.0 and game.equip_slot("defence",0,"shield"),"defense slot independent")
	game.paused=true
	game.tick(5.0)
	check(is_equal_approx(game.equipment_switch_remaining("weapons",0),10.0),"pause does not spend cooldown")
	game.paused=false
	game.speed=3.0
	game.tick(3.0) # main passes one real second multiplied by speed.
	check(is_equal_approx(game.equipment_switch_remaining("weapons",0),7.0),"boosted game seconds spend cooldown")
	game.tick(7.0)
	check(game.equipment_switch_remaining("weapons",0)==0.0 and game.equip_slot("weapons",0,"laser"),"boundary permits switch")
	game.db.config.equipmentSwitchCooldownSeconds=2.0
	game.tick(10.0)
	check(game.equip_slot("weapons",0,"cannon") and is_equal_approx(game.equipment_switch_remaining("weapons",0),2.0),"duration follows configuration")
	var saved: Dictionary = game.portable_save_data()
	var restored := fixture()
	restored.profile.productionElapsed=1000.0 # Portable import can replace an active profile.
	restored.load_progress_data(saved)
	check(is_equal_approx(restored.equipment_switch_remaining("weapons",0),2.0),"cooldown restores against saved production clock")
	game.clear_level()
	check(game.equipment_switch_remaining("weapons",0)==0.0 and game.equipment_switch_remaining("defence",0)==0.0,"stage clear clears every slot")
	var wave := fixture()
	check(wave.start(1,false),"nonfinal encounter starts")
	wave.spawn_group()
	check(not wave.is_final_encounter() and wave.equip_slot("weapons",0,"cannon"),"nonfinal encounter has a refit cooldown")
	wave.enemies.clear()
	wave.finish_combat_step(0.0)
	check(wave.state==BattleGame.State.TRAVEL and wave.equipment_switch_remaining("weapons",0)==0.0,"nonfinal battle point clears cooldown")
	var native_wave := fixture()
	check(native_wave.start(1,false),"native waiting fixture starts")
	native_wave.spawn_group()
	check(native_wave.equip_slot("weapons",0,"cannon"),"native waiting fixture has cooldown")
	native_wave.enemies.clear()
	native_wave.native_wave_waiting=true
	native_wave.tick(0.01)
	check(native_wave.state==BattleGame.State.TRAVEL and native_wave.equipment_switch_remaining("weapons",0)==0.0,"native completion handoff clears cooldown")
	var multi := fixture()
	multi.profile.selectedShip="Destroyer"
	multi.profile.loadout=multi.default_loadout("Destroyer",multi.profile.unlocked)
	multi.reset_player()
	check(multi.equip_slot("weapons",0,"cannon"),"two-slot fixture switches first weapon")
	multi.tick(5.0)
	check(multi.equipment_switch_remaining("weapons",1)==0.0 and multi.equip_slot("weapons",1,"laser"),"second weapon slot switches independently")
	check(is_equal_approx(multi.equipment_switch_remaining("weapons",0),5.0) and is_equal_approx(multi.equipment_switch_remaining("weapons",1),10.0),"same-category slots have separate deadlines")
	var fallen := fixture()
	check(fallen.equip_slot("weapons",0,"cannon"),"death fixture switches")
	fallen.player.armour=0.0
	fallen.player.shield=0.0
	fallen.begin_retreat()
	check(fallen.equipment_switch_remaining("weapons",0)==0.0,"death clears cooldown")
	print("EQUIPMENT_SWITCH_COOLDOWN checks=",checks," failures=",failures)
	quit(1 if failures else 0)
