extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/static-hints-evidence/sources/"+OS.get_environment("STATIC_HINT_KIND")+".json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/static-hints-evidence/"+OS.get_environment("STATIC_HINT_KIND")
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

func capture(label:String,hint:Label):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var r=hint.get_global_rect();var parent_rect=p.get_global_rect() if OS.get_environment("STATIC_HINT_KIND")=="restore" else scene.galaxy_panel.get_global_rect()
 var data={"label":label,"hint":hint.text,"visible":hint.is_visible_in_tree(),"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"parent_rect":[parent_rect.position.x,parent_rect.position.y,parent_rect.size.x,parent_rect.size.y],"lines":hint.get_line_count(),"quote":p.commands.quote_label.text,"feedback":p.commands.feedback.text,"source_cores":g.profile.hyperspace.ultimate_cores,"materials":g.profile.hyperspace.materials.duplicate(true)}
 check(parent_rect.encloses(r),"static hint bounds inside actual panel "+label)
 snapshots.append(data)
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var kind=OS.get_environment("STATIC_HINT_KIND");var path="/tmp/static-hints-evidence/sources/"+kind+".json";var source_sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state));var before=g.profile.hyperspace.duplicate(true);var crew_before=g.profile.crew.duplicate(true);var galaxy_before=g.galaxy.save_data()
 check(before==raw.save.hyperspace,"real source formal hyperspace load unchanged")
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native acknowledge existing unlock");g.paused=true
 if kind=="restore":
  await click(button_named(scene,"异空间"),"native hyperspace")
  await click(p.section_buttons[1],"native warehouse")
  var card=null
  for _page in 12:
   for b in p.cards:
    if str(b.get_meta("drone_id",""))=="space:1:2":card=b;break
   if card!=null:break
   if p.next.disabled:break
   await click(p.next,"native warehouse next")
  check(card!=null,"actual white ultimate card")
  if card==null:quit(1);return
  await click(card,"native actual ultimate card");await click(p.section_buttons[2],"native forge")
  await choose(p.commands.operation,11,"native choose restore only no payment")
  check(p.commands.restore_hint.is_visible_in_tree() and p.commands.restore_hint.text.contains("不提升等级") and p.commands.restore_hint.text.contains("另需对应材料") and p.commands.restore_hint.text.contains("不会退回"),"restore hint visible before quote with all three static facts")
  await capture("01-before-restore-quote",p.commands.restore_hint)
  await click(button_named(p.sections[2],p.t("quote")),"native read-only restore quote")
  check(p.commands.quote_label.text.contains("究极核心 1") and p.commands.restore_hint.is_visible_in_tree(),"restore quote retains real one-core cost plus static caution")
  await capture("02-restore-quote-no-payment",p.commands.restore_hint)
  await choose(p.commands.operation,9,"native change operation read-only")
  check(not p.commands.restore_hint.visible,"restore hint hidden on modernization")
  await choose(p.commands.operation,11,"native restore hint reappears")
  check(p.commands.restore_hint.visible,"restore hint restored on operation reselect")
 else:
  await click(button_named(scene,"星系"),"native actual completed galaxy")
  var gp=scene.galaxy_panel
  check(g.galaxy.regions.galaxy_1.state.status=="complete" and gp.cards.crew.text=="6 人" and gp.cards.explorers.text=="0","actual completed galaxy six assigned zero construction ships")
  check(gp.complete_crew_hint.is_visible_in_tree() and gp.complete_crew_hint.text=="建设已完成，可在管理中召回船员。","completed actual page has static recall guidance")
  await capture("01-complete-crew-guidance",gp.complete_crew_hint)
  await click(gp.manage_button,"native view actual crew manager no recall")
  check(gp.crew_dialog.visible,"existing crew management remains reachable")
  await click(gp.crew_dialog.get_ok_button(),"native close manager without recall")
  await click(button_named(scene,"装备"),"native close galaxy")
  await click(button_named(scene,"星系"),"native reopen completed galaxy")
  check(gp.complete_crew_hint.is_visible_in_tree(),"completed guidance survives normal close reopen")
  await capture("02-complete-reopened",gp.complete_crew_hint)
 check(g.profile.hyperspace==before,"no payment or hyperspace state change")
 check(g.profile.crew==crew_before,"no crew recall or assignment change")
 check(g.galaxy.save_data()==galaxy_before,"no galaxy progression or rule mutation")
 check(FileAccess.get_sha256(path)==source_sha,"original source bytes unchanged")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"commit":"21587054fd6e9e4e02449514205140e5631a9900","kind":kind,"source_sha":source_sha,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"))
 print("STATIC_HINTS ",kind," failures=",checks.filter(func(c):return not c.ok).size());quit()
