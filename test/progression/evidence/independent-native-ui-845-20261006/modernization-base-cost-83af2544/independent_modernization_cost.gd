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
var folder="/tmp/modernization-ui-evidence/native"
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
 check(g.profile.hyperspace==raw.save.hyperspace,"real parent source formally loaded unchanged")
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native source unlock acknowledgement");g.paused=true
 await click(button_named(scene,"异空间"),"native hyperspace navigation")
 var specs=[{"id":"space:2:2","error":"insufficient_materials","cost":150,"material":"antiproton","target":20},{"id":"space:2:1","error":"insufficient_materials","cost":60,"material":"degenerate_matter","target":20},{"id":"space:1:2","error":"ultimate_modification_forbidden"},{"id":"space:1:3","error":"","cost":190,"material":"glueball","target":60}]
 for spec in specs:
  var id=str(spec.id)
  await click(p.section_buttons[1],"native warehouse "+id)
  while p.page>0:await click(p.previous,"native page back")
  var card=null
  for _page in 12:
   for b in p.cards:
    if str(b.get_meta("drone_id",""))==id:card=b;break
   if card!=null:break
   if p.next.disabled:break
   await click(p.next,"native next actual page")
  check(card!=null,"actual card found "+id)
  if card==null:continue
  await click(card,"native select "+id);await click(p.section_buttons[2],"native forge "+id)
  await choose(p.commands.operation,9,"native modernization "+id)
  var before=g.profile.hyperspace.duplicate(true);var old=before.inventory.drones[id].duplicate(true)
  await click(button_named(p.sections[2],p.t("quote")),"native actual new quote "+id)
  var request=p.commands.quoted_request.duplicate(true);var preview=g.hyperspace.preview_forge(g,request)
  check(g.profile.hyperspace==before,"new quote read-only "+id)
  check(str(preview.error)==str(spec.error),"expected actual availability or ultimate restriction "+id+" "+str(preview.error))
  if spec.has("cost"):
   check(int(request.args.target_level)==int(spec.target),"target from actual route history "+id)
   check(int(preview.get("cost",{}).get(spec.material,-1))==int(spec.cost),"coefficient+1 actual amount "+id)
   check(p.commands.quote_label.text.contains(str(spec.cost)),"native quote displays actual amount "+id)
  await capture(id.replace(":","-")+"-new-quote",id,preview)
  if not str(spec.error).is_empty():
   check(p.commands.commit_button.disabled,"blocked native payment "+id)
   await click(p.commands.commit_button,"native blocked commit "+id)
   check(g.profile.hyperspace==before,"blocked quote no debit no mutation "+id)
  else:
   check(not p.commands.commit_button.disabled,"real white drone new payment enabled")
   await click(p.commands.commit_button,"native pay actual nonzero white modernization")
   var after=g.profile.hyperspace
   check(int(before.materials.glueball)==263 and int(after.materials.glueball)==73,"actual glueball263→73 debit190")
   check(int(after.inventory.drones[id].level)==60 and int(after.inventory.drones[id].forge_revision)==int(old.forge_revision)+1,"actual white15→60 one revision")
   check(after.inventory.drones[id].affixes==old.affixes and after.inventory.drones[id].forge_rng_state==old.forge_rng_state,"no affix or random state reroll")
   check(after.ultimate_cores==before.ultimate_cores and after.history==before.history and after.materials.antiproton==before.materials.antiproton and after.materials.degenerate_matter==before.materials.degenerate_matter,"unrelated materials cores histories unchanged")
   var expected=before.inventory.drones.duplicate(true);expected[id]=after.inventory.drones[id].duplicate(true)
   check(after.inventory.drones==expected,"unrelated real drones unchanged")
   var paid=after.duplicate(true)
   await click(p.commands.commit_button,"native repeat disabled paid quote")
   check(g.profile.hyperspace==paid,"repeat UI cannot debit again")
   var replay=g.hyperspace.forge(g,request)
   check(str(replay.error).is_empty() and int(replay.cost.glueball)==190 and g.profile.hyperspace==paid,"exact original request returns cached190 receipt no debit")
   check(p.commands.feedback.text.contains("190"),"success native feedback shows actual190 spent")
   await capture("white-paid-190",id,replay)
   FileAccess.open(folder+"/actual-after-paid-checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify({"save":g.portable_save_data(),"rng_state":str(g.rng.state)},"\t"))
 check(FileAccess.get_sha256(path)==sha,"parent real source bytes unchanged")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"83af25441ed34979ef530f5dfece62599d66f6c8","source_sha":sha,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"))
 print("MODERNIZATION_NATIVE failures=",checks.filter(func(c):return not c.ok).size());quit()
