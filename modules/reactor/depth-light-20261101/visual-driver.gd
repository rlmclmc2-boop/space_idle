extends SceneTree
var _watch: bool=true
var count_mode: int=1 if "single" in OS.get_cmdline_user_args() else 4
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
 for i in n:await process_frame
func clear_guidance(session,game) -> void:
 var pending: Dictionary=session.pending_guidance()
 if pending.is_empty():return
 var tries: int=0
 while not pending.is_empty() and tries<20:
  var result: Dictionary=session.dismiss_guidance(str(pending.kind),str(pending.id))
  assert(result.ok)
  pending=session.pending_guidance();tries+=1
 game._sync_guidance()
func guard_guidance(session,game) -> void:
 while _watch:
  await RenderingServer.frame_pre_draw
  if not _watch or not is_instance_valid(game):break
  clear_guidance(session,game)
func click(control: Control) -> void:
 var at: Vector2=control.get_global_rect().get_center()
 if control.get_viewport()!=root:
  at=control.get_viewport().get_parent().get_global_transform()*at
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=at;event.global_position=at
  root.push_input(event,true)
 await frames(3)
func exact_uranium(session) -> String:
 var text: Dictionary=load("res://src/systems/resource_amounts.gd").integer_text(session.economy.budget()["2"],session.amount_api)
 assert(text.ok)
 return str(text.text)
func snapshot(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/reactor-faceted-"+name+".png")
func run() -> void:
 root.size=Vector2i(1440,900);root.content_scale_size=root.size
 var game=load("res://src/main.tscn").instantiate();root.add_child(game);await frames(4)
 root.grab_focus()
 await frames(3)
 var session=game.session
 assert(session!=null and game.startup_error.is_empty() and session.current_chrono_speed()==1)
 var state: Dictionary=session.campaign_system.save_state()
 state.grants["feature:reactor"]=true;state.grants["reactor_module:condensation"]=true
 assert(session.campaign_system.restore_state(state).ok)
 session.reactor_system.refresh_availability(session.campaign_system.available)
 assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
 clear_guidance(session,game);game._select_left_module("reactor");await frames(5)
 var scene=game.reactor_scene
 var tested_owner=session.reactor_system
 if count_mode==1:
  var parameters: Dictionary=session.reactor_system._parameters.duplicate(true);parameters.reactorModules="smelting"
  var owner=load("res://src/systems/reactor.gd").new(parameters,session.amount_api,session.run_state)
  var publish: Callable=func(_factors,_wallet,_kind):
   owner.accept();return {"ok":true}
  owner.refresh_availability(func(kind,id):return kind=="feature" and id=="reactor")
  assert(owner.refresh(session.reactor_inputs(),publish).ok)
  tested_owner=owner;scene._owner=owner;scene._publish=publish
  owner.presentation_changed.connect(scene.invalidate_presentation)
  scene.bind_presentation(owner.presentation_model,func():return {"game_time":session.game_time,"paused":not session.pause_reasons.is_empty(),"running":session.run_state.is_running()})
  scene.bind_purchase_quote(func(quantity,maximum):return owner.purchase_max_preview(session.economy.can_pay) if maximum else owner.purchase_preview(session.economy.can_pay,quantity))
  await frames(8)
 guard_guidance(session,game)
 var credit: Dictionary=session.amount_api.apply("from_decimal",["1000"])
 assert(session.economy.credit_yield("2",credit.value,session.wall_time,session.game_time).ok)
 await frames(4)
 var zero: Dictionary={}
 for id in tested_owner.enabled_modules():zero[id]="0"
 assert(tested_owner.apply_allocation_plan(zero,session.reactor_inputs(),scene._publish).ok)
 await frames(4)
 # The changed thumb travel must still submit through the real native input.
 var first_id: String=str(tested_owner.enabled_modules()[0])
 var tested_slider: HSlider=scene._rows[first_id].slider
 await click(tested_slider)
 assert(scene.last_result.get("ok",false))
 var pointer_row: Dictionary={}
 for row in tested_owner.presentation_model().modules:
  if row.id==first_id:pointer_row=row
 assert(float(pointer_row.ratio)>0.0 and float(pointer_row.ratio)<1.0)
 print("NATIVE_TRACK_HIT id=",first_id," owner_ratio=",pointer_row.ratio," slider_rect=",tested_slider.get_global_rect()," ratio_anchor=",scene._rows[first_id].ratio.position)
 assert(tested_owner.apply_allocation_plan(zero,session.reactor_inputs(),scene._publish).ok)
 await frames(4)
 var role_counts: Dictionary={}
 for material in scene._stage._palette.values():
  var role: int=int(material.get_shader_parameter("surface_role"))
  role_counts[role]=int(role_counts.get(role,0))+1
 print("SURFACE_PALETTE_ROLES ",role_counts)
 print("VIDEO_CONTEXT paused=",session.pause_reasons," running=",session.run_state.is_running()," focused=",DisplayServer.window_is_focused()," pause_root=",game._battle_viewport.get_parent().get_global_transform()*game._pause_button.get_global_rect().get_center())
 await snapshot("readable-"+str(count_mode)+"-zero")
 var video: String="/tmp/reactor-readable-"+str(count_mode)+"-12s.mp4"
 var pid: int=OS.create_process("ffmpeg",["-y","-loglevel","error","-video_size","1440x900","-framerate","25","-f","x11grab","-draw_mouse","0","-i",":100.0+0,0","-t","12","-an","-c:v","libx264","-threads","2","-preset","veryfast","-crf","24","-pix_fmt","yuv420p",video])
 assert(pid>0)
 var wall: int=Time.get_ticks_usec();var game_start: float=session.game_time
 var ui_start: Dictionary=scene.presentation_counts.duplicate();var stage_start: Dictionary=scene._stage.diagnostics.duplicate()
 print("VIDEO_START real_time=1x controlled_grants_and_wallet=true pid=",pid," game_time=",game_start," phase=",scene._stage.visual_phase())
 await create_timer(1.0).timeout
 await click(scene._equal)
 assert(scene.last_result.get("ok",false))
 await create_timer(4.0).timeout
 await click(game._pause_button)
 assert(session.pause_reasons.has("user"))
 var paused_phase: float=scene._stage.visual_phase()
 var paused_light: float=float(scene._stage._background_material.get_shader_parameter("core_power"))
 await create_timer(1.0).timeout
 assert(is_equal_approx(paused_phase,scene._stage.visual_phase()))
 assert(is_equal_approx(paused_light,float(scene._stage._background_material.get_shader_parameter("core_power"))))
 print("VIDEO_NATIVE_PAUSE frozen_phase=",paused_phase," frozen_core_light=",paused_light)
 await click(game._pause_button)
 assert(not session.pause_reasons.has("user"))
 await create_timer(6.0).timeout
 while OS.is_process_running(pid):await create_timer(.05).timeout
 print("VIDEO_END wall_s=",float(Time.get_ticks_usec()-wall)/1000000.0," game_s=",session.game_time-game_start," phase=",scene._stage.visual_phase()," ui_before=",ui_start," ui_after=",scene.presentation_counts," stage_before=",stage_start," stage_after=",scene._stage.diagnostics)
 assert(FileAccess.file_exists(video))
 await snapshot("readable-"+str(count_mode)+"-active")
 print("VISUAL_OWNER ",count_mode," model=",tested_owner.presentation_model()," stage_loads=",scene._stage._loads)
 _watch=false
 await frames(2)
 if session.save_files!=null:session.save_files.close(2000)
 game.queue_free();await frames(2)
 quit()
