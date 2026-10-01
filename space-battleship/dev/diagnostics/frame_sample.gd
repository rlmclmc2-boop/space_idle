extends SceneTree
## Opt-in real-game sampler. No simulation, FPS, VSync, resolution or save-policy changes.
class SampleGame extends "res://scripts/presented_battle_game.gd":
 var measure=false
 var counters={}
 func add(key:String,started:int)->void:
  if measure:
   counters[key+"_us"]=int(counters.get(key+"_us",0))+Time.get_ticks_usec()-started
   counters[key+"_calls"]=int(counters.get(key+"_calls",0))+1
 func tick(dt:float)->void:
  var started=Time.get_ticks_usec();super.tick(dt);add("tick",started)
 func tick_projectiles(dt:float)->void:
  var started=Time.get_ticks_usec();super.tick_projectiles(dt);add("projectile_step",started)
 func advance_jewel_repair(dt:float)->bool:
  var started=Time.get_ticks_usec();var changed=super.advance_jewel_repair(dt);add("repair",started);return changed
 func save_progress()->void:
  var started=Time.get_ticks_usec();super.save_progress();add("save",started)

class SampleScene extends "res://scripts/battlefield.gd":
 var rows=[]
 var phases={}
 var events={}
 var previous={}
 var frame_started=0
 var capture_started=0
 var armed=true
 var completed=false
 var duration=20.0
 var warmup=0.0
 var interrupted=false
 var sample_label:Label
 var metadata={}
 func create_battle_game(persist:bool)->BattleGame:
  var observed=SampleGame.new(db,persist)
  db=observed.db
  observed.launch_provider=_prototype_launch_pose
  observed.target_provider=_prototype_target_point
  return observed
 func _ready()->void:
  super._ready()
  var overlay=CanvasLayer.new();overlay.layer=100;add_child(overlay)
  var status_panel=PanelContainer.new()
  status_panel.position=Vector2(12,110)
  status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var background=StyleBoxFlat.new();background.bg_color=Color(0.02,0.06,0.09,0.95)
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:background.set_content_margin(side,8)
  status_panel.add_theme_stylebox_override("panel",background)
  overlay.add_child(status_panel)
  sample_label=Label.new();sample_label.custom_minimum_size.x=550
  sample_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  sample_label.add_theme_font_size_override("font_size",22)
  sample_label.add_theme_color_override("font_color",Color.WHITE)
  sample_label.add_theme_color_override("font_shadow_color",Color.BLACK)
  sample_label.add_theme_constant_override("shadow_offset_x",2)
  sample_label.add_theme_constant_override("shadow_offset_y",2)
  status_panel.add_child(sample_label)
  sample_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  update_waiting_status(blocking_reasons())
  metadata={"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"rendering_method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"cpu":OS.get_processor_name(),"logical_cpu_count":OS.get_processor_count(),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"window_size":DisplayServer.window_get_size(),"app_started_at":Time.get_datetime_string_from_system(),"game_sha256":FileAccess.get_sha256("res://scripts/game.gd"),"branches_sha256":FileAccess.get_sha256("res://scripts/enhancement_branches.gd"),"pulse_sha256":FileAccess.get_sha256("res://dev/toon_ship/pulse_vfx.gd"),"timing_note":"frame_us includes rendering/present/VSync/wait; main_us is this main callback only. Nested phases overlap; not GPU time. Engine render counters are the latest available frame, not synchronized GPU measurements."}
 func sampler_window_focused()->bool:
  # Application focus alone stays true when the separate QA window owns focus.
  return DisplayServer.get_name()=="headless" or get_window().has_focus()
 func blocking_reasons()->PackedStringArray:
  var reasons=PackedStringArray()
  # Use the engine's active modal chain, not visibility flags on ordinary nodes.
  # QATools is a non-modal Window and may remain open behind the game.
  var modal=get_last_exclusive_window()
  if is_instance_valid(modal) and modal!=get_window() and modal.visible:
   reasons.append("请关闭弹窗："+(modal.title if not modal.title.is_empty() else str(modal.name)))
  if background_unfocused or not sampler_window_focused():
   reasons.append("游戏窗口未获得焦点，请点击游戏窗口")
  if game.paused:reasons.append("游戏已暂停，请手动继续游戏")
  if game.speed!=1:reasons.append("当前为 %s 倍速，请手动切回 1 倍速"%str(game.speed))
  if equipment_panel.upgrade_amount!=1:
   reasons.append("当前升级数量为 %s，请手动选择 +1"%str(equipment_panel.upgrade_amount))
  return reasons
 func blocked()->bool:
  return not blocking_reasons().is_empty()
 func update_waiting_status(reasons:PackedStringArray)->void:
  var message=""
  if not reasons.is_empty():
   message=("采样已中止，已丢弃本次数据：" if interrupted else "性能采样等待：")+"\n"+"\n".join(reasons)
  else:
   message="性能采样暖机：条件已满足，%.1f 秒后自动记录 %s 秒。\n请保持当前页、1 倍速 / +1。"%[maxf(0.0,2.0-warmup),str(duration)]
  if sample_label.text!=message:sample_label.text=message
 func sampling_window_state(window:Window)->Dictionary:
  if not is_instance_valid(window):return {"present":false}
  return {"present":true,"visible":window.visible,"focused":window.has_focus(),"mode":window.mode,"embedded":window.is_embedded(),"screen":window.current_screen}
 func sampling_inspector_state()->Dictionary:
  if not is_instance_valid(equipment_panel):return {"present":false}
  return {"present":true,"visible":equipment_panel.detail_frame.is_visible_in_tree(),"expanded":equipment_panel.details_open,"stats_visible":equipment_panel.detail.stats.is_visible_in_tree()}
 func sampling_display_state()->Dictionary:
  var main_window=get_window()
  var qa=get_tree().root.get_node_or_null("QATools") as Window
  return {"main":sampling_window_state(main_window),"qa":sampling_window_state(qa),"equipment_inspector":sampling_inspector_state(),"screen_refresh_hz":DisplayServer.screen_get_refresh_rate(main_window.current_screen) if DisplayServer.get_name()!="headless" else -1.0}
 func add(key:String,started:int)->void:
  if capture_started>0:phases[key]=int(phases.get(key,0))+Time.get_ticks_usec()-started
 func advance_game_time(seconds:float)->void:
  var started=Time.get_ticks_usec();super.advance_game_time(seconds);add("advance_us",started)
 func refresh_visible_cards(delta:=0.0)->void:
  var started=Time.get_ticks_usec();super.refresh_visible_cards(delta);add("cards_us",started)
 func refresh_draw_layers(dt:float)->void:
  var started=Time.get_ticks_usec();super.refresh_draw_layers(dt);add("draw_refresh_us",started)
 func on_event(kind:String,info:Dictionary)->void:
  var started=Time.get_ticks_usec();super.on_event(kind,info)
  if capture_started>0:events[kind]=int(events.get(kind,0))+1
  add("events_us",started)
 func _draw_muzzle_cues()->void:
  var started=Time.get_ticks_usec();super._draw_muzzle_cues();add("muzzle_draw_us",started)
 func draw_battle()->void:
  var started=Time.get_ticks_usec();super.draw_battle();add("battle_draw_us",started)
 func _process(delta:float)->void:
  var now=Time.get_ticks_usec()
  var reasons=blocking_reasons()
  if capture_started>0 and not reasons.is_empty():
   capture_started=0;game.measure=false;rows.clear();previous={}
   armed=true;warmup=0.0;interrupted=true
  if capture_started>0 and not previous.is_empty():
   previous.frame_us=now-frame_started
   previous.phases=phases.duplicate();previous.events=events.duplicate()
   previous.combat=game.counters.duplicate()
   rows.append(previous)
   if now-capture_started>=duration*1000000 or rows.size()>=3600:
    finish_capture()
  if armed and not completed:
   warmup=0.0 if not reasons.is_empty() else warmup+delta
   update_waiting_status(reasons)
   if warmup>=2.0:
    # Keep started_at compatible, but make it the actual start of this capture.
    metadata.capture_started_at=Time.get_datetime_string_from_system()
    metadata.started_at=metadata.capture_started_at
    metadata.window_state_at_start=sampling_display_state()
    capture_started=now;armed=false;game.measure=true;interrupted=false
    sample_label.text="性能采样中（%s 秒），请保持当前页、1 倍速和 +1。游戏继续正常运行。"%str(duration)
  phases.clear();events.clear();game.counters.clear();frame_started=now
  var started=Time.get_ticks_usec()
  super._process(delta)
  var main_us=Time.get_ticks_usec()-started
  if capture_started>0:
   previous={"elapsed_us":now-capture_started,"delta":delta,"main_us":main_us,"page":equipment_tabs.current_tab,"speed":game.speed,"paused":game.paused,"background":background_unfocused,"upgrade_amount":equipment_panel.upgrade_amount,"condition_valid":not blocked(),"equipment_inspector":sampling_inspector_state(),"projectiles":game.projectiles.size(),"missile_queue":game.missile_queue.size(),"repeats":game.jewel_repeats.size(),"deferred_buckets":game.enhancement_deferred.size(),"attacks":game.profile.enhancementAttacks,"hits":game.profile.enhancementHits,"pulse_events":pulse_events.size(),"particles":particles.size(),"nodes":get_tree().get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_memory":OS.get_static_memory_usage(),"static_memory_peak":OS.get_static_memory_peak_usage(),"engine_process_seconds":Performance.get_monitor(Performance.TIME_PROCESS),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
 func viewport_inventory(node:Node,result:Array)->void:
  if node is SubViewport:result.append({"path":str(node.get_path()),"size":node.size,"update_mode":node.render_target_update_mode,"objects":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_OBJECTS_IN_FRAME)})
  for child in node.get_children():viewport_inventory(child,result)
 func finish_capture()->void:
  capture_started=0;completed=true;game.measure=false
  var inventory=[];viewport_inventory(self,inventory);metadata.viewports=inventory
  metadata.finished_at=Time.get_datetime_string_from_system()
  metadata.window_state_at_finish=sampling_display_state()
  var stamp=Time.get_datetime_string_from_system().replace(":","-")
  var path="res://.runtime/frame-sample-"+stamp+".json"
  var directory_error=DirAccess.make_dir_recursive_absolute("res://.runtime")
  if directory_error!=OK:
   sample_label.text="性能报告目录创建失败："+str(directory_error);printerr(sample_label.text);return
  var file=FileAccess.open(path,FileAccess.WRITE)
  if file==null:
   sample_label.text="性能报告写入失败："+str(FileAccess.get_open_error());printerr(sample_label.text);return
  file.store_string(JSON.stringify({"metadata":metadata,"rows":rows}));file.flush()
  var write_error=file.get_error();file.close()
  if write_error!=OK:
   sample_label.text="性能报告写入失败："+str(write_error);printerr(sample_label.text);return
  sample_label.text="性能采样完成：.runtime/frame-sample-"+stamp+".json（F7 再采一页）"
  print("PERFORMANCE SAMPLE: ",ProjectSettings.globalize_path(path))
  previous={}
 func _unhandled_input(event:InputEvent)->void:
  if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F7 and capture_started==0:
   rows.clear();previous={};completed=false;armed=true;warmup=0;interrupted=false
   update_waiting_status(blocking_reasons())
   get_viewport().set_input_as_handled();return
  super._unhandled_input(event)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate()
 scene.set_script(SampleScene)
 root.add_child(scene)
 current_scene=scene
