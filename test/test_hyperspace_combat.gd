extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const CC=preload("res://scripts/combat_context.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func enemy(id: int,hp: float=100000) -> Dictionary:
	return {"uid":id,"hp":hp,"max_hp":hp,"x":100.0,"y":100.0,"armourType":99,"slot":id,"drops":[],"res_ratio":1.0}
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks();g.stat_cache_enabled=true
	var rng:=RandomNumberGenerator.new();rng.seed=1
	var d:=Rewards.create_drone(rng,g.hyperspace.config,"guide","legendary","missile",5,"1")
	d.legendary_effect={"effect_id":"precise_guidance","parameters":{}}
	d.affixes=[{"key":"global_damage","tier":5,"value":0.1,"locked":false}]
	Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
	var original=g.jewel_equipment_stat({"key":"laser","level":1})
	check(g.hyperspace.set_equipped(g,["guide"]),"equip uses authority")
	check(N.compare(g.jewel_equipment_stat({"key":"laser","level":1}),N.multiply(original,1.105))==0,"amplified global damage multiplicative")
	var projection: Dictionary=g.hyperspace_totals()
	check(is_same(projection,g.hyperspace_totals()),"same cached equipped projection")
	var a:=enemy(1);var b:=enemy(2);g.enemies=[a,b]
	var batch:=CC.root(1,"module:0","missile")
	for i in 5:g.hit_enemy(a,10,2,[],false,batch)
	check(a.hp==99950 and a.guidance_layers==1,"five missiles share frozen factor and one target stack")
	g.hit_enemy(b,10,2,[],false,batch)
	check(b.hp==99990 and b.guidance_layers==1,"same batch distinct target one stack")
	g.hit_enemy(a,10,2,[],false,CC.root(2,"module:0","missile"))
	check(a.hp==99935 and a.guidance_layers==2,"next batch benefits previous layer only")
	var derived:=CC.derive(batch,"repeat")
	g.hit_enemy(a,10,2,[],false,derived)
	check(a.hp==99912 and a.guidance_layers==2,"derived attack benefits debuff but never stacks")
	check(not CC.can_trigger(derived) and CC.derive(derived,"chain").is_empty(),"depth1 cannot derive")
	var dead:=enemy(3,1);g.enemies.append(dead);g.hit_enemy(dead,10,2,[],false,CC.root(3,"module:0","missile"))
	check(not dead.has("guidance_layers"),"death clears target debuff")
	# Existing on-hit and kill explosions obey the same permission, not local booleans.
	var iron: Dictionary={"kind":"iron","source":0,"p4":10,"p2":0.1,"level":1}
	g.hit_enemy(b,1,1,[iron],false,CC.derive(CC.root(4,"module:0","laser"),"chain"))
	check(not b.has("jewelIronSources"),"derived hit cannot trigger iron on-hit")
	var blast:=enemy(4,1);blast.jewelExplosion=1.0;g.enemies=[blast,b];var before: float=b.hp
	g.hit_enemy(blast,10,1,[],false,CC.derive(CC.root(5,"module:0","laser"),"explosion"))
	check(b.hp==before,"derived kill cannot trigger interference explosion")
	var filter: Dictionary={"version":2,"enabled":true,"mode":"all","action":"clear_matches","conditions":[{"field":"weapon","value":"missile"}]}
	check(g.hyperspace.set_filter(g,filter) and g.hyperspace.export_filter(g).begins_with("SPACE-FILTER-v2:"),"explicit filter action saves in string")
	check(not g.hyperspace.set_filter(g,{"version":2,"enabled":true,"mode":"all","action":"clear_matches","conditions":[]}),"empty active destroy filter rejected")
	print("HYPERSPACE_COMBAT ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
