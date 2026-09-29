extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func click_power(input: Control, fraction: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = input.get_global_transform()*Vector2(input.size.x*clampf(fraction,0.0001,0.9999),input.size.y*0.5)
	press.global_position = press.position
	input.get_viewport().push_input(press,true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	release.global_position = release.position
	input.get_viewport().push_input(release,true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.cleared = [1]
	scene.build_ui()
	scene.equipment_tabs.current_tab = 2
	await process_frame
	var panel = scene.reactor_panel
	var weapons = panel.module_controls.weapons
	var defence = panel.module_controls.defence
	var smelting = panel.module_controls.smelting
	var capacity: int = scene.game.reactor_capacity()
	check(weapons.slider.max_value == capacity and weapons.track.available_ratio == 1.0,"Full slider scale initially available")
	click_power(weapons.input,0.3)
	click_power(defence.input,0.4)
	check(int(scene.game.profile.reactorAllocation.weapons)==30 and int(scene.game.profile.reactorAllocation.defence)==40 and int(scene.game.profile.reactorAllocation.smelting)==0,"Each input changes only its module")
	check(scene.game.reactor_allocated()==70 and panel.remaining_label.text.contains("30") and is_equal_approx(weapons.track.available_ratio,0.6),"Remaining pool sets available limit while slider retains total scale")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(weapons.input.size.x,weapons.input.size.y*0.5)
	weapons.input._gui_input(press)
	check(int(scene.game.profile.reactorAllocation.weapons)==60 and int(scene.game.profile.reactorAllocation.defence)==40 and scene.game.reactor_allocated()==capacity,"Increase stops at current amount plus remaining without moving another module")
	check(weapons.input.value_label.visible and weapons.input.value_label.text=="60" and weapons.slider.max_value==capacity and is_equal_approx(weapons.track.available_ratio,0.6),"Drag value and unavailable track segment reflect integer limit")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	weapons.input._gui_input(release)
	check(not weapons.input.value_label.visible and panel.remaining_label.text.contains("0"),"Drag value hides after release at zero remaining")
	click_power(defence.input,0.0)
	check(int(scene.game.profile.reactorAllocation.defence)==0 and int(scene.game.profile.reactorAllocation.weapons)==60 and scene.game.reactor_allocated()==60 and panel.remaining_label.text.contains("40"),"Decrease returns energy to remaining pool")
	weapons.clear.emit_signal("pressed")
	check(int(scene.game.profile.reactorAllocation.weapons)==0 and scene.game.reactor_allocated()==0 and weapons.clear.disabled,"Clear affects only selected module and restores full pool")
	click_power(smelting.input,1.0)
	check(int(scene.game.profile.reactorAllocation.smelting)==capacity and scene.game.reactor_allocated()==capacity and panel.total_track.ratio>=0.999,"One module reaches full allocation: "+str(scene.game.profile.reactorAllocation)+" transform="+str(smelting.input.get_global_transform()))
	panel.equalize_button.emit_signal("pressed")
	check(int(scene.game.profile.reactorAllocation.weapons)==34 and int(scene.game.profile.reactorAllocation.defence)==33 and int(scene.game.profile.reactorAllocation.smelting)==33 and scene.game.reactor_allocated()==capacity,"Equalize is the only bulk redistribution")
	scene.game.profile.reactorLevel = 60
	scene.game.set_reactor_allocation("weapons",1234567)
	panel.refresh()
	check(weapons.energy.text==UIText.t("reactor.module.energy",{"energy":"1.2M"}) and int(scene.game.profile.reactorAllocation.weapons)==1234567,"Large display is compact without rounding allocation")
	check(panel.energy_label.text==UIText.t("reactor.energy",{"energy":scene.number(scene.game.reactor_capacity())}) and panel.remaining_label.text==UIText.t("reactor.remaining",{"energy":scene.number(scene.game.reactor_capacity()-scene.game.reactor_allocated())}),"Total and remaining use shared quantity formatting")
	check(weapons.boost.text.contains("K%") and panel.level_label.text.contains("60"),"Large percent is compact while level stays exact")
	check(defence.share.text == UIText.t("reactor.allocation_tiny"),"Positive sub-percent allocation is not displayed as zero")
	var before_step: int = scene.game.profile.reactorAllocation.weapons
	weapons.steps[0].emit_signal("pressed")
	check(scene.game.profile.reactorAllocation.weapons == before_step-int(scene.db.config.reactorAllocationStep),"Minus follows the configured allocation step")
	weapons.steps[1].emit_signal("pressed")
	check(scene.game.profile.reactorAllocation.weapons == before_step,"Plus restores one configured allocation step")
	press.position = Vector2(weapons.input.size.x*0.3,weapons.input.size.y*0.5)
	weapons.input._gui_input(press)
	check(weapons.input.value_label.text==scene.number(scene.game.profile.reactorAllocation.weapons),"Drag label uses shared compact formatting")
	release.position = press.position
	weapons.input._gui_input(release)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2048,1280)]:
		root.size = resolution
		await process_frame
		for key in panel.module_controls:
			var controls = panel.module_controls[key]
			var energy_rect: Rect2 = controls.energy.get_global_rect()
			var track_rect: Rect2 = controls.track.get_global_rect()
			check(energy_rect.position.y >= track_rect.end.y and not energy_rect.intersects(controls.input.get_global_rect()) and controls.energy.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Energy text stays below the allocation track without blocking input at "+str(resolution))
			check(not track_rect.intersects(controls.clear.get_global_rect()) and not controls.name.get_global_rect().intersects(controls.boost.get_global_rect()),"Row text and clear button do not overlap at "+str(resolution))
			var expected_prefix: String=UIText.t("reactor.module.%s.effect" % key) if scene.game.reactor_module_unlocked(key) else UIText.t("reactor.module.locked",{"level":str(int(scene.db.unlock_row("reactor_module",key).get("level",0)))})
			check(controls.boost.text.begins_with(expected_prefix) and controls.boost.get_minimum_size().x <= controls.boost.size.x,"Named effect or locked module label fits at "+str(resolution))
			check(controls.track.position==weapons.track.position and controls.clear.position==weapons.clear.position and controls.name.position==weapons.name.position,"Module columns align at "+str(resolution))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/reactor-%dx%d.png" % [resolution.x,resolution.y])
	print("reactor allocation UI failures: ",failures)
	quit(1 if failures else 0)
