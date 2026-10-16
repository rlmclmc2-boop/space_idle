extends SceneTree
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func snap(path:String)->void:
 await process_frame
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../test/"+path+".png")
func run()->void:
 var scene=load("res://main.tscn").instantiate()
 scene.automation_args=["--capture"]
 root.add_child(scene)
 scene.set_process(false)
 scene.game.save_enabled=false
 scene.game.profile.onboarding.completed=true
 scene.beginner_guide.set_process(false)
 scene.beginner_guide.hide()
 scene.game.stage=3
 scene.game.group_index=4
 scene.game.pending_unlocks.clear()
 scene.select_system(11)
 scene.refresh_navigation()
 var page=scene.enemy_intel_page
 page.refresh_if_needed()
 check(page.selected_point==3,"opens current point")
 check(page.visible_entry_indices.size()==3,"three table-authored identities at3-4")
 check(not page.detail_scroll.visible,"details collapsed by default")
 var route:int=page.route_builds
 var details:int=page.detail_builds
 for i in 120:page.refresh_if_needed()
 check(page.route_builds==route and page.detail_builds==details,"unchanged visible frames do not rebuild")
 await snap("enemy-intel-overview")
 page.details_button.button_pressed=true
 check(page.detail_scroll.visible,"details toggle opens")
 check(page.detail_builds==details,"details toggle does not recompute")
 await snap("enemy-intel-details")
 page.follow_current=false
 page.show_point(0)
 scene.game.group_index=5
 page.refresh_if_needed()
 check(page.selected_point==0,"manual browsing stays selected while combat advances")
 page.follow_current=true
 page.show_point(page.current_point)
 check(page.selected_point==4,"return current point")
 page.hide()
 scene.game.stage=2
 page.refresh_if_needed()
 check(page.route_builds==route,"hidden page does no route work")
 page.show()
 page.refresh_if_needed()
 check(page.route_builds==route+1,"new stage builds once on reopen")
 print("enemy intel polish: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
