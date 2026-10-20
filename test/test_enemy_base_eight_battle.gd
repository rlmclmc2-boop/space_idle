extends SceneTree
## Real main scene, isolated save-disabled QA formation; no screenshot compositing.
const KEYS=["scout","sentry","interceptor","swarm","anchor","reactive","shielded","command"]
var friendly_fires:=0
var hostile_fires:=0
var hits:=0
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var output:=OS.get_environment("ENEMY_BASE_OUTPUT");assert(not output.is_empty())
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1373,883)
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.rng.seed=81019
 g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101
 g.profile.selectedShip="Heavy_Battleship";g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout={"weapons":[{"key":"cannon","level":1},{"key":"missile","level":1},{"key":"laser","level":1},{"key":"longLaser","level":1},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":1}]}
 g.invalidate_stat_cache();g.reset_player();g.player.armour=1e8
 scene.ship_view.set_hull("Heavy_Battleship");scene.current_hull="Heavy_Battleship";scene._set_reference_dimensions();scene.ship_view.set_loadout(g.weapon_entries(),g.active_slot_count("weapons"))
 assert(g.start(1,false));g.group_index=1;g.spawn_group();g.player.armour=1e8
 var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in KEYS.size():
  var enemy:Dictionary=template.duplicate(true)
  enemy.uid=81000+i;enemy.slot=i;enemy.archetype_id=KEYS[i];enemy.armourType=2 if i<2 else 1;enemy.shieldType=1
  enemy.size=1+i%6
  enemy.x=66.0+110.0*(i%5);enemy.y=110.0+144.0*(i/5)
  enemy.hp=1e8;enemy.max_hp=1e8;enemy.shield=1e8;enemy.max_shield=1e8;enemy.shieldRecovery=0.0
  enemy.equipment=[{"name":"laser_mon"}];enemy.cooldowns=[0.0]
  enemy.explicit_formation=true;enemy.formation_columns=5;enemy.formation_count=8;enemy.size_formation=true
  g.enemies.append(enemy)
 g.event.connect(func(kind:String,info:Dictionary):
  if kind=="fire":
   if info.get("shot",{}).get("hostile",false):hostile_fires+=1
   else:friendly_fires+=1
  if kind=="hit":hits+=1)
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 for frame in 160:
  await process_frame
  if frame>=110 and friendly_fires>0 and hostile_fires>0 and hits>0:break
 assert(friendly_fires>0 and hostile_fires>0 and hits>0,"Actual combat did not fire and settle damage")
 g.paused=true;scene.fx_time=3.0;scene.shake=0.0
 g.projectile_clear();scene.projectile_visuals.clear();scene.floats.clear();scene.damage_pending.clear()
 scene.rail_events.clear();scene.missile_events.clear();scene._pulse_events.clear()
 scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var rows:Array=[]
 var reference_path:=OS.get_environment("ENEMY_BASE_REFERENCE")
 var reference:Dictionary={}
 if not reference_path.is_empty():reference=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
 var baseline_only:=OS.get_environment("ENEMY_BASE_BASELINE")=="1"
 for enemy in g.enemies:
  var key:String=scene.enemy_ship_key(enemy)
  assert(key=="enemy_opening_"+str(enemy.archetype_id),"Archetype fell back")
  var texture:Texture2D=scene.ship_hull_texture(key)
  var used:Rect2i=texture.get_image().get_used_rect()
  var rect:Rect2=scene.enemy_hull_rect(enemy,scene.enemy_render_width(enemy))
  var centre:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*.5)/texture.get_size()*rect.size
  assert(centre.length()<0.001,"Display alpha centre left combat centre")
  var used_size:Vector2=Vector2(used.size)/texture.get_size()*rect.size
  var angle:float=scene.enemy_render_angle(enemy)
  var rotated:=Vector2(used_size.x*absf(cos(angle))+used_size.y*absf(sin(angle)),used_size.x*absf(sin(angle))+used_size.y*absf(cos(angle)))
  if not baseline_only:check(rotated.x<=90.401 and rotated.y<=79.334,"approved single-cell hull display size for actor sizes1..6")
  if not baseline_only:check(is_equal_approx(rotated.x,90.4) or is_equal_approx(rotated.y,79.3333333333),"uniform fit reaches approved size")
  var record=scene.retained_contacts.records.get(int(enemy.uid))
  check(record!=null and record.supported,"retained contact uses actual hull")
  check((record.hull.data.rect.size*record.hull.scale).is_equal_approx(rect.size),"retained and canonical hull dimensions match")
  var point:Vector2=scene.enemy_render_position(enemy)
  if not reference.is_empty():
   var expected_position=reference.rows[rows.size()].position
   check(str(point)==str(expected_position),"authored display position identical to main reference")
  rows.append({"display_aabb":rotated,"size":enemy.size,"archetype":enemy.archetype_id,"visual_key":key,"texture":scene.visual_config.ships[key].texture,"geometry_texture":scene.visual_config.ships[key].geometry_texture,"centre_error":centre.length(),"position":scene.enemy_render_position(enemy),"width":scene.enemy_render_width(enemy)})
 # Compare actual retained node rectangles with canonical layout and the clip.
 # Baseline mode records the pre-fix error; normal runs enforce alignment.
 var meter_baseline:=OS.get_environment("ENEMY_METERS_BASELINE")=="1"
 var meters:Array=[]
 var edge_meters:Array=[]
 for enemy in g.enemies:
  var record=scene.retained_contacts.records[int(enemy.uid)]
  var centre:Vector2=record.root.position
  var health:=Rect2(centre+record.health.position,record.health.data.rect.size)
  var shield:=Rect2(centre+record.shield.position,record.shield.data.rect.size)
  var canonical:Dictionary=scene.enemy_status_layout(enemy,centre,scene.enemy_render_width(enemy),scene.enemy_render_angle(enemy),PackedVector2Array())
  var error:float=absf(health.get_center().x-centre.x)
  meters.append({"key":enemy.archetype_id,"centre":centre,"health":health,"shield":shield,"centre_error":error})
  if not meter_baseline:
   check(error<0.001 and absf(shield.get_center().x-centre.x)<0.001,"both meters centred on rendered hull")
   check(is_equal_approx(health.position.x,canonical.health.position.x) and is_equal_approx(health.size.x,canonical.health.size.x),"retained and canonical horizontal layout agree")
   var clip:Rect2=scene.battle_clip.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,scene.battle_clip.size)
   for node in [record.health,record.shield]:
    var screen:Rect2=node.get_global_transform_with_canvas()*node.data.rect
    check(clip.encloses(screen),"entire actual meter is within rendered clip")
 # Probe both edge columns with camera shake; restore the QA actor afterwards.
 var edge_enemy:Dictionary=g.enemies[4]
 var saved_x:float=float(edge_enemy.x)
 for edge_x in [20.0,552.0]:
  edge_enemy.x=edge_x
  for shake_x in [-9.0,0.0,9.0]:
   scene.retained_contacts.sync(Vector2(shake_x,0),false)
   var record=scene.retained_contacts.records[int(edge_enemy.uid)]
   var centre:Vector2=record.root.position
   var rect:=Rect2(centre+record.health.position,record.health.data.rect.size)
   var canonical:Dictionary=scene.enemy_status_layout(edge_enemy,centre,scene.enemy_render_width(edge_enemy),scene.enemy_render_angle(edge_enemy),PackedVector2Array())
   edge_meters.append({"x":edge_x,"shake":shake_x,"centre":centre,"health":rect})
   if not meter_baseline:
    check(absf(rect.get_center().x-centre.x)<0.001,"edge meter remains centred with shake")
    check(rect.position.x>=5.999 and rect.end.x<=566.001 and rect.size.x>0,"both edge endpoints remain in safe clip")
    check(is_equal_approx(rect.position.x,canonical.health.position.x) and is_equal_approx(rect.size.x,canonical.health.size.x),"edge retained/canonical agree")
 edge_enemy.x=saved_x;scene.retained_contacts.sync(Vector2.ZERO,false)
 # Fallback hulls do not inherit the base-eight display policy.
 var fallback:Dictionary=g.enemies[0].duplicate(true);fallback.uid=89999;fallback.slot=99;fallback.erase("archetype_id")
 for size in range(1,7):
  fallback.size=size
  check(scene.enemy_hull_rect(fallback,25.0).size==Vector2(25,50),"legacy fallback display unchanged")
 # The immutable native view consumes the same published appearance and pose.
 var geometry=preload("res://scripts/simulation_geometry_authority.gd").new();geometry.prepare(scene,g)
 var view=preload("res://scripts/simulation_geometry_view.gd").new()
 var expected:Array=[]
 for enemy in g.enemies:
  expected.append(scene.enemy_hull_rect(enemy,scene.enemy_render_width(enemy)).size)
  view.descriptor(int(enemy.uid),geometry.display_descriptor(enemy))
 view.apply(geometry.display_frame(g.enemies,false));scene.simulation_geometry_view=view
 for i in g.enemies.size():
  var enemy=g.enemies[i]
  check(scene.enemy_hull_rect(enemy,scene.enemy_render_width(enemy)).size.is_equal_approx(expected[i]),"native view retains display size")
 scene.simulation_geometry_view=null;geometry.close({"providers":{},"spatial":g.target_spatial_source})
 await process_frame;await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 assert(image.save_png(output.path_join("base-eight-battle.png"))==OK)
 # A second actual window render provides more pixels for the wide hulls.
 root.size=Vector2i(1952,1256)
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 var large:=root.get_texture().get_image()
 assert(large.save_png(output.path_join("base-eight-battle-large.png"))==OK)
 var result={"meters":meters,"edge_meters":edge_meters,"checks":checks,"failures":failures,"fixture":"save-disabled held-health QA in actual main.tscn; original authored coordinates, no grid allocation","keys":KEYS,"friendly_fires":friendly_fires,"hostile_fires":hostile_fires,"hits":hits,"native":g.native_execution!=null,"engine":Engine.get_version_info().string,"window_png":[image.get_width(),image.get_height()],"large_png":[large.get_width(),large.get_height()],"rows":rows}
 FileAccess.open(output.path_join("battle.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("ENEMY_BASE_BATTLE ",JSON.stringify(result));quit(1 if failures else 0)
