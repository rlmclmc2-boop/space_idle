extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var checks := 0
var failures := 0
var scene
var baseline := OS.get_environment("TASK3_BASELINE")=="1"
var folder := ProjectSettings.globalize_path("res://../task3-evidence")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize()->void:call_deferred("run")
func spawn(slots:Array)->void:
	var g=scene.game
	g.db.groups["999999"]={"slots":slots,"combatTier":"normal"}
	g.db.levels[0].groups=[{"id":999999,"position":0.5},{"id":999999,"position":0.8}]
	g.stage=1;g.group_index=0;g.spawn_group()
	for enemy in g.enemies:
		for index in enemy.cooldowns.size():enemy.cooldowns[index]=1000.0
		enemy.hp=1e100;enemy.max_hp=1e100
	g.refresh_missile_target_registry();g.projectiles.clear();scene.enemy_poses.clear()
	scene.fx_time=4.0
	for enemy in g.enemies:scene.enemy_pose(enemy).born=0.0
func envelope(enemy:Dictionary)->Rect2:
	var texture=scene.ship_hull_texture("enemy_"+str(int(enemy.size)))
	var used:Rect2=scene.enemy_hull_bounds(texture)
	var dimensions=Vector2(scene.enemy_render_width(enemy),scene.enemy_render_width(enemy)*2.0)
	var position:Vector2=scene.enemy_render_position(enemy)
	var result=Rect2(position,Vector2.ZERO)
	for corner in [used.position,Vector2(used.end.x,used.position.y),used.end,Vector2(used.position.x,used.end.y)]:
		result=result.expand(position+(corner*dimensions).rotated(PI+scene.enemy_render_angle(enemy)))
	return result.grow(5.0)
func validate(label:String)->void:
	var enemies=scene.game.enemies
	for i in enemies.size():
		var a:Dictionary=enemies[i]
		check(scene.game.targets().has(a),label+": target selectable")
		check(scene.battle_point(scene.game.target_point(a)).distance_to(scene.enemy_render_position(a))<0.01,label+": collision provider uses rendered target")
		for j in range(i+1,enemies.size()):
			var b:Dictionary=enemies[j]
			check(not envelope(a).intersects(envelope(b)),label+": hulls do not overlap "+str([a.slot,b.slot]))
			check(Geometry2D.intersect_polygons(protection(a),protection(b)).is_empty(),label+": protection envelopes do not overlap "+str([a.slot,b.slot]))
			if int(a.size)>int(b.size):check(float(a.y)<=float(b.y),label+": large ship behind small ship")
func protection(enemy:Dictionary)->PackedVector2Array:
	var packet:Dictionary=scene.enemy_recognition_geometry(enemy)
	var outline:PackedVector2Array=packet.inner
	if float(enemy.get("shield",0))>0:
		outline=packet.front if int(enemy.get("shieldType",0))==1 and int(enemy.size)>=4 else packet.outer
	var result:=PackedVector2Array()
	for point in outline:result.append(scene.enemy_render_position(enemy)+point.rotated(PI+scene.enemy_render_angle(enemy)))
	return result
func capture(name:String)->void:
	if DisplayServer.get_name()=="headless":
		await process_frame
		return
	scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
	scene.music_on=false;scene.sound_on=false;scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.rng.seed=92841;g.speed=1
	g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.cleared=range(1,76);g.rebuild_unlocks();g.profile.selectedShip="Frigate"
	g.profile.loadout={"weapons":[{"key":"cannon","level":1},{"key":"laser","level":1},{"key":"laser","level":1}],"defence":[{"key":"armour","level":10},{"key":"","level":1}]}
	g.start(1,false);scene.refresh_structure();scene.refresh_tab_visibility()
	if not baseline:
		# The authored 40 templates and generated group-shaped inputs use one spawn path.
		var count:=0
		for design in g.db.data.battle_design.values():
			var slots:Array=g.db.groups[str(int(design.group_id))].slots.duplicate()
			spawn(slots);check(g.enemies.size()==slots.filter(func(v):return v!=null).size(),"authored count preserved")
			for enemy in g.enemies:check(int(enemy.id)==int(slots[int(enemy.slot)]),"identity/slot preserved")
			validate("authored "+str(design.group_id));count+=1
		check(count==40,"40 authored templates exercised")
	var cases={"mixed":[3,1,5,7,1,3,8,5,3],"same-size":[7,8,7,8,7,8,7,8,7,8],"single-heavy":[12],"full-fleet":[3,1,5,7,12,3,1,5,8,12,3,1,5,8,12],"full-heavy":[12,12,12,12,12,12,12,12,12,12,12,12,12,12,12]}
	for label in cases:
		spawn(cases[label]);scene._process(0.0)
		if not baseline:
			for clock in [4.0,5.0,6.0,7.0]:scene.fx_time=clock;validate(label)
		await capture(label)
	spawn([7,3,1]);scene._process(0.0)
	g.db.data.enhance_config.base_critical_rate.value=0;g.db.data.enhance_config.repeat_probability.value=0
	var target:Dictionary=g.targets(int(g.db.equip("cannon",1).dmgtype))[0]
	target.hp=1.0;target.max_hp=1.0
	g.cooldowns={"weapons_0":0.001,"weapons_1":100.0,"weapons_2":100.0}
	scene.rail_events.clear()
	var target_died:=false
	for frame in 42:
		scene._process(1.0/60.0)
		if float(target.hp)<=0:target_died=true
		await capture("rail-%02d"%frame)
		if not baseline and frame==30:
			check(target_died,"rail real primary impact kills fixture target")
			check(scene.rail_events.any(func(e):return e.kind=="fire"),"launch afterglow survives target death")
		if not baseline and frame==40:check(not scene.rail_events.any(func(e):return e.kind=="fire"),"afterglow expires independently")
	if not baseline:
		for bounds in [Vector2(572,960),Vector2(386,648),Vector2(1000,700)]:
			for direction in [Vector2.UP,Vector2(-0.4,-1).normalized(),Vector2(0.6,-1).normalized(),Vector2.RIGHT]:
				var origin=bounds*0.75
				check(not Rect2(Vector2.ZERO,bounds).has_point(scene.rail_vfx.exit_point(origin,direction,bounds)),"rail reaches outside actual clip bounds")
		check(scene.rail_origin_max_error<0.01,"rail retains actual muzzle")
		check(scene.rail_hit_count==1,"visual extension adds no extra primary impacts")
		for key in ["laser","cannon","missile","longLaser"]:
			for depth in [0,2]:
				g.profile.loadout.weapons=[{"key":key,"level":1}]
				g.reset_player();spawn(cases["full-fleet"])
				var candidate:Dictionary=g.enemies.filter(func(e):return float(e.y)==(110.0 if depth==0 else 350.0))[0]
				g.enemies.assign([candidate]);g.refresh_missile_target_registry()
				candidate.hp=1e12;candidate.max_hp=1e12
				var hp_before:float=candidate.hp
				g.cooldowns={"weapons_0":0.001}
				for step in 360:scene._process(1.0/60.0)
				check(candidate.hp<hp_before,key+": actual hit reaches "+("back" if depth==0 else "front")+" row")
	print("SIZE FORMATION / RAIL PATH checks=",checks," failures=",failures," baseline=",baseline," evidence=",folder)
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free();await process_frame;current_scene=null
	quit(1 if failures else 0)
