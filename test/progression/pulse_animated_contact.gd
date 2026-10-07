extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
	func show_qa_tools()->void:pass
var checks:=0
var failures:=0
var scene
var impacts:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func launch(target:Dictionary)->Dictionary:
	var g=scene.game
	var entry:Dictionary=g.combat_entry(0)
	var weapon:Dictionary=g.player_weapon_row(entry)
	g.begin_enhancement_attack(0,target)
	var attack:Dictionary=g.jewel_attack(0)
	g.launch_player_attack(0,target,weapon,attack,g.player_weapon_offset(0),0.0)
	g.finish_enhancement_attack(0)
	return g.projectiles.back()
func drain()->void:
	for i in 90:
		scene.fx_time+=1.0/60.0
		scene.game.tick_projectiles(1.0/60.0)
		scene.advance_projectile_visuals(1.0/60.0)
func run()->void:
	scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.automation_args=[]
	var g=scene.game
	g.profile.loadout.weapons[0]={"key":"laser","level":1}
	g.invalidate_stat_cache();g.reset_player();g.start(1,false);g.spawn_group()
	var target:Dictionary=g.enemies[0]
	target.hp=1e20;target.max_hp=target.hp;target.equipment=[];target.cooldowns=[]
	scene.enemy_poses.clear();scene.fx_time=0.0
	g.event.connect(func(kind,info):
		if kind=="projectile_impact" and str(info.shot.key)=="laser":impacts.append(info))
	var shot=launch(target)
	var origin:Vector2=shot.launch_point
	var aim:Vector2=shot.ballistic_target_origin
	var visual:Dictionary=scene.projectile_visual(shot)
	check(Vector2(visual.origin).distance_to(origin)<0.0001,"pulse display starts at committed physical muzzle")
	check(scene.battle_point(scene.straight_projectile_point(aim,visual)).distance_to(scene.battle_point(aim))<0.02,"pulse display reaches the authoritative projected aim without old logical scaling")
	var angle:float=shot.direction.angle()
	var before:Vector2=scene.enemy_render_position(target)
	drain()
	check(before.distance_to(scene.enemy_render_position(target))>0.5,"fixture exercises actual entry and hover animation")
	check(impacts.size()==1 and shot.dead and not g.projectiles.has(shot),"entry/hover target receives one impact and pulse retires")
	check(absf(angle_difference(shot.direction.angle(),angle))<0.0001,"cosmetic motion does not steer the pulse")
	check(scene.pulse_events.any(func(e):return e.kind=="hit" and scene.battle_point(e.position).distance_to(scene.battle_point(aim))<0.02),"impact FX uses the same projected contact as damage")
	impacts.clear();scene.fx_time=4.0
	shot=launch(target);angle=shot.direction.angle();target.x+=80.0
	drain()
	check(impacts.is_empty(),"real lateral movement still evades a straight pulse")
	check(absf(angle_difference(shot.direction.angle(),angle))<0.0001,"real lateral movement cannot add homing")
	var hostile:Dictionary={"target":g.player,"hostile":true}
	check(g.projectile_target_point(hostile)==Vector2(g.player.x,g.player.y),"hostile target geometry stays unchanged")
	print("PULSE_ANIMATED_CONTACT ",checks," checks ",failures," failures")
	quit(1 if failures else 0)