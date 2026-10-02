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
		slot.level=1+int(slot.id)%5
		slot.status="active"
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
	var sample=load("res://dev/cosmic_city_individual/direction.gd").new()
	map.world.add_child(sample);sample.build(map)
	map.camera.size=134.0
	var target:=Vector3(-1,0,-1)
	map.camera.position=target+Vector3(130,130,130);map.camera.look_at(target)
	map.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await create_timer(2.0).timeout
	scene.refresh_fps_label(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../individual-city-full-ui.png")
	map.view.get_texture().get_image().save_png("res://../individual-city-viewport.png")
	quit()
