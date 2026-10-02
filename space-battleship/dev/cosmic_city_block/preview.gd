extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI);scene.music_on=false;scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
	var g=scene.game
	g.save_enabled=false;g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.visible=false
	g.profile.cleared=range(1,int(g.db.data.unlock["feature/galaxy"].level)+1)
	g.profile.highestLevel=int(g.db.data.unlock["feature/galaxy"].level)+1
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	for progress in g.profile.planets.values():progress.conquered=true
	g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/galaxy_1_complete.json"))
	g.galaxy.load_state(g,{"galaxy_1":fixture.save})
	var region=g.galaxy.regions.galaxy_1
	for slot in region.slots:
		slot.level=3 if int(slot.id)<3 else 0
		slot.status="active" if int(slot.id)<3 else "empty"
	region.refresh_counts();region.building_revision+=1
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(8)
	for i in 4:await process_frame
	var panel=scene.galaxy_panel
	panel.detail_slot=-1;panel.refresh()
	if panel.cards.has("traffic"):
		var value=panel.cards.traffic
		value.get_parent().get_child(value.get_index()-1).hide();value.hide()
	var map=panel.map
	map.set_process(false)
	for child in map.world.get_children():
		if child is Node3D and not child is Camera3D and not child is WorldEnvironment and not child is DirectionalLight3D:
			if child is MeshInstance3D and child.material_override==map.space_material:continue
			child.visible=false
	audit_assets(map)
	var sample=load("res://dev/cosmic_city_block/block_sample.gd").new()
	map.world.add_child(sample);sample.build(map)
	map.camera.size=46.0
	var target:=Vector3(0,-1.3,9)
	map.camera.position=target+Vector3(65,65,65);map.camera.look_at(target)
	map.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await create_timer(2.0).timeout
	scene.refresh_fps_label(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../city-block-overview-ui.png")
	map.view.get_texture().get_image().save_png("res://../city-block-overview.png")
	map.camera.size=20.0
	target=Vector3(0,-0.8,0)
	map.camera.position=target+Vector3(65,65,65);map.camera.look_at(target)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	map.view.get_texture().get_image().save_png("res://../city-block-straight-detail.png")
	map.camera.size=22.0
	target=Vector3(-7,-1,15)
	map.camera.position=target+Vector3(65,65,65);map.camera.look_at(target)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	map.view.get_texture().get_image().save_png("res://../city-block-elbow-detail.png")
	print("BLOCK SAMPLE platforms=3 families=3 connections=",sample.connections.size()," port_height=",sample.PORT_Y)
	var largest_gap:=0.0
	for link in sample.connections:
		var near_end:Vector3=link.mesh.global_transform*Vector3(0,0,-float(link.span)*0.5)
		var far_end:Vector3=link.mesh.global_transform*Vector3(0,0,float(link.span)*0.5)
		largest_gap=maxf(largest_gap,maxf(near_end.distance_to(link.a.global_position),far_end.distance_to(link.b.global_position)))
		print("SOCKET ",link.a.get_parent().name," -> ",link.b.get_parent().name," span=",link.span," height_delta=",absf(link.a.global_position.y-link.b.global_position.y))
	print("INTERFACE_CHECK maximum_endpoint_gap=",largest_gap)
	quit(1 if largest_gap>0.0001 else 0)

func audit_assets(map) -> void:
	var rows:Array=[]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/galaxy/v3/manifest.json"))
	for record in manifest.assets:
		if record.key=="transport_shuttle":continue
		var model:Node3D=map.asset(record.path)
		map.world.add_child(model)
		var body:MeshInstance3D=model.find_child("Structure",true,false)
		var bounds:=body.mesh.get_aabb()
		var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
		for index in 8:
			var point:Vector3=body.global_transform*bounds.get_endpoint(index)
			low=low.min(point);high=high.max(point)
		var dock:Node3D=model.find_child("DockSocket",true,false)
		var scaling:=1.2 if str(record.key)=="galaxy_core" else 1.4
		rows.append({"key":record.key,"level":record.level,"bottom_y":low.y,"planar_center":[(low.x+high.x)*0.5,(low.z+high.z)*0.5],"scaled_bounds":[(high.x-low.x)*scaling,(high.y-low.y)*scaling,(high.z-low.z)*scaling],"aircraft_dock":[dock.global_position.x,dock.global_position.y,dock.global_position.z],"pipe_socket_exists":model.find_child("PipeSocket",true,false)!=null})
		model.free()
	var file:=FileAccess.open("res://../city-block-asset-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "));file.close()
	print("ASSET AUDIT buildings_and_core=",rows.size())
