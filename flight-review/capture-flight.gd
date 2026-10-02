extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var failures := 0
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport: Viewport=root
	root.title="Galaxy Art QA · 太空战舰"
	root.gui_embed_subwindows=true
	root.close_requested.connect(func():quit())
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	scene.music_on=false
	scene.automation_args=["--capture"]
	root.add_child(scene)
	root.title="Galaxy Art QA · 太空战舰"
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	var g=scene.game
	g.save_enabled=false
	g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.visible=false

	g.profile.cleared=range(1,int(g.db.data.unlock["feature/galaxy"].level)+1)
	g.profile.highestLevel=int(g.db.data.unlock["feature/galaxy"].level)+1
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	for progress in g.profile.planets.values():progress.conquered=true
	g.rebuild_unlocks()
	g.galaxy.refresh_unlocks(g)
	scene.refresh_structure()
	scene.refresh_tab_visibility()
	print("GALAXY UI SETUP status=",g.galaxy.regions.galaxy_1.state.status," hidden=",scene.equipment_tabs.is_tab_hidden(8))
	scene.select_system(8)
	await process_frame
	await process_frame
	var panel=scene.galaxy_panel
	panel.refresh()
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/galaxy_1_complete.json"))
	await record_construction(viewport,scene,panel,fixture,12.0)
	quit()

func record_construction(viewport: Viewport,scene,panel,fixture: Dictionary,seconds: float) -> void:
	if DisplayServer.get_name()=="headless":push_error("Real-time recording requires the native game viewport");return
	var g=scene.game
	g.galaxy.load_state(g,{"galaxy_1":fixture.save})
	var region=g.galaxy.regions.galaxy_1
	for slot in region.slots:
		var built: bool=OS.get_environment("GALAXY_CITY_RECORD")=="1" or int(slot.id)<15
		slot.status="active" if built else "empty"
		slot.level=(1+int(slot.id)%5 if OS.get_environment("GALAXY_CITY_RECORD")=="1" else 1) if built else 0
		slot.work=region.work_cost() if built else 0.0
		slot.construction=0.0;slot.upgrade_progress=0.0
	if OS.get_environment("GALAXY_CITY_RECORD")!="1":
		region.slots[15].status="constructing";region.slots[15].level=1
		region.slots[15].work=region.work_cost()*0.425
		region.slots[15].construction=float(region.row.construction_time)
	region.state.status="exploring"
	region.state.explore_work=region.work_cost()*15.425
	region.refresh_counts();region.building_revision+=1;g.galaxy.effect_generation+=1
	panel.detail_slot=-1 if OS.get_environment("GALAXY_CITY_RECORD")=="1" else 15
	scene.select_system(8);panel.refresh()
	panel.map.zoom=1.0;panel.map.pan=Vector2.ZERO;panel.map.layout()
	g.paused=false;g.speed=1.0
	scene.set_process(true)
	await create_timer(6.0).timeout
	panel.refresh()
	var map=panel.map
	var bridge=map.city.connections[0]
	var joint:Vector3=bridge.a.global_position
	map.camera.size=20.0
	map.camera.position=joint+Vector3(130,130,130)
	map.camera.look_at(joint,Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	map.view.get_texture().get_image().save_png("res://../service-bridge-joint.png")
	# Fixed close inspection camera follows neither ships nor time; production craft remain unchanged.
	var boat:Dictionary=map.transports[0]
	var midpoint:Vector3=boat.curve.sample_baked(boat.curve.get_baked_length()*0.5)
	map.camera.size=48.0
	map.camera.position=midpoint+Vector3(130,130,130)
	map.camera.look_at(midpoint,Vector3.UP)
	var directory:=ProjectSettings.globalize_path("res://../flight-frames")
	DirAccess.make_dir_recursive_absolute(directory)
	var frames:Array=[]
	var start:=Time.get_ticks_usec()
	while true:
		await RenderingServer.frame_post_draw
		var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
		var filename:="frame_%05d.png"%frames.size()
		map.view.get_texture().get_image().save_png(directory+"/"+filename)
		var fleet:Array=[]
		for item in map.transports:
			var p:Vector3=item.node.position
			var screen:Vector2=map.camera.unproject_position(p)
			fleet.append({"visible":item.node.visible,"position":[p.x,p.y,p.z],"screen":[screen.x,screen.y],"source":item.get("source",-99),"destination":item.get("destination",-99),"phase":item.phase})
		frames.append({"file":filename,"time_s":elapsed,"visual_clock":map.visual_clock,"running":map.running,"paused":g.paused,"crew_count":map.crew_count,"spawned":map.transports.size(),"fleet":fleet})
		if elapsed>=seconds:break
	var output:=FileAccess.open("res://../flight-positions.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"speed":g.speed,"camera_size":map.camera.size,"source":"unscaled native galaxy viewport; inspection camera only; unchanged production ship size and routes", "frames":frames},"  "));output.close()
	print("FLIGHT REVIEW frames=",frames.size()," seconds=",frames[-1].time_s," spawn=",map.transports.size()," crew=",map.crew_count," running=",map.running," paused=",g.paused)
