extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/modernization-ui-evidence/sources/save_periodic_185401.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/modernization-restore-evidence/native"
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

func capture(label:String,id:String,preview:Dictionary):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var h=g.profile.hyperspace
 var data={"label":label,"id":id,"drone":h.inventory.drones[id].duplicate(true),"preview":preview,"quote":p.commands.quote_label.text,"feedback":p.commands.feedback.text,"request":p.commands.quoted_request.duplicate(true),"disabled":p.commands.commit_button.disabled,"materials":h.materials.duplicate(true),"cores":h.ultimate_cores,"command_seq":h.command_seq,"last_command":h.last_command.duplicate(true)}
 snapshots.append(data);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var path="/tmp/modernization-ui-evidence/sources/save_periodic_185401.json";var sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state))
 check(g.profile.hyperspace==raw.save.hyperspace,"real original two-core source unchanged")
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native source acknowledge");g.paused=true
 await click(button_named(scene,"异空间"),"native hyperspace")
 await click(p.section_buttons[1],"native warehouse")
 var card=null
 for _page in 12:
  for b in p.cards:
   if str(b.get_meta("drone_id",""))=="space:1:2":card=b;break
  if card!=null:break
  if p.next.disabled:break
  await click(p.next,"native next actual page")
 check(card!=null,"actual ultimate white pulse card")
 if card==null:quit(1);return
 await click(card,"native actual ultimate");await click(p.section_buttons[2],"native forge")
 await choose(p.commands.operation,11,"native restore ultimate")
 var before=g.profile.hyperspace.duplicate(true)
 await click(button_named(p.sections[2],p.t("quote")),"native restore quote")
 var request=p.commands.quoted_request.duplicate(true);var preview=g.hyperspace.preview_forge(g,request)
 check(str(preview.error).is_empty() and int(preview.cost.ultimate_cores)==1,"actual restore costs one core")
 check(g.profile.hyperspace==before,"restore quote read-only")
 await capture("01-real-restore-quote","space:1:2",preview)
 await click(p.commands.commit_button,"native actual restore pay one core")
 var restored=g.profile.hyperspace.duplicate(true)
 check(int(restored.ultimate_cores)==1 and not restored.inventory.drones["space:1:2"].ultimate,"actual cores2→1 and ultimate removed")
 check(restored.materials==before.materials and restored.inventory.drones["space:1:2"].ultimate_affix==before.inventory.drones["space:1:2"].ultimate_affix,"restore preserves material and original extra affix")
 await capture("02-real-restored-one-core-spent","space:1:2",{})
 await choose(p.commands.operation,9,"native restored modernization")
 await click(button_named(p.sections[2],p.t("quote")),"native restored new modernize quote")
 request=p.commands.quoted_request.duplicate(true);preview=g.hyperspace.preview_forge(g,request)
 check(int(request.args.target_level)==20 and int(preview.cost.degenerate_matter)==60 and int(g.profile.hyperspace.materials.degenerate_matter)==4,"restored actual alpha20 cost60 has4")
 check(str(preview.error)=="insufficient_materials" and p.commands.commit_button.disabled,"restored modernization blocked without new funds")
 await click(p.commands.commit_button,"native blocked restored commit")
 check(g.profile.hyperspace==restored,"failed modernization no refund of already spent core no new debit")
 check(int(g.profile.hyperspace.ultimate_cores)==1 and int(g.profile.hyperspace.inventory.drones["space:1:2"].level)==10,"real opportunity cost remains one core and normal level10")
 await capture("03-restored-modernization-insufficient60-have4","space:1:2",preview)
 FileAccess.open(folder+"/actual-after-restore-blocked-checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify({"save":g.portable_save_data(),"rng_state":str(g.rng.state)},"\t"))
 check(FileAccess.get_sha256(path)==sha,"parent source bytes unchanged")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"83af25441ed34979ef530f5dfece62599d66f6c8","source_sha":sha,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"))
 print("RESTORE_INSUFFICIENT failures=",checks.filter(func(c):return not c.ok).size());quit()
