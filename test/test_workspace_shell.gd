extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()*Vector2(root.size)/root.get_visible_rect().size
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=range(1,51)
	scene.game.profile.highestLevel=51
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.build_ui()
	await process_frame
	var tabs := scene.equipment_tabs
	var pages := tabs.get_children().filter(func(child):return child is Control and child!=tabs.get_tab_bar())
	var page_identity := pages.duplicate()
	check(not tabs.tabs_visible and scene.system_nav_buttons.size()==8,"Vertical navigation includes the final chrono page")
	check(scene.battle_clip.position.x<scene.system_nav.get_global_rect().position.x and scene.system_nav.get_global_rect().end.x<scene.workspace_frame.get_global_rect().position.x,"Battle, navigation, workspace are three separate columns")
	check(scene.workspace_frame.size.x>scene.system_nav.size.x*6,"Workspace owns the remaining width")
	check(scene.global_status_label.text.contains("1") and scene.global_status_label.get_global_rect().end.y<78,"Global status is in the header")
	var header_controls: Array[Control] = [scene.global_status_label,scene.resource_mode_button,scene.music_button,scene.loop_select,scene.loop_button,scene.guard_settings,scene.sound_button,scene.help_button]
	for left in header_controls.size():
		for right in range(left+1,header_controls.size()):
			check(not header_controls[left].get_global_rect().intersects(header_controls[right].get_global_rect()),"Header controls do not overlap: %d/%d" % [left,right])
	var resource_columns := [Rect2(Vector2(scene.RIGHT_UI_OFFSET+scene.position.x+65,18),Vector2(205,48)),Rect2(Vector2(scene.RIGHT_UI_OFFSET+scene.position.x+280,18),Vector2(205,48))]
	for column in resource_columns:
		for control in header_controls:
			check(not column.intersects(control.get_global_rect()),"Resource text stays clear of "+control.name)
	check(not resource_columns[0].intersects(resource_columns[1]),"Resource columns stay separate")
	scene.game.paused=true
	scene.refresh_draw_layers(0)
	check(scene.global_status_label.text==UIText.t("battle.stage",{"stage":str(scene.game.stage)})+" · "+UIText.t("hud.state.paused"),"Paused status updates without rebuilding the header")
	scene.game.paused=false
	scene.refresh_draw_layers(0)
	var position: Vector2=tabs.position
	var size: Vector2=tabs.size
	var scale_value: Vector2=tabs.scale
	for index in scene.system_nav_buttons.size():
		var navigation: Button=scene.system_nav_buttons[index]
		if not navigation.visible:continue
		await click(navigation)
		check(tabs.current_tab==index and scene.workspace_title.text==UIText.t(scene.SYSTEM_TITLES[index]),"Navigation selects matching titled page: "+str(index))
		check(bool(navigation.get_meta("selected")) and tabs.position==position and tabs.size==size and tabs.scale==scale_value,"Page stays inside shared workspace: "+str(index))
		check(scene.battle_layer.visible and scene.battle_clip.position==scene.BATTLE_ORIGIN,"Battle remains visible beside page: "+str(index))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/workspace-page-%d.png" % index)
	check(pages==page_identity,"System controls are reused across navigation")
	check(not scene.has_method("toggle_battle_focus") and scene.battle_clip.position==scene.BATTLE_ORIGIN and scene.system_nav.visible and scene.workspace_frame.visible,"Battle stays fixed in the main layout")
	print("Workspace shell: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
