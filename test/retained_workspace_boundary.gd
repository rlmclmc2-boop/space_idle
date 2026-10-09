extends "res://checkpoint_scene_cost.gd"
# Same natural checkpoint, finite GUI boundaries; does not advance combat or mint resources.
var controller
var failures = []
var capture_frame_us = []
func tick(scene, count = 1):
 for _i in count:
  var began = Time.get_ticks_usec()
  var before = 0 if controller == null else controller.capture_times.size()
  scene._process(0.0);await process_frame;await RenderingServer.frame_post_draw
  if controller != null and controller.capture_times.size() > before:capture_frame_us.append(Time.get_ticks_usec()-began)
func settle(scene):
 await tick(scene,1)
 var began = Time.get_ticks_usec()
 while not controller.retained and controller.supports_scroll() and scene.equipment_tabs.current_tab==0 and Time.get_ticks_usec()-began<5000000:
  await tick(scene,1)
 return controller.retained
func check(label, condition, details = {}):
 print("BOUNDARY ",JSON.stringify({"case":label,"pass":condition,"details":details}))
 if not condition: failures.append(label)
func click(control: Control):
 var point = control.get_global_rect().get_center()
 var motion = InputEventMouseMotion.new();motion.position = point;root.push_input(motion,true)
 for pressed in [true,false]:
  var event = InputEventMouseButton.new();event.position = point
  event.button_index = MOUSE_BUTTON_LEFT;event.pressed = pressed;root.push_input(event,true)
func measure(scene,g,_save_hash):
 await tick(scene,12)
 var panel = scene.equipment_panel
 var profile = JSON.stringify(g.profile,"",true,true)
 controller = load("res://retained_workspace_controller.gd").new();scene.add_child(controller)
 if not controller.setup(scene):fail("workspace bit collision");return
 await settle(scene)
 check("quiet_retained",controller.retained,{"captures_us":controller.capture_times,"calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 # Card selection uses actual root GUI input, with original nodes still in place.
 var card = panel.cards.values()[-1]
 click(card);await tick(scene,1)
 check("selection_input",panel.selected == card.slot_id,{"selected":panel.selected,"fallbacks":controller.fallback_count})
 await settle(scene)
 check("selection_recaptured",controller.retained)
 root.get_texture().get_image().save_png("res://.runtime/workspace-selected-retained.png")
 controller.invalidate();await tick(scene,1)
 root.get_texture().get_image().save_png("res://.runtime/workspace-selected-live.png")
 # Presentation-number update probes exact draw signal path without altering gameplay data.
 await settle(scene)
 var label = panel.total;var old_text = label.text
 label.text = old_text + " 12345"
 await tick(scene,1)
 check("number_same_frame_fallback",not controller.retained)
 await settle(scene)
 check("number_recaptured",controller.retained)
 label.text = old_text;await settle(scene)
 # Native popup is outside retained Canvas; actual click must still open it.
 click(card.name_button);await tick(scene,1)
 check("popup_real_input",card.name_button.get_popup().visible)
 card.name_button.get_popup().hide();await settle(scene)
 # Keyboard focus redraws native button state.
 card.release_focus();await settle(scene)
 card.grab_focus();await tick(scene,1)
 check("focus_same_frame_fallback",not controller.retained)
 await settle(scene)
 # Shrinking the actual window causes layout + native-pixel cache reallocation.
 var old_size = root.size;root.size = Vector2i(1000,640);await tick(scene,1)
 check("resize_same_frame_fallback",not controller.retained)
 await settle(scene)
 check("resize_recaptured",controller.retained,{"cache_size":str(controller.cache.size)})
 # Authorized presentation-only fixture: constrain the existing scroll region;
 # natural inventory stays unchanged (the six normal cards fit at default size).
 var old_scroll_size = panel.grid_scroll.size
 panel.grid_scroll.size.y = 220;await settle(scene)
 var bar = panel.grid_scroll.get_v_scroll_bar()
 var original_scroll = bar.value
 check("overflow_region_full_live",not controller.retained,{"max":bar.max_value,"page":bar.page})
 if bar.max_value > bar.page:
  await settle(scene)
  var wheel = InputEventMouseButton.new();wheel.position = panel.grid_scroll.get_global_rect().get_center()
  wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed = true;root.push_input(wheel,true)
  check("scroll_signal_immediate_fallback",not controller.retained and bar.value > original_scroll,{"scroll":bar.value})
  await settle(scene)
  check("overflow_scroll_stays_live",not controller.retained and not controller.supports_scroll())
  root.get_texture().get_image().save_png("res://.runtime/workspace-scroll-retained.png")
  controller.invalidate();await tick(scene,1)
  root.get_texture().get_image().save_png("res://.runtime/workspace-scroll-live.png")
  bar.value = original_scroll
 else:check("scroll_available",false)
 panel.grid_scroll.size = old_scroll_size
 root.size = old_size;await settle(scene)
 # Color-only property has no draw signal; explicit bounded signature must catch it.
 var color = panel.detail.status.modulate
 panel.detail.status.modulate = Color.RED;await tick(scene,1)
 check("color_same_frame_fallback",not controller.retained)
 panel.detail.status.modulate = color;await settle(scene)
 scene.select_system(9);await tick(scene,3)
 check("animated_page_full_live",not controller.retained and root.canvas_cull_mask==controller.original_mask)
 scene.select_system(0);await settle(scene)
 check("reveal_catches_up",controller.retained)
 check("outside_header_live",scene.system_nav_buttons[9].visibility_layer != controller.CACHE_BIT)
 check("profile_unchanged",profile==JSON.stringify(g.profile,"",true,true))
 # A real legal upgrade on the in-memory natural QA copy tests authoritative
 # resource and level feedback; save writes remain disabled.
 var upgraded = false
 for id in panel.cards:
  var candidate = panel.cards[id];var item = panel.items[id]
  if candidate.upgrade_button.disabled or not candidate.upgrade_button.is_visible_in_tree():continue
  var old_level = g.slot_entry(item.category,item.index).level
  click(candidate.upgrade_button);await tick(scene,1)
  check("real_upgrade_number_feedback",g.slot_entry(item.category,item.index).level == old_level+1 and not controller.retained)
  await settle(scene)
  check("real_upgrade_recaptured",controller.retained)
  upgraded = true;break
 if not upgraded:print("UNVERIFIED_REAL_UPGRADE no affordable visible upgrade in unchanged natural QA checkpoint; presentation-number invalidation tested separately")
 var fixture = Label.new();fixture.text="boundary";panel.add_child(fixture);await tick(scene,1)
 check("new_control_fallback",not controller.retained)
 fixture.reparent(scene.ui)
 check("moved_control_restored",fixture.visibility_layer==1)
 fixture.queue_free();await tick(scene,1)
 print("CONTROLLER_SUMMARY ",JSON.stringify({"capture_us":controller.capture_times,"capture_frame_us":capture_frame_us,"real_upgrade_exercised":upgraded,"fallbacks":controller.fallback_count,"failures":failures}))
 controller.shutdown();await tick(scene,1)
 check("teardown_restores",root.canvas_cull_mask==controller.original_mask and scene.equipment_tabs.visibility_layer==1)
 if not failures.is_empty():fail(failures)
