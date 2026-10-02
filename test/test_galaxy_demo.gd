extends SceneTree
## Creates a synthetic canonical save in the isolated test user directory, then
## exercises the ordinary loader twice and renders the actual main scene.
class DemoUI extends "res://scripts/battlefield.gd":
	func show_qa_tools() -> void:pass
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var area := ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\","/")
	check(OS.get_user_data_dir().replace("\\","/").begins_with(area),"Demo save uses only an isolated user directory")
	if failures:quit(1);return
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.rng.seed=20261002
	var gate := int(db.data.unlock["feature/galaxy"].level)
	for row in db.data.planet.values():gate=maxi(gate,int(db.data.unlock[row.unlockId].level))
	g.profile.cleared=range(1,gate+1)
	g.rebuild_unlocks()
	for planet in g.profile.planets.values():
		planet.conquered=true
		planet.auto_explore=false
	g.profile.onboarding.completed=true
	g.profile.onboarding.dismissed=true
	g.profile.resources["1"]=100000.0
	g.profile.resources["2"]=10000.0
	for category in ["weapons","defence"]:
		for entry in g.profile.loadout[category]:
			if not str(entry.key).is_empty():entry.level=10
	g.galaxy.refresh_unlocks(g)
	var region=g.galaxy.regions.galaxy_1
	for slot in region.slots:
		slot.status="active"
		slot.level=1+int(slot.id)%5
		slot.work=region.work_cost()
		slot.construction=0.0
		slot.upgrade_progress=0.0
	region.state.status="developing"
	region.refresh_counts();region.building_revision+=1
	g.galaxy.effect_generation+=1
	# No crew is assigned: the demonstration layout remains stable until the
	# player deliberately dispatches crew. This is ordinary game state.
	g.start(1,false)
	g.toggle_loop()
	g.save_enabled=true;g.save_progress()
	check(g.last_save_error==OK,"Canonical save writer succeeds")
	var destination := ProjectSettings.globalize_path("res://../space-idle-galaxy-demo-v4.json")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(BattleGame.SAVE_PATH),destination)==OK,"Canonical save is copied to the demo deliverable")
	var loaded := BattleGame.new(db,true)
	verify_demo(loaded,"first load")
	var signature: String=JSON.stringify(loaded.galaxy.save_data())
	loaded.save_progress()
	check(loaded.last_save_error==OK,"Loaded demo can be saved normally")
	var reloaded := BattleGame.new(db,true)
	verify_demo(reloaded,"save/reload")
	check(JSON.stringify(reloaded.galaxy.save_data())==signature,"Building layout and levels survive a normal save/reload")
	# Restore the delivered bytes so the normal scene loads the actual artifact.
	check(DirAccess.copy_absolute(destination,ProjectSettings.globalize_path(BattleGame.SAVE_PATH))==OK,"Normal scene receives the exact delivered JSON")
	if DisplayServer.get_name()!="headless":
		root.gui_embed_subwindows=true
		var scene=load("res://main.tscn").instantiate()
		scene.set_script(DemoUI)
		scene.music_on=false
		root.add_child(scene);current_scene=scene
		scene.set_process(false)
		scene.game.save_enabled=false
		scene.game.paused=true
		await process_frame;await process_frame
		if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.confirmed.emit()
		await process_frame
		verify_demo(scene.game,"normal main scene")
		check(not scene.equipment_tabs.is_tab_hidden(8),"Normal scene exposes the galaxy navigation")
		scene.select_system(8)
		await process_frame;await process_frame
		var map=scene.galaxy_panel.map
		scene.galaxy_panel.refresh_sample(0)
		scene.battle_hud_layer.queue_redraw()
		map.zoom=1.0;map.pan=Vector2.ZERO;map.layout()
		await capture("galaxy-demo-overview.png")
		check(map.slot_nodes.size()==region.slots.size(),"Normal scene renders all demo buildings")
		map.zoom=2.4;map.pan=-map.frame_origin;map.layout()
		await capture("galaxy-demo-hub.png")
		map.zoom=1.0;map.pan=Vector2.ZERO;map.layout()
		var point: Vector2=map.camera.unproject_position(map.slot_nodes[2].global_position)*map.size/Vector2(map.view.size)
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.position=map.get_global_transform()*point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed
			root.push_input(click,true)
		await capture("galaxy-demo-selected.png")
		check(map.selected_slot==2 and scene.galaxy_panel.detail_slot==2,"Loaded demo building accepts an actual click")
		scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
		scene.queue_free();await process_frame;current_scene=null
	print("GALAXY DEMO checks=",checks," failures=",failures," save_version=",BattleGame.SAVE_VERSION," file=",destination)
	quit(1 if failures else 0)
func verify_demo(g, phase: String) -> void:
	check(g.content_unlocked("feature","galaxy"),phase+": real galaxy prerequisite remains satisfied")
	check(g.galaxy.conquered(g)>=int(g.db.data.galaxy.galaxy_1.unlock_value),phase+": conquered planets survive loading")
	var region=g.galaxy.regions.galaxy_1
	check(region.state.status=="developing" and region.occupied_count==int(region.row.building_slot_count),phase+": all configured buildings load")
	var levels := {};var families := {}
	for slot in region.slots:levels[int(slot.level)]=true;families[str(slot.type)]=true
	check(levels.size()==5 and families.size()==6,phase+": five levels and six families are present")
	check(g.profile.loop and int(g.profile.guardStage)==1,phase+": safe starting guard route survives loading")
func capture(filename: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../"+filename)
