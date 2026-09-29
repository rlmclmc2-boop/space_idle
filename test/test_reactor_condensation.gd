extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	var game = scene.game
	game.profile.cleared = [1,14]
	game.profile.highestLevel = 15
	check(game.reactor_modules().size()==4,"Fourth module configured")
	check(not game.reactor_module_unlocked("condensation"),"Locked before clearing level 15")
	check(not game.set_reactor_allocation("condensation",20),"Locked allocation rejected")
	game.equalize_reactor_allocation()
	check(game.profile.reactorAllocation.condensation==0 and game.reactor_allocated()==game.reactor_capacity(),"Locked module excluded from equalization")
	game.load_reactor({"reactorLevel":1,"reactorAllocation":{"weapons":20,"condensation":50}})
	check(game.profile.reactorAllocation.condensation==0,"Locked allocation cannot enter through save")
	scene.build_ui()
	scene.equipment_tabs.current_tab = 2
	await process_frame
	var panel = scene.reactor_panel
	var controls: Dictionary = panel.module_controls.condensation
	panel.module_scroll.go_to_slot(1)
	await process_frame
	check(not controls.slider.editable and controls.steps[1].disabled,"Locked UI cannot allocate")
	check(controls.boost.text.contains("15"),"Locked UI shows configured threshold")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/condensation-locked.png")
	var same_control: int = controls.slider.get_instance_id()
	game.profile.cleared.append(15)
	game.rebuild_unlocks()
	panel.refresh()
	check(game.reactor_module_unlocked("condensation") and controls.slider.editable and not controls.steps[1].disabled,"Unlock refreshes existing controls")
	check(same_control==controls.slider.get_instance_id(),"Unlock preserves control instances")
	game.equalize_reactor_allocation()
	panel.refresh()
	check(game.profile.reactorAllocation.condensation==25 and game.reactor_allocated()==100,"Four unlocked modules share capacity")
	controls.clear.emit_signal("pressed")
	check(game.profile.reactorAllocation.condensation==0 and controls.branch.trunk_ratio>0 and not controls.scene_fx.is_processing(),"Zero gem allocation keeps trunk flowing")
	controls.steps[1].emit_signal("pressed")
	check(game.profile.reactorAllocation.condensation==1,"Gem increment button works")
	game.set_reactor_allocation("condensation",25)
	panel.refresh()
	check(controls.scene_fx.is_processing() and panel.allocation_scroll.current_slot()==1,"Fourth module animates and columns remain synchronized")
	var power: float = game.reactor_multiplier("condensation")
	game.db.config.jewelCreat = 1000000
	game.profile.highestLevel = 16
	check(is_equal_approx(game.settle_jewel_fragments(10,"drop",2),snappedf(20.0*power,0.01)),"Direct fragments gain configured boost with one final rounding")
	check(game.settle_jewel_fragments(10,"furnace",1)==10,"Furnace fragments excluded")
	check(game.settle_jewel_fragments(10,"other",1)==10,"Other fragment credits excluded")
	var direct := {"jewel":true,"amount":10.0,"jewelRatio":2.0,"x":100.0,"y":100.0}
	game.drops.append(direct)
	var before: float = game.profile.jewelFragments
	game.collect(direct,true)
	check(is_equal_approx(float(game.profile.jewelFragments)-before,snappedf(20.0*power,0.01)),"Actual pickup settles boosted amount")
	var once: float = game.profile.jewelFragments
	game.collect(direct,true)
	check(game.profile.jewelFragments==once,"Repeated pickup cannot double-credit")
	var raw: Dictionary = game.profile.duplicate(true)
	game.load_reactor(raw)
	check(game.profile.reactorAllocation.condensation==25,"Unlocked save restores gem allocation")
	game.load_reactor({"reactorLevel":1,"reactorAllocation":{"weapons":20,"defence":30,"smelting":40}})
	check(game.profile.reactorAllocation.condensation==0 and game.reactor_allocated()==90,"Old save gains empty fourth slot without reallocating others")
	game.equalize_reactor_allocation()
	panel.refresh()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/condensation-active.png")
	print("condensation failures: ",failures)
	quit(1 if failures else 0)
