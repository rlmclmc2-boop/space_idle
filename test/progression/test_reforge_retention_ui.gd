extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize()->void:call_deferred("run")
func click(control:Control)->void:
 await process_frame;await process_frame
 var ancestor=control.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:
   ancestor.ensure_control_visible(control);await process_frame;await process_frame;ancestor.ensure_control_visible(control);await process_frame;await process_frame
   break
  ancestor=ancestor.get_parent()
 var point:Vector2=control.get_global_transform_with_canvas()*(control.size/2)
 var window:Window=control.get_window()
 if window!=root and root.gui_embed_subwindows:point=root.get_final_transform()*(Vector2(window.position)+point)
 else:point=window.get_final_transform()*point
 var window_id:int=root.get_window_id() if root.gui_embed_subwindows else window.get_window_id()
 var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=window_id;Input.parse_input_event(motion)
 await process_frame
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  event.window_id=window_id;Input.parse_input_event(event);await process_frame
func capture(dialog,label:String)->void:
 var folder:String=OS.get_environment("QA_RETENTION_EVIDENCE")
 if folder.is_empty() or DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+label+"-main-viewport.png")
 dialog.get_texture().get_image().save_png(folder+"/"+label+"-dialog.png")
 var screen_image:Image=DisplayServer.screen_get_image(DisplayServer.window_get_current_screen(root.get_window_id()))
 if screen_image!=null:screen_image.save_png(folder+"/"+label+"-screen.png")
 var control:Control=dialog.get_ok_button()
 FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"display":DisplayServer.get_name(),"root_size":str(root.size),"dialog_size":str(dialog.size),"embedded":dialog.is_embedded(),"root_embed":root.gui_embed_subwindows,"dialog_position":str(dialog.position),"confirm_rect":str(control.get_global_rect()),"selected":dialog.selected,"capacity":dialog.capacity,"summary":dialog.summary.text,"feedback":dialog.feedback.text},"\t"))
func current_dialog(panel):
 for child in panel.get_children():
  if child.get_script()==preload("res://scripts/hyperspace_reforge_dialog.gd"):return child
 return null
func run()->void:
 var width:String=OS.get_environment("QA_RETENTION_WIDTH")
 if not width.is_empty():root.size=Vector2i(int(width),int(OS.get_environment("QA_RETENTION_HEIGHT")))
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true;scene.game.profile.onboarding.completed=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=80;g.profile.cleared=range(1,80);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.planets["1"].degree=300;g.planet_buildings.sync(g,"1");g.profile.planets["1"].buildings.shipyard.status="ready"
 check(g.planet_buildings.activate(g,"1","shipyard"),"Actual activated shipyard fixture")
 var ids:Array=[];var bag:Dictionary=g.profile.hyperspace.inventory
 var cap:int=preload("res://scripts/drone_inventory.gd").retention_capacity(bag,g.hyperspace.config)+int(g.hyperspace.config.retention_capacity_gain)
 for index in cap+2:
  var rng=RandomNumberGenerator.new();rng.seed=900+index;var id="retain:%d"%index
  var d:Dictionary=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,id,"gold","laser",5,"1")
  check(preload("res://scripts/drone_inventory.gd").insert(bag,d,g.hyperspace.config),"Valid generated inventory fixture")
  ids.append(id)
  if index<2:bag.favorites.append(id)
 g.profile.hyperspace.materials.antiproton=7;g.profile.hyperspace.energy=1;g.profile.resources["1"]=12345
 scene.refresh_tab_visibility();scene.select_system(6);await process_frame
 var before:String=JSON.stringify(g.profile)
 scene.planet_panel._confirm_reforge("1");await process_frame;var dialog=current_dialog(scene.planet_panel)
 check(dialog.size.y<=540,"Retention dialog stays within short-window height")
 await capture(dialog,"01-selection")
 check(dialog!=null and dialog.capacity==cap and dialog.choices.size()==cap+2,"Production entry previews upcoming source-derived capacity and all valid candidates")
 await click(dialog.choices[ids[0]])
 check(dialog.selected==[ids[0]],"Native modal checkbox changes only retention draft")
 if dialog.selected!=[ids[0]]:quit(1);return
 check(JSON.stringify(g.profile)==before,"Preview and checkbox do not mutate authoritative profile")
 await click(dialog.get_cancel_button());await process_frame
 check(JSON.stringify(g.profile)==before and current_dialog(scene.planet_panel)==null,"Native modal cancellation is zero change")
 scene.planet_panel._confirm_reforge("1");await process_frame;dialog=current_dialog(scene.planet_panel)
 for id in ids:await click(dialog.choices[id])
 await capture(dialog,"02-over-capacity")
 check(dialog.selected.size()==cap+2 and dialog.get_ok_button().disabled,"Native selection over current upcoming capacity disables confirm")
 check(not g.reforge_planet("1",ids) and JSON.stringify(g.profile)==before,"Domain independently rejects over-capacity transaction without mutation")
 await click(dialog.get_cancel_button());await process_frame
 scene.planet_panel._confirm_reforge("1");await process_frame;dialog=current_dialog(scene.planet_panel)
 await click(dialog.choices[ids[0]]);await click(dialog.choices[ids[1]])
 await capture(dialog,"03-selected-favorites")
 check(not dialog.get_ok_button().disabled and dialog.selected==[ids[0],ids[1]],"Two favorite drones explicitly selected within allowance")
 await click(dialog.get_ok_button());await process_frame
 var next:Dictionary=g.profile.hyperspace
 check(next.round_id==2 and next.inventory.drones.size()==2 and next.inventory.sealed.size()==2 and next.inventory.equipped.is_empty(),"Native production confirm retains selected IDs only and seals/unloads them atomically")
 check(next.inventory.favorites==[ids[0],ids[1]] and next.materials.antiproton==0 and next.energy==g.hyperspace.config.energy_cap and g.profile.resources["1"]==12345,"Favorites persist; hyperspace materials reset and source-correct resource balances persist")
 check(preload("res://scripts/drone_inventory.gd").retention_capacity(next.inventory,g.hyperspace.config)==cap,"Committed allowance increases by source gain")
 var after:String=JSON.stringify(g.profile);check(not g.reforge_planet("1",[ids[0]]) and JSON.stringify(g.profile)==after,"Duplicate conquest cannot reapply transaction")
 var saved:Dictionary=g.portable_save_data();var restored=BattleGame.new(g.db,false);restored.load_progress_data(saved)
 check(restored.profile.hyperspace.inventory.sealed==next.inventory.sealed and restored.profile.hyperspace.inventory.drones==next.inventory.drones,"Current-version real save/read preserves retained drones and gates")
 var gate:int=int(next.inventory.sealed[ids[0]])
 restored.profile.highestLevel=gate-1;var sealed_before=JSON.stringify(restored.profile.hyperspace)
 check(not restored.hyperspace.claim_sealed(restored,ids[0]) and JSON.stringify(restored.profile.hyperspace)==sealed_before,"Retained drone cannot be claimed before actual gate")
 restored.profile.highestLevel=gate;check(restored.hyperspace.claim_sealed(restored,ids[0]),"Actual source gate releases retained drone")
 g.paused=true;g.profile.highestLevel=80;g.profile.cleared=range(1,80);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.planets["2"].degree=300;g.planet_buildings.sync(g,"2");var later_shipyard:=""
 for row in g.planet_buildings.rows(g,"2"):
  if str(row.type)=="shipyard":later_shipyard=str(row.id);break
 g.profile.planets["2"].buildings[later_shipyard].status="ready"
 check(g.planet_buildings.activate(g,"2",later_shipyard),"Second earned shipyard fixture activates")
 scene.planet_panel._confirm_reforge("2");await process_frame;dialog=current_dialog(scene.planet_panel)
 check(dialog.capacity==cap+int(g.hyperspace.config.retention_capacity_gain),"Next reforge preview includes another source-defined allowance increase")
 await click(dialog.choices[ids[0]])
 check(g.hyperspace.set_favorites(g,[ids[1]]),"Actual inventory change while draft is open")
 var changed:String=JSON.stringify(g.profile)
 check(dialog.stale and dialog.get_ok_button().disabled,"Real inventory change invalidates frozen selection")
 dialog.commit();check(JSON.stringify(g.profile)==changed,"Stale direct confirm cannot delete or seal a changed inventory")
 await click(dialog.get_cancel_button());await process_frame
 check(JSON.stringify(g.profile)==changed,"Cancel stale draft leaves the independently committed change alone")
 print("REFORGE_RETENTION_UI ",checks," checks ",failures," failures");quit(1 if failures else 0)
