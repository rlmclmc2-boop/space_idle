extends SceneTree
const OUT := "/tmp/space-idle-runtime472/reactor-bay-shared/"
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func clear_guidance(session, game) -> void:
	var pending: Dictionary=session.pending_guidance()
	while not pending.is_empty():
		assert(session.dismiss_guidance(str(pending.kind),str(pending.id)).ok)
		pending=session.pending_guidance()
	game._sync_guidance()
func click(control: Control) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=control.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await frames(2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=motion.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		Input.parse_input_event(event)
		await frames(3)
func run() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	var game=load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await frames(70)
	assert(game.startup_error.is_empty())
	game._skip_tutorial=true
	var session=game.session
	var saved: Dictionary=session.campaign_system.save_state()
	saved.grants["feature:reactor"]=true
	saved.grants["reactor_module:condensation"]=true
	assert(session.campaign_system.restore_state(saved).ok)
	session.reactor_system.refresh_availability(session.campaign_system.available)
	assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
	var credit: Dictionary=session.amount_api.apply("from_decimal",["1000000"])
	assert(credit.ok and session.economy.credit_yield("2",credit.value,session.wall_time,session.game_time).ok)
	clear_guidance(session,game)
	session.set_pause("user",false)
	game._refresh_feature_visibility()
	await click(game._zone_shell._route_buttons["reactor"])
	await frames(25)
	var scene=game.reactor_scene
	assert(scene.visible and not game.equipment_scene.visible)
	assert(session.reactor_system.presentation_model().modules.size()==4)
	assert(is_zero_approx(float(session.reactor_system.presentation_model().load)))
	await shot("reactor-four-zero")
	await click(scene._equal)
	await frames(85)
	clear_guidance(session,game)
	assert(scene.last_result.ok and is_equal_approx(float(session.reactor_system.presentation_model().load),1.0))
	assert(session.pause_reasons.is_empty() and session.current_chrono_speed()==1)
	await shot("reactor-four-active")
	var start: int=Engine.get_process_frames()
	var clock: float=session.game_time
	await frames(180)
	await RenderingServer.frame_post_draw
	var f=FileAccess.open(OUT+"movie-segment.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"start_process_frame":start,"end_process_frame":Engine.get_process_frames(),"fps":30,"speed":1,"simulated_seconds":6,"game_time_start":clock,"game_time_end":session.game_time,"stage_phase":scene._stage.visual_phase(),"pause_reasons":session.pause_reasons,"state":"四路Owner均分带载","method":"Godot MovieMaker fixed30fps offline; current full shared main"},"  "));f.close()
	var Reactor=load("res://src/systems/reactor.gd")
	var parameters: Dictionary=session.reactor_system._parameters.duplicate(true)
	parameters.reactorModules="smelting"
	var fixture=Reactor.new(parameters,session.amount_api,session.run_state)
	var publish: Callable=func(_factors,_wallet,_kind):
		fixture.accept()
		return {"ok":true}
	fixture.refresh_availability(func(kind,target):return kind=="feature" and target=="reactor")
	assert(fixture.refresh(session.reactor_inputs(),publish).ok)
	scene._owner=fixture;scene._publish=publish
	scene.bind_presentation(fixture.presentation_model,func():return {"game_time":session.game_time,"paused":false,"running":true})
	scene.bind_purchase_quote(func(quantity,maximum):return fixture.purchase_max_preview(session.economy.can_pay) if maximum else fixture.purchase_preview(session.economy.can_pay,quantity))
	fixture.presentation_changed.connect(scene.invalidate_presentation)
	await frames(25)
	await shot("reactor-one-zero")
	await click(scene._equal)
	await frames(85)
	assert(scene.last_result.ok and fixture.enabled_modules()==["smelting"])
	await shot("reactor-one-active")
	var one_start: int=Engine.get_process_frames()
	var one_clock: float=session.game_time
	await frames(180)
	await RenderingServer.frame_post_draw
	var one_file=FileAccess.open(OUT+"one-movie-segment.json",FileAccess.WRITE)
	one_file.store_string(JSON.stringify({"start_process_frame":one_start,"end_process_frame":Engine.get_process_frames(),"fps":30,"speed":1,"simulated_seconds":6,"game_time_start":one_clock,"game_time_end":session.game_time,"stage_phase":scene._stage.visual_phase(),"state":"单路受控Reactor Owner均分带载","method":"Godot MovieMaker fixed30fps offline; current full shared main"},"  "));one_file.close()
	var parameters_two: Dictionary=session.reactor_system._parameters.duplicate(true)
	parameters_two.reactorModules="smelting,weapons"
	var fixture_two=Reactor.new(parameters_two,session.amount_api,session.run_state)
	var publish_two: Callable=func(_factors,_wallet,_kind):
		fixture_two.accept()
		return {"ok":true}
	fixture_two.refresh_availability(func(kind,target):return kind=="feature" and target=="reactor")
	assert(fixture_two.refresh(session.reactor_inputs(),publish_two).ok)
	scene._owner=fixture_two;scene._publish=publish_two
	scene.bind_presentation(fixture_two.presentation_model,func():return {"game_time":session.game_time,"paused":false,"running":true})
	scene.bind_purchase_quote(func(quantity,maximum):return fixture_two.purchase_max_preview(session.economy.can_pay) if maximum else fixture_two.purchase_preview(session.economy.can_pay,quantity))
	fixture_two.presentation_changed.connect(scene.invalidate_presentation)
	await frames(25)
	await shot("reactor-two-zero")
	await click(scene._equal)
	await frames(85)
	assert(scene.last_result.ok and fixture_two.enabled_modules().size()==2)
	await shot("reactor-two-active")
	await click(game._zone_shell._route_buttons["equipment"])
	await frames(8)
	assert(game.equipment_scene.visible and not scene.visible)
	await shot("equipment-return")
	print("FACETED_SHARED source=3e0240c9 four_zero_active+one_zero_active+equipment_return; actual mouse equal/navigation; phase=",scene._stage.visual_phase())
	if session.save_files!=null:session.save_files.close(2000)
	game.queue_free()
	await frames(3)
	quit()
