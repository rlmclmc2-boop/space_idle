extends SceneTree

const OUT := "res://docs/tasks/playtest-ui-art/evidence/"

func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in 80: await process_frame
	var game = scene.game
	# Reached stage 4 after clearing stage 3: the integrated factory unlock gate.
	if not game.profile.cleared.has(3): game.profile.cleared.append(3)
	game.profile.highestLevel = maxi(4, int(game.profile.highestLevel))
	scene.refresh_tab_visibility()
	assert(game.ai_tech_factory_unlocked())
	scene.select_system(1)
	scene.hightech_page.invalidate(true)
	for frame in 8: await process_frame
	await capture("integrated-factory-idle.png")
	var started: bool = game.select_tech("singularity")
	assert(started)
	game.paused = false
	scene.hightech_page.invalidate(true)
	for sample in 3:
		for frame in 18: await process_frame
		await capture("integrated-factory-active-%02d.png" % sample)
		print("ART_INTEGRATION progress=", game.profile.aiTechProgress.get("singularity", 0), " phase=", scene.hightech_page.art.phase)
	quit()

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + filename))
	print("ART_INTEGRATION ", filename, " result=", error)
