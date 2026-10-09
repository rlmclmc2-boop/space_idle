extends "res://checkpoint_scene_cost.gd"
# Preparation/amortization and actual legal upgrade only; no repeated static suite.
var controller
var failures = []
var frame_preparation = []
func run():
 Engine.set_meta("checkpoint_path","res://round2.json")
 Engine.set_meta("checkpoint_stage",7);Engine.set_meta("checkpoint_group",4)
 Engine.set_meta("checkpoint_ship","Frigate")
 await super.run()
func tick(scene):
 var started=Time.get_ticks_usec()
 var before=0 if controller==null else controller.capture_times.size()
 scene._process(0.0);await process_frame;await RenderingServer.frame_post_draw
 var elapsed=Time.get_ticks_usec()-started
 if controller!=null and controller.capture_times.size()>before:
  var capture=controller.capture_times[-1].duplicate();capture.frame_us=elapsed;frame_preparation.append(capture)
 return elapsed
func check(label,condition,details={}):
 print("COST_BOUNDARY ",JSON.stringify({"case":label,"pass":condition,"details":details}))
 if not condition:failures.append(label)
func settle(scene):
 var started=Time.get_ticks_usec()
 while not controller.retained and Time.get_ticks_usec()-started<5000000:
  await tick(scene)
 return controller.retained
func click(control):
 var point=control.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  root.push_input(event,true)
func row(scene,name,count=32,interval=0):
 var samples=[];var calls=[];var retained_frames=0
 var initial=controller.capture_times.size();var backoffs=controller.backoffs
 var text=scene.equipment_panel.total.text
 for i in count:
  if interval>0 and i%interval==0:scene.equipment_panel.total.text=text+" "+str(i)
  samples.append(await tick(scene));calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  if controller.retained:retained_frames+=1
 print("COST_ROW ",JSON.stringify({"name":name,"frames":stats(samples),"calls":stats(calls),"retained_frames":retained_frames,"capture_frames":controller.capture_times.size()-initial,"backoffs":controller.backoffs-backoffs}))
 scene.equipment_panel.total.text=text
func measure(scene,g,_hash):
 if OS.get_cmdline_user_args().has("--attribution-only"):
  await super.measure(scene,g,_hash)
  return
 for _i in 12:await tick(scene)
 var original=JSON.stringify(g.profile,"",true,true)
 controller=load("res://retained_workspace_controller.gd").new();scene.add_child(controller)
 if not controller.setup(scene):fail("bit_collision");return
 # Adjacent interleaved rows avoid treating the earlier large software-render
 # drift as a proven gain. Only this changed candidate's cost is measured.
 for index in 3:
  controller.set_capture_enabled(false)
  for _i in 6:await tick(scene)
  await row(scene,"quiet_control_"+str(index),16)
  controller.set_capture_enabled(true)
  check("quiet_settle_"+str(index),await settle(scene))
  for _i in 6:await tick(scene)
  await row(scene,"quiet_retained_"+str(index),16)
 # One changed number must prepare only its intersecting strip.
 var total=scene.equipment_panel.total;var text=total.text
 var initial=controller.capture_times.size()
 total.text=text+" 98765";await tick(scene)
 check("number_immediate_live",not controller.retained)
 check("number_settle",await settle(scene))
 check("number_partial_capture",controller.capture_times.size()-initial==1,{"new_capture_frames":controller.capture_times.size()-initial})
 root.get_texture().get_image().save_png("res://.runtime/workspace-cost-number-retained.png")
 controller.set_capture_enabled(false);await tick(scene)
 root.get_texture().get_image().save_png("res://.runtime/workspace-cost-number-live.png")
 print("COST_QUALITY_RECT ",str(controller.capture_rect))
 total.text=text
 for _i in 8:await tick(scene)
 await row(scene,"quiet_return",16)
 # Identical presentation-change sequence: measure frequent invalidation's net
 # cost. Report wall-time frequencies, not a claim of fixed local game FPS.
 await row(scene,"changing_control",48,6)
 controller.quiet_us=controller.MIN_QUIET_US;controller.attempts_since_retained=0
 controller.set_capture_enabled(true)
 var churn_initial=controller.capture_times.size()
 await row(scene,"changing_candidate",48,6)
 check("churn_has_no_stale_retained",not controller.retained)
 check("churn_no_preparation",controller.capture_times.size()==churn_initial)
 controller.set_capture_enabled(false)
 await row(scene,"changing_return",48,6)
 check("profile_unchanged_before_action",original==JSON.stringify(g.profile,"",true,true))
 # Father's authorized natural stage7 copy: actual GUI upgrade spends legal
 # resources; it may invalidate resource feedback, card stats and navigation.
 controller.set_capture_enabled(true);check("pre_upgrade_settle",await settle(scene))
 var panel=scene.equipment_panel;var upgraded=false
 for id in panel.cards:
  var card=panel.cards[id];var item=panel.items[id]
  if card.upgrade_button.disabled or not card.upgrade_button.is_visible_in_tree():continue
  var old_level=g.slot_entry(item.category,item.index).level
  var old_resources=g.profile.resources.duplicate(true)
  var old_caption=card.fields.level.text
  click(card.upgrade_button);await tick(scene)
  check("legal_upgrade_level",g.slot_entry(item.category,item.index).level==old_level+1)
  check("legal_upgrade_feedback",card.fields.level.text!=old_caption and old_resources!=g.profile.resources and not controller.retained)
  check("upgrade_settle",await settle(scene))
  root.get_texture().get_image().save_png("res://.runtime/workspace-cost-upgrade-retained.png")
  controller.set_capture_enabled(false);await tick(scene)
  root.get_texture().get_image().save_png("res://.runtime/workspace-cost-upgrade-live.png")
  upgraded=true;break
 check("legal_upgrade_exercised",upgraded)
 print("COST_PREPARATION ",JSON.stringify({"frames":frame_preparation,"backoffs":controller.backoffs,"failures":failures}))
 var original_mask=controller.original_mask
 var owner=weakref(controller)
 controller.queue_free();controller=null
 await tick(scene);await tick(scene)
 check("owner_exit_restores",owner.get_ref()==null and root.canvas_cull_mask==original_mask and scene.equipment_tabs.visibility_layer==1,{"owner_released":owner.get_ref()==null,"mask":root.canvas_cull_mask,"source_layer":scene.equipment_tabs.visibility_layer})
 controller=null
 if not failures.is_empty():fail(failures)
