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
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear();g.profile.onboarding.completed=true
 var p=scene.equipment_panel
 for id in g.profile.resources:g.profile.resources[id]=1e6
 p.refresh();p.select_item("weapons_0");p.show_inspector()
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var count:int=g.max_upgrade_amount_slot("weapons",0);var costs:Dictionary=g.slot_upgrade_cost("weapons",0,count)
 var quote:String=p.max_upgrade_quote()
 check(count>1 and quote.contains("可升%d级"%count) and quote.contains(scene.cost_text(costs)),"Inspector MAX shows authoritative affordable quantity and complete batch costs")
 var tooltip=p.detail.max._make_custom_tooltip(p.detail.max.tooltip_text)
 check(tooltip.get_child(0).text==quote,"Actual MAX hover obtains the live quote")
 # Keep both native custom tooltip contents alive while resources change.
 root.add_child(tooltip)
 p.set_upgrade_amount(0)
 check(p.items.weapons_0.upgrade_count==count and p.cards.weapons_0.upgrade_button.tooltip_text==quote,"Card global MAX reuses same refresh quantity and displays same quote")
 check(p.cards.weapons_0.fields.action.text=="升级+%d"%count and p.cards.weapons_0.upgrade_button.text.contains("升级+%d"%count),"MAX actual ink and native button show the existing quoted quantity")
 check(p.cards.weapons_0.fields.action.get_theme_font("font").get_string_size(p.cards.weapons_0.fields.action.text,HORIZONTAL_ALIGNMENT_LEFT,-1,p.cards.weapons_0.fields.action.get_theme_font_size("font_size")).x<=p.cards.weapons_0.fields.action.size.x,"Visible quantity fits its reserved button width")
 check(p.cards.weapons_0.fields.cost.get_theme_font("font").get_string_size(p.cards.weapons_0.fields.cost.text,HORIZONTAL_ALIGNMENT_LEFT,-1,p.cards.weapons_0.fields.cost.get_theme_font_size("font_size")).x<=p.cards.weapons_0.fields.cost.size.x,"Quoted cost remains readable beside the added quantity")
 var card_button=p.cards.weapons_0.upgrade_button
 var card_tooltip=card_button._make_custom_tooltip(card_button.tooltip_text);root.add_child(card_tooltip)
 for id in g.profile.resources:g.profile.resources[id]=1e9
 p.refresh_pending()
 var increased:String=p.max_upgrade_quote()
 check(p.cards.weapons_0.fields.action.text=="升级+%d"%p.items.weapons_0.upgrade_count,"Visible MAX quantity follows the existing affordability refresh")
 check(increased!=quote and tooltip.get_child(0).text==increased,"Existing resource refresh updates already-open inspector MAX quote")
 check(card_tooltip.get_child(0).text==card_button.tooltip_text and card_tooltip.get_child(0).text==increased,"Already-open card MAX quote stays synchronized with live button costs")
 for id in g.profile.resources:g.profile.resources[id]=1e6
 p.refresh_pending()
 check(tooltip.get_child(0).text==quote and card_tooltip.get_child(0).text==quote,"Open quotes follow decreases as well as production increases")
 tooltip.free();card_tooltip.free()
 p.refresh_pending()
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Preview changes neither profile nor RNG")
 var old_level:int=g.module_entry("weapons",0).level
 p.act("max")
 check(int(g.module_entry("weapons",0).level)==old_level+count,"Existing purchase applies the quoted quantity")
 for id in costs:check(GrowthNumber.compare(g.profile.resources[id],GrowthNumber.subtract(1e6,costs[id]))==0,"Existing purchase deducts quoted resource "+str(id))
 for id in g.profile.resources:g.profile.resources[id]=0
 check(p.max_upgrade_quote().contains("可升0级"),"Hover recomputes after resources change and reports zero quantity")
 p.set_upgrade_amount(1)
 check(p.cards.weapons_0.fields.action.text==UIText.t("equipment.upgrade_cost",{"cost":""}).strip_edges() and p.cards.weapons_0.fields.action.size.x==50,"Returning to single upgrade restores its compact existing layout")
 scene.queue_free();await process_frame
 print("EQUIPMENT MAX: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
