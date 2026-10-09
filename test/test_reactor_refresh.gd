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
	check(NumberFormat.scalar(3.24)=="3" and NumberFormat.scalar(3.26)=="3.5" and NumberFormat.scalar(-0.01)=="0","Ordinary display uses half units without negative zero")
	check(NumberFormat.scalar(39100)=="39.1K" and NumberFormat.scalar({"m":3.91,"e":4})=="39.1K","Scalar display preserves suffix precision for native and large-number values")
	check(NumberFormat.precise(6.75)=="6.75" and g.description_number(0.28)=="0.28","Formula literals and fractional economic values keep precision")
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
	check(panel.details_dialog.visible and panel.details_text.text.contains(panel.upgrade_buttons.x1.tooltip_text) and panel.details_text.text.contains(panel.upgrade_buttons.MAX.tooltip_text),"Explicit details contains the authoritative single and MAX price/benefit projections")
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
