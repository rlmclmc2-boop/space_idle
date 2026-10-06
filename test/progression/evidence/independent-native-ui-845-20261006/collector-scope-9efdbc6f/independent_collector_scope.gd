extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/collector-scope-evidence/sources/save_final.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/collector-scope-evidence/native"
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

func choose(option:OptionButton,index:int,label:String):
 await click(option,label+" open actual native menu")
 var menu=option.get_popup();var input=preload("res://qa/player_input.gd").new();input.setup(scene,self)
 for _n in 30:
  if menu.get_focused_item()==index:break
  if not await input.popup_focus_step(menu,index):break
 check(await input.popup_choice(menu,index),label+" actual highlighted menu Enter")
 actions.append({"label":label,"native_menu_window":menu.get_window_id(),"index":index,"selected":option.selected})

func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var path="/tmp/collector-scope-evidence/sources/save_final.json";var sha=FileAccess.get_sha256(path);var before=g.profile.hyperspace.duplicate(true)
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native existing unlock acknowledge");g.paused=true
 await click(button_named(scene,"异空间"),"native hyperspace")
 await click(p.section_buttons[1],"native current real warehouse")
 var card=null
 for _page in 12:
  for b in p.cards:
   if str(b.get_meta("drone_id",""))=="space:6:8":card=b;break
  if card!=null:break
  if p.next.disabled:break
  await click(p.next,"native next current actual page")
 if card==null:quit(1);return
 await click(card,"native actual collector-equipped drone")
 await click(button_named(p.sections[1],p.t("module_manage")),"native module hint inspect without applying")
 var label=null
 for c in p.commands.module_dialog.find_children("*","Label",true,false):
  if c.text.contains("资源收集器："):label=c;break
 check(label!=null and label.is_visible_in_tree(),"existing module source hint displays collector scope")
 if label==null:quit(1);return
 check(label.text.contains("战斗掉落铁/铀") and label.text.contains("自动生成铀") and label.text.contains("铁熔炉产出"),"three actual direct production paths named")
 check(label.text.contains("不影响异空间材料") and label.text.contains("宝石/强化碎片") and label.text.contains("星系自动铁/铀"),"unsupported material and production sources explicitly excluded")
 check(not label.text.contains("\\n") and label.text.split("\n").size()==4,"actual hint uses four real lines no literal escape")
 var dialog=p.commands.module_dialog;var pos=dialog.position;var desktop=DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(root.get_window_id()))
 check(dialog.size.x<=800,"module dialog keeps compact readable width")
 check(desktop.encloses(Rect2i(pos,dialog.size)),"actual module dialog stays inside desktop usable bounds")
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/actual-collector-source-hint-screen.png")
 check(g.profile.hyperspace==before and FileAccess.get_sha256(path)==sha,"source and actual profile unchanged no apply payment or equip")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha":sha,"actual_hint":label.text,"dialog_position":[pos.x,pos.y],"dialog_size":[dialog.size.x,dialog.size.y],"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions},"\t"))
 print("COLLECTOR_SCOPE_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
