extends SceneTree
## GUI acceptance with isolated, in-memory drops; never reads a player save.
var checks := 0
var failures := 0
var scene
var evidence := OS.get_environment("RESOURCE_ART_EVIDENCE")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func capture(label: String) -> void:
	scene.refresh_draw_layers(0.0)
	scene.battle_layer.queue_redraw()
	scene.overlay_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not evidence.is_empty():
		root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
func fixture(index: int, point: Vector2, amount: Variant = 1.0) -> Dictionary:
	var logical: Vector2=scene.battle_logical_point(point)
	var id := "1" if index%5 in [0,2] else ("2" if index%5==4 else "jewel")
	var drop := {"uid":900+index,"x":logical.x,"y":logical.y,"age":0.7,"id":id,"amount":amount}
	if id=="jewel":drop.jewel=true
	if index%5 in [2,3]:drop.hightech=true
	if index%5==4:drop.auto_gen=true;drop.speed=40.0
	return drop
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Resource art acceptance needs the graphical renderer")
		quit(1);return
	scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.beginner_guide.set_process(false)
	scene.beginner_guide.hide()
	scene.game.profile.cleared=range(1,41)
	scene.game.rebuild_unlocks()
	scene.refresh_structure()
	scene.game.drops.clear()
	scene.message_time=0.0
	for i in 5:
		scene.game.drops.append(fixture(i,Vector2(110+(i%3)*175,430+(i/3)*130)))
	var drops_before: Array=scene.game.drops.duplicate(true)
	var resources_before: Dictionary=scene.game.profile.resources.duplicate(true)
	var ui_before: int = scene.ui.get_child_count()
	var tabs = scene.equipment_tabs
	await capture("minimum")
	check(scene.game.drops==drops_before and scene.game.profile.resources==resources_before,"Rendering leaves drop amounts, ages and balances unchanged")
	check(scene.drop_layer.get_index()<scene.ship_view.get_index(),"Resources render behind the live 3D hull")
	for drop in scene.game.drops:drop.age=0.04 if drop.get("hightech",false) or drop.get("auto_gen",false) else 0.54
	await capture("spawn")
	for drop in scene.game.drops:drop.age=0.7
	# Three different currencies coexist; real pointer events still use the host's
	# original display anchor and game-owned collection rules.
	for drop in scene.game.drops.duplicate():
		var point: Vector2=scene.drop_render_position(drop)
		var click := InputEventMouseButton.new()
		click.position=scene.battle_layer.to_global(point)
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		scene._unhandled_input(click)
		check(not scene.game.drops.has(drop),"Visible resource collects through actual mouse input")
	check(scene.floats.filter(func(f):return f.get("resource","")=="jewel").size()==1,"Fragment collections aggregate into one pickup notice")
	check(scene.floats.any(func(f):return f.get("resource","")=="jewel" and str(f.text).contains(UIText.t("main._ready.text_02"))),"Fragment pickup shows the actual currency name")
	await capture("pickup")
	for effect in scene.pickup_effects:effect.life=float(effect.duration)*0.6
	await capture("pickup-flight")
	# Simultaneous large values must fit existing resource UI and pickup notices.
	scene.game.profile.resources["1"]={"m":1.23,"e":420}
	scene.game.profile.resources["2"]=1e200
	scene.game.profile.jewelFragments=1e100
	scene.game.drops.clear()
	for i in 5:
		scene.game.drops.append(fixture(i,Vector2(110+(i%3)*175,430+(i/3)*130),{"m":1.23,"e":420} if i%5 in [0,2] else 1e100))
	var hover := InputEventMouseMotion.new()
	hover.position=scene.battle_layer.to_global(scene.drop_render_position(scene.game.drops[2]))
	root.warp_mouse(hover.position)
	Input.parse_input_event(hover)
	await capture("large")
	scene.select_system(4)
	await capture("enhancement-balance")
	var fragment_icon: TextureRect=scene.enhancement_panel.get_child(0).get_node("FragmentBalanceIcon")
	check(fragment_icon.size==Vector2(32,32) and not fragment_icon.get_global_rect().intersects(scene.enhancement_panel.balance_label.get_global_rect()),"Fragment balance icon fits its slot without covering the value")
	check(scene.enhancement_panel.balance_label.tooltip_text.contains("100"),"Large fragment balance retains exact tooltip")
	scene.select_system(0)
	# Density must not allocate a node for each item or replace unrelated controls.
	scene.game.drops.clear()
	scene.floats.clear()
	scene.pickup_effects.clear()
	for i in 160:
		scene.game.drops.append(fixture(i,Vector2(35+(i%16)*33,340+(i/16)*42),3.0))
	await capture("density")
	check(scene.ui.get_child_count()==ui_before and scene.equipment_tabs==tabs,"Dense drops retain controls and their instance identities")
	for drop in scene.game.drops.duplicate():scene.game.collect(drop,true)
	check(scene.pickup_effects.size()<=24,"Dense collection keeps the existing bounded pickup budget")
	check(scene.floats.size()==3,"Dense collection aggregates all amounts into three currency notices")
	for id in ["1","2","jewel"]:
		var expected := 0.0
		for i in 160:
			var drop := fixture(i,Vector2.ZERO,3.0)
			if drop.id==id:expected+=float(drop.amount)
		var notice: Dictionary=scene.floats.filter(func(f):return f.get("resource","")==id).front()
		check(GrowthNumber.compare(notice.amount,expected)==0,"Pickup aggregation preserves credited amounts for "+id)
	await capture("density-pickup")
	scene.game.drops.clear()
	for i in 30:
		scene.game.drops.append(fixture(i,scene.player_render_position()+Vector2((i%6-3)*18,(i/6-2)*18)))
	await capture("hull-overlap")
	scene.game.paused=true
	var pickups_before: Array=scene.pickup_effects.duplicate(true)
	var redraws := [0]
	scene.drop_layer.draw.connect(func():redraws[0]+=1)
	scene._process(0.2)
	check(scene.pickup_effects==pickups_before,"Pause freezes pickup flights")
	await process_frame
	check(redraws[0]==0,"Paused resources retain draw commands without a redraw")
	# Foreground feedback must follow the pointer even while gameplay is paused.
	scene.pickup_effects.clear()
	scene.floats.clear()
	scene.game.drops.clear()
	var covered := fixture(2,scene.player_render_position(),7.0)
	scene.game.drops.append(covered)
	root.warp_mouse(scene.battle_layer.to_global(Vector2(20,260)))
	scene.refresh_draw_layers(0.016)
	await process_frame
	await RenderingServer.frame_post_draw
	var overlay_redraws := [0]
	scene.overlay_layer.draw.connect(func():overlay_redraws[0]+=1)
	root.warp_mouse(scene.battle_layer.to_global(scene.drop_render_position(covered)))
	await process_frame
	scene.refresh_draw_layers(0.016)
	await process_frame
	await RenderingServer.frame_post_draw
	check(overlay_redraws[0]>0,"Paused hover enters with foreground feedback above the ship")
	if not evidence.is_empty():root.get_texture().get_image().save_png(evidence.path_join("paused-hull-hover.png"))
	overlay_redraws[0]=0
	root.warp_mouse(scene.battle_layer.to_global(Vector2(20,260)))
	await process_frame
	scene.refresh_draw_layers(0.016)
	await process_frame
	await RenderingServer.frame_post_draw
	check(overlay_redraws[0]>0,"Paused hover clears when the pointer leaves")
	overlay_redraws[0]=0
	scene.refresh_draw_layers(0.016)
	await process_frame
	check(overlay_redraws[0]==0,"Stationary paused hover does not continuously redraw")
	scene.game.paused=false
	scene.game.profile.resources["1"]=100.0
	var amount_before: Variant=scene.game.profile.resources["1"]
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=scene.battle_layer.to_global(scene.drop_render_position(covered))
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
	check(not scene.game.drops.has(covered),"Actual viewport click collects a resource behind the ship")
	check(GrowthNumber.compare(scene.game.profile.resources["1"],GrowthNumber.add(amount_before,7.0))==0,"Covered pickup preserves its full manual credit")
	print("RESOURCE ART: ",checks," checks, ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
