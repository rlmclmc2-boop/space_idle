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
var folder="/tmp/dismantle-feedback-evidence/native"
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
var events=[]
var before_h={}
var candidate="space:1:3"
var recipient="space:6:8"
func normalized(value):return JSON.parse_string(JSON.stringify(value))
func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var d={"label":label,"selected":p.selected_id,"quote":p.commands.quote_label.text,"feedback":p.commands.feedback.text,"request":p.commands.quoted_request.duplicate(true),"confirm_text":p.commands.dismantle_dialog.dialog_text if p.commands.dismantle_dialog!=null else "","modules":g.profile.hyperspace.hanging_modules.duplicate(true),"materials":g.profile.hyperspace.materials.duplicate(true),"warehouse":g.profile.hyperspace.inventory.warehouse.duplicate(),"core":g.profile.hyperspace.ultimate_cores}
 snapshots.append(d);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(d,"\t"))
func select_card(id:String)->bool:
 await click(p.section_buttons[1],"native warehouse for actual "+id)
 while p.page>0:await click(p.previous,"native return warehouse first page")
 for _page in 12:
  for b in p.cards:
   if str(b.get_meta("drone_id",""))==id:await click(b,"native select actual "+id);return true
  if p.next.disabled:break
  await click(p.next,"native actual warehouse next")
 return false
func savepoint(label:String):
 FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"save":g.portable_save_data(),"rng_state":str(g.rng.state),"source_commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5"},"\t"))
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene;g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var source_path="/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json";var source_sha=FileAccess.get_sha256(source_path);var raw=JSON.parse_string(FileAccess.get_file_as_string(source_path));g.rng.state=int(str(raw.rng_state));before_h=g.profile.hyperspace.duplicate(true)
 check(normalized(before_h)==normalized(raw.save.hyperspace) and before_h.hanging_modules.values().all(func(v):return not v.unlocked and int(v.level)==0),"actual original full-locked natural source preserved at start")
 var bag=before_h.inventory;var Bag=preload("res://scripts/drone_inventory.gd")
 check(bag.drones.has(candidate) and not Bag.protected(bag,candidate) and not bag.sealed.has(candidate),"actual surplus white15 candidate unprotected unequipped unpresetted unsealed")
 check(bag.drones[recipient].hanging_slots>=1 and not bag.drones[recipient].ultimate and bag.equipped.has(recipient),"actual equipped nonultimate recipient has existing free slot")
 g.event.connect(func(kind:String,info:Dictionary):
  if kind=="hyperspace_changed":events.append({"kind":kind,"info":info.duplicate(true),"modules":g.profile.hyperspace.hanging_modules.duplicate(true),"materials":g.profile.hyperspace.materials.duplicate(true)})
 )
 await click(button_named(scene,"异空间"),"native real source hyperspace")
 check(await select_card(candidate),"actual surplus candidate card found")
 await click(p.section_buttons[2],"native actual dismantle forge")
 await choose(p.commands.operation,12,"native dismantle operation")
 var rng_before=str(g.rng.state);var state_before=normalized(g.profile.hyperspace)
 await click(button_named(p.sections[2],p.t("quote")),"native actual dismantle quote")
 check(normalized(g.profile.hyperspace)==state_before and str(g.rng.state)==rng_before,"actual dismantle quote read-only no reward injection")
 check(p.commands.dismantle_hint.is_visible_in_tree() and p.commands.dismantle_hint.text.contains("首次副本") and p.commands.dismantle_hint.text.contains("0级"),"actual source hint explains first copy unlock at0 and later experience")
 check(p.commands.quote_label.text.contains("胶球 ×1") and p.commands.quote_label.text.contains("随机挂设副本 1 份"),"real preview shows fixed material amount and random copy count")
 check(g.hyperspace.config.hanging_modules.keys().all(func(key):return not p.commands.quote_label.text.contains(p.hanging_name(key))),"quote does not reveal or assume random module name")
 var actual_request=p.commands.quoted_request.duplicate(true)
 await capture("01-real-dismantle-quote-before-reward")
 await click(p.commands.commit_button,"native dismantle opens confirmation")
 check(p.commands.dismantle_dialog.visible and normalized(g.profile.hyperspace)==state_before,"confirmation before irreversible removal keeps original state")
 await capture("02-real-dismantle-confirmation")
 await click(p.commands.dismantle_dialog.get_ok_button(),"native confirm one surplus white dismantle")
 var h=g.profile.hyperspace;var unlocked=[]
 for key in h.hanging_modules:
  if not before_h.hanging_modules[key].unlocked and h.hanging_modules[key].unlocked:unlocked.append(key)
 check(not h.inventory.drones.has(candidate) and h.inventory.warehouse.size()==bag.warehouse.size()-1,"one real surplus drone removed exactly once")
 check(unlocked.size()==1 and int(h.materials.glueball)==int(before_h.materials.glueball)+1,"white dismantle actual one module unlock and one missile material")
 for key in unlocked:check(int(h.hanging_modules[key].level)==0 and float(h.hanging_modules[key].exp)==0,"first actual copy unlocks level0 with zero exp "+str(key))
 check(h.ultimate_cores==before_h.ultimate_cores and h.inventory.equipped==bag.equipped and h.inventory.favorites==bag.favorites and h.inventory.presets==bag.presets and h.inventory.sealed==bag.sealed,"protected fleet favorites presets sealed cores unchanged")
 var remaining=bag.drones.duplicate(true);remaining.erase(candidate)
 check(h.inventory.drones==remaining,"all other actual drones unchanged by dismantle")
 savepoint("actual-after-one-dismantle-checkpoint")
 check(p.commands.quote_label.text.contains("实际收到：胶球 ×1") and p.commands.quote_label.text.contains(p.hanging_name(unlocked[0])+" ×1") and p.commands.quote_label.text.contains("首次解锁，当前等级 0；获得经验 0"),"paid actual reward text names received material and first real module outcome")
 var received=JSON.parse_string(g.profile.hyperspace.last_command.result_json).rewards
 check(int(received.materials.glueball)==1 and int(received.modules[unlocked[0]].copies)==1 and bool(received.modules[unlocked[0]].newly_unlocked),"committed receipt retains actual reward quantities and unlock state")
 var paid_state=normalized(g.profile.hyperspace)
 await click(p.commands.commit_button,"native repeat disabled actual dismantle result button")
 check(normalized(g.profile.hyperspace)==paid_state,"repeat native commit cannot duplicate actual reward")
 var replay=g.hyperspace.forge(g,actual_request)
 check(str(replay.error).is_empty() and normalized(replay.rewards)==normalized(received) and normalized(g.profile.hyperspace)==paid_state,"same exact receipt returns same actual display rewards without recredit")
 var protected_request=actual_request.duplicate(true);protected_request.drone_id=recipient;protected_request.expected_revision=g.profile.hyperspace.inventory.drones[recipient].forge_revision
 var protected_preview=g.hyperspace.preview_forge(g,protected_request)
 check(str(protected_preview.error)=="protected_drone" and normalized(g.profile.hyperspace)==paid_state,"protected actual equipped favorite preset drone still rejected read-only")
 await capture("03-real-dismantle-result-and-unlock")
 if unlocked.size()==1:
  check(await select_card(recipient),"actual existing recipient selected")
  await click(button_named(p.sections[1],p.t("module_manage")),"native earned module manager")
  var choice=null
  for n in p.commands.module_choices:
   if str(n.get_meta("module_key"))==str(unlocked[0]):choice=n
  check(choice!=null and not choice.disabled,"actual earned first module selectable under real level gate")
  var source_hint_found=false
  for n in p.commands.module_dialog.find_children("*","Label",true,false):
   if n.text.contains("首次解锁为0级") and n.text.contains("后续副本"):source_hint_found=true
  check(source_hint_found,"actual module dialog persistently explains dismantle source and progression")
  await capture("04-real-first-module-unlocked-level0")
  if choice!=null and not choice.disabled:
   await click(choice,"native equip actually earned hanging")
   await click(button_named(p.commands.module_dialog,p.t("module_apply")),"native apply actual earned hanging")
   check(g.profile.hyperspace.inventory.drones[recipient].hangings==unlocked,"actual unlocked module attached without new resources")
   var totals=g.hyperspace_totals()
   check(totals.hangings.has(unlocked[0]) and is_zero_approx(float(totals.hangings[unlocked[0]])),"first-copy level0 real aggregate bonus is zero not claimed as positive gain")
   FileAccess.open(folder+"/actual-module-totals.json",FileAccess.WRITE).store_string(JSON.stringify(totals,"\t"))
   savepoint("actual-after-earned-hanging-checkpoint")
   await capture("05-real-first-module-equipped")
 check(FileAccess.get_sha256(source_path)==source_sha,"parent original full-locked source byte-identical")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"commit":"f8744214","source_sha":source_sha,"scope":"One actual surplus dismantle and earned hanging attachment in isolated source; original all-locked natural history retained separately","candidate_before":bag.drones[candidate],"recipient_before":bag.drones[recipient],"source_warehouse":bag.warehouse.size(),"unlocked":unlocked,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"events":events,"snapshots":snapshots},"\t"));print("DISMANTLE_FEEDBACK_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
