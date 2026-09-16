extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	var builds := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds += 1
		super.build_ui()

var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position=control.get_global_rect().get_center()
	Input.parse_input_event(mouse)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=mouse.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	var scene:=TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.highestLevel=int(scene.db.config.jewelDropLevel)-1
	scene.refresh_tab_visibility()
	check(scene.equipment_tabs.is_tab_hidden(5),"Jewel tab hidden below gate")
	var tabs:=scene.equipment_tabs
	var builds:=scene.builds
	var defence: Label=scene.equipment_card_controls.defence_0.title
	scene.game.profile.highestLevel+=1
	scene.refresh_tab_visibility()
	scene.refresh_equipment_cards("weapons_0")
	check(not tabs.is_tab_hidden(5) and scene.builds==builds,"Unlock only changes visibility")
	var panel=scene.jewel_panel
	for i in 3:
		scene.game.profile.jewels.append(scene.game.new_jewel("7"))
	scene.equipment_tabs.current_tab=5
	await process_frame
	await click(scene.equipment_tabs.get_child(5).get_child(0))
	check(panel.visible and panel.cells.size()==30,"Real click opens 30-cell workshop")
	var cell=panel.cells[0]
	var draws:={"background":0,"defence":0,"cell":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.equipment_panels.defence_0.draw.connect(func():draws.defence+=1)
	cell.draw.connect(func():draws.cell+=1)
	await click(cell)
	await click(panel.cells[1])
	await click(panel.cells[2])
	check(panel.selected.size()==3 and not panel.combine.disabled,"Mouse stages matching gems")
	await click(panel.combine)
	check(scene.game.profile.jewels.size()==1 and scene.game.profile.jewels[0].level==2,"Real click combines")
	check(panel.selected.is_empty() and panel.combine.disabled,"Consumed selection cleared; double click safe")
	check(panel.cells[0]==cell and scene.equipment_tabs==tabs and scene.builds==builds,"Combine preserves unrelated and grid controls")
	panel.hide()
	scene.equipment_tabs.current_tab=0
	await process_frame
	await click(scene.equipment_card_controls.weapons_0.socket)
	check(panel.visible and panel.equipment_index==0,"Equipment button opens socket UI")
	await click(panel.cells[0])
	scene.writes.clear()
	await click(panel.socket_buttons[0])
	check(scene.game.profile.jewels.is_empty() and scene.game.slot_entry("weapons",0).sockets[0].id=="7","Mouse sockets gem")
	check(not scene.writes.has(defence),"Socket never writes unrelated defence label")
	await click(panel.socket_buttons[0])
	check(scene.game.profile.jewels.size()==1 and scene.game.slot_entry("weapons",0).sockets[0].is_empty(),"Mouse unsockets gem")
	scene.game.slot_entry("weapons",0).level=20
	panel.refresh()
	check(panel.socket_buttons.size()==2,"Socket structure follows equipment level")
	await click(panel.cells[0]);await click(panel.socket_buttons[0])
	scene.game.profile.jewels.append(scene.game.new_jewel("7",1))
	panel.refresh()
	await click(panel.cells[0]);await click(panel.socket_buttons[1])
	check(scene.game.profile.jewels.size()==1 and panel.detail.text.contains("同ID"),"Different-level same-ID conflict visibly rejected")
	panel.open()
	scene.game.profile.jewels.append(scene.game.new_jewel("4",10))
	panel.refresh()
	await click(panel.cells[1])
	check(not panel.compose.disabled and panel.combine.disabled,"Max-level action availability")
	var iron: float=scene.game.profile.resources["1"]
	await click(panel.compose)
	check(scene.game.profile.resources["1"]==iron+1000 and scene.game.profile.jewels.size()==1,"Actual mouse decomposes configured reward")
	scene._process(0)
	await process_frame
	await process_frame
	scene.writes.clear()
	for key in draws:draws[key]=0
	for i in 3:
		panel.refresh()
		scene._process(0)
		await process_frame
	check(scene.writes.is_empty(),"Paused unchanged UI no property writes")
	check(draws.background==0 and draws.defence==0 and draws.cell==0,"Paused unchanged controls no redraws")
	panel.hide()
	scene.writes.clear()
	scene.game.pickup_jewel_fragment("1")
	check(scene.writes.is_empty() and not panel.is_processing(),"Hidden workshop stops updates")
	panel.open()
	check(panel.fragments.text.contains("1 / 1000"),"Opening catches up fragment state")
	for id in scene.db.data.jewel:
		scene.game.profile.jewels.append(scene.game.new_jewel(str(id),3))
	panel.refresh()
	await click(panel.cells[4])
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-workshop.png")
	panel.open("weapons",0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-sockets.png")
	print("Jewel UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
