extends SceneTree
## Finite, ordinary enemy encounters and finite wallet. No direct HP or hit edits.
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.target_spatial_source=battle_read_model
  g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var scene
var events:Dictionary={}
var trace:Array=[]
var drop_ids:Dictionary={}
var compact_fires:=0
var quote:Dictionary={}
var admissions:=0
var observed_native_death:=false
var death:Dictionary={}
var wave_residuals:Array=[]
var newborns:Array=[]
var debt_peak:Dictionary={}
func observe(kind:String,info:Dictionary)->void:
 events[kind]=int(events.get(kind,0))+1
 if kind=="fire" and info.has("native_laser"):compact_fires+=1
 if kind=="fire" and not quote.is_empty():
  if info.has("shot") and str(info.shot.get("key",""))=="laser" and int(info.shot.get("mount",-1))==0:
   newborns.append({"serial":int(info.shot.serial),"damage":float(info.shot.damage),"native":false})
  elif info.has("native_laser") and scene.game.native_execution!=null:
   var serial=int(info.native_laser.serial)
   var current=flight_values(scene.game.native_execution.kernel)
   if current.has(serial) and int(current[serial].weapon_index)==0:newborns.append({"serial":serial,"damage":float(current[serial].damage),"native":true})
 if kind=="wave_clear":
  var serials:Array=[]
  for shot in scene.game.projectiles:serials.append(int(shot.serial))
  var seen:Dictionary={}
  for serial in serials:seen[serial]=true
  wave_residuals.append({"game":scene.game.production_time(),"serials":serials,"unique":serials.size()==seen.size(),"next_frame":[]})
 if kind in ["encounter","wave_clear","collect","retreat","upgrades_completed","native_execution_handoff","state","upgrade"]:
  trace.append({"kind":kind,"game":scene.game.production_time(),"group":scene.game.group_index,"info":info.duplicate(true),"resources":scene.game.profile.resources.duplicate(true),"projectiles":scene.game.projectiles.size(),"native":scene.game.native_execution!=null})
 if kind=="retreat":
  observed_native_death=scene.game.native_execution!=null or admissions>0
  death={"game":scene.game.production_time(),"player":scene.game.player.duplicate(true),"debt":scene.game.enhancement_deferred.duplicate(true),"projectiles":scene.game.projectiles.size(),"native_active":scene.game.native_execution!=null,"handoffs":scene.game.native_handoff_count,"reason":info.duplicate(true)}
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
 root.get_texture().get_image().save_png("res://.runtime/"+name+".png")
func flight_values(kernel)->Dictionary:
 var result:Dictionary={}
 for f in kernel.export_handoff().flights:result[int(f.view.serial)]={"damage":f.damage,"weapon_index":f.weapon_index}
 return result
func purchase()->void:
 var g=scene.game
 scene.set_process(false)
 var panel=scene.equipment_panel
 panel.set_upgrade_amount(1);panel.refresh()
 var item:Dictionary=panel.items.get("weapons_0",{})
 assert(not item.is_empty(),"visible equipment card")
 var cost:Dictionary=g.slot_upgrade_cost("weapons",0,1)
 var wallet:Dictionary=g.profile.resources.duplicate(true)
 var level:int=int(g.weapon_entries()[0].level)
 var old_flights=flight_values(g.native_execution.kernel)
 var old_damage:float=float(g.native_execution.weapons[0].damage)
 var displayed=str(item.cost)
 var expected=scene.cost_text(cost)
 assert(displayed==expected and bool(item.direct_upgradeable),"UI quote matches affordable authority")
 panel.upgrade_card("weapons_0")
 var after_flights=flight_values(g.native_execution.kernel) if g.native_execution!=null else {}
 var survivors:=0
 for serial in old_flights:
  if after_flights.has(serial):
   survivors+=1
   assert(float(after_flights[serial].damage)==float(old_flights[serial].damage),"existing flight keeps damage")
 var debited:=true
 for id in cost:
  if GrowthNumber.compare(g.profile.resources.get(id,0),GrowthNumber.subtract(wallet.get(id,0),cost[id]))!=0:debited=false
 panel.refresh()
 quote={"displayed":displayed,"expected":expected,"cost":cost,"wallet_before":wallet,"wallet_after":g.profile.resources.duplicate(true),"debit_once":debited,"level_before":level,"level_after":int(g.weapon_entries()[0].level),"old_damage":old_damage,"new_damage":float(g.native_execution.weapons[0].damage) if g.native_execution!=null else -1.0,"active_before":old_flights.size(),"survivors":survivors,"active_after":after_flights.size(),"prior_serials":old_flights.keys(),"post_quote":str(panel.items.get("weapons_0",{}).get("cost","")),"post_expected":scene.cost_text(g.slot_upgrade_cost("weapons",0,1))}
 assert(debited and quote.level_after==level+1 and quote.post_quote==quote.post_expected,"purchase updates quote/level/wallet once")
 scene.set_process(true)
func run()->void:
 assert(ClassDB.class_exists("SpaceCombatKernel") and GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open(),"candidate DLL loaded")
 var mode=OS.get_environment("INTEGRATION_MODE")
 assert(mode in ["waves","death"],"explicit integration mode")
 var ui=load("res://main.tscn").instantiate();ui.set_script(UI);scene=ui
 ui.automation_args=["--capture"];ui.music_on=false
 root.add_child(ui);current_scene=ui;ui.automation_args=[];ui.set_process(false)
 var g=ui.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;ui.beginner_guide.hide()
 g.profile.cleared=range(1,31);g.profile.highestLevel=31;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear()
 if mode=="waves":
  g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":3000.0,"2":300.0}
  g.profile.loadout={"weapons":[{"key":"laser","level":5},{"key":"cannon","level":5},{"key":"missile","level":5},{"key":"longLaser","level":5}],"defence":[{"key":"armour","level":5},{"key":"shield","level":5}]}
 else:
  g.profile.selectedShip="Frigate";g.profile.resources={"1":300.0,"2":30.0}
  var weapon_slots:Array=[];var defence_slots:Array=[]
  for i in g.active_slot_count("weapons"):weapon_slots.append({"key":"laser","level":1})
  for i in g.active_slot_count("defence"):defence_slots.append({"key":"armour" if i%2==0 else "shield","level":1})
  g.profile.loadout={"weapons":weapon_slots,"defence":defence_slots}
  g.profile.enhancementLevel=40
 g.invalidate_stat_cache();g.reset_player()
 ui.refresh_structure();ui.refresh_tab_visibility();ui.select_system(0)
 g.event.connect(observe)
 g.native_execution_auto=true
 var stage=1 if mode=="waves" else 30
 assert(g.start(stage,false),"real table stage starts")
 var initial={"stage":stage,"ship":g.profile.selectedShip,"wallet":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"enhancement_level":g.profile.enhancementLevel,"save":g.save_enabled,"cache":g.stat_cache_enabled,"speed":g.speed,"render":RenderingServer.get_current_rendering_method()}
 var began=Time.get_ticks_usec();var first_clock=g.production_time();var bought=false;var crew_assigned=false;var first_admit=false;var first_death_frame=false;var reason="time_limit"
 ui.set_process(true)
 while g.production_time()-first_clock<75.0 and Time.get_ticks_usec()-began<110000000:
  await RenderingServer.frame_post_draw
  if g.native_execution!=null and not first_admit:admissions+=1;first_admit=true
  for d in g.drops:drop_ids[int(d.uid)]=true
  if not g.enhancement_deferred.is_empty():debt_peak=g.enhancement_deferred.duplicate(true)
  for item in wave_residuals:
   if item.next_frame.is_empty() and g.production_time()>float(item.game):
    for shot in g.projectiles:item.next_frame.append(int(shot.serial))
  if mode=="waves":
   if not bought and g.native_execution!=null and compact_fires>0 and g.state==BattleGame.State.COMBAT:
    purchase();bought=true
   if bought and not crew_assigned and (newborns.size()>0 or g.production_time()>4.5):
    assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"ordinary automated upgrades")
    crew_assigned=true
   if bought and int(events.get("wave_clear",0))>=2 and int(events.get("encounter",0))>=3 and int(events.get("collect",0))>0:
    reason="coverage_endpoint";break
  else:
   if death.size()>0 and not first_death_frame:
    capture("natural-death-entry");first_death_frame=true
   if death.size()>0 and g.state!=BattleGame.State.RETREAT:
    reason="death_and_retreat_exit";break
 ui.set_process(false)
 capture("natural-"+mode+"-end")
 var row={"mode":mode,"reason":reason,"dll_sha256":FileAccess.get_sha256("res://bin/space_native.dll"),"initial":initial,"events":events,"trace":trace,"drop_ids":drop_ids.keys(),"compact_fires":compact_fires,"quote":quote,"newborns":newborns,"wave_residuals":wave_residuals,"debt_peak":debt_peak,"admissions":admissions,"death":death,"end":{"game":g.production_time(),"state":g.state,"group":g.group_index,"player":g.player.duplicate(true),"debt":g.enhancement_deferred.duplicate(true),"drops":g.drops.duplicate(true),"projectiles":g.projectiles.size(),"native_active":g.native_execution!=null,"handoffs":g.native_handoff_count,"wallet":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"rng":str(g.rng.state)},"wall_seconds":(Time.get_ticks_usec()-began)/1000000.0}
 FileAccess.open("res://.runtime/integration-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(row))
 print("INTEGRATION_RESULT ",mode," ",reason," events=",JSON.stringify(events)," compact=",compact_fires)
 ui.queue_free();await process_frame;quit()
