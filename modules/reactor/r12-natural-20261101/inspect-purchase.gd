extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game: Node2D = load("res://src/main.tscn").instantiate()
    root.add_child(game)
    for i in 20: await process_frame
    var session = game.session
    print("INSPECT_PROGRESS ", session.campaign_system.progress_facts(), " ", session.campaign_system.scenery_facts())
    print("INSPECT_BUDGET ", session.economy.budget())
    print("INSPECT_EQUIPMENT ", session.equipment.save_state())
    var result: Dictionary = session.equipment.buy_all_levels(1, false, session.equipment_inputs(), session.economy.affordable, session.economy.payment, session.publish_equipment_levels)
    print("INSPECT_BUY ", result)
    quit()
