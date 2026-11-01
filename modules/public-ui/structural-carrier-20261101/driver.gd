extends SceneTree
const OUT := "/tmp/space-idle-runtime472/public-structural-carrier/"
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func point(button: Button) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=button.get_global_rect().get_center()
	Input.parse_input_event(event)
func press(button: Button, down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=button.get_global_rect().get_center()
	event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	Input.parse_input_event(event)
func run() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	var game=load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await frames(60)
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial=true
	var session=game.session
	for pair in [["1","12345678901234567890123"],["2","999900000000000000"]]:
		var amount: Dictionary=session.amount_api.apply("from_decimal",[pair[1]])
		assert(amount.ok and session.economy.credit_yield(pair[0],amount.value,session.wall_time,session.game_time).ok)
	var pending: Dictionary=session.pending_guidance()
	while not pending.is_empty():
		assert(session.dismiss_guidance(str(pending.kind),str(pending.id)).ok)
		pending=session.pending_guidance()
	game._sync_guidance()
	game._refresh_feature_visibility()
	await frames(8)
	var shell=game._zone_shell
	assert(shell._active_route=="equipment")
	await shot("equipment")
	for cell in shell._balances:
		var font: Font=cell.get_theme_font("font")
		assert(font.get_string_size(cell.text,HORIZONTAL_ALIGNMENT_LEFT,-1,cell.get_theme_font_size("font_size")).x<=cell.size.x)
	var start: int=Engine.get_process_frames()
	var settings: Button=shell._route_buttons.settings
	point(settings)
	await frames(12)
	assert(settings.is_hovered())
	await shot("settings-nav-hover")
	press(settings,true)
	await frames(12)
	assert(bool(shell._route_held.get("settings",false)))
	await shot("settings-nav-held")
	press(settings,false)
	await frames(12)
	assert(shell._active_route=="settings")
	await shot("settings")
	var equipment: Button=shell._route_buttons.equipment
	point(equipment)
	await frames(12)
	await shot("equipment-nav-hover")
	press(equipment,true)
	await frames(12)
	await shot("equipment-nav-held")
	press(equipment,false)
	await frames(12)
	assert(shell._active_route=="equipment")
	await shot("equipment-return")
	var end: int=Engine.get_process_frames()
	var file=FileAccess.open(OUT+"movie-segment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"start_process_frame":start,"end_process_frame":end,"fps":30,"method":"Godot MovieMaker fixed30fps offline; native mouse hover/down/up for two routes; whole viewport continuous","state":"受控长余额/业务快照暂停"},"  "));file.close()
	var saved: Dictionary=session.campaign_system.save_state()
	saved.grants["feature:reactor"]=true
	assert(session.campaign_system.restore_state(saved).ok)
	session.reactor_system.refresh_availability(session.campaign_system.available)
	assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
	game._refresh_feature_visibility()
	shell._route_buttons.reactor.pressed.emit()
	await frames(8)
	await shot("reactor-carrier-boundary")
	assert(game.reactor_scene.visible)
	print("PUBLIC_STRUCTURAL two_native_mouse_routes=ok long_amounts_fit=ok no_owner_logic_change reactor_body=production_baseline_not_approved")
	if session.save_files!=null:session.save_files.close(2000)
	game.queue_free()
	await frames(3)
	quit()
