extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 var impacts:Dictionary={}
 func weapon_impact(shot:Dictionary,point:Vector2)->void:
  impacts[int(shot.serial)]=battle_point(point)
  super.weapon_impact(shot,point)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  battle_read_model.setup(self);g.target_spatial_source=battle_read_model
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var checks:=0
var failures:=0
var cases:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var hulls=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
 for weapon in ["laser","longLaser","missile","cannon"]:
  for size_class in range(1,7):
   var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];scene.music_on=false
   root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
   var g=scene.game;g.save_enabled=false;g.rng.seed=1975;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
   g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.selectedShip=hulls[(size_class-1)%5]
   g.profile.loadout={"weapons":[{"key":weapon,"level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
   g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
   var enemy:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
   enemy.uid=500+size_class;enemy.slot=0;enemy.x=286.0;enemy.y=250.0;enemy.size=size_class;enemy.hp=1e9;enemy.max_hp=1e9;enemy.equipment=[];enemy.cooldowns=[];enemy.explicit_formation=true;enemy.formation_count=1
   g.enemies.append(enemy)
   var tier:String=["normal","boss","ultimate"][(size_class-1)%3]
   g.db.groups[str(int(g.db.levels[g.stage-1].groups[g.group_index-1].id))].combatTier=tier
   g.publish_encounter_geometry()
   scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
   g.native_execution_auto=false;g.combat_presentation=null
   var geometry=scene
   var row:Dictionary=scene.visual_config.ships["enemy_"+str(size_class)]
   var tex:Texture2D=scene.ship_hull_texture("enemy_"+str(size_class));var used:Rect2i=tex.get_image().get_used_rect()
   var rect:Rect2=scene.enemy_hull_rect(enemy,geometry.enemy_render_width(enemy))
   var visible_center:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*0.5)/tex.get_size()*rect.size
   check(visible_center.length()<0.0001,"enemy visible centre matches target anchor")
   var config:Dictionary=scene.ship_view.manifest.hulls[g.profile.selectedShip]
   var local_center:Vector3=preload("res://scripts/ship_geometry_convention.gd").body_center(config)
   var measured:Array=[];var fire_points:Array=[]
   var callback=func(kind:String,info:Dictionary):
    if kind=="fire" and not bool(info.shot.hostile):
     var shot:Dictionary=info.shot
     fire_points.append(Vector2(info.x,info.y))
     check(geometry.battle_point(Vector2(info.x,info.y)).distance_to(scene.ship_view.screen_muzzle_for_slot(0,int(shot.get("salvo_ordinal",0))))<1.0,"GDScript launch matches visible muzzle")
    if kind=="projectile_impact" and not bool(info.shot.hostile):
     var shot:Dictionary=info.shot;var contact:Vector2=geometry.battle_point(info.pos)
     if shot.has("fixed_screen_step"):
      contact=Vector2(shot.fixed_screen_origin)+Vector2(shot.fixed_screen_step)*(Vector2(info.pos)-Vector2(shot.launch_point)).dot(g.projectile_direction(shot))
      var polygon:PackedVector2Array=scene.battle_read_model.ballistic_shape(shot.target).hull;var error=INF
      for i in polygon.size():error=minf(error,contact.distance_to(Geometry2D.get_closest_point_to_segment(contact,polygon[i],polygon[(i+1)%polygon.size()])))
      check(error<0.1,"GDScript pulse uses actual hull surface contact")
     else:check(contact.distance_to(geometry.entity_render_position(shot.target))<0.05,"GDScript centre hit uses current target anchor")
     check(scene.impacts.has(int(shot.serial)) and Vector2(scene.impacts[int(shot.serial)]).distance_to(contact)<0.05,"GDScript effect matches actual logical impact")
     measured.append(contact)
    if kind=="beam_hit" and not bool(info.shot.hostile):
     check(geometry.battle_point(g.target_point(enemy)).distance_to(geometry.entity_render_position(enemy))<0.05,"beam target centre uses shared transform")
     measured.append(geometry.entity_render_position(enemy))
   g.event.connect(callback)
   var first:Vector2=geometry.enemy_render_position(enemy)
   for step in 360:
    scene._process(1.0/60.0)
    if not measured.is_empty():break
   check((scene.ship_view.ship.transform*local_center).distance_to(scene.ship_view.orbit_center)<0.0001,"player complete assembly centres on target anchor")
   check(scene.ship_view.camera.unproject_position(scene.ship_view.ship.global_transform*local_center).distance_to(scene.player_render_position())<0.05,"visible player centre equals incoming target anchor")
   check(not measured.is_empty(),"actual hit observed "+weapon+str(size_class))
   check(not fire_points.is_empty(),"actual birth observed")
   check(geometry.enemy_render_position(enemy).distance_to(first)>0.01,"encounter entrance changes displayed position")
   check(absf(scene.enemy_render_width(enemy)-geometry.enemy_render_width(enemy))<0.0001,"display and simulation width identical")
   var width:float=geometry.enemy_render_width(enemy);var packet=geometry.enemy_recognition_geometry(enemy)
   cases.append({"weapon":weapon,"enemy_size":size_class,"player":g.profile.selectedShip,"tier":tier,"scale":enemy.hull_scale,"width":width,"hits":measured.size(),"entry_displacement":geometry.enemy_render_position(enemy).distance_to(first)})
   if size_class in [1,4,6] and weapon=="laser":
    scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
    await process_frame;await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://.runtime")
    root.get_texture().get_image().save_png("res://.runtime/gds-pulse-"+str(size_class)+".png")
   g.event.disconnect(callback)
   if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
   scene.queue_free();await process_frame
   print("GEOMETRY_CASE ",weapon," ",size_class)
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 var out=FileAccess.open("res://.runtime/gds-hull-weapon-matrix.json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"));out.close()
 print("GDS_HULL_WEAPON_MATRIX ",checks," checks ",failures," failures");quit(1 if failures else 0)
