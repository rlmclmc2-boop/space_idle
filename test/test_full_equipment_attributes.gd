extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=61;g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.enhancementLevel=1;g.profile.enhancementOrder.defence=["delayed_damage","memory_material","adaptation"];g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(0);await process_frame
 var p=scene.equipment_panel;p.refresh();p.select_item("defence_0");p.show_inspector();if not p.details_open:p.toggle_details()
 await process_frame
 var before=JSON.stringify(g.profile);var rng=g.rng.state;var debt=g.enhancement_deferred_total()
 var body=scene.enhancement_panel.effect_description("delayed_damage")
 check(p.detail.stats.text.contains(body) and body.contains("满血") and body.contains("每秒 5 次"),"Real full armour attributes retain complete buffer settlement cadence and full-health debt explanation")
 check(not p.detail.stats.clip_text and p.detail.stats.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING and p.detail.stats.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"Requested full attributes use wrapping without inherited card ellipsis")
 check(p.detail.stats.tooltip_text.contains(body),"Full attribute hover includes the buffer paragraph rather than only damage calculation")
 var tip=p.detail.stats._make_custom_tooltip(p.detail.stats.tooltip_text);root.add_child(tip);await process_frame
 check(tip.get_child(0).text.contains(body) and tip.get_child(0).custom_minimum_size.x==620,"Existing bounded hover presentation renders complete requested text")
 p.update_detail_height(true)
 check(p.detail_body.custom_minimum_size.y>=p.detail.stats.position.y+p.detail.stats.get_minimum_size().y and p.detail.stats.get_visible_line_count()==p.detail.stats.get_line_count(),"Inspector scroll extent accounts for every wrapped line of full attributes")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng and g.enhancement_deferred_total()==debt,"Reading attributes changes no pending damage, defence mechanics, resources or RNG")
 tip.queue_free();scene.queue_free();await process_frame
 print("Full equipment attributes: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
