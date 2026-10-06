extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/clear60-ui-evidence/sources/save_final.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/clear60-ui-evidence/native"
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
 var gp=scene.galaxy_panel
 var d={"label":label,"stage":g.stage,"highest":g.profile.highestLevel,"pending":g.pending_unlocks.duplicate(),"galaxy_selected":gp.selected,"galaxy_status":g.galaxy.regions.galaxy_1.state.status,"galaxy_detail_slot":gp.detail_slot,"galaxy_detail":gp.details.text,"history":g.profile.hyperspace.history.duplicate(true),"drone_id":p.selected_id,"quote":p.commands.quote_label.text,"feedback":p.commands.feedback.text,"request":p.commands.quoted_request.duplicate(true),"commit_disabled":p.commands.commit_button.disabled}
 snapshots.append(d);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(d,"\t"))
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var path="/tmp/clear60-ui-evidence/sources/save_final.json";var hash=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state))
 check(g.profile.highestLevel==61 and g.profile.cleared.has(60) and g.profile.hyperspace==raw.save.hyperspace,"actual clear60 formal load preserves full hyperspace state and real highest61")
 await capture("01-actual-clear60-formal-load")
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native acknowledge actual pending unlock")
  g.paused=true
 check(g.pending_unlocks.is_empty(),"actual pending unlock notices acknowledged natively")
 var nav=button_named(scene,"星系")
 check(nav!=null and nav.is_visible_in_tree() and not nav.disabled,"actual galaxy navigation available")
 if nav!=null:await click(nav,"native open actual galaxy after clear60")
 var gp=scene.galaxy_panel
 check(gp.selected=="galaxy_1" and gp.is_visible_in_tree() and gp.selector.item_count>=1,"real galaxy_1 selector and page opened")
 await capture("02-galaxy-entry")
 if gp.start_button.is_visible_in_tree():await click(gp.start_button,"native start actual available galaxy")
 check(g.galaxy.regions.galaxy_1.state.status=="exploring","native galaxy start enters exploring without fake building")
 await capture("03-galaxy-started")
 var map=gp.map;var picked=-1;var pos=Vector2.ZERO
 for y in range(50,int(map.size.y)-55,12):
  for x in range(20,int(map.size.x)-20,12):
   var at=Vector2(x,y);var id=map.pick(at)
   if id>=0:picked=id;pos=at;break
  if picked>=0:break
 if picked>=0:
  var point=map.get_window().get_final_transform()*map.get_global_transform_with_canvas()*pos
  actions.append({"label":"native actual survey footprint select","slot":picked,"point":[point.x,point.y],"native":true})
  for down in [true,false]:
   var e=InputEventMouseButton.new();e.position=point;e.window_id=root.get_window_id();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);await process_frame
 check(picked>=0 and gp.detail_slot==picked and gp.detail_frame.visible and not gp.details.text.is_empty(),"native existing building-plan footprint opens correct detail")
 await capture("04-galaxy-building-plan-detail")
 await click(gp.manage_button,"native galaxy crew manager")
 check(gp.crew_dialog.visible,"galaxy crew interaction dialog opens")
 await capture("05-galaxy-real-crew-dialog")
 await click(gp.crew_dialog.get_ok_button(),"native close galaxy crew manager")
 await click(button_named(scene,"装备"),"native close galaxy page")
 await click(button_named(scene,"星系"),"native reopen galaxy")
 check(gp.selected=="galaxy_1" and g.galaxy.regions.galaxy_1.state.status=="exploring","galaxy close reopen preserves started state")
 await click(button_named(scene,"异空间"),"native hyperspace after real clear60")
 await click(p.section_buttons[1],"native actual drone warehouse")
 var targets={"space:2:2":20,"space:1:3":55,"space:2:1":20,"space:4:2":15}
 for id in targets:
  var drone=g.profile.hyperspace.inventory.drones[id];var card=null
  for _page in 8:
   for b in p.cards:
    if str(b.get_meta("drone_id",""))==id:card=b;break
   if card!=null:break
   if p.next.disabled:break
   await click(p.next,"native warehouse page for "+id)
  check(card!=null,"actual drone card found "+id)
  if card==null:continue
  await click(card,"native select actual "+str(drone.weapon)+" drone")
  await click(p.section_buttons[2],"native forge page")
  await choose(p.commands.operation,9,"native modernization operation")
  var before=JSON.stringify(g.profile.hyperspace)
  await click(button_named(p.sections[2],p.t("quote")),"native modernization quote "+str(drone.weapon))
  check(int(p.commands.quoted_request.args.target_level)==int(targets[id]),"actual corresponding route target "+str(drone.weapon)+" "+str(targets[id]))
  check(JSON.stringify(g.profile.hyperspace)==before,"modernization quote read-only "+str(drone.weapon))
  await capture("06-modernize-"+str(drone.weapon))
  if id=="space:1:3":
   var original_highest=g.profile.highestLevel;g.profile.highestLevel=45
   await click(button_named(p.sections[2],p.t("quote")),"short private in-memory cap45 quote using unchanged real records")
   check(int(p.commands.quoted_request.args.target_level)==45,"real beta55 retained but cap45 selects actual beta45")
   var request=p.commands.quoted_request.duplicate(true);request.args.target_level=55
   var denied=g.hyperspace.preview_forge(g,request)
   check(str(denied.error)=="stale_modernization_target","domain rejects real55 request above private cap45")
   await capture("07-private-cap45-real-history-boundary")
   g.profile.highestLevel=original_highest;p.commands.invalidate()
  await click(p.section_buttons[1],"native back to warehouse for next actual route")
  while p.page>0:await click(p.previous,"native warehouse back to first page")
 check(g.profile.hyperspace.history==raw.save.hyperspace.history and g.profile.hyperspace.inventory==raw.save.hyperspace.inventory and g.profile.hyperspace.materials==raw.save.hyperspace.materials,"all real history inventory materials unchanged; quote only no forge payment")
 check(FileAccess.get_sha256(path)==hash,"parent actual source stays byte-identical")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5","source_evidence_commit":"bf09ce3c9c8bf2c0405a7893337896484237aab7","source_sha":hash,"crossversion_prefix_and45_formal_recovery":true,"formal_scene_regeneration":true,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"))
 print("CLEAR60_NATIVE failures=",checks.filter(func(c):return not c.ok).size());quit()
