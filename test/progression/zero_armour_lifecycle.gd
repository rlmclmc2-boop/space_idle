extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
var checkpoint:Dictionary
func _initialize():call_deferred("run")
func fixture():
	var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
	var raw:Dictionary=checkpoint.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
	g.load_progress_data(raw);g.profile.chronoParticles=float(raw.get("chronoParticles",0));g.login_chrono_particles=0
	g.save_enabled=false;g.change_state(BattleGame.State.LEVEL_SELECT)
	g.metrics=Metrics.new();g.metrics.initialize(g)
	return g
func run():
	var input:=OS.get_environment("PROGRESSION_WAVE_CHECKPOINT");assert(not input.is_empty())
	checkpoint=JSON.parse_string(FileAccess.get_file_as_string(input))
	var rows:Array=[]
	for weapon in ["mixed","laser","missile","cannon","longLaser"]:
		var g=fixture();var driver=Driver.new();driver.ui_refresh_seconds=1.0;driver.setup(self,g)
		if weapon!="mixed":
			for index in g.weapon_entries().size():assert(g.equip_slot("weapons",index,weapon))
		for index in g.loadout_entries("defence").size():
			var level_before:int=int(g.loadout_entries("defence")[index].level)
			assert(g.equip_slot("defence",index,"shield"))
			assert(int(g.loadout_entries("defence")[index].level)==level_before)
		assert(float(g.stat("armour"))==0 and float(g.stat("shield"))>0)
		var resources_before:Dictionary=g.profile.resources.duplicate(true)
		assert(not g.start(33,false))
		assert(not g.is_active() and g.state==BattleGame.State.LEVEL_SELECT)
		assert(g.profile.resources==resources_before and g.metrics.kills==0)
		assert(driver.scene.message==UIText.t("battle.zero_armour"))
		rows.append({"weapon":weapon,"all_shield_equip_allowed":true,"start_allowed":false,"armour":g.stat("armour"),"shield":g.stat("shield"),"feedback":driver.scene.message})
		driver.close();await process_frame
	var live=fixture();var view=Driver.new();view.ui_refresh_seconds=1.0;view.setup(self,live)
	assert(live.start(33,false));live.spawn_group()
	var cleared_before:Array=live.profile.cleared.duplicate()
	for index in live.loadout_entries("defence").size():assert(live.equip_slot("defence",index,"shield"))
	assert(live.state==BattleGame.State.RETREAT and live.metrics.deaths==1)
	for step in 120:
		view.before_tick(1.0/60.0);live.tick(1.0/60.0);view.after_tick(1.0/60.0)
	assert(live.state==BattleGame.State.LEVEL_SELECT and not live.is_active())
	assert(live.metrics.kills==0 and live.metrics.deaths==1 and live.profile.cleared==cleared_before)
	var recovered_level:int=int(live.loadout_entries("defence")[0].level)
	assert(live.equip_slot("defence",0,"armour"))
	assert(int(live.loadout_entries("defence")[0].level)==recovered_level)
	assert(live.start(33,false) and live.is_active())
	rows.append({"scope":"live last-armour refit","one_native_retreat":true,"no_combat_or_clear_while_zero_hp":true,"public_armour_refit_restart":true})
	view.close();await process_frame
	var result:={"pass":true,"checkpoint":input,"scope":"Native public refits/start; full-shield layout remains selectable, zero life cannot fight; no injected HP/resources/immunity. Existing crew automation during2s retreat retained.","cases":rows}
	var dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");assert(not dir.is_empty())
	FileAccess.open(dir.path_join("zero-armour-lifecycle.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ZERO_ARMOUR_LIFECYCLE_PASS ",JSON.stringify(result));quit()
