extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game: Node2D = load("res://src/main.tscn").instantiate()
    root.add_child(game)
    for i in 20: await process_frame
    var session = game.session
    print("INSPECT_STAGE5_PROGRESS ",session.campaign_system.progress_facts()," ",session.campaign_system.scenery_facts()," pause=",session.pause_reasons)
    print("INSPECT_STAGE5_HUD ",session.battle.hud_values())
    print("INSPECT_STAGE5_BUDGET ",session.economy.budget())
    print("INSPECT_STAGE5_EQUIPMENT ",session.equipment.save_state().slots)
    print("INSPECT_STAGE5_REACTOR ",session.reactor_system.presentation_model())
    print("INSPECT_STAGE5_ENEMY_COUNT ",session.battle.enemy_intelligence().size())
    quit()
