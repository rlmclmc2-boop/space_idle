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
	check(scene.equipment_tabs.is_tab_hidden(8),"Galaxy hidden before unlock")
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
	g.galaxy.load_state(g,{"galaxy_1":fixture.save})
	var region=g.galaxy.regions.galaxy_1
	region.slots[5].status="empty";region.slots[5].level=0;region.refresh_counts();region.building_revision+=1
	panel.refresh()
	var map=panel.map
	for offset in [Vector3.ZERO,Vector3(6.8,0,0),Vector3(7.7,0,0)]:
		var pixel:Vector2=map.camera.unproject_position(map.slot_nodes[5].global_position+offset)*map.size/Vector2(map.view.size)
		check(map.pick(pixel)==5,"Independent platform including rim remains selectable")
	var outside:Vector2=map.camera.unproject_position(map.slot_nodes[5].global_position+Vector3(8.3,0,0))*map.size/Vector2(map.view.size)
	check(map.pick(outside)!=5,"Platform picking stops outside its boundary")
	print("PLATFORM PICK checks=",checks," failures=",failures)
	if failures>0:quit(1);return
	await record_construction(viewport,scene,panel,fixture,10.0)
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
	# Let the actual native game bring the staggered six-boat city traffic online.
	await create_timer(6.0).timeout
	panel.refresh()
	panel.map.camera.size=48.0
	var target:=Vector3(0,7,0)
	panel.map.camera.position=target+Vector3(130,130,130)
	panel.map.camera.look_at(target,Vector3.UP)
	var directory := ProjectSettings.globalize_path("res://../closeup-frames")
	DirAccess.make_dir_recursive_absolute(directory)
	var frames: Array=[]
	var start := Time.get_ticks_usec()
	var image_size := Vector2i.ZERO
	while true:
		await RenderingServer.frame_post_draw
		var elapsed := (Time.get_ticks_usec()-start)/1000000.0
		var filename := "frame_%05d.jpg"%frames.size()
		var frame_image:Image=panel.map.view.get_texture().get_image()
		image_size=frame_image.get_size()
		frame_image.save_jpg(directory+"/"+filename,0.96)
		var fleet:Array=[]
		for boat in panel.map.transports:
			var p:Vector3=boat.node.position
			fleet.append({"position":[p.x,p.y,p.z],"visible":boat.node.visible,"source":boat.get("source",-99),"destination":boat.get("destination",-99)})
		frames.append({"file":filename,"time_s":elapsed,"fleet":fleet,"visual_clock":panel.map.visual_clock,"running":panel.map.running,"paused":g.paused,"crew":panel.map.crew_count,"construction_progress":region.node_progress(region.slots[15]),"built":region.slots.filter(func(slot):return slot.status in ["active","upgrading"]).size(),"traffic_visible":panel.map.transports.filter(func(item):return item.node.visible).size()})
		if elapsed>=seconds:break
	var metadata := {"fixture":"isolated first-galaxy plan, 30 completed nodes with mixed levels" if OS.get_environment("GALAXY_CITY_RECORD")=="1" else "isolated first-galaxy plan, 15 completed and one constructing","source":"actual native game root framebuffer, every rendered frame, real wall-clock timestamps","wall_seconds":frames[-1].time_s,"width":image_size.x,"height":image_size.y,"speed":g.speed,"frames":frames}
	var output := FileAccess.open(directory+"/recording.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(metadata,"  "));output.close()
	scene.set_process(false)
	print("GALAXY_REALTIME_RECORD frames=",frames.size()," seconds=",metadata.wall_seconds," size=",metadata.width,"x",metadata.height," speed=",g.speed)

