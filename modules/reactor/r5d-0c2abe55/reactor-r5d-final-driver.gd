extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func clear_guidance(session, game) -> void:
	var pending: Dictionary = session.pending_guidance(); var tries := 0
	while not pending.is_empty() and tries < 20:
		assert(session.dismiss_guidance(str(pending.kind),str(pending.id)).ok)
		pending = session.pending_guidance(); tries += 1
	game._sync_guidance()
func measure(label: String, scene: Control, session, game, duration: float) -> void:
	var samples: Array[float] = []
	var start: int = Time.get_ticks_usec(); var last: int = start
	var game_start: float = session.game_time
	var draws: int = scene._stage.diagnostics.draws
	var updates: int = scene._stage.diagnostics.active_frames
	while float(Time.get_ticks_usec()-start)/1000000.0 < duration:
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now-last)/1000.0); last=now
		if samples.size() % 35 == 0: clear_guidance(session, game)
	samples.sort()
	var total: float = float(last-start)/1000.0
	var sum: float = 0.0
	for v in samples: sum += v
	print("PROFILE ", label, " frames=", samples.size(), " wall_ms=", total, " fps=", 1000.0*float(samples.size())/total, " mean_ms=", sum/maxf(1.0,float(samples.size())), " p50_ms=", samples[int((samples.size()-1)*0.50)], " p95_ms=", samples[int((samples.size()-1)*0.95)], " stage_draw_delta=", scene._stage.diagnostics.draws-draws, " stage_active_delta=", scene._stage.diagnostics.active_frames-updates, " game_seconds=", session.game_time-game_start)
func make_backdrop(scene: Control) -> Dictionary:
	var group: Dictionary = {}
	for id in scene._stage.IDS:
		var module = scene._stage._modules[id]
		group[id] = {"position":module._effect.position,"size":module._effect.size}
	return group
func use_backdrop(scene: Control, group: Dictionary, enabled: bool) -> void:
	for id in scene._stage.IDS:
		var module = scene._stage._modules[id]
		module._effect.position = group[id].position if enabled else Vector2.ZERO
		module._effect.size = group[id].size if enabled else module.size
	scene._stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var game: Node2D=load("res://src/main.tscn").instantiate();root.add_child(game);await frames(4)
	var session=game.session;assert(session!=null and game.startup_error.is_empty() and session.current_chrono_speed()==1)
	var saved: Dictionary=session.campaign_system.save_state();saved.grants["feature:reactor"]=true;saved.grants["reactor_module:condensation"]=true
	assert(session.campaign_system.restore_state(saved).ok)
	session.reactor_system.refresh_availability(session.campaign_system.available)
	assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
	clear_guidance(session,game);game._select_left_module("reactor");await frames(5)
	var scene: Control=game.reactor_scene;assert(scene.visible)
	scene._equal.pressed.emit();await frames(5);clear_guidance(session,game)
	var model: Dictionary=session.reactor_system.presentation_model();assert(model.ok and model.modules.size()==4 and float(model.load)>0.0)
	print("PROFILE_CONTEXT pid=",OS.get_process_id()," renderer=",RenderingServer.get_rendering_device()!=null," size=",root.size," speed=",session.current_chrono_speed()," load=",model.load," modules=",model.modules.map(func(r):return [r.id,r.load]))
	await create_timer(2.3).timeout; clear_guidance(session,game)
	var group:Dictionary=make_backdrop(scene)
	use_backdrop(scene,group,false);await frames(5)
	await measure("full_rect_A1",scene,session,game,6.0)
	use_backdrop(scene,group,true);await frames(5)
	await measure("cropped_rect_B1",scene,session,game,6.0)
	use_backdrop(scene,group,false);await frames(5)
	await measure("full_rect_A2",scene,session,game,6.0)
	use_backdrop(scene,group,true);await frames(5)
	await measure("cropped_rect_B2",scene,session,game,6.0)
	# Pause only for same-phase visual comparison; never for timing windows.
	game.set_process(false)
	var fixed_time:float=session.game_time
	scene._clock=func():return {"game_time":fixed_time,"paused":true,"running":true}
	use_backdrop(scene,group,false);await frames(3)
	root.get_texture().get_image().save_png("/tmp/reactor-r5d-final-baseline.png")
	use_backdrop(scene,group,true);await frames(3)
	root.get_texture().get_image().save_png("/tmp/reactor-r5d-final-cached.png")
	quit()
