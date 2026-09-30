extends SceneTree
## Explicit isolated save fixture; real main scene, equipment APIs and combat data.
var scene
var failures:Array[String]=[]
var output:=""
var records:Array=[]
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func capture(label:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run()->void:
	output=ProjectSettings.globalize_path("res://.runtime/fleet")
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var seed_game=load("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),true)
	seed_game.profile.cleared=range(1,61)
	seed_game.rebuild_unlocks()
	seed_game.profile.onboarding.completed=true
	seed_game.profile.onboarding.dismissed=true
	seed_game.switch_ship("Heavy_Battleship")
	var pattern:=["laser","missile","cannon","longLaser","missile","longLaser","cannon","missile"]
	for i in seed_game.active_slot_count("weapons"):
		check(seed_game.equip_slot("weapons",i,pattern[i]),"Fixture equipment must be valid")
		seed_game.profile.loadout.weapons[i].level=8
	for i in seed_game.active_slot_count("defence"):
		seed_game.equip_slot("defence",i,"armour" if i%2==0 else "shield")
		seed_game.profile.loadout.defence[i].level=18
	seed_game.invalidate_stat_cache()
	seed_game.start(8,false)
	seed_game.spawn_group()
	seed_game.save_progress()
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	root.size=Vector2i(1373,883)
	for i in 3:await process_frame
	if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
	check(scene.game.save_enabled and scene.fixture_name.is_empty(),"Full loadout must enter through normal persisted main scene")
	check(scene.game.profile.loadout.weapons.size()==8,"Full persisted capacity")
	var enemies_before:Array=[]
	for enemy in scene.game.enemies:enemies_before.append({"id":enemy.id,"hp":enemy.hp,"max_hp":enemy.max_hp,"size":enemy.size})
	var damage_before=scene.game.player.armour
	var shots:=0
	scene.game.event.connect(func(kind,info):
		if kind=="fire":records.append({"hostile":bool(info.shot.hostile),"key":info.shot.key}))
	for frame in 150:
		scene._process(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frames/frame-%04d.png"%frame))
	await capture("full-loadout-combat")
	check(records.any(func(e):return not e.hostile),"Real player fires")
	check(records.any(func(e):return e.hostile),"Real enemies fire")
	check(scene.missile_fire_count>0 and scene.pulse_fire_count>0 and scene.rail_fire_count>0,"Missile pulse and rail all use shared renderer")
	var tab=scene.equipment_tabs
	var capacities:={}
	for key in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		check(scene.game.switch_ship(key) or scene.game.profile.selectedShip==key,"Normal switch: "+key)
		scene.game.paused=true
		scene._process(0.0)
		await capture("hull-"+key)
		var active:=int(scene.game.active_slot_count("weapons"))
		check(scene.ship_view.modules.size()==active,key+" active visual capacity")
		var indices:Array=[]
		for module in scene.ship_view.modules:
			indices.append(int(module.slot))
			var muzzle:Vector2=scene.ship_view.screen_muzzle_for_slot(int(module.slot))
			check(muzzle.is_finite() and Rect2(Vector2.ZERO,scene.BATTLE_VIEW_SIZE).has_point(muzzle),key+" visible muzzle "+str(module.slot))
		check(indices.size()==active and not indices.has(-1),key+" stable slot identities")
		capacities[key]={"active":active,"hull":scene.ship_view.modules.filter(func(e):return e.carrier=="hull").size(),"drone":scene.ship_view.carriers.size()}
		check(scene.equipment_tabs==tab,"Switch retains unrelated tabs")
	# Find real configured encounters that cover all six sizes; no enemy HP overrides.
	var cases:={1:Vector2i(2,1),2:Vector2i(1,0),3:Vector2i(1,4),4:Vector2i(6,8),5:Vector2i(21,2),6:Vector2i(21,5)}
	for size in cases:
		var c:Vector2i=cases[size]
		scene.game.start(c.x,false)
		scene.game.group_index=c.y
		scene.game.spawn_group()
		scene.game.paused=true
		scene._process(0.0)
		await capture("enemy-size-"+str(size))
		check(scene.game.enemies.any(func(e):return int(e.size)==int(size)),"Configured encounter includes size "+str(size))
	var facts:={"passed":failures.is_empty(),"failures":failures,"fixture":"isolated full-loadout save, no enemy durability edits","production_entry":"main.tscn","save_enabled":scene.game.save_enabled,"capacities":capacities,"shots":records.size(),"missile_fires":scene.missile_fire_count,"pulse_fires":scene.pulse_fire_count,"rail_fires":scene.rail_fire_count,"beam_full_cues":scene.beam_full_cue_count,"enemies_before":enemies_before,"video_fps":30,"video_frames":150,"window":str(root.size)}
	var file:=FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE);file.store_string(JSON.stringify(facts,"\t"));file.close()
	print("BATTLEFIELD_FLEET_CHECK ",JSON.stringify(facts))
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
	scene.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
