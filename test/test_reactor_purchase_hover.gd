extends SceneTree
const Preview=preload("res://scripts/reactor_upgrade_preview.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.reactorLevel=20;g.profile.reactorAllocation={"weapons":1500,"defence":1500,"smelting":94,"condensation":100};g.invalidate_stat_cache()
 var quote:Dictionary=Preview.quote(g,15);g.profile.resources["2"]=quote.cost
 scene.refresh_tab_visibility();scene.select_system(2);await process_frame
 var p=scene.reactor_panel;p.refresh();var button=p.upgrade_buttons.MAX
 check(p.affordable_count==15 and button.tooltip_text.begins_with("购买 15 级\n合计 "+NumberFormat.resource(quote.cost,true)+" 铀"),"Natural-like MAX15 hover shows quantity and authoritative full total")
 check(button.tooltip_text.contains("能源 "+NumberFormat.compact(g.reactor_capacity())+" → "+NumberFormat.compact(quote.next_capacity)) and button.tooltip_text.contains("武器"),"Primary hover retains capacity and meaningful module returns")
 check(not button.tooltip_text.contains(UIText.t("reactor.purchase_scope")) and not button.tooltip_text.contains("免费") and not button.tooltip_text.contains("精确"),"Hover omits long rules and irrelevant free-energy instructions")
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 var content=button._make_custom_tooltip(button.tooltip_text);root.add_child(content);await process_frame
 var label:Label=content.get_child(0)
 check(label.custom_minimum_size.x==460 and label.get_theme_font_size("font_size")==20 and label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and label.get_theme_constant("line_spacing")==4,"Native tooltip wraps at a bounded width with normal font and separated lines")
 check(content.get_combined_minimum_size().x<=484.01,"Tooltip minimum width includes bounded content and padding")
 p.show_upgrade_details()
 check(p.details_text.text.contains(UIText.t("reactor.purchase_scope")) and p.details_text.text.count(UIText.t("reactor.purchase_scope"))==1 and p.details_text.text.contains("加成"),"Requested full upgrade details retain scope once and before/after values")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng,"Both quote presentations leave budget, allocation and RNG unchanged")
 content.queue_free();scene.queue_free();await process_frame
 print("Reactor purchase hover: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
