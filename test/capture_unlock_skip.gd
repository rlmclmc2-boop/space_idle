extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.automation_args = ["--capture"]
 root.add_child(scene)
 scene.set_process(false)
 scene.game.save_enabled = false
 scene.game.profile.onboarding.completed = true
 scene.beginner_guide.set_process(false)
 scene.beginner_guide.hide()
 scene.set_tutorial_auto_skip(false)
 scene.game.pending_unlocks.assign([scene.db.unlock_id("equipment","shield")])
 scene.refresh_navigation()
 scene.layout_overlay_controls()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../test/unlock-skip-off.png")
 scene.unlock_skip_checkbox.button_pressed=true
 scene.refresh_navigation()
 scene.layout_overlay_controls()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../test/unlock-skip-on.png")
 await create_timer(5).timeout
 quit()
