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
var events=[]
var target=0
var original_drone={}
func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var h=g.profile.hyperspace
 var d={"label":label,"core":h.ultimate_cores,"materials":h.materials.duplicate(true),"target":target,"drone":h.inventory.drones["space:1:2"].duplicate(true),"inventory":h.inventory.duplicate(true),"quote":p.commands.quote_label.text,"feedback":p.commands.feedback.text,"request":p.commands.quoted_request.duplicate(true),"commit_disabled":p.commands.commit_button.disabled,"command_seq":h.command_seq,"last_command":h.last_command.duplicate(true)}
 snapshots.append(d);FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(d,"\t"))
func save_reload(label:String,request:Dictionary):
 var before=JSON.stringify(g.profile.hyperspace);var raw={"save":g.portable_save_data(),"rng_state":str(g.rng.state),"source_commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5"}
 var path=folder+"/"+label+"-checkpoint.json";FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(raw,"\t"))
 var actual=JSON.parse_string(FileAccess.get_file_as_string(path));var saved=actual.save.duplicate(true)
 saved.chronoSavedAt=Time.get_unix_time_from_system();saved.hightechSavedAt=saved.chronoSavedAt
 g.load_progress_data(saved);g.profile.chronoParticles=float(actual.save.chronoParticles);g.login_chrono_particles=0;g.resume_progress();g.paused=true;g.load_hyperspace_routes();g.rng.state=int(str(actual.rng_state));p.dirty=true;p.refresh()
 check(JSON.stringify(g.profile.hyperspace)==before,label+" actual serialized formal reload no extra debit")
 var replay=g.hyperspace.forge(g,request)
 check(str(replay.error).is_empty() and JSON.stringify(g.profile.hyperspace)==before,label+" saved receipt formal duplicate command returns cached result without debit")
func operation(index:int,label:String,expected_cost:Dictionary,expected_core:int,expected_ultimate:bool,expected_level:int)->bool:
 await choose(p.commands.operation,index,"native "+label+" operation menu")
 var before=JSON.stringify(g.profile.hyperspace)
 await click(button_named(p.sections[2],p.t("quote")),"native "+label+" real quote")
 var request=p.commands.quoted_request.duplicate(true);var preview=g.hyperspace.preview_forge(g,request)
 check(JSON.stringify(g.profile.hyperspace)==before,label+" quote read-only")
 check(preview.cost==expected_cost,label+" actual cost matches live original configuration")
 await capture(label+"-quote")
 if not str(preview.error).is_empty() or p.commands.commit_button.disabled:
  checks.append({"ok":false,"label":label+" blocked real quote: "+str(preview.error)});return false
 await click(p.commands.commit_button,"native "+label+" commit actual quote")
 var h=g.profile.hyperspace;var drone=h.inventory.drones["space:1:2"]
 check(int(h.ultimate_cores)==expected_core and bool(drone.ultimate)==expected_ultimate and int(drone.level)==expected_level,label+" exact core ultimate level result")
 check(drone.ultimate_affix==original_drone.ultimate_affix and drone.affixes==original_drone.affixes and drone.hangings==original_drone.hangings and drone.legendary==original_drone.legendary and drone.legendary_effect==original_drone.legendary_effect and drone.hanging_slots==original_drone.hanging_slots,label+" original extra affix normal affixes hangings legendary preserved")
 var after=JSON.stringify(h)
 await click(p.commands.commit_button,"native repeat disabled "+label+" commit location")
 check(JSON.stringify(g.profile.hyperspace)==after,label+" repeat native click no duplicate cost")
 await capture(label+"-result")
 await save_reload(label,request)
 return true
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene
 g=scene.game;g.paused=true;g.save_enabled=false;p=scene.hyperspace_panel
 var path="/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json";var source_sha=FileAccess.get_sha256(path);var raw=JSON.parse_string(FileAccess.get_file_as_string(path));g.rng.state=int(str(raw.rng_state));original_drone=raw.save.hyperspace.inventory.drones["space:1:2"].duplicate(true)
 var source_inventory=raw.save.hyperspace.inventory.duplicate(true)
 check(g.profile.hyperspace==raw.save.hyperspace and int(g.profile.hyperspace.ultimate_cores)==2,"real naturally funded two-core source formal restore unchanged")
 var route=""
 for key in g.hyperspace.config.routes:
  if str(g.hyperspace.config.routes[key].weapon)==str(original_drone.weapon):route=str(key)
 for key in g.profile.hyperspace.history[route]:
  if int(key)<=int(g.profile.highestLevel):target=maxi(target,int(key))
 check(route=="alpha" and target>int(original_drone.level),"target derived from actual matching weapon route and current-round cap")
 g.event.connect(func(kind:String,info:Dictionary):
  if kind=="hyperspace_changed":events.append({"kind":kind,"info":info.duplicate(true),"core":g.profile.hyperspace.ultimate_cores,"drone":g.profile.hyperspace.inventory.drones["space:1:2"].duplicate(true)})
 )
 for _i in 4:
  if g.pending_unlocks.is_empty():break
  await click(scene.continue_button,"native acknowledge existing source unlock")
  g.paused=true
 await click(button_named(scene,"异空间"),"native actual hyperspace navigation")
 await click(p.section_buttons[1],"native real warehouse")
 var card=null
 for _page in 10:
  for b in p.cards:
   if str(b.get_meta("drone_id",""))=="space:1:2":card=b;break
  if card!=null:break
  if p.next.disabled:break
  await click(p.next,"native find actual equipped ultimate card")
 check(card!=null,"actual space:1:2 card available")
 if card==null:finish(source_sha);return
 await click(card,"native actual white ultimate space:1:2")
 await click(p.section_buttons[2],"native actual forge")
 await capture("01-actual-white-ultimate-source")
 var allowed=await operation(11,"02-restore",{"ultimate_cores":int(g.hyperspace.config.forge_costs.restore_ultimate.ultimate_cores)},1,false,int(original_drone.level))
 if allowed:
  allowed=await operation(9,"03-modernize",{str(g.hyperspace.config.routes[route].material):0},1,false,target)
 if allowed:
  allowed=await operation(10,"04-reultimate",{"ultimate_cores":int(g.hyperspace.config.forge_costs.ultimate.ultimate_cores)},0,true,target)
 if allowed:
  var inventory=g.profile.hyperspace.inventory;var d=inventory.drones["space:1:2"]
  var expected=source_inventory.drones.duplicate(true);expected["space:1:2"]=d.duplicate(true)
  check(inventory.drones==expected,"every unrelated real drone unchanged")
  for key in source_inventory:
   if key not in ["drones","generation"]:check(inventory[key]==source_inventory[key],"real inventory boundary unchanged "+str(key))
  check(g.profile.hyperspace.materials==raw.save.hyperspace.materials and g.profile.hyperspace.history==raw.save.hyperspace.history,"all actual materials and historical records unchanged")
  check(int(d.forge_revision)==int(original_drone.forge_revision)+3 and d.forge_rng_state==original_drone.forge_rng_state,"three commits advance revision without rerolling retained extra affix")
  var affix=original_drone.ultimate_affix
  var effect=preload("res://scripts/drone_effect_aggregator.gd")
  var actual=effect.project(g);var expected_value=effect.affix_value(affix,d,g.hyperspace.config)
  check(float(actual.affixes.get(str(affix.key),0))>=expected_value,"reultimate retained extra affix active at actual new level")
  await click(button_named(scene,"装备"),"native close final forge")
  await click(button_named(scene,"异空间"),"native reopen final lifecycle")
  await capture("05-final-reopened-and-restored")
 finish(source_sha)
func finish(source_sha:String):
 check(FileAccess.get_sha256("/tmp/ultimate-chain-evidence/sources/save_periodic_185401.json")==source_sha,"parent actual two-core file byte-identical")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5","source_evidence_commit":"8ab0ef05109d6e0b90822546d6b90df59cc52c06","source_sha":source_sha,"source_x1":185401.399978375,"hours_after_clear60":1.0914444441902824,"actual_target":target,"checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"events":events,"snapshots":snapshots},"\t"))
 print("ULTIMATE_LIFECYCLE failures=",checks.filter(func(c):return not c.ok).size());quit()
