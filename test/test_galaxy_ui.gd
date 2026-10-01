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
	check(scene.battle_layer.modulate.r<1,"Galaxy softens battle visuals")
	var button: Button=panel.crew_rows.navigator
	click(viewport,button.get_global_rect().get_center())
	await process_frame
	check(g.galaxy.crew_count(g,"galaxy_1")==1,"Real click dispatches crew")
	var region=g.galaxy.regions.galaxy_1
	g.galaxy.advance(g,1)
	panel.refresh()
	var map=panel.map
	check(map.view.own_world_3d and map.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Independent orthographic world")
	var old_zoom: float=map.zoom
	var position: Vector2=map.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.position=position;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	viewport.push_input(wheel,true)
	await process_frame
	check(map.zoom>old_zoom,"Real wheel zoom")
	var press := InputEventMouseButton.new()
	var anchor_before: Vector2=map.get_global_transform()*(map.camera.unproject_position(Vector3.ZERO)*map.size/Vector2(map.view.size))
	press.position=position;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	viewport.push_input(press,true)
	var motion := InputEventMouseMotion.new()
	motion.position=position+Vector2(25,10);motion.relative=Vector2(25,10);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion,true)
	press.pressed=false;press.position=motion.position
	viewport.push_input(press,true)
	await process_frame
	check(map.pan.length()>0,"Real pan")
	var anchor_after: Vector2=map.get_global_transform()*(map.camera.unproject_position(Vector3.ZERO)*map.size/Vector2(map.view.size))
	check((anchor_after-anchor_before).distance_to(motion.relative)<1.0,"Isometric drag follows pointer on screen")
	var unrelated=scene.crew_panel.get_instance_id()
	scene.select_system(0)
	await process_frame
	check(scene.battle_layer.modulate==Color.WHITE,"Leaving Galaxy restores battle appearance")
	var ticks: int=map.visual_ticks
	var updates: int=map.draw_updates
	var work: float=region.state.build_elapsed
	g.galaxy.advance(g,9)
	check(region.state.build_elapsed==work,"Hidden online batch waits")
	g.galaxy.advance(g,1)
	check(region.state.build_elapsed!=work or region.occupied_count>0,"Hidden batch advances construction dispatch")
	await process_frame
	await process_frame
	check(map.visual_ticks==ticks and map.draw_updates==updates and not map.is_processing(),"Hidden zero visual work")
	check(map.view.render_target_update_mode==SubViewport.UPDATE_DISABLED and map.world.process_mode==Node.PROCESS_MODE_DISABLED,"Hidden viewport/world disabled")
	check(scene.crew_panel.get_instance_id()==unrelated,"Other UI instance preserved")
	scene.select_system(8)
	await process_frame
	panel.refresh()
	check(map.is_processing(),"Reveal resumes presentation")
	g.paused=true;panel.refresh_sample(0)
	ticks=map.visual_ticks
	await process_frame
	check(map.visual_ticks==ticks,"Pause freezes visuals")
	g.paused=false;panel.refresh_sample(0)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/galaxy_1_complete.json"))
	check(fixture is Dictionary,"Logic-owned full-build fixture is available")
	if not fixture is Dictionary:quit(1);return
	g.galaxy.load_state(g,{"galaxy_1":fixture.save})
	region=g.galaxy.regions.galaxy_1
	var saved_before: String=JSON.stringify(region.blueprint)
	map.zoom=1.0;map.pan=Vector2.ZERO
	panel.refresh()
	await create_timer(1.2).timeout
	panel.refresh()
	check(region.occupied_count==int(region.row.building_slot_count),"Fixture keeps live configured building count")
	check(region.max_level_count==region.slots.size(),"Full-build fixture is genuinely complete")
	check(map.transit.curves.size()==region.blueprint.edges.size(),"Connections use every authoritative edge")
	check(map.transports.size()<=12 and map.pulses.size()<=4,"Bounded reusable visual pools")
	check(map.explorers.is_empty(),"Construction vessels stop when no construction remains")
	for plan in region.blueprint.nodes:
		var visual: Node3D=map.slot_nodes[int(plan.id)]
		check(visual.position.is_equal_approx(Vector3(float(plan.world_pos[0]),0,float(plan.world_pos[1]))),"Exact blueprint position")
		check(is_equal_approx(visual.rotation.y,float(plan.rotation_y)),"Exact blueprint orientation")
		var screen_position: Vector2= map.camera.unproject_position(visual.global_position)
		check(Rect2(Vector2.ZERO,Vector2(map.view.size)).grow(-10).has_point(screen_position),"Complete blueprint fits default camera")
		var route: Curve3D=map.transit.curves[int(plan.id)]
		var edge: Dictionary=region.blueprint.edges[int(plan.id)]
		check(Vector2(route.get_point_position(0).x,route.get_point_position(0).z).is_equal_approx(Vector2(edge.path[0][0],edge.path[0][1])),"Traffic starts on authoritative path")
		check(Vector2(route.get_point_position(route.point_count-1).x,route.get_point_position(route.point_count-1).z).is_equal_approx(Vector2(edge.path[-1][0],edge.path[-1][1])),"Traffic ends on authoritative path")
	check(JSON.stringify(region.blueprint)==saved_before,"Renderer does not mutate blueprint")
	await capture(viewport,"galaxy-complete-ui.png")
	# The representative cluster uses the exact first four nodes and their planned types.
	map.zoom=2.4;map.pan=Vector2.ZERO;map.layout()
	await capture(viewport,"galaxy-hub-cluster-ui.png")
	map.zoom=1.0;map.layout()
	var id := 2
	var node: Node3D=map.slot_nodes[id]
	var local: Vector2=map.camera.unproject_position(node.global_position)
	var screen: Vector2=map.get_global_transform()*(local*map.size/Vector2(map.view.size))
	click(viewport,screen)
	await process_frame
	check(map.selected_slot==id and panel.detail_slot==id,"Real click inspects building")
	var cached_node: int=node.get_node("Building").get_instance_id()
	var cached_updates: int=map.draw_updates
	panel.refresh()
	check(map.slot_nodes[id].get_node("Building").get_instance_id()==cached_node and map.draw_updates==cached_updates,"Unchanged refresh reuses model and static mesh")
	var unrelated_model: int=map.slot_nodes[3].get_node("Building").get_instance_id()
	var route_mesh: Mesh=map.transit.network.mesh
	region.slots[2].level=4;region.building_revision+=1
	panel.refresh()
	check(map.draw_updates==cached_updates+1 and map.slot_nodes[3].get_node("Building").get_instance_id()==unrelated_model,"Single level change updates only its building")
	check(map.transit.network.mesh==route_mesh,"Level-only change preserves static transit mesh")
	region.slots[2].level=5;region.building_revision+=1;panel.refresh()
	# A legal outward construction state: first layer complete, one nearest second-layer node busy.
	for slot in region.slots:
		slot.level=1 if int(slot.id)<4 else 0
		slot.status="active" if int(slot.id)<4 else "empty"
		slot.work=region.work_cost() if int(slot.id)<4 else 0.0
		slot.construction=0.0
		slot.upgrade_progress=0.0
	region.state.status="exploring"
	region.slots[4].status="constructing";region.slots[4].level=1
	region.slots[4].work=region.work_cost()*0.42
	region.slots[4].construction=float(region.row.construction_time)
	region.refresh_counts();region.building_revision+=1
	g.galaxy.effect_generation+=1
	map.zoom=1.45;map.pan=Vector2.ZERO;map.layout()
	panel.detail_slot=4;map.selected_slot=4;map.hover_slot=-1;map.update_highlight();panel.refresh()
	await create_timer(1.2).timeout
	panel.refresh()
	check(map.construction[4].ring.visible,"Construction gantry is readable")
	check(map.slot_nodes[4].get_node("Building").visible,"Construction retains partial recognizable building")
	check(is_equal_approx(map.construction[4].height,float(map.asset_bounds[map.visual_path(region.slots[4])][1])*1.2*region.node_progress(region.slots[4])),"Construction uses full node progress, not finishing countdown")
	check(not map.slot_nodes[5].has_node("Building") and map.slot_nodes[5].get_node("SurveyFootprint").visible,"Unbuilt nodes show planned footprint")
	await capture(viewport,"galaxy-construction-ui.png")
	map.zoom=2.1;map.pan=Vector2(0,-12);map.layout()
	await capture(viewport,"galaxy-construction-detail-ui.png")
	var empty_position: Vector2=map.camera.unproject_position(map.slot_nodes[5].global_position)
	check(map.pick(empty_position*map.size/Vector2(map.view.size))==5,"Planned nodes remain clickable")
	click(viewport,button.get_global_rect().get_center())
	await process_frame
	panel.refresh()
	check(map.crew_count==0 and panel.state_label.text==UIText.t("galaxy.waiting_crew"),"No crew shows waiting state")
	check(map.explorers.is_empty() and panel.cards.explorers.text=="0","Construction vessels stop immediately when crew is recalled")
	var held_height: float=map.construction[4].height
	g.galaxy.advance(g,1);panel.refresh()
	check(is_equal_approx(map.construction[4].height,held_height),"Unassigned construction reveal remains stationary")
	await capture(viewport,"galaxy-unassigned-ui.png")
	click(viewport,button.get_global_rect().get_center())
	await process_frame
	panel.refresh()
	# Upgrade state is tested only after all functional buildings exist, matching logic.
	for slot in region.slots:
		slot.level=4;slot.status="active";slot.work=region.work_cost();slot.construction=0.0
	region.state.status="developing"
	region.slots[2].status="upgrading";region.slots[2].upgrade_progress=region.upgrade_cost(region.slots[2])*0.35
	region.refresh_counts();region.building_revision+=1;g.galaxy.effect_generation+=1
	map.zoom=1.55;map.pan=Vector2.ZERO;map.layout();panel.detail_slot=2;panel.refresh()
	await capture(viewport,"galaxy-upgrade-ui.png")
	check(map.construction[2].ring.visible and map.slot_nodes[2].get_node("Building").visible,"Upgrade retains existing structure and progress feedback")
	var dormant_updates: int=map.draw_updates
	var dormant_ticks: int=map.visual_ticks
	scene.select_system(0)
	await process_frame
	await process_frame
	check(map.draw_updates==dormant_updates and map.visual_ticks==dormant_ticks,"Final hidden page stops all changed visual work")
	print("GALAXY 3D UI checks=",checks," failures=",failures," visual_nodes=",map.world.get_child_count()," buildings=",region.occupied_count," actual_fps=",Engine.get_frames_per_second())
	if OS.get_environment("GALAXY_CAPTURE_HOLD")=="1":
		g.galaxy.load_state(g,{"galaxy_1":fixture.save})
		panel.detail_slot=-1
		scene.select_system(8);panel.refresh()
		await create_timer(1.2).timeout
		panel.refresh()
		scene.refresh_fps_label(true)
		await create_timer(90).timeout
	scene.queue_free()
	await process_frame
	current_scene=null
	quit(1 if failures else 0)
func capture(viewport: Viewport,filename: String) -> void:
	if is_instance_valid(current_scene):current_scene.refresh_fps_label(true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://../"+filename)

func click(viewport: Viewport,position: Vector2) -> void:
	for pressed in [true,false]:
		var input := InputEventMouseButton.new()
		input.position=position;input.button_index=MOUSE_BUTTON_LEFT;input.pressed=pressed
		viewport.push_input(input,true)
