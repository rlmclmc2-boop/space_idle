extends SceneTree

class ObservedGame extends BattleGame:
	var affordability_queries := 0
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
	scene.equipment_tabs.current_tab=0
	g.profile.resources["2"]=1000.0
	g.profile.reactorLevel=2
	queries=g.affordability_queries
	panel.refresh()
	check(g.affordability_queries==queries,"Hidden panel defers data work")
	scene.equipment_tabs.current_tab=2
	panel.refresh()
	check(panel.level_label.text.contains("2") and not panel.upgrade_buttons.x1.disabled,"Reveal catches up level and budget")
	panel.change_allocation(20,"weapons")
	check(slider.value==20 and panel.module_controls.weapons.track.ratio>0,"Allocation feedback remains immediate")
	g.profile.planets["1"].conquered=true
	panel.refresh()
	check(panel.module_controls.weapons.share.text.contains("(+10%)"),"Permanent free power invalidates module display")
	g.profile.planets["1"].conquered=false
	panel.refresh()
	check(not panel.module_controls.weapons.share.text.contains("("),"Removing bonus immediately clears display")
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
	print("Reactor refresh: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
