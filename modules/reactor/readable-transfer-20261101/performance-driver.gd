extends SceneTree
var frozen: bool=false
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
 for i in n:await process_frame
func clear_guidance(session,game):
 var p: Dictionary=session.pending_guidance()
 while not p.is_empty():
  assert(session.dismiss_guidance(str(p.kind),str(p.id)).ok)
  p=session.pending_guidance()
 game._sync_guidance()
func measure(label: String,scene,seconds: float):
 var start: int=Time.get_ticks_usec();var last: int=start;var samples: Array[float]=[]
 var before: Dictionary=scene.presentation_counts.duplicate();var nodes_before: int=scene.get_child_count()
 var stages_before: Dictionary=scene._stage.diagnostics.duplicate()
 while float(Time.get_ticks_usec()-start)/1000000.0<seconds:
  await process_frame
  var now: int=Time.get_ticks_usec();samples.append(float(now-last)/1000.0);last=now
 var fps: float=float(samples.size())*1000000.0/float(last-start)
 samples.sort()
 var delta: Dictionary={}
 for key in before:delta[key]=scene.presentation_counts[key]-before[key]
 var stage_delta: Dictionary={}
 for key in stages_before:stage_delta[key]=scene._stage.diagnostics[key]-stages_before[key]
 print("PROFILE ",JSON.stringify({"mode":label,"frames":samples.size(),"wall_ms":float(last-start)/1000.0,"fps":fps,"mean_ms":1000.0/fps,"p50_ms":samples[int((samples.size()-1)*.5)],"p95_ms":samples[int((samples.size()-1)*.95)],"ui_delta":delta,"stage_delta":stage_delta,"root_children_before":nodes_before,"root_children_after":scene.get_child_count()}))
func snap(scene,name: String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/reactor-faceted-"+name+".png")
func run():
 root.size=Vector2i(1440,900);root.content_scale_size=root.size
 var game=load("res://src/main.tscn").instantiate();root.add_child(game);await frames(4)
 var session=game.session
 assert(session!=null and game.startup_error.is_empty())
 var state: Dictionary=session.campaign_system.save_state();state.grants["feature:reactor"]=true;state.grants["reactor_module:condensation"]=true
 assert(session.campaign_system.restore_state(state).ok)
 session.reactor_system.refresh_availability(session.campaign_system.available)
 assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
 clear_guidance(session,game);game._select_left_module("reactor");await frames(5)
 var scene=game.reactor_scene
 scene._equal.pressed.emit();await frames(5);clear_guidance(session,game)
 await create_timer(2.3).timeout;clear_guidance(session,game)
 game.set_process(false)
 var started: int=Time.get_ticks_usec();var game_start: float=session.game_time
 scene.bind_presentation(session.reactor_system.presentation_model,func():return {"game_time":game_start+float(Time.get_ticks_usec()-started)/1000000.0,"paused":frozen,"running":true})
 await frames(3)
 print("PROFILE_CONTEXT fixed_battle_and_session=true wall_clock_visual_1x=true renderer=Mesa_llvmpipe_GL_compatibility no_recording=true size=",root.size," loads=",scene._stage._loads)
 await measure("projected_animated_first",scene,5.0)
 frozen=true;await frames(3)
 await measure("projected_frozen_same_render",scene,5.0)
 frozen=false;scene.hide();await frames(3)
 await measure("projected_hidden_no_replacement",scene,5.0)
 scene.show();await frames(5)
 await measure("projected_animated_return",scene,5.0)
 print("PROJECTED_CACHE_END ",scene._stage.diagnostics)
 if session.save_files!=null:session.save_files.close(2000)
 game.queue_free();await frames(3)
 quit()
