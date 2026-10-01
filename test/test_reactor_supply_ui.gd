extends SceneTree
const ROUTES := preload("res://scripts/reactor_routes.gd")
var failures := 0
var checks := 0
var records: Array = []
var scene: Node
var panel: Control
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func snapshot(tag: String) -> void:
 panel.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 var g=scene.game
 var c=panel.module_controls.weapons
 records.append({"case":tag,"capacity":g.reactor_capacity(),"manual":g.profile.reactorAllocation.weapons,"pool_used":g.reactor_allocated(),"free":g.charge_free_ratio(),"effective_ratio":g.reactor_effective_ratio("weapons"),"multiplier":g.reactor_multiplier("weapons"),"manual_text":c.energy.text,"share_text":c.share.text,"free_text":c.allocation_boost.text,"effective_text":c.bay_energy.text,"effect_text":c.boost.text,"source_running":panel.network.is_processing()})
 root.get_texture().get_image().save_png("res://.runtime/supply-"+tag+".png")
 var expected_ratio: float=float(g.profile.reactorAllocation.weapons)/float(g.reactor_capacity())+g.charge_free_ratio()
 var expected_gain: float=1.0+pow(float(g.profile.reactorAllocation.weapons)+g.reactor_capacity()*g.charge_free_ratio(),float(g.db.config.reactorBoostExponent))/float(g.db.config.reactorPercentScale)
 check(is_equal_approx(g.reactor_effective_ratio("weapons"),expected_ratio),tag+": independent A/C + free formula")
 check(is_equal_approx(g.reactor_multiplier("weapons"),expected_gain),tag+": independent 1 + pow(A + C*free,exp)/scale formula")
 var powered: bool=Array(g.reactor_modules()).any(func(k):return g.reactor_effective_ratio(k)>0.0)
 check(panel.core.is_processing()==powered and panel.network.is_processing()==powered,tag+": source follows real effective supply")
 check(int(g.profile.reactorAllocation.weapons)==int(c.slider.value),tag+": integer manual input preserved")
 check(c.bay_energy.text.contains(panel.energy_text(g.reactor_effective_ratio("weapons")*g.reactor_capacity())),tag+": effective energy comes from API")
func phase_state() -> Array:
 var result: Array=[]
 for node in [panel.core,panel.network,panel.total_track,panel.footer_flow]:result.append([node.phase,node.is_processing()])
 for controls in panel.module_controls.values():
  for key in ["branch","track","scene_fx"]:result.append([controls[key].phase,controls[key].is_processing()])
 return result
func route_pixels(tag: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var im := root.get_texture().get_image()
 print("PIXEL TRANSFORM ",tag," image=",im.get_size()," window=",root.size," stretch=",root.get_stretch_transform())
 var visible_keys: Array=[]
 for key in panel.module_controls:
  var c=panel.module_controls[key]
  var branch=c.branch
  var local_junction: Vector2=branch.route[0]
  var junction: Vector2=branch.get_global_transform_with_canvas()*local_junction
  var scroll_point: Vector2=panel.module_scroll.get_global_transform_with_canvas().affine_inverse()*junction
  if not Rect2(Vector2.ZERO,panel.module_scroll.size).has_point(scroll_point):continue
  visible_keys.append(key)
  var pipe_point: Vector2=panel.network.get_global_transform_with_canvas()*ROUTES.point_at(panel.network.route,branch.flow_offset)
  check(junction.distance_to(pipe_point)<1.0,tag+": shared trunk/branch junction "+key)
  var machine_inlet: Vector2=c.row.get_global_transform_with_canvas()*ROUTES.inlet(key)
  var pipe_end: Vector2=branch.get_global_transform_with_canvas()*branch.route[-1]
  check(machine_inlet.distance_to(pipe_end)<0.01,tag+": actual machine inlet "+key)
  # Centerline samples must land on the colored pipe, never the cream room backing.
  for x in [0.0,12.0,24.0,36.0]:
   var pixel: Vector2=root.get_stretch_transform()*(branch.get_global_transform_with_canvas()*(local_junction+Vector2(x,0)))
   if pixel.x<0 or pixel.y<0 or pixel.x>=im.get_width() or pixel.y>=im.get_height():continue
   var color:=im.get_pixelv(Vector2i(pixel))
   check((color.b>color.r*1.1 and color.g>color.r*1.15) or (color.g>0.95 and color.b>0.90),tag+": pipe-center pixel "+key+" x="+str(x)+" "+str(color))
 for distance in [110.0,130.0,160.0,190.0,260.0,350.0,420.0,450.0,500.0,700.0,900.0,1100.0]:
  var page_point: Vector2=ROUTES.point_at(panel.network.route,distance)
  var pixel: Vector2=root.get_stretch_transform()*(panel.network.get_global_transform_with_canvas()*page_point)
  var color:=im.get_pixelv(Vector2i(pixel))
  check((color.b>color.r*1.1 and color.g>color.r*1.15) or (color.g>0.95 and color.b>0.90),tag+": core outlet / bend / trunk pixel distance="+str(distance)+" "+str(color))
 print("ROUTE COVERAGE ",tag," ",visible_keys)
 check(visible_keys.size()==3,tag+": all three visible device inlets sampled")
 im.save_png("res://.runtime/supply-route-"+tag+".png")
func run() -> void:
 scene=load("res://main.tscn").instantiate()
 scene.automation_args=["--capture"]
 root.add_child(scene)
 scene.set_process(false)
 scene.game.save_enabled=false
 check(is_instance_valid(scene.ship_view),"Production main.tscn retains the current toon battlefield")
 scene.fps_label.hide()
 scene.game.profile.cleared=range(1,101)
 scene.game.profile.highestLevel=101
 scene.game.profile.lifetime_max_stage=101
 scene.game.profile.onboarding.completed=true
 scene.game.rebuild_unlocks()
 scene.game.pending_unlocks.clear()
 scene.game.profile.resources["2"]=100000.0
 for p in scene.game.profile.planets.values():p.conquered=false
 check(scene.game.upgrade_reactor(4),"Real capacity upgrade")
 scene.build_ui()
 scene.equipment_tabs.current_tab=2
 await process_frame
 panel=scene.reactor_panel
 root.size=Vector2i(2048,1280)
 var g=scene.game
 var capacity: int=g.reactor_capacity()
 check(capacity!=100,"Non-100 capacity fixture uses real upgrade API")
 for key in g.reactor_modules():g.set_reactor_allocation(key,0)
 await snapshot("zero")
 g.set_reactor_allocation("weapons",1)
 await snapshot("low-no-free")
 g.set_reactor_allocation("weapons",0)
 g.profile.planets["1"].conquered=true
 check(is_equal_approx(g.charge_free_ratio(),0.1),"Actual first-planet free charge")
 await snapshot("free-only")
 check(g.reactor_allocated()==0,"Free power does not consume budget")
 g.set_reactor_allocation("weapons",25)
 await snapshot("manual25-free")
 check(panel.module_controls.weapons.energy.text.contains("25 / 207") and panel.module_controls.weapons.share.text.contains("12.1%"),"25 energy is 12.1 percent at capacity 207")
 g.set_reactor_allocation("weapons",50)
 await snapshot("partial-free")
 check(is_equal_approx(g.reactor_effective_ratio("weapons"),50.0/capacity+0.1),"50 energy share is 50/capacity, plus free ratio")
 check(not panel.module_controls.weapons.share.text.contains("50%"),"50 energy is not 50 percent")
 g.set_reactor_allocation("weapons",capacity)
 await snapshot("full-free")
 check(is_equal_approx(g.reactor_effective_ratio("weapons"),1.1),"Effective ratio above 100 percent remains uncapped")
 check(panel.module_controls.weapons.bay_energy.text.contains("110%"),"Text preserves 110 percent")
 check(panel.module_controls.weapons.scene_fx.ratio==1.0,"Visual intensity alone is capped")
 g.profile.planets["2"].conquered=true
 await snapshot("free-increase")
 check(is_equal_approx(g.charge_free_ratio(),0.2),"Free level change from real second-planet reward")
 var before: int=g.reactor_capacity()
 panel.upgrade("x1")
 await snapshot("capacity-upgrade")
 check(g.reactor_capacity()>before,"Existing upgrade updates free energy and pool")
 g.set_reactor_allocation("weapons",50)
 for resolution in [Vector2i(2048,1280),Vector2i(1180,760)]:
  root.size=resolution
  for slot in [0,1]:
   panel.module_scroll.go_to_slot(slot)
   await route_pixels(str(resolution.x)+"-slot"+str(slot))
 root.size=Vector2i(1180,760)
 g.profile.grantedUnlocks=[]
 g.profile.cleared=[1]
 g.rebuild_unlocks()
 g.set_reactor_allocation("condensation",0)
 await snapshot("locked")
 var source_strength := 0.0
 for key in g.reactor_modules():source_strength+=g.reactor_effective_ratio(key)
 check(is_equal_approx(panel.module_controls.weapons.branch.trunk_ratio,clampf(source_strength,0.0,1.0)),"Module unlock change invalidates existing trunk strength")
 check(panel.module_controls.defence.boost.text.begins_with(UIText.t("reactor.module.defence.effect")) and UIText.t("reactor.module.defence.effect")=="装甲与护盾","Defence presentation names both affected capacities")
 check(panel.module_controls.condensation.row.tooltip_text.contains(UIText.t("reactor.module.condensation.desc")),"Condensation detail retains direct-drop-only scope")
 check(not panel.module_controls.condensation.slider.editable and panel.module_controls.condensation.branch.ratio==0.0 and not panel.module_controls.condensation.scene_fx.is_processing(),"Locked module receives no free power")
 g.paused=true
 panel.refresh()
 var state:=phase_state()
 await create_timer(0.2).timeout
 check(state==phase_state() and state.all(func(s):return not s[1]),"Pause freezes all dynamic layers")
 g.paused=false
 panel.refresh()
 scene.select_system(0)
 state=phase_state()
 check(state.all(func(s):return not s[1]),"Parent page_active boundary stops every layer synchronously")
 await create_timer(0.2).timeout
 check(state==phase_state(),"Hidden phases remain unchanged")
 scene.select_system(2)
 await process_frame
 panel.refresh()
 check(panel.network.is_processing(),"Reveal resumes free supply")
 var old_level: int=g.profile.reactorLevel
 panel.upgrade("x10")
 check(g.profile.reactorLevel==old_level+10,"x10 preserves upgrade behavior")
 old_level=g.profile.reactorLevel
 var max_count: int=g.reactor_max_upgrades()
 panel.upgrade("MAX")
 check(g.profile.reactorLevel==old_level+max_count,"MAX preserves affordability and upgrade behavior")
 if OS.get_environment("REACTOR_RECORD")=="1":await record()
 var file:=FileAccess.open("res://.runtime/supply-cases.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "))
 file.close()
 print("REACTOR SUPPLY: ",checks," checks, ",failures," failures")
 scene.queue_free()
 await process_frame
 await process_frame
 quit(1 if failures else 0)

func record() -> void:
 var g=scene.game
 g.profile.cleared=range(1,101)
 g.rebuild_unlocks()
 for key in g.reactor_modules():g.set_reactor_allocation(key,0)
 g.profile.reactorLevel=5
 g.profile.planets["1"].conquered=true
 g.profile.planets["2"].conquered=false
 g.profile.resources["2"]=100000.0
 panel.module_scroll.go_to_slot(0)
 panel.refresh()
 root.size=Vector2i(1180,760)
 await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://.runtime/reactor-v2-frames")
 var ticks: Array=[]
 var start:=Time.get_ticks_usec()
 var elapsed:=0.0
 var state:=0
 var frame:=0
 while elapsed<10.0:
  elapsed=(Time.get_ticks_usec()-start)/1000000.0
  if elapsed>=3.0 and state==0:
   panel.change_allocation(25,"weapons")
   state=1
  if elapsed>=6.0 and state==1:
   panel.module_scroll.go_to_slot(1)
   state=2
  await process_frame
  await RenderingServer.frame_post_draw
  elapsed=(Time.get_ticks_usec()-start)/1000000.0
  root.get_texture().get_image().save_png("res://.runtime/reactor-v2-frames/%05d.png" % frame)
  ticks.append(elapsed)
  frame+=1
 var metadata:={"wall_seconds":(Time.get_ticks_usec()-start)/1000000.0,"actual_frames":frame,"timestamps":ticks,"fixture":"Production main.tscn, isolated memory progress, main gameplay loop stopped; reactor process clocks run normally","stages":"0-3s free-only; 3-6s manual25 + free; 6-10s modules2-4"}
 var output:=FileAccess.open("res://.runtime/reactor-v2-recording.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(metadata,"  "))
 output.close()
 print("REACTOR REALTIME CAPTURE ",metadata.wall_seconds,"s ",frame," actual frames")
