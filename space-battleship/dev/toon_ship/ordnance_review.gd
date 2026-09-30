extends SceneTree
## Two deterministic real-combat runs. Only rail renderer differs.
const DT:=1.0/30.0
const FRAMES:=450
var output:=""
var errors:Array[String]=[]
var baseline:Array[String]=[]
var check_only:=false
var after_only:=false
var capture_mode:=""
var first_difference:Dictionary={}
var kind:="missile"
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
		if arg=="--prototype-beam-fixture":kind="beam"
		if arg=="--ordnance-after-only":after_only=true
		if arg=="--ordnance-check-only":check_only=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():quit(1);return
	root.size=Vector2i(1335,859)
	var report:Dictionary={"frames_each":FRAMES,"step_seconds":DT,"synthetic":"Heavy, eight "+kind+" weapons; no player save","gameplay":"ordinary deterministic combat progression; no altered CD/speed/hit/damage","runs":[],"normalization":"resource_samples.time wall-clock receipt timestamp only"}
	var shared_profile:Dictionary={}
	for mode in ["before","after"]:
		capture_mode=mode
		seed(5927)
		scene=load("res://dev/toon_ship_test.tscn").instantiate();root.add_child(scene);scene.set_process(false)
		if shared_profile.is_empty():shared_profile=scene.game.profile.duplicate(true)
		# Fresh ordinary BattleGame per pass; shared profile and seed are explicit
		# test inputs, never a player's save or altered balance configuration.
		scene.game=BattleGame.new(scene.db,false)
		scene.game.profile=shared_profile.duplicate(true)
		scene.game.rng.seed=90317
		scene.game.event.connect(scene.on_event)
		scene.game.start(1,false);scene.game.distance=99.8
		scene.fx_time=0.0;scene.demo_time=0.0;scene.clock=0.0
		scene.game.paused=false;scene.build_ui()
		scene.missile_vfx_enabled=(mode=="after")
		scene.continuous_beam_enabled=(mode=="after")
		var label:=Label.new();label.text=mode.to_upper()+" | MISSILE / CONTINUOUS BEAM | SYNTHETIC LOADOUT | REAL COMBAT, 30 Hz CAPTURE"
		label.position=Vector2(10,10);label.add_theme_font_size_override("font_size",18);scene.add_child(label)
		var directory:=output.path_join(mode);DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
		var peak:=0
		var peak_frame:=0
		var first_hit_frame:=-1
		var observed_slots:Dictionary={}
		var readonly_ok:=true
		var beam_charge_frames:=0
		var beam_active_frames:=0
		var first_loss_frame:=-1
		var first_active_frame:=-1
		var baseline_losses:=0
		var baseline_loss_jump:=0.0
		var prior:Dictionary={}
		var tangent_error:=0.0
		var previous_active:Dictionary={}
		var first_beam_end:=-1
		var maximum_end_particles:=0
		for frame_index in FRAMES:
			scene._process(DT)
			for visual in scene.projectile_visuals:
				if bool(visual.shot.hostile) or str(visual.shot.key)!="missile":continue
				var serial:=int(visual.shot.get("serial",0))
				var point:Vector2=scene.missile_visual_position(visual.shot,float(visual.spread),visual.origin,visual)
				var logical:=Vector2(visual.shot.x,visual.shot.y)
				if prior.has(serial) and bool(prior[serial].target) and visual.shot.target.is_empty():
					baseline_losses+=1
					if first_loss_frame<0:first_loss_frame=frame_index
					var expected:Vector2=prior[serial].point+logical-Vector2(prior[serial].logical)
					baseline_loss_jump=maxf(baseline_loss_jump,scene.battle_point(point).distance_to(scene.battle_point(expected)))
				prior[serial]={"point":point,"logical":logical,"target":not visual.shot.target.is_empty()}
				if mode=="after" and int(visual.samples)>1:
					var head:=int(visual.head)
					var movement:Vector2=scene.battle_point(visual.trail[head])-scene.battle_point(visual.trail[(head+13)%14])
					if movement.length_squared()>0.001:tangent_error=maxf(tangent_error,absf(angle_difference(float(visual.angle),movement.angle())))
			var active:Dictionary={}
			for shot in scene.game.projectiles:
				if bool(shot.get("beam",false)) and not bool(shot.hostile) and scene.game.long_laser_valid(shot) and int(shot.ticks)>0:active[int(shot.serial)]=true
			for serial in previous_active:
				if not active.has(serial) and first_beam_end<0:first_beam_end=frame_index
			previous_active=active
			maximum_end_particles=maxi(maximum_end_particles,scene.particles.filter(func(p):return p.has("beam_end")).size())
			var before_render:=fingerprint(scene.game)
			if mode=="before":baseline.append(before_render)
			else:
				if before_render!=baseline[frame_index] and first_difference.is_empty():
					var a:Dictionary=JSON.parse_string(baseline[frame_index]);var b:Dictionary=JSON.parse_string(before_render)
					for key in a:
						if a[key]!=b.get(key):first_difference[key]={"before":a[key],"after":b.get(key)}
				check(before_render==baseline[frame_index],"Gameplay differs from baseline at frame %d"%frame_index)
			var shots:=0
			for shot in scene.game.projectiles:
				if not bool(shot.hostile) and str(shot.key)==("missile" if kind=="missile" else "longLaser"):
					shots+=1
					observed_slots[int(shot.get("mount",-1)) if kind=="beam" else int(scene.projectile_visual(shot).get("mount",-1))]=true
					if kind=="beam":
						if float(shot.charge)>0 and float(shot.elapsed)<float(shot.charge):beam_charge_frames+=1
						elif int(shot.ticks)>0:
							beam_active_frames+=1
							if first_active_frame<0:first_active_frame=frame_index
			if shots>peak:peak=shots;peak_frame=frame_index
			if scene.missile_hit_count>0 and first_hit_frame<0:first_hit_frame=frame_index
			await capture(directory.path_join("frames/frame-%04d.png"%frame_index))
			readonly_ok=readonly_ok and before_render==fingerprint(scene.game)
		check(readonly_ok,"Drawing must not mutate gameplay")
		check(observed_slots.has(0) and observed_slots.has(5),"Capture must contain both hull and moving-drone rail fire")
		if mode=="after" and kind=="missile":
			check(scene.missile_fire_count>0 and scene.missile_hit_count>0,"Pulse launch and real impact events must both occur")
			check(scene.missile_origin_max_error<0.00001,"Launch origin must match actual projected moving-carrier muzzle")
		if mode=="after" and kind=="missile":
			check(tangent_error<0.00001,"Missile body follows actual rendered motion tangent")
			check(baseline_losses>0,"Real combat must include missile target death while a missile remains in flight")
			check(baseline_loss_jump<0.001,"Target-loss presentation must not jump or fake retarget")
		if kind=="beam":
			check(beam_active_frames>0 and first_beam_end>=0,"Existing beams must start and end")
			if mode=="after":check(maximum_end_particles==0,"Own sustained beams must disappear without legacy end fragments")
		# Pause retains event lifetime and position without new simulation updates.
		scene.game.paused=true
		var frozen:=fingerprint(scene.game)
		var old_time:float=scene.fx_time
		scene._process(DT)
		check(frozen==fingerprint(scene.game) and is_equal_approx(old_time,scene.fx_time),"Pause must freeze gameplay and effect clock")
		report.runs.append({"mode":mode,"kind":kind,"first_target_loss_frame":first_loss_frame,"first_beam_active_frame":first_active_frame,"first_beam_end_frame":first_beam_end,"maximum_beam_end_particles":maximum_end_particles,"target_loss_events":baseline_losses,"target_loss_max_jump":baseline_loss_jump,"maximum_tangent_error":tangent_error,"beam_charge_samples":beam_charge_frames,"beam_active_samples":beam_active_frames,"peak_projectiles":peak,"peak_frame":peak_frame,"first_hit_frame":first_hit_frame,"fire_slots":observed_slots.keys(),"missile_fire_events":scene.missile_fire_count,"missile_hit_events":scene.missile_hit_count,"maximum_launch_muzzle_error":scene.missile_origin_max_error,"draw_preserves_state":readonly_ok,"save_enabled":scene.game.save_enabled})
		scene.free();await process_frame
	report.errors=errors;report.passed=errors.is_empty();report.first_difference=first_difference
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ORDNANCE_REVIEW ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
