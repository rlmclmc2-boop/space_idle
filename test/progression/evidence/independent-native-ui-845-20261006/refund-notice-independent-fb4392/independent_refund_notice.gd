extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/qa845-evidence/exit-retest/paid-candidate-checkpoint.json"));var saved=raw.save.duplicate(true)
  saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
  game.load_progress_data(saved);game.profile.chronoParticles=float(raw.save.chronoParticles);game.login_chrono_particles=0;game.load_hyperspace_routes()
  return game
 func show_qa_tools()->void:pass
var scene
var g
var p
var checks=[]
var actions=[]
var snapshots=[]
var folder="/tmp/refund-notice-evidence/native"
func _initialize():call_deferred("run")
func check(ok:bool,label:String):checks.append({"ok":ok,"label":label});print("CHECK ",ok," ",label)
func button_named(parent:Node,text:String):
 for b in parent.find_children("*","Button",true,false):
  if b.text==text:return b
 return null
func click(c:Control,label:String):
 await process_frame;await process_frame
 var ancestor=c.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:
   ancestor.ensure_control_visible(c);await process_frame;await process_frame;break
  ancestor=ancestor.get_parent()
 var window=c.get_window();var point=c.get_global_transform_with_canvas()*(c.size/2)
 if window!=root and window.is_embedded():point=root.get_final_transform()*(Vector2(window.position)+point)
 else:point=window.get_final_transform()*point
 var event_window_id=root.get_window_id() if window==root or window.is_embedded() else window.get_window_id()
 actions.append({"label":label,"window_id":event_window_id,"point":[point.x,point.y],"disabled":c.get("disabled"),"visible":c.is_visible_in_tree(),"native":true})
 var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=event_window_id;Input.parse_input_event(motion);await process_frame
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.window_id=event_window_id;Input.parse_input_event(e);await process_frame


func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+label+".png");DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var d={"label":label,"energy":g.profile.hyperspace.energy,"active":g.profile.hyperspace.active.duplicate(true),"runtime_result":g.manual_hyperspace.last_result.duplicate(true),"notice":p.recent_result.text,"notice_visible":p.recent_result.is_visible_in_tree(),"status":p.status.text,"stage":g.stage,"point":g.group_index,"highest":g.profile.highestLevel,"actions":actions.duplicate(true)}
 snapshots.append(d);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(d,"\t"))
func reload(raw:Dictionary):
 var saved=raw.save.duplicate(true);saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
 g.load_progress_data(saved);g.profile.chronoParticles=float(raw.save.chronoParticles);g.login_chrono_particles=0;g.resume_progress();g.paused=true;g.load_hyperspace_routes();p.refresh_manual_status();p.refresh_progress()
 await process_frame;await process_frame
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene;g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var paid_path="/tmp/qa845-evidence/exit-retest/paid-candidate-checkpoint.json";var unpaid_path="/tmp/qa845-evidence/native/queued-candidate-checkpoint.json";var ordinary_path="/tmp/qa845-evidence/original-save-reach15-old0a.json"
 var paid=JSON.parse_string(FileAccess.get_file_as_string(paid_path));var unpaid=JSON.parse_string(FileAccess.get_file_as_string(unpaid_path));var ordinary=JSON.parse_string(FileAccess.get_file_as_string(ordinary_path));var source_shas={}
 for path in [paid_path,unpaid_path,ordinary_path]:source_shas[path]=FileAccess.get_sha256(path)
 var ticket=float(paid.save.hyperspace.active.ticket);var expected=float(paid.save.hyperspace.energy)+ticket
 await click(button_named(scene,"异空间"),"native view actual paid checkpoint recovery notice")
 check(g.profile.hyperspace.active.is_empty() and is_equal_approx(float(g.profile.hyperspace.energy),expected),"actual paid receipt refunded once through patch formal startup")
 check(g.profile.hyperspace.inventory==paid.save.hyperspace.inventory and g.profile.hyperspace.materials==paid.save.hyperspace.materials,"notice patch changes neither actual inventory nor materials")
 var result=g.manual_hyperspace.last_result
 check(result.get("reason")=="interrupted_reload" and is_equal_approx(float(result.get("refund",0)),ticket) and p.recent_result.visible and p.recent_result.text.contains("读档中断") and p.recent_result.text.contains("已退票 %.0f"%ticket),"native notice reflects actual interrupted route and exact refund")
 await capture("01-actual-paid-refund-notice")
 var state=JSON.stringify(g.profile.hyperspace);var text=p.recent_result.text;var control=p.recent_result
 await click(button_named(scene,"装备"),"native close notice page")
 await click(button_named(scene,"异空间"),"native reopen notice page")
 await click(button_named(scene,"异空间"),"repeat native current notice page")
 check(p.recent_result==control and p.recent_result.text==text and p.recent_result.visible and JSON.stringify(g.profile.hyperspace)==state,"close/reopen and repeated native page click preserve actual notice without refund")
 await capture("02-reopened-interruption-notice")
 var settled={"save":g.portable_save_data(),"rng_state":str(g.rng.state),"source_commit":"fb4392f32d3fcdb85f90e9f7816f9d39dc6ea1f7"};FileAccess.open(folder+"/settled-candidate-checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify(settled,"\t"))
 await reload(paid)
 check(is_equal_approx(float(g.profile.hyperspace.energy),expected) and g.manual_hyperspace.last_result.get("reason")=="interrupted_reload","same actual started input cannot compound refunded balance")
 await capture("03-same-paid-input-second-load")
 await reload(settled)
 check(is_equal_approx(float(g.profile.hyperspace.energy),expected) and g.manual_hyperspace.last_result.is_empty() and not p.recent_result.visible,"actual already-settled reload neither refunds nor claims new refund notice")
 await capture("04-settled-load-no-false-notice")
 await reload(unpaid)
 check(g.profile.hyperspace==unpaid.save.hyperspace and g.manual_hyperspace.queued.is_empty() and g.manual_hyperspace.last_result.is_empty() and not p.recent_result.visible,"actual prior unpaid queue checkpoint reload never shows false refund")
 await capture("05-unpaid-load-no-false-notice")
 await reload(ordinary)
 check(g.profile.hyperspace==ordinary.save.hyperspace and g.manual_hyperspace.last_result.is_empty() and not p.recent_result.visible,"original ordinary source has no false refund or altered balance")
 await capture("06-ordinary-load-no-false-notice")
 for path in source_shas:check(FileAccess.get_sha256(path)==source_shas[path],"source checkpoint remains unchanged: "+path.get_file())
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"fb4392f32d3fcdb85f90e9f7816f9d39dc6ea1f7","source_shas":source_shas,"old0a_to_845_to_patch":true,"not_parent_numeric_cp":true,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"));print("REFUND_NOTICE_NATIVE failures=",checks.filter(func(c):return not c.ok).size());quit()
