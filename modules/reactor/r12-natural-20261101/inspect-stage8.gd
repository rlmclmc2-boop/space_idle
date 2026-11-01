extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game: Node2D = load("res://src/main.tscn").instantiate()
    root.add_child(game)
    for i in 20: await process_frame
    var session = game.session
    print("INSPECT_STAGE8_PROGRESS ",session.campaign_system.progress_facts()," ",session.campaign_system.scenery_facts())
    print("INSPECT_STAGE8_BUDGET ",session.economy.budget())
    print("INSPECT_STAGE8_EQUIPMENT ",session.equipment.save_state().slots)
    print("INSPECT_STAGE8_DEFENCE_OPTIONS ",session.equipment.panel_equipment("defence:0"))
    print("INSPECT_STAGE8_WEAPON_OPTIONS ",session.equipment.panel_equipment("weapon:0"))
    print("INSPECT_STAGE8_REACTOR ",session.reactor_system.presentation_model())
    quit()
