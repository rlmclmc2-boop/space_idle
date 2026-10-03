extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Database=preload("res://scripts/balance_database.gd")
func run_wave(record:Dictionary,weapon:String,delta:int,factor:=1.0) -> Dictionary:
	var db=Database.new()
	db.levels[0]=db.levels[0].duplicate(true)
	db.levels[0].groups=[{"id":int(record.group_id),"position":0.0}]
	for ratio in ["atkRatio","lifeRatio","resRatio"]:db.levels[0][ratio]=1.0
	var seen := {}
	for eid in db.groups[str(int(record.group_id))].slots:
		if eid!=null and not seen.has(str(int(eid))):
			seen[str(int(eid))]=true;db.enemies[str(int(eid))].dmgMultiple*=factor
	var g=Game.new(db);g.rng.seed=1701;g.stat_cache_enabled=true
	g.profile.selectedShip="Destroyer";g.profile.grantedUnlocks=[db.unlock_id("ship","Destroyer")]
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.crew=[];g.profile.enhancementLevel=0
	g.profile.loadout={"weapons":[],"defence":[]}
	var level:int=int(record.base_level)+delta
	for index in 4:g.profile.loadout.weapons.append({"key":weapon,"level":level})
	g.profile.loadout.defence=[{"key":"shield","level":level},{"key":"armour","level":level}]
	g.start(1,false);g.spawn_group()
	var result:="timeout"
	for step in 7200:
		g.tick(1.0/60.0)
		if g.state==BattleGame.State.RETREAT:result="loss";break
		if not g.has_alive_enemy():result="win";break
	return {"result":result,"seconds":g.simulated_time,"armour":g.player.armour,"shield":g.player.shield,"rng_state":str(g.rng.state)}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var db=Database.new()
	var f=FileAccess.open("res://.runtime/wave-matrix.jsonl",FileAccess.WRITE)
	var count:=0
	for key in db.data.battle_design:
		var record:Dictionary=db.data.battle_design[key]
		for weapon in ["laser","missile","cannon","longLaser"]:
			for delta in [0,1,2,3]:
				var row:Dictionary=run_wave(record,weapon,delta)
				row.merge({"key":key,"weapon":weapon,"delta":delta,"seed":1701,"tier":record.tier,"scope":"exact rule fixture; no presentation geometry; raw module upgrades are diagnostic, not fresh progression"})
				f.store_line(JSON.stringify(row));f.flush();count+=1
		print("MATRIX_GROUP ",key," rows=",count)
	f.close();print("MATRIX_COMPLETE rows=",count," data_sha256=",FileAccess.get_sha256("res://data/game_data.json"));quit()
