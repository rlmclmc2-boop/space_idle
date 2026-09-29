extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.cleared = [1]
	scene.game.profile.resources["2"] = 1000.0
	scene.build_ui()
	scene.equipment_tabs.current_tab = 2
	await process_frame
	var panel = scene.reactor_panel
	var orb_bounds: Rect2 = panel.core.get_global_rect()
	check(orb_bounds.end.x < panel.energy_label.get_global_rect().position.x,"Live reactor core leaves data controls unobstructed: "+str(orb_bounds)+" / "+str(panel.energy_label.get_global_rect()))
	check(panel.room.texture != null and panel.core.layers.orb.material is ShaderMaterial,"Unified room and live reactor orb load")
	check(panel.module_controls.values().all(func(controls):return controls.dimmer is ColorRect and controls.scene_fx.mouse_filter == Control.MOUSE_FILTER_IGNORE),"Integrated equipment effects keep input clear")
	check(panel.module_controls.weapons.icon.texture != null and panel.module_controls.defence.icon.texture != null and panel.module_controls.smelting.icon.texture != null,"Module icon resources load")
	check(panel.module_controls.weapons.track.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.module_controls.weapons.slider.mouse_filter != Control.MOUSE_FILTER_IGNORE and panel.core.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.network.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.room.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Art layers do not block power controls")
	var old_phase: float = panel.core.layers.orb.material.get_shader_parameter("phase")
	await process_frame
	check(panel.core.layers.orb.material.get_shader_parameter("phase") != old_phase,"Energy orb animates without rebuilding controls")
	check(panel.level_label.text.contains("1") and panel.energy_label.text.contains("100"),"Reactor level and energy shown")
	check(panel.uranium_label.text == UIText.t("reactor.uranium",{"uranium":scene.number(1000.0)}) and panel.cost_label.text == UIText.t("reactor.cost",{"cost":scene.number(scene.game.reactor_upgrade_cost())}),"Uranium and configured cost shown")
	check(panel.module_controls.size() == scene.game.reactor_modules().size(),"Configured sliders shown")
	check(panel.equalize_button.is_visible_in_tree() and panel.equalize_button.text == UIText.t("reactor.equalize") and panel.equalize_button.get_parent() != panel.upgrade_buttons.MAX.get_parent(),"Equalize is secondary to grouped upgrade actions")
	check(panel.upgrade_buttons.x1.get_parent() == panel.upgrade_buttons.x10.get_parent() and panel.upgrade_buttons.x10.get_parent() == panel.upgrade_buttons.MAX.get_parent(),"Upgrade controls share one group")
	check(panel.next_label.text.contains("2"),"Next level shown")
	panel.upgrade_buttons.x1.emit_signal("pressed")
	check(scene.game.profile.reactorLevel == 2 and panel.level_label.text.contains("2") and panel.next_label.text.contains("3"),"Upgrade button refreshes level and next level")
	var slider: HSlider = panel.module_controls.weapons.slider
	var power_input: Control = panel.module_controls.weapons.input
	check(power_input.size.y > panel.module_controls.weapons.track.size.y and power_input.mouse_filter == Control.MOUSE_FILTER_STOP,"Whole power band accepts pointer input")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(0,4)
	power_input._gui_input(press)
	check(int(scene.game.profile.reactorAllocation.weapons)==0 and panel.module_controls.weapons.track.ratio==0.0 and panel.module_controls.weapons.dimmer.color.a > 0.5,"Click at start clears power and visibly dims module bay")
	var drag := InputEventMouseMotion.new()
	drag.global_position = power_input.get_global_transform()*Vector2(power_input.size.x+100,4)
	power_input._input(drag)
	check(int(scene.game.profile.reactorAllocation.weapons)==scene.game.reactor_capacity() and panel.total_track.ratio >= 0.999 and panel.remaining_label.text.contains("0"),"Drag past track fills capacity and total slot")
	panel.module_controls.defence.slider.value = 99
	check(int(scene.game.profile.reactorAllocation.defence)==0 and scene.game.reactor_allocated()==scene.game.reactor_capacity(),"Allocation cannot exceed total energy")
	drag.global_position = power_input.get_global_transform()*Vector2(power_input.size.x*0.25,4)
	power_input._input(drag)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = drag.global_position
	power_input._input(release)
	check(int(scene.game.profile.reactorAllocation.weapons)==30 and not power_input.dragging and panel.module_controls.weapons.track.preview_ratio < 0.0,"Captured drag follows pointer and releases to integer")
	press.position = Vector2(power_input.size.x*0.5,power_input.size.y-3)
	power_input._gui_input(press)
	release.position = press.position
	power_input._gui_input(release)
	check(int(scene.game.profile.reactorAllocation.weapons)==60,"Click anywhere in tall power band jumps to integer position")
	slider.value = 50.7
	check(scene.game.profile.reactorAllocation.weapons == 51 and panel.allocation_label.text.contains("51") and panel.remaining_label.text.contains("69"),"Slider applies integer allocation and totals immediately")
	check(panel.module_controls.weapons.track.ratio > 0 and panel.module_controls.weapons.boost.text.begins_with(UIText.t("reactor.module.weapons.effect")),"Pipeline and named boost update immediately")
	slider.grab_focus()
	var right := InputEventKey.new()
	right.window_id = scene.get_window().get_window_id()
	right.keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	check(int(scene.game.profile.reactorAllocation.weapons)==52 and panel.remaining_label.text.contains("68"),"Focused power slot accepts integer keyboard input")
	panel.equalize_button.emit_signal("pressed")
	check(int(scene.game.profile.reactorAllocation.weapons)==40 and panel.allocation_label.text.contains("120") and panel.remaining_label.text.contains("0"),"Equalize button updates allocation and summary")
	var affordable: int = scene.game.reactor_max_upgrades()
	check(panel.upgrade_buttons.x10.disabled == (affordable < 10) and panel.upgrade_buttons.MAX.disabled == (affordable == 0),"Upgrade buttons follow affordable count")
	var unrelated := scene.equipment_panel
	panel.refresh()
	check(scene.equipment_panel == unrelated and slider == panel.module_controls.weapons.slider,"Refresh retains unrelated controls and active slider")
	check(panel.network.position+panel.network.network_route[0] == Vector2(362,333),"Feed starts inside the bottom of the live energy core")
	check(is_equal_approx((panel.network.position+panel.network.network_route[-1]).x,panel.module_scroll.position.x+17),"Feed bend lands on the module trunk axis")
	var flow_view := SubViewport.new()
	flow_view.size = Vector2i(337,155)
	flow_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(flow_view)
	var feed := preload("res://scripts/reactor_visual.gd").new()
	feed.mode = "network"
	feed.size = Vector2(337,155)
	flow_view.add_child(feed)
	feed.set_ratio(1.0)
	feed.set_process(true)
	await RenderingServer.frame_post_draw
	var intake_before := flow_view.get_texture().get_image().get_region(Rect2i(11,25,12,48)).get_data()
	var flow_before := flow_view.get_texture().get_image().get_region(Rect2i(60,100,160,12)).get_data()
	await create_timer(0.17).timeout
	await RenderingServer.frame_post_draw
	var flow_after := flow_view.get_texture().get_image().get_region(Rect2i(60,100,160,12)).get_data()
	var intake_after := flow_view.get_texture().get_image().get_region(Rect2i(11,25,12,48)).get_data()
	check(intake_before != intake_after,"Energy visibly leaves the core through the downward collector")
	check(flow_before != flow_after,"Visible energy travels along the horizontal feed, not just the vertical trunk")
	flow_view.queue_free()
	for zero_key in ["weapons","defence","smelting"]:
		panel.equalize_button.emit_signal("pressed")
		panel.module_controls[zero_key].clear.emit_signal("pressed")
		var inactive = panel.module_controls[zero_key]
		check(inactive.branch.ratio == 0.0 and inactive.branch.trunk_ratio > 0.0 and inactive.branch.is_processing(),"Zero outlet retains passing trunk flow: "+zero_key)
		check(not inactive.track.is_processing() and not inactive.scene_fx.is_processing(),"Zero outlet stops only its own load effects: "+zero_key)
		check(panel.module_controls.values().all(func(c):return c.branch.is_processing() if c.index < 3 else not c.branch.is_processing()),"Every visible trunk section flows past a zero outlet")
	var branch_view := SubViewport.new()
	branch_view.size = Vector2i(146,220)
	branch_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(branch_view)
	var isolated_branch := preload("res://scripts/reactor_visual.gd").new()
	isolated_branch.mode = "branch"
	isolated_branch.size = Vector2(146,220)
	branch_view.add_child(isolated_branch)
	isolated_branch.set_trunk_ratio(0.66)
	isolated_branch.set_ratio(0.0)
	isolated_branch.set_process(true)
	await RenderingServer.frame_post_draw
	var trunk_before := branch_view.get_texture().get_image().get_region(Rect2i(12,0,10,220)).get_data()
	var outlet_before := branch_view.get_texture().get_image().get_region(Rect2i(50,85,65,20)).get_data()
	await create_timer(0.17).timeout
	await RenderingServer.frame_post_draw
	check(trunk_before != branch_view.get_texture().get_image().get_region(Rect2i(12,0,10,220)).get_data(),"Trunk pixels animate when the local allocation is zero")
	check(outlet_before == branch_view.get_texture().get_image().get_region(Rect2i(50,85,65,20)).get_data(),"Zero outlet pixels remain still while trunk moves")
	branch_view.queue_free()
	for controls in panel.module_controls.values():controls.clear.emit_signal("pressed")
	check(not panel.network.is_processing() and panel.module_controls.values().all(func(c):return not c.branch.is_processing()),"All-zero allocations stop the complete power network")
	panel.equalize_button.emit_signal("pressed")
	scene.game.paused = true
	panel.refresh()
	check(not panel.core.is_processing() and not panel.network.is_processing() and not panel.module_controls.weapons.track.is_processing() and panel.module_controls.values().all(func(controls):return not controls.scene_fx.is_processing() and not controls.branch.is_processing()),"Paused scene stops animation")
	scene.game.paused = false
	panel.refresh()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/reactor.png")
	var saved_summary: String = panel.allocation_label.text
	panel.set_readout(panel.allocation_label,"已分配 123456789012345678901234567890 / 123456789012345678901234567890")
	check(panel.allocation_label.get_parent().clip_contents and panel.allocation_label.autowrap_mode == TextServer.AUTOWRAP_OFF and panel.allocation_label.get_theme_font_size("font_size") == 13,"Long summary stays on one clipped line")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/reactor-long-readout.png")
	panel.set_readout(panel.allocation_label,saved_summary)
	panel.upgrade_buttons.MAX.emit_signal("pressed")
	check(scene.game.profile.reactorLevel > 2 and panel.energy_label.text == UIText.t("reactor.energy",{"energy":scene.number(scene.game.reactor_capacity())}),"MAX button upgrades and refreshes capacity display")
	print("reactor UI failures: ",failures)
	quit(1 if failures else 0)
