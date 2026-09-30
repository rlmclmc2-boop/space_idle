extends SceneTree
## Run in an isolated copy + user directory. Uses the actual production main scene.
var scene
var failures:Array[String]=[]
var output:=""
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:
	call_deferred("run")
func capture(label:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run()->void:
	output=ProjectSettings.globalize_path("res://.runtime")
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	root.size=Vector2i(1373,883)
	for i in 3:await process_frame
	if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
	check(scene.game.save_enabled,"Production startup must preserve save support")
	check(scene.fixture_name.is_empty(),"Production startup has no fixture")
	var first_ship:=str(scene.game.profile.selectedShip)
	check(first_ship==scene.game.first_ship(),"Fresh user starts with the normal first ship")
	check(scene.game.profile.unlocked==scene.game.fresh_profile().unlocked,"Fresh unlocks are authoritative")
	check(scene.ship_view.modules.size()==scene.game.weapon_entries().filter(func(e):return not str(e.key).is_empty()).size(),"Fresh visual modules match actual equipment")
	for i in 300:scene._process(1.0/60.0)
	await capture("new-player")
	var profile:=JSON.stringify(scene.game.profile)
	scene.game.save_progress()
	var restored=load("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),true)
	check(restored.profile.selectedShip==scene.game.profile.selectedShip,"Load preserves selected ship")
	for category in ["weapons","defence"]:
		var actual:Array=restored.profile.loadout[category]
		var expected:Array=scene.game.profile.loadout[category]
		check(actual.size()==expected.size(),"Load preserves module capacity: "+category)
		for i in expected.size():
			for field in ["key","level"]:check(actual[i][field]==expected[i][field],"Load preserves module "+category+str(i)+field)
			for field in ["attacks","hits"]:check(actual[i].get(field,0)==expected[i].get(field,0),"Load preserves counters "+field)
			check(actual[i].get("sockets",[])==expected[i].get("sockets",[]),"Load preserves gem sockets")
	check(restored.profile.unlocked==scene.game.profile.unlocked,"Load preserves unlocks")
	# Advance ordinary starting combat: unchanged enemy HP, no injected inventory.
	var fights:=0
	for i in 600:
		scene._process(1.0/60.0)
		if scene.game.state==BattleGame.State.COMBAT:fights+=1
		if i%120==0:await process_frame
	check(fights>0,"Fresh player reaches actual combat")
	await capture("new-player-combat")
	scene.game.paused=true
	scene._process(0.0)
	await process_frame
	var time:float=scene.game.distance
	var orbit:float=scene.ship_view.orbit_elapsed
	var clock:float=scene.fx_time
	for i in 4:scene._process(1.0/30.0)
	check(scene.game.distance==time and scene.fx_time==clock and scene.ship_view.orbit_elapsed==orbit,"Pause freezes combat, FX and drone orbits")
	root.size=Vector2i(960,540)
	await capture("narrow-paused")
	check(scene.ship_view.size==scene.BATTLE_VIEW_SIZE,"Window resize retains logical render surface")
	print("BATTLEFIELD_LIVE_CHECK ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"fresh_ship":first_ship,"save_enabled":scene.game.save_enabled,"modules":scene.ship_view.modules.size(),"combat_frames":fights,"fresh_profile_bytes":profile.length()}))
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
