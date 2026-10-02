extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var checks:=0
var failures:=0
var records: Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize()->void:call_deferred("run")
func render_image()->Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func body_delta(first:Image,last:Image,center:Vector2,radius:float)->Dictionary:
	var difference:=0.0;var changed:=0;var samples:=0
	for y in range(int(center.y-radius*0.5),int(center.y+radius*0.5)):
		for x in range(int(center.x-radius*0.5),int(center.x+radius*0.5)):
			if x<0 or y<0 or x>=first.get_width() or y>=first.get_height():continue
			var a:=first.get_pixel(x,y);var b:=last.get_pixel(x,y)
			var delta:float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))*255.0/3.0
			difference+=delta;samples+=1
			if delta>=2.0:changed+=1
	var mean:float=difference/maxi(1,samples);var fraction:float=float(changed)/maxi(1,samples)
	return {"mean":mean,"fraction":fraction,"samples":samples}
func run()->void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
	scene.music_on=false;scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene
	scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.paused=false;g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
	g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.rebuild_unlocks()
	for progress in g.profile.planets.values():progress.conquered=true
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(6)
	await process_frame;await process_frame
	var panel=scene.planet_panel
	print("PLANET FIXTURE visible=",panel.is_visible_in_tree()," tab=",scene.equipment_tabs.current_tab," unlocked=",g.planet_unlocked("1")," cards=",panel.cards.keys())
	var baseline:=OS.get_environment("PLANET_ROTATION_BASELINE")=="1"
	var recording:=OS.get_environment("PLANET_ROTATION_RECORD")=="1"
	var folder:=ProjectSettings.globalize_path("res://../planet-rotation")
	DirAccess.make_dir_recursive_absolute(folder)
	for id in g.db.data.planet:
		panel.select_planet(id);panel.refresh()
		var visual=panel.cards[id].visual;var globe=visual.globe
		globe.phases=Vector2.ZERO;globe.visual_clock=0.0
		globe.globe_material.set_shader_parameter("phase",Vector2.ZERO);globe.globe_material.set_shader_parameter("visual_clock",0.0)
		var first:Image=await render_image();first.save_png(folder+"/planet-"+id+"-start.png")
		var pixel_scale:Vector2=Vector2(first.get_size())/root.get_visible_rect().size
		var transform:Transform2D=Transform2D.IDENTITY.scaled(pixel_scale)*globe.get_global_transform_with_canvas()
		var center:Vector2=transform*(globe.size*0.5)
		var radius:float=globe.size.x*0.5/globe.extent*transform.x.length()
		var nodes:=get_node_count();var start:Vector2=globe.phases
		var frames:=120 if recording else 2
		var dt:=12.0/frames
		var frames_dir:String=folder+"/planet-"+id;DirAccess.make_dir_recursive_absolute(frames_dir)
		for frame in frames:
			panel.refresh_sample(dt)
			var shot:Image=await render_image()
			if recording:shot.save_jpg(frames_dir+"/frame-%03d.jpg"%frame,0.95)
		# Freeze all time-driven halo/jet/pulse effects: pixel comparison isolates surface rotation.
		globe.globe_material.set_shader_parameter("visual_clock",0.0)
		var last:Image=await render_image();last.save_png(folder+"/planet-"+id+"-end.png")
		var metrics:=body_delta(first,last,center,radius)
		var mean:float=metrics.mean;var fraction:float=metrics.fraction;var samples:int=metrics.samples
		globe.globe_material.set_shader_parameter("phase",Vector2.ONE)
		var full_turn:Image=await render_image()
		var seam:=body_delta(first,full_turn,center,radius)
		check(float(seam.mean)<0.15,id+" full revolution closes without a texture jump")
		globe.globe_material.set_shader_parameter("phase",globe.phases)
		check(samples>50,id+" visible native sphere ROI exists")
		if not baseline:check(mean>1.0 and fraction>0.1,id+" visible rotating surface contrast")
		check(globe.phases!=start and is_zero_approx(globe.rotation),id+" sphere maps turn while quad and orbit orientation stay fixed")
		check(get_node_count()==nodes,id+" rotation creates no nodes")
		var frozen:Vector2=globe.phases;var writes:int=globe.parameter_writes
		g.paused=true;panel.refresh_sample(1.0);g.paused=false
		check(globe.phases==frozen and globe.parameter_writes==writes,id+" paused surface makes no writes")
		scene.select_system(0);await process_frame;await process_frame
		visual.advance(1.0,false);globe.advance(1.0,false)
		check(globe.phases==frozen and globe.parameter_writes==writes,id+" hidden surface makes no writes")
		scene.select_system(6);await process_frame;await process_frame
		panel.select_planet(id);visual.advance(0.05,false)
		check(globe.phases.distance_to(frozen)<0.05,id+" reveal resumes without catch-up jump")
		records.append({"id":id,"mean_rgb_byte_delta":mean,"changed_fraction":fraction,"surface_speed":globe.surface_speed,"cloud_speed":globe.cloud_speed,"radius_px":radius,"center":[center.x,center.y],"simulation_seconds":12,"frames":frames})
		print("ROTATION BODY ",JSON.stringify(records.back()))
	FileAccess.open(folder+"/measurements.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("CELESTIAL ROTATION checks=",checks," failures=",failures)
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free();await process_frame;current_scene=null
	quit(1 if failures else 0)
