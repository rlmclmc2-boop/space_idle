extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func click(control:Control)->void:
 var point=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
 var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=root.get_window_id();Input.parse_input_event(motion);await process_frame
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.window_id=root.get_window_id();Input.parse_input_event(event);await process_frame
func popup_text(node:Node)->Array:
 var result:Array=[]
 if node is PopupPanel and node.visible:
  for child in node.find_children("*","Label",true,false):result.append(child.text)
 for child in node.get_children(true):result.append_array(popup_text(child))
 return result
func run()->void:
 var source_path=OS.get_environment("QA_HOVER_SOURCE")
 if source_path.is_empty():printerr("QA_HOVER_SOURCE must be an actual saved source");quit(2);return
 var source=JSON.parse_string(FileAccess.get_file_as_string(source_path))
 if not source is Dictionary or not source.get("save") is Dictionary:printerr("Invalid hover source");quit(2);return
 var size_text=OS.get_environment("QA_HOVER_WIDTH")
 if not size_text.is_empty():root.size=Vector2i(int(size_text),int(OS.get_environment("QA_HOVER_HEIGHT")))
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false
 g.load_progress_data(source.save)
 check(g.profile.highestLevel==source.save.highestLevel,"Actual source formal save accepted")
 g.resume_progress();g.rng.state=int(str(source.rng_state));scene.refresh_tab_visibility()
 await process_frame;await click(scene.system_nav_buttons[4]);await process_frame
 var panel=scene.enhancement_panel;check(panel.visible,"Native page4 visit")
 var before=JSON.stringify(g.profile);var rng_before=g.rng.state
 var records:Array=[]
 for item in [{"name":"history","control":panel.level_label},{"name":"weapon-description","control":panel.effect_cards.weapons[0].description}]:
  var control:Control=item.control
  var point=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
  var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=root.get_window_id();Input.parse_input_event(motion)
  var end=Time.get_ticks_usec()+1200000
  while Time.get_ticks_usec()<end:await process_frame
  var hovered=root.gui_get_hovered_control();var texts=popup_text(root)
  check(hovered==control,"Native hover reaches "+item.name)
  check(not control.tooltip_text.is_empty() and texts.has(control.tooltip_text),"Actual visible tooltip contains assigned "+item.name)
  check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Hover leaves source model/RNG unchanged")
  records.append({"name":item.name,"tooltip":control.tooltip_text,"visible_popup_texts":texts,"hovered":str(hovered.get_path()) if hovered!=null else "","expected":str(control.get_path())})
  var folder=OS.get_environment("QA_HOVER_EVIDENCE")
  if not folder.is_empty() and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+item.name+".png")
 var details:Button=panel.effect_cards.weapons[0].details
 await click(details);await process_frame
 check(is_instance_valid(panel.effect_detail_dialog) and panel.effect_detail_dialog.visible,"Adjacent detail button remains reachable")
 var folder=OS.get_environment("QA_HOVER_EVIDENCE")
 if not folder.is_empty():FileAccess.open(folder+"/hover-results.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
 print("ENHANCEMENT_HOVER ",checks," checks ",failures," failures");quit(1 if failures else 0)
