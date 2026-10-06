extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/e528-strong34-evidence/actual-combat35/snapshot.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/e528-strong34-evidence/ui35"
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
 var path="/tmp/e528-strong34-evidence/actual-combat35/snapshot.json";var sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state));var before=g.profile.hyperspace.duplicate(true)
 check(before==raw.save.hyperspace,"actual second-round combat35 source formally loaded unchanged")
 check(int(g.profile.highestLevel)==35 and int(before.round_id)==2,"actual second round frontier35")
 check(before.inventory.sealed.is_empty(),"all ten real kept drones already reclaimed")
 check(before.inventory.equipped.size()==4,"actual ship currently equips four drones")
 for _i in 5:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native acknowledge actual pending unlock");g.paused=true
 await click(button_named(scene,"异空间"),"native actual hyperspace")
 await click(p.section_buttons[1],"native actual warehouse")
 await capture("00-reclaimed-warehouse")
 for id in before.inventory.equipped:
  while p.page>0:await click(p.previous,"native first page")
  var card=null
  for _page in 12:
   for b in p.cards:
    if str(b.get_meta("drone_id",""))==str(id):card=b;break
   if card!=null:break
   if p.next.disabled:break
   await click(p.next,"native current fleet pagination")
  check(card!=null,"actual equipped card found "+str(id))
  if card==null:continue
  await click(card,"native actual selected "+str(id))
  check(p.detail_title.text.contains("等级 "+str(int(before.inventory.drones[id].level))),"actual fleet level "+str(id))
  await capture("fleet-"+str(id).replace(":","-"))
  await click(p.section_buttons[2],"native forge "+str(id))
  await choose(p.commands.operation,9,"native modernize "+str(id))
  await click(button_named(p.sections[2],p.t("quote")),"native read actual price "+str(id))
  var request=p.commands.quoted_request.duplicate(true);var preview=g.hyperspace.preview_forge(g,request)
  var d:Dictionary=before.inventory.drones[id];var c:Dictionary=g.hyperspace.config
  if d.ultimate:check(str(preview.error)=="ultimate_modification_forbidden","actual ultimate modernization blocked")
  else:
   var route=c.routes.keys().filter(func(k):return c.routes[k].weapon==d.weapon)[0]
   var target=0
   for k in before.history.get(route,{}):
    if int(k)<=int(g.profile.highestLevel):target=maxi(target,int(k))
   if target<=int(d.level):
    check(str(preview.error)=="no_new_record" and p.commands.commit_button.disabled,"actual new legendary already at highest corresponding route30 record; no modernize quote "+str(id))
    snapshots.append({"label":"actual-modernization-quote","id":id,"preview":preview,"request":request,"quote_label":p.commands.quote_label.text,"materials":before.materials.duplicate(true),"disabled":p.commands.commit_button.disabled})
    await capture("quote-"+str(id).replace(":","-"))
    await click(p.section_buttons[1],"native warehouse next")
    continue
   var coefficient=1.0
   for a in d.affixes:coefficient+=float(c.modernization_tier_weights[str(int(a.tier))])
   var cost=roundf((1.0+float(target-int(c.material_reward_start_level))/float(c.modernization_level_step))*coefficient*(float(c.modernization_legendary_multiplier) if d.legendary else 1.0))*float(c.modernization_cost_base)
   check(int(request.args.get("target_level",0))==target,"quote target uses actually retained eligible history "+str(id))
   check(float(preview.get("cost",{}).get(c.routes[route].material,-1))==cost,"native price agrees independent base+1 arithmetic "+str(id))
   check(p.commands.quote_label.text.contains(str(int(cost))),"actual quote label displays cost "+str(id))
   check(str(preview.error)=="insufficient_materials" and p.commands.commit_button.disabled,"actual materials insufficient, blocked payment "+str(id))
  snapshots.append({"label":"actual-modernization-quote","id":id,"preview":preview,"request":request,"quote_label":p.commands.quote_label.text,"materials":before.materials.duplicate(true),"disabled":p.commands.commit_button.disabled})
  await capture("quote-"+str(id).replace(":","-"))
  await click(p.section_buttons[1],"native warehouse next")
 await click(button_named(p.sections[1],p.t("totals_manage")),"native actual equipped totals")
 check(p.commands.totals_dialog.visible,"actual totals dialog")
 var totals=g.hyperspace_totals()
 check(is_equal_approx(float(totals.hangings.get("resource_collector",0)),0.2),"actual two equipped level1 collectors sum20percent; warehouse copy excluded")
 await capture("totals-actual-level-one")
 await click(p.commands.totals_dialog.get_ok_button(),"native close totals")
 await click(button_named(p.sections[1],p.t("module_manage")),"native actual module progression")
 check(int(before.hanging_modules.resource_collector.level)==1 and before.hanging_modules.keys().filter(func(k):return k!="resource_collector").all(func(k):return int(before.hanging_modules[k].level)==0),"actual resource collector naturally level1; other modules remain level0")
 await capture("modules-actual-actual-progression")
 await click(p.commands.module_dialog.get_ok_button(),"native close module manager without applying")
 check(g.profile.hyperspace==before,"all native observations no forge/equip/attachment/save mutation")
 check(FileAccess.get_sha256(path)==sha,"actual combat35 snapshot original bytes unchanged")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":sha,"x1_seconds":raw.x1_seconds,"target_fingerprint":"13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d","checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots,"scope":"Read-only actual main35 COMBAT checkpoint snapshot through normal production main.tscn graphics; paused after formal load; separate from cached campaign"},"\t"))
 print("UI35_DONE failures=",checks.filter(func(c):return not c.ok).size());quit()
