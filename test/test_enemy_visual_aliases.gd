extends SceneTree
## Isolated production-scene visual check. No source tables or enemy attack data edits.
var scene
var failures:Array[String]=[]
var facts:={"rows":[],"aliases":[],"launches":[],"max_muzzle_error_pixels":0.0,"max_flash_error_pixels":0.0}
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/"+name+".png")
func make_enemy(row:Dictionary,id:int)->Dictionary:
	var e:=row.duplicate(true)
	e.uid=id;e.slot=4;e.x=250.0;e.y=130.0;e.hp=row.health;e.max_hp=row.health;e.cooldowns=[]
	return e
func record_launch(kind:String,info:Dictionary)->void:
	if kind!="fire" or not bool(info.shot.hostile):return
	var shot:Dictionary=info.shot
	var enemy:Dictionary={}
	var slot:=-1
	var nearest:=INF
	for candidate in scene.game.enemies:
		for index in candidate.equipment.size():
			var logical:Vector2=Vector2(candidate.x,candidate.y)+scene.game.enemy_weapon_offset(candidate,index)
			var distance:=logical.distance_squared_to(Vector2(shot.x,shot.y))
			if distance<nearest:nearest=distance;enemy=candidate;slot=index
	var component=scene.enemy_component_for_slot(enemy,slot)
	check(component!=null,"Fired slot has visible component")
	if component==null:return
	var pose:Dictionary=scene.enemy_component_pose(enemy,component)
	var expected:Vector2=scene.enemy_render_position(enemy)+Vector2(pose.origin)+Vector2(pose.port).rotated(float(pose.angle))
	var visual:Dictionary=scene.projectile_visual(shot)
	var actual:Vector2=scene.battle_point(visual.origin)
	var error:=actual.distance_to(expected)
	facts.max_muzzle_error_pixels=maxf(facts.max_muzzle_error_pixels,error)
	check(error<0.001,"Launch matches visible aperture")
	if scene.weapon_key(shot) in ["laser","cannon"]:
		var flash:Dictionary=scene.enemy_impacts.back()
		var flash_error:float=scene.battle_point(flash.position).distance_to(expected)
		facts.max_flash_error_pixels=maxf(facts.max_flash_error_pixels,flash_error)
		check(flash.kind=="fire" and flash_error<0.001,"Enemy flash matches aperture")
	check(not bool(shot.get("prototype_missile",false)),"Hostile shot excludes player phased missile")
	facts.launches.append({"key":shot.key,"canonical":scene.weapon_key(shot),"size":enemy.size,"slot":slot,"muzzle_error":error,"speed":shot.speed,"damage":shot.damage})
func run()->void:
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	root.size=Vector2i(1331,856)
	for i in 3:await process_frame
	if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
	scene.beginner_guide.set_process(false)
	var source:=JSON.stringify(scene.db.data)
	for id in scene.db.enemies:
		var enemy:=make_enemy(scene.db.enemies[id],10000+int(id))
		var mapped:Dictionary={}
		for index in enemy.equipment.size():
			mapped[scene.slot_hardpoint_index("enemy_"+str(int(enemy.size)),index)]=true
			var component=scene.enemy_component_for_slot(enemy,index)
			check(component!=null,"Real enemy "+str(id)+" slot "+str(index))
			check(scene.enemy_port_offset(enemy,index).is_finite(),"Finite configured muzzle")
		check(scene.enemy_weapon_components(enemy).size()==mapped.size(),"Unique configured hardpoints represented")
		facts.rows.append({"id":id,"size":enemy.size,"logical_slots":enemy.equipment.size(),"visible_components":scene.enemy_weapon_components(enemy).size()})
	var aliases:={"laser_mon":"laser","cannon-mon":"cannon","missile-mon":"missile","longLaser-mon":"longLaser","missile_mon":"missile"}
	for key in aliases:
		var enemy:=make_enemy(scene.db.enemies["3"],20000+facts.aliases.size())
		enemy.equipment=[{"name":key}]
		var component=scene.enemy_component_for_slot(enemy,0)
		check(component!=null and component.profile==scene.weapon_visual_profile(aliases[key]),"Exact alias "+key)
		facts.aliases.append({"key":key,"canonical":aliases[key],"mode":component.mode(),"port":str(scene.enemy_port_offset(enemy,0)),"table_row":scene.db.equipment.has(key)})
	check(scene.weapon_visual_profile("laser_mon_unknown").is_empty(),"Unknown suffix is not guessed")
	check(JSON.stringify(scene.db.data)==source,"Visual resolution cannot mutate source data")
	scene.game.profile.cleared=range(1,61)
	scene.game.rebuild_unlocks()
	scene.game.event.connect(record_launch)
	# Existing mixed encounter: size1/2, laser and cannon. No enemy loadout substitutions.
	check(scene.game.start(3,false),"Configured small encounter accessible");scene.game.group_index=2;scene.game.spawn_group()
	for i in 64:scene._process(1.0/60.0)
	scene.game.paused=true;scene._process(0.0);await capture("enemy-small-weapons-live")
	# Existing large encounter: a real size6 cannon flagship and size1 laser escorts.
	# Isolated player armor level keeps the short high-level visual sample alive.
	scene.game.profile.loadout.defence[0].level=230;scene.game.invalidate_stat_cache()
	check(scene.game.start(42,false),"Configured large encounter accessible");scene.game.group_index=3;scene.game.spawn_group()
	for i in 64:scene._process(1.0/60.0)
	scene.game.paused=true;scene._process(0.0);await capture("enemy-large-weapons-live")
	# Missile table rows are not equipped by current mon rows: exercise their real
	# launch path explicitly as a labelled table fixture, without changing attack values.
	for key in ["missile-mon","missile_mon"]:
		var enemy:Dictionary=scene.game.enemies[0]
		enemy.equipment=[{"name":key}]
		scene.game.fire(enemy,scene.game.player,scene.db.enemy_weapon(key),scene.db.enemy_weapon(key).dmg,true,key,scene.game.enemy_weapon_offset(enemy,0))
		var shot:Dictionary=scene.game.projectiles.back()
		var visual:Dictionary=scene.projectile_visual(shot)
		check(scene.battle_point(visual.origin).distance_to(scene.enemy_render_position(enemy)+scene.enemy_port_offset(enemy,0))<0.001,"Missile bay and flight origin "+key)
		check(not bool(shot.get("prototype_missile",false)),"Enemy missile remains stock")
	check(facts.launches.any(func(e):return e.canonical=="laser") and facts.launches.any(func(e):return e.canonical=="cannon"),"Both actual enemy attack families fired")
	facts.passed=failures.is_empty();facts.failures=failures
	var file:=FileAccess.open("res://.runtime/enemy-visual-facts.json",FileAccess.WRITE);file.store_string(JSON.stringify(facts,"\t"));file.close()
	print("ENEMY_VISUAL_ALIASES ",JSON.stringify(facts))
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
