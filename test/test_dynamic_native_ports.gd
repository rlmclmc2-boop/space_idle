extends SceneTree
const VIEW=preload("res://scripts/presented_ship_view.gd")
const POSE=preload("res://scripts/logical_fleet_pose.gd")
class CountedPose extends "res://scripts/logical_fleet_pose.gd":
 var builds:=0
 func _project_presentation_muzzles(module:Dictionary,art:Dictionary,root_transform:Transform3D)->PackedVector2Array:
  builds+=1
  return super._project_presentation_muzzles(module,art,root_transform)
 func fresh(slot:int)->PackedVector2Array:
  var module:Dictionary=module_by_slot.get(slot,{})
  if module.is_empty() or not presentation_art.has(str(module.assignment.key)):return PackedVector2Array()
  var root_transform:Transform3D=ship_transform if module.assignment.carrier=="hull" else carriers[module.carrier_index].transform
  return super._project_presentation_muzzles(module,presentation_art[str(module.assignment.key)],root_transform)
var checks:=0
var failures:=0
var evidence:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
class Session extends RefCounted:
 var kernel:RefCounted
 var handed_off:=false
class Game extends RefCounted:
 var native_execution:RefCounted
class Surface extends RefCounted:
 var game:RefCounted
 var battle_slice_runtime=RefCounted.new()
 var retained_contacts_enabled:=true
 var prototype_enabled:=true
 var pulse_vfx_enabled:=true
 var enemy_vfx_enabled:=true
 var missile_vfx_enabled:=true
 var accelerated_visual_mode:=false
 var projectile_visuals:Array=[]
 var particles:Array=[]
 var missile_density:=0
 var draw_surface:Control
func world(kind:int=0)->Dictionary:
 return {"clock":0.0,"rng_state":418,"resistance":0.5,"player":{"x":0.0,"y":100.0,"armour":1e9,"shield":1e9,"armour_type":2,"shield_type":1},"enemies":[{"uid":100,"slot":0,"x":0.0,"y":0.0,"hp":1e9,"max_hp":1e9,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}],"weapons":[{"kind":kind,"type":1,"slot":0,"source":0,"hostile":false,"damage":10.0,"interval":0.1,"remaining":0.0,"speed":50.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2(0,100),"entry":{"key":["laser","cannon","missile","longLaser"][kind]},"row":{"cd":0.1,"para1":1.0,"para2":1.0,"para3":0.0}}]}
func core(kind:int=0,compact:bool=true):
 var k=ClassDB.instantiate("SpaceCombatKernel");check(k.configure(world(kind)),"configure")
 k.input_ballistic_geometry([PackedVector2Array([Vector2(-20,-20),Vector2(20,-20),Vector2(20,20),Vector2(-20,20)])],PackedVector2Array([Vector2.ZERO]),PackedVector2Array([Vector2(0,100)]),PackedByteArray([1]))
 k.input_geometry(PackedVector2Array([Vector2.ZERO]),PackedVector2Array([Vector2(0,100)]))
 k.set_compact_laser_births(compact)
 return k
func numeric(k)->Dictionary:
 var rows=[]
 for shot in k.projectile_views():
  rows.append([shot.serial,shot.key,shot.get("dead",false),shot.motion_lease.x(),shot.motion_lease.y(),shot.motion_lease.direction(),shot.damage,shot.get("fixed_screen_origin"),shot.get("fixed_screen_step")])
 return {"player":k.player_view().duplicate(true),"enemies":k.enemy_views().duplicate(true),"rng":str(k.rng_source().state),"rows":rows,"metrics":k.metrics()}
func paired()->void:
 for kind in 4:
  for compact in [false,true]:
   var a=core(kind,compact);var b=core(kind,compact)
   for step in 300:
    check(b.input_presentation_muzzles([PackedVector2Array([Vector2(30+step%23,80-step%11),Vector2(-40,60)])]),"runtime coordinate update")
    a.advance(1.0/60.0);b.advance(1.0/60.0)
    var left=numeric(a);var right=numeric(b)
    check(left==right,"numeric/RNG/damage invariant kind=%d compact=%s step=%d"%[kind,compact,step])
    a.take_feedback();b.take_feedback()
   check(a.metrics().hits>0,"damage actually settled")
   evidence.append({"kind":kind,"compact":compact,"steps":300,"numeric_equal":true,"hits":a.metrics().hits,"root_attacks":a.metrics().root_attacks,"rng":str(a.rng_source().state)})
   a.cancel();b.cancel()
func snapshot_test()->void:
 var k=core();var first:=Vector2(30,70);var second:=Vector2(-55,80)
 check(k.input_presentation_muzzles([PackedVector2Array([first])]),"first port")
 k.advance(1.0/60.0)
 var events=k.take_feedback();check(events[0].presentation_origin==first,"birth feedback owns original value")
 # Update BEFORE the first display, then create a second birth in the same binary.
 check(k.input_presentation_muzzles([PackedVector2Array([second])]),"move/scale without binary change")
 check(not k.input_presentation_muzzles([PackedVector2Array([Vector2(INF,1)])]),"reject nonfinite atomically")
 check(not k.input_presentation_muzzles([]),"reject wrong weapon count")
 check(not k.input_presentation_muzzles([[]]),"reject wrong row type")
 for i in 6:k.advance(1.0/60.0)
 var surface=Surface.new();surface.game=Game.new();surface.game.native_execution=Session.new();surface.game.native_execution.kernel=k
 surface.draw_surface=Control.new();root.add_child(surface.draw_surface)
 var p=ClassDB.instantiate("SpaceCombatPresentation");p.configure_retained_gpu(ShaderMaterial.new())
 p.advance_visuals(surface,0.0);p.advance_visuals(surface,0.0)
 var hot:Dictionary=p.retained_metrics()
 check(hot.old_advance==0 and hot.births==2,"retained descriptors reused without cold exports")
 # Cold to_array intentionally materializes compatibility rows. The following
 # native advance recaptures those rows once; hot descriptor reuse was checked above.
 var frame=p.prepare_flights(surface,[],Vector2.ZERO);var rows=frame.to_array()
 check(rows.size()==2,"two native retained births")
 for i in rows.size():
  var shot:Dictionary=rows[i].shot
  var origin:Vector2=first if i==0 else second
  check(shot.presentation_origin==origin,"first display uses actual birth snapshot")
  var distance:float=(Vector2(shot.motion_lease.x(),shot.motion_lease.y())-Vector2(shot.launch_point)).dot(shot.direction)
  var expected:Vector2=origin+Vector2(shot.presentation_step)*distance
  check(Vector2(rows[i].pos).distance_to(expected)<0.001,"retained GPU anchor uses visual ray")
 if rows.is_empty():k.cancel();surface.draw_surface.free();return
 var old:Vector2=rows[0].pos
 k.input_presentation_muzzles([PackedVector2Array([Vector2(200,300)])])
 p.advance_visuals(surface,0.0);rows=p.prepare_flights(surface,[],Vector2.ZERO).to_array()
 check(Vector2(rows[0].pos).distance_to(old)<0.001,"post-display turn cannot drag old shot")
 var m:Dictionary=p.retained_metrics();check(m.old_advance==0 and m.old_prepare==0 and m.births==4,"no CPU fallback, retained descriptors reused")
 evidence.append({"frozen_before_first_display":true,"frozen_after_display":true,"retained_before_cold_export":hot,"retained_after_cold_export":m,"origins":[first,second]})
 k.take_feedback()
 check(k.input_presentation_muzzles([PackedVector2Array()]),"empty row fallback")
 for i in 7:k.advance(1.0/60.0)
 var fallback_births:=0
 for event in k.take_feedback():
  if int(event.kind)!=0:continue
  fallback_births+=1;check(not event.has("presentation_origin"),"empty input does not leak a previous birth origin")
 check(fallback_births>0,"fallback birth exercised")
 k.cancel();surface.draw_surface.free()
func retired_feedback_test()->void:
 var k=core();var first:=Vector2(10,70)
 k.input_presentation_muzzles([PackedVector2Array([first])])
 for step in 300:k.advance(1.0/60.0)
 k.input_presentation_muzzles([PackedVector2Array([Vector2(120,90)])])
 check(k.metrics().hits>0 and k.metrics().root_attacks>k.metrics().active_flights,"retired flights and slot reuse exercised before first display")
 var births:=0
 for event in k.take_feedback():
  if int(event.kind)==0:
   births+=1;check(event.presentation_origin==first,"retired/reused slots cannot rewrite value feedback")
 check(births>0,"retained birth feedback observed")
 evidence.append({"retired_before_first_display":true,"births":births,"hits":k.metrics().hits})
 k.cancel()
func projection_test()->void:
 var view=VIEW.new();view.size=Vector2(600,700);root.add_child(view)
 var pose=POSE.new();pose.prepare(view)
 var maximum:=0.0;var count:=0
 for hull in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
  var capacity:int=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"].find(hull)+1
  for key in ["laser","cannon","missile","longLaser"]:
   for scale in [0.7,1.0,1.35]:
    var entries:Array=[]
    for i in capacity:entries.append({"key":key})
    # Runtime edits to data then loadout reconstruction; binary stays identical.
    var original:float=float(view.static_weapon_art[key].visual_scale)
    var point:Array=view.static_weapon_art[key].emission_pixels[0].duplicate()
    view.static_weapon_art[key].emission_pixels[0]=[float(point[0])+17.0*(scale-1.0),float(point[1])-11.0*(scale-1.0)]
    var mount_scale:float=float(view.approved_hull_art[hull].get("weapon_scale",1.0))
    view.approved_hull_art[hull].weapon_scale=mount_scale*scale
    pose.approved[hull].weapon_scale=mount_scale*scale
    var seat:Array=view.approved_hull_art[hull].hardpoints[0].pos.duplicate()
    view.approved_hull_art[hull].hardpoints[0].pos=[float(seat[0])+0.03*(scale-1.0),float(seat[1])+0.02*(scale-1.0)]
    view.static_weapon_art[key].visual_scale=original*scale
    view.set_loadout([],0);view.set_hull(hull);view.set_loadout(entries,capacity)
    pose.configuration_dirty=true;pose.configure(hull,entries,capacity,{})
    for angle in [-0.8,0.0,0.8]:
     var angles:Array=[]
     for i in capacity:angles.append(angle)
     view.set_pose(Vector2(300,350),540,0,Vector2(300,-200),0,false,false);view.set_slot_angles(angles)
     pose.pose_base(Vector2(300,350),540,0,0,false,0);pose.set_slot_angles(angles)
     for i in capacity:
      var ports:PackedVector2Array=pose.screen_presentation_muzzles_for_slot(i)
      for ordinal in ports.size():
       var error:float=ports[ordinal].distance_to(view.screen_visual_muzzle_for_slot(i,ordinal));maximum=maxf(maximum,error);count+=1
       check(error<0.05,"pure data vs actual visual port")
    view.static_weapon_art[key].visual_scale=original
    view.static_weapon_art[key].emission_pixels[0]=point
    view.approved_hull_art[hull].hardpoints[0].pos=seat
    view.approved_hull_art[hull].weapon_scale=mount_scale
    pose.approved[hull].weapon_scale=mount_scale
 evidence.append({"projection_points":count,"maximum_error_px":maximum,"runtime_scales":[0.7,1.0,1.35],"runtime_emission_pixel_offset":true,"runtime_hardpoint_offset":true,"runtime_mount_scale":true,"hulls":5,"weapon_families":4})
 view.free()
func cache_probe(pose,label:String)->void:
 var before:int=pose.builds
 # Compare memoized output with a fresh projection; the separate renderer
 # matrix above checks that projection against actual visual Node3D ports.
 var expected:PackedVector2Array=pose.fresh(0)
 check(pose.screen_presentation_muzzles_for_slot(0)==expected,label+" fresh value")
 check(pose.builds==before+1,label+" invalidates once")
 check(pose.screen_presentation_muzzles_for_slot(0)==expected and pose.builds==before+1,label+" stable hit")
func cache_test()->void:
 var view=VIEW.new();view.size=Vector2(600,700);root.add_child(view)
 var pose=CountedPose.new();pose.prepare(view)
 var entries:Array=[{"key":"laser"}]
 view.set_hull("Frigate");view.set_loadout(entries,1)
 pose.configure("Frigate",entries,1,{})
 view.set_pose(Vector2(300,350),540,0,Vector2(300,-200),0,false,false);view.set_slot_angles([0.1])
 pose.pose_base(Vector2(300,350),540,0,0,false,0);pose.set_slot_angles([0.1])
 var first:PackedVector2Array=pose.screen_presentation_muzzles_for_slot(0)
 var frozen:=first.duplicate();var builds:int=pose.builds
 check(first[0].distance_to(view.screen_visual_muzzle_for_slot(0,0))<0.05,"cache initial actual visual port")
 for i in 64:check(pose.screen_presentation_muzzles_for_slot(0)==first,"unchanged cache output")
 check(pose.builds==builds,"unchanged inputs do not repeat projection")
 var k=core();k.input_presentation_muzzles([first]);k.advance(1.0/60.0);k.take_feedback()
 pose.set_slot_angles([0.7]);cache_probe(pose,"turret turn")
 pose.approved.Frigate.hardpoints[0].pos[0]+=0.035;cache_probe(pose,"in-place hardpoint")
 pose.approved.Frigate.weapon_scale*=1.1;cache_probe(pose,"hull weapon scale")
 pose.presentation_art.laser.visual_scale*=0.8;cache_probe(pose,"art scale")
 pose.presentation_art.laser.anchor[0]+=5.0;cache_probe(pose,"in-place anchor")
 pose.presentation_art.laser.pixels_per_model[0]*=1.1;cache_probe(pose,"in-place pixels per model")
 pose.presentation_art.laser.emission_pixels[0][1]-=7.0;cache_probe(pose,"nested emission pixel")
 pose.presentation_art.laser.emission_pixels.append([30,12]);cache_probe(pose,"port count")
 var module:Dictionary=pose.module_by_slot[0]
 module.mount_chain[0]=module.mount_chain[0].scaled_local(Vector3(1.1,1.0,0.9));cache_probe(pose,"mount chain")
 module.descriptor.pivot_chain.insert(0,Transform3D(Basis.IDENTITY,Vector3(0.03,0,0.04)));cache_probe(pose,"pivot chain")
 pose.ship_transform=pose.ship_transform.translated(Vector3(0.1,0,0.1));cache_probe(pose,"ship transform")
 pose.rendered_position+=Vector2(3,4);cache_probe(pose,"rendered position")
 pose.rendered_height*=1.01;cache_probe(pose,"rendered height")
 pose.approved.Frigate.opaque=Rect2(pose.approved.Frigate.opaque.position,pose.approved.Frigate.opaque.size+Vector2(2,1));cache_probe(pose,"opaque fit")
 pose.approved.Frigate.mesh_size+=Vector2(0.1,0.1);cache_probe(pose,"mesh fit")
 pose.approved.Frigate.base_position+=Vector3(0.02,0,0.01);cache_probe(pose,"base fit")
 pose.manifest.hulls.Frigate.model_span*=1.02;cache_probe(pose,"model span")
 pose.camera_transform=pose.camera_transform.translated(Vector3(0.2,0.1,0.1));cache_probe(pose,"camera transform")
 var next_projection:Projection=pose.projection;next_projection.x*=1.03;pose.projection=next_projection;cache_probe(pose,"projection")
 pose.size+=Vector2(2,3);cache_probe(pose,"viewport size")
 var test_carriers:Array[Dictionary]=[{"transform":Transform3D.IDENTITY}]
 module.assignment.carrier="drone";module.carrier_index=0;pose.carriers=test_carriers;cache_probe(pose,"carrier assignment")
 pose.carriers[0].transform=pose.carriers[0].transform.translated(Vector3(0.2,0,0.2));cache_probe(pose,"carrier transform")
 module.assignment.key="missile";module.descriptor=pose.weapons.missile;cache_probe(pose,"weapon configuration")
 k.input_presentation_muzzles([pose.screen_presentation_muzzles_for_slot(0)])
 check(first==frozen,"cache replacement does not mutate prior returned value")
 check(k.projectile_views()[0].presentation_origin==frozen[0],"cached provider preserves existing birth snapshot")
 pose.module_by_slot.erase(0);check(pose.screen_presentation_muzzles_for_slot(0).is_empty(),"removed slot cannot leak cached ports")
 pose.configuration_dirty=true;pose.configure("Frigate",entries,1,{})
 cache_probe(pose,"configuration recapture")
 pose.invalidate_pose();cache_probe(pose,"explicit ownership invalidation")
 evidence.append({"cache_unchanged_queries":64,"cache_rebuilds":pose.builds,"in_place_descriptor_edits":true,"camera_and_projection":true,"birth_value_preserved":true})
 k.cancel();view.free()
func _initialize()->void:call_deferred("run")
func run()->void:
 var library_path:="res://bin/space_native.dll" if OS.has_feature("windows") else "res://bin/libspace_native.so"
 var library_before:=FileAccess.get_sha256(library_path)
 check(library_before.length()==64,"matching native binary exists")
 paired();snapshot_test();retired_feedback_test();projection_test();cache_test()
 check(FileAccess.get_sha256(library_path)==library_before,"all runtime edits reuse the same native binary")
 var result={"checks":checks,"failures":failures,"evidence":evidence,"engine":Engine.get_version_info(),"native_sha256":library_before}
 FileAccess.open("res://.runtime/dynamic-ports.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("DYNAMIC_PORTS ",JSON.stringify(result));quit(1 if failures else 0)
