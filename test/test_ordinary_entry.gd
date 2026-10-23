extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.notify_configuration_changed()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var checks=0
var failures=0
var reports:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func points(scene)->Dictionary:
 var out:Dictionary={}
 for enemy in scene.game.enemies:out[str(enemy.uid)]=scene.enemy_render_position(enemy)
 return out
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and str(args[0])=="planet-loading":
  await run_planet_loading();return
 if not args.is_empty() and str(args[0]).begins_with("reactor-"):
  await run_reactor(str(args[0]));return
 if not args.is_empty() and str(args[0]).begins_with("product-"):
  await run_product(str(args[0]));return
 for native in [false,true]:
  var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture","--capture-all"];scene.music_on=false
  root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
  var g=scene.game
  check(g.economy.balance("1")==5000.0 and g.economy.balance("2")==100.0,"capture-all installs the complete economy snapshot")
  g.save_enabled=false;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear();var equipment=g.equipment.save_data()
  for entry in equipment.loadout.weapons:entry.key=""
  g.equipment.install_snapshot(equipment,g.db);g.notify_configuration_changed()
  check(g.start(1,false),"real first-stage travel starts")
  g.native_execution_auto=native
  g.distance=float(g.db.levels[0].groups[0].position)*float(g.db.levels[0].length)-0.1
  scene._process(1.0/60.0)
  check(g.state==g.State.COMBAT and not g.enemies.is_empty(),"real first encounter spawns")
  var start=points(scene)
  scene.battle_layer.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.runtime/entry-"+str(native)+"-start.png")
  for i in 80:scene._process(1.0/60.0)
  var end=points(scene)
  for id in start:
   check(end.has(id) and float(end[id].y)-float(start[id].y)>45.0,"each real first-wave ship completes visible entry")
  for i in 30:scene._process(1.0/60.0)
  check(points(scene)==end,"resident ships remain fixed after entry")
  scene.battle_layer.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.runtime/entry-"+str(native)+"-end.png")
  reports.append({"native":native,"start":start,"end":end,"resident":points(scene),"count":g.enemies.size()})
  if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
  if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
  scene.queue_free();await process_frame
 var out=FileAccess.open("res://.runtime/ordinary-entry.json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports},"\t"));out.close()
 print("ORDINARY_ENTRY ",checks," checks ",failures," failures");quit(1 if failures else 0)

func product_state(g)->Dictionary:
 var wallet:Dictionary=g.economy.save_data();wallet.erase("chronoParticles")
 return {"wallet":wallet,"equipment":g.equipment.save_data(),"enhancement":g.enhancement_growth.save_data(),"reactor":g.reactor.save_data(),"crew":g.crew.save_data(),"planets":g.planets.save_data(),"galaxy":g.galaxy.save_data(),"research":g.research.save_data(),"hyperspace":g.hyperspace.save_data(),"time":g.production_time()}

func product_capture(scene,label:String)->void:
 scene._process(0.0) # Use the product redraw path before reading the displayed header.
 scene.battle_layer.queue_redraw();scene.refresh_save_status()
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/"+label+".png")

func product_remember(g,receipt:Dictionary)->void:
 var file:=FileAccess.open("user://product-expected.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"domains":product_state(g),"receipt":receipt,"chrono":g.economy.balance("chrono")}));file.close()

func run_product(phase:String)->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var area:=ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\","/")
 check(OS.get_user_data_dir().replace("\\","/").begins_with(area),"Product run uses isolated player data")
 # Keep the shipped scene, real constructor, caches, native choice and save writer.
 # No --capture or replacement scene script is used in these process phases.
 var scene=load("res://main.tscn").instantiate();scene.automation_args=[];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game
 check(g.startup_error.is_empty() and g.save_enabled and g.progress_writer.owns_progress() and g.stat_cache_enabled,"Original product scene holds its writer lock with saving and caches enabled")
 if not g.startup_error.is_empty() or not g.save_enabled:quit(1);return
 await process_frame
 if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
 var receipt:Dictionary={}
 if phase=="product-write":
  check(not FileAccess.file_exists(BattleGame.SAVE_PATH),"Product starts in a fresh isolated slot")
  # Seed unlocks and a finite budget; perform progression through real commands.
  # This is an authored acceptance scenario, not a claim of playing 60 stages.
  g.rng.seed=1701
  g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear()
  g.profile.onboarding.completed=true;scene.beginner_guide.hide()
  check(g.economy.credit_many({"1":1e15,"2":1e15,"jewel":1e12}),"Acceptance budget credits through economy")
  var wallet:Dictionary=g.economy.save_data();wallet.chronoParticles=100.0;wallet.materials[g.db.evolution_material_id()]=10000
  check(g.economy.install_snapshot(wallet),"Acceptance chrono balance installs")
  check(g.equip_slot("weapons",0,"cannon"),"Real module selection prepares the challenge ship")
  check(g.upgrade_slot("weapons",0,119),"Real weapon purchase prepares the challenge ship")
  check(g.upgrade_slot("defence",0,119),"Real defence purchase prepares the challenge ship")
  check(g.upgrade_enhancement(30)==30 and g.upgrade_reactor(2),"Real enhancement and reactor purchases succeed")
  check(g.set_reactor_allocation("weapons",3),"Real allocation commits before product save")
  check(g.assign_crew("navigator","equipment_upgrade","equipment") and g.set_crew_upgrade_mode("navigator","1"),"Real automatic upgrade job is assigned")
  check(g.select_tech("weapon_accuracy") and g.set_tech_input("1",10),"Real paid research starts")
  scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
  scene.equipment_panel.set_upgrade_amount(1);scene.equipment_panel.refresh()
  var level:int=g.slot_entry("weapons",0).level
  var quote:Dictionary=g.slot_upgrade_cost("weapons",0,1);var iron=g.economy.balance("1")
  scene.equipment_panel.cards["weapons_0"].upgrade_button.pressed.emit()
  check(g.slot_entry("weapons",0).level==level+1 and g.economy.balance("1")==g.N.subtract(iron,quote.get("1",0)),"Actual equipment card signal commits its displayed one-level price")
  check(g.start(1,false),"Product starts a normal sortie")
  g.auto_gen_elapsed=float(g.auto_gen_settings().interval)-0.1 # Near-due acceptance timer; keep configured drop travel and amount.
  level=int(g.slot_entry("weapons",0).level);var collections:Array=[];g.event.connect(func(kind,info):
   if kind=="collect" and info.get("auto_gen",false):collections.append(info.duplicate(true)))
  var points=g.research.progress("weapon_accuracy")
  for frame in 2400:
   scene._process(1.0/60.0)
   if frame%10==0:await process_frame
  check(g.slot_entry("weapons",0).level>level,"Product external clock executes automatic equipment purchases")
  check(not collections.is_empty(),"Product clock advances configured 30-second automatic income")
  check(g.research.progress("weapon_accuracy")>points or g.hightech_level("weapon_accuracy")>0,"Product clock advances paid research")
  g.paused=true;var elapsed=g.production_time();var particles=g.economy.balance("chrono")
  scene._process(0.5)
  check(g.production_time()==elapsed and g.economy.balance("chrono")==particles,"Paused product spends no game time or particles")
  g.paused=false;check(g.set_speed(5),"Product accepts configured x5 speed")
  scene._process(0.1)
  check(is_equal_approx(g.production_time()-elapsed,0.5) and g.economy.balance("chrono")<particles,"Product consumes one boosted external interval")
  g.set_speed(1)
  check(g.start_hyperspace_challenge("alpha"),"Product enters a real production hyperspace route")
  for frame in 12000:
   if not g.manual_hyperspace.active:break
   scene._process(1.0/60.0)
   if frame%20==0:await process_frame
  print("PRODUCT_CHALLENGE ",JSON.stringify({"result":g.manual_hyperspace.last_result,"point":g.group_index,"state":g.state,"active":g.manual_hyperspace.active,"enemies":g.enemies.map(func(enemy):return {"id":enemy.id,"hp":enemy.hp,"shield":enemy.shield})}))
  check(not g.manual_hyperspace.active and g.manual_hyperspace.last_result.get("reason")=="success","Actual attacks clear the manual challenge and return")
  check(g.hyperspace.state.active.get("status")=="completed_pending","Actual challenge leaves an unclaimed reward receipt")
  check(g.distance==0 and g.group_index==0 and g.enemies.is_empty(),"Product returns to a clean mainline start")
  receipt=g.hyperspace.state.active.duplicate(true)
  g.paused=true;scene.show_save_page();scene.save_panel.manual_button.pressed.emit()
  check(g.last_save_error==OK and FileAccess.file_exists(BattleGame.SAVE_PATH),"Actual save button writes the complete current-format snapshot")
  product_remember(g,receipt)
  await product_capture(scene,phase)
 else:
  var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://product-expected.json"))
  # Disk JSON has one numeric type; compare values after the same encoding,
  # not textual int/float spellings (all domain keys and values remain checked).
  var restored:Dictionary=JSON.parse_string(JSON.stringify(product_state(g)))
  var mismatches:Array=[]
  for key in expected.domains:
   if restored.get(key)!=expected.domains[key]:mismatches.append(key)
  print("PRODUCT_RESTORED ",JSON.stringify({"domains":restored.keys(),"mismatches":mismatches}))
  check(restored.size()==expected.domains.size() and mismatches.is_empty(),"Fresh product process restores all domain snapshots and settled time")
  check(g.economy.balance("chrono")>=float(expected.chrono) and g.economy.balance("chrono")<=g.chrono_capacity(),"Reopen preserves balance plus bounded offline chrono")
  g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
  receipt=expected.receipt
  if phase=="product-reopen":
   check(g.hyperspace.state.active.get("status")=="completed_pending","Pending challenge reward survives process restart")
   check(g.claim_hyperspace(int(receipt.round_id),int(receipt.run_id)),"Product claims the saved real challenge reward")
   var committed:Dictionary=g.economy.save_data();var inventory:Dictionary=g.hyperspace.save_data()
   check(not g.claim_hyperspace(int(receipt.round_id),int(receipt.run_id)) and g.economy.save_data()==committed and g.hyperspace.save_data()==inventory,"Same receipt cannot credit again")
   scene.show_save_page();scene.save_panel.manual_button.pressed.emit()
   check(g.last_save_error==OK,"Actual save button persists the completed claim")
   product_remember(g,receipt)
  else:
   var committed:Dictionary=g.economy.save_data();var inventory:Dictionary=g.hyperspace.save_data()
   check(not g.claim_hyperspace(int(receipt.round_id),int(receipt.run_id)) and g.economy.save_data()==committed and g.hyperspace.save_data()==inventory,"Claim remains final after another product process restart")
   check(g.start(1,false),"Reopened product can start a fresh sortie")
   for frame in 90:
    scene._process(1.0/60.0)
    if frame%10==0:await process_frame
   check(g.production_time()>float(expected.domains.time),"Reopened product resumes live simulation")
  await product_capture(scene,phase)
 var report:={"phase":phase,"checks":checks,"failures":failures,"saving":g.save_enabled,"writer":g.progress_writer.owns_progress(),"startup_error":g.startup_error,"header_values":{"iron":scene.resource_display("1"),"uranium":scene.resource_display("2")},"production_time":g.production_time(),"receipt_status":g.hyperspace.state.active.get("status",""),"native":g.native_execution!=null}
 FileAccess.open("res://.runtime/"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report," "))
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
 scene.queue_free();await process_frame
 print("PRODUCT_ENTRY ",phase," ",checks," checks ",failures," failures");quit(1 if failures else 0)

# Capacity acceptance uses the original product scene and a fresh real save slot.
func run_reactor(phase:String)->void:
 var N=GrowthNumber
 var area:=ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\","/")
 check(OS.get_user_data_dir().replace("\\","/").begins_with(area),"Reactor product uses isolated player data")
 var scene=load("res://main.tscn").instantiate();scene.automation_args=[];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game
 check(g.startup_error.is_empty() and g.save_enabled and g.progress_writer.owns_progress() and g.stat_cache_enabled,"Original scene enables saving, writer lock and attribute caches")
 if not g.startup_error.is_empty() or not g.save_enabled:quit(1);return
 g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
 await process_frame
 if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
 var report:Dictionary={"phase":phase}
 if phase=="reactor-write":
  check(not FileAccess.file_exists(BattleGame.SAVE_PATH),"Fresh reactor product save")
  g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear()
  check(g.economy.credit_many({"antiproton":12345,"ultimate_cores":4321}),"Exact material and core acceptance balances")
  check(g.economy.credit("2",1e6) and g.upgrade_reactor(2),"Actual small integer purchase")
  check(g.set_reactor_allocation("weapons",30.9) and g.reactor.allocation("weapons")==30.0,"Small allocation floors to an integer")
  var cost=g.reactor.purchase_cost(1000000000,g.db.config)
  check(g.economy.credit("2",N.multiply(cost,2.0)),"Finite huge budget installs through economy")
  var before=g.economy.balance("2");var started:=Time.get_ticks_usec()
  check(g.upgrade_reactor(1000000000) and g.reactor.level()==1000000003,"Actual billion-level purchase commits")
  report.purchase_ms=(Time.get_ticks_usec()-started)/1000.0
  check(N.compare(g.economy.balance("2"),N.subtract(before,cost))==0,"Actual purchase uses the same finite quoted cost")
  var capacity=g.reactor_capacity()
  check(capacity is Dictionary and N.valid(capacity),"Capacity remains finite without expanding decimal digits")
  check(g.equalize_reactor_allocation(),"Actual huge equalization commits")
  check(absf(N.ratio(g.reactor_allocated(),capacity)-1.0)<1e-14,"Equalized sum consumes capacity within binary64 rounding")
  scene.refresh_tab_visibility();scene.select_system(2);scene.reactor_panel.refresh()
  var controls:Dictionary=scene.reactor_panel.module_controls.weapons
  controls.allocation_input.text_submitted.emit(N.input_text(N.divide(capacity,8.0)))
  check(absf(N.ratio(g.reactor.allocation("weapons"),capacity)-0.125)<1e-14,"Actual scientific entry signal changes huge allocation")
  var allocation=g.reactor.allocations()
  for invalid in [-1.0,NAN,INF,{"i":"100"},{"m":INF,"e":1000}]:
   check(not g.set_reactor_allocation("weapons",invalid) and g.reactor.allocations()==allocation,"Invalid allocation rejected without changing state")
  check(N.parse_input("-3")==null and N.parse_input("1e+-3")==null and N.parse_input("nan")==null,"Invalid editable numbers rejected")
  check(N.compare(N.parse_input(N.input_text(g.reactor.allocation("weapons"))),g.reactor.allocation("weapons"))==0,"Scientific editable value round trips")
  check(not g.set_reactor_allocation("weapons",N.add(g.reactor.allocation("weapons"),1)),"Unrepresentable unit increment is a no-op")
  var wide=g.reactor.save_data();wide.reactorLevel=9007199254740993
  var owner=preload("res://scripts/reactor_state.gd").new()
  check(owner.install_snapshot(wide,g.db.config),"64-bit level above binary64 integer range accepted")
  var encoded=JSON.parse_string(JSON.stringify(owner.save_data()))
  check(encoded.reactorLevel=="9007199254740993" and owner.install_snapshot(encoded,g.db.config) and owner.level()==9007199254740993,"Wide level survives JSON without rounding or a new gameplay cap")
  wide.reactorLevel="9223372036854775807"
  check(owner.install_snapshot(wide,g.db.config) and owner.level()==9223372036854775807 and not owner.valid_level("9223372036854775808"),"Existing signed64 level representation boundary is explicit")
  g.paused=true;scene.show_save_page();scene.save_panel.manual_button.pressed.emit()
  check(g.last_save_error==OK and FileAccess.file_exists(BattleGame.SAVE_PATH),"Real save button writes huge capacity allocation")
  var expected:={"reactor":g.reactor.save_data(),"capacity":g.reactor_capacity(),"effect":g.reactor_multiplier("weapons"),"uranium":g.economy.balance("2"),"materials":g.economy.save_data().materials,"cores":g.economy.save_data().ultimateCores}
  FileAccess.open("user://reactor-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected,"",true,true))
  report.merge(expected)
 else:
  var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://reactor-expected.json"))
  check(g.reactor.level()==1000000003 and JSON.parse_string(JSON.stringify(g.reactor.save_data(),"",true,true))==expected.reactor,"New product process restores billion-level allocations")
  check(N.compare(g.reactor_capacity(),expected.capacity)==0 and N.compare(g.reactor_multiplier("weapons"),expected.effect)==0,"Reopen recomputes identical capacity and effective weapon contribution")
  check(N.compare(g.economy.balance("2"),expected.uranium)==0,"Debited huge wallet survives reopen")
  check(JSON.parse_string(JSON.stringify(g.economy.save_data().materials))==expected.materials and g.economy.save_data().ultimateCores==expected.cores,"Material and core integer wallets unchanged")
  check(g.start(1,false),"Reopened huge-capacity product starts a sortie")
  var before=g.production_time()
  for frame in 30:scene._process(1.0/60.0)
  check(g.production_time()>before and N.valid(g.reactor_multiplier("weapons")),"Live product clock and finite effects continue after reopen")
 scene.refresh_tab_visibility();scene.select_system(2);scene.reactor_panel.refresh()
 await product_capture(scene,phase)
 report.merge({"header_values":{"iron":scene.resource_display("1"),"uranium":scene.resource_display("2")},"checks":checks,"failures":failures,"saving":g.save_enabled,"version":g.SAVE_VERSION,"native":g.native_execution!=null})
 FileAccess.open("res://.runtime/"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report," ",true,true))
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
 scene.queue_free();await process_frame
 print("REACTOR_PRODUCT ",phase," ",checks," checks ",failures," failures ",JSON.stringify(report));quit(1 if failures else 0)

func run_planet_loading()->void:
 var area:=ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\","/")
 check(OS.get_user_data_dir().replace("\\","/").begins_with(area),"Planet product uses isolated player data")
 var scene=load("res://main.tscn").instantiate();scene.automation_args=[];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game
 check(g.startup_error.is_empty() and g.save_enabled and g.progress_writer.owns_progress(),"Planet loading uses original product scene and writer")
 if not g.startup_error.is_empty():quit(1);return
 g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.profile.cleared=range(1,101);g.profile.highestLevel=101
 var planets:Dictionary=g.planets.save_data();planets.merge(g.crew.save_data())
 for progress in planets.planets.values():progress.conquered=true
 check(g.planets.install_snapshot(planets,g.db),"Current planet acceptance state installs")
 g.rebuild_unlocks();g.pending_unlocks.clear();scene.refresh_structure();scene.refresh_tab_visibility()
 check(g.start(1,false),"Live sortie starts before opening the planet page")
 scene.select_system(6)
 var panel=scene.planet_panel;var id:String=panel.selected_planet_id;var visual=panel.cards[id].visual
 check(visual.preparing and visual.loading.visible and panel.cards[id].stage_title.visible,"Planet details and image-loading feedback appear immediately")
 await product_capture(scene,"planet-loading-shell")
 scene.select_system(0);await process_frame
 var before:float=g.production_time()
 for frame in 4:scene._process(1.0/60.0);await process_frame
 check(not panel.is_visible_in_tree() and g.production_time()>before,"Navigation and game clock respond while images are pending")
 planets=g.planets.save_data();planets.merge(g.crew.save_data());planets.planets[id].degree=7.0
 check(g.planets.install_snapshot(planets,g.db),"Current planet view changes while hidden")
 scene.select_system(6)
 for frame in 600:
  if panel.cards.values().all(func(card):return not card.icon.preparing) and not visual.preparing:break
  scene._process(1.0/60.0);await process_frame
 check(not visual.preparing and visual.globe.visible and not visual.loading.visible and visual.last_degree==7.0,"Prepared image uses current exploration state after returning")
 check(visual.globe.surface_map!=null and visual.globe.cloud_map!=null,"Actual planet textures are installed")
 var visual_id:int=visual.get_instance_id();var texture:Texture2D=visual.globe.surface_map
 scene.select_system(0);await process_frame;scene.select_system(6);await process_frame
 check(panel.cards[id].visual.get_instance_id()==visual_id and visual.globe.surface_map==texture and not visual.preparing,"Prepared image and controls are reused on revisit")
 for other in panel.cards:
  panel.cards[other].list_button.pressed.emit()
  for frame in 600:
   if not panel.cards[other].visual.preparing:break
   scene._process(1.0/60.0);await process_frame
  check(panel.selected_planet_id==other and not panel.cards[other].visual.preparing and panel.cards[other].visual.planet_id==other,"Actual navigation signal installs the selected planet image")
 panel.cards[id].list_button.pressed.emit();scene._process(0.0)
 await product_capture(scene,"planet-loading-ready")
 FileAccess.open("res://.runtime/planet-loading.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"production_time":g.production_time(),"planets":panel.cards.size(),"saving":g.save_enabled}))
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
 scene.queue_free();await process_frame
 print("PLANET_LOADING ",checks," checks ",failures," failures");quit(1 if failures else 0)
