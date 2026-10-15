extends SceneTree
## Short isolated layout fixture in the real main scene, no persisted save.
func _initialize()->void:call_deferred("run")
func refresh_guides(node:Node)->void:
	var script=node.get_script()
	if script!=null and str(script.resource_path).ends_with("beginner_guide.gd"):node.call("refresh")
	for child in node.get_children():refresh_guides(child)
func run()->void:
	var dir=OS.get_environment("OPENING_REVIEW_DIR")
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.capture_frame=-10000
	scene.game.save_enabled=false;scene.game.profile.highestLevel=2
	root.size=Vector2i(1373,883)
	for stage in [1,2]:
		scene.game.paused=false;scene.game.start(stage,false);scene.game.spawn_group();scene.game.pending_unlocks.clear()
		for frame in 24:scene._process(0.02)
		scene.game.paused=true;scene.game.profile.onboarding.completed=true;scene.game.profile.onboarding.dismissed=true
		scene.refresh_structure();refresh_guides(scene)
		var before=scene.game.enemies.duplicate(true);var distance=scene.game.distance;var rng_state=scene.game.rng.state
		scene.refresh_draw_layers(0.0);scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if scene.game.stage!=stage or scene.game.enemies!=before or scene.game.distance!=distance or scene.game.rng.state!=rng_state:
			push_error("Real scene render mutated state or fixture stage entry failed");quit(1);return
		root.get_texture().get_image().save_png(dir+"/main-stage-%d.png"%stage)
		print("MAIN_RENDER_OK stage=",stage," native=",ClassDB.class_exists("SpaceCombatPresentation")," texture=",scene.OPENING_SCENERY[stage-1].get_size())
	quit()
