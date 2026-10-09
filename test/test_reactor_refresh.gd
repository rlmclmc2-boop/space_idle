extends SceneTree

class ObservedGame extends BattleGame:
	var affordability_queries := 0
	var effect_queries := 0
	func reactor_effective_ratio(key: String) -> float:
		effect_queries+=1
		return super.reactor_effective_ratio(key)
	func reactor_max_upgrades() -> int:
		affordability_queries += 1
		return super.reactor_max_upgrades()

class ObservedUI extends "res://scripts/main.gd":
	var writes: Dictionary = {}
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			writes[control.get_instance_id()] = int(writes.get(control.get_instance_id(),0))+1
		super.set_ui_value(control,property,value)

var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene := ObservedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	var g := ObservedGame.new(scene.db,false)
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.paused=true
	g.profile.resources["2"]=1000.0
	scene.game=g
	g.event.connect(scene.on_event)
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	await process_frame
	var panel=scene.reactor_panel
	panel.refresh()
	var fee_game:=BattleGame.new(scene.db,false);fee_game.profile.cleared=[1];fee_game.profile.reactorLevel=2;fee_game.profile.resources["2"]=6.9
	check(fee_game.reactor_upgrade_cost()==7 and fee_game.reactor_max_upgrades()==0 and not fee_game.upgrade_reactor(1) and fee_game.profile.resources["2"]==6.9,"Fractional stock cannot buy the actual integer fee and is preserved")
	fee_game.profile.resources["2"]=7.9
	check(fee_game.upgrade_reactor(1) and is_equal_approx(float(fee_game.profile.resources["2"]),0.9),"Integer debit retains the unspent fractional balance")
	var bulk:=BattleGame.new(scene.db,false);bulk.profile.cleared=[1];bulk.profile.resources["2"]=278.5
	var unit_sum:=0.0
	for level in range(1,11):unit_sum+=ceilf(float(scene.db.config.reactorUpgradeBase)*pow(float(scene.db.config.reactorUpgradeGrowth),level-1))
	var preview=preload("res://scripts/reactor_upgrade_preview.gd")
	check(unit_sum==278 and preview.quote(bulk,10).cost==unit_sum and bulk.reactor_max_upgrades()==10,"Batch quote and MAX use the independently rounded sum of ten level fees")
	var singles:=BattleGame.new(scene.db,false);singles.profile.cleared=[1];singles.profile.resources["2"]=278.5
	for i in 10:check(singles.upgrade_reactor(1),"Repeated single purchase is affordable")
	check(bulk.upgrade_reactor(10) and bulk.profile.resources["2"]==singles.profile.resources["2"] and bulk.profile.resources["2"]==0.5,"Batch and split purchases debit the same actual integer total")
	bulk.profile.reactorLevel=1;bulk.profile.resources["2"]=277.9
	check(bulk.reactor_max_upgrades()==9 and not bulk.upgrade_reactor(10),"MAX respects the new integer batch boundary")
	check(NumberFormat.resource(13.5)=="13" and NumberFormat.resource(39100)=="39.1K" and NumberFormat.resource_pair(1238.9,1239)=={"owned":"1238","cost":"1239","exact":true},"Whole-resource display preserves suffix precision and reveals hidden shortages")
	var huge_pair:Dictionary=NumberFormat.resource_pair({"m":2.3004,"e":500},{"m":2.3005,"e":500})
	check(huge_pair.exact and huge_pair.owned!=huge_pair.cost,"Huge resource shortages also retain distinct exact scientific significands")
	var prior_level:int=g.profile.reactorLevel;var prior_budget=g.profile.resources["2"]
	g.profile.reactorLevel=2;g.profile.resources["2"]=6.9;panel.refresh()
	check(panel.uranium_label.text==UIText.t("reactor.uranium",{"uranium":"6"}) and panel.upgrade_buttons.x1.disabled and panel.upgrade_buttons.x1.text.contains("7铀") and scene.resource_display("2")=="6","Actual reactor and resource strip agree on integer fee/stock/disabled state")
	for level in range(1,50):
		g.profile.reactorLevel=level
		var fee=g.reactor_upgrade_cost()
		if fee>=1000 and NumberFormat.resource(fee-0.1)==NumberFormat.resource(fee):
			g.profile.resources["2"]=fee-0.1;panel.refresh()
			check(panel.upgrade_buttons.x1.disabled and panel.uranium_label.text==UIText.t("reactor.uranium",{"uranium":NumberFormat.resource(fee-0.1,true)}) and panel.upgrade_buttons.x1.text.contains(NumberFormat.resource(fee,true)),"Actual underfunded purchase expands a colliding suffix to unequal exact integers")
			break
	g.profile.reactorLevel=prior_level;g.profile.resources["2"]=prior_budget;g.invalidate_stat_cache();panel.refresh()
	var prior_fragments=g.profile.jewelFragments
	g.profile.jewelFragments=31.2;scene.select_system(4);scene.enhancement_panel.open();scene.enhancement_panel.refresh()
	check(scene.enhancement_panel.balance_label.text==UIText.t("enhance.balance",{"amount":"31"}) and scene.enhancement_panel.balance_label.tooltip_text==UIText.t("enhance.balance",{"amount":"31"}) and g.profile.jewelFragments==31.2,"Actual fragment panel displays31 without discarding its internal0.2 balance")
	check(scene.hyperspace_panel.commands.material_number(13)=="13" and scene.hyperspace_panel.commands.material_number(39100)=="39.1K","Other material panels use integer quantities and approved suffix precision")
	g.profile.jewelFragments=prior_fragments;scene.select_system(2);panel.refresh()
	check(NumberFormat.scalar(3.24)=="3" and NumberFormat.scalar(3.26)=="3.5" and NumberFormat.scalar(-0.01)=="0","Ordinary display uses half units without negative zero")
	check(NumberFormat.scalar(39100)=="39.1K" and NumberFormat.scalar({"m":3.91,"e":4})=="39.1K","Scalar display preserves suffix precision for native and large-number values")
	check(NumberFormat.precise(6.75)=="6.75" and g.description_number(0.28)=="0.28","Formula literals and fractional economic values keep precision")
	check(g.format_description({"para1":1.4304762894},"{para1,百分比,保留两位小数}",1)=="143%","Legacy two-decimal percentage templates now use the shared presentation policy")
	check(g.format_description({"para1":0.28},"{para1/0.28,百分比}",1)=="100%","Display policy never quantizes formula operands before evaluation")
	var display_profile:=JSON.stringify(g.profile);var display_rng:=g.rng.state
	var master_help:String=scene.hyperspace_panel.legendary_help.explanation({"effect_id":"drone_master","parameters":{"maximum_reduction":0.553}})
	check(master_help.contains(scene.hyperspace_panel.t("percent",{"value":"55"})) and not master_help.contains("55.3%"),"Owned legendary details use integer percentage points")
	check(JSON.stringify(g.profile)==display_profile and g.rng.state==display_rng,"Formatting legendary details preserves saved parameters and RNG")
	check(scene.enhancement_panel.cadence(0.2)==UIText.t("enhance.cadence.frequency",{"value":"5"}) and scene.enhancement_panel.cadence(0.28)==UIText.t("enhance.cadence.periodic"),"Fixed periodic timing uses an exact frequency or withholds an inaccurate interval")
	check(scene.enhancement_panel.effect_description("memory_material").contains(UIText.t("enhance.cadence.frequency",{"value":"5"})) and scene.enhancement_panel.effect_description("delayed_damage").contains(UIText.t("enhance.cadence.frequency",{"value":"5"})),"Actual memory and deferred-damage descriptions do not show a zero-second interval")
	check(NumberFormat.scalar_is_exact(0.5) and not NumberFormat.scalar_is_exact(0.28) and not NumberFormat.scalar_is_exact(3.24),"Fixed time gate rejects misleading half-unit rounding")
	var beam_entry:Dictionary={"key":"longLaser","level":1}
	var beam:Dictionary=scene.equipment_display_snapshot(beam_entry)
	check(is_equal_approx(float(beam.rate.interval),0.5) and is_equal_approx(float(beam.rate.stage_time),3.0),"Current clean beam mechanism matches its displayable timings")
	check(scene.equipment_panel.card_level_text(beam_entry,"weapons",true,beam).contains("3秒升满") and scene.equipment_panel.rate_notes(beam).contains("达到右值"),"Mechanism-matched fixed beam timings remain discoverable")
	check(scene.equipment_panel.rate_detail(beam,beam).contains(UIText.t("weapon.rate_single",{"damage":scene.number(beam.rate.single),"seconds":"0.5"})),"Actual beam details show the real half-second interval")
	var previous_beam:Dictionary=beam.duplicate(true);previous_beam.rate.interval=0.28;previous_beam.rate.stage_time=3.24
	check(not scene.equipment_panel.card_level_text(beam_entry,"weapons",true,previous_beam).contains("升满") and not scene.equipment_panel.rate_notes(previous_beam).contains("达到右值"),"Non-representable fixed timings remain protected from misleading rounding")
	check(panel.capacity_label.get_parent().position.y>=panel.equalize_button.position.y+panel.equalize_button.size.y and panel.capacity_label.get_parent().position.y-panel.equalize_button.position.y-panel.equalize_button.size.y<=12,"Capacity follows control actions without the removed legend gap")
	check(panel.allocation_hint.position.y>=panel.capacity_label.get_parent().position.y+panel.capacity_label.get_parent().size.y and panel.allocation_hint.position.y+panel.allocation_hint.size.y<=panel.allocation_scroll.position.y,"Temporary-supply warning has a reserved row clear of readouts and controls")
	var slider: HSlider=panel.module_controls.weapons.slider
	check(panel.upgrade_buttons.x1.text.contains(panel.purchase_cost_text(g.reactor_upgrade_cost())) and panel.upgrade_buttons.x1.text.split("\n").size()==2 and panel.upgrade_buttons.x1.tooltip_text.contains(panel.energy_text(g.reactor_capacity_at(int(g.profile.reactorLevel)+1))),"Single purchase shows action and fee; energy projection remains available in details")
	check(panel.upgrade_buttons.x10.tooltip_text.contains("10") and panel.upgrade_buttons.MAX.tooltip_text.contains("收益"),"Batch and MAX expose purchase-specific effect previews")
	check(panel.benefit_label.text==UIText.t("reactor.upgrade_idle") and panel.benefit_label.get_theme_font_size("font_size")>=25,"Zero supply offers the useful next action without a wall of zero percentages")
	check(not panel.allocation_hint.visible and not panel.next_label.visible and not panel.cost_label.visible,"Default hides allocation convention and duplicated next-level cost")
	check(panel.module_controls.values().all(func(c):return not c.allocation_boost.visible and c.allocation_boost.text.is_empty() and not c.share.text.contains("免费")),"No free supply means no default free-zero readouts")
	var xml:=XMLParser.new();xml.open("res://assets/ui/reactor/toon-console.svg")
	var header_aligned:=false
	while xml.read()==OK:
		if xml.get_node_type()!=XMLParser.NODE_ELEMENT or xml.get_node_name()!="rect":continue
		var a:Dictionary={}
		for i in xml.get_attribute_count():a[xml.get_attribute_name(i)]=xml.get_attribute_value(i)
		if str(a.get("fill",""))!="#243d50":continue
		var outer:=Rect2(float(a.get("x",0)),float(a.get("y",0)),float(a.get("width",0)),float(a.get("height",0)))
		var inner:=Rect2(panel.upgrade_plate.position,panel.upgrade_plate.size)
		if outer.encloses(inner) and outer.position.y<inner.position.y and outer.position.x<inner.position.x and outer.end.y<=panel.module_scroll.position.y:header_aligned=true
	check(header_aligned and panel.benefit_label.position.y+panel.benefit_label.size.y<=panel.upgrade_plate.position.y+panel.upgrade_plate.size.y-16,"Static header encloses the foreground, with summary bottom margin and no scroll overlap")
	check(panel.benefit_label.position.y+panel.benefit_label.size.y<=panel.module_scroll.position.y,"Visible return stays clear of module bays")
	for line in panel.benefit_label.text.split("\n"):
		check(panel.benefit_label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,panel.benefit_label.get_theme_font_size("font_size")).x<=panel.benefit_label.size.x,"Single-step return fits without truncation")
	for button in panel.upgrade_buttons.values():
		check(button.position.y+button.size.y<=panel.benefit_label.position.y,"Purchase button stays clear of visible return")
		for line in button.text.split("\n"):
			check(button.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x<=button.size.x-16,"Purchase text fits its button")
	slider.grab_focus()
	var queries := g.affordability_queries
	scene.writes.clear()
	for i in 30:panel.refresh()
	check(g.affordability_queries==queries,"Unchanged reactor does not recompute affordability")
	check(scene.writes.is_empty(),"Paused unchanged reactor writes no control properties")
	check(slider.has_focus(),"Idle refresh retains input focus")
	g.profile.resources["2"]=0.0
	panel.refresh()
	check(panel.upgrade_buttons.x1.disabled and g.affordability_queries==queries+1,"Income/budget changes immediately update upgrade availability")
	check(not scene.writes.has(slider.get_instance_id()),"Resource-only change does not rewrite allocation slider")
	g.paused=false
	panel.change_allocation(20,"weapons")
	panel.refresh()
	check(not panel.benefit_label.text.contains("武器 +0.00%") and panel.upgrade_buttons.x1.tooltip_text.contains("武器"),"Allocation changes immediately update visible and expanded projected return")
	scene.equipment_tabs.current_tab=0
	check(not panel.core.is_processing() and not panel.network.is_processing(),"Leaving the selected tab synchronously stops animations")
	g.profile.resources["2"]=1000.0
	g.profile.reactorLevel=2
	queries=g.affordability_queries
	panel.refresh()
	check(g.affordability_queries==queries,"Hidden panel defers data work")
	await process_frame
	var hidden_phase: float=panel.core.phase
	await create_timer(0.25).timeout
	check(not panel.is_visible_in_tree() and panel.core.phase==hidden_phase,"Actually hidden core stays stopped across frames")
	for controls in panel.module_controls.values():
		for layer_key in ["branch","track","scene_fx"]:
			check(not controls[layer_key].is_processing(),"Hidden module animation is stopped: "+str(layer_key))
	scene.equipment_tabs.current_tab=2
	await process_frame
	panel.refresh()
	check(panel.level_label.text.contains("2") and not panel.upgrade_buttons.x1.disabled,"Reveal catches up level and budget")
	panel.change_allocation(20,"weapons")
	check(slider.value==20 and panel.module_controls.weapons.track.ratio>0,"Allocation feedback remains immediate")
	g.profile.planets["1"].conquered=true
	panel.refresh()
	check(panel.module_controls.weapons.share.text.contains("免费+10%") and panel.module_controls.weapons.bay_energy.text.contains(panel.energy_text(g.reactor_effective_ratio("weapons")*g.reactor_capacity())),"Nonzero permanent free power reveals its contribution without a duplicate overlapping label")
	g.profile.planets["1"].conquered=false
	panel.refresh()
	check(not panel.module_controls.weapons.allocation_boost.visible and panel.module_controls.weapons.allocation_boost.text.is_empty() and not panel.module_controls.weapons.share.text.contains("免费"),"Removing bonus immediately hides obsolete free supply")
	g.db.config.reactorEnergyBase=float(g.db.config.reactorEnergyBase)*2
	panel.refresh()
	check(slider.max_value==g.reactor_capacity(),"Capacity dependency updates existing slider")
	g.paused=false
	panel.refresh()
	check(panel.core.is_processing(),"Unpause restarts animation without data invalidation")
	g.paused=true
	panel.refresh()
	check(not panel.core.is_processing(),"Pause stops animation without data invalidation")
	check(is_same(slider,panel.module_controls.weapons.slider),"Updates preserve control instances")
	var idle_effect_queries := g.effect_queries
	scene.writes.clear()
	for i in 300:scene.refresh_visible_cards(1.0/60.0)
	check(g.effect_queries==idle_effect_queries and scene.writes.is_empty(),"300 unchanged visible frames do no reactor dependency work or property writes")
	print("REACTOR IDLE / 300 frames: effect dependency queries=",g.effect_queries-idle_effect_queries,"; prior per-frame path=",300*panel.module_controls.size())
	g.paused=false
	g.speed=1.0
	g.profile.resources["2"]=0.0
	g.resources_changed(["2"])
	for i in 30:scene.refresh_visible_cards(1.0/60.0)
	check(g.effect_queries==idle_effect_queries,"dirty resource refresh waits its fixed cutoff")
	g.profile.resources["2"]=1e6
	g.event.emit("galaxy_income",{"id":"2","amount":1e6})
	for i in 31:scene.refresh_visible_cards(1.0/60.0)
	check(g.effect_queries>idle_effect_queries and not panel.upgrade_buttons.x1.disabled,"merged income does not postpone first UI dirty cutoff")
	idle_effect_queries=g.effect_queries
	g.resources_changed(["1"])
	for i in 20:scene.refresh_visible_cards(1.0/60.0)
	check(g.effect_queries==idle_effect_queries,"unrelated resource does not invalidate reactor UI")
	g.paused=false
	scene.refresh_visible_cards(1.0/60.0)
	check(panel.core.is_processing() and g.effect_queries==idle_effect_queries,"unpause resumes animation without dependency recomputation")
	var animation_phase: float=panel.core.phase
	await process_frame
	await process_frame
	check(panel.core.phase!=animation_phase,"powered core animation continues independently of dirty data")
	g.paused=true
	scene.refresh_visible_cards(1.0/60.0)
	check(not panel.core.is_processing() and g.effect_queries==idle_effect_queries,"pause freezes animation without dependency recomputation")
	panel.module_scroll.scroll_vertical=100
	slider.grab_focus()
	var focused_scroll: int=panel.module_scroll.scroll_vertical
	panel.change_allocation(30,"weapons")
	check(slider.value==30 and slider.has_focus() and panel.module_scroll.scroll_vertical==focused_scroll,"direct allocation refresh preserves focus, scroll and immediate value")
	var before_details:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
	panel.details_button.pressed.emit()
	var scope:=UIText.t("reactor.purchase_scope")
	check(panel.details_dialog.visible and ["x1","x10","MAX"].all(func(mode):return panel.details_text.text.contains(panel.upgrade_buttons[mode].tooltip_text.trim_suffix("\n"+scope))),"Explicit details retains every authoritative price/benefit projection")
	check(panel.details_text.text.count(scope)==1,"Expanded details explain the common projection scope once")
	check(JSON.stringify(g.profile)==before_details and g.rng.state==rng_before,"Opening details never purchases or changes the player plan or RNG")
	var fractional_percent:=RegEx.new();fractional_percent.compile("[0-9]+\\.[0-9]+%")
	check(fractional_percent.search(panel.details_text.text)==null,"Expanded reactor projections use integer percentage points")
	panel.details_dialog.hide()
	scene.equipment_tabs.current_tab=0
	g.profile.resources["2"]=0.0
	g.resources_changed(["2"])
	idle_effect_queries=g.effect_queries
	for i in 30:panel.refresh_pending(1.0/60.0)
	check(g.effect_queries==idle_effect_queries and panel.dirty,"hidden page retains dirty work without data reads")
	scene.equipment_tabs.current_tab=2
	await process_frame
	check(panel.upgrade_buttons.x1.disabled and not panel.dirty,"reveal catches deferred budget immediately")
	print("Reactor refresh: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
