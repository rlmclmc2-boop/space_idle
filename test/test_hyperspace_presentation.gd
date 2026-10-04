extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
var ordinary_calls:=0
var drone_calls:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func ordinary_pose(_mount: int,_aim: Vector2,_ordinal: int) -> Dictionary:
	ordinary_calls+=1
	return {"position":Vector2(250,400),"direction":Vector2.UP}
func drone_pose(id: String,_aim: Vector2,_ordinal: int) -> Dictionary:
	drone_calls+=1
	check(id=="presented","provider receives stable drone identity")
	return {"position":Vector2(300,400),"direction":Vector2.UP}
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=Presented.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks()
	var rng:=RandomNumberGenerator.new();rng.seed=8
	var d:=Rewards.create_drone(rng,g.hyperspace.config,"presented","blue","missile",5,"1")
	d.affixes=[];Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);g.hyperspace.set_equipped(g,[d.id]);g.state=g.State.COMBAT
	var enemy: Dictionary={"uid":1,"hp":100000.0,"max_hp":100000.0,"x":280.0,"y":100.0,"armourType":99,"slot":0,"equipment":[],"drops":[],"res_ratio":1.0}
	g.enemies=[enemy];g.launch_provider=ordinary_pose;g.drone_launch_provider=drone_pose
	var index:=g.weapon_entries().size();var entry: Dictionary=g.combat_entry(index)
	g.begin_enhancement_attack(index,enemy);var attack: Dictionary=g.jewel_attack(index)
	var weapon: Dictionary=g.player_weapon_row(entry)
	for i in 2:g.launch_player_attack(index,enemy,weapon,attack,g.player_weapon_offset(index),0.0,i,2)
	g.finish_enhancement_attack(index);g.tick_projectiles(0.0)
	check(drone_calls==1 and ordinary_calls==0,"drone never indexes ordinary tube provider")
	check(g.projectiles[0].launch_point==Vector2(300,400),"visible launch point follows drone provider")
	check(is_same(g.projectiles[0].combat_context,attack.combat_context),"delayed ejection preserves batch context")
	g.invalidate_stat_cache();g.motion_clock=g.EJECTION_GAP;g.tick_projectiles(0.0)
	check(drone_calls==2 and g.cancelled_ejections==0 and g.missile_queue.is_empty(),"unrelated projection change preserves queued missile source")
	check(is_same(g.projectiles[0].combat_context,g.projectiles[1].combat_context),"salvo shares one target debuff batch")
	g.hyperspace.set_equipped(g,[])
	check(g.combat_weapon_entries().size()==g.weapon_entries().size(),"unequip removes only independent drone sources")
	print("HYPERSPACE_PRESENTATION ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
