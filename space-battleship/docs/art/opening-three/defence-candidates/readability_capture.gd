extends SceneTree
const ROOT="res://docs/art/opening-three/defence-candidates/"
const Review=preload("res://docs/art/opening-three/defence-candidates/binding_check.gd")
const Identity=preload("res://scripts/enemy_visual_identity.gd")
const Retained=preload("res://scripts/retained_enemy_contacts.gd")
var scene
var out:String
var evidence={"source":"6b2e98da382ac3903a0474936119a2dea59d4cb6","native_kernel":false,"stage":2,"point":5,"group":33010,"ticks":180,"dt":1.0/60.0,"render_checks":0,"frames":[],"launches":[]}
func _initialize():call_deferred("run")
func fresh_scene():
	if is_instance_valid(scene):scene.queue_free();await process_frame
	seed(51015)
	scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.capture_frame=-10000
	scene.game.save_enabled=false;scene.game.rng.seed=51015
	scene.game.profile.onboarding.completed=true;scene.game.profile.onboarding.dismissed=true
func screenshot(path:String):
	var before=[scene.game.enemies.duplicate(true),scene.game.projectiles.duplicate(true),scene.game.distance,scene.game.rng.state]
	scene.refresh_draw_layers(0.0);scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(before==[scene.game.enemies,scene.game.projectiles,scene.game.distance,scene.game.rng.state])
	evidence.render_checks+=1
	root.get_texture().get_image().save_png(path)
func record_event(kind:String,info:Dictionary):
	if kind!="fire":return
	var shot:Dictionary=info.get("shot",{})
	evidence.launches.append({"serial":shot.get("serial",0),"hostile":shot.get("hostile",false),"mount":shot.get("mount",-1),"x":shot.get("x",0),"y":shot.get("y",0)})
func run():
	out=OS.get_environment("OPENING_DECK_OUTPUT")
	assert(not out.is_empty());DirAccess.make_dir_recursive_absolute(out+"/frames")
	root.size=Vector2i(1373,883);root.content_scale_size=Vector2i(1952,1256)
	await fresh_scene();scene.hide()
	var board=Review.PaintBoard.new();board.owner_scene=scene;board.position=Vector2(350,70)
	board.heading="SOL 6b2e98da / same equipment, mounts, hull scale / "+out.get_file()
	board.footer="Single-contact comparison at default window scale; no component scaling or equipment changes."
	var retained=Retained.new();retained.setup(scene);retained.position=Vector2(600,0);board.add_child(retained)
	var source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"authoritative-loadouts.json"))
	var seen={};var index=0
	for row in source.rows:
		if seen.has(row.archetype_id):continue
		seen[row.archetype_id]=true
		var enemy={"id":int(row.id),"uid":int(row.id),"slot":index,"size":int(row.size),"archetype_id":row.archetype_id,"armourType":Identity.ARCHETYPES[row.archetype_id][1],"shieldType":2,"x":220.0,"y":160.0,"hp":100.0,"max_hp":100.0,"shield":50.0 if row.archetype_id=="shielded" else 0.0,"max_shield":100.0 if row.archetype_id=="shielded" else 0.0,"shieldRecovery":1.0 if row.archetype_id=="shielded" else 0.0,"equipment":row.equipment}
		board.specimens.append(enemy)
		var record=retained.create_record(enemy);var spatial=retained.display_spatial(record,enemy)
		retained.compile_record(record,spatial,false);retained.update_record(record,spatial,Vector2(260,155+index*110)-scene.enemy_render_position(enemy))
		index+=1
	root.add_child(board);await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/same-scale.png")
	board.queue_free();await process_frame
	await fresh_scene()
	scene.game.profile.highestLevel=3
	var level:Dictionary=scene.db.levels[1];var group:Dictionary=level.groups[4]
	assert(int(group.id)==33010)
	assert(scene.game.start(2,false,{"distance":float(group.position)*float(level.length),"groupIndex":5,"state":scene.game.State.COMBAT,"guardArrived":false,"retreatBossPending":false}))
	scene.game.event.connect(record_event)
	scene.refresh_structure()
	evidence.initial_count=scene.game.enemies.size()
	assert(evidence.initial_count==13)
	evidence.initial_equipment=[]
	for enemy in scene.game.enemies:evidence.initial_equipment.append({"uid":enemy.uid,"id":enemy.id,"size":enemy.size,"archetype_id":enemy.archetype_id,"equipment":enemy.equipment.duplicate(true)})
	for tick in 180:
		scene._process(1.0/60.0)
		if tick%3==0:
			await screenshot(out+"/frames/%03d.png"%(tick/3))
			evidence.frames.append({"tick":tick+1,"enemies":scene.game.enemies.size(),"alive":scene.game.enemies.filter(func(e):return e.hp>0).size(),"projectiles":scene.game.projectiles.size(),"state":scene.game.state})
	evidence.final_enemies=scene.game.enemies.duplicate(true);evidence.final_projectiles=scene.game.projectiles.duplicate(true)
	evidence.final_distance=scene.game.distance;evidence.final_rng=scene.game.rng.state
	# Only compare serializable gameplay fields; no Resource identity enters this record.
	for enemy in evidence.final_enemies:
		for key in enemy.keys():
			if enemy[key] is Object:enemy.erase(key)
	FileAccess.open(out+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"  ")+"\n")
	print("DECK_CAPTURE_OK group=33010 initial=",evidence.initial_count," frames=",evidence.render_checks," launches=",evidence.launches.size())
	quit()
