extends SceneTree
# Graphical staged regression, not a natural playthrough or performance test.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 if DisplayServer.get_name()=="headless":printerr("Requires graphical display");quit(2);return
 root.size=Vector2i(1180,812)
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 await process_frame;await process_frame
 var g=scene.game;g.save_enabled=false;g.profile.highestLevel=7;g.profile.cleared=range(1,7);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.resources["1"]=1000000000.;g.profile.resources["2"]=1000000000.
 for i in 3:
  check(g.equip_slot("weapons",i,"longLaser" if i==1 else "laser") and g.upgrade_slot("weapons",i,18 if i==2 else 17),"parent weapon levels18/18/19")
 check(g.upgrade_slot("defence",0,22) and g.equip_slot("defence",1,"shield") and g.upgrade_slot("defence",1,15),"parent armour23/shield16")
 var fixture=g.portable_save_data()
 for size in [Vector2i(1180,812),Vector2i(960,600),Vector2i(960,540)]:
  root.size=size;await process_frame;await process_frame
  var cases=[]
  for uid in [0,20,50,300,400]:cases.append({"route":"alpha","point":4,"uid":uid})
  if size==Vector2i(960,600):
   for route in ["alpha","beta","gamma","delta"]:
    for point in 10:
     if route!="alpha" or point!=4:cases.append({"route":route,"point":point,"uid":300})
  for c in cases:
   g.load_progress_data(fixture.duplicate(true));g.resume_progress();g.pending_unlocks.clear();scene.fx_time=42.
   check(g.load_hyperspace_routes() and g.start_hyperspace(c.route,5),"paid dispatch "+str(c))
   g.uid=c.uid;g.group_index=c.point;g.spawn_group();g.paused=true
   check(g.manual_hyperspace.active and not g.enemies.is_empty(),"production geometry does not abort "+str(size)+str(c))
   if not g.manual_hyperspace.active:continue
   var state=g.enemies.map(func(e):return [e.id,e.x,e.y,e.hp,e.max_hp,e.max_shield,e.dmgMultiple,e.res_ratio])
   var errors=scene.validate_explicit_formation()
   check(errors.is_empty(),"actual independent-yaw envelopes "+str(size)+str(c)+str(errors))
   check(state==g.enemies.map(func(e):return [e.id,e.x,e.y,e.hp,e.max_hp,e.max_shield,e.dmgMultiple,e.res_ratio]),"geometry leaves authored combat state intact")
   if size==Vector2i(960,600) and c.route=="alpha" and c.point==4 and c.uid==300:
    scene.fx_time+=5.;scene.encounter_presentation.sync(g,0);scene.refresh_tab_visibility();scene.select_system(9);scene.hyperspace_panel.dirty=true;scene.hyperspace_panel.refresh();scene.refresh_draw_layers(0);scene.battle_layer.queue_redraw();scene.battle_hud_layer.queue_redraw()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var folder=OS.get_environment("COMPACT_GEOMETRY_EVIDENCE")
    if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("alpha5-compact-fixed.png"))
    # Malformed same-centre actors must still fail; this never alters source data.
    var guard=g.enemies[0];var leader=g.enemies.filter(func(e):return int(e.size)>=4)[0]
    var original=Vector2(guard.x,guard.y);guard.x=leader.x;guard.y=leader.y
    check(not scene.validate_explicit_formation().is_empty(),"real overlap remains rejected in compact window")
    guard.x=original.x;guard.y=original.y
   g.manual_hyperspace.finish(g,false)
 scene.queue_free();await process_frame
 print("COMPACT GEOMETRY: ",checks," checks, ",failures," failures; staged scenes only")
 quit(1 if failures else 0)
