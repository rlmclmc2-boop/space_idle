extends SceneTree
## Render-only in-memory fixtures. Run against an isolated imported project/user dir.
## Does not validate native kernel performance or the pending 18-point configuration.
var scene
func _initialize()->void:call_deferred("run")
func run()->void:
	scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.capture_frame=-10000
	scene.game.save_enabled=false
	scene.game.profile.onboarding.completed=true
	scene.game.profile.highestLevel=3
	root.size=Vector2i(1373,883)
	for stage in range(1,4):
		scene.game.paused=false
		scene.game.start(stage,false)
		assert(scene.game.stage==stage,"Fixture stage entry failed")
		scene.game.spawn_group()
		scene.game.pending_unlocks.clear()
		for frame in 24:scene._process(0.02)
		scene.game.paused=true
		scene.refresh_structure()
		var before:Array=scene.game.enemies.duplicate(true)
		var distance:float=scene.game.distance
		var rng_state:int=scene.game.rng.state
		scene.refresh_draw_layers(0.0)
		scene.stars_layer.queue_redraw()
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(scene.game.enemies==before and scene.game.distance==distance and scene.game.rng.state==rng_state,"Renderer mutated authoritative state")
		root.get_texture().get_image().save_png("/tmp/opening-verify/stage-%d-ui.png"%stage)
		print("RENDER_OK stage=",stage," groups=",scene.db.levels[stage-1].groups.size()," native_available=",ClassDB.class_exists("SpaceCombatPresentation"))
	quit()
