extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var scene = load("res://main.tscn").instantiate()
    scene.automation_args = ["--capture"]
    root.add_child(scene)
    scene.set_process(false)
    scene.game.save_enabled = false
    scene.game.pending_unlocks.clear()
    assert(scene.game.start(1, false), "stage1 start failed")
    for tick in 60: scene._process(1.0 / 60.0)
    print("STAGE1_MAIN_OK stage=", scene.game.stage, " state=", scene.game.state, " enemies=", scene.game.enemies.size())
    quit()
