extends SceneTree

const OUT := "res://docs/tasks/playtest-ui-art/evidence/"

func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	var scene:Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in 80:await process_frame
	await capture("main-live.png")
	scene.select_system(1)
	for i in 15:await process_frame
	await capture("factory-idle.png")
	scene.hightech_page.set_drawer_open(true)
	for i in 4:await process_frame
	await capture("factory-drawer.png")
	scene.hightech_page.set_drawer_open(false)
	var started:bool=scene.game.select_tech("singularity")
	scene.game.paused=false
	scene.hightech_page.invalidate(true)
	print("ART_CAPTURE research_started=",started," paused=",scene.game.paused)
	for sample in 6:
		for frame in 18:await process_frame
		await capture("factory-active-%02d.png" % sample)
		print("ART_CAPTURE sample=",sample," progress=",scene.game.profile.aiTechProgress.get("singularity",0)," phase=",scene.hightech_page.art.phase)
	scene.game.paused=true
	scene.hightech_page.invalidate(true)
	var phase_before:float=scene.hightech_page.art.phase
	for frame in 20:await process_frame
	await capture("factory-paused.png")
	print("ART_CAPTURE pause_phase_before=",phase_before," after=",scene.hightech_page.art.phase)
	scene.game.paused=false
	scene.hightech_page.invalidate(true)
	scene.hightech_page.set_drawer_open(true)
	var drawer_phase:float=scene.hightech_page.art.phase
	for frame in 20:await process_frame
	await capture("factory-active-drawer.png")
	print("ART_CAPTURE drawer_phase_before=",drawer_phase," after=",scene.hightech_page.art.phase)
	scene.hightech_page.set_drawer_open(false)
	scene.select_system(0)
	for frame in 6:await process_frame
	await capture("equipment-fee.png")
	scene.equipment_tabs.set_tab_hidden(11,false)
	scene.select_system(11)
	for frame in 8:await process_frame
	scene.enemy_intel_page.show_point(2)
	for frame in 3:await process_frame
	await capture("enemy-intel-point3.png")
	for entry in scene.enemy_intel_page.entries:
		if int(entry.point)==2:print("ART_CAPTURE point3 id=",entry.id," count=",entry.count," label=",entry.display_name)
	quit()

func capture(filename:String) -> void:
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path(OUT+filename)
	var err:=root.get_texture().get_image().save_png(path)
	print("ART_CAPTURE ",filename," result=",err)
