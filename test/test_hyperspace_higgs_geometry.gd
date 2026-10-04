extends SceneTree
const Geometry=preload("res://scripts/rail_geometry.gd")
const Vfx=preload("res://dev/toon_ship/rail_vfx.gd")
const Battlefield=preload("res://scripts/battlefield.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func enemy(id: int,point: Vector2) -> Dictionary:
	return {"uid":id,"hp":100000.0,"max_hp":100000.0,"x":point.x,"y":point.y,"pixel_point":point,"armourType":99,"slot":id,"equipment":[],"drops":[],"res_ratio":1.0}
func prepared(trail: float,area_bonus: float) -> BattleGame:
	var db:=ShipDatabase.new();db.config.offlineMax=0;db.data.weapon_motion.rail_trail_width.value=trail
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks()
	var rng:=RandomNumberGenerator.new();rng.seed=34
	var d:=Rewards.create_drone(rng,g.hyperspace.config,"higgs","legendary","cannon",5,"1")
	d.affixes=[];d.legendary_effect={"effect_id":"higgs_cannon","parameters":{"damage_bonus":2.0,"area_bonus":area_bonus}}
	Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);g.hyperspace.set_equipped(g,[d.id]);g.state=g.State.COMBAT
	return g
func launch(g: BattleGame,target: Dictionary) -> Dictionary:
	var index:=g.weapon_entries().size()
	g.begin_enhancement_attack(index,target);var attack:=g.jewel_attack(index)
	g.launch_player_attack(index,target,g.player_weapon_row(g.combat_entry(index)),attack,g.player_weapon_offset(index),0.0)
	g.finish_enhancement_attack(index);return g.projectiles.back()
func _initialize() -> void:
	for spec in [[28.0,1.0],[52.0,2.0]]:
		var g:=prepared(spec[0],spec[1]);var vfx:=Vfx.new();vfx.configure(g.db)
		var full_width: float=vfx.discharge_width(1.0+spec[1]);var origin:=Vector2(g.player.x,g.player.y)+g.player_weapon_offset(g.weapon_entries().size())
		g.enemies=[enemy(1,origin+Vector2(0,-100)),enemy(2,origin+Vector2(full_width*0.5-0.1,-200)),enemy(3,origin+Vector2(full_width*0.5+0.1,-250)),enemy(4,origin+Vector2(0,10))]
		var observed:=[]
		g.event.connect(func(kind,info):
			if kind=="fire":observed.append(info.shot.get("rail_width_multiplier",0)))
		var shot:=launch(g,g.enemies[0])
		check(shot.higgs.full_width==full_width and full_width==Geometry.width(spec[0],1.0+spec[1]),"real rail width and legendary multiplier shared")
		check(observed==[1.0+spec[1]],"fire presentation sees committed expansion before damage")
		check(Vector2(shot.higgs.end)==vfx.exit_point(origin,Vector2.UP,g.BATTLE_SIZE,full_width),"hit strip and visible exit use identical width extension")
		g.advance_higgs_projectile(shot,0.0)
		check(g.enemies[0].hp<100000 and g.enemies[1].hp<100000,"entire strip settles primary and inside-edge enemy immediately")
		check(g.enemies[2].hp==100000 and g.enemies[3].hp==100000,"outside-edge and behind-origin enemies excluded")
		var hp: float=g.enemies[0].hp;g.advance_higgs_projectile(shot,1.0)
		check(g.enemies[0].hp==hp and shot.dead,"repeated sweep cannot duplicate hits")
	var g:=prepared(28.0,1.0)
	g.enemies=[enemy(1,Vector2(0,0)),enemy(2,Vector2(0,0)),enemy(3,Vector2(0,0))]
	g.enemies[0].pixel_point=Vector2(300,100);g.enemies[1].pixel_point=Vector2(327.9,200);g.enemies[2].pixel_point=Vector2(328.1,250)
	g.rail_geometry_provider=func(_shot):return {"origin":Vector2(300,800),"aim":Vector2(300,100),"bounds":Vector2(572,960),"full_width":56.0}
	g.rail_target_point_provider=func(target):return target.pixel_point
	var shot:=launch(g,g.enemies[0]);g.advance_higgs_projectile(shot,0.0)
	check(g.enemies[0].hp<100000 and g.enemies[1].hp<100000 and g.enemies[2].hp==100000,"projected screen geometry controls strip instead of mixed logical units")
	check(shot.higgs.origin==Vector2(300,800) and shot.higgs.points["2"]==Vector2(327.9,200),"launch geometry value snapshot frozen")
	g.hyperspace.set_equipped(g,[]);g.rail_geometry_provider=Callable();g.rail_target_point_provider=Callable()
	g.projectiles.clear();g.equip_slot("weapons",0,"cannon")
	var offset:=g.player_weapon_offset(0);var origin:=Vector2(g.player.x,g.player.y)+offset
	g.enemies=[enemy(1,origin+Vector2(0,-100)),enemy(2,origin+Vector2(0,-200))]
	g.begin_enhancement_attack(0,g.enemies[0]);var attack:=g.jewel_attack(0)
	g.launch_player_attack(0,g.enemies[0],g.player_weapon_row(g.combat_entry(0)),attack,offset,0.0);g.finish_enhancement_attack(0)
	check(not g.projectiles.back().has("higgs") and g.projectiles.back().rail_width_multiplier==1.0,"ordinary cannon has no legendary sweep")
	g.tick_projectiles(10)
	check(g.enemies[0].hp<100000 and g.enemies[1].hp==100000,"ordinary cannon only damages primary")
	print("HYPERSPACE_HIGGS_GEOMETRY ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
