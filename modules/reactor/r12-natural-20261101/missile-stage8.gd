extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game: Node2D = load("res://src/main.tscn").instantiate()
    root.add_child(game)
    for i in 20: await process_frame
    assert(game.startup_error.is_empty())
    var session = game.session
    assert(session != null and session.run_state.is_running())
    print("R12_PLAY_INITIAL progress=",session.campaign_system.progress_facts()," state=",session.campaign_system.scenery_facts()," reactor=",session.reactor_system.presentation_model())
    var shield_refit: Dictionary = session.equipment.equip_slot("weapon:0","missile",session.equipment_inputs(),session.publish_equipment_refit)
    print("R12_PLAY_MISSILE_REFIT ",shield_refit," slots=",session.equipment.save_state().slots)
    var calls := 0
    var peak_stage: int = int(session.campaign_system.progress_facts().highest_reached)
    var stagnant := 0
    var reactor_purchases := 0
    while calls < 24000 and session.run_state.is_running() and not session.campaign_system.available("reactor_module","condensation"):
        session.frame(1.0/60.0,false)
        calls += 1
        var reached: int = int(session.campaign_system.progress_facts().highest_reached)
        if reached > peak_stage:
            peak_stage = reached
            stagnant = 0
            print("R12_PLAY_REACHED stage=",peak_stage," calls=",calls," cleared=",session.campaign_system.progress_facts().cleared_stages)
        else: stagnant += 1
        if calls % 60 == 0 and not session.pause_reasons.is_empty():
            var pending: Dictionary = session.pending_guidance()
            print("R12_PLAY_PAUSE calls=",calls," reasons=",session.pause_reasons," guidance=",pending)
            var tries := 0
            while not pending.is_empty() and tries < 20:
                assert(session.dismiss_guidance(str(pending.kind),str(pending.id)).ok)
                pending=session.pending_guidance()
                tries += 1
            game._sync_guidance()
        if calls % 300 == 0:
            session.equipment.buy_all_levels(1,false,session.equipment_inputs(),session.economy.affordable,session.economy.payment,session.publish_equipment_levels)
        if calls % 3000 == 0:
            var bought: Dictionary = session.reactor_system.purchase(1,false,session.reactor_inputs(),session.economy.payment,session.publish_reactor)
            if bought.ok:
                reactor_purchases += 1
                var capacity: String = str(session.reactor_system.presentation_model().capacity)
                var assigned: Dictionary = session.reactor_system.allocate_text("weapons",capacity,session.reactor_inputs(),session.publish_reactor)
                print("R12_PLAY_REACTOR calls=",calls," level=",session.reactor_system.presentation_model().level," capacity=",capacity," assigned=",assigned.ok)
        if calls % 6000 == 0:
            print("R12_PLAY_PROGRESS calls=",calls," progress=",session.campaign_system.progress_facts()," state=",session.campaign_system.scenery_facts()," hud=",session.battle.hud_values()," enemy=",session.battle.enemy_intelligence().slice(0,1)," budget=",session.economy.budget())
            await process_frame
        if stagnant >= 30000 and peak_stage < 15:
            print("R12_PLAY_STALLED stage=",peak_stage," calls=",calls," state=",session.campaign_system.scenery_facts())
            break
    print("R12_PLAY_FINAL calls=",calls," progress=",session.campaign_system.progress_facts()," state=",session.campaign_system.scenery_facts()," condensation=",session.campaign_system.available("reactor_module","condensation")," enabled=",session.reactor_system.enabled_modules()," reactor_purchases=",reactor_purchases," running=",session.run_state.is_running()," reason=",session.run_state.reason())
    quit()
