extends SceneTree
const Prototype=preload("res://dev/toon_ship/prototype_battle_game.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);printerr(message)
func sample(prototype:bool,key:String,partial:bool=false)->Dictionary:
	var source:=ShipDatabase.new()
	if partial:source.equipment["missile-mon"][0].para2=null
	var original:=JSON.stringify(source.data)
	var g=Prototype.new(source,false) if prototype else BattleGame.new(source,false)
	check(JSON.stringify(source.data)==original,"Construction must not mutate caller database")
	g.start(1,false);g.spawn_group()
	for entry in g.weapon_entries():entry.key=""
	g.player.armour=1e9;g.player.shield=1e9
	var enemy:Dictionary=g.enemies[0];g.enemies.clear();g.enemies.append(enemy)
	enemy.hp=1e9;enemy.equipment=[{"name":key}];enemy.cooldowns=[float(g.db.enemy_weapon(key).cd)]
	var records:Array=[]
	var clock:=[0]
	g.event.connect(func(kind,info):
		if kind=="fire" and bool(info.shot.hostile):
			var shot:Dictionary=info.shot
			records.append({"frame":clock[0],"damage":shot.damage,"speed":shot.speed,"direction":str(shot.direction)})
			check(not shot.get("prototype_missile",false),"Enemy must not enter phased missile motion"))
	for frame in 360:
		clock[0]=frame;g.tick(1.0/60.0)
	return {"records":records,"cooldown":enemy.cooldowns[0],"weapon":g.db.enemy_weapon(key)}
func _initialize()->void:
	var evidence:Dictionary={}
	for key in ["laser_mon","cannon-mon","missile-mon","missile_mon"]:
		var normal:=sample(false,key);var prototype:=sample(true,key)
		check(normal==prototype,"Enemy actual attack mismatch: "+key)
		evidence[key]=prototype
	check(sample(false,"missile-mon",true)==sample(true,"missile-mon",true),"Null field fallback must stay original")
	var source:=ShipDatabase.new();var g=Prototype.new(source,false)
	var repeated=Prototype.new(g.db,false)
	check(g.db.equip("missile",1)==repeated.db.equip("missile",1),"Repeated construction must not multiply player damage")
	g.start(1,false);g.spawn_group()
	for entry in g.weapon_entries():entry.key=""
	g.weapon_entries()[0].key="missile";g.cooldowns[g.slot_id("weapons",0)]=0
	var target:Dictionary=g.enemies[0];target.hp=1e9
	g.enemies.clear();g.enemies.append(target)
	g.tick(1.0/60.0);target.hp=0
	for frame in 90:g.tick(1.0/60.0)
	check(g.launch_records.size()==5 and g.missile_queue.is_empty(),"Player must finish five committed ejections")
	check(g.hit_records.is_empty(),"Dead target must not receive ghost damage")
	print("ENEMY_ISOLATION_CHECK ",JSON.stringify({"passed":failures.is_empty(),"errors":failures,"enemy":evidence,"player_launches":g.launch_records.size()}))
	quit(0 if failures.is_empty() else 1)
