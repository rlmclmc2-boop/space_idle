extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    root.size = Vector2i(1440, 900)
    root.content_scale_size = Vector2i(1440, 900)
    var game: Node2D = load("res://src/main.tscn").instantiate()
    root.add_child(game)
    for i in 20: await process_frame
    assert(game.startup_error.is_empty())
    var session = game.session
    assert(session != null and session.run_state.is_running())
    var pending: Dictionary = session.pending_guidance()
    var tries := 0
    while not pending.is_empty() and tries < 20:
        assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
        pending = session.pending_guidance()
        tries += 1
    game._sync_guidance()
    print("R12_NATURAL_INITIAL progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " feature=", session.campaign_system.available("feature", "reactor"), " condensation=", session.campaign_system.available("reactor_module", "condensation"), " enabled=", session.reactor_system.enabled_modules())
    assert(not session.campaign_system.available("feature", "reactor"))
    var calls := 0
    while calls < 30000 and session.run_state.is_running() and not session.campaign_system.available("feature", "reactor"):
        session.frame(1.0 / 60.0, false)
        calls += 1
        if calls % 60 == 0 and not session.pause_reasons.is_empty():
            print("R12_NATURAL_PAUSE calls=", calls, " reasons=", session.pause_reasons, " guidance=", session.pending_guidance())
            pending = session.pending_guidance()
            tries = 0
            while not pending.is_empty() and tries < 20:
                assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
                pending = session.pending_guidance()
                tries += 1
            game._sync_guidance()
        if calls % 1200 == 0:
            print("R12_NATURAL_PROGRESS calls=", calls, " progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " pending=", session.pending_seconds)
            await process_frame
    print("R12_NATURAL_FINAL calls=", calls, " progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " feature=", session.campaign_system.available("feature", "reactor"), " condensation=", session.campaign_system.available("reactor_module", "condensation"), " enabled=", session.reactor_system.enabled_modules(), " running=", session.run_state.is_running(), " reason=", session.run_state.reason())
    if session.campaign_system.available("feature", "reactor"):
        pending = session.pending_guidance()
        tries = 0
        while not pending.is_empty() and tries < 20:
            assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
            pending = session.pending_guidance()
            tries += 1
        game._sync_guidance()
        game._select_left_module("reactor")
        for i in 5: await process_frame
        print("R12_NATURAL_VISUAL model=", session.reactor_system.presentation_model(), " scene_visible=", game.reactor_scene.visible)
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("/tmp/reactor-natural-r12b/stage1.png")
    quit()
