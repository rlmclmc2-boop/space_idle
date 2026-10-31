extends SceneTree

const MODULES := ["weapons", "defence", "smelting", "condensation"]

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
	var path := "/tmp/reactor-r11-evidence/reactor-r11-controlled-" + label + "-1440x900.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("CAPTURE ", path)

func publish_controlled(factors: Dictionary, next_wallet, kind: String, session, neutral: Dictionary) -> Dictionary:
	var full: Dictionary = neutral.duplicate(true)
	for id in factors: full[id] = factors[id]
	return session.publish_reactor(full, next_wallet, kind)

func run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
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
	assert(session.reactor_system.refresh(session.reactor_inputs(), session.publish_reactor).ok)
	clear_guidance(session, game)
	game._select_left_module("reactor")
	await frames(4)
	var scene = game.reactor_scene
	assert(scene != null and scene.visible)
	var amount: Dictionary = session.amount_api.apply("from_decimal", ["1000"])
	assert(amount.ok)
	assert(session.economy.credit_yield("2", amount.value, session.wall_time, session.game_time).ok)
	var owner = session.reactor_system
	var seed: Dictionary = owner.save_state()
	var zero: Dictionary = session.amount_api.apply("zero", [])
	assert(zero.ok)
	var neutral: Dictionary = session._reactor_factors.duplicate(true)
	var publish: Callable = publish_controlled.bind(session, neutral)
	for count in range(1, 5):
		var ids: Array = MODULES.slice(0, count)
		owner._parameters["reactorModules"] = ",".join(PackedStringArray(ids))
		var state: Dictionary = seed.duplicate(true)
		state.allocations = {}
		for id in ids: state.allocations[id] = zero.value
		assert(owner.restore_state(state).ok)
		owner.refresh_availability(func(kind, id): return kind == "feature" or id == "condensation")
		assert(owner.refresh(session.reactor_inputs(), publish).ok)
		scene._dirty = true
		scene._refresh()
		await frames(5)
		clear_guidance(session, game)
		var model: Dictionary = owner.presentation_model()
		assert(model.ok and model.modules.size() == count and float(model.load) == 0.0)
		assert(scene._ids.size() == count)
		await capture(str(count) + "-zero")
		assert(not scene._equal.disabled)
		assert(owner.distribute(session.reactor_inputs(), publish).ok)
		scene._dirty = true
		scene._refresh()
		await frames(5)
		clear_guidance(session, game)
		model = owner.presentation_model()
		assert(model.ok and model.modules.size() == count and float(model.load) > 0.0)
		for row in model.modules: assert(float(row.load) > 0.0)
		await capture(str(count) + "-active")
		print("STATE ", count, " IDs=", ids, " LOAD=", model.load)
	quit()
