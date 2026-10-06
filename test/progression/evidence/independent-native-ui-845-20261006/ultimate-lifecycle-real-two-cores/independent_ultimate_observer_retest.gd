extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/ultimate-chain-evidence/native/04-reultimate-checkpoint.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/ultimate-chain-evidence/native"
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
func reload_actual(path:String):
 var raw=JSON.parse_string(FileAccess.get_file_as_string(path));var saved=raw.save.duplicate(true)
 saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
 g.load_progress_data(saved);g.profile.chronoParticles=float(raw.save.chronoParticles);g.login_chrono_particles=0;g.resume_progress();g.paused=true;g.load_hyperspace_routes();g.rng.state=int(str(raw.rng_state));p.dirty=true;p.refresh()
 return raw
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene;g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var baseline="/tmp/ultimate-chain-evidence/native/"
 var audit=JSON.parse_string(FileAccess.get_file_as_string(baseline+"audit.json"))
 var input_paths=[]
 var source_sha=FileAccess.get_sha256("/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json")
 for op in ["02-restore","03-modernize","04-reultimate"]:
  var path=baseline+op+"-checkpoint.json";input_paths.append({"path":path,"sha":FileAccess.get_sha256(path)})
  var raw=reload_actual(path);var expected=normalized(raw.save.hyperspace);var actual=normalized(g.profile.hyperspace)
  check(actual==expected,op+" exact semantic full namespace preserved after actual paid save formal reload")
  var quote={}
  for snap in audit.snapshots:
   if snap.label==op+"-quote":quote=snap.request
  var replay=g.hyperspace.forge(g,quote)
  check(str(replay.error).is_empty() and normalized(g.profile.hyperspace)==expected,op+" actual saved receipt duplicate returns cached result no second debit")
  snapshots.append({"op":op,"before":expected,"after":normalized(g.profile.hyperspace),"replay":replay,"quote_request":quote})
 var originals=["/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json",baseline+"02-restore-checkpoint.json",baseline+"03-modernize-checkpoint.json"]
 var operations=["02-restore","03-modernize","04-reultimate"]
 var costs=[{"ultimate_cores":1},{"degenerate_matter":0},{"ultimate_cores":1}]
 for i in 3:
  reload_actual(originals[i]);var quote={}
  for snap in audit.snapshots:
   if snap.label==operations[i]+"-quote":quote=snap.request
  var before=normalized(g.profile.hyperspace);var preview=g.hyperspace.preview_forge(g,quote)
  check(str(preview.error).is_empty() and normalized(preview.cost)==normalized(costs[i]),operations[i]+" read-only actual prepayment source quote numeric cost verified")
  check(normalized(g.profile.hyperspace)==before,operations[i]+" directed quote retest unchanged actual source state")
 var final_raw=reload_actual(baseline+"04-reultimate-checkpoint.json")
 await click(button_named(scene,"异空间"),"native final actual paid checkpoint recovered")
 await click(p.section_buttons[1],"native final recovered actual warehouse")
 for b in p.cards:
  if str(b.get_meta("drone_id",""))=="space:1:2":await click(b,"native final restored upgraded ultimate card");break
 await click(p.section_buttons[2],"native final upgraded ultimate forge detail")
 await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/final-actual-checkpoint-restored-screen.png")
 check(int(g.profile.hyperspace.ultimate_cores)==0 and g.profile.hyperspace.inventory.drones["space:1:2"]==final_raw.save.hyperspace.inventory.drones["space:1:2"],"final actual restored paid ultimate level20 zero cores unchanged")
 for item in input_paths:check(FileAccess.get_sha256(item.path)==item.sha,"actual paid checkpoint unchanged "+str(item.path).get_file())
 check(FileAccess.get_sha256("/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json")==source_sha,"parent source unchanged through observer-only retest")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Only exact previous failed numeric cost and serialized reload observer checks; no paid commit repeated","checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"));print("ULTIMATE_OBSERVER_RETEST failures=",checks.filter(func(c):return not c.ok).size());quit()
