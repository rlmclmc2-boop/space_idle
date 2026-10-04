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
func target(id: int,hp: float=100000) -> Dictionary:
	return {"uid":id,"hp":hp,"max_hp":hp,"x":200.0,"y":100.0,"armourType":99,"slot":id,"equipment":[],"drops":[],"res_ratio":1.0}
func prepared(effect: String):
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks();g.stat_cache_enabled=true
	var rng:=RandomNumberGenerator.new();rng.seed=123
	var row: Dictionary=g.hyperspace.config.legendary_effects[effect]
	var weapon: String="laser" if row.weapon.is_empty() else str(row.weapon)
	var d:=Rewards.create_drone(rng,g.hyperspace.config,"legend", "legendary",weapon,5,"1")
	var parameters: Dictionary={}
	for key in row.parameters:parameters[key]=float(row.parameters[key][1])
	d.legendary_effect={"effect_id":effect,"parameters":parameters};d.affixes=[]
	Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
	g.hyperspace.set_equipped(g,["legend"]);g.state=g.State.COMBAT
	return g
func _initialize() -> void:
	var g: BattleGame=prepared("laser_charge")
	check(g.combat_weapon_entries().size()==g.weapon_entries().size()+1,"ordinary and drone source lists independent")
	check(g.combat_entry(g.weapon_entries().size()).level==2 and g.drone_combat.weapon_multiplier(g,"laser")==1.0+0.5*g.combat_weapon_entries().filter(func(e):return e.key=="laser").size(),"highest corresponding module plus quality, two laser charge sources")
	var source: Dictionary=g.combat_entry(g.weapon_entries().size());g.invalidate_stat_cache()
	check(is_same(source,g.combat_entry(g.weapon_entries().size())),"unrelated stat invalidation retains combat identity")
	g=prepared("scatter_pulse");g.enemies=[target(1)]
	check(g.drone_combat.weapon_multiplier(g,"laser")==4.0,"scatter sole target bonus")
	g.enemies.append(target(2));check(g.drone_combat.weapon_multiplier(g,"laser")==1.0,"scatter bonus only sole target")
	g.cooldowns[g.slot_id("weapons",0)]=0;g.cooldowns[g.slot_id("weapons",g.weapon_entries().size())]=0;g.tick(0.001)
	check(g.projectiles.size()==4,"two scatter sources launch at both targets")
	g=prepared("strange_matter");var killed:=target(1,1);var survivor:=target(2);g.enemies=[killed,survivor]
	g.hit_enemy(killed,10,int(g.db.equip("cannon",1).dmgtype),[],false,CC.root(1,"module:0","cannon"))
	check(g.drone_combat.delayed.size()==2,"cannon kill creates exactly two delayed explosions")
	g.drone_combat.advance(g,0.9);check(survivor.hp==100000,"explosion respects delay")
	g.drone_combat.advance(g,0.1);check(survivor.hp==99960 and g.drone_combat.delayed.is_empty(),"both explosions damage once and cannot spawn explosions")
	g=prepared("black_hole");var victim:=target(1);g.enemies=[victim]
	g.drone_combat.advance(g,20);check(g.drone_combat.black_hole_remaining==5,"black hole opens after twenty battle seconds")
	var health=g.player.armour;g.hit_enemy(victim,10,1,[],false,CC.root(2,"module:0","laser"));g.hit_player(10,1)
	check(victim.hp==100000 and g.player.armour==health and g.drone_combat.black_hole_damage==10,"absorbs both sides but stores only friendly damage")
	g.drone_combat.advance(g,5);check(victim.hp==99980 and g.drone_combat.black_hole_remaining==0,"black hole explodes with stored friendly damage")
	g.drone_combat.advance(g,15);check(g.drone_combat.black_hole_remaining==5,"period counts five absorption seconds")
	g.drone_combat.advance(g,5);check(victim.hp==99980,"empty black hole causes no minimum damage")
	g=prepared("black_hole");g.drone_combat.advance(g,25)
	check(g.drone_combat.black_hole_remaining==0 and g.drone_combat.black_hole_elapsed==5,"batched elapsed time crosses absorption boundaries")
	g=prepared("drone_master");var raw: float=float(g.drone_combat.incoming(g,100,CC.root(0,"enemy","laser")).damage)
	check(is_equal_approx(raw,20.0),"legendary rank proportional damage reduction")
	g=prepared("wild_missile");g.enemies=[target(1),target(2)]
	var missile_index:=g.weapon_entries().size()
	for i in 4:
		g.begin_enhancement_attack(missile_index,g.enemies[0]);var attack: Dictionary=g.jewel_attack(missile_index)
		check(attack.combat_context.get("wild_missile",false)==(i==3),"every fourth primary salvo substituted")
		if i==3:
			check(not CC.can_trigger(attack.combat_context) and g.enhancement_attack_contexts[missile_index].derived,"wild substitution cannot start trigger chain")
			g.hit_enemy(g.enemies[0],attack.damage,3,[],false,attack.combat_context)
			check(g.enemies[0].hp<g.enemies[1].hp and g.enemies[1].hp<100000,"wild direct damage plus one all-target explosion")
		g.finish_enhancement_attack(missile_index)

	g=prepared("wild_missile");g.enemies=[target(1)];var launcher:=g.weapon_entries().size()
	for i in 4:g.cooldowns[g.slot_id("weapons",launcher)]=0;g.tick(0.001)
	check(g.projectiles.size()==int(g.db.equip("missile",1).para1)*3+1,"real fourth missile launch contains one projectile")
	g=prepared("dodge_counter");g.db.equipment.laser[0].cri=1.0;g.invalidate_stat_cache();g.enemies=[target(1)]
	var hp=g.player.armour
	for i in 2:g.rng.seed=42;g.hit_player(10,1,CC.root(i,"enemy","laser"))
	check(g.player.armour==hp and g.projectiles.size()==1 and not CC.can_trigger(g.projectiles[0].combat_context),"dodge counter cooldown and depth1")
	g=prepared("higgs_cannon")
	check(not g.equip_slot("weapons",0,"cannon"),"higgs restricts combined ordinary and drone cannon count")
	g.enemies=[target(1),target(2)];var offset: Vector2=g.player_weapon_offset(g.weapon_entries().size())
	for i in 2:g.enemies[i].x=g.player.x+offset.x;g.enemies[i].y=200-i*100
	var cannon: Dictionary=g.player_weapon_row(g.combat_entry(g.weapon_entries().size()));g.begin_enhancement_attack(g.weapon_entries().size(),g.enemies[0])
	var cannon_attack: Dictionary=g.jewel_attack(g.weapon_entries().size());g.launch_player_attack(g.weapon_entries().size(),g.enemies[0],cannon,cannon_attack,offset,0)
	check(g.projectiles.back().has("higgs"),"higgs primary projectile carries penetration")
	g.tick_projectiles(0.5);check(g.enemies[0].hp<100000 and g.enemies[1].hp<100000,"one cannon penetrates both path targets")
	g=prepared("prism_tower");g.profile.loadout.weapons[0].key="longLaser";g.invalidate_stat_cache();g.enemies=[]
	for i in 7:
		var e:=target(i);e.x=100+i*20;g.enemies.append(e)
	for i in [0,g.weapon_entries().size()]:g.lock_long_laser(g.player,g.player_weapon_row(g.combat_entry(i)),false,i,g.combat_entry(i))
	check(g.projectiles.filter(func(p):return p.get("prism_tower",false)).size()==1,"one simultaneous prism tower")
	check(g.projectiles[0].attack_instance.chain.links.size()==5,"prism chooses five secondary targets")
	g=prepared("endless_beam");g.enemies=[target(1),target(2)]
	check(g.equip_slot("weapons",0,"longLaser"),"endless ordinary module installs")
	check(is_same(g.endless_source(),g.weapon_entries()[0]) and int(g.combat_entry(g.weapon_entries().size()).level)>int(g.endless_source().level),"higher quality drone cannot replace highest ordinary module")
	g.lock_long_laser(g.player,g.player_weapon_row(g.combat_entry(0)),false,0,g.combat_entry(0));var beam: Dictionary=g.projectiles.back()
	var dead_uid: int=beam.target.uid;beam.elapsed=5.0;beam.target.hp=0;g.advance_long_laser(beam,0.1)
	check(beam.target.uid!=dead_uid and beam.target.hp>0 and is_equal_approx(beam.elapsed,5.1) and not beam.dead,"highest beam changes dead target without losing growth")
	g.change_state(g.State.TRAVEL);g.advance_long_laser(beam,0.1)
	check(g.projectiles.has(beam) and beam.await_target and not beam.dead,"endless beam waits between waves")
	g.enemies=[target(3)];g.state=g.State.COMBAT;g.advance_long_laser(beam,0.1)
	check(beam.target.uid==3 and is_equal_approx(beam.elapsed,5.2),"endless growth preserved on next wave")
	g=prepared("drone_rebuild");g.profile.selectedShip="Heavy_Battleship";var ids: Array=["legend"]
	var rng:=RandomNumberGenerator.new();rng.seed=12
	for i in 4:
		var d:=Rewards.create_drone(rng,g.hyperspace.config,"white:%d"%i,"white","laser",5,"1");Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);ids.append(d.id)
	check(g.hyperspace.set_equipped(g,ids),"five drone rebuild fixture")
	for i in 4:
		g.player.armour=0
		check(g.drone_combat.try_rebuild(g) and g.drone_combat.disabled[-1]=="white:%d"%i,"lowest quality stable ID invalidated")
	check(not g.drone_combat.try_rebuild(g) and g.drone_combat.rebuild_stacks==4,"rebuild capped at four")
	check(g.profile.hyperspace.inventory.equipped.size()==5 and g.combat_weapon_entries().size()==g.weapon_entries().size()+1,"rebuild only temporary invalidation, no inventory deletion")
	g.drone_combat.reset();g.invalidate_stat_cache();check(g.combat_weapon_entries().size()==g.weapon_entries().size()+5,"battle reset restores disabled drones")
	print("HYPERSPACE_EFFECTS ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
