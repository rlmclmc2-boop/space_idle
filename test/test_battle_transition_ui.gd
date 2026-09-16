extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.highestLevel=int(scene.db.config.jewelDropLevel)
	scene.game.start(1,false)
	scene.game.spawn_group()
	for enemy in scene.game.enemies:enemy.hp=0
	scene.particles.clear()
	scene.floats.clear()
	scene.shake=0
	scene.star_streak=0
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var combat := root.get_texture().get_image()
	combat.save_png("res://.runtime/transition-combat.png")
	var panel=scene.jewel_panel
	check(not panel.visible,"Workshop starts closed without an explicit open")
	var tabs=scene.equipment_tabs
	var draws := {"background":0,"chrome":0,"stars":0,"tabs":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.chrome_layer.draw.connect(func():draws.chrome+=1)
	scene.stars_layer.draw.connect(func():draws.stars+=1)
	tabs.draw.connect(func():draws.tabs+=1)
	scene.game.tick(0)
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var travel := root.get_texture().get_image()
	travel.save_png("res://.runtime/transition-travel.png")
	var region := Rect2i(420,230,580,300)
	check(combat.get_region(region).get_data()==travel.get_region(region).get_data(),"Transition frame has no abrupt background brightness change")
	check(draws.values().all(func(count):return count==0),"State transition does not redraw static layers, tabs or unchanged stars")
	check(not panel.visible and scene.equipment_tabs==tabs,"Wave end retains closed workshop and existing UI")
	scene._process(1.0/60.0)
	check(scene.star_streak>0 and scene.star_streak<0.1,"Travel trails fade in gradually")
	for i in 20:scene._process(1.0/60.0)
	check(is_equal_approx(scene.star_streak,1),"Travel trails reach normal appearance")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/transition-cruising.png")
	scene.game.spawn_group()
	check(is_equal_approx(scene.star_streak,1),"Encounter event does not abruptly remove trails")
	scene._process(1.0/60.0)
	check(scene.star_streak>0.9 and scene.star_streak<1,"Encounter trails fade out gradually")
	scene.game.paused=true
	var streak: float=scene.star_streak
	await process_frame
	for key in draws:draws[key]=0
	for i in 3:scene._process(1.0/60.0)
	await process_frame
	check(scene.star_streak==streak and draws.stars==0,"Pause freezes star effect without redraw")
	scene.game.pickup_jewel_fragment("1")
	scene.on_event("jewels_changed",{"slot":""})
	scene.game.change_state(BattleGame.State.LEVEL_CLEAR)
	check(not panel.visible and not panel.is_processing(),"Pickup and state events cannot open workshop")
	panel.open()
	check(panel.visible,"Explicit open still works")
	panel.hide()
	scene.game.change_state(BattleGame.State.TRAVEL)
	scene.refresh_navigation()
	check(not panel.visible,"Closed workshop stays closed at next battle point")
	check(scene.equipment_tabs==tabs,"Transition animation never rebuilds controls")
	print("Battle transition UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
