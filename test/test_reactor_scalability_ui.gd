extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func rect_in(control: Control, ancestor: Control) -> Rect2:
	var position := Vector2.ZERO
	var current: Control = control
	while current != ancestor:
		position += current.position
		current = current.get_parent() as Control
		if current == null:return Rect2()
	return Rect2(position,control.size)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for count in [4,5]:
		var scene := preload("res://scripts/main.gd").new()
		scene.automation_args = ["--capture"]
		root.add_child(scene)
		scene.set_process(false)
		scene.game.save_enabled = false
		scene.game.profile.cleared = [1]
		scene.game.profile.resources["2"] = 1000.0
		var keys := PackedStringArray(["weapons","defence","smelting","test_4","test_5"])
		keys.resize(count)
		scene.db.config.reactorModules = ",".join(keys)
		for key in keys:scene.game.profile.reactorAllocation[key] = int(100/count)
		scene.build_ui()
		scene.equipment_tabs.current_tab = 2
		await process_frame
		var panel = scene.reactor_panel
		check(panel.module_controls.size() == count,"All %d modules constructed" % count)
		check(not panel.core.get_global_rect().intersects(panel.level_label.get_global_rect()),"Core leaves the upgrade controls clear")
		check(panel.allocation_label.get_parent().clip_contents and panel.remaining_label.get_parent().clip_contents,"Summary text is clipped to its slots")
		check(panel.module_scroll.size.y == 3*220 and panel.allocation_scroll.size.y == 3*110,"Both columns show three complete modules")
		check(panel.module_content.size.y >= count*220,"Content holds all bays")
		check(panel.module_scroll.max_slot() == count-3,"Last full viewport slot")
		var housing := preload("res://assets/ui/reactor/module-housing-v3.png")
		for controls in panel.module_controls.values():
			check(controls.row.get_children().any(func(child):return child is TextureRect and child.texture == housing),"Each module reuses the common housing")
			check(controls.branch != null and controls.icon.texture != null,"Module has a pipe branch and icon")
			check(not controls.icon.get_global_rect().intersects(controls.name.get_global_rect()),"Module icon and name do not overlap")
			check(not controls.name.get_global_rect().intersects(controls.clear.get_global_rect()),"Module name and clear action do not overlap")
			check(not controls.boost.get_global_rect().intersects(controls.bay_energy.get_global_rect()),"Module effect and energy stay distinct")
			check(not controls.energy.get_global_rect().intersects(controls.input.get_global_rect()),"Energy readout does not overlap the allocation hit area")
			check(controls.row.get_global_rect().encloses(controls.bay_track.get_global_rect()),"Power segments remain inside their housing")
		check(not panel.module_controls[keys[count-1]].scene_fx.is_processing(),"Offscreen bay animation sleeps")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.window_id = scene.get_window().get_window_id()
		wheel.position = panel.module_scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		root.push_input(wheel,true)
		await process_frame
		check(panel.module_scroll.scroll_vertical == 220 and panel.allocation_scroll.scroll_vertical == 110,"One wheel event moves both columns by one module")
		panel.module_scroll.go_to_slot(0)
		var fixed_core: Rect2 = panel.core.get_global_rect()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/reactor-%d-top.png" % count)
		panel.module_scroll.go_to_slot(count-3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/reactor-%d-bottom.png" % count)
		check(panel.allocation_scroll.current_slot() == count-3,"Allocation rows stay paired with last device rows")
		check(panel.core.get_global_rect() == fixed_core,"Core stays fixed at %d modules" % count)
		check(panel.module_scroll.scroll_vertical == (count-3)*220,"Scroll snaps to last complete viewport")
		check(panel.module_controls[keys[count-1]].scene_fx.is_processing() and not panel.module_controls.weapons.scene_fx.is_processing(),"Only visible bays animate after scroll")
		check(panel.module_controls[keys[count-1]].row.get_global_rect().end.y <= panel.module_scroll.get_global_rect().end.y,"Last bay fully visible at %d modules" % count)
		panel.allocation_scroll.go_to_slot(0)
		await process_frame
		check(panel.module_scroll.current_slot() == 0,"Scrolling allocation column also moves device column")
		scene.equipment_tabs.current_tab = 0
		await process_frame
		check(not panel.core.is_processing() and panel.module_controls.values().all(func(c):return not c.scene_fx.is_processing()),"Hidden reactor stops all device animation")
		scene.equipment_tabs.current_tab = 2
		await process_frame
		check(panel.core.is_processing() and panel.module_controls.weapons.scene_fx.is_processing(),"Revealing reactor resumes visible animation")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("reactor scalability failures: ",failures)
	quit(1 if failures else 0)
