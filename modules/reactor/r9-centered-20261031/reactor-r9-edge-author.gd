extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func clear_guidance(session, game) -> void:
	var pending: Dictionary = session.pending_guidance()
	var tries := 0
	while not pending.is_empty() and tries < 20:
		assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
		pending = session.pending_guidance()
		tries += 1
	game._sync_guidance()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "/tmp/reactor-r9-edge-" + label + "-1440x900.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("CAPTURE ", path)

func run() -> void:
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	var game: Node2D = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	var session = game.session
	assert(session != null and game.startup_error.is_empty())
	assert(session.current_chrono_speed() == 1)
	var campaign: Dictionary = session.campaign_system.save_state()
	campaign.grants["feature:reactor"] = true
	campaign.grants["reactor_module:condensation"] = true
	assert(session.campaign_system.restore_state(campaign).ok)
	assert(session.reactor_system.refresh_availability(session.campaign_system.available))
	assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
	clear_guidance(session,game)
	game._select_left_module("reactor")
	await frames(5)
	var scene = game.reactor_scene
	assert(scene != null and scene.visible)
	var amount: Dictionary = session.amount_api.apply("from_decimal",["1000"])
	assert(amount.ok)
	assert(session.economy.credit_yield("2",amount.value,session.wall_time,session.game_time).ok)
	scene._equal.pressed.emit()
	await create_timer(2.3).timeout
	await frames(2)
	clear_guidance(session,game)
	var owner = session.reactor_system
	var model: Dictionary = owner.presentation_model()
	assert(model.ok and model.modules.size() == 4)
	for row in model.modules: assert(float(row.load) > 0.0)
	await capture("all-active")
	var changed: Dictionary = owner.allocate_text("defence","0",session.reactor_inputs(),session.publish_reactor)
	assert(changed.ok)
	await create_timer(2.3).timeout
	await frames(2)
	clear_guidance(session,game)
	model = owner.presentation_model()
	assert(model.ok and model.modules.size() == 4)
	assert(float(model.modules[1].load) == 0.0)
	assert(float(model.modules[0].load) > 0.0 and float(model.modules[2].load) > 0.0)
	await capture("mixed-zero")
	changed = owner.allocate_text("defence","1",session.reactor_inputs(),session.publish_reactor)
	assert(changed.ok)
	await create_timer(2.3).timeout
	await frames(2)
	clear_guidance(session,game)
	model = owner.presentation_model()
	assert(model.ok and float(model.modules[1].load) > 0.0 and float(model.modules[1].load) <= 0.01)
	await capture("low-positive")
	var phase_before: float = scene._stage.visual_phase()
	game._select_left_module("equipment")
	await create_timer(1.0).timeout
	assert(not scene.visible)
	var phase_hidden: float = scene._stage.visual_phase()
	assert(is_equal_approx(phase_hidden,phase_before))
	game._select_left_module("reactor")
	await create_timer(0.5).timeout
	await frames(2)
	clear_guidance(session,game)
	assert(scene.visible and scene._stage.visual_phase() > phase_hidden)
	model = owner.presentation_model()
	assert(model.ok and float(model.modules[1].load) > 0.0)
	await capture("reopened-low-positive")
	print("EDGE_DONE def_load=",model.modules[1].load," phase_before=",phase_before," phase_hidden=",phase_hidden," phase_after=",scene._stage.visual_phase())
	quit()
