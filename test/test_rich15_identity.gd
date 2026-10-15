extends SceneTree
# Resolves the exact rich15 source actor from qa_battle_consistency_real.gd.
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false)
	var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
	g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
	g.profile.resources={"1":1e80,"2":1e80};g.profile.loadout={"weapons":[],"defence":[]}
	for key in ["missile","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
	for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
	g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
	var template=g.enemies[0].duplicate(true);g.enemies.clear()
	for i in 15:
		var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
		g.enemies.append(e)
	var rows:Array=[];var archetypes:Dictionary={};var ship_keys:Dictionary={};var textures:Dictionary={}
	for enemy in g.enemies:
		var archetype:=str(enemy.get("archetype_id",""))
		var key:String=scene.enemy_ship_key(enemy) if scene.has_method("enemy_ship_key") else "enemy_"+str(clampi(int(enemy.size),1,6))
		var path:String=scene.ship_hull_texture(key).resource_path
		archetypes[archetype]=int(archetypes.get(archetype,0))+1
		ship_keys[key]=int(ship_keys.get(key,0))+1
		textures[path]=int(textures.get(path,0))+1
		rows.append({"uid":int(enemy.uid),"id":int(enemy.id),"archetype_id":archetype,"ship_key":key,"texture":path})
	var result={"stage":g.stage,"group_index":g.group_index,"count":g.enemies.size(),"archetypes":archetypes,"ship_keys":ship_keys,"textures":textures,"rows":rows,"save":g.save_enabled}
	FileAccess.open("res://.runtime/rich15-identity.json",FileAccess.WRITE).store_string(JSON.stringify(result)+"\n")
	print("RICH15_IDENTITY ",JSON.stringify(result))
	quit()
