extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var game=super.create_battle_game(false)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("/tmp/galaxy-complete-ui-evidence/sources/save_final.json"));var saved=raw.save.duplicate(true)
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
var folder="/tmp/galaxy-complete-ui-evidence/native"
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
func capture(label:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id())).save_png(folder+"/"+label+"-screen.png")
 var gp=scene.galaxy_panel;var items=[]
 for i in gp.selector.item_count:items.append({"name":gp.selector.get_item_text(i),"key":gp.selector.get_item_metadata(i)})
 snapshots.append({"label":label,"stage":g.stage,"highest":g.profile.highestLevel,"selected":gp.selected,"state_text":gp.state_label.text,"cards":{"exploration":gp.cards.exploration.text,"buildings":gp.cards.buildings.text,"max_level":gp.cards.max_level.text},"start_visible":gp.start_button.is_visible_in_tree(),"selector_items":items,"next_definition":g.galaxy.regions.galaxy_1.row.next_galaxy,"detail_slot":gp.detail_slot,"detail_text":gp.details.text})
func run():
 root.size=Vector2i(1373,883);root.gui_embed_subwindows=false
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=[];root.add_child(scene);current_scene=scene;g=scene.game;g.paused=true;g.save_enabled=false
 var source="/tmp/galaxy-complete-ui-evidence/sources/save_final.json";var sha=FileAccess.get_sha256(source);var raw=JSON.parse_string(FileAccess.get_file_as_string(source));g.rng.state=int(str(raw.rng_state));var before=normalized(g.profile.hyperspace);var galaxy_before=normalized(g.galaxy.save_data())
 check(g.stage==60 and g.profile.highestLevel==61 and g.galaxy.regions.galaxy_1.state.status=="complete" and g.galaxy.regions.galaxy_1.slots.size()==30 and g.galaxy.regions.galaxy_1.slots.all(func(v):return int(v.level)==5),"actual complete source formal load 30x5 no main61 advance")
 await click(button_named(scene,"星系"),"native actual completed galaxy navigation")
 var gp=scene.galaxy_panel
 check(gp.selected=="galaxy_1" and gp.cards.buildings.text=="30 / 30" and gp.cards.max_level.text=="30" and not gp.start_button.is_visible_in_tree(),"actual complete page 30/30 all30 maxlevel no repeat start")
 await capture("01-real-30x5-completed-page")
 await click(gp.selector,"native inspect actual galaxy selector entries")
 await capture("02-real-selector-only-configured-first-galaxy")
 await choose(gp.selector,0,"native choose only actual completed galaxy")
 check(g.db.data.galaxy.size()==1 and gp.selector.item_count==1 and str(g.galaxy.regions.galaxy_1.row.next_galaxy).is_empty(),"845 only defines first galaxy with empty next_galaxy; no invented next entry")
 var map=gp.map;var picked=-1;var pos=Vector2.ZERO
 for y in range(55,int(map.size.y)-60,12):
  for x in range(20,int(map.size.x)-20,12):
   var at=Vector2(x,y);var id=map.pick(at)
   if id>=0:picked=id;pos=at;break
  if picked>=0:break
 if picked>=0:
  var point=map.get_window().get_final_transform()*map.get_global_transform_with_canvas()*pos
  actions.append({"label":"native actual completed building select","slot":picked,"native":true})
  for down in [true,false]:
   var e=InputEventMouseButton.new();e.position=point;e.window_id=root.get_window_id();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);await process_frame
 check(picked>=0 and gp.detail_slot==picked and gp.detail_frame.visible and gp.details.text.contains("5"),"actual completed building selected shows real level5 detail")
 await capture("03-real-max-building-detail")
 var node=gp.get_instance_id()
 await click(button_named(scene,"装备"),"native close completed galaxy")
 await click(button_named(scene,"星系"),"native reopen completed galaxy")
 check(gp.get_instance_id()==node and gp.selected=="galaxy_1" and gp.cards.buildings.text=="30 / 30" and gp.cards.max_level.text=="30" and not gp.start_button.is_visible_in_tree(),"real complete state and same panel persist after reopen")
 await capture("04-real-complete-reopened")
 check(g.stage==60 and normalized(g.profile.hyperspace)==before and normalized(g.galaxy.save_data())==galaxy_before,"no progression forge or completed galaxy mutation during display checks")
 check(FileAccess.get_sha256(source)==sha,"parent actual complete source byte-identical")
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"commit":"845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5","source_commit":"119457ced6c485f763a14ae6b87ccf14b8c57d70","source_sha":sha,"source_x1":206171.533306872,"scope":"Actual full galaxy UI only, no stage61 or construction injection; only first galaxy configured","checks":checks,"failures":checks.filter(func(c):return not c.ok),"actions":actions,"snapshots":snapshots},"\t"));print("GALAXY_COMPLETE_UI failures=",checks.filter(func(c):return not c.ok).size());quit()
