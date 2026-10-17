extends SceneTree

const OUT := "res://docs/tasks/playtest-ui-art/evidence/animation/"
const REGION := Rect2i(548, 181, 795, 624)

func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	var scene:Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in 80:await process_frame
	if not scene.game.profile.cleared.has(3):scene.game.profile.cleared.append(3)
	scene.game.profile.highestLevel=maxi(4,int(scene.game.profile.highestLevel))
	scene.refresh_tab_visibility()
	assert(scene.game.ai_tech_factory_unlocked())
	scene.select_system(1)
	scene.game.profile.aiTechActive=""
	scene.game.paused=false
	var started:bool=scene.game.select_tech("singularity")
	assert(started)
	scene.hightech_page.invalidate(true)
	for i in 8:await process_frame
	scene.hightech_page.art.phase=0.0
	var directory:=ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(directory)
	print("ART_ANIMATION started=",started," game_paused=",scene.game.paused)
	for sample in 36:
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		var path:=directory+"frame_%02d.png" % sample
		var image:=root.get_texture().get_image().get_region(REGION)
		var err:=image.save_png(path)
		if err!=OK:push_error("Frame capture failed: "+str(err))
		if sample%6==0:print("ART_ANIMATION frame=",sample," progress=",scene.game.profile.aiTechProgress.get("singularity",0)," phase=",scene.hightech_page.art.phase)
	quit()
