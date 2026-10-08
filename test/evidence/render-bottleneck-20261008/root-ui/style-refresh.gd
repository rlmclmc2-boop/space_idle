extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var g=super.create_battle_game(false);g.stat_cache_enabled=true;return g
var themes:=0
var draws:=0
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func track(node:Node)->void:
 if node is Control:node.theme_changed.connect(func():themes+=1)
 if node is CanvasItem:node.draw.connect(func():draws+=1)
 for child in node.get_children():track(child)
func run()->void:
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(1180,812);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;OS.low_processor_usage_mode=false
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources={"1":1e9,"2":1e9}
 for i in 3:g.equip_slot("weapons",i,"laser");g.upgrade_slot("weapons",i,33)
 g.upgrade_slot("defence",0,33);g.equip_slot("defence",1,"shield");g.upgrade_slot("defence",1,33)
 g.start(34,false);g.state=BattleGame.State.COMBAT;g.spawn_group();g.paused=false;scene.refresh_structure();scene.refresh_navigation();scene._process(0.0);scene.set_process(false)
 for ignored in 15:await process_frame
 track(scene.equipment_panel)
 var card:Button=scene.equipment_panel.cards.weapons_0
 var before_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 8:
  themes=0;draws=0
  var style_before:int=card.get_theme_stylebox("normal").get_instance_id()
  var started=Time.get_ticks_usec()
  var applied:bool=g.upgrade_slot("weapons",0)
  var upgrade_us=Time.get_ticks_usec()-started
  await process_frame;await RenderingServer.frame_post_draw
  var style_after:int=card.get_theme_stylebox("normal").get_instance_id()
  rows.append({"applied":applied,"level":g.module_entry("weapons",0).level,"command_us":upgrade_us,"theme_events":themes,"ui_draw_events":draws,"normal_style_replaced":style_before!=style_after,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
 var snapshot={"field_level":card.fields.level.text,"cost":card.fields.cost.text,"button":card.upgrade_button.text,"profile_level":g.module_entry("weapons",0).level,"balance":g.profile.resources["1"],"normal_bg":str(card.get_theme_stylebox("normal").texture.get_image().get_pixel(12,12)),"focus":str(root.gui_get_focus_owner())}
 var payload={"source":"43842f56","mode":OS.get_environment("STYLE_PROBE_MODE"),"fixture":"Constructed isolated34; cache true; save false; frozen game process; 8 actual paid slot upgrade commands, no natural FPS claim","rows":rows,"snapshot":snapshot,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-before_resources}
 var path="/workspace/bug-qa/performance-20261008/style-"+OS.get_environment("STYLE_PROBE_MODE")+".json"
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close();print(JSON.stringify(payload));quit()
