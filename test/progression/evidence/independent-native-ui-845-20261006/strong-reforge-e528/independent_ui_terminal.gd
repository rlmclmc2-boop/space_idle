extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/e528-strong34-evidence/cached-run/save_final.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/e528-strong34-evidence/ui-terminal"
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

func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var data={"label":label,"selected":p.selected_id,"detail_title":p.detail_title.text,"details":p.details.text,"budgets":p.budgets.text,"totals_text":p.commands.totals_label.text if p.commands.totals_label!=null else "","totals":g.hyperspace_totals().duplicate(true),"modules":g.profile.hyperspace.hanging_modules.duplicate(true),"equipped":g.profile.hyperspace.inventory.equipped.duplicate(true)}
 snapshots.append(data);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func wheel(c:Control):
 var window=c.get_window();var point=c.get_global_transform_with_canvas()*(c.size/2)
 if window!=root and window.is_embedded():point=root.get_final_transform()*(Vector2(window.position)+point)
 else:point=window.get_final_transform()*point
 var wid=root.get_window_id() if window==root or window.is_embedded() else window.get_window_id()
 for _i in 9:
  var move=InputEventMouseMotion.new();move.position=point;move.window_id=wid;Input.parse_input_event(move);await process_frame
  for down in [true,false]:
   var e=InputEventMouseButton.new();e.position=point;e.window_id=wid;e.button_index=MOUSE_BUTTON_WHEEL_DOWN;e.pressed=down;Input.parse_input_event(e);await process_frame
 actions.append({"label":"native totals scroll to hanging bonuses","window_id":wid,"point":[point.x,point.y]})
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var path="/tmp/e528-strong34-evidence/cached-run/save_final.json";var sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));var before=g.profile.hyperspace.duplicate(true)
 check(before==raw.save.hyperspace,"actual terminal hyperspace unchanged")
 check(g.stage==35 and g.state==g.State.LEVEL_CLEAR and int(g.profile.highestLevel)==36,"actual clear35 stop;36 only unlocked, no stage36 advance")
 check(g.profile.cleared.has(35),"actual production cleared35 receipt")
 check(before.inventory.equipped==["space:1:2","space:2:3","space:1:11","space:1:13"],"actual original terminal fleet IDs")
 check(int(before.materials.glueball)==4 and int(before.materials.degenerate_matter)==0 and int(before.materials.antiproton)==1,"actual terminal material balance")
 await capture("00-actual-main35-clear-paused")
 await click(button_named(scene,"异空间"),"native actual hyperspace terminal")
 await click(p.section_buttons[1],"native terminal warehouse")
 await click(button_named(p.sections[1],p.t("totals_manage")),"native terminal actual bonuses")
 await wheel(p.commands.totals_label.get_parent())
 await capture("01-terminal-resource20-master58-9")
 await click(p.commands.totals_dialog.get_ok_button(),"native close terminal totals")
 check(g.profile.hyperspace==before and FileAccess.get_sha256(path)==sha,"read-only terminal no progression/payment/profile/file mutation")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":sha,"x1_seconds":raw.x1_seconds,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots,"scope":"Normal production graphics; paused actual terminal clear35 snapshot, no next/continue action"},"\t"))
 print("UI_TERMINAL_DONE failures=",checks.filter(func(c):return not c.ok).size());quit()
