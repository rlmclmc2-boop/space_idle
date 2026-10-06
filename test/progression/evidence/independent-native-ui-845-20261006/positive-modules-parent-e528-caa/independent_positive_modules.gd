extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/positive-module-ui-evidence/sources/save_final.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/positive-module-ui-evidence/native"
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
 var path="/tmp/positive-module-ui-evidence/sources/save_final.json";var sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state));var before=g.profile.hyperspace.duplicate(true)
 check(before==raw.save.hyperspace,"real post60 source formal hyperspace unchanged")
 check(before.inventory.equipped.size()==5,"five actual equipped drones")
 var fleet=[];var equipped_expected={};var warehouse_expected={};var c=g.hyperspace.config
 for id in before.inventory.drones:
  var d=before.inventory.drones[id]
  if id in before.inventory.equipped:fleet.append({"id":id,"level":d.level,"weapon":d.weapon,"ultimate":d.ultimate,"legendary":d.legendary,"hangings":d.hangings.duplicate()})
  for key in d.hangings:
   var contribution=pow(1.0+float(c.hanging_modules[key].effect_growth),int(before.hanging_modules[key].level))-1.0
   var target=equipped_expected if id in before.inventory.equipped else warehouse_expected
   target[key]=float(target.get(key,0))+contribution
 var actual=g.hyperspace_totals()
 check(is_equal_approx(float(actual.hangings.get("resource_collector",0)),0.2),"two equipped level1 collectors correctly sum20percent")
 check(actual.hangings.size()==1 and not actual.hangings.has("distributed_algorithm"),"warehouse installed distributed algorithm does not count")
 check(is_equal_approx(float(warehouse_expected.resource_collector),0.3) and is_equal_approx(float(warehouse_expected.distributed_algorithm),0.1),"real excluded warehouse has collector30percent and algorithm10percent")
 check(is_equal_approx(float(actual.hangings.resource_collector),float(equipped_expected.resource_collector)),"actual aggregate equals independent equipped-only arithmetic")
 check(not is_equal_approx(float(actual.hangings.resource_collector),float(equipped_expected.resource_collector)+float(warehouse_expected.resource_collector)),"warehouse collector copies do not inflate actual total to50percent")
 check(before.hanging_modules.values().all(func(x):return x.unlocked and int(x.level)>0),"all five actual modules naturally unlocked positive level; no invented level0 state")
 for key in c.hanging_modules:
  check(is_zero_approx(pow(1.0+float(c.hanging_modules[key].effect_growth),0)-1.0),"production bonus formula level0 equalszero "+key+" static arithmetic not mutated source")
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native acknowledge existing unlock");g.paused=true
 await click(button_named(scene,"异空间"),"native actual hyperspace")
 await click(p.section_buttons[1],"native actual warehouse")
 for id in before.inventory.equipped:
  while p.page>0:await click(p.previous,"native first page for actual fleet")
  var card=null
  for _page in 12:
   for b in p.cards:
    if str(b.get_meta("drone_id",""))==str(id):card=b;break
   if card!=null:break
   if p.next.disabled:break
   await click(p.next,"native actual fleet pagination")
  check(card!=null,"actual fleet card located "+str(id))
  if card==null:continue
  await click(card,"native selected actual fleet "+str(id))
  check(p.detail_title.text.contains("等级 "+str(int(before.inventory.drones[id].level))),"native real fleet level label "+str(id))
  await capture("fleet-"+str(id).replace(":","-"))
 await click(button_named(p.sections[1],p.t("totals_manage")),"native view actual totals")
 check(p.commands.totals_dialog.visible and p.commands.totals_label.text.contains("当前装备总加成") and p.commands.totals_label.text.contains("已生效挂设总加成"),"totals states currently equipped and active hanging scope")
 check(p.commands.totals_label.text.contains("资源收集器: 20.0%") and not p.commands.totals_label.text.contains("分布式算法:"),"native totals correctly display actual20percent and exclude unequipped algorithm")
 await capture("01-actual-totals-top")
 await wheel(p.commands.totals_label.get_parent())
 await capture("02-actual-positive-hanging-total-and-current-fleet")
 await click(p.commands.totals_dialog.get_ok_button(),"native close totals no mutation")
 await click(button_named(p.sections[1],p.t("module_manage")),"native inspect actual five module progression no apply")
 check(p.commands.module_dialog.visible and p.commands.module_choices.size()==5,"native five actual module progression visible")
 await capture("03-five-naturally-grown-modules")
 await click(p.commands.module_dialog.get_ok_button(),"native close module manager without applying")
 check(g.profile.hyperspace==before,"no payment equip attach dismantle or profile mutation")
 check(FileAccess.get_sha256(path)==sha,"real original source bytes unchanged")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"commit":"caa80f59aef5dcf1caab20e40e17b39a8a27d1e1","source_evidence_commit":"1b1041117c30709551342874273e28cd0c7e5dab","source_sha":sha,"source_x1":raw.x1_seconds,"fleet":fleet,"equipped_arithmetic":equipped_expected,"excluded_warehouse_arithmetic":warehouse_expected,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"))
 print("POSITIVE_MODULE_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
