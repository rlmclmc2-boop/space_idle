extends SceneTree
var scene
var markers:Array=[]
var facts:Array=[]
var output:=""
var show_markers:=false
var baseline:=false
func draw_markers()->void:
	if not show_markers:return
	for m in markers:
		scene.pulse_layer.draw_circle(m.mouth,7,Color.YELLOW,false,1.0)
		scene.pulse_layer.draw_line(m.launch-Vector2(5,0),m.launch+Vector2(5,0),Color.CYAN,1.0)
		scene.pulse_layer.draw_line(m.launch-Vector2(0,5),m.launch+Vector2(0,5),Color.CYAN,1.0)
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--baseline":baseline=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1335,859)
	scene=load("res://dev/toon_ship_test.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	scene.game.start(1,false);scene.game.spawn_group()
	for enemy in scene.game.enemies:enemy.hp=1e8;enemy.max_hp=1e8
	scene.game.player.armour=1e8
	for i in scene.game.weapon_entries().size():scene.game.cooldowns[scene.game.slot_id("weapons",i)]=0.4 if i in [1,5] else 1e9
	scene.game.paused=false
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
	scene.pulse_layer.draw.connect(draw_markers)
	var seen:=0
	for frame in 100:
		scene._process(1.0/60.0)
		var changed:bool=scene.game.launch_records.size()>seen
		if changed:
			markers.clear()
			for rec in scene.game.launch_records.slice(seen):
				var module:Dictionary={}
				for m in scene.ship_view.modules:
					if int(m.slot)==int(rec.mount):module=m

				# Independent visible LaunchOpening front-face geometry from polish_weapons.py.
				var mouth:Vector2=scene.ship_view.camera.unproject_position(module.pivot.to_global(Vector3(-0.34 if int(rec.ordinal)%2==0 else 0.34,0.48,-0.495)))
				var launch:Vector2=scene.battle_point(rec.position)
				facts.append({"frame":frame,"mount":rec.mount,"ordinal":rec.ordinal,"mouth":str(mouth),"launch":str(launch),"error_px":mouth.distance_to(launch),"carrier":module.carrier,"heading":module.mount.global_rotation.y})
				markers.append({"mouth":mouth,"launch":launch})
			seen=scene.game.launch_records.size()
		await process_frame
		await RenderingServer.frame_post_draw
		if changed:
			root.get_texture().get_image().save_png(output.path_join("frame-%03d.png"%frame))
			show_markers=true;scene.pulse_layer.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("marked-%03d.png"%frame))
			show_markers=false;scene.pulse_layer.queue_redraw()
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	print("MUZZLE_REVIEW ",JSON.stringify(facts))
	var passed:=facts.size()==10
	for fact in facts:passed=passed and (baseline or float(fact.error_px)<0.001)
	scene.free();quit(0 if passed else 1)
