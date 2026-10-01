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
	var slider: HSlider=panel.module_controls.weapons.slider
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
	check(panel.module_controls.weapons.allocation_boost.text.contains("10%") and panel.module_controls.weapons.bay_energy.text.contains(panel.energy_text(g.reactor_effective_ratio("weapons")*g.reactor_capacity())),"Permanent free power invalidates module display")
	g.profile.planets["1"].conquered=false
	panel.refresh()
	check(panel.module_controls.weapons.allocation_boost.text==UIText.t("reactor.flow.free",{"energy":"0","percent":"0"}),"Removing bonus immediately clears display")
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
	g.profile.resources["2"]=0.0
	g.resources_changed(["2"])
	for i in 6:scene.refresh_visible_cards(1.0/60.0)
	check(g.effect_queries==idle_effect_queries,"dirty resource refresh waits its fixed cutoff")
	g.profile.resources["2"]=1e6
	g.event.emit("galaxy_income",{"id":"2","amount":1e6})
	for i in 7:scene.refresh_visible_cards(1.0/60.0)
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
