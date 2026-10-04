extends SceneTree
const Balance=preload("res://scripts/balance_game.gd")
const Generator=preload("res://scripts/player_loadout_generator.gd")
const Simulator=preload("res://scripts/enemy_fleet_simulator.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const CC=preload("res://scripts/combat_context.gd")
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=Balance.new(db);g.profile.cleared=range(1,41);g.rebuild_unlocks()
	var rng:=RandomNumberGenerator.new();rng.seed=22
	var d:=Rewards.create_drone(rng,g.hyperspace.config,"balance-guide","legendary","missile",5,"1")
	d.legendary_effect={"effect_id":"precise_guidance","parameters":{}};d.affixes=[]
	Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);g.hyperspace.set_equipped(g,[d.id])
	var target: Dictionary={"uid":1,"hp":100000.0,"max_hp":100000.0,"x":200.0,"y":100.0,"armourType":99,"slot":0,"equipment":[],"drops":[],"res_ratio":1.0}
	g.enemies=[target]
	var context:=CC.root(1,"drone:balance-guide","missile")
	g.hit_enemy(target,10,2,[],false,context);g.hit_enemy(target,10,2,[],false,context)
	check(target.guidance_layers==1 and target.hp==99980,"production override forwards shared salvo context")
	g.hit_enemy(target,10,2,[],false,CC.derive(context,"repeat"))
	check(target.guidance_layers==1 and target.hp==99965,"production override preserves derived no-trigger permission")
	var generator:=Generator.new(db);var options: Dictionary=generator.default_options();options.count=4
	var generated: Dictionary=generator.generate(options)
	check(generated.status=="complete" and generated.results.size()==4,"production generator and simulator dependencies load")
	print("HYPERSPACE_BALANCE_CONTEXT ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
