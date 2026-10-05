extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
const Permission=preload("res://scripts/hyperspace_permissions.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
var checks:=0
var failures:=0
var scene
var records:Array=[]
var output:=""
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func click(control:Control)->void:
 var point=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
 var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=root.get_window_id();Input.parse_input_event(motion);await process_frame
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.window_id=root.get_window_id();Input.parse_input_event(event);await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 scene.refresh_draw_layers(0.0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func occupied(label:String)->void:
 var g=scene.game;var panel=scene.crew_panel
 check(Permission.reserved_crew(g.profile.hyperspace)=="navigator" and not g.idle_planet_crew("navigator"),label+": authority keeps navigator occupied")
 check(panel.row_fields.navigator.role.text==UIText.t("crew.hyperspace_reserved_short") and panel.status.text==UIText.t("crew.hyperspace_reserved"),label+": row and selected detail no longer say idle")
 check(panel.assign_button.disabled and panel.assignment_reason.visible and panel.assignment_reason.text==UIText.t("crew.hyperspace_busy_reason") and panel.assign_button.tooltip_text==UIText.t("crew.hyperspace_busy_reason"),label+": visible disabled reason matches actual permission")
 records.append({"case":label,"role":panel.row_fields.navigator.role.text,"status":panel.status.text,"assign_disabled":panel.assign_button.disabled,"reason":panel.assignment_reason.text,"reserved":Permission.reserved_crew(g.profile.hyperspace),"auto":g.profile.hyperspace.auto.duplicate(true),"active_status":g.profile.hyperspace.active.get("status","")})
func run()->void:
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_CREW_SOURCE")))
 if snapshot.is_empty() or not snapshot.get("save") is Dictionary:printerr("Actual crew source required");quit(2);return
 if not OS.get_environment("QA_MANUAL_WIDTH").is_empty():root.size=Vector2i(int(OS.get_environment("QA_MANUAL_WIDTH")),int(OS.get_environment("QA_MANUAL_HEIGHT")))
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;var raw:Dictionary=snapshot.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system();g.load_progress_data(raw);g.resume_progress();g.rng.state=int(str(snapshot.rng_state));scene.refresh_tab_visibility()
 check(g.profile.highestLevel==snapshot.save.highestLevel and g.profile.hyperspace==snapshot.save.hyperspace,"Actual source formally loaded without altering auto inventory resources")
 check(g.load_hyperspace_routes(),"Isolated persist=false UI fixture explicitly loads actual production routes")
 scene.hyperspace_panel.refresh_manual_status()
 await process_frame;var before=JSON.stringify(g.profile);var rng_before=g.rng.state
 await click(scene.system_nav_buttons[5]);await click(scene.crew_panel.rows.navigator)
 check(scene.crew_panel.visible and scene.crew_panel.selected=="navigator","Native crew page and navigator selection")
 var row_id:int=scene.crew_panel.rows.navigator.get_instance_id();occupied("actual source auto waiting")
 await capture("01-actual-navigator-occupied")
 await click(scene.system_nav_buttons[6]);var card:Dictionary=scene.planet_panel.cards["1"]
 check(not card.crew_ids.has("navigator"),"Actual planet roster excludes auto-reserved worker even when picker is hidden")
 await click(scene.system_nav_buttons[9]);var panel=scene.hyperspace_panel
 check(panel.manual_ready(),"Loaded production route enables real manual UI instead of missing fixture adapter")
 panel.level.value=31
 check(panel.resource_reference_hint.text==UIText.t("hyperspace.resource_reference_hint",{"level":"31","cleared":"30"}),"Selected31 uses actual cleared30 hint")
 panel.level.value=5
 check(panel.resource_reference_hint.text==UIText.t("hyperspace.resource_reference_hint",{"level":"5","cleared":"30"}),"Lower battle selection keeps latest actual clear30 hint")
 await capture("02-actual-resource-source-hint")
 var actual_unchanged:bool=JSON.stringify(g.profile)==before and g.rng.state==rng_before
 check(actual_unchanged,"All native read-only pages selection and actual captures preserve model and RNG")
 check(g.hyperspace.set_auto(g,false,"",0,""),"Actual stop releases waiting auto owner")
 await click(scene.system_nav_buttons[5]);await click(scene.crew_panel.rows.navigator)
 check(g.idle_planet_crew("navigator") and scene.crew_panel.status.text==UIText.t("crew.free") and not scene.crew_panel.assignment_reason.visible and scene.crew_panel.assign_button.tooltip_text.is_empty(),"Stop event restores true idle labels and clears stale disabled reason")
 await click(scene.system_nav_buttons[6]);check(card.crew_ids.has("navigator"),"Stopped owner is restored to actual available planet roster")
 check(g.hyperspace.set_auto(g,true,"beta",5,"navigator"),"Actual recorded route re-enables auto reservation")
 await click(scene.system_nav_buttons[5]);await click(scene.crew_panel.rows.navigator);occupied("re-enabled")
 g.paused=true;scene.crew_panel.refresh();occupied("paused retains reservation");g.paused=false
 # Explicit legal running-state fixture: top-up only this isolated UI specimen to its configured start threshold.
 g.profile.hyperspace.energy=float(g.hyperspace.online_config(g).energy_cap)
 check(g.hyperspace.start_auto(g),"Legal running fixture starts through real paid domain transaction")
 occupied("running")
 check(g.hyperspace.set_auto(g,false,"",0,""),"Stop recurrence while actual running receipt remains")
 occupied("recurrence stopped but current task running")
 check(g.hyperspace.complete(g,int(g.profile.hyperspace.active.round_id),int(g.profile.hyperspace.active.run_id),false),"Actual failed completion releases receipt and refunds once")
 check(g.idle_planet_crew("navigator") and scene.crew_panel.status.text==UIText.t("crew.free") and not scene.crew_panel.assignment_reason.visible,"Current task removal restores idle without UI changing ownership")
 # A legal full-inventory fixture isolates the warehouse wait boundary; these are fixture drones, never a campaign grant.
 var rng=RandomNumberGenerator.new();rng.seed=915;var fixture_count:=0
 while Bag.has_space(g.profile.hyperspace.inventory,g.hyperspace.config):
  var id:String="occupancy-ui:"+str(fixture_count)
  if not Bag.insert(g.profile.hyperspace.inventory,Rewards.create_drone(rng,g.hyperspace.config,id,"white","laser",5,"1"),g.hyperspace.config):printerr("Invalid capacity fixture");quit(2);return
  fixture_count+=1
 check(g.hyperspace.set_auto(g,true,"beta",5,"navigator") and not g.hyperspace.start_auto(g),"Full legal warehouse blocks actual auto start")
 var waiting:Dictionary=g.profile.hyperspace.duplicate(true);waiting.blocked=true;g.hyperspace.publish(g,waiting,"warehouse_wait_fixture")
 occupied("full warehouse waiting")
 check(scene.crew_panel.rows.navigator.get_instance_id()==row_id,"Occupancy events preserve existing row controls")
 FileAccess.open(output+"/ui-occupancy-observations.json",FileAccess.WRITE).store_string(JSON.stringify({"source":OS.get_environment("QA_CREW_SOURCE"),"actual_read_only_model_unchanged":actual_unchanged,"fixture_energy_topup_after_read_only":true,"fixture_full_bag_drones":fixture_count,"logical_ticks":0,"records":records},"\t"))
 print("CREW_OCCUPANCY_RESOURCE_HINT ",checks," checks ",failures," failures");quit(1 if failures else 0)
