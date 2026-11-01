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
    print("R12_CONTINUE_INITIAL progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " enabled=", session.reactor_system.enabled_modules())
    var allocation: Dictionary = session.reactor_system.allocate_text("weapons", "100", session.reactor_inputs(), session.publish_reactor)
    print("R12_ALLOCATE ", allocation, " model=", session.reactor_system.presentation_model())
    var calls := 0
    var peak_stage: int = int(session.campaign_system.progress_facts().highest_reached)
    var stagnant := 0
    while calls < 18000 and session.run_state.is_running() and not session.campaign_system.available("reactor_module", "condensation"):
        session.frame(1.0 / 60.0, false)
        calls += 1
        var now_stage: int = int(session.campaign_system.progress_facts().highest_reached)
        if now_stage > peak_stage:
            peak_stage = now_stage
            stagnant = 0
            print("R12_CONTINUE_REACHED stage=", peak_stage, " calls=", calls)
        else:
            stagnant += 1
        if calls % 60 == 0 and not session.pause_reasons.is_empty():
            var pending: Dictionary = session.pending_guidance()
            print("R12_CONTINUE_PAUSE calls=", calls, " reasons=", session.pause_reasons, " guidance=", pending)
            var tries := 0
            while not pending.is_empty() and tries < 20:
                assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
                pending = session.pending_guidance()
                tries += 1
            game._sync_guidance()
        if calls % 3000 == 0:
            print("R12_CONTINUE_PROGRESS calls=", calls, " progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " pause=", session.pause_reasons, " hud=", session.battle.hud_values())
            await process_frame
        if stagnant >= 30000 and peak_stage < 15:
            print("R12_CONTINUE_STALLED stage=", peak_stage, " calls=", calls, " state=", session.campaign_system.scenery_facts())
            break
    print("R12_CONTINUE_FINAL calls=", calls, " progress=", session.campaign_system.progress_facts(), " state=", session.campaign_system.scenery_facts(), " condensation=", session.campaign_system.available("reactor_module", "condensation"), " enabled=", session.reactor_system.enabled_modules(), " running=", session.run_state.is_running(), " reason=", session.run_state.reason())
    quit()
