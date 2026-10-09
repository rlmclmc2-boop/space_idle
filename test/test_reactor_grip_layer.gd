extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(scene.equipment_tabs.get_tab_idx_from_control(scene.reactor_panel));scene.reactor_panel.refresh();await process_frame
 var controls:Dictionary=scene.reactor_panel.module_controls.weapons
 var track=controls.track;var grip=track.layers.grip
 check(grip.z_index+track.z_index>controls.manual_segment.z_index and grip.z_index+track.z_index>controls.free_segment.z_index,"Grip draws above later overlapping supply strips")
 check(grip.size==track.size and grip.get_parent()==track,"Grip follows the same track coordinate space without a rebuilt row")
 check(grip.mouse_filter==Control.MOUSE_FILTER_IGNORE and not grip.is_processing(),"Grip does not intercept input or start a timer")
 controls.input.apply_pointer(controls.input.size.x*.4)
 check(is_equal_approx(grip.preview_ratio,.4) and is_equal_approx(grip.ratio,track.ratio),"Pointer preview and actual allocation both reach overlay grip")
 var same=grip;controls.input.finish_drag(controls.input.size.x*.3)
 check(grip==same and grip.preview_ratio<0 and is_equal_approx(grip.ratio,track.ratio),"Release retains grip and restores actual ratio")
 check(controls.manual_segment.visible and controls.free_segment.visible,"Colored manual and free supply layers remain present")
 scene.queue_free();await process_frame
 print("REACTOR GRIP LAYER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
