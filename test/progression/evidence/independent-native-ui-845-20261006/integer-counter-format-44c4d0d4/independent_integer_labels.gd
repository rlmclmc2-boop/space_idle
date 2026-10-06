extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/integer-count-evidence/native"
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
func normalized(value):return JSON.parse_string(JSON.stringify(value))
func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 snapshots.append({"label":label,"summary":p.forge_details.text,"summary_instance":p.forge_details.get_instance_id(),"drone":g.profile.hyperspace.inventory.drones["space:1:2"].duplicate(true),"module_dialog_visible":p.commands.module_dialog!=null and p.commands.module_dialog.visible})
func select_actual():
 await click(button_named(scene,"异空间"),"native open current real save hyperspace")
 await click(p.section_buttons[1],"native real warehouse")
 for b in p.cards:
  if str(b.get_meta("drone_id",""))=="space:1:2":await click(b,"native select actual white ultimate");break
 await click(p.section_buttons[2],"native actual forge summary")
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene;g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var paths=["/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json","/tmp/ultimate-chain-evidence/native/04-reultimate-checkpoint.json"];var shas={}
 for path in paths:shas[path]=FileAccess.get_sha256(path)
 var raw=JSON.parse_string(FileAccess.get_file_as_string(paths[0]));var original=normalized(g.profile.hyperspace)
 await select_actual()
 check(p.forge_details.text.contains("挂设槽 1 个") and p.forge_details.text.contains("改造版本 2") and not p.forge_details.text.contains("1.0") and not p.forge_details.text.contains("2.0"),"actual original revision2 summary shows integer slots and revision")
 await capture("01-real-revision2-integer-summary")
 var instance=p.forge_details.get_instance_id()
 await click(p.section_buttons[1],"native module management from real warehouse")
 await click(button_named(p.sections[1],p.t("module_manage")),"native actual hanging module dialog")
 var texts=[]
 for n in p.commands.module_dialog.find_children("*","Label",true,false):texts.append(n.text)
 for n in p.commands.module_choices:texts.append(n.text)
 check(texts.any(func(t):return t.contains("挂设 0 / 1（同架不可重复）")),"actual module dialog capacity integer1")
 check(p.commands.module_choices.all(func(n):return n.text.contains("等级 0") and not n.text.contains("等级 0.0")),"real module levels all display integer0")
 FileAccess.open(folder+"/module-dialog-texts.json",FileAccess.WRITE).store_string(JSON.stringify(texts,"\t"))
 await capture("02-real-integer-module-dialog")
 await click(p.commands.module_dialog.get_ok_button(),"native close module dialog")
 await click(button_named(scene,"装备"),"native close format page")
 await select_actual()
 check(p.forge_details.get_instance_id()==instance and p.forge_details.text.contains("挂设槽 1 个"),"close reopen integer label preserved same control")
 check(normalized(g.profile.hyperspace)==original,"original real namespace including receipt unchanged by all format actions")
 var final_raw=JSON.parse_string(FileAccess.get_file_as_string(paths[1]));var saved=final_raw.save.duplicate(true);saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
 g.load_progress_data(saved);g.profile.chronoParticles=float(final_raw.save.chronoParticles);g.login_chrono_particles=0;g.resume_progress();g.paused=true;g.load_hyperspace_routes();p.dirty=true;p.refresh()
 await select_actual()
 check(p.forge_details.text.contains("挂设槽 1 个") and p.forge_details.text.contains("改造版本 5") and not p.forge_details.text.contains("5.0"),"actual previously paid revision5 checkpoint integer summary")
 check(normalized(g.profile.hyperspace)==normalized(final_raw.save.hyperspace),"real revision5 paid save namespace and command fingerprint unchanged")
 await capture("03-real-revision5-integer-summary")
 for path in shas:check(FileAccess.get_sha256(path)==shas[path],"existing real source unchanged "+path.get_file())
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Only integer UI labels; existing actual revision2 and revision5 checkpoints; no new forge commit or progress tick","checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots,"source_shas":shas},"\t"));print("INTEGER_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
