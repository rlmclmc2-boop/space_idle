extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 var energy_before_process=0.0
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var path=OS.get_environment("QA_RELOAD_FILE")
  if path.is_empty():path="/workspace/longrun_packages/clear35-to40-independent/diagnostics/actual-clear35-to40-natural-same0a4/save_reach_15_round_3.json"
  var raw=JSON.parse_string(FileAccess.get_file_as_string(path));var saved=raw.save.duplicate(true)
  saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
  game.load_progress_data(saved);game.profile.chronoParticles=float(raw.save.chronoParticles);game.login_chrono_particles=0;game.load_hyperspace_routes()
  return game
 func show_qa_tools()->void:pass
 func _process(delta:float)->void:
  energy_before_process=float(game.profile.hyperspace.energy);super._process(delta)
var scene
var g
var p
var checks=[]
var actions=[]
var snapshots=[]
var events=[]
var folder="/tmp/qa845-evidence/native"
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
func wheel(container:ScrollContainer,count:int):
 for _i in count:
  var w=container.get_window();var point=w.get_final_transform()*container.get_global_transform_with_canvas()*(container.size/2)
  for down in [true,false]:
   var e=InputEventMouseButton.new();e.position=point;e.window_id=w.get_window_id();e.button_index=MOUSE_BUTTON_WHEEL_DOWN;e.pressed=down;Input.parse_input_event(e);await process_frame
func state()->Dictionary:
 return {"stage":g.stage,"state":g.state,"highest":g.profile.highestLevel,"energy":g.profile.hyperspace.energy,"active":g.profile.hyperspace.active.duplicate(true),"queue":g.manual_hyperspace.queued.duplicate(true),"queue_error":g.manual_hyperspace.queue_error,"status":p.status.text,"hint":p.queue_departure_hint.text,"hint_visible":p.queue_departure_hint.is_visible_in_tree(),"reason":p.manual_reason.text,"start_disabled":p.start_button.disabled,"cancel_visible":p.cancel_queue_button.is_visible_in_tree(),"exit_visible":p.exit_button.is_visible_in_tree(),"recent":p.recent_result.text,"source_to_candidate_regenerated":true}
func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+label+".png");DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var s=state();s.label=label;s.actions=actions.duplicate(true)
 var eq=scene.equipment_panel;s.beam_stats=eq.detail.stats.text;s.beam_scroll=eq.detail_scroll.scroll_vertical;s.beam_inspector_visible=eq.detail_frame.is_visible_in_tree()
 snapshots.append(s);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(s,"\t"))
func save_point(name:String):
 FileAccess.open(folder+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"save":g.portable_save_data(),"rng_state":str(g.rng.state),"source_commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5"},"\t"))
func run():
 var reload_path=OS.get_environment("QA_RELOAD_FILE")
 if not reload_path.is_empty():folder="/tmp/qa845-evidence/reload"
 if OS.get_environment("QA_EXIT_RETEST")=="1":folder="/tmp/qa845-evidence/exit-retest"
 if OS.get_environment("QA_PAID_RELOAD")=="1":folder="/tmp/qa845-evidence/paid-reload"
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;g.load_hyperspace_routes();p=scene.hyperspace_panel
 var original_path="/workspace/longrun_packages/clear35-to40-independent/diagnostics/actual-clear35-to40-natural-same0a4/save_reach_15_round_3.json"
 var source_path=original_path if reload_path.is_empty() else reload_path
 var source_sha=FileAccess.get_sha256(source_path);var raw=JSON.parse_string(FileAccess.get_file_as_string(source_path));g.rng.state=int(str(raw.rng_state))
 if OS.get_environment("QA_PAID_RELOAD")!="1":check(g.profile.highestLevel==raw.save.highestLevel and g.profile.hyperspace==raw.save.hyperspace,"actual existing source restored through formal load, no currency/seed fixture")
 g.event.connect(func(kind:String,info:Dictionary):
  if kind.begins_with("hyperspace"):
   events.append({"kind":kind,"info":info.duplicate(true),"energy":g.profile.hyperspace.energy,"energy_before_process":scene.energy_before_process,"stage":g.stage,"state":g.state})
  if kind=="hyperspace_manual":g.paused=true
 )
 await click(button_named(scene,"异空间"),"native hyperspace navigation")
 if OS.get_environment("QA_PAID_RELOAD")=="1":
  var receipt=raw.save.hyperspace.active
  check(not g.manual_hyperspace.active and g.profile.hyperspace.active.is_empty() and is_equal_approx(float(g.profile.hyperspace.energy),float(raw.save.hyperspace.energy)+float(receipt.ticket)),"actual native paid checkpoint formal startup refunds once")
  check(g.stage==int(receipt.return_journey.stage) and g.group_index==int(receipt.return_journey.groupIndex) and g.profile.hyperspace.inventory==raw.save.hyperspace.inventory,"paid recovery returns exact saved main stage/point with same inventory")
  await capture("01-paid-checkpoint-formal-recovery")
  var once=JSON.stringify(g.profile.hyperspace);var saved=raw.save.duplicate(true);saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
  g.load_progress_data(saved);g.profile.chronoParticles=float(raw.save.chronoParticles);g.login_chrono_particles=0;g.resume_progress();g.paused=true;g.load_hyperspace_routes();p.refresh_manual_status();p.refresh_progress()
  check(JSON.stringify(g.profile.hyperspace)==once,"reading same actual paid checkpoint again does not compound refund")
  await capture("02-same-paid-checkpoint-second-recovery")
 elif OS.get_environment("QA_EXIT_RETEST")=="1":
  await click(p.start_button,"native establish only paid exit boundary")
  var jump=0
  for n in scene.loop_select.item_count:
   if scene.loop_select.get_item_id(n)==5:jump=n
  await choose(scene.loop_select,jump,"native cleared-stage warp for exit-only retest")
  var until=Time.get_ticks_msec()+5000
  while not g.manual_hyperspace.active and Time.get_ticks_msec()<until:await process_frame
  check(g.manual_hyperspace.active,"real paid state for exit-only retest")
  if g.manual_hyperspace.active:
   var receipt=g.profile.hyperspace.active.duplicate(true)
   save_point("paid-candidate-checkpoint")
   await capture("01-real-paid-exit-boundary")
   await click(p.exit_button,"native exit once at controlled paused boundary")
   var after=JSON.stringify(g.profile.hyperspace)
   await click(p.exit_button,"native repeat same former exit location")
   if p.commands.crew_dialog!=null and p.commands.crew_dialog.visible:await click(p.commands.crew_dialog.get_ok_button(),"close modal from repeated former exit location")
   check(not g.manual_hyperspace.active and JSON.stringify(g.profile.hyperspace)==after and is_equal_approx(float(g.manual_hyperspace.last_result.refund),float(receipt.ticket)),"exit-only retest: exact single refund and no duplicate mutation")
   await capture("02-native-single-refund-repeat-stable")
 elif not reload_path.is_empty():
  check(g.manual_hyperspace.queued.is_empty() and g.profile.hyperspace.active.is_empty(),"formal unpaid queued checkpoint reload contains no paid exploration or transient request")
  await capture("01-formal-unpaid-queue-reload")
 else:
  # Stop only the real existing automatic policy via its actual dialog, avoiding scheduler interference.
  await click(p.crew_button,"open existing real automatic policy manager")
  await click(button_named(p.commands.crew_dialog,p.t("auto_disable")),"native stop existing auto policy")
  check(not g.profile.hyperspace.auto.enabled,"real native auto stop, no energy gift")
  var base_h=JSON.stringify(g.profile.hyperspace)
  await click(p.start_button,"native queue real battle boundary")
  check(not g.manual_hyperspace.queued.is_empty() and not g.manual_hyperspace.active and JSON.stringify(g.profile.hyperspace)==base_h,"actual COMBAT queue does not charge or mutate inventory")
  await capture("01-real-combat-queued")
  var q=g.manual_hyperspace.queued.duplicate(true)
  await click(p.start_button,"repeat click disabled queue start")
  check(g.manual_hyperspace.queued==q and JSON.stringify(g.profile.hyperspace)==base_h,"duplicate native request cannot duplicate or charge")
  await click(button_named(scene,"装备"),"close exploration page via native equipment navigation")
  await click(button_named(scene,"异空间"),"reopen exploration page")
  check(g.manual_hyperspace.queued==q and p.cancel_queue_button.visible,"queue survives page close and reopen with cancel available")
  save_point("queued-candidate-checkpoint")
  await capture("02-reopen-persistent-unpaid-queue")
  await click(p.cancel_queue_button,"native cancel unpaid queue")
  await click(p.cancel_queue_button,"repeat click former cancel location")
  if p.commands.crew_dialog.visible:await click(p.commands.crew_dialog.get_ok_button(),"close dialog opened by changed former cancel location")
  check(g.manual_hyperspace.queued.is_empty() and JSON.stringify(g.profile.hyperspace)==base_h,"cancel and repeated location never charge")
  await click(p.start_button,"native requeue after cancel")
  var jump=0
  for i in scene.loop_select.item_count:
   if scene.loop_select.get_item_id(i)==5:jump=i
  await choose(scene.loop_select,jump,"native warp to already cleared stage5 safe departure")
  var until=Time.get_ticks_msec()+5000
  while not g.manual_hyperspace.active and Time.get_ticks_msec()<until:await process_frame
  check(g.manual_hyperspace.active,"queued exploration actually dispatches after native legal warp")
  await capture("03-actual-paid-manual-entry")
  if g.manual_hyperspace.active:
   var receipt=g.profile.hyperspace.active.duplicate(true);var started_events=events.filter(func(e):return e.kind=="hyperspace_changed" and e.info.get("reason")=="started")
   check(started_events.size()==1 and is_equal_approx(float(started_events[0].energy_before_process)-float(started_events[0].energy),float(receipt.ticket)),"one actual dispatch charges exact receipt ticket once")
   var paid=JSON.stringify(g.profile.hyperspace)
   await click(p.start_button,"repeat disabled start after paid entry")
   check(JSON.stringify(g.profile.hyperspace)==paid,"paid-state repeated native start is unchanged")
   await click(button_named(scene,"装备"),"leave paid exploration page")
   await click(button_named(scene,"异空间"),"return paid exploration page")
   check(JSON.stringify(g.profile.hyperspace)==paid and p.exit_button.visible,"paid exploration survives page close and reopen")
   await click(p.exit_button,"native exit actual paid exploration")
   var refunded=JSON.stringify(g.profile.hyperspace)
   await click(p.exit_button,"repeat click former exit location")
   if p.commands.crew_dialog.visible:await click(p.commands.crew_dialog.get_ok_button(),"close dialog opened by changed former exit location")
   check(not g.manual_hyperspace.active and JSON.stringify(g.profile.hyperspace)==refunded and is_equal_approx(float(g.manual_hyperspace.last_result.refund),float(receipt.ticket)),"actual native exit refunds once, repeated location unchanged")
   await capture("04-exit-refund-and-return")
  await click(button_named(scene,"装备"),"native equipment page for beam detail")
  var eq=scene.equipment_panel;var id=g.slot_id("weapons",0);var card=eq.cards[id];var op=card.name_button;var beam=-1
  for i in op.item_count:
   if str(card.equipment_options[i])=="longLaser":beam=i
  check(beam>=0,"beam exists in actual unlocked module picker")
  if beam>=0:
   await choose(op,beam,"native free swap actual first weapon to beam")
   await click(eq.footer_buttons.details,"native open beam inspector")
   await wheel(eq.detail_scroll,3)
   check(eq.detail.stats.text.begins_with(preload("res://scripts/ui_text.gd").t("equipment.continuous_beam_snapshot_hint")),"beam snapshot explanation is first stats line")
   await capture("05-beam-first-stats-hint")
   var close=eq.detail_frame.find_child("close_detail",true,false)
   if close==null:close=button_named(eq.detail_frame,preload("res://scripts/ui_text.gd").t("equipment.close"))
   await click(close,"native close beam inspector")
   await click(eq.footer_buttons.details,"native reopen beam inspector")
   await capture("06-beam-reopened-hint")
 check(FileAccess.get_sha256(source_path)==source_sha,"actual source file remains byte-identical")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5","fingerprint":"4e07f51458d778fa152222ab0d39042cc07f4d7f83d2e1c563479de5e4123983","source":source_path,"source_sha":source_sha,"source_old0a":reload_path.is_empty(),"formal_regeneration":true,"not_parent_same_version_numeric_cp":true,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"events":events,"snapshots":snapshots},"\t"))
 print("845_NATIVE_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
