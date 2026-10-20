extends SceneTree
const IDENTITY=preload("res://scripts/enemy_visual_identity.gd")
const MOUNTS=preload("res://scripts/enemy_weapon_interface.gd")
const KEYS=["anchor","reactive","shielded","command"]
const NAMES={"anchor":"锚定舰","reactive":"反应舰","shielded":"护盾舰","command":"指挥舰"}
var checks:=0
var failures:=0
var fires:=0
var hits:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func identity_checks()->void:
 var lookup=IDENTITY.new();var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
 for key in config.ships:config.ships[key].asset_ready=true
 for key in KEYS:
  for size in range(1,7):
   for state in [["normal",false,"",1],["elite",false,"_elite",2],["boss",true,"_boss",4],["ultimate",true,"_boss",4],["boss",false,"",1],["ultimate",false,"",1]]:
    var e={"archetype_id":key,"armourType":1,"size":size,"combat_tier":state[0],"encounter_leader":state[1]}
    check(lookup.resolve(e,config)=="enemy_opening_"+key+str(state[2]),"published tier/leader selection independent of size")
    var before:Dictionary=e.duplicate(true);var plan:Dictionary=MOUNTS.describe(e,config)
    check(plan.slot_count==state[3] and plan.hardpoints.size()==state[3] and plan.slot_map.size()==state[3],"reserved 1/2/4 contract independent of size")
    check(e==before and not e.has("equipment"),"interface does not write an enemy loadout")
  var missing:Dictionary=config.duplicate(true);missing.ships["enemy_opening_"+key+"_elite"].asset_ready=false
  check(lookup.resolve({"archetype_id":key,"armourType":1,"size":6,"combat_tier":"elite"},missing)=="enemy_opening_"+key,"unavailable variant keeps base hull")
 check(lookup.resolve({"archetype_id":"scout","armourType":2,"size":6,"combat_tier":"elite"},config)=="enemy_opening_scout","other four archetypes retain ordinary assets")
 check(lookup.resolve({"archetype_id":"anchor","armourType":2,"size":6,"combat_tier":"elite"},config)=="enemy_6","armour mismatch fallback retained")
# Explicit isolated-fixture adapter; this is deliberately absent from production.
func install_preview_mounts(scene,enemy:Dictionary)->void:
 var plan:Dictionary=MOUNTS.describe(enemy,scene.visual_config)
 var width:float=scene.enemy_render_width(enemy)
 var dimensions:Vector2=scene.enemy_hull_rect(enemy,width).size
 var row:Dictionary=scene.visual_config.ships[scene.enemy_ship_key(enemy)]
 row.hardpoints=plan.hardpoints;row.slot_map=plan.slot_map
 for point in row.hardpoints:
  point.pos=[float(point.pos[0])*dimensions.x/width,float(point.pos[1])*dimensions.y/(width*2.0)]
 enemy.equipment=[];enemy.cooldowns=[]
 for slot in int(plan.slot_count):
  enemy.equipment.append({"name":"cannon-mon"});enemy.cooldowns.append(0.0)
 scene.enemy_pose(enemy).erase("components_signature")

# Probe the actual aim getter at both clamp limits, then map the painted footprint
# back onto the unrotated PNG and its authored main-armor carrier region.
func carrier_rotation_checks(scene,hero:Dictionary,component,rect:Rect2,texture:Texture2D)->Array:
 var image:=texture.get_image()
 var bounds:Array=component.hardpoint.carrier_region
 var region:=Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2])-float(bounds[0]),float(bounds[3])-float(bounds[1]))
 var point:Vector2=scene.enemy_render_position(hero);var hull_angle:float=scene.enemy_render_angle(hero)
 var active:bool=scene.battle_draw_active;var target:Vector2=scene.battle_draw_player_position;var cached:Dictionary=scene.battle_draw_enemy_positions.duplicate()
 scene.battle_draw_active=true;scene.battle_draw_enemy_positions[int(hero.uid)]=point
 var rows:Array=[]
 for yaw in [-55.0,0.0,55.0]:
  scene.battle_draw_player_position=point+Vector2.from_angle(PI/2+hull_angle+deg_to_rad(yaw))*900.0
  var pose:Dictionary=scene.enemy_component_pose(hero,component)
  var actual_yaw:float=rad_to_deg(wrapf(float(pose.angle)-PI/2-hull_angle,-PI,PI))
  check(absf(actual_yaw-yaw)<.001,"actual weapon aim reaches requested rotation clamp")
  var w:float=float(pose.width)*.45
  var base:=Vector2(0,(.64-scene.enemy_recognition.muzzle_factor/.45)*w)
  var origin:Vector2=Vector2(pose.origin)+(Vector2(pose.port)-Vector2(.64*w,0)).rotated(pose.angle)
  var rotation:float=float(pose.angle)-PI/2
  var base_centre:Vector2=origin+base.rotated(rotation)
  check(base_centre.distance_to(pose.origin)<.001,"rotated readable base remains on actual mount pivot")
  var footprint:PackedVector2Array=[]
  for radius in [0.0,.33,.66,1.0]:
   for step in 32:footprint.append(base+Vector2.from_angle(TAU*step/32.0)*w*1.03*radius)
  footprint.append_array(PackedVector2Array([base+Vector2(-.40,-.42)*w,base+Vector2(.40,-.42)*w,Vector2(.35*w,.64*w),Vector2(-.35*w,.64*w)]))
  var safe:=true
  var decorative_glow_samples:=0
  for local in footprint:
   var hull_local:Vector2=(origin+local.rotated(rotation)).rotated(-(PI+hull_angle))
   var uv:Vector2=hull_local/rect.size
   if not region.has_point(uv):safe=false;break
   var pixel:Vector2=(hull_local-rect.position)/rect.size*texture.get_size()
   var color:=image.get_pixelv(Vector2i(pixel))
   var glowing:bool=color.r>.49 and color.g>.137 and color.r>color.g*1.45 and color.r>color.b*1.7
   if glowing:decorative_glow_samples+=1
   if color.a<.9:safe=false;break
  check(safe,"rotated base and barrel remain on main carrier; decorative glow may be covered")
  rows.append({"yaw":yaw,"actual_yaw":actual_yaw,"decorative_glow_samples":decorative_glow_samples,"safe":safe,"base_centre_error":base_centre.distance_to(pose.origin)})
 scene.battle_draw_active=active;scene.battle_draw_player_position=target;scene.battle_draw_enemy_positions=cached
 return rows

class Frame extends Node2D:
 var box:Rect2
 var label:String
 func _draw()->void:
  draw_rect(box,Color(.3,.9,1,.7),false,1.0)
  draw_string(ThemeDB.fallback_font,box.position+Vector2(5,16),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d4faff"))
func _initialize()->void:call_deferred("run")
func run()->void:
 identity_checks()
 if OS.get_environment("RANKED_UNIT")=="1":print("RANKED_UNIT ",checks," checks ",failures," failures");quit(1 if failures else 0);return
 var output:=OS.get_environment("RANKED_OUTPUT");DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1373,883)
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false;root.add_child(scene);scene.automation_args=[]
 if OS.get_environment("RANKED_TURRET_BEFORE")!="1":
  var preview_skin=preload("res://dev/qa/ranked_turret_preview.gd").new()
  preview_skin.muzzle_factor=float(scene.weapon_visual_profile("cannon").muzzle[0][0])
  scene.enemy_recognition=preview_skin
 var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.rng.seed=20261020
 g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 check(g.start(1,false),"actual battle starts");g.group_index=1;g.spawn_group()
 g.profile.selectedShip="Heavy_Battleship";g.profile.loadout={"weapons":[],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
 for key in ["cannon","missile","laser","longLaser","cannon"]:g.profile.loadout.weapons.append({"key":key,"level":1})
 g.invalidate_stat_cache();g.reset_player();g.player.armour=1e10;g.player.shield=1e10
 scene.current_hull="Heavy_Battleship";scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions();scene.ship_view.set_loadout(g.weapon_entries(),g.active_slot_count("weapons"))
 var template:Dictionary=g.enemies[0].duplicate(true)
 g.event.connect(func(kind:String,_info:Dictionary):
  if kind=="fire":fires+=1
  if kind=="hit":hits+=1)
 var ruler=Frame.new();scene.battle_clip.add_child(ruler);ruler.z_index=100
 var snapshots:Array=[];var case_index:=0
 for rank in ["elite","boss"]:
  for key in KEYS:
   g.paused=true;g.enemies.clear();scene.enemy_poses.clear();scene.fixed_layout_signature.clear()
   var encounter:Dictionary=g.db.levels[g.stage-1].groups[g.group_index-1];g.db.groups[str(int(encounter.id))].combatTier=rank;g.db.groups[str(int(encounter.id))].description=str(NAMES[key])+" · "+("BOSS" if rank=="boss" else "精英")
   for i in 3:
    var e:Dictionary=template.duplicate(true);e.uid=92000+case_index*10+i;e.slot=i;e.archetype_id=key if i==0 else "sentry";e.armourType=1 if i==0 else 2;e.shieldType=1
    if i==0:
     e.id=990000+case_index
     g.db.enemies[str(int(e.id))]=template.duplicate(true)
     g.db.enemies[str(int(e.id))].des=str(NAMES[key])+" · "+("BOSS" if rank=="boss" else "精英")
    e.size=2 if i==0 else 6;e.combat_tier=rank;e.encounter_leader=rank=="boss" and i==0;e.hull_scale=1.35 if e.encounter_leader else 1.0
    e.x=286.0 if i==0 else 65.0 if i==1 else 507.0;e.y=210.0 if i==0 else 90.0
    e.hp=1e10;e.max_hp=1e10;e.shield=1e10;e.max_shield=1e10;e.shieldRecovery=0.0;e.equipment=[{"name":"laser_mon"}];e.cooldowns=[0.0]
    e.explicit_formation=true;e.size_formation=true;e.formation_columns=5;e.formation_count=3;g.enemies.append(e)
   scene.encounter_presentation.identity="";scene.encounter_presentation.leader_uid=-1;scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
   # Prove production geometry with its original single weapon before QA installation.
   var production_hero:Dictionary=g.enemies[0]
   var production_packet:Dictionary=scene.enemy_recognition_geometry(production_hero)
   production_hero.combat_tier="normal"
   var production_base:Dictionary=scene.enemy_recognition_geometry(production_hero)
   production_hero.combat_tier=rank
   for field in ["inner","outer","front","single_front"]:check(production_packet[field]==production_base[field],"production original geometry and equipment retained")
   var planned:Array=MOUNTS.describe(production_hero,scene.visual_config).hardpoints
   var col:float=absf(float(planned[0].pos[0]))
   var pitch:float=absf(float(planned[0].pos[1]))
   var sum:=Vector2.ZERO
   for planned_point in planned:
    sum+=Vector2(float(planned_point.pos[0]),float(planned_point.pos[1]))
    check(is_equal_approx(absf(float(planned_point.pos[0])),col),"turret columns align with one mirrored width")
    if rank=="boss":check(is_equal_approx(absf(float(planned_point.pos[1])),pitch),"BOSS rows align above and below hull centre")
   check(absf(sum.x)<.000001,"turret layout has zero left/right mass offset")
   if rank=="boss":check(sum.length()<.000001 and planned.size()==4,"BOSS 2x2 array is centred on hull mass")
   else:check(is_equal_approx(float(planned[0].pos[1]),float(planned[1].pos[1])),"elite pair uses one shared row")
   install_preview_mounts(scene,production_hero)
   if case_index==0:
    g.paused=false
    for frame in 130:
     await process_frame
     if frame>=100 and fires>0 and hits>0:break
    check(fires>0 and hits>0,"real fire and hit before preview")
   g.paused=true;scene.fx_time=4.0;scene.shake=0.0
   for e in g.enemies:scene.enemy_pose(e).born=0.0
   g.projectile_clear();scene.projectile_visuals.clear();scene.floats.clear();scene.damage_pending.clear();scene.rail_events.clear();scene.missile_events.clear();scene._pulse_events.clear()
   scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw();scene.encounter_presentation.sync(g,0.0)
   var hero:Dictionary=g.enemies[0];var hero_key:String=scene.enemy_ship_key(hero)
   check(hero_key=="enemy_opening_"+key+"_"+rank,"ranked hull selected")
   for i in [1,2]:check(scene.enemy_ship_key(g.enemies[i])=="enemy_opening_sentry","boss escorts do not inherit boss art")
   var point:Vector2=scene.enemy_render_position(hero);var width:float=scene.enemy_render_width(hero);var angle:float=scene.enemy_render_angle(hero)
   var rect:Rect2=scene.enemy_hull_rect(hero,width);var texture:Texture2D=scene.ship_hull_texture(hero_key);var used:Rect2i=texture.get_image().get_used_rect()
   var centre:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*.5)/texture.get_size()*rect.size
   check(centre.length()<.001,"ranked alpha centre remains battle centre")
   var body:=Rect2();var first:=true
   for pixel in [Vector2(used.position),Vector2(used.end.x,used.position.y),Vector2(used.end),Vector2(used.position.x,used.end.y)]:
    var vertex:Vector2=point+(rect.position+pixel/texture.get_size()*rect.size).rotated(PI+angle)
    if first:body=Rect2(vertex,Vector2.ZERO);first=false
    else:body=body.expand(vertex)
   var available:=Vector2(204.8,212.6666666667) if rank=="elite" else Vector2(319.2,194.6666666667)
   check(body.size.x<=available.x+.001 and body.size.y<=available.y+.001,"entire rotated hull fits approved body allowance")
   var packet:Dictionary=scene.enemy_recognition_geometry(hero)
   var expected_slots:=2 if rank=="elite" else 4
   var components:Array=scene.enemy_weapon_components(hero)
   check(hero.equipment.size()==expected_slots and components.size()==expected_slots,"QA has exact reserved elite/BOSS weapon count")
   var mounts:Array=[]
   var mount_centres:Array[Vector2]=[]
   for component in components:
    check(component.mode()=="main" and float(component.hardpoint.rotation_limit)>0,"each reserved weapon has an independent rotating mount")
    var mount_pose:Dictionary=scene.enemy_component_pose(hero,component)
    var canvas_scale:float=(root.get_final_transform()*scene.battle_clip.get_global_transform_with_canvas()).get_scale().x
    var base_diameter:float=float(mount_pose.width)*.45*2.06
    check(base_diameter*canvas_scale>=12.0,"turret base remains legible in original window pixels")
    var local_uv:Array=component.hardpoint.pos
    var pixel:=Vector2(used.position)+Vector2(used.size)*.5+Vector2(float(local_uv[0])*width,float(local_uv[1])*width*2.0)/rect.size*texture.get_size()
    check(texture.get_image().get_pixelv(Vector2i(pixel)).a>.3,"turret axis lies on opaque armor, not between accessories")
    for other in mount_centres:check(Vector2(mount_pose.origin).distance_to(other)>base_diameter+2.0,"independent turret bases do not overlap")
    mount_centres.append(mount_pose.origin)
    var source_color:=texture.get_image().get_pixelv(Vector2i(pixel))
    check(source_color.a>.9,"axis is seated on the main hull; decoration brightness does not choose placement")
    var rotation_checks:=carrier_rotation_checks(scene,hero,component,rect,texture)
    mounts.append({"carrier_group":component.hardpoint.carrier_group,"carrier_region":component.hardpoint.carrier_region,"rotation_checks":rotation_checks,"slot":component.owner_slot,"origin":mount_pose.origin,"muzzle":mount_pose.muzzle,"base_diameter_pixels":base_diameter*canvas_scale})
   for i in [1,2]:check(g.enemies[i].equipment.size()==1 and scene.enemy_weapon_components(g.enemies[i]).size()==1,"ordinary escorts retain one weapon in QA")
   check(scene.enemy_render_position(hero)==point and is_equal_approx(scene.enemy_render_width(hero),width),"ranked skin does not move or resize model geometry")
   var outline:PackedVector2Array=packet.inner.duplicate();var protection_scale:float=scene.enemy_display_protection_scale(hero,packet,angle)
   for i in outline.size():outline[i]*=protection_scale
   var status:Dictionary=scene.enemy_status_layout(hero,point,width,angle,outline)
   var padding_top:=42.0 if rank=="elite" else 60.0
   ruler.box=Rect2(point-available*.5-Vector2(12,padding_top),Vector2(228.8,266.6666666667) if rank=="elite" else Vector2(343.2,266.6666666667));ruler.label=key+" "+rank+(" 2x2" if rank=="elite" else " 3x2");ruler.queue_redraw()
   check(ruler.box.encloses(body) and ruler.box.encloses(status.health) and ruler.box.encloses(status.shield),"hull and both meters inside reserved display frame")
   check(absf(status.health.get_center().x-point.x)<.001 and absf(status.shield.get_center().x-point.x)<.001,"ranked meters centred")
   if rank=="boss":check(ruler.box.encloses(status.caption_bounds),"boss name fits reserved top space")
   await process_frame;await RenderingServer.frame_post_draw
   if rank=="elite":
    var record=scene.retained_contacts.records[int(hero.uid)]
    check(record.supported and (record.hull.data.rect.size*record.hull.scale).is_equal_approx(rect.size),"elite retained and canonical hull agree")
    for mount in record.mounts:check(mount.node.get_index()>record.protection.get_index(),"turret foreground order stays above hull, accessories and protection")
   var geometry=preload("res://scripts/simulation_geometry_authority.gd").new();geometry.prepare(scene,g)
   check(geometry.enemy_ship_key(hero)==hero_key,"native authority selects same ranked art")
   check(geometry.enemy_render_position(hero).distance_to(point)<.001,"native authority keeps same authored position")
   var view=preload("res://scripts/simulation_geometry_view.gd").new()
   for e in g.enemies:view.descriptor(int(e.uid),geometry.display_descriptor(e))
   view.apply(geometry.display_frame(g.enemies,false));scene.simulation_geometry_view=view
   check(scene.enemy_hull_rect(hero,scene.enemy_render_width(hero)).size.is_equal_approx(rect.size),"native view preserves ranked display size")
   scene.simulation_geometry_view=null;geometry.close({"providers":{},"spatial":g.target_spatial_source})
   await process_frame;await RenderingServer.frame_post_draw
   var filename:String=str(key)+"-"+str(rank)+".png";root.get_texture().get_image().save_png(output.path_join(filename))
   snapshots.append({"case":key+"_"+rank,"file":filename,"visual_key":hero_key,"actor_size":hero.size,"weapon_slots":expected_slots,"mounts":mounts,"position":point,"model_width":width,"body":body,"display_frame":ruler.box,"health":status.health,"shield":status.shield,"caption":status.caption_bounds,"alpha_centre_error":centre.length()});case_index+=1
 var result={"window_png":root.get_texture().get_image().get_size(),"viewport_final_scale":root.get_final_transform().get_scale(),"checks":checks,"failures":failures,"fires":fires,"hits":hits,"engine":Engine.get_version_info().string,"native_full_run":false,"fixture":"actual main.tscn, save disabled, held-health QA actor metadata; explicit QA-only 2/4 equipment and reserved mount installation, two ordinary one-weapon escorts; production loadouts/stats/formation unchanged","snapshots":snapshots}
 FileAccess.open(output.path_join("ranked.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("RANKED_CAPTURE ",JSON.stringify(result));quit(1 if failures else 0)
