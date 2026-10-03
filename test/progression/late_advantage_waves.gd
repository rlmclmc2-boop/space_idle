extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():call_deferred("run")
func run():
	var path:=OS.get_environment("PROGRESSION_WAVE_CHECKPOINT")
	assert(not path.is_empty())
	var checkpoint:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var stage:int=int(OS.get_environment("PROGRESSION_WAVE_STAGE"))
	if stage<=0:stage=20
	var node_text:=OS.get_environment("PROGRESSION_WAVE_NODES")
	if node_text.is_empty():node_text="9"
	var rows:Array=[]
	for node_string in node_text.split(","):
		var node:int=int(node_string)
		for weapon in ["mixed","longLaser","laser"]:
			var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true;g.simulated_time=float(checkpoint.x1_seconds)
			var raw:Dictionary=checkpoint.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
			g.load_progress_data(raw);g.profile.chronoParticles=float(raw.get("chronoParticles",0));g.login_chrono_particles=0
			g.rng.seed=1701;g.speed=1.0
			g.metrics=Metrics.new();g.metrics.initialize(g)
			if weapon!="mixed":
				assert(g.profile.unlocked.has(weapon))
				for index in g.weapon_entries().size():assert(g.equip_slot("weapons",index,weapon))
			g.start(stage,false)
			var driver=Driver.new();driver.ui_refresh_seconds=1.0;driver.setup(self,g)
			g.group_index=node-1;g.spawn_group()
			var initial:Dictionary={"loadout":g.profile.loadout.duplicate(true),"hightech":g.profile.hightechLevels.duplicate(true),"reactor":g.profile.reactorLevel,"enhancement":g.profile.enhancementLevel,"armour":g.stat("armour"),"shield":g.stat("shield"),"weapons":[],"enemies":[]}
			for entry in g.weapon_entries():initial.weapons.append({"key":entry.key,"level":entry.level,"effective_level":g.effective_equipment_level(int(entry.level)),"damage":g.equipment_stat(str(entry.key),int(entry.level))})
			for enemy in g.enemies:initial.enemies.append({"id":enemy.id,"hp":enemy.hp,"shield":enemy.shield,"armour_type":enemy.armourType,"shield_type":enemy.shieldType})
			var began:float=g.simulated_time
			var status:="timeout"
			for step in 36000:
				driver.before_tick(1.0/60.0);g.tick(1.0/60.0);driver.after_tick(1.0/60.0)
				if g.state==BattleGame.State.RETREAT:status="loss";break
				if not g.has_alive_enemy():status="win";break
			var row:Dictionary={"stage":stage,"node":node,"weapon":weapon,"status":status,"seconds":g.simulated_time-began,"seed":1701,"initial":initial,"final_loadout":g.profile.loadout.duplicate(true),"final_hightech":g.profile.hightechLevels.duplicate(true),"rng":str(g.rng.state)}
			rows.append(row);print("LATE_ADVANTAGE_WAVE ",JSON.stringify(row))
			FileAccess.open("res://.runtime/late-advantage-waves.json",FileAccess.WRITE).store_string(JSON.stringify({"checkpoint":path,"checkpoint_data":checkpoint.data_sha256,"current_data":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"scope":"Legal profile cloned into a selected battle point; public weapon refits preserve slot levels; full scene/event hook; no manual upgrades during wave, existing automatic growth retained; diagnostic only, no fresh-run timing claim","rows":rows},"\t"))
			driver.close();await process_frame
	quit()
