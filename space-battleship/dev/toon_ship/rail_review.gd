extends SceneTree
## Two deterministic real-combat runs. Only rail renderer differs.
const DT:=1.0/30.0
const FRAMES:=300
var output:=""
var errors:Array[String]=[]
var baseline:Array[String]=[]
var check_only:=false
var after_only:=false
var capture_mode:=""
var first_difference:Dictionary={}
var single:=false
var scene
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
	if not ok and not errors.has(text):errors.append(text);printerr("FAIL: ",text)
func fingerprint(game)->String:
	var state:Dictionary={}
	for property in game.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE==0:continue
		var value=game.get(property.name)
		if value is Object:continue
		# Resource receipt wall-clock timestamps necessarily differ in sequential
		# runs. Preserve every receipt amount/id/origin; normalize only that clock.
		if str(property.name)=="resource_samples":
			value=value.duplicate(true)
			for sample in value:sample.erase("time")
		state[str(property.name)]=value
	state["combat_rng_state"]=game.rng.state
	return JSON.stringify(state)
func capture(path:String)->void:
	if after_only and capture_mode=="before":return
	await process_frame
	if check_only:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--prototype-rail-single":single=true
		if arg=="--rail-after-only":after_only=true
		if arg=="--rail-check-only":check_only=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():quit(1);return
	root.size=Vector2i(1335,859)
	var report:Dictionary={"frames_each":FRAMES,"step_seconds":DT,"synthetic":("Heavy, one rail cannon; no player save" if single else "Heavy, eight rail cannons; no player save"),"gameplay":"Current prototype rail speed is 12x original; only renderer differs between these runs","runs":[],"normalization":"resource_samples.time wall-clock receipt timestamp only"}
	var shared_profile:Dictionary={}
	for mode in ["before","after"]:
		capture_mode=mode
		seed(5927)
		scene=load("res://dev/toon_ship_test.tscn").instantiate();root.add_child(scene);scene.set_process(false)
		if shared_profile.is_empty():shared_profile=scene.game.profile.duplicate(true)
		# Fresh ordinary BattleGame per pass; shared profile and seed are explicit
		# test inputs, never a player's save or altered balance configuration.
		scene.game=scene.create_battle_game(false)
		scene.game.profile=shared_profile.duplicate(true)
		scene.game.rng.seed=90317
		scene.game.event.connect(scene.on_event)
		scene.game.start(1,false);scene.game.distance=99.8
		scene.fx_time=0.0;scene.demo_time=0.0;scene.clock=0.0
		scene.game.paused=false;scene.build_ui()
		scene.rail_vfx_enabled=(mode=="after")
		var label:=Label.new();label.text=mode.to_upper()+" | RAIL CANNON | SYNTHETIC LOADOUT | REAL COMBAT, 30 Hz CAPTURE"
		label.position=Vector2(10,10);label.add_theme_font_size_override("font_size",18);scene.add_child(label)
		var directory:=output.path_join(mode);DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
		var peak:=0
		var peak_frame:=0
		var first_hit_frame:=-1
		var observed_slots:Dictionary={}
		var readonly_ok:=true
		for frame_index in FRAMES:
			scene._process(DT)
			var before_render:=fingerprint(scene.game)
			if mode=="before":baseline.append(before_render)
			else:
				if before_render!=baseline[frame_index] and first_difference.is_empty():
					var a:Dictionary=JSON.parse_string(baseline[frame_index]);var b:Dictionary=JSON.parse_string(before_render)
					for key in a:
						if a[key]!=b.get(key):first_difference[key]={"before":a[key],"after":b.get(key)}
				check(before_render==baseline[frame_index],"Gameplay differs from baseline at frame %d"%frame_index)
			# Very fast rounds can launch and hit between rendered frames. Use the
			# real launch pose timestamp for coverage, not surviving projectile count.
			for slot in scene.turret_visuals:
				if str(scene.game.slot_entry("weapons",int(slot)).get("key",""))=="cannon" and float(scene.turret_visuals[slot].get("fired_at",-1.0))>0.0:observed_slots[int(slot)]=true
			var shots:=0
			for shot in scene.game.projectiles:
				if not bool(shot.hostile) and str(shot.key)=="cannon":
					shots+=1;observed_slots[int(scene.projectile_visual(shot).get("mount",-1))]=true
			if shots>peak:peak=shots;peak_frame=frame_index
			if scene.rail_hit_count>0 and first_hit_frame<0:first_hit_frame=frame_index
			await capture(directory.path_join("frames/frame-%04d.png"%frame_index))
			readonly_ok=readonly_ok and before_render==fingerprint(scene.game)
		check(readonly_ok,"Drawing must not mutate gameplay")
		check(observed_slots.has(0) and (single or observed_slots.has(5)),"Capture must contain both hull and moving-drone rail fire")
		if mode=="after":
			check(scene.rail_fire_count>0 and scene.rail_hit_count>0,"Pulse launch and real impact events must both occur")
			check(scene.rail_origin_max_error<0.00001,"Launch origin must match actual projected moving-carrier muzzle")
		# Pause retains event lifetime and position without new simulation updates.
		scene.game.paused=true
		var frozen:=fingerprint(scene.game)
		var old_time:float=scene.fx_time
		scene._process(DT)
		check(frozen==fingerprint(scene.game) and is_equal_approx(old_time,scene.fx_time),"Pause must freeze gameplay and effect clock")
		report.runs.append({"mode":mode,"peak_projectiles":peak,"peak_frame":peak_frame,"first_hit_frame":first_hit_frame,"fire_slots":observed_slots.keys(),"rail_fire_events":scene.rail_fire_count,"rail_hit_events":scene.rail_hit_count,"maximum_launch_muzzle_error":scene.rail_origin_max_error,"draw_preserves_state":readonly_ok,"save_enabled":scene.game.save_enabled})
		scene.free();await process_frame
	report.errors=errors;report.passed=errors.is_empty();report.first_difference=first_difference
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RAIL_REVIEW ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
