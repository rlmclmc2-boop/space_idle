extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
func _initialize()->void:call_deferred("run")
func run()->void:
 var width=OS.get_environment("QA_MANUAL_WIDTH")
 if not width.is_empty():root.size=Vector2i(int(width),int(OS.get_environment("QA_MANUAL_HEIGHT")))
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true
 await process_frame;await process_frame
 var g=scene.game;g.save_enabled=false;g.rng.seed=20261005;g.profile.hyperspace.random_state="123456789";g.profile.highestLevel=33;g.profile.cleared=range(1,33);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.loop=false;g.enemies.clear();g.projectiles.clear();g.state=g.State.LEVEL_SELECT
 for ship in g.db.ships.keys():
  if g.ship_unlocked(ship) and g.active_slot_count("defence",ship)>1:g.switch_ship(ship);break
 g.equip_slot("defence",1,"shield")
 if not g.load_hyperspace_routes() or not g.start_hyperspace("alpha",5):printerr("Probe lawful route failed");quit(2);return
 var records:Array=[];var rejected:=0
 # UID bases are explicit presentation fixtures, never restored player serials or campaign simulation.
 var uid_bases:Array=[138]
 for base_uid in uid_bases:
  for point in [4,10]:
   g.enemies.clear();g.projectiles.clear();scene.enemy_poses.clear();g.uid=base_uid;g.group_index=point-1;g.state=g.State.TRAVEL;scene.fx_time=0
   g.spawn_group()
   var errors=scene.validate_explicit_formation()
   if not errors.is_empty():rejected+=1
   records.append({"base_uid":base_uid,"point":point,"errors":errors,"state_after_production_event":g.state,"actors":g.enemies.map(func(e):return {"uid":e.uid,"slot":e.slot,"id":e.id,"x":e.x,"y":e.y,"variance":scene.enemy_pose(e).variance})})
   if rejected>0:break
  if rejected>0:break
 var folder=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 FileAccess.open(folder+"/probe.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":"No battle ticks; lawful alpha5 actual groups4/10 with explicit UID base138, lawful same two-defence ship/shield as core, seed20261005/random_state123456789, stop at first rejection and fx_time0; production on_event validator retained","selected_ship":g.profile.selectedShip,"root_size":str(root.size),"viewport":str(root.get_visible_rect()),"screen_scale":scene.enemy_recognition_screen_scale(),"rejected":rejected,"records":records},"\t"))
 print("FORMATION_PROBE ",records.size()," cases ",rejected," rejected");quit()
