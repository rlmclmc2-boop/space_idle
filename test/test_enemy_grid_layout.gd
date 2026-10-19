extends SceneTree
const GRID=preload("res://scripts/enemy_grid_layout.gd")
const KEYS=["scout","sentry","interceptor","swarm","anchor","reactive","shielded","command"]
var checks:=0
var failures:=0
var fires:=0
var hits:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func actors(count:int,elite:=0,boss:=false)->Array:
 var out:Array=[]
 for i in count:out.append({"uid":i+1,"slot":i,"size":6 if boss and i==0 else 4 if i<elite else 1,"encounter_leader":boss and i==0})
 return out
func verify_pack(plan:Dictionary,rows:Array)->void:
 check(not plan.overflow,"fits15 cells")
 check(plan.placements.size()==rows.size(),"no actors discarded")
 var boxes:Array=[]
 for e in rows:
  var r:Rect2i=plan.placements[int(e.uid)]
  check(r.position.x>=0 and r.position.y>=0 and r.end.x<=5 and r.end.y<=3,"footprint in grid")
  for other in boxes:check(not r.intersects(other),"no cell overlap")
  boxes.append(r)
func units()->void:
 for count in range(1,16):verify_pack(GRID.pack(actors(count)),actors(count))
 for count in range(1,13):
  var rows=actors(count,1);verify_pack(GRID.pack(rows),rows)
 var rows=actors(9,2);verify_pack(GRID.pack(rows),rows)
 rows=actors(10,0,true)
 for front in [false,true]:
  var plan=GRID.pack(rows,front);verify_pack(plan,rows)
  check(plan.placements[1].position.y==(1 if front else 0),"boss can use top/front two rows")
 var mixed=actors(7,0,true);mixed[1].size=4;verify_pack(GRID.pack(mixed),mixed)
 var before=rows.duplicate(true);var plan=GRID.pack(rows)
 rows.remove_at(1);check(GRID.valid_for(plan,rows),"death retains survivor allocation")
 check(before[0]==rows[0],"packing never mutates actor values")
 var overloaded=GRID.pack(actors(15,2));check(overloaded.overflow and overloaded.placements.is_empty() and overloaded.required_cells==21,"21-cell encounter atomically preserves legacy display")
 for ratio in [Vector2(174,272),Vector2(343,301),Vector2(461,305),Vector2(364,315)]:
  for span in [Vector2i.ONE,Vector2i(2,2),Vector2i(3,2)]:
   var p={"placements":{1:Rect2i(Vector2i.ZERO,span)}};var body=GRID.body_rect(p,{"uid":1})
   for angle in [-.07,0,.07]:
    var scale=GRID.fit_scale(ratio,body.size,angle);var c=absf(cos(angle));var s=absf(sin(angle))
    var aabb=Vector2(ratio.x*c+ratio.y*s,ratio.x*s+ratio.y*c)*scale
    check(aabb.x<=body.size.x+.001 and aabb.y<=body.size.y+.001,"rotated equal-aspect hull fits")
 print("GRID_UNIT ",checks," checks ",failures," failures")
func plane_bounds(view,plane:MeshInstance3D)->Rect2:
 var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
 var opaque:Rect2=Rect2(texture.get_image().get_used_rect());var size:Vector2=(plane.mesh as PlaneMesh).size
 var result:=Rect2();var first:=true
 for pixel in [opaque.position,Vector2(opaque.end.x,opaque.position.y),opaque.end,Vector2(opaque.position.x,opaque.end.y)]:
  var uv:Vector2=pixel/Vector2(texture.get_size());var point:Vector2=view.camera.unproject_position(plane.to_global(Vector3((uv.x-.5)*size.x,0,(uv.y-.5)*size.y)))
  if first:result=Rect2(point,Vector2.ZERO);first=false
  else:result=result.expand(point)
 return result
class Ruler extends Node2D:
 var plan:Dictionary
 var hulls:Array=[]
 var player_front:=0.0
 var enemy_front:=0.0
 func _draw()->void:
  var font:=ThemeDB.fallback_font
  for c in 6:draw_line(Vector2(c*114.4,0),Vector2(c*114.4,GRID.AREA.end.y),Color(0.2,.9,1,.4),1,true)
  for r in 4:draw_line(Vector2(0,r*GRID.AREA.size.y/3.0),Vector2(572,r*GRID.AREA.size.y/3.0),Color(0.2,.9,1,.4),1,true)
  for id in plan.placements:
   var cell=GRID.cell_rect(plan,{"uid":id});draw_rect(cell.grow(-2),Color(1,.8,.25,.8),false,1.5)
  if player_front>0:
   draw_line(Vector2(5,GRID.AREA.end.y),Vector2(5,player_front),Color("fbdd8c"),2,true)
   draw_string(font,Vector2(13,(GRID.AREA.end.y+player_front)*.5),"reserved %.1f"%(player_front-GRID.AREA.end.y),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fbdd8c"))
   if enemy_front>0:
    draw_line(Vector2(560,enemy_front),Vector2(560,player_front),Color("8cfbb2"),2,true)
    draw_string(font,Vector2(330,(enemy_front+player_front)*.5),"nearest %.1f"%(player_front-enemy_front),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8cfbb2"))
func capture(case:String,output:String)->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false;root.add_child(scene);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.rng.seed=102019
 g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 check(g.start(1,false),"real battle starts");g.group_index=1;g.spawn_group()
 if case!="ordinary":
  var encounter:Dictionary=g.db.levels[g.stage-1].groups[g.group_index-1]
  g.db.groups[str(int(encounter.id))].combatTier="boss" if case.begins_with("boss") else "elite"
 g.profile.selectedShip="Heavy_Battleship";g.profile.loadout={"weapons":[],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
 for key in ["cannon","missile","laser","longLaser","cannon"]:g.profile.loadout.weapons.append({"key":key,"level":1})
 g.invalidate_stat_cache();g.reset_player();g.player.armour=1e10;g.player.shield=1e10
 scene.current_hull="Heavy_Battleship";scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions();scene.ship_view.set_loadout(g.weapon_entries(),g.active_slot_count("weapons"))
 check(g.active_slot_count("weapons")==5,"fifth hull five active weapons")
 var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
 var count:int=15 if case=="ordinary" else 5
 for i in count:
  var e=template.duplicate(true);e.uid=91000+i;e.slot=i;e.archetype_id=KEYS[i%8];e.size=1+(i%3);e.encounter_leader=false
  if case=="elite" and i<2:e.size=4;e.archetype_id="sentry" if i==0 else "anchor"
  if case.begins_with("boss") and i==0:e.size=6;e.encounter_leader=true;e.archetype_id="command"
  e.armourType=2 if e.archetype_id in ["scout","sentry"] else 1;e.shieldType=1
  e.x=66.0+(i%5)*110.0;e.y=110.0+(i/5)*144.0
  e.hp=1e10;e.max_hp=1e10;e.shield=1e10;e.max_shield=1e10;e.shieldRecovery=0.0
  e.equipment=[{"name":"laser_mon"}];e.cooldowns=[0.0];e.formation_columns=5;e.formation_count=count;e.explicit_formation=false;e.size_formation=true
  g.enemies.append(e)
 scene.enemy_poses.clear();scene.enemy_grid_plan=GRID.pack(g.enemies,case=="boss-front");scene.fixed_layout_signature.clear()
 g.event.connect(func(kind:String,_info:Dictionary):
  if kind=="fire":fires+=1
  if kind=="hit":hits+=1)
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 for frame in 140:
  await process_frame
  if frame>=100 and fires>0 and hits>0:break
 check(fires>0 and hits>0,"actual battle fired and settled")
 check(scene.ship_view.hull_key=="Heavy_Battleship" and scene.ship_view.modules.size()==5,"actual rendered fifth hull full loadout")
 g.paused=true
 await process_frame;await RenderingServer.frame_post_draw
 var placements:Array=[];var display_boxes:Array=[];var maximum_error:=0.0;var expected_rects:Dictionary={};var enemy_actual_front:=0.0
 for e in g.enemies:
  var model_width:float=scene.enemy_render_width(e);var point:Vector2=scene.enemy_render_position(e);var angle:float=scene.enemy_render_angle(e)
  var texture=scene.ship_hull_texture(scene.enemy_ship_key(e));var used:Rect2i=texture.get_image().get_used_rect();var rect:Rect2=scene.enemy_hull_rect(e,model_width)
  var centre:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*.5)/texture.get_size()*rect.size
  maximum_error=maxf(maximum_error,centre.length());check(centre.length()<.001,"alpha centre stays hit centre")
  var box:=Rect2();var first:=true
  for p in [Vector2(used.position),Vector2(used.end.x,used.position.y),Vector2(used.end),Vector2(used.position.x,used.end.y)]:
   var vertex:Vector2=point+(rect.position+p/texture.get_size()*rect.size).rotated(PI+angle)
   if first:box=Rect2(vertex,Vector2.ZERO);first=false
   else:box=box.expand(vertex)
  expected_rects[int(e.uid)]=rect.size
  var cell:Rect2=GRID.cell_rect(scene.enemy_grid_plan,e)
  check(cell.encloses(box),"entire rotated body inside footprint")
  for other in display_boxes:check(not box.intersects(other),"actual hull AABBs separated")
  display_boxes.append(box);enemy_actual_front=maxf(enemy_actual_front,box.end.y)
  var recognition=scene.enemy_recognition_geometry(e)
  var envelope:PackedVector2Array=recognition.inner.duplicate()
  var protection_scale:float=scene.enemy_display_protection_scale(e,recognition,angle)
  for index in envelope.size():envelope[index]*=protection_scale
  for key in ["inner","outer","front","single_front"]:
   for vertex in recognition.get(key,PackedVector2Array()):
    var rendered:Vector2=point+(Vector2(vertex)*protection_scale).rotated(PI+angle)
    check(cell.has_point(rendered),"drawn protection inside footprint")
    enemy_actual_front=maxf(enemy_actual_front,rendered.y)
  var meters=scene.enemy_status_layout(e,point,model_width,angle,envelope)
  check(cell.encloses(meters.health) and cell.encloses(meters.shield),"health and shield bars inside footprint")
  if scene.encounter_presentation.is_leader(e):check(cell.encloses(meters.caption_bounds),"boss name and top safety inside footprint")
  placements.append({"uid":e.uid,"key":e.archetype_id,"span":GRID.footprint(e),"cell":cell,"body":box,"health":meters.health,"shield":meters.shield,"caption_bounds":meters.caption_bounds if scene.encounter_presentation.is_leader(e) else Rect2(),"logical_actor":[e.x,e.y],"centre":point,"model_width":model_width})
 # Actual opaque player hull + every mounted art plane, then conservative visible shield.
 var own:Rect2=plane_bounds(scene.ship_view,scene.ship_view.approved_body_plane)
 for module in scene.ship_view.modules:own=own.merge(plane_bounds(scene.ship_view,module.node.find_child("StaticWeaponArt",true,false)))
 var shield:MeshInstance3D=scene.ship_view.shield
 if shield.visible:
  var aabb:=shield.get_aabb()
  for x in [aabb.position.x,aabb.end.x]:
   for y in [aabb.position.y,aabb.end.y]:
    for z in [aabb.position.z,aabb.end.z]:own=own.expand(scene.ship_view.camera.unproject_position(shield.to_global(Vector3(x,y,z))))
 var snapshot_own:=own
 for module in scene.ship_view.modules:
  var saved:Vector3=module.pivot.rotation
  for yaw in [-85.0,0.0,85.0]:
   module.pivot.rotation.y=deg_to_rad(yaw)
   own=own.merge(plane_bounds(scene.ship_view,module.node.find_child("StaticWeaponArt",true,false)))
  module.pivot.rotation=saved
 var gap:float=own.position.y-GRID.AREA.end.y
 check(gap>=scene.BATTLE_VIEW_SIZE.y*float(scene.battle_visual.enemy_player_min_gap),"existing192-unit battle gap to complete fifth hull/shield and extreme turret yaw")
 # Both visual authorities must agree without installing another battle owner.
 var geometry=preload("res://scripts/simulation_geometry_authority.gd").new();geometry.prepare(scene,g)
 for e in g.enemies:check(geometry.enemy_render_position(e).distance_to(scene.enemy_render_position(e))<.01,"simulation/display grid position parity")
 var view=preload("res://scripts/simulation_geometry_view.gd").new()
 for e in g.enemies:view.descriptor(int(e.uid),geometry.display_descriptor(e))
 view.apply(geometry.display_frame(g.enemies,false))
 check(view.grid_plan==geometry.enemy_grid_plan,"grid plan published with native display frame")
 var old_plan=scene.enemy_grid_plan;scene.enemy_grid_plan={};scene.simulation_geometry_view=view
 for e in g.enemies:
  var rect:Rect2=scene.enemy_hull_rect(e,scene.enemy_render_width(e));check(rect.size.is_equal_approx(expected_rects[int(e.uid)]) and scene.enemy_display_grid_plan().placements.has(int(e.uid)),"native view uses published plan even when Main is stale")
 scene.simulation_geometry_view=null;scene.enemy_grid_plan=old_plan
 geometry.close({"providers":{},"spatial":g.target_spatial_source});geometry=null
 var ruler=Ruler.new();ruler.plan=scene.enemy_grid_plan;ruler.player_front=own.position.y;ruler.enemy_front=enemy_actual_front;scene.battle_clip.add_child(ruler);ruler.z_index=100
 await process_frame;await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();image.save_png(output.path_join(case+".png"))
 var result={"case":case,"checks":checks,"failures":failures,"fires":fires,"hits":hits,"grid":GRID.AREA,"single_cell":GRID.AREA.size/Vector2(5,3),"insets_ltrb":GRID.INSET,"player_hull":"Heavy_Battleship","player_slots":scene.ship_view.modules.size(),"player_snapshot_bounds":snapshot_own,"player_bounds_with_weapons_and_shield":own,"enemy_area_clear_gap":gap,"actual_enemy_visual_front":enemy_actual_front,"nearest_fleet_envelope_gap":own.position.y-enemy_actual_front,"alpha_centre_max_error":maximum_error,"placements":placements,"engine":Engine.get_version_info().string,"native":false,"fixture":"actual main.tscn, save disabled, held-health QA actors; no stage/count/damage table edits"}
 FileAccess.open(output.path_join(case+".json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("GRID_CAPTURE ",JSON.stringify(result))
 scene.queue_free();await process_frame;await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 var selected:=OS.get_environment("GRID_CASE")
 if selected=="unit":units();quit(1 if failures else 0);return
 root.size=Vector2i(1952,1256)
 var output:=OS.get_environment("GRID_OUTPUT");DirAccess.make_dir_recursive_absolute(output)
 await capture(selected,output)
 quit(1 if failures else 0)
