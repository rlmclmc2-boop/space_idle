extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2048,1280)
	viewport.gui_embed_subwindows=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene=preload("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	viewport.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	var g=scene.game
	g.save_enabled=false
	check(scene.equipment_tabs.is_tab_hidden(8),"Galaxy hidden before unlock")
	g.profile.cleared=range(1,61)
	for progress in g.profile.planets.values():progress.conquered=true
	g.rebuild_unlocks()
	g.galaxy.refresh_unlocks(g)
	scene.refresh_structure()
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
	var work: float=region.state.explore_work
	g.galaxy.advance(g,9)
	check(region.state.explore_work==work,"Hidden online batch waits")
	g.galaxy.advance(g,1)
	check(region.state.explore_work>work,"Hidden batch advances work")
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
	region.state.explore_work=float(region.row.explore_work_total)
	region.state.status="developing"
	region.sync_map()
	while region.occupied_count<region.slots.size():region.build_attempt()
	for slot in region.slots:
		slot.construction=0.0
		slot.status="active"
		slot.level=1+int(slot.id)%5
	region.slots[0].status="constructing";region.slots[0].construction=20.0
	region.slots[1].status="upgrading";region.slots[1].upgrade_progress=200.0
	region.refresh_counts();region.building_revision+=1
	g.galaxy.effect_generation+=1
	map.zoom=1.0;map.pan=Vector2.ZERO;map.layout()
	panel.refresh()
	await create_timer(1.2).timeout
	panel.refresh()
	check(map.transports.size()<=12 and map.pulses.size()<=4,"Bounded reusable visual pools")
	check(map.explorers.is_empty(),"Exploration ships stop after 100 percent")
	var id := 2
	var node: Node3D=map.slot_nodes[id]
	var local: Vector2=map.camera.unproject_position(node.global_position)
	var screen: Vector2=map.get_global_transform()*(local*map.size/Vector2(map.view.size))
	click(viewport,screen)
	await process_frame
	check(map.selected_slot==id and panel.detail_slot==id,"Real click inspects building")
	check(map.construction[0].ring.visible and map.construction[1].ring.visible,"Construction and upgrade visuals")
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://../galaxy-3d-ui.png")
	map.zoom=1.7;map.layout()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://../galaxy-3d-detail.png")
	print("GALAXY 3D UI failures=",failures," visual_nodes=",map.world.get_child_count()," buildings=",region.occupied_count)
	quit(1 if failures else 0)
func click(viewport: SubViewport,position: Vector2) -> void:
	for pressed in [true,false]:
		var input := InputEventMouseButton.new()
		input.position=position;input.button_index=MOUSE_BUTTON_LEFT;input.pressed=pressed
		viewport.push_input(input,true)
