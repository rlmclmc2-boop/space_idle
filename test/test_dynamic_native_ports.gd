extends SceneTree
const VIEW=preload("res://scripts/presented_ship_view.gd")
const POSE=preload("res://scripts/logical_fleet_pose.gd")
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
func _initialize()->void:call_deferred("run")
func run()->void:
 var library_before:=FileAccess.get_sha256("res://bin/libspace_native.so")
 paired();snapshot_test();retired_feedback_test();projection_test()
 check(FileAccess.get_sha256("res://bin/libspace_native.so")==library_before,"all runtime edits reuse the same native binary")
 var result={"checks":checks,"failures":failures,"evidence":evidence,"engine":Engine.get_version_info(),"native_sha256":library_before}
 FileAccess.open("res://.runtime/dynamic-ports.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("DYNAMIC_PORTS ",JSON.stringify(result));quit(1 if failures else 0)
